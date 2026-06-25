local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Frame = require(ReplicatedStorage.Source.Core.UI.Primitives.Frame)
local Textlabel = require(ReplicatedStorage.Source.Core.UI.Primitives.Textlabel)
local UICorner = require(ReplicatedStorage.Source.Core.UI.Primitives.UICorner)
local UIListLayout = require(ReplicatedStorage.Source.Core.UI.Primitives.UIListLayout)
local UIPadding = require(ReplicatedStorage.Source.Core.UI.Primitives.UIPadding)
local UIStroke = require(ReplicatedStorage.Source.Core.UI.Primitives.UIStroke)
local TableServiceClient = require(ReplicatedStorage.Source.Features.Tables.TableServiceClient)

local LocalPlayer = Players.LocalPlayer

return function()
	return Frame({
		Visible = function()
			return TableServiceClient.ActiveTable() ~= nil
		end,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromOffset(280, 90),
		BackgroundColor3 = Color3.fromRGB(20, 24, 30),
		BackgroundTransparency = 0.1,

		UICorner({ CornerRadius = UDim.new(0, 12) }),
		UIStroke({ Color = Color3.fromRGB(80, 200, 255), Thickness = 2 }),
		UIPadding({ PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
		UIListLayout({
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 4),
		}),

		Textlabel({
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0.5),
			TextColor3 = Color3.new(1, 1, 1),
			Text = function()
				local state = TableServiceClient.RoundState()
				if state == "InProgress" then
					return "Game in progress"
				elseif state == "Ended" then
					return "Waiting for a second player"
				else
					return "Waiting for a second player"
				end
			end,
		}),

		Textlabel({
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0.5),
			TextColor3 = Color3.fromRGB(180, 220, 255),
			Text = function()
				local turnPlayer = TableServiceClient.CurrentTurnPlayer()
				if TableServiceClient.RoundState() ~= "InProgress" or not turnPlayer then
					return ""
				end
				return if turnPlayer == LocalPlayer
					then "Your turn — swing the hammer!"
					else turnPlayer.Name .. "'s turn"
			end,
		}),
	})
end
