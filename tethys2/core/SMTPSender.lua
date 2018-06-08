module(..., package.seeall)

local oo = require "loop.simple"
local State = require'tethys2.core.State'
local Relay = require('tethys2.plugins.deposit.Relay')
local util = require'tethys2.util.util'
local dns = require'tethys2.util.dns'
local mime = require('mime')
local scheduler = require('loop.thread.SocketScheduler')
local socket    = scheduler.socket
require'config'

new = oo.class()
SMTPSender = new
class = new

function SMTPSender:checkCode(s, code)
	local line = s:receive()
	if not line then self.currentError = "No response from server" return false end
	self.server:logDebug("<<%s,", line)
	while line:find("^...%-") do
		line = s:receive()
		if not line then self.currentError = "No response from server" return false end
		self.server:logDebug("<<%s,", line)
	end
	if line:find(code) then
		return true
	else
		self.currentError = line
		return false
	end
end

function SMTPSender:writeLine(s, str)
	s:send(str)
	s:send("\r\n")
	self.server:logDebug(">>%s", str)
end

function SMTPSender:sendMail(socket, mxs, host, data, route_raw)
	local s = socket
	s:settimeout(60)

	local error_user = {}

	mxs = mxs or { {host=host} }
	for i, mx in ipairs(mxs) do
		self.server:log("Connecting to MX %s (%s) to send mail from <%s>", mx.host or "[no MX record in DNS]", host, route_raw.from)
		if not s:connect(mx.host, 25) then
			self.currentError = "Could not connect to MX server "..tostring(mx.host).." (MX of domain "..tostring(mx.host)..")"
			self.server:logError("%s", self.currentError)
			if i == #mxs then return util.reverseTable(data, self.currentError) end
		else
			if not self:checkCode(s, "^2..") then
				self.server:logError("%s", self.currentError)
				if i == #mxs then return util.reverseTable(data, self.currentError) end
			else
				break
			end
		end
	end

	self:writeLine(s, "HELO "..config.settings.bind.reply_host)
	if not self:checkCode(s, "^2..") then return util.reverseTable(data, self.currentError) end

	self:writeLine(s, string.format("MAIL FROM:<%s>", route_raw.from))
	if not self:checkCode(s, "^2..") then return util.reverseTable(data, self.currentError) end

	local nb_err = 0
	for i, v in ipairs(data) do
		self:writeLine(s, string.format("RCPT TO:<%s>", v))
		if not self:checkCode(s, "^2..") then error_user[v] = self.currentError nb_err=nb_err+1 end
	end
	if #data == nb_err then return error_user end

	self:writeLine(s, "DATA")
	if not self:checkCode(s, "^354") then return util.reverseTable(data, self.currentError) end
	-- Inlined data
	if not self.path and not self.filename and self.inline_data then
		for i, line in ipairs(self.inline_data) do
			if line:find("^%.") then
				line = "."..line
			end
			self:writeLine(s, line)
		end
	-- Read data from file
	else
		for line in io.lines(self.path.."/"..self.filename, "r") do
			if line:find("^%.") then
				line = "."..line
			end
			self:writeLine(s, line)
		end
	end
	self:writeLine(s, ".")
	if not self:checkCode(s, "^2..") then return util.reverseTable(data, self.currentError) end

	self:writeLine(s, "QUIT")

	s:close()

	return error_user
end

