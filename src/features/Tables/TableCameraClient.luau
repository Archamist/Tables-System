local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TableServiceClient = require(ReplicatedStorage.Source.Features.Tables.TableServiceClient)

local LocalPlayer = Players.LocalPlayer

local WAITING_BACK_DISTANCE = 9
local WAITING_HEIGHT = 11

local PICK_HEIGHT = 3

local SWING_BACK_DISTANCE = 1
local SWING_SIDE_DISTANCE = 5
local SWING_HEIGHT = 3

local FOCUS_HEIGHT = 4
local CAMERA_LERP_SPEED = 6

type CameraMode = "Default" | "Waiting" | "PickTile" | "Swing"

local TableCameraClient = {}

local mode: CameraMode = "Default"
local renderConnection: RBXScriptConnection? = nil

local function ResolveMode(): CameraMode
	local tableModel = TableServiceClient.ActiveTable()
	if not tableModel or TableServiceClient.RoundState() ~= "InProgress" then
		return "Default"
	end

	if TableServiceClient.IsSwinging() then
		return "Swing"
	end

	return if TableServiceClient.CurrentTurnPlayer() == LocalPlayer then "PickTile" else "Waiting"
end

local function GetSeatFacing(tableModel: Model): (Vector3, Vector3, Vector3)
	local tableCenter = tableModel:GetPivot().Position
	local seat = TableServiceClient.ActiveSeat()
	local seatPos = if seat then seat.Position else tableCenter + Vector3.new(0, 0, 10)

	local flat = Vector3.new(tableCenter.X - seatPos.X, 0, tableCenter.Z - seatPos.Z)
	local towardTable = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local sideways = Vector3.new(-towardTable.Z, 0, towardTable.X)

	return seatPos, towardTable, sideways
end

local function StepCamera(dt: number): ()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local newMode: CameraMode
	local ok, result = pcall(ResolveMode)
	newMode = if ok then result else "Default"

	if newMode ~= mode then
		mode = newMode
		camera.CameraType = if mode == "Default" then Enum.CameraType.Custom else Enum.CameraType.Scriptable
	end

	if mode == "Default" then
		return
	end

	local tableModel = TableServiceClient.ActiveTable()
	if not tableModel or not tableModel.Parent then
		return
	end

	local seatPos, towardTable, sideways = GetSeatFacing(tableModel)
	local focus = tableModel:GetPivot().Position + Vector3.new(0, FOCUS_HEIGHT, 0)

	local targetCFrame: CFrame
	if mode == "PickTile" then
		local camPos = focus + Vector3.new(0, PICK_HEIGHT, 0)
		targetCFrame = CFrame.lookAt(camPos, focus, towardTable)
	elseif mode == "Swing" then
		local camPos = seatPos
			- towardTable * SWING_BACK_DISTANCE
			+ sideways * SWING_SIDE_DISTANCE
			+ Vector3.new(0, SWING_HEIGHT, 0)
		targetCFrame = CFrame.lookAt(camPos, focus)
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
