local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
return function(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	return Vide.create("ScrollingFrame")(props)
end
