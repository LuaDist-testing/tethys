module(..., package.seeall)

local oo = require "loop.simple"
require'config'

new = oo.class()
State = new
class = new

function State:clean()
	self.order = {}
	self.helo = nil
	self.from = nil
	self.to = {}
	self.data = {}
	self.__to_done = false
end

function State:setOrder(command)
	self.order[command] = true
end

function State:removeOrder(command)
	self.order[command] = nil
end

function State:requireOrder(...)
	for i, com in ipairs{...} do
		if not self.order[com] then return false end
	end
	return true
end

function State:setHelo(helo)
	self.helo = helo
end

function State:setFrom(from)
	self.from = from
	self:done()
end

function State:addData(data)
	table.insert(self.data, data)
end

function State:addTo(account, host, extra, orig_account, orig_host)
	local data = self.to[account.."@"..host]
	if not data then data = {} self.to[account.."@"..host] = data end

	data.account = account
	data.host = host
	data.extra = extra
	data.orig = data.orig or {}
	table.insert(data.orig, {account=orig_account, host=orig_host})

	self.__to_done = true
	self:done()
end

function State:done()
	if not self.from or not self.__to_done or #self.data == 0 then return end
	return true
end

function State:__init()
	local t = {
		to = {}, data = {}, order = {},
	}
	t = oo.rawnew(self, t)
	return t
end
