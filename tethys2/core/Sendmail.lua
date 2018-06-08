module(..., package.seeall)

local oo = require "loop.simple"
local Server = require'tethys2.core.Server'
local State = require'tethys2.core.State'
local SMTPSender = require'tethys2.core.SMTPSender'
local util = require('tethys2.util.util')
require'posix'
require'config'

new = oo.class({ server_type="sendmail" }, Server.class)
Sendmail = new
class = new

function Sendmail:thread(...)
	-- Drop privilegdes but dont realy go daemon
	self:daemonize(true)
	self:postInit()

	-- Read mail, drop it
	local smtp = SMTPSender.new(self)

	local from = (posix.getlogin() or "root").."@"..config.settings.bind.reply_host
	smtp.inline_data = {}
	for line in io.stdin:lines() do
		table.insert(smtp.inline_data, line)
	end

	local route_raw = {
		try=config.settings.sender.retries,
		from=from,
		rcpt={
		},
	}

	for i, addr in ipairs(arg) do
		local account, host = util.addressRouteStrip(addr)
		if account and host then
			table.insert(route_raw.rcpt, {account=account, host=host})
		end
	end
	if os.getenv("MAILTO") then
		for addr in os.getenv("MAILTO"):gmatch("([^,]+)") do
			local account, host = util.addressRouteStrip(addr)
			if account and host then
				table.insert(route_raw.rcpt, {account=account, host=host})
			end
		end
	end

	local route = {}
	for i, rcpt in ipairs(route_raw.rcpt) do
		route[rcpt.host] = route[rcpt.host] or {}
		table.insert(route[rcpt.host], rcpt.account.."@"..rcpt.host)
	end

	for host, data in pairs(route) do
		local thread = coroutine.create(function()
			local s = socket:tcp()
			local error_user = smtp:sendMail(s, mx, host, data, route_raw)

			for addr, reason in pairs(error_user) do
			end
		end)

		-- Register the thread and add a trap for errors
		self.scheduler:register(thread)
		self.scheduler.traps[thread] = function(self2, thread, success, errmsg)
			if not success and errmsg then self:logError("[lua-error] %s", errmsg) end
		end
	end

	return true
end

function Sendmail:start(...)
	local args = arg
	local thread = coroutine.create(function() self:thread(unpack(args)) end)
	self.scheduler:register(thread)
	self.scheduler.traps[thread] = function(self2, thread, success, errmsg)
		if not success and errmsg then self:logError("%s", errmsg) end
	end
	self.scheduler:run()
end

