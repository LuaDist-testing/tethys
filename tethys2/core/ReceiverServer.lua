module(..., package.seeall)

local oo = require "loop.simple"
local Server = require'tethys2.core.Server'
local SMTPReceiver = require'tethys2.core.SMTPReceiver'
local socket = require 'socket'
require'lpc'
require'posix'
require'copas'
require'config'

new = oo.class({ server_type="receiver" }, Server.class)
ReceiverServer = new
class = new

-- Handle the server as a single process with lua coroutines (using copas)
function ReceiverServer:coroutine()
	self:log("Tethys SMTP Receiver starting(coroutine mode)..")

	-- Create the socket BEFORE dropping priviledges, as we probably will run on port 25 which requires root
	self.server_sock = socket.bind(config.settings.bind.host, config.settings.bind.port)
	self.server_sock:settimeout(1)

	self:postInit()
	self:daemonize()

	local errmsg
	self.nb_threads = 0
	self.channels = {}
	self.by_ips = {}
	local serv_handler = function(channel)
--[[
		-- Close really old ones
		if config.settings.socket_timeout then
			for chan, time in pairs(self.channels) do
				local old = os.time() - time
				self:logDebug("Channel %s is %d seconds old..", tostring(chan), old)
				if old > config.settings.socket_timeout then
					self:logDebug("Killing channel %s : %d seconds old", tostring(chan), old)
					chan:close()
				end
			end
		end
]]
		-- Handle whatever we got
		if channel then
			-- Do we allow it to connect ?
			local can_continue = false
			local ip = channel:getpeername()
			if ip then
				self.by_ips[ip] = self.by_ips[ip] or 0
				if config.settings.max_threads and self.nb_threads >= config.settings.max_threads then
					self:logDebug("Refused connection from %s because it we have too many global connections.", ip, self.by_ips[ip])
				elseif not config.settings.max_connections_from_ip or self.by_ips[ip] < config.settings.max_connections_from_ip then
					can_continue = true
					self.by_ips[ip] = self.by_ips[ip] + 1
				else
					self:logDebug("Refused connection from %s because it already has %d connections.", ip, self.by_ips[ip])
				end
			end

			if can_continue then
				local copas_channel = copas.wrap(channel)
				copas_channel:settimeout(1)

				copas.setErrorHandler(function(self2, thread, success, errmsg)
				self:logError(self2, thread, success, errmsg)
					if not success and errmsg then self:logError("[lua-error] %s", errmsg) end
					channel:close()

					self.channels[channel] = nil
					self.by_ips[ip] = self.by_ips[ip] - 1
					if self.by_ips[ip] <= 0 then self.by_ips[ip] = nil end
					self.nb_threads = self.nb_threads - 1
					self:logDebug("One less thread in the world: %d // %s", self.nb_threads, tostring(channel))
				end)

				self.nb_threads = self.nb_threads + 1
				self.channels[channel] = os.time()
				self:logDebug("One more thread in the world: %d // %s", self.nb_threads, tostring(channel))
				local smtp = SMTPReceiver.new(self, copas_channel, channel)
				smtp:handle()

				self.channels[channel] = nil
				self.by_ips[ip] = self.by_ips[ip] - 1
				if self.by_ips[ip] <= 0 then self.by_ips[ip] = nil end
				self.nb_threads = self.nb_threads - 1
				self:logDebug("One less thread in the world: %d // %s", self.nb_threads, tostring(channel))

			else
				channel:send("500 Too many connections from your IP, try again later.\r\n")
				channel:close()
			end
		end
	end

	copas.addserver(self.server_sock, serv_handler)

	copas.loop()
end

-- Handle the server as a forking multiprocess server
function ReceiverServer:fork()
	self:log("Tethys SMTP Receiver starting(fork mode)..")

	-- Create the socket BEFORE dropping priviledges, as we probably will run on port 25 which requires root
	self.server_sock = socket.bind(config.settings.bind.host, config.settings.bind.port)
	self.server_sock:settimeout(1)

	self:postInit()
	self:daemonize()

	local errmsg
	self.nb_threads = 0
	self.channels = {}
	self.by_ips = {}
	local serv_handler = function(channel)
		-- Handle whatever we got
		if channel then
			channel:settimeout(1, 't')

			local smtp = SMTPReceiver.new(self, channel, channel)
			smtp:handle()
		end
	end

	local pids = {}
	while true do
		for pid, e in pairs(pids) do
			local ret = lpc.wait(pid, 1)
			if ret then
				self.channels[e.channel] = nil
				self.by_ips[e.ip] = self.by_ips[e.ip] - 1
				if self.by_ips[e.ip] <= 0 then self.by_ips[e.ip] = nil end
				self.nb_threads = self.nb_threads - 1
				self:logDebug("One less thread in the world: %d // %s", self.nb_threads, tostring(e.channel))

				pids[pid] = nil
			elseif config.settings.socket_timeout then
				-- Do we need to kill it ?
				if os.time() - self.channels[e.channel] > config.settings.socket_timeout then
					posix.kill(pid)
					self:logDebug("KILL process, timeout exceeded: " .. pid)
				end
			end
		end

		local channel = self.server_sock:accept()
		if channel then
			local can_continue = false
			local ip = channel:getpeername()
			if ip then
				self.by_ips[ip] = self.by_ips[ip] or 0
				if config.settings.max_threads and self.nb_threads >= config.settings.max_threads then
					self:logDebug("Refused connection from %s because it we have too many global connections.", ip, self.by_ips[ip])
				elseif not config.settings.max_connections_from_ip or self.by_ips[ip] < config.settings.max_connections_from_ip then
					can_continue = true
					self.by_ips[ip] = self.by_ips[ip] + 1
				else
					self:logDebug("Refused connection from %s because it already has %d connections.", ip, self.by_ips[ip])
				end
			end

			if can_continue then
				self.nb_threads = self.nb_threads + 1
				self.channels[channel] = os.time()
				self:logDebug("One more thread in the world: %d // %s", self.nb_threads, tostring(channel))
				local smtp = SMTPReceiver.new(self, copas_channel, channel)

				local pid = posix.fork()
				if pid == 0 then
					self.server_sock:close()
					serv_handler(channel)
					os.exit()
				else
					channel:close()
					pids[pid] = {channel=channel, ip=ip}
				end
			else
				channel:send("500 Too many connections from your IP, try again later.\r\n")
				channel:close()
			end
		end
	end
end


function ReceiverServer:start()
	if not config.settings.process_mode or config.settings.process_mode == "coroutine" then
		self:coroutine()
	elseif config.settings.process_mode == "fork" then
		self:fork()
	end
end
