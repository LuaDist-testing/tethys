module(..., package.seeall)

local oo = require "loop.simple"
local Maildir = require'tethys2.util.Maildir'
require'posix'
require'lfs'
require'config'

--
-- Mail format to drop mails into a maildir structure
-- Relaydirs are directories containing: new/ cur/ tmp/
-- New mails arrive in new/ and read mails are put in cur/
--
new = oo.class({}, Maildir.class)
Relaydir = new
class = new

function Relaydir:relayMail(state)
	local olddir = lfs.currentdir()
	local pid = posix.getprocessid().pid
	lfs.chdir(self.path)

	local name
	if not state.force_name then
		repeat
			name = os.date("%s."..pid.."."..config.settings.bind.reply_host)
		until not lfs.attributes("tmp/"..name) and not lfs.attributes("new/"..name) and not lfs.attributes("cur/"..name) and not lfs.attributes("retry/"..name)

		-- Append processing date
		name = name.."-date"..(state.post_after or os.time())
	else
		name = state.force_name
	end

	-- Write message
	if not state.no_mail then
		local fff = io.open("tmp/"..name, "w")
		for i, d in ipairs(state.data) do
			fff:write(d) fff:write("\n")
		end
		fff:close()
	end

	-- Write a descriptor
	fff = io.open("tmp/info-"..name, "w")
	fff:write("return {\n")
	fff:write(string.format("try=%d,\n", state.retry or config.settings.sender.retries))
	fff:write(string.format("from=%q,\n", state.from))
	fff:write(string.format("rcpt={\n"))
	for i, to in pairs(state.to) do
		if to.to_relay then
			fff:write(string.format("{account=%q,host=%q},\n", tostring(to.account), tostring(to.host)))
		end
	end
	fff:write("},\n")
	fff:write("}\n")
	fff:close()

	state.relay_dest = state.relay_dest or "new"
	posix.link("tmp/info-"..name, state.relay_dest.."/info-"..name)
	posix.unlink("tmp/info-"..name)
	posix.link("tmp/"..name, state.relay_dest.."/"..name)
	posix.unlink("tmp/"..name)

	lfs.chdir(olddir)
	return name
end

-- Create a maildir structure
function Relaydir:checkRepository()
	oo.superclass(Relaydir).checkRepository(self)
	lfs.mkdir("retry")
end
