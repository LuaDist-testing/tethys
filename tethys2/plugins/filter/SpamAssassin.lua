module(..., package.seeall)

local oo = require "loop.simple"
local Plugin = require 'tethys2.plugins.filter.Plugin'
require'config'

new = oo.class({}, Plugin.class)
SpamAssassin = new
class = new

function SpamAssassin:filterMessage(to, state, filtered)
	if state.spamasssasin_done then return end

	-- Make a thread for spamassassin call
	local pthread = self.server.scheduler.current
	local thread = coroutine.create(function()
		local s = socket:tcp()
		s:connect(config.settings.filter.spamassassin.host, config.settings.filter.spamassassin.port)

		local size = 0
		for i, line in ipairs(state.data) do size = size + line:len() + 2 end

		-- Send the data to spam assassin
		s:send("SYMBOLS SPAMC/1.2\r\n")
		s:send("Content-length: "..size.."\r\n\r\n")
		for i, line in ipairs(state.data) do s:send(line) s:send("\r\n") end
		s:shutdown("send")

		local line = s:receive("*l")
		if line:find("^SPAMD/.*EX_OK$") then
			line = s:receive("*l")
			local i, j, spam, level, max = line:find("^Spam: (%a+) ; ([%d.]+) / ([%d.]+)$")
			if s:receive("*l") then
				line = s:receive("*l")
			end
			if i then
				self.server:logDebug("SpamAssasin: '%s' '%s' '%s' :: '%s'", spam, level, max, tostring(line))
				table.insert(state.data, 1, "X-Spam-Flag: "..(spam:lower()=="true" and "YES" or "NO"))
				table.insert(state.data, 2, ("X-Spam-Status: %s, score=%s required=%s tests=%s"):format((spam:lower()=="true" and "Yes" or "No"), level, max, line or "[No Data]"))
			end
		end

		s:close()

		-- Continue parent thread
		self.server.scheduler:register(pthread)
	end)

	-- Register the thread and add a trap for errors
	self.server.scheduler:register(thread)
	self.server.scheduler.traps[thread] = function(self2, thread, success, errmsg)
		if not success and errmsg then self.server:logError("[lua-error] %s", errmsg) end
	end

	-- Wait for child to finish
	self.server.scheduler:suspend()

	state.spamasssasin_done = true
end

function SpamAssassin:init(server)
	oo.superclass(SpamAssassin).init(self, server)
end
