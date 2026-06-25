local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local TableServer = require(ServerScriptService.Features.Tables.Classes.TableServer)
type Table = TableServer.Table

local TabelServiceServer = {}

local Tables: { [Model]: Table? } = {}

local function RegisterTable(model: Model): ()
	if Tables[model] then
		return
	end
	Tables[model] = TableServer.new(model)
end

local function UnregisterTable(model: Model): ()
	local tableObj = Tables[model]
	if not tableObj then
		return
	end
	tableObj:Destroy()
	Tables[model] = nil
end

function TabelServiceServer.init(self: TabelServiceServer): ()
	for _, model in CollectionService:GetTagged("Tables") do
		if model:IsA("Model") then
			RegisterTable(model)
		end
	end

	CollectionService:GetInstanceAddedSignal("Tables"):Connect(function(instance)
		if instance:IsA("Model") then
			RegisterTable(instance)
		end
	end)

	CollectionService:GetInstanceRemovedSignal("Tables"):Connect(function(instance)
		if instance:IsA("Model") then
			UnregisterTable(instance)
		end
	end)
end

function TabelServiceServer.GetTable(self: TabelServiceServer, model: Model): Table?
	return Tables[model]
end

export type TabelServiceServer = typeof(TabelServiceServer)

return TabelServiceServer
