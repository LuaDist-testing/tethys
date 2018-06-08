module(..., package.seeall)

local oo = require "loop.simple"
local MailFormat = require'tethys2.util.MailFormat'
require'posix'
require'lfs'
require'config'

--
-- Mail format to drop mails into a maildir structure
-- Maildirs are directories containing: new/ cur/ tmp/
-- New mails arrive in new/ and read mails are put in cur/
--
new = oo.class({ type="maildir", path_ext=".maildir" }, MailFormat.class)
Maildir = new
class = new

function Maildir:dropMail(from, data)
	local olddir = lfs.currentdir()
	local pid = posix.getprocessid().pid
	lfs.chdir(self.path)
	local name
	repeat
		name = os.date("%s."..pid.."."..config.settings.bind.reply_host)
		posix.sleep(1)
	until not lfs.attributes("tmp/"..name) and not lfs.attributes("new/"..name) and not lfs.attributes("cur/"..name)
	local fff = io.open("tmp/"..name, "w")
	if from then fff:write(string.format("Return-Path: <%s>", from)) fff:write('\n') end
	for i, d in ipairs(data) do
		fff:write(d) fff:write("\n")
	end
	fff:close()

	if self.uid and self.gid then posix.chown("tmp/"..name, self.uid, self.gid) end

	posix.link("tmp/"..name, "new/"..name)

	posix.unlink("tmp/"..name)

	lfs.chdir(olddir)
	return name
end

function Maildir:setRead(name)
	if lfs.attributes("new/"..name) and not lfs.attributes("cur/"..name) then
		posix.link("new/"..name, "cur/"..name)
		posix.unlink("new/"..name)
		return true
	end
end

-- Create a maildir structure
function Maildir:checkRepository()
	self.path = self.path:gsub("//", "/")
	if self.path:find("^/") then lfs.chdir("/") end
	for p in string.gmatch(self.path, "[^/]+") do
		if not lfs.attributes(p) then
			lfs.mkdir(p)
			if self.uid and self.gid then posix.chown(p, self.uid, self.gid) end
		end
		lfs.chdir(p)
	end
	lfs.mkdir("new")
	lfs.mkdir("cur")
	lfs.mkdir("tmp")
	if self.uid and self.gid then
		posix.chown("new", self.uid, self.gid)
		posix.chown("cur", self.uid, self.gid)
		posix.chown("tmp", self.uid, self.gid)
	end
end
