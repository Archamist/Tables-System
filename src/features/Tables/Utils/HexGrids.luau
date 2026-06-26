local HexGrid = {}

export type AxialCoord = { Q: number, R: number }

function HexGrid.GenerateDisk(radius: number): { AxialCoord }
	local coords = {}
	for q = -radius, radius do
		local rMin = math.max(-radius, -q - radius)
		local rMax = math.min(radius, -q + radius)
		for r = rMin, rMax do
			table.insert(coords, { Q = q, R = r })
		end
	end
	return coords
end

function HexGrid.Distance(q1: number, r1: number, q2: number, r2: number): number
	local dq = q1 - q2
	local dr = r1 - r2
	return (math.abs(dq) + math.abs(dr) + math.abs(dq + dr)) / 2
end

function HexGrid.AxialToWorld(q: number, r: number, size: number): Vector3
	local x = size * (3 / 2 * q)
	local z = size * (math.sqrt(3) / 2 * q + math.sqrt(3) * r)
	return Vector3.new(x, 0, z)
end

function HexGrid.Key(q: number, r: number): string
	return q .. "," .. r
end

return HexGrid
