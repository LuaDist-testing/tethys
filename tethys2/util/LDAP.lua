local base = _G
local lualdap = require("lualdap")
local oo = require "loop.simple"
local table = require "table"
local config = require "config"
local string = require "string"

module(...)

LDAP = oo.class({})
new = LDAP
class = LDAP

function LDAP:__init(t)
	local obj = {}
	obj.ld = lualdap.open_simple(t.host, t.user, t.pass)
	if not obj.ld then return end

	return oo.rawnew(self, obj)
end

function LDAP:search(q, convert)
--	local res = {}
--	self:printTable(res, q)
--	self:log(table.concat(res))
	q.scope = q.scope or "onelevel"
	return self.ld:search(q)
end

function LDAP:add(dn, q)
--	self:log(sql)
	return self.ld:add(dn, q)
end

function LDAP:modify(dn, ...)
--	self:log(sql)
	return self.ld:modify(dn, base.unpack(arg))
end

function LDAP:delete(dn, ...)
--	self:log(sql)
	return self.ld:delete(dn, base.unpack(arg))
end

function LDAP:close()
	self.ld:close()
end

function LDAP:__gc()
	self:close()
end

function LDAP:oneOrMany(elem)
	if base.type(elem) ~= "table" then elem = { elem } end
	return elem
end

function LDAP:quote(str)
	return str
end
