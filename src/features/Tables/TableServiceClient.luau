local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Vide = require(Packages.Vide)

local source = Vide.source
local LocalPlayer = Players.LocalPlayer

type TableServerState = "Idle" | "InProgress" | "Ended"
type Connection = { Disconnect: (self: any) -> () }

local HEX_SIZE = 0.5 -- must match HEX_SIZE in TableServer's board generation
local BOARD_HEIGHT_OFFSET = 1 -- must match BOARD_HEIGHT_OFFSET in TableServer
local ARM_LENGTH = 0.5
local MIN_POP_SCALE = 0.05
local POP_TIME = 0.4
local SWING_TIME = 0.3
local ARM_PIVOT_HEIGHT = 0.5
local SWING_START_ANGLE = -math.rad(180) -- 55
local SWING_END_ANGLE = -math.rad(135)
local GLIDE_TIME = 0.3
local APPEAR_OFFSET = 5
local APPEAR_HEIGHT = 3

local function HexToWorld(tableModel: Model, q: number, r: number): Vector3
	local pivot = tableModel:GetPivot()
	local lx = HEX_SIZE * 1.5 * q
	local lz = HEX_SIZE * (0.5 * math.sqrt(3) * q + math.sqrt(3) * r)
	return pivot:PointToWorldSpace(Vector3.new(lx, BOARD_HEIGHT_OFFSET, lz))
end

local Hammer = ReplicatedStorage.Assets.Misc.Hammer

local function TweenModel(
	duration: number,
	easingStyle: Enum.EasingStyle,
	easingDirection: Enum.EasingDirection,
	onStep: (alpha: number) -> ()
): ()
	local elapsed = 0
	while elapsed < duration do
		elapsed += RunService.RenderStepped:Wait()
		local alpha = TweenService:GetValue(math.clamp(elapsed / duration, 0, 1), easingStyle, easingDirection)
		onStep(alpha)
	end
	onStep(1)
end

local function PlayHammerSwing(tableModel: Model, q: number, r: number, onComplete: (() -> ())?): ()
	local tilePos = HexToWorld(tableModel, q, r)
	local tableCenter = tableModel:GetPivot().Position
	local toTile = tilePos - tableCenter
	local flatToTile = Vector3.new(toTile.X, 0, toTile.Z)
	local swingDir = if flatToTile.Magnitude > 0.01 then flatToTile.Unit else Vector3.new(1, 0, 0)

	local pivotCFrame = tableModel:GetPivot()
	local side = if q < 0 then -1 else 1
	local perpAxis = (pivotCFrame.LookVector * side).Unit
	local armPivot = tilePos + Vector3.new(0, ARM_PIVOT_HEIGHT, 0)

	local function HammerCF(angle: number, pivot: Vector3?): CFrame
		local p = pivot or armPivot
		local offset = CFrame.fromAxisAngle(perpAxis, angle) * Vector3.new(0, -ARM_LENGTH, 0)
		return CFrame.new(p + offset) * CFrame.fromAxisAngle(perpAxis, angle)
	end

	task.spawn(function()
		local hammer = Hammer:Clone() :: Model
		hammer.Parent = Workspace

		local appearPivot = armPivot + swingDir * APPEAR_OFFSET + Vector3.new(0, APPEAR_HEIGHT, 0)
		local appearCF = HammerCF(SWING_START_ANGLE, appearPivot)
		local preSwingCF = HammerCF(SWING_START_ANGLE)

		hammer:ScaleTo(MIN_POP_SCALE)
		hammer:PivotTo(appearCF)
		TweenModel(POP_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out, function(alpha)
			hammer:ScaleTo(MIN_POP_SCALE + (1 - MIN_POP_SCALE) * alpha)
		end)

		TweenModel(GLIDE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, function(alpha)
			hammer:PivotTo(appearCF:Lerp(preSwingCF, alpha))
		end)

		TweenModel(SWING_TIME, Enum.EasingStyle.Cubic, Enum.EasingDirection.In, function(alpha)
			hammer:PivotTo(HammerCF(SWING_START_ANGLE + (SWING_END_ANGLE - SWING_START_ANGLE) * alpha))
		end)

		if onComplete then
			onComplete()
		end

		TweenModel(POP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function(alpha)
			hammer:ScaleTo(1 - (1 - MIN_POP_SCALE) * alpha)
		end)

		hammer:Destroy()
	end)