function SMTPSender:send()
	self.server:log("New mail in sendbox %s :=: %s", self.path, self.filename)
	local route_raw = loadfile(self.path.."/"..self.infofile)()
	local route = {}
	for i, rcpt in ipairs(route_raw.rcpt) do
		route[rcpt.host] = route[rcpt.host] or {}
		table.insert(route[rcpt.host], rcpt.account.."@"..rcpt.host)
	end

	-- Count active threads and return statuses
	local thread_return = { active_threads = 0, errors = {}, nb_errors = 0 }
	for host, data in pairs(route) do
		local mx = dns.resolveMX(host)
		self.server:log("Resolved mx for %s to %s (%s)", host, tostring(mx), tostring(mx and mx.host))

		-- Make a thread for each server to call, so they answer in parallel
		local thread = coroutine.create(function()
			local s = socket:tcp()
			local error_user
			error_user = self:sendMail(s, mx, host, data, route_raw)

			for addr, reason in pairs(error_user) do
				thread_return.errors[addr] = { mx = mx, reason = reason }
				thread_return.nb_errors = thread_return.nb_errors + 1
			end
		end)

		-- Count one more thread to wait
		thread_return.active_threads = thread_return.active_threads + 1

		-- Register the thread and add a trap for errors
		scheduler:register(thread)
		scheduler.traps[thread] = function(self2, thread, success, errmsg)
			-- We are done, count one less thread
			thread_return.active_threads = thread_return.active_threads - 1

			if not success and errmsg then self.server:logError("[lua-error] %s", errmsg) end
		end
	end

	-- Wait until all threads return
	while thread_return.active_threads > 0 do
		scheduler:suspend(1)
	end

	local errors = thread_return.errors
	local nb_errors = thread_return.nb_errors

	-- No errors ? we are done there
	if nb_errors == 0 then return true end

	-- Send error mails if any
	if (route_raw.try or 0) <= 0 then
		for addr, reason_data in pairs(errors) do
			local acc, host = util.addressRouteStrip(route_raw.from)
			if acc and host then
				local data = {}
				reason_data = reason_data or {}
				table.insert(data, os.date("Date: %d %b %Y %H:%M:%S %z"))
				table.insert(data, ("From: %s"):format(config.settings.mail_error.from))
				table.insert(data, ("To: %s@%s"):format(acc, host))
				table.insert(data, "Subject: Mail delivery failure")
				table.insert(data, "")
				table.insert(data, ("Sorry %s, your message to %s is lost."):format(acc, addr))
				table.insert(data, ("%s said '%s'"):format(reason_data.mx and reason_data.mx[1] and reason_data.mx[1].host or "???", (type(reason_data.reason) == "string") and reason_data.reason or "Unknown error"))
				table.insert(data, "")
				table.insert(data, "--- Below this line is a copy of the message.")
				table.insert(data, "")
				for line in io.lines(self.path.."/"..self.filename, "r") do
					table.insert(data, line)
				end

				local state = State.new()
				state:setFrom("")
				state.data = data
				state:addTo(acc, host, nil, acc, host)

				local relay = Relay.new()
				relay:init(self.server)
				relay:deliverMail(state.to[acc.."@"..host], state)
				self.server:log("Could not send mail to <%s>, sending error message to <%s@%s> (%s) from <>", addr, acc, host, route_raw.from)
				relay:finishDelivery(state)
			end
		end
	-- Can we still try latter? Pretty please!
	else
		local newname = self.filename:match("(.*)%-date%d+")
		if newname then
			newname = newname.."-date"..(os.time() + config.settings.sender.retries_time)
		else
			-- This really should not happen
			newname = self.filename
		end
		local state = State.new()
		state:setFrom(route_raw.from)
		state.data = {}
		state.retry = route_raw.try-1
		state.relay_dest = "retry"
		state.no_mail = true
		state.force_name = newname

		local relay = Relay.new()
		relay:init(self.server)

		-- Call the relay plugin to do the work correctly
		for addr, reason_data in pairs(errors) do
			local account, host = util.addressRouteStrip(addr)
			self.server:log("Could not send mail to <%s>, will retry again later", addr)
			if account and host then
				state:addTo(account, host, nil, account, host)
				relay:deliverMail(state.to[account.."@"..host], state)
			end
		end
		relay:finishDelivery(state)

		local olddir = lfs.currentdir()
		lfs.chdir(self.path)
		lfs.chdir("..")
		posix.link("new/"..self.filename, "retry/"..newname)
		posix.unlink("new/"..self.filename)
		posix.unlink("new/"..self.infofile)
		lfs.chdir(olddir)
		return false
	end
	return true
end

function SMTPSender:handle()
	if lfs.attributes(self.path.."/"..self.filename, "mode") == "file" and lfs.attributes(self.path.."/info-"..self.filename, "mode") == "file" then
		-- If we are ready to try it, try it
		self.infofile = "info-"..self.filename
		if self:send() then
			lfs.chdir(self.path)
			lfs.chdir("..")
			posix.link("new/"..self.filename, "cur/"..self.filename)
			posix.link("new/info-"..self.filename, "cur/info-"..self.filename)
			posix.unlink("new/"..self.filename)
			posix.unlink("new/info-"..self.filename)
		end
		collectgarbage("collect")
	end
end

function SMTPSender:__init(server, path, filename)
	local t = {}
	t.server = server
	t.path = path
	t.filename = filename

	t = oo.rawnew(self, t)
	return t
end
