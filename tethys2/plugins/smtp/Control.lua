module(..., package.seeall)

local oo = require "loop.simple"
local Plugin = require "tethys2.plugins.smtp.Plugin"
require'config'

new = oo.class({}, Plugin.class)
Control = new
class = new

function Control:__init()
	local t = {}
	t = oo.rawnew(self, t)
	return t
end

function Control:handleCTRL(handler, params)
	-- Only to people we trust a bit
	if not handler.allowRelay then
		handler:sendStatus(handler.codes.BAD_COMMAND, "Unknown command")
		return
	end

	params = params:upper()
	if params == "THRD" then
		local now = os.time()
		handler.socket:send(("* %d threads alive\n"):format(self.server.nb_threads))
		for chan, time in pairs(self.server.channels) do
			handler.socket:send((" * %s alive since %s(%d seconds ago), from %s\n"):format(tostring(chan), os.date("%Y-%m-%d %H:%M:%S", time), now - time, tostring(chan:getpeername())))
		end
		handler:sendStatus(handler.codes.OK, "Threads done")
	elseif params == "IP__" then
		for ip, nb in pairs(self.server.by_ips) do
			handler.socket:send((" * %s at %d connections\n"):format(tostring(ip), nb))
		end
		handler:sendStatus(handler.codes.OK, "IPs done")
	else
		handler:sendStatus(handler.codes.BAD_COMMAND, "Unknown command")
	end
end

function Control:handleCommand(handler, command, params)
	if self["handle"..command] then
		if self["handle"..command](self, handler, params) then return true else return false end
	end
	return nil
end

function Control:init(server)
	self.server = server
end
