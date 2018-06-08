module(..., package.seeall)

local oo = require "loop.simple"
local Plugin = require 'tethys2.plugins.filter.Plugin'
local MIMEMail = require 'tethys2.util.MIMEMail'
require'config'

new = oo.class({}, Plugin.class)
FixMail = new
class = new

function FixMail:filterMessage(to, state, filtered)
	if state.fixmail_done then return end

	local mime = MIMEMail.new(state.data)
	mime:parse(true)

	local fixed = {}

	-- Mail has no date, add one and add a special header to know we did it
	if config.settings.filter.fixmail.fix.date and not mime.mail.headers.date then
		table.insert(state.data, 1, os.date("Date: %d %b %Y %H:%M:%S %z"))
		table.insert(fixed, "date")
		self.server:logDebug("Fixing date header in mail")
	end

	-- Mail has date but replace it with current date to deter spammers
	if config.settings.filter.fixmail.replace.date then
		table.insert(state.data, 1, os.date("Date: %d %b %Y %H:%M:%S %z"))

		-- Replace Date header
		local last_header = nil
		for i = 2, #(state.data) do
			local line = state.data[i]
			if line == "" then break end

			local x, y, header, value = line:find("^([Dd][Aa][Tt][Ee]): *(.*)$")
			if header then
				state.data[i] = "X-Tethys-Original-" .. state.data[i]
				break
			end
		end

		table.insert(fixed, "date_replace")
		self.server:logDebug("Replaced date header in mail")
	end

	-- Mail has no envelope header
	if config.settings.filter.fixmail.fix.envelope and not mime.mail.headers["x-tethys-smtp-envelope"] then
		for i, to in pairs(state.to) do
			for i, orig in ipairs(to.orig) do
				table.insert(state.data, 1, ("    To: %s@%s"):format(orig.account or "[Unknown]", orig.host or "[Unknown]"))
			end
		end
		table.insert(state.data, 1, ("X-Tethys-SMTP-Envelope: From: %s"):format(state.from or "[Unknown]"))
		table.insert(fixed, "tethys-smtp-envelope")
		self.server:logDebug("Adding smtp envelope")
	end

	if #fixed > 0 then
		table.insert(state.data, 1, os.date("X-Tethys-FixMail: "..table.concat(fixed, ",")))
	end
	state.fixmail_done = true
end

function FixMail:init(server)
	oo.superclass(FixMail).init(self, server)
end
