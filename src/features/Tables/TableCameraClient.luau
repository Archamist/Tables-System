--!strict
--[[
	TableCameraClient

	While the local player is seated at a Table and a round is InProgress,
	swaps to a scriptable camera: a pulled-back view for whoever isn't on
	turn, and a closer-to-overhead view that pans with the mouse cursor for
	whoever is. Restores the default camera otherwise.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local TableServiceClient = require(ReplicatedStorage.Source.Features.Tables.TableServiceClient)

local LocalPlayer = Players.LocalPlayer

local WAITING_OFFSET = Vector3.new(0, 16, 20)
local TURN_OFFSET = Vector3.new(0, 26, 6)
local TURN_PAN_RADIUS = 9
local TURN_PAN_VERTICAL = 5
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
	if not tableModel then
		return
	end

	local focus = tableModel:GetPivot().Position + Vector3.new(0, FOCUS_HEIGHT, 0)

	local targetCFrame: CFrame
	if mode == "Turn" then
		local alphaX, alphaY = GetMousePanAlpha(camera)
		local pan = Vector3.new(alphaX * TURN_PAN_RADIUS, -alphaY * TURN_PAN_VERTICAL, 0)
		targetCFrame = CFrame.lookAt(focus + TURN_OFFSET + pan, focus)
	else
		targetCFrame = CFrame.lookAt(focus + WAITING_OFFSET, focus)
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
