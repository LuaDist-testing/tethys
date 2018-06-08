module(..., package.seeall)

local oo = require "loop.simple"
require'config'

new = oo.class{}
Plugin = new
class = new

Plugin.LAST = 1
Plugin.MOVE = 2
Plugin.READ = 3
Plugin.DELETE = 4

function Plugin:__init()
	local t = {}
	t = oo.rawnew(self, t)
	return t
end

function Plugin:filterMessage(to, state, filtered)
end

function Plugin:init(server)
	self.server = server
end
