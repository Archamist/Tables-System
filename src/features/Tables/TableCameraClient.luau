local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local TableServiceClient = require(ReplicatedStorage.Source.Features.Tables.TableServiceClient)

local LocalPlayer = Players.LocalPlayer

-- Distances/heights are now relative to YOUR OWN seat, not a fixed world offset —
-- that's what makes the view correct no matter which side of the table you sit on.
local WAITING_BACK_DISTANCE = 9 -- how far behind your own seat the spectator camera sits
local WAITING_HEIGHT = 7 -- how high above your seat the spectator camera sits

local TURN_BACK_DISTANCE = 2 -- how far behind your seat the turn camera sits (small = closer/more top-down)
local TURN_HEIGHT = 7 -- how high above your seat the turn camera sits while picking a tile

local TURN_PAN_RADIUS = 3 -- left/right drift as you move the mouse
local TURN_PAN_DEPTH = 3 -- forward/back drift over the board as you move the mouse

local FOCUS_HEIGHT = 4
local CAMERA_LERP_SPEED = 6

type CameraMode = "Default" | "Waiting" | "Turn"

local TableCameraClient = {}

local mode: CameraMode = "Default"
local renderConnection: RBXScriptConnection? = nil

local function GetMousePanAlpha(camera: Camera): (number, number)
	local viewport = camera.ViewportSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return 0, 0
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	local alphaX = (mouseLocation.X / viewport.X) * 2 - 1
	local alphaY = (mouseLocation.Y / viewport.Y) * 2 - 1
	return math.clamp(alphaX, -1, 1), math.clamp(alphaY, -1, 1)
end

local function ResolveMode(): CameraMode
	local tableModel = TableServiceClient.ActiveTable()
	if not tableModel or TableServiceClient.RoundState() ~= "InProgress" then
		return "Default"
	end
	return if TableServiceClient.CurrentTurnPlayer() == LocalPlayer then "Turn" else "Waiting"
end

-- Returns your seat's position and the flat (Y=0) direction from your seat
-- toward the table's center. This is the single source of truth for "which
-- way is this seat facing" — both camera position AND camera orientation
-- below are derived from it, so they can never fall out of sync with each
-- other regardless of which side of the table you're sitting on.
local function GetSeatFacing(tableModel: Model): (Vector3, Vector3)
	local tableCenter = tableModel:GetPivot().Position
	local seat = TableServiceClient.ActiveSeat()
	local seatPos = if seat then seat.Position else tableCenter + Vector3.new(0, 0, 10)

	local flat = Vector3.new(tableCenter.X - seatPos.X, 0, tableCenter.Z - seatPos.Z)
	local towardTable = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)

	return seatPos, towardTable
end

local function StepCamera(dt: number): ()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local newMode = ResolveMode()
	if newMode ~= mode then
		mode = newMode :: CameraMode
		camera.CameraType = if mode == "Default" then Enum.CameraType.Custom else Enum.CameraType.Scriptable
	end

	if mode == "Default" then
		return
	end

	local tableModel = TableServiceClient.ActiveTable()
	if not tableModel or not tableModel.Parent then
		return
	end

	local seatPos, towardTable = GetSeatFacing(tableModel)
	local focus = tableModel:GetPivot().Position + Vector3.new(0, FOCUS_HEIGHT, 0)

	local targetCFrame: CFrame
	if mode == "Turn" then
		local alphaX, alphaY = GetMousePanAlpha(camera)
		local sideways = Vector3.new(-towardTable.Z, 0, towardTable.X) -- perpendicular to your facing, for left/right pan
		local pan = sideways * (alphaX * TURN_PAN_RADIUS) + towardTable * (alphaY * TURN_PAN_DEPTH)

		local camPos = seatPos - towardTable * TURN_BACK_DISTANCE + Vector3.new(0, TURN_HEIGHT, 0) + pan
		-- Up-hint is towardTable itself (the same per-seat direction driving
		-- position above), NOT a fixed world axis. A fixed axis only matches
		-- seats facing one particular way; for a seat on the other side of
		-- the table it points the opposite way and flips the render upside
		-- down, which is exactly the bug in the screenshot.
		targetCFrame = CFrame.lookAt(camPos, focus, towardTable)
	else
		local camPos = seatPos - towardTable * WAITING_BACK_DISTANCE + Vector3.new(0, WAITING_HEIGHT, 0)
		targetCFrame = CFrame.lookAt(camPos, focus)
	end

	camera.CFrame = camera.CFrame:Lerp(targetCFrame, math.clamp(dt * CAMERA_LERP_SPEED, 0, 1))
end

function TableCameraClient.Init(): ()
	if renderConnection then
		return
	end
	renderConnection = RunService.RenderStepped:Connect(StepCamera)
end

function TableCameraClient.Destroy(): ()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if mode ~= "Default" then
		mode = "Default"
		local camera = Workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
		end
	end
end

return TableCameraClient
