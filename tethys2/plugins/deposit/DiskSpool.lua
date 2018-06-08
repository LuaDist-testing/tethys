module(..., package.seeall)

local oo = require "loop.simple"
local Plugin = require 'tethys2.plugins.deposit.Plugin'
local Filter = require 'tethys2.plugins.filter.Plugin'
require'posix'
require'lfs'
require'config'
local MailFormat = require(config.settings.deposit.spool_type or 'tethys2.util.Maildir')

new = oo.class({}, Plugin.class)
DiskSpool = new
class = new

function DiskSpool:deliverMail(to, state, params)
	to.filtered = to.filtered or {}
	local spool_path
	local uid, gid = nil, nil
	if not params then
		spool_path = config.settings.deposit.spool_path.."/"..to.host.."/"..to.account.."/"..MailFormat.class.path_ext
		-- Handle maildir++ for filtering
		if MailFormat.class.type == "maildir" then
			if to.filtered[Filter.class.MOVE] then spool_path = spool_path.."/."..to.filtered[Filter.class.MOVE] end
		end
	else
		local path = params
		if type(params) == "table" then
			uid = params.uid
			gid = params.gid
			path = params.path
		end
		spool_path = path:gsub("#PATHEXT#", MailFormat.class.path_ext)

		-- Handle maildir++ for filtering
		if MailFormat.class.type == "maildir" then
			if to.filtered[Filter.class.MOVE] then spool_path = spool_path.."/."..to.filtered[Filter.class.MOVE] end
		end
	end

	local spool = MailFormat.new(spool_path)
	if uid and gid then spool:setOwner(uid, gid) end
	spool:checkRepository()
	local id = spool:dropMail(state.from, state.data)

	-- Make it already read, if possible for the spool backend
	if to.filtered[Filter.class.READ] then spool:setRead(id) end
end

function DiskSpool:finishDelivery(state)
	return nil
end

function DiskSpool:init(server)
	oo.superclass(DiskSpool).init(self, server)
end
