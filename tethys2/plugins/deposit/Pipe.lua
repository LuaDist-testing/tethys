module(..., package.seeall)

local oo = require "loop.simple"
local Plugin = require 'tethys2.plugins.deposit.Plugin'
local MailFormat = require 'tethys2.util.Maildir'
require'posix'
require'lfs'
require'config'

new = oo.class({}, Plugin.class)
Pipe = new
class = new

function Pipe:deliverMail(to, state, params)
	local command = params or config.settings.deposit.pipe_command
	local fff = io.popen(command:gsub("#TO#", account.."@"..host):gsub("#FROM#", state.from), "w")
	fff:write(string.format("Return-Path: <%s>", state.from)) fff:write('\n')
	for i, d in ipairs(state.data) do
		fff:write(d) fff:write("\r\n")
	end
	fff:close()
end

function Pipe:finishDelivery(state)
	return nil
end

function Pipe:init(server)
	oo.superclass(Pipe).init(self, server)
end
