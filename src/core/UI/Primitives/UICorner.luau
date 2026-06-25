local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
return function(props)
	return Vide.create("UICorner")(props)
end
