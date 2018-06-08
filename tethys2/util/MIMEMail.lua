module(..., package.seeall)

local oo = require "loop.simple"
require'posix'
require'lfs'
require'config'
require'mime'
require'iconv'

new = oo.class({ type="none", path_ext="" })
MIMEMail = new
class = new

function MIMEMail:__init(data, start_line, boundary)
	local t = {
		start_line = start_line,
		boundary=boundary,
		data=data,
		mail = { headers = {}, body = {}, parts = {} }
	}
	t = oo.rawnew(self, t)
	return t
end

function MIMEMail:unquote(str)
	str = str:gsub("=%?([^?]+)%?(.)%?([^?]+)%?=", function(charset, type, data)
		local cd = iconv.new("UTF-8//IGNORE", charset)
		if type == "B" then
			data = mime.unb64(data)
			data = cd:iconv(data or "") or data or ""
			return data
		elseif type == "Q" then
			data = mime.unqp(data)
			data = cd:iconv(data or "") or data or ""
			return data
		end
	end)
	return str
end

function MIMEMail:parse(only_header)
	local header_end = self.start_line or 1
	local last_header = nil
	for i = self.start_line or 1, #(self.data) do
		header_end = i
		local line = self.data[i]

		if self.boundary and line:find(self.boundary, 1, true) then break end
		if line == "" then header_end = header_end + 1 break end

		local x, y, value = line:find("^%s+(.*)$")
		if value and last_header then
			self.mail.headers[last_header] = self.mail.headers[last_header] .. "\n" .. self:unquote(value)
		else
			local x, y, header, value = line:find("^([^:]+): *(.*)$")
			if header then
				header = header:lower()
				if not self.mail.headers[header] then
					self.mail.headers[header] = self:unquote(value)
				else
					self.mail.headers[header] = self.mail.headers[header] .. "\n" .. self:unquote(value)
				end
				last_header = header
			end
		end
	end
	if only_header then return end

	-- Multipart message, parse all subparts
	local subboundary, subboundary_end
	if self.mail.headers["content-type"] and self.mail.headers["content-type"]:find("multipart/") then
		local i, j
		i, j, subboundary = self.mail.headers["content-type"]:find('boundary="?([^"]+)"?')
		if subboundary then
			subboundary = "--"..subboundary
			subboundary_end = subboundary.."--"
		end
	end

	local i = header_end
	local next_line_append = false
	while i <= #(self.data) do
		local line = self.data[i]
		if self.boundary and line:find(self.boundary, 1, true) then break end

		if subboundary and line:find(subboundary, 1, true) then
			while not line:find(subboundary_end, 1, true) do
				local part = new(self.data, i + 1, subboundary)
				i = part:parse()
				line = self.data[i]
				table.insert(self.mail.parts, part)
			end
		else
			-- Ok a normal body line, decode if needed
			local set_next = false
			local no_insert = false
			if self.mail.headers["content-transfer-encoding"] and self.mail.headers["content-transfer-encoding"]:lower() == "quoted-printable" then
				local str, res, j =  line, "", i
				if line:sub(#line) == "=" then
					set_next = true
				end
				line = mime.unqp(line)
			elseif self.mail.headers["content-transfer-encoding"] and self.mail.headers["content-transfer-encoding"]:lower() == "base64" then
			end
			if not next_line_append then
				if not no_insert then table.insert(self.mail.body, (line or "")) end
			else
				next_line_append = false
				self.mail.body[#(self.mail.body)] = self.mail.body[#(self.mail.body)]..(line or "")
			end
			if set_next then next_line_append = true end
		end

		i = i + 1
	end

	-- If the body is in base64 we finish it by concatenating all lines
	if self.mail.headers["content-transfer-encoding"] and self.mail.headers["content-transfer-encoding"]:lower() == "base64" then
		local whole = table.concat(self.mail.body)
		self.mail.body = { whole }
	end

	return i
end

function MIMEMail:splitBodies(bodies)
	local body = self.mail.body
	table.insert(bodies, body)
	self.mail.body = #bodies

	for i, part in ipairs(self.mail.parts) do
		part:splitBodies(bodies)
		self.mail.parts[i] = part.mail
	end
end

function MIMEMail:split()
	if self.bodies then return end
	local bodies =  {}
	self:splitBodies(bodies, 1)
	self.bodies = bodies
end
