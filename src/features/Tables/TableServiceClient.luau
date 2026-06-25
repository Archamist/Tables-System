local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)
local Vide = require(Packages.Vide)

local source = Vide.source
local LocalPlayer = Players.LocalPlayer

type TableServerState = "Idle" | "InProgress" | "Ended"
type Connection = { Disconnect: (self: any) -> () }

local TableServiceClient = {}

TableServiceClient.ActiveTable = source(nil :: Model?)
TableServiceClient.RoundState = source("Idle" :: TableServerState)
TableServiceClient.CurrentTurnPlayer = source(nil :: Player?)
TableServiceClient.LastResult = source(nil :: { Aborted: boolean }?)

local activeNetworker: any = nil
local activeConnections: { Connection } = {}

local Handlers = {}

function Handlers.OnHammerSwing(_self: any, _player: Player, _q: number, _r: number): ()
	-- TODO: hammer swing animation/sound
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

	-- Handlers acts as the value store — Networker writes set values directly onto it
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
