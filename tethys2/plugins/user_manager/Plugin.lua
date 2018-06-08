module(..., package.seeall)

local oo = require "loop.simple"
require'config'

new = oo.class{}
Plugin = new
class = new

function Plugin:__init()
	local t = {}
	t = oo.rawnew(self, t)
	return t
end

function Plugin:getUser(account, host)
	return nil
end

function Plugin:getRelayHost(host)
	return nil
end

function Plugin:authUser(account, host, pass)
	return nil
end

function Plugin:init(server)
	self.server = server
end
