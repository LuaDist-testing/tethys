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

function Plugin:deliverMail(to, state, params)
	return nil
end

function Plugin:finishDelivery(state)
	return nil
end

function Plugin:init(server)
	self.server = server
end
