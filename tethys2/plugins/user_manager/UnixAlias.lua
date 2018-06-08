module(..., package.seeall)

local oo = require "loop.simple"
local Plugin = require 'tethys2.plugins.user_manager.Plugin'
require'config'
require'io'

new = oo.class({}, Plugin.class)
UnixAlias = new
class = new

function UnixAlias:getUser(account, host)
	local hosts = config.settings.user_manager.unixalias.hosts
	if not hosts[host] then return nil end

	local aliases = {}
	for line in io.lines(config.settings.user_manager.unixalias.alias_file) do
		if not line:find("^#") and line:len() > 0 then
			local i, j, alias, dest = line:find("^([^:]+)%s*:%s*(.+)%s*$")
			if i then
				aliases[alias] = dest
			end
		end
	end
	while aliases[account] do
		if not aliases[account] then break end
		account = aliases[account]
	end

	for line in io.lines(config.settings.user_manager.unixalias.users_file) do
		if not line:find("^#") and line:len() > 0 then
			local i, j, user, uid, gid, home = line:find("^([^:]*):[^:]*:(%d*):(%d*):[^:]*:([^:]*):[^:]*$")
			if i and user == account then
				return {
					account=user,
					host=host,
					type='account',
					param={
						path = ("%s/#PATHEXT#"):format(home),
						uid = tonumber(uid),
						gid = tonumber(gid),
					}
				}
			end
		end
	end
	return nil
end

function UnixAlias:getRelayHost(host)
	-- Do we know this host?
	return config.settings.user_manager.unixalias.hosts[host]
end

function UnixAlias:authUser(account, host, pass)
	-- This module cant handle login
	return false
end

function UnixAlias:init(server)
	oo.superclass(UnixAlias).init(self, server)
end
