module(..., package.seeall)

local oo = require "loop.simple"
local Server = require'tethys2.core.Server'
local SMTPReceiver = require'tethys2.core.SMTPReceiver'
local scheduler = require('loop.thread.SocketScheduler')
local socket    = scheduler.socket
require'config'

new = oo.class({ server_type="receiver" }, Server.class)
ReceiverServer = new
class = new

function ReceiverServer:thread()
	self:log("Tethys SMTP Receiver starting..")

	-- Create the socket BEFORE dropping priviledges, as we probably will run on port 25 which requires root
	self.server_sock = socket:bind(config.settings.bind.host, config.settings.bind.port)

	self:postInit()
	self:daemonize()

	local errmsg
	repeat
		local channel
		channel, errmsg = self.server_sock:accept()
		if channel then
			local handler = coroutine.create(function()
				local smtp = SMTPReceiver.new(self, channel)
				smtp:handle()
			end)
			scheduler:register(handler)
			scheduler.traps[handler] = function(self2, thread, success, errmsg)
				if not success and errmsg then self:logError("[lua-error] %s", errmsg) end
				channel.__object:close()
			end
		end
	until errmsg
	self.server_sock:close()
end


function ReceiverServer:start()
	self.scheduler = scheduler
	scheduler:register(coroutine.create(function() self:thread() end))
	scheduler:run()
end
