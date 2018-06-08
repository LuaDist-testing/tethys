module(..., package.seeall)

local oo = require "loop.simple"
local Plugin = require 'tethys2.plugins.filter.Plugin'
require'config'
require'lpc'

new = oo.class({}, Plugin.class)
SpamAssassin = new
class = new

function SpamAssassin:filterMessage(to, state, filtered)
	local pid, fin, fout = lpc.run("spamc")

	self.server:logDebug("SpamAssassin runnning...")

	-- Send the data to spam assassin
	for i, line in ipairs(state.data) do fin:write(line) fin:write("\r\n") end
	fin:flush()
	fin:close()

	-- Read the spam assassin response
	state.data = {}
	for line in fout:lines() do
		if line then state:addData(line) end
	end
	fout:close()

	lpc.wait(pid)

	self.server:logDebug("SpamAssassin done!")
end

function SpamAssassin:init(server)
	oo.superclass(SpamAssassin).init(self, server)
end
