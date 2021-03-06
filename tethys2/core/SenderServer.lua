module(..., package.seeall)

local oo = require "loop.simple"
local Relaydir = require'tethys2.util.Relaydir'
local Server = require'tethys2.core.Server'
local SMTPSender = require'tethys2.core.SMTPSender'
local fam = require('fam')
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
	local rdir = Relaydir.new(maildir.."/.maildir")
	rdir:checkRepository()

	local fam_conn = fam.open()
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
					self.scheduler:register(handler)
					self.scheduler.traps[handler] = function(self2, thread, success, errmsg)
						if not success and errmsg then self:logError("[lua-error] %s", errmsg) end
					end
				end
			end
			self.scheduler:suspend(1)
		end
	end)
	self.scheduler:register(FAMHandler)
	self.scheduler.traps[FAMHandler] = function(self2, thread, success, errmsg)
		if not success and errmsg then self2:logError("%s", errmsg) end
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
			self.scheduler:suspend(20)
		end
	end)
	self.scheduler:register(RetryHandler)
	self.scheduler.traps[RetryHandler] = function(self2, thread, success, errmsg)
		if not success and errmsg then self:logError("%s", errmsg) end
	end
end

function SenderServer:start()
	local thread = coroutine.create(function() self:thread() end)
	self.scheduler:register(thread)
	self.scheduler.traps[thread] = function(self2, thread, success, errmsg)
		if not success and errmsg then self:logError("%s", errmsg) end
	end
	self.scheduler:run()
end
