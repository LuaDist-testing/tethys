module(..., package.seeall)

local oo = require "loop.simple"
local scheduler = require('loop.thread.SocketScheduler')
require'config'
require'logging.syslog'
require'logging.console'
require'posix'
require'daemon'

new = oo.class{ server_type="global" }
Server = new
class = new

function Server:log(str, ...)
	if config.settings.log.level < 2 then return end
	str = str:format(...)
	self._log:info(str)
end

function Server:logError(str, ...)
	if config.settings.log.level < 1 then return end
	str = str:format(...)
	self._log:error(str)
end

function Server:logDebug(str, ...)
	if config.settings.log.level < 3 then return end
	str = str:format(...)
	self._log:debug(str)
end

function Server:daemonize(no_daemon)
	if config.settings.daemon.daemonize and not no_daemon then
		daemon.daemonize()

		local pid_file = io.open(config.settings.daemon.pid_file:format(self.server_type), "w")
		pid_file:write(tostring(posix.getprocessid().pid), "\n")
		pid_file:close()
	end

	-- Drop privileges if needed
	if config.settings.bind.uid and type(config.settings.bind.uid) == "number" then
		posix.setuid(config.settings.bind.uid)
	end
	if config.settings.bind.gid and type(config.settings.bind.gid) == "number" then
		posix.setgid(config.settings.bind.gid)
	end
end

function Server:__init()
	local t = {}
	t = oo.rawnew(self, t)

	t.scheduler = scheduler

	if config.settings.daemon.daemonize then
		self.log_prefix = "tethys2-smtp-"..self.server_type
		t._log = logging.syslog(self.log_prefix, lsyslog.FACILITY_MAIL)
	else
		t._log = logging.console()
	end

	t.user_manager = require(config.settings.user_manager.plugin).new()
	t.user_manager:init(t)
	t.deposit = require(config.settings.deposit.plugin).new()
	t.deposit:init(t)
	if type(config.settings.filter.plugin) == "string" then config.settings.filter.plugin = { config.settings.filter.plugin } end
	t.filters = {}
	for i, p in pairs(config.settings.filter.plugin) do
		local filter = require(p).new()
		filter:init(t)
		table.insert(t.filters, filter)
	end
	t.smtp_plugins = {}
	if config.settings.smtp.plugin then
		if type(config.settings.smtp.plugin) == "string" then config.settings.smtp.plugin = { config.settings.smtp.plugin } end
		for i, p in ipairs(config.settings.smtp.plugin) do
			local plug = require(p).new()
			plug:init(t)
			table.insert(t.smtp_plugins, plug)
		end
	end

	return t
end

function Server:postInit()
	for type, plugins in pairs(config.settings.preload.plugins) do
		if type == self.server_type then
			for i, plugin in ipairs(plugins) do
				local p = require(plugin)
				p.class:initPlugin(self)
			end
		end
	end
end
