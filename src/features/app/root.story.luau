local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RootUi = require(script.Parent.RootUi)
local Vide = require(ReplicatedStorage.Packages.Vide)

return function(parent)
	local Destory = Vide.mount(RootUi, parent)
	return function()
		Destory()
	end
end
