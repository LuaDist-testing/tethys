module(..., package.seeall)

local oo = require "loop.simple"
require'posix'
require'lfs'
require'config'

new = oo.class({ type="none", path_ext="" })
MailFormat = new
class = new

function MailFormat:dropMail(from, data)
	return nil
end

function MailFormat:setRead(name)
end

function MailFormat:checkRepository()
end

function MailFormat:setOwner(uid, gid)
	self.uid = uid
	self.gid = gid
end

function MailFormat:__init(path)
	local t = { path = path }
	t = oo.rawnew(self, t)
	return t
end
