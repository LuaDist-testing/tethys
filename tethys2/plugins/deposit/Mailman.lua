module(..., package.seeall)

local oo = require "loop.simple"
local Plugin = require 'tethys2.plugins.deposit.Plugin'
local MailFormat = require 'tethys2.util.Maildir'
require'posix'
require'lfs'
require'config'

new = oo.class({}, Plugin.class)
Mailman = new
class = new

Mailman.mailman_types =
{
	{"^(.*)%-admin$", "bounces"},
	{"^(.*)%-bounces$", "bounces"},
	{"^(.*)%-join$", "join"},
	{"^(.*)%-leave$", "leave"},
	{"^(.*)%-owner$", "owner"},
	{"^(.*)%-request$", "request"},
}

function Mailman:deliverMail(to, state, params)
	local type, list = "post", to.orig[1].account

	for i, d in ipairs(self.mailman_types) do
		local l = to.orig[1].account:find(d[1])
		if l then
			type, list = d[2], l
			break
		end
	end

	self.server:logDebug("Mailmain deposit: %s on %s", type, list)

	local command = params or config.settings.deposit.mailman_command
	local fff = io.popen(("%s '%s' '%s'"):format(command, type, list), "w")
	fff:write(string.format("Return-Path: <%s>", state.from)) fff:write('\n')
	for i, d in ipairs(state.data) do
		fff:write(d) fff:write("\r\n")
	end
	fff:close()
end

function Mailman:finishDelivery(state)
	return nil
end

function Mailman:init(server)
	oo.superclass(Mailman).init(self, server)
end
