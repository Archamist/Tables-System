local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Vide = require(Packages.Vide)

local source = Vide.source
local LocalPlayer = Players.LocalPlayer

type TableServerState = "Idle" | "InProgress" | "Ended"
type Connection = { Disconnect: (self: any) -> () }

-- ── Tuning ─────────────────────────────────────────────────────────────────
-- HEX_SIZE:     centre-to-centre tile spacing in studs.
-- PIVOT_HEIGHT: height above the tile where the swing hinge sits.
-- ARM_LENGTH:   distance from hinge to the Hammer model's pivot centre.
-- Assumes the model's local +Y runs handle→head (head at -Y end).
local HEX_SIZE = 2.5
local PIVOT_HEIGHT = 5
local ARM_LENGTH = 3

-- Swing angles in radians; 0 = straight down, negative = tilted back.
local SWING_START = math.rad(-90)
local SWING_IMPACT = math.rad(8)
local SWING_RETRACT = math.rad(-52)
local PHASE_HOLD = 0.07 -- seconds near impact before retracting
local ANIM_TOTAL = 0.85 -- lifetime of the Hammer clone

-- ── Spring helper ──────────────────────────────────────────────────────────
-- Semi-implicit Euler: more stable than explicit at large stiffness values.
-- Returns (newPos, newVel).
local function SpringStep(
	pos: number,
	vel: number,
	target: number,
	stiffness: number,
	damping: number,
	dt: number
): (number, number)
	local force = (target - pos) * stiffness - vel * damping
	vel = vel + force * dt
	pos = pos + vel * dt
	return pos, vel
end

-- ── Hex → world ────────────────────────────────────────────────────────────
-- Flat-top axial. Swap lx/lz formulas for pointy-top grids.
local function HexToWorld(tableModel: Model, q: number, r: number): Vector3
	local pivot = tableModel:GetPivot()
	local lx = HEX_SIZE * 1.5 * q
	local lz = HEX_SIZE * (0.5 * math.sqrt(3) * q + math.sqrt(3) * r)
	return pivot:PointToWorldSpace(Vector3.new(lx, 0, lz))
end

-- ── Hammer swing ──────────────────────────────────────────────────────────
local Hammer = ReplicatedStorage.Assets.Misc.Hammer

local function PlayHammerSwing(tableModel: Model, q: number, r: number): ()
	local tilePos = HexToWorld(tableModel, q, r)
	local tableCenter = tableModel:GetPivot().Position

	-- Swing axis: horizontal, perpendicular to tile→centre.
	-- Arc therefore lives in the vertical plane through the tile.
	local flat = Vector3.new(tableCenter.X - tilePos.X, 0, tableCenter.Z - tilePos.Z)
	local swingAxis: Vector3 = if flat.Magnitude > 0.01
		then flat.Unit:Cross(Vector3.new(0, 1, 0)).Unit
		else Vector3.new(1, 0, 0)

	local pivotPos = tilePos + Vector3.new(0, PIVOT_HEIGHT, 0)

	local angle = SWING_START
	local angleVel = 0.0

	local function GetHammerCFrame(): CFrame
		local rot = CFrame.fromAxisAngle(swingAxis, angle)
		local armDir = rot * Vector3.new(0, -1, 0)
		local center = pivotPos + armDir * (ARM_LENGTH * 0.5)
		return CFrame.new(center) * rot
	end

	local hammer = Hammer:Clone() :: Model
	hammer.Parent = Workspace
	hammer:PivotTo(GetHammerCFrame())

	local retracting = false
	local nearImpactTime = 0.0
	local totalTimer = 0.0

	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function(dt: number)
		totalTimer += dt
		if totalTimer >= ANIM_TOTAL then
			conn:Disconnect()
			hammer:Destroy()
			return
		end

		local target: number
		local stiffness: number
		local damping: number

		if retracting then
			-- Near-critical damping: smooth return, no bounce.
			target = SWING_RETRACT
			stiffness = 105
			damping = 19
		else
			-- Underdamped swing (ζ ≈ 0.51): fast with a small natural
			-- overshoot at impact that reads as a satisfying hit.
			target = SWING_IMPACT
			stiffness = 185
			damping = 14

			if angle >= SWING_IMPACT - math.rad(4) then
				nearImpactTime += dt
				if nearImpactTime >= PHASE_HOLD then
					retracting = true
				end
			end
		end

		angle, angleVel = SpringStep(angle, angleVel, target, stiffness, damping, dt)
		hammer:PivotTo(GetHammerCFrame())
	end)
end

-- ── Module ────────────────────────────────────────────────────────────────

local TableServiceClient = {}

TableServiceClient.ActiveTable = source(nil :: Model?)
TableServiceClient.RoundState = source("Idle" :: TableServerState)
TableServiceClient.CurrentTurnPlayer = source(nil :: Player?)
TableServiceClient.LastResult = source(nil :: { Aborted: boolean }?)

local activeNetworker: any = nil
local activeConnections: { Connection } = {}

local Handlers = {}

function Handlers.OnHammerSwing(_self: any, _player: Player, q: number, r: number): ()
	local tableModel = TableServiceClient.ActiveTable()
	if not tableModel then
		return
	end
	PlayHammerSwing(tableModel, q, r)
end

function Handlers.OnPenguinFall(_self: any, _loser: Player?): ()
	-- TODO: VFX/SFX for penguin falling
end

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
	TableServiceClient.RoundState("Idle")
	TableServiceClient.CurrentTurnPlayer(nil)
	TableServiceClient.LastResult(nil)
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
