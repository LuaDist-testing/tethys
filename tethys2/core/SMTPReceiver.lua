module(..., package.seeall)

local oo = require "loop.simple"
local State = require'tethys2.core.State'
local util = require'tethys2.util.util'
local Filter = require'tethys2.plugins.filter.Plugin'
local mime = require('mime')
require'config'

new = oo.class()
SMTPReceiver = new
class = new

SMTPReceiver.codes =
{
	HELO = 		"220 %s\r\n",
	OK = 		"250 %s\r\n",
	EHLO_REPLY = 	"250-%s\r\n",
	QUIT = 		"221 %s\r\n",
	DATA_OK = 	"354 %s\r\n",
	BAD_COMMAND = 	"500 %s\r\n",
	BAD_SEQUENCE = 	"503 %s\r\n",
	BAD_AUTH = 	"504 %s\r\n",
	BAD_USER = 	"550 %s\r\n",

	AUTH_CONTINUE = "334 %s\r\n",
	AUTH_OK = 	"334 %s\r\n",
	AUTH_KO = 	"535 %s\r\n",
	AUTH_ERROR = 	"501 %s\r\n",
}

function SMTPReceiver:getCode(c, str)
	return string.format(c, str)
end
function SMTPReceiver:sendStatus(code, txt)
	local str = self:getCode(code, txt)
	self.server:logDebug(">>%s", str)
	self.socket:send(str)
end

-- Resolve account@host until it finds something that is not an alias
function SMTPReceiver:resolveAccount(account, host)
	local data = self.server.user_manager:getUser(account, host)
	if not data then
		-- If we are allowed to relay mail, and the mail is not from one of our domains, do relay
		-- If it is for our domain but we have no account, we reject it
		if self.allowRelay and not self.server.user_manager:getRelayHost(host) then
			data = { account=account, host=host, allow_relay=true }
			return { data }
		else
			self:sendStatus(self.codes.BAD_USER, "Unknown user")
			return nil
		end
	end
	if data.type == "alias" then
		local ret = {}
		for addr in data.param:gmatch("([^,]+@[^,]+)") do
			local naccount, nhost = util.addressRouteStrip(addr)
			if naccount and nhost then
				self.server:log("[ALIAS RESOLVER] %s@%s => %s@%s", account, host, naccount, nhost)
				local tmp = self:resolveAccount(naccount, nhost)
				if tmp then
					for i, d in ipairs(tmp) do table.insert(ret, d) end
				end
			end
		end
		if #ret == 0 then
			self:sendStatus(self.codes.BAD_USER, "Unknown user in alias table")
			return nil
		else
			return ret
		end
	elseif data.type == "forward" then
		-- Forbid forward to local domains(use aliases instead)
		local faccount, fhost = util.addressRouteStrip(data.param)
		if not self.server.user_manager:getRelayHost(fhost) then
			data = { account=faccount, host=fhost, allow_relay=true }
			return { data }
		else
			self:sendStatus(self.codes.BAD_USER, "User configured as forward to local domain, bad admin!")
			return nil
		end
	end
	return { data }
end

function SMTPReceiver:filterState(to)
	local filtered = {}
	for i, filter in ipairs(self.server.filters) do
		filter:filterMessage(to, self.state, filtered)
		if filtered[Filter.class.LAST] then break end
	end
	to.filtered = filtered
end

