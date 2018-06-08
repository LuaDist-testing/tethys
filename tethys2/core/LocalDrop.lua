module(..., package.seeall)

local oo = require "loop.simple"
local Server = require'tethys2.core.Server'
local State = require'tethys2.core.State'
local Filter = require'tethys2.plugins.filter.Plugin'
require'config'

new = oo.class({ server_type="localdrop" }, Server.class)
LocalDrop = new
class = new

function LocalDrop:thread(account, host)
	-- Drop privilegdes but dont realy go daemon
	self:daemonize(true)
	self:postInit()

	-- Read mail, drop it
	local state = State.new()
	state:addTo(account, host, nil, account, host)
	state:setFrom(nil)
	for line in io.stdin:lines() do
		state:addData(line)
	end

	local filtered = {}
	for i, filter in ipairs(self.filters) do
		filter:filterMessage(state.to[account.."@"..host], state, filtered)
		if filtered[Filter.class.LAST] then break end
	end
	state.to[account.."@"..host].filtered = filtered
	self:log("Dropping mail on: %s@%s", account, host)

	self.deposit:deliverMail(state.to[account.."@"..host], state)
	self.deposit:finishDelivery(state)
end

function LocalDrop:start(account, host)
	local thread = coroutine.create(function() self:thread(account, host) end)
	self.scheduler:register(thread)
	self.scheduler.traps[thread] = function(self2, thread, success, errmsg)
		if not success and errmsg then self:logError("%s", errmsg) end
	end
	self.scheduler:run()
end

