module(..., package.seeall)

-- Removes any routing info from the address, as this is deprecated by RFC 2821
function addressRouteStrip(str)
	local i, j, acc, host
	i, j, str = str:find(":?([^:]*)$")
	if not i then return end
	i, j, acc, host = str:find("([^@]*)@([^@]*)")
	if not i then return end
	return acc, host
end

function reverseTable(t, v)
	local nt = {}
	for i, e in ipairs(t) do nt[e] = v or true end
	return nt
end
