local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sift = require(ReplicatedStorage.Packages.Sift)
local Vide = require(ReplicatedStorage.Packages.Vide)

local RootModules = {}
local initailized = false

local function CaptureRoots()
	if initailized then
		return
	end
	initailized = true
	for _, RootModule in ReplicatedStorage.Source.Features:GetDescendants() do
		if RootModule:IsA("ModuleScript") and RootModule.Name:find("Root") and RootModule ~= script then
			table.insert(RootModules, require(RootModule))
		end
	end
end

return function()
	CaptureRoots()
	return Vide.create("ScreenGui")({
		Name = "Root",
		ResetOnSpawn = false,
		IgnoreGuiInset = true, -- lets the GUI draw behind the Roblox top bar
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ClipToDeviceSafeArea = false,

		Sift.Array.map(RootModules, function(v)
			return v()
		end),
	})
end
