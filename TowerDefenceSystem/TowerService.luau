local TowerService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local towers = ReplicatedStorage.Assets.Towers

local Types = require(ReplicatedStorage.Types)
local Packets = require(ReplicatedStorage.Utils.Packets)
local HotbarService = require(ServerScriptService.Services.HotbarService)
local Tower = require(ReplicatedStorage.Classes.Tower)
local CanPlace = require(ReplicatedStorage.Utils.CanPlace)

local function raycastDown(origin: Vector3, distance: number?, ignore: {Instance}?): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}

	return workspace:Raycast(origin, Vector3.new(0, -(distance or 25), 0), params)
end

local function verifyData(player: Player, data: {
	Position: Vector3,
	RotationIndex: number,
	})
	
	if typeof(data.Position) ~= "Vector3" or typeof(data.RotationIndex) ~= "number" then return false end
	if data.RotationIndex < 0 or data.RotationIndex > 3 then return false end
	
	local result = raycastDown(data.Position, _, {player.Character})
	if not result or not result.Instance then
		print("Attempted to place tower in air!")
		return false
	end
	
	if result.Instance.Parent ~= workspace.PlaceableArea then
		print("Not placed on placable area!")
		return false
	end
	
	return true
end

local function placeTower(player, data)
	local hotbar = HotbarService.Get(player)
	if not table.find(hotbar, data.TowerName) then
		warn(`{player.Name} doesn't have {data.TowerName} in their hotbar!`)
	end

	local template = towers:FindFirstChild(data.TowerName)
	if not template then 
		warn(`{data.TowerName} doesn't have a template in 'ReplicatedStorage/Assets/Towers/'!`)
		return 
	end
	
	if not verifyData(player, data) then 
		print("Data is incorrect!")
		return
	end
	
	local towerModel = template:Clone()
	
	local tower: Tower.Tower = Tower.new(towerModel, data.TowerName)
	local radius = tower.PlacementRadius
	
	if not CanPlace(data.Position, radius, workspace.PlacedTowers) then
		print("Can't place!")
		return
	end
	
	towerModel:SetAttribute("Radius", radius)
	
	tower.Model.Parent = workspace.PlacedTowers
	tower:PositionAt(data.Position, data.RotationIndex)
	tower:DetectEnemies()
end

Packets.PlaceTower.OnServerEvent:Connect(placeTower)

return TowerService
