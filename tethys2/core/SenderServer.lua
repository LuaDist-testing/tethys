module(..., package.seeall)

local oo = require "loop.simple"
local Server = require'tethys2.core.Server'
local SMTPSender = require'tethys2.core.SMTPSender'
local fam = require('fam')
local scheduler = require('loop.thread.SocketScheduler')
require'posix'
require'lfs'
require'config'

new = oo.class({ server_type="sender" }, Server.class)
SenderServer = new
class = new

function SenderServer:thread()
	self:log("Tethys SMTP Sender starting..")
	self:daemonize()

	local maildir = config.settings.deposit.relay_maildir
	local fam_conn = fam.open()
	lfs.mkdir(maildir.."/.maildir/")
	lfs.mkdir(maildir.."/.maildir/new")
	lfs.mkdir(maildir.."/.maildir/retry")
	fam.monitorDirectory(fam_conn, maildir.."/.maildir/new/")
	self:log("Monitoring: %s/.maildir/new/", maildir)

	self:postInit()

	-- Handle FAM monitoring in a thread
	local FAMHandler = coroutine.create(function()
		while true do
			-- Process all new mails
			while fam.pendingEvent(fam_conn) > 0 do
				local evt = fam.nextEvent(fam_conn)
				if evt and (evt.code == "Created" or evt.code == "Exists") and evt.filename:sub(1, 5) ~= "info-" then
					local handler
					handler = coroutine.create(function()
						local smtp = SMTPSender.new(self, evt.path, evt.filename)
						smtp:handle()
					end)
					scheduler:register(handler)
					scheduler.traps[handler] = function(self2, thread, success, errmsg)
						if not success and errmsg then self:logError("[lua-error] %s", errmsg) end
					end
				end
			end
			scheduler:suspend(1)
		end
	end)
	scheduler:register(FAMHandler)
	scheduler.traps[FAMHandler] = function(self, thread, success, errmsg)
		if not success and errmsg then self:logError("%s", errmsg) end
	end

	-- Handle checking for retries in a thread
	local RetryHandler = coroutine.create(function()
		while true do
			-- Check for retry mails
			for f in lfs.dir(maildir.."/.maildir/retry/") do
				local i, j, name, date = f:find("^(.*)%-date(%d+)$")
				if i and tonumber(date) <= os.time() then
					posix.link(maildir.."/.maildir/retry/"..f, maildir.."/.maildir/new/"..name.."-date"..date)
					posix.unlink(maildir.."/.maildir/retry/"..f)
					posix.link(maildir.."/.maildir/retry/info-"..f, maildir.."/.maildir/new/info-"..name.."-date"..date)
					posix.unlink(maildir.."/.maildir/retry/info-"..f)
				end
			end
			scheduler:suspend(20)
		end
	end)
	scheduler:register(RetryHandler)
	scheduler.traps[RetryHandler] = function(self2, thread, success, errmsg)
		if not success and errmsg then self:logError("%s", errmsg) end
	end
end

function SenderServer:start()
	self.scheduler = scheduler
	scheduler:register(coroutine.create(function() self:thread() end))
	scheduler:run()
end
