local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local WaveService = require(ServerScriptService.Services.WaveService)

local Types = require(ReplicatedStorage.Types)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Normal = require(ReplicatedStorage.Classes.Normal)

local indicatorTemplate = ReplicatedStorage.Assets.Parts.Indicator
local TowerDataFolder = ReplicatedStorage.Data.TowerData

local RETURN_DELAY = 1.5
local TURN_SPEED = 12
local INDICATOR_THICKNESS = 0.1
local GROUND_OFFSET = 0.05
local MODEL_FACING_OFFSET = CFrame.identity

local Tower = {}
Tower.__index = Tower

export type Tower = typeof(setmetatable(
	{} :: {
		_trove: Trove.Trove,
		_lastSeen: number,
		_detecting: boolean,
		Model: Model,
		Damage: number,
		FireRate: number,
		FireType: Types.FireType,
		LongRange: boolean,
		PlacementRadius: number,
		AttackRadius: number,
		HeightOffset: number,
		BaseRotation: CFrame,
		PlacementIndicator: Part,
		AttackingIndicator: Part,
	},
	Tower
	))

local function makeRing(part: Part, color: Color3)
	part.Transparency = 1

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 5
	stroke.Parent = frame
	stroke.Transparency = 0.75
end

local function makeIndicator(
	model: Model,
	rootPart: BasePart,
	x: number,
	groundY: number,
	z: number,
	radius: number
): Part
	local newIndicator = indicatorTemplate:Clone()

	newIndicator.Anchored = false
	newIndicator.CanCollide = false
	newIndicator.CanQuery = false
	newIndicator.CanTouch = false
	newIndicator.Massless = true

	newIndicator.Size = Vector3.new(INDICATOR_THICKNESS, radius * 2, radius * 2)
	newIndicator.CFrame = CFrame.new(x, groundY, z) * CFrame.Angles(0, 0, math.rad(90))
	newIndicator.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = newIndicator
	weld.Part1 = rootPart
	weld.Parent = newIndicator

	return newIndicator
end

function Tower.new(model: Model, towerName: Types.TowerType): Tower?
	local moduleScript = TowerDataFolder:FindFirstChild(towerName)
	if not moduleScript then
		warn("No tower module for " .. tostring(towerName))
		return nil
	end

	local TowerModule: Types.TowerModule = require(moduleScript)

	local rootPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not rootPart then
		warn(`{model.Name} has no HumanoidRootPart or PrimaryPart to weld indicators to`)
		return nil
	end

	local pivot = model:GetPivot()
	local boundingCFrame, boundingSize = model:GetBoundingBox()
	local bottomY = boundingCFrame.Position.Y - boundingSize.Y / 2

	local placementIndicator = makeIndicator(
		model,
		rootPart,
		pivot.Position.X,
		bottomY + GROUND_OFFSET,
		pivot.Position.Z,
		TowerModule.PlacementRadius
	)

	local attackingIndicator = makeIndicator(
		model,
		rootPart,
		pivot.Position.X,
		bottomY + GROUND_OFFSET * 2,
		pivot.Position.Z,
		TowerModule.AttackRadius
	)
	makeRing(attackingIndicator, Color3.fromRGB(73, 216, 255))

	local self = setmetatable({
		_trove = Trove.new(),
		_lastSeen = 0,
		_detecting = false,
		Model = model,
		Damage = TowerModule.Damage,
		FireRate = TowerModule.FireRate,
		FireType = TowerModule.FireType,
		LongRange = TowerModule.LongRange,
		PlacementRadius = TowerModule.PlacementRadius,
		AttackRadius = TowerModule.AttackRadius,
		HeightOffset = pivot.Position.Y - bottomY,
		BaseRotation = pivot.Rotation,
		PlacementIndicator = placementIndicator,
		AttackingIndicator = attackingIndicator,
	}, Tower)

	self._trove:Add(self.Model)

	return self :: Tower
end

function Tower.PositionAt(self: Tower, position: Vector3, rotationIndex: number?)
	local yaw = math.rad((rotationIndex or 0) * 90)
	self.BaseRotation = CFrame.Angles(0, -yaw, 0)
	self.Model:PivotTo(CFrame.new(position) * self.BaseRotation)
end

function Tower.TurnTowards(self: Tower, goalRotation: CFrame, dt: number)
	local current = self.Model:GetPivot()
	local goal = CFrame.new(current.Position) * goalRotation

	if current.LookVector:Dot(goal.LookVector) > 0.9999 then
		return
	end

	self.Model:PivotTo(current:Lerp(goal, 1 - math.exp(-TURN_SPEED * dt)))
end

function Tower.AttackEnemy(self: Tower, enemy: Normal.Normal)
	enemy:TakeDamage(self.Damage)
end

function Tower.DetectEnemies(self: Tower)
	if self._detecting then
		return
	end
	self._detecting = true

	local cooldown = 1 / self.FireRate
	local lastAttack = 0

	self._trove:Connect(RunService.Heartbeat, function(dt: number)
		local pos = self.Model:GetPivot().Position
		local range = self.AttackRadius

		local target: Normal.Normal? = WaveService.GetClosestEnemy(pos, range)

		if target then
			self._lastSeen = os.clock()

			local enemyPos = target.Model:GetPivot().Position
			local flatTarget = Vector3.new(enemyPos.X, pos.Y, enemyPos.Z)

			if (flatTarget - pos).Magnitude > 0.01 then
				local aim = CFrame.lookAt(pos, flatTarget).Rotation * MODEL_FACING_OFFSET
				self:TurnTowards(aim, dt)
			end

			if os.clock() - lastAttack >= cooldown then
				lastAttack = os.clock()
				self:AttackEnemy(target)
			end
		elseif os.clock() - self._lastSeen > RETURN_DELAY then
			self:TurnTowards(self.BaseRotation, dt)
		end
	end)
end

function Tower.Destroy(self: Tower)
	self._trove:Destroy()
end

return Tower
