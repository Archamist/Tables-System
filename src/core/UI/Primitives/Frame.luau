local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local c = Vide.create

return function(props: {})
	return c("Frame")(props)
end
