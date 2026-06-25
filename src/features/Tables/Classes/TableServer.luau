local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Packages = ReplicatedStorage.Packages
local HexGrid = require(ReplicatedStorage.Source.Features.Tables.Utils.HexGrids)
local Janitor = require(Packages.Janitor)
local Networker = require(Packages.Networker)
local Signal = require(Packages.Signal)

local HEX_RADIUS = 2
local HEX_SIZE = 2.5
local SUPPORT_RADIUS = 1
local HIT_RADIUS = 1
local HAMMER_SWING_TIME = 0.4
local SEAT_RELOCK_DELAY = 3

export type TableState = "Idle" | "InProgress" | "Ended"

type Hex = {
	Part: BasePart,
	Q: number,
	R: number,
	IsSupport: boolean,
	Broken: boolean,
}

local TableServer = {}
TableServer.__index = TableServer

export type Table = typeof(setmetatable(
	{} :: {
		Model: Model,
		Seats: { Seat },
		Occupants: { [Seat]: Player? },
		SeatCount: number,
		OccupiedCount: number,
		State: TableState,
		Hexes: { [string]: Hex },
		SupportRemaining: number,
		Penguin: BasePart?,
		TurnIndex: number,
		_roundToken: number,
		Janitor: Janitor.Janitor,
		RoundJanitor: Janitor.Janitor,
		Networker: any,
		Started: Signal.Signal<()>,
		Ended: Signal.Signal<()>,
	},
	TableServer
))

function TableServer.new(tableModel: Model): Table
	local self = setmetatable({} :: any, TableServer) :: Table
	self.Model = tableModel
	self.Seats = {}
	self.Occupants = {}
	self.SeatCount = 0
	self.OccupiedCount = 0
	self.State = "Idle"
	self.Hexes = {}
	self.SupportRemaining = 0
	self.Penguin = nil
	self.TurnIndex = 1
	self._roundToken = 0
	self.Janitor = Janitor.new()
	self.RoundJanitor = Janitor.new()
	self.Started = Signal.new()
	self.Ended = Signal.new()
	self.Networker = Networker.server.new(tableModel, self :: any)

	for _, descendant in tableModel:GetDescendants() do
		if descendant:IsA("Seat") then
			table.insert(self.Seats, descendant)
			self.SeatCount += 1

			self.Janitor:Add(descendant:GetPropertyChangedSignal("Occupant"):Connect(function()
				self:_onOccupantChanged(descendant)
			end))
		end
	end

	self.Janitor:Add(self.RoundJanitor, "Destroy")
	self.Janitor:Add(self.Started, "Destroy")
	self.Janitor:Add(self.Ended, "Destroy")

	return self
end

function TableServer.GetCurrentPlayer(self: Table): Player?
	local seat = self.Seats[self.TurnIndex]
	return seat and self.Occupants[seat] or nil
end

function TableServer._onOccupantChanged(self: Table, seat: Seat): ()
	local occupant = seat.Occupant
	local player = occupant and Players:GetPlayerFromCharacter(occupant.Parent :: Model)
	local oldPlayer = self.Occupants[seat]
	local wasOccupied = oldPlayer ~= nil

	if player and not wasOccupied and self.State == "InProgress" then
		if occupant then
			occupant.Sit = false
		end
		return
	end

	self.Occupants[seat] = player

	if player and not wasOccupied then
		self.OccupiedCount += 1
	elseif not player and wasOccupied then
		self.OccupiedCount -= 1
	end

	if (self.State :: TableState) == "InProgress" and not player then
		if oldPlayer and oldPlayer.Parent == Players then
			local character = oldPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				self.Occupants[seat] = oldPlayer
				self.OccupiedCount += 1
				seat:Sit(humanoid)
				return
			end
		end

		self:EndGame(true)
		return
	end

	if self.State == "Idle" and self.OccupiedCount >= self.SeatCount then
		task.defer(function()
			if self.State == "Idle" and self.OccupiedCount >= self.SeatCount then
				self.State = "InProgress"
				self:StartGame()
			end
		end)
	end
end

function TableServer.StartGame(self: Table): ()
	self.State = "InProgress"
	self.TurnIndex = 1
	self._roundToken += 1

	for _, seat in self.Seats do
		local occupant = seat.Occupant
		if occupant and occupant:IsA("Humanoid") then
			seat:SetAttribute("OldJumpPower", occupant.JumpPower)
			seat:SetAttribute("OldJumpHeight", occupant.JumpHeight)
			occupant.JumpPower = 0
			occupant.JumpHeight = 0
		end
	end

	self:_generateBoard()

	self.Networker:setAll("State", self.State)
	self.Networker:setAll("CurrentTurnPlayer", self:GetCurrentPlayer())
	self.Started:Fire()
end

