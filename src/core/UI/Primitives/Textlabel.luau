local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sift = require(ReplicatedStorage.Packages.Sift)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local defaultTextSettings = {
	BackgroundTransparency = 1,
	TextScaled = true,
	ZIndex = 1,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.BuilderSansExtraBold,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
}

local defaultDropShadowSettings = {
	Transparency = 0,
	Offset = UDim2.fromOffset(0, 4),
	Color = Color3.fromRGB(0, 0, 0),
}

local defaultStrokeSettings = {
	Thickness = 2,
	Transparency = 0,
	Color = Color3.fromRGB(0, 0, 0),
}

return function(props)
	local frameProps = {
		Name = props.Name or "TextLabelFrame",
		BackgroundTransparency = props.BackgroundTransparency or 1,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ZIndex = props.ZIndex,
		Rotation = props.Rotation,
		BackgroundColor3 = props.BackgroundColor3,
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
		SizeConstraint = props.SizeConstraint,
		AutomaticSize = props.AutomaticSize,
	}

	if props.FrameChildren then
		table.insert(frameProps, props.FrameChildren)
	end

	local textLabelProps = {
		Name = "TextLabel",
		BackgroundTransparency = 1,
		ZIndex = 1,
		LayoutOrder = 1,
		Text = props.Text,
	}

	textLabelProps.TextColor3 = props.TextColor3 or defaultTextSettings.TextColor3
	textLabelProps.TextSize = props.TextSize
	textLabelProps.TextScaled = if props.TextSize then false else props.TextScaled or defaultTextSettings.TextScaled
	textLabelProps.Font = props.Font or defaultTextSettings.Font
	textLabelProps.TextTransparency = props.TextTransparency
	textLabelProps.TextXAlignment = props.TextXAlignment
	textLabelProps.TextYAlignment = props.TextYAlignment
	textLabelProps.TextWrapped = props.TextWrapped

	local automaticSize = props.AutomaticSize
	if not automaticSize then
		automaticSize = if props.Prefix or props.Suffix then Enum.AutomaticSize.X else nil
	end
	textLabelProps.AutomaticSize = automaticSize

	textLabelProps.Position = props.TextPosition or UDim2.fromScale(0.5, 0.5)
	textLabelProps.AnchorPoint = props.TextAnchorPoint or Vector2.new(0.5, 0.5)
	textLabelProps.Size = if props.Prefix or props.Suffix then UDim2.fromScale(0, 1) else UDim2.fromScale(1, 1)
	textLabelProps.RichText = props.RichText

	if props.Stroke then
		table.insert(textLabelProps, create("UIStroke")(Sift.Dictionary.merge(defaultStrokeSettings, props.Stroke)))
	end

	if props.Gradient then
		local gradientInstance = create("UIGradient")
		table.insert(textLabelProps, gradientInstance(props.Gradient))
	end

	for key, child in props do
		if type(key) == "number" then
			table.insert(textLabelProps, child)
		end
	end

	table.insert(frameProps, create("TextLabel")(textLabelProps))

	if props.DropShadow then
		local dropShadowCreator = create("TextLabel")
		local dropShadowProps = {
			Name = "DropShadow",
			BackgroundTransparency = 1,
			ZIndex = 0,
			Text = props.Text,
		}

		dropShadowProps.TextColor3 = props.DropShadow.Color or defaultDropShadowSettings.Color
		dropShadowProps.TextSize = props.TextSize
		dropShadowProps.TextScaled = if props.TextSize
			then false
			else props.TextScaled or defaultTextSettings.TextScaled
		dropShadowProps.Font = props.Font or defaultTextSettings.Font
		dropShadowProps.TextTransparency = props.DropShadow.Transparency or defaultDropShadowSettings.Transparency
		dropShadowProps.TextXAlignment = props.TextXAlignment
		dropShadowProps.TextYAlignment = props.TextYAlignment
		dropShadowProps.TextWrapped = props.TextWrapped
		dropShadowProps.Position = (props.TextPosition or UDim2.fromScale(0.5, 0.5))
			+ (props.DropShadow.Offset or defaultDropShadowSettings.Offset)
		dropShadowProps.AnchorPoint = props.TextAnchorPoint or Vector2.new(0.5, 0.5)
		dropShadowProps.RichText = props.RichText
		dropShadowProps.Size = UDim2.fromScale(1, 1)

		table.insert(frameProps, dropShadowCreator(dropShadowProps))
	end

	if props.Prefix or props.Suffix then
		local listLayoutCreator = create("UIListLayout")
		local listLayoutProps = {
			FillDirection = Enum.FillDirection.Horizontal,
		}

		listLayoutProps.HorizontalAlignment = if props.Prefix and props.Prefix.HorizontalAlignment
			then props.Prefix.HorizontalAlignment
			elseif props.Suffix and props.Suffix.HorizontalAlignment then props.Suffix.HorizontalAlignment
			else Enum.HorizontalAlignment.Center
		listLayoutProps.VerticalAlignment = Enum.VerticalAlignment.Center
		listLayoutProps.SortOrder = Enum.SortOrder.LayoutOrder
		listLayoutProps.Padding = if props.Prefix and props.Prefix.Padding
			then props.Prefix.Padding
			elseif props.Suffix and props.Suffix.Padding then props.Suffix.Padding
			else UDim.new(0, 4)

		table.insert(frameProps, listLayoutCreator(listLayoutProps))
	end

	if props.Prefix then
		local prefixCreator = create("ImageLabel")
		local prefixProps = {
			Name = "Prefix",
			BackgroundTransparency = 1,
			LayoutOrder = 0,
		}

		prefixProps.Size = props.Prefix.Size or UDim2.fromScale(1, 1)
		prefixProps.SizeConstraint = props.Prefix.SizeConstraint or Enum.SizeConstraint.RelativeYY
		prefixProps.ScaleType = Enum.ScaleType.Fit
		prefixProps.Image = props.Prefix.Image
		prefixProps.ImageColor3 = props.Prefix.ImageColor3
		prefixProps.ImageTransparency = props.Prefix.ImageTransparency

		table.insert(frameProps, prefixCreator(prefixProps))
	end

	if props.Suffix then
		local suffixCreator = create("ImageLabel")
		local suffixProps = {
			Name = "Suffix",
			BackgroundTransparency = 1,
			LayoutOrder = 2,
		}

		suffixProps.Size = props.Suffix.Size or UDim2.fromScale(1, 1)
		suffixProps.SizeConstraint = props.Suffix.SizeConstraint or Enum.SizeConstraint.RelativeYY
		suffixProps.ScaleType = Enum.ScaleType.Fit
		suffixProps.Image = props.Suffix.Image
		suffixProps.ImageColor3 = props.Suffix.ImageColor3
		suffixProps.ImageTransparency = props.Suffix.ImageTransparency

		table.insert(frameProps, suffixCreator(suffixProps))
	end

	return create("Frame")(frameProps)
end