end

local TableServiceClient = {}

TableServiceClient.ActiveTable = source(nil :: Model?)
TableServiceClient.ActiveSeat = source(nil :: Seat?)
TableServiceClient.RoundState = source("Idle" :: TableServerState)
TableServiceClient.CurrentTurnPlayer = source(nil :: Player?)
TableServiceClient.LastResult = source(nil :: { Aborted: boolean }?)
TableServiceClient.IsSwinging = source(false)

local activeNetworker: any = nil
local activeConnections: { Connection } = {}

local Handlers = {}

function Handlers.OnHammerSwing(_self: any, _player: Player, q: number, r: number): ()
	local tableModel = TableServiceClient.ActiveTable()
	if not tableModel then
		return
	end

	TableServiceClient.IsSwinging(true)

	PlayHammerSwing(tableModel, q, r, function()
		TableServiceClient.IsSwinging(false)
	end)
end

function Handlers.OnPenguinFall(_self: any, _loser: Player?): () end

function Handlers.OnRoundEnded(_self: any, aborted: boolean): ()
	TableServiceClient.LastResult({ Aborted = aborted })
end

local function Cleanup(): ()
	for _, conn in activeConnections do
		conn:Disconnect()
	end
	table.clear(activeConnections)

	if activeNetworker then
		if type(activeNetworker.Destroy) == "function" then
			activeNetworker:Destroy()
		end
		activeNetworker = nil
	end

	TableServiceClient.ActiveTable(nil)
	TableServiceClient.ActiveSeat(nil)
	TableServiceClient.RoundState("Idle")
	TableServiceClient.CurrentTurnPlayer(nil)
	TableServiceClient.LastResult(nil)
	TableServiceClient.IsSwinging(false)
end

local function FindTableModel(seat: Seat): Model?
	local ancestor: Instance? = seat.Parent
	while ancestor do
		if ancestor:IsA("Model") and CollectionService:HasTag(ancestor, "Tables") then
			return ancestor
		end
		ancestor = ancestor.Parent
	end
	return nil
end

local function OnSeated(active: boolean, seatPart: Instance?): ()
	if not active then
		Cleanup()
		return
	end

	if not seatPart or not seatPart:IsA("Seat") then
		return
	end

	local tableModel = FindTableModel(seatPart)
	if not tableModel then
		return
	end

	local newNetworker = Networker.client.new(tableModel, Handlers)
	activeNetworker = newNetworker
	TableServiceClient.ActiveTable(tableModel)
	TableServiceClient.ActiveSeat(seatPart :: Seat)

	local stateSignal = newNetworker:getServerChangedSignal("State")
	table.insert(
		activeConnections,
		stateSignal:Connect(function(value: TableServerState)
			TableServiceClient.RoundState(value)
		end)
	)

	local turnSignal = newNetworker:getServerChangedSignal("CurrentTurnPlayer")
	table.insert(
		activeConnections,
		turnSignal:Connect(function(value: Player?)
			TableServiceClient.CurrentTurnPlayer(value)
		end)
	)

	TableServiceClient.RoundState((Handlers :: any).State or "Idle")
	TableServiceClient.CurrentTurnPlayer((Handlers :: any).CurrentTurnPlayer)
end

function TableServiceClient.Init(): ()
	local function OnCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Seated:Connect(OnSeated)
	end

	if LocalPlayer.Character then
		OnCharacter(LocalPlayer.Character)
	end
	LocalPlayer.CharacterAdded:Connect(OnCharacter)
end

return TableServiceClient
