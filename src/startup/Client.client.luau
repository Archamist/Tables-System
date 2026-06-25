local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableCameraClient = require(ReplicatedStorage.Source.Features.Tables.TableCameraClient)
local TableServiceClient = require(ReplicatedStorage.Source.Features.Tables.TableServiceClient)
local MountUI = require(script.Parent.MountUI)

local Dataservice = require(ReplicatedStorage.Packages.Dataservice).client
Dataservice:init()

MountUI()

TableServiceClient.Init()
TableCameraClient.Init()
