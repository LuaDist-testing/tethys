module(..., package.seeall)

local oo = require "loop.simple"
local Plugin = require 'tethys2.plugins.filter.Plugin'
local SQL = require 'tethys2.util.SQL'
require'config'

new = oo.class({}, Plugin.class)
MySQL = new
class = new

MySQL.schemas =
{
	tDropFilter = [[
CREATE TABLE tDropFilter (
        dft_i_id        INT UNSIGNED NOT NULL AUTO_INCREMENT,

        acc_s_name      VARCHAR(64) NOT NULL,
        acc_s_host      VARCHAR(100) NOT NULL,

        dft_i_order     INT NOT NULL DEFAULT 0,

        dft_e_type      ENUM('header', 'notheader', 'lua') NOT NULL DEFAULT 'header',
        dft_s_param     TEXT NOT NULL,

        dft_ee_result   SET('move','drop','read','last') NOT NULL DEFAULT 'move',
        dft_s_dest      VARCHAR(255),

        PRIMARY KEY     (dft_i_id),
        KEY             (acc_s_name, acc_s_host),
        KEY             (dft_i_order)
);
	]],
}

function MySQL:filterMessage(to, state, filtered)
	if not self.rules[to.host] then return {} end
	if not self.rules[to.host][to.account] then return {} end
	for i, rule in ipairs(self.rules[to.host][to.account]) do
		if rule.match(state) then
			self.server:logDebug("Rule matched: %s", rule.desc)

			for j, effect in ipairs(rule.effect) do
				effect(state, filtered)
			end
			return
		end
	end
	return
end

function MySQL:makeRule(row)
	local rule = {}

	rule.desc = "["..row.dft_e_type.."]: "..row.dft_s_param

	-- Message matchers
	if row.dft_e_type == "header" then
		local i, j, header, match = row.dft_s_param:find("^([^:]+):(.*)$")
		if header and match then
			header = "^"..header..":"
--			self.server:logDebug("Making rule: header[%s] ?=? %s", header, match)
			rule.match = function(state)
				for i, line in ipairs(state.data) do
					line = line:lower()
					if line == "" then break end
					if line:find(header) then
						if line:find(match, 1, 1) then return true end
					end
				end
				return false
			end
		else
			return nil, "Wrong header rule: "..row.dft_s_param
		end
	elseif row.dft_e_type == "notheader" then
		local i, j, header, match = row.dft_s_param:find("^([^:]+):(.*)$")
		if header and match then
			header = "^"..header..":"
--			log:debug(("Making rule: header[%s] ?=? %s"):format(header, match))
			rule.match = function(state)
				for i, line in ipairs(state.data) do
					line = line:lower()
					if line == "" then break end
					if line:find(header) and line:find(match, 1, 1) then return false end
				end
				return true
			end
		else
			return nil, "Wrong notheader rule: "..row.dft_s_param
		end
	elseif row.dft_e_type == "lua" then
		local fct = loadstring(row.dft_s_param)
		if fct then
--			log:debug("Making rule: lua")
			rule.match = fct
		else
			return nil, "Wrong lua rule: "..row.dft_s_param
		end
	end

	-- Message effects
	rule.effect = {}
	if row.dft_ee_result:find("move") then
		table.insert(rule.effect, function(state, params)
			params[self.MOVE] = row.dft_s_dest
		end)
	end
	if row.dft_ee_result:find("drop") then
		table.insert(rule.effect, function(state, params)
			params[self.DELETE] = true
		end)
	end
	if row.dft_ee_result:find("read") then
		table.insert(rule.effect, function(state, params)
			params[self.READ] = true
		end)
	end
	if row.dft_ee_result:find("last") then
		table.insert(rule.effect, function(state, params)
			params[self.LAST] = true
		end)
	end

	return rule
end


function MySQL:init(server)
	oo.superclass(MySQL).init(self, server)

	local con = SQL.new(config.settings.filter.mysql)
	con:loadTables(self.schemas)

	self.rules = {}
	local cur = con:execute("SELECT * FROM tDropFilter ORDER BY acc_s_host,acc_s_name,dft_i_order")
	local row = cur:fetch ({}, "a")
	while row do
		local rule = self:makeRule(row)

		if rule.match and rule.effect then
			self.rules[row.acc_s_host] = self.rules[row.acc_s_host] or {}
			self.rules[row.acc_s_host][row.acc_s_name] = self.rules[row.acc_s_host][row.acc_s_name] or {}
			table.insert(self.rules[row.acc_s_host][row.acc_s_name], rule)
		end

		row = cur:fetch ({}, "a")
	end

	con:close()
end
