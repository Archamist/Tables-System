local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TabelServiceServer = require(ServerScriptService.Features.Tables.TabelServiceServer)
local DataTemplate = require(ReplicatedStorage.Source.Game.Items.DataTemplate)

local Dataservice = require(ReplicatedStorage.Packages.Dataservice).server
Dataservice:init({
	template = DataTemplate,
	profileStoreIndex = "PRE",
	useMock = false,
	resetData = false,
	dontsave = false,
})

TabelServiceServer:init()