function TableServer._generateBoard(self: Table): ()
	local pivot = self.Model:GetPivot()
	local offset = Vector3.new(0, 5, 0)

	self.Hexes = {}
	self.SupportRemaining = 0

	for _, coord in HexGrid.GenerateDisk(HEX_RADIUS) do
		local key = HexGrid.Key(coord.Q, coord.R)
		local distance = HexGrid.Distance(0, 0, coord.Q, coord.R)
		local isSupport = distance <= SUPPORT_RADIUS

		local part = Instance.new("Part")
		part.Name = "Hex_" .. key
		part.Size = Vector3.new(HEX_SIZE * 1.8, 1, HEX_SIZE * 1.8)
		part.Anchored = true
		part.Color = if isSupport then Color3.fromRGB(173, 216, 230) else Color3.fromRGB(220, 240, 250)

		local localPos = HexGrid.AxialToWorld(coord.Q, coord.R, HEX_SIZE) + offset
		part.CFrame = pivot * CFrame.new(localPos)

		self.RoundJanitor:Add(part)
		part.Parent = self.Model

		local clickDetector = Instance.new("ClickDetector")
		clickDetector.MaxActivationDistance = 20
		clickDetector.Parent = part

		self.RoundJanitor:Add(clickDetector.MouseClick:Connect(function(player: Player)
			self:_onHexClicked(key, player)
		end))

		self.Hexes[key] = {
			Part = part,
			Q = coord.Q,
			R = coord.R,
			IsSupport = isSupport,
			Broken = false,
		}

		if isSupport then
			self.SupportRemaining += 1
		end
	end

	local penguin = Instance.new("Part")
	penguin.Name = "Penguin"
	penguin.Shape = Enum.PartType.Ball
	penguin.Size = Vector3.new(3, 3, 3)
	penguin.Color = Color3.fromRGB(245, 245, 245)
	penguin.Anchored = true
	penguin.CFrame = pivot * CFrame.new(offset + Vector3.new(0, 2.5, 0))
	self.RoundJanitor:Add(penguin)
	penguin.Parent = self.Model
	self.Penguin = penguin
end

function TableServer._onHexClicked(self: Table, key: string, player: Player): ()
	if self.State ~= "InProgress" then
		return
	end

	if player ~= self:GetCurrentPlayer() then
		return
	end

	local hex = self.Hexes[key]
	if not hex or hex.Broken then
		return
	end

	self:_swingAndBreak(hex)
end

function TableServer._swingAndBreak(self: Table, hex: Hex): ()
	local roundToken = self._roundToken
	self.Networker:fireAll("OnHammerSwing", self:GetCurrentPlayer(), hex.Q, hex.R)

	task.delay(HAMMER_SWING_TIME, function()
		if self._roundToken ~= roundToken or hex.Broken then
			return
		end

		self:_breakRadius(hex, HIT_RADIUS)

		if self.State == "InProgress" then
			self:_advanceTurn()
		end
	end)
end

function TableServer._advanceTurn(self: Table): ()
	local startingTurn = self.TurnIndex
	repeat
		self.TurnIndex = (self.TurnIndex % #self.Seats) + 1
	until self:GetCurrentPlayer() ~= nil or self.TurnIndex == startingTurn

	self.Networker:setAll("CurrentTurnPlayer", self:GetCurrentPlayer())
end

function TableServer._breakRadius(self: Table, center: Hex, radius: number): ()
	for _, hex in self.Hexes do
		if not hex.Broken and HexGrid.Distance(center.Q, center.R, hex.Q, hex.R) <= radius then
			self:_breakHex(hex)
		end
	end
end

function TableServer._breakHex(self: Table, hex: Hex): ()
	hex.Broken = true
	if hex.IsSupport then
		self.SupportRemaining -= 1
	end

	local part = hex.Part
	part.Anchored = false
	part:ApplyImpulse(Vector3.new((math.random() - 0.5) * 20, -10, (math.random() - 0.5) * 20))
	Debris:AddItem(part, 3)

	if self.SupportRemaining <= 0 and self.State == "InProgress" then
		self:_penguinFalls()
	end
end

function TableServer._penguinFalls(self: Table): ()
	if self.Penguin then
		self.Penguin.Anchored = false
	end

	self.Networker:fireAll("OnPenguinFall", self:GetCurrentPlayer())

	task.delay(1.5, function()
		self:EndGame()
	end)
end

function TableServer.EndGame(self: Table, aborted: boolean?): ()
	if self.State ~= "InProgress" and self.State ~= "Ended" then
		return
	end

	self.State = "Ended"
	self._roundToken += 1
	self.Networker:setAll("State", self.State)
	self.Networker:fireAll("OnRoundEnded", aborted == true)
	self.Ended:Fire()

	for _, seat in self.Seats do
		local occupant = seat.Occupant
		local humanoid = occupant

		if not humanoid then
			local matchedPlayer = self.Occupants[seat]
			local character = matchedPlayer and matchedPlayer.Character
			humanoid = character and character:FindFirstChildOfClass("Humanoid")
		end

		if humanoid then
			humanoid.JumpPower = seat:GetAttribute("OldJumpPower") or 50
			humanoid.JumpHeight = seat:GetAttribute("OldJumpHeight") or 7.2
			humanoid.Sit = false
		end

		seat:SetAttribute("OldJumpPower", nil)
		seat:SetAttribute("OldJumpHeight", nil)
		seat.Disabled = true
	end

	self.RoundJanitor:Cleanup()
	self.Hexes = {}
	self.Penguin = nil

	task.delay(SEAT_RELOCK_DELAY, function()
		for _, seat in self.Seats do
			seat.Disabled = false
		end
		self.State = "Idle"
		self.Networker:setAll("State", self.State)
	end)
end

function TableServer.Destroy(self: Table): ()
	if self.Networker then
		self.Networker:Destroy()
	end
	self.Janitor:Destroy()
end

return TableServer
