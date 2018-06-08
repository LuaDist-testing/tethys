module(..., package.seeall)

local oo = require "loop.simple"
local Server = require'tethys2.core.Server'
local State = require'tethys2.core.State'
local Relay = require('tethys2.plugins.deposit.Relay')
local util = require('tethys2.util.util')
require'posix'
require'config'

new = oo.class({ server_type="sendmail" }, Server.class)
Sendmail = new
class = new

function Sendmail:start(...)
	-- Drop privilegdes but dont realy go daemon
	self:daemonize(true)
	self:postInit()

	-- Read mail, drop it
	local relay = Relay.new()
	relay:init(self)

	local state = State.new()
	state:setFrom((posix.getlogin() or "root").."@"..config.settings.bind.reply_host)
	for line in io.stdin:lines() do
		state:addData(line)
	end

	for i, addr in ipairs(arg) do
		local account, host = util.addressRouteStrip(addr)
		if account and host then
			state:addTo(account, host, nil, account, host)
			relay:deliverMail(state.to[account.."@"..host], state)
		end
	end

	relay:finishDelivery(state)
	return true
end
