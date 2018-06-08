local base = _G
local mysql = require("luasql.mysql")
local oo = require "loop.simple"
local string = require "string"

module(...)

SQL = oo.class({})
new = SQL
class = SQL

function SQL:__init(tbl)
	if not tbl then return end
	local obj = { con_info = tbl }
	obj.env = mysql:mysql()
	if not obj.env then return end
	obj.con = obj.env:connect(tbl.base, tbl.user, tbl.pass, tbl.host)
	if not obj.con then return end

	return oo.rawnew(self, obj)
end

function SQL:execute(sql, ...)
	sql = sql:format(...)
	local res, err

	if self.con then
		res, err = self.con:execute(sql)
	else
		err = "SQL Module: server has gone away"
	end
	if err and err:find("server has gone away") then
		self.con = self.env:connect(self.con_info.base, self.con_info.user, self.con_info.pass, self.con_info.host)
		if self.con then
			return self.con:execute(sql)
		end
	end
	return res, err
end

function SQL:close()
	self.con:close()
	self.env:close()
end

function SQL:__gc()
	self:close()
end

function SQL:quote(str)
	if str then
		return "'" .. string.gsub(string.gsub(str, "(')", "''"), "(\\)", "\\\\") .. "'"
	else
		return "NULL"
	end
end

function SQL:lastId()
	local cur = self:execute("SELECT LAST_INSERT_ID()")
	if not cur then return nil end
	local row = cur:fetch ({}, "n")
	local id = nil
	if row then id = base.tonumber(row[1]) end
	cur:close()
	return id
end

function SQL:selectOneRow(sql)
	local cur = self:execute(sql)
	if not cur then return nil end
	local row = cur:fetch ({}, "a")
	cur:close()
	return row
end

function SQL:loadTables(schemas)
	local ret = {}
	for name, sql in base.pairs(schemas) do
		local cur = self:execute("SHOW TABLES LIKE '"..name.."'")
		local create = true
		if cur then
			if cur:fetch({},"a") then cur:close() create = false end
			cur:close()
		end

		if create then
			self:execute(sql)
			ret[name] = true
		end
	end
	return ret
end
