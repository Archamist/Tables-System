local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local RemoveKeys = require(ReplicatedStorage.Source.Core.Util.RemoveKeys)

local create = Vide.create
local customPropertyKeys = { "HoverScale", "OnEnter", "OnLeave", "OnDown", "OnUp" }

return function(props)
	local targetHoverScale = props.HoverScale or 1.1
	local scaleSource = Vide.source(1)
	local springScale = Vide.spring(scaleSource, 0.2, 0.7)

	local buttonProps = RemoveKeys(props, customPropertyKeys)
	local originalSelectionGained = buttonProps.SelectionGained
	local originalSelectionLost = buttonProps.SelectionLost

	buttonProps.BackgroundTransparency = buttonProps.BackgroundTransparency or 1

	table.insert(
		buttonProps,
		create("UIScale")({
			Scale = springScale,
		})
	)

	local function handleEnter()
		--SoundController:Play(Sounds.ui.hover)
		scaleSource(targetHoverScale)

		if props.OnEnter then
			props.OnEnter()
		end
	end

	local function handleLeave()
		scaleSource(1)

		if props.OnLeave then
			props.OnLeave()
		end
	end

	buttonProps.MouseEnter = handleEnter
	buttonProps.MouseLeave = handleLeave

	function buttonProps.SelectionGained()
		--SoundController:Play(Sounds.ui.hover)
		scaleSource(targetHoverScale)

		if props.OnEnter then
			props.OnEnter()
		end

		if originalSelectionGained then
			originalSelectionGained()
		end
	end

	function buttonProps.SelectionLost()
		scaleSource(1)

		if props.OnLeave then
			props.OnLeave()
		end

		if originalSelectionLost then
			originalSelectionLost()
		end
	end

	function buttonProps.MouseButton1Down()
		--SoundController:Play(Sounds.ui.mouseDown)

		if props.OnDown then
			props.OnDown()
		end
	end

	function buttonProps.MouseButton1Up()
		--SoundController:Play(Sounds.ui.mouseUp)

		if props.OnUp then
			props.OnUp()
		end
	end

	return create("ImageButton")(buttonProps)
end
