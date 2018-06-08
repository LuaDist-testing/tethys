module(..., package.seeall)

local dns = require('dns')

function resolveMX(host)
	local mxs = dns.MX(host)

	if not mxs or #mxs == 0 then return { {host=host, priority=1} }
	else
		table.sort(mxs, function(a, b) return a.priority < b.priority end)
		return mxs
	end
end
