module(..., package.seeall)

local oo = require "loop.simple"
local Plugin = require 'tethys2.plugins.deposit.Plugin'
local Relaydir = require 'tethys2.util.Relaydir'
require'posix'
require'lfs'
require'config'

new = oo.class({}, Plugin.class)
Relay = new
class = new

function Relay:deliverMail(to, state, params)
	to.to_relay = true
end

function Relay:finishDelivery(state)
	local spool_path = config.settings.deposit.relay_maildir.."/.maildir/"
	local spool = Relaydir.new(spool_path)
	spool:checkRepository()

	local id = spool:relayMail(state)
end

function Relay:init(server)
	oo.superclass(Relay).init(self, server)
end
