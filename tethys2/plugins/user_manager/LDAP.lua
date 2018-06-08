module(..., package.seeall)

local oo = require "loop.simple"
local Plugin = require 'tethys2.plugins.user_manager.Plugin'
local LDAPConnect = require('tethys2.util.LDAP')
require'config'

new = oo.class({}, Plugin.class)
LDAP = new
class = new

function class:getUser(account, host, default_con)
	local user = account.."@"..host
	local con = default_con or LDAPConnect.new(config.settings.user_manager.ldap)
	local data = nil

	-- If we have a people dn, try there first
	if config.settings.user_manager.ldap.people_dn then
		for dn, row in con:search{base=config.settings.user_manager.ldap.people_dn, filter=("(|(mail=%s))"):format(con:quote(user))} do
			local params = ''
			if row.mailParams then params = table.concat(con:oneOrMany(row.mailParams), ',') end
			data = { account=account, host=host, type=row.mailType or 'account', param=params, pass=row.userPassword }
			break -- Only take the first
		end
	end

	-- No such account here, let's try for the non-real people accounts, if allowed
	if config.settings.user_manager.ldap.accounts_dn and not data then
		for dn, row in con:search{base=config.settings.user_manager.ldap.accounts_dn, filter=("(|(mail=%s))"):format(con:quote(user))} do
			local params = con:oneOrMany(row.mailParams)
			data = { account=account, host=host, type=row.mailType, param=table.concat(params, ','), pass=row.userPassword }
			break -- Only take the first
		end
	end

	-- No such account here, let's try for the host default account, if allowed
	if config.settings.user_manager.ldap.hosts_dn and not data and host then
		for dn, row in con:search{base=config.settings.user_manager.ldap.hosts_dn, filter=("(|(mail=%s)(mailType=account))"):format(con:quote(host))} do
			if row.mailType and row.mailType == "account" then
				-- Recursively get that acount
				local i, j, acc, hst = row.mailParams:find("^(.*)@(.*)$")
				if acc and hst then
					data = self:getUser(acc, hst, con)
				end
				break -- Only take the first
			end
		end
	end

	if not default_con then con:close() end
	return data
end

function class:getRelayHost(host)
	local data = nil
	local con = LDAPConnect.new(config.settings.user_manager.ldap)
	if config.settings.user_manager.ldap.hosts_dn then
		for dn, row in con:search{base=config.settings.user_manager.ldap.hosts_dn, filter=("(|(mail=%s))"):format(con:quote(host))} do
			data = { host=host }
		end
	else
		-- If no hosts_dn is given, accept all hosts
		data = { host = host }
	end
	con:close()
	return data
end

function class:authUser(account, host, pass)
	-- No auth bind DN given, we can not try to bind!
	if not config.settings.user_manager.ldap.auth_bind_dn then return false end

	local user_dn = config.settings.user_manager.ldap.auth_bind_dn:gsub("%%u", account):gsub("%%d", host)
	local con = LDAPConnect.new{host=config.settings.user_manager.ldap.host, user=user_dn, pass=pass}
	if con then
		for dn, row in con:search{base=user_dn, scope="base"} do
			-- Ok we found it!
			return true
		end
		con:close()
	end
	return false
end

function class:init(server)
	oo.superclass(class).init(self, server)
end

function class:initPlugin(server)
	self.server = server
--	con = SQL.new(config.settings.user_manager.mysql)
end
