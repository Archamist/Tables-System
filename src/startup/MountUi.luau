local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local RootUi = require(ReplicatedStorage.Source.Features.App.RootUi)

local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

return function()
	Vide.mount(RootUi, PlayerGui)
end
