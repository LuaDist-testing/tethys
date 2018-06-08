module(..., package.seeall)

local oo = require "loop.simple"
local Plugin = require 'tethys2.plugins.deposit.Plugin'
require'config'

new = oo.class({}, Plugin.class)
Log = new
class = new

function Log:deliverMail(to, state, params)
	for i, d in ipairs(state.data) do
		self.server:logDebug("[DEPOSIT LOG]"..d)
	end
end

function Log:finishDelivery(state)
	return nil
end

function Log:init(server)
	oo.superclass(Log).init(self, server)
	self.server:logDebug("[DEPOSIT LOG] Init...")
end