function SMTPReceiver:finishState()
	table.insert(self.state.data, 1, string.format("Received: from %s by %s (Tethys SMTP) ; %s", tostring(self.state.helo), config.settings.bind.reply_host, os.date("%d %b %Y %H:%M:%S %z")))

	local used_deposits = {}
	local loaded_deposits = {}
	for i, to in pairs(self.state.to) do
		self:filterState(to)

		-- Only deliver it if it was not deleted by the filter
		if not to.filtered[Filter.class.DELETE] then
			if to.extra and to.extra.deposit then
				local depositclass = require(to.extra.deposit)

				local deposit = loaded_deposits[to.extra.deposit]
				if not deposit then
					deposit = depositclass.new()
					deposit:init(self.server)
				end

				deposit:deliverMail(to, self.state, to.extra and to.extra.params)
				used_deposits[deposit] = true
			else
				self.server.deposit:deliverMail(to, self.state, to.extra and to.extra.params)
				used_deposits[server.deposit] = true
			end
		end
	end
	for deposit, _ in pairs(used_deposits) do
		deposit:finishDelivery(self.state)
	end

	-- Real local users can save their outgoing mails if they want
	if self.state:requireOrder("AUTH") and self.state.auth and self.state.auth.account and self.state.auth.host then
		-- Add the special header
		table.insert(self.state.data, 1, "x-tethys-copy-send: true")

		local to = { account=self.state.auth.account, host=self.state.auth.host }
		self:filterState(to)

		-- Only bother if we move it somewhere(we do not want to polute the user's inbox with outgoing mails)
		if to.filtered[Filter.class.MOVE] then
			self.server.deposit:deliverMail(to, self.state)
			self.server.deposit:finishDelivery(self.state)
		end
	end
end

function SMTPReceiver:handleNOOP(params)
	self:sendStatus(self.codes.OK, "OK")
end

function SMTPReceiver:handleHELO(params)
	self.state:setHelo(params)
	self:sendStatus(self.codes.OK, config.settings.bind.reply_host.." SMTP")
	self.state:setOrder("HELO")
end

function SMTPReceiver:handleEHLO(params)
	self.state:setHelo(params)
	self:sendStatus(self.codes.EHLO_REPLY, config.settings.bind.reply_host.." SMTP")
	self:sendStatus(self.codes.OK, "AUTH LOGIN")
	self.state:setOrder("HELO")
end

function SMTPReceiver:handleAUTH(params)
	-- Check commands sequence
	if not self.state:requireOrder("HELO") or self.state:requireOrder("AUTH") then
		self:sendStatus(self.codes.BAD_SEQUENCE, "Bad command sequence")
		return
	end
	local user, pass

	if params:upper() == "LOGIN" then
		self:sendStatus(self.codes.AUTH_CONTINUE, "VXNlcm5hbWU6")
		local line = self.socket:receive()
		if not line then return end
		user = mime.unb64(line)
		self:sendStatus(self.codes.AUTH_CONTINUE, "UGFzc3dvcmQ6")
		local line = self.socket:receive()
		if not line then return end
		pass = mime.unb64(line)
--[[	elseif params:upper() == "PLAIN" then
		state.sendStatus(s, codes.AUTH_CONTINUE, "")
		local line = s:receive()
		if not line then return end
		local i, j
		i, j, user, pass = line:find("^%z([^%z]+)%z([^%z]+)$")
		if user and pass then
			user = mime.unb64(user)
			pass = mime.unb64(pass)
		else
			state.sendStatus(s, codes.AUTH_ERROR, "Cannot decode auth parameter")
		end
]]	else
		self:sendStatus(self.codes.BAD_AUTH, "AUTH mechanism not available")
		return
	end

	local account, host = util.addressRouteStrip(user)
	if account and host and pass and self.server.user_manager:authUser(account, host, pass) then
		self.allowRelay = true
		self.state.user = user
		self:sendStatus(self.codes.AUTH_OK, "Welcome "..user)
		self.state:setOrder("AUTH")
		self.state.auth = {account=account, host=host}
	else
		self:sendStatus(self.codes.AUTH_KO, "Wrong auth")
	end
end

function SMTPReceiver:handleMAIL(params)
	-- Check commands sequence
	if not self.state:requireOrder("HELO") then
		self:sendStatus(self.codes.BAD_SEQUENCE, "Bad command sequence")
		return
	end
	self.state:setOrder("MAIL")

	-- Parse arguments
	if not string.find(params:upper(), "^FROM:") then
		self:sendStatus(self.codes.BAD_COMMAND, "Bad from syntax: "..params)
		return
	end
	local i, j, from = string.find(params, ": *<(.*)> *$")
	if i and j and from and (from == "" or util.addressRouteStrip(from)) then
		self.state:setFrom(from)
		self:sendStatus(self.codes.OK, "OK")
	else
		self:sendStatus(self.codes.BAD_COMMAND, "Bad from syntax: "..params)
	end
end

function SMTPReceiver:handleRCPT(params)
	-- Check commands sequence
	if not self.state:requireOrder("MAIL") then
		self:sendStatus(self.codes.BAD_SEQUENCE, "Bad command sequence")
		return
	end

	-- Parse arguments
	if not string.find(params:upper(), "^TO:") then
		self:sendStatus(self.codes.BAD_COMMAND, "Bad to syntax: "..params)
		return
	end
	local i, j, addr = string.find(params, ": *<(.*)> *$")
	if i and j and addr then
		-- Grab account and host
		local account, host = util.addressRouteStrip(addr)
		if not account or not host then
			self:sendStatus(self.codes.BAD_COMMAND, "Bad to syntax")
			return
		end
		-- Check that the user is allowed here
		local mdata = self:resolveAccount(account, host)
		if mdata then
			for i, data in ipairs(mdata) do
				-- Special deposit plugin for this account
				if data.type == "deposit" then
					i, j, deposit, depo_param = data.param:find("([^:]*):(.*)")
					if deposit then
						if depo_param == "" then depo_param = nil end
						self.state:addTo(data.account, data.host, { deposit=deposit, params=depo_param }, account, host)
					else
						self.server.logError("Unknown user in deposit table: "..data.param)
					end
				else
					-- Normal account
					local extra = nil
					-- If we must relay to an other server, change the deposit plugin on the fly to the relay deposit
					if data.allow_relay then extra = { deposit="tethys2.plugins.deposit.Relay", params=config.settings.deposit.relay_maildir }
					else extra = { params = data.param } end
					self.state:addTo(data.account, data.host, extra, account, host)
				end
			end
			self.state:setOrder("RCPT")
			self:sendStatus(self.codes.OK, "OK")
		end
	else
		self:sendStatus(self.codes.BAD_COMMAND, "Bad to syntax")
	end
end

function SMTPReceiver:handleDATA(params)
	if not self.state:requireOrder("RCPT") then
		self:sendStatus(self.codes.BAD_SEQUENCE, "Bad command sequence")
		return
	end
	self.state:setOrder("DATA")
	self:sendStatus(self.codes.DATA_OK, "go ahead")
	local size = 0
	while true do
		local line = self.socket:receive()
		self.server:logDebug("<<%s", tostring(line))
		if not line then
			self.state:clean()
			return true
		end
		if line == "." then
			break
		elseif line:find("^%..") then
			line = line:sub(2)
		end
		size = line:len()
		if size > config.settings.max_data_size then
			self.state.data = {}
			self.state:removeOrder("DATA")
			self:sendStatus(self.codes.BAD_COMMAND, "DATA too large.")
			return
		end
		self.state:addData(line)
	end
	if self.state:done() then
		table.insert(self.states_to_process, self.state)

		-- Reset the state, send OK status
		self:handleRSET()
	else
		self:sendStatus(self.codes.OK, "OK")
	end
end

function SMTPReceiver:handleRSET(params)
	local ishelo = self.state:requireOrder("HELO")
	self.state = State.new()
	if ishelo then self.state:setOrder("HELO") end
	self:sendStatus(self.codes.OK, "OK")
end

function SMTPReceiver:handleQUIT(params)
	self:sendStatus(self.codes.QUIT, config.settings.bind.reply_host.." Tethys SMTP is done with you")
	return true
end

function SMTPReceiver:handle()
	self.state = State.new()

	self.allowRelay = false
	local dhost = self.socket:getpeername()
	if config.settings.relay.allow_ip[dhost] then
		self.allowRelay = true
		self.server:log("Connection from %s, relaying allowed", dhost)
	end

	self:sendStatus(self.codes.HELO, config.settings.bind.reply_host.." Tethys SMTP is watching you...")
	while true do
		local line = self.socket:receive()
		if not line then break end
		self.server:logDebug("<<%s", line)
		local com = line:sub(1, 4):upper()
		local params = line:sub(6)
		if com ~= "" then
			if self["handle"..com] then
				if self["handle"..com](self, params) then break end
			else
				self:sendStatus(self.codes.BAD_COMMAND, "Unknown command")
			end
		end
	end
	self.server:log("Connection from %s ended", dhost)

	-- Now we can process filters, as this can take time
	for i, state in ipairs(self.states_to_process) do
		self.state = state
		self:finishState()
	end

	collectgarbage("collect")
end

function SMTPReceiver:__init(server, socket)
	local t = {}
	t.server = server
	t.socket = socket
	t.states_to_process = {}

	t = oo.rawnew(self, t)
	return t
end
