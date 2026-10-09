local WaveService = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(ReplicatedStorage.Types)
local Normal = require(ReplicatedStorage.Classes.Normal)
local EnemyService = require(ServerScriptService.Services.EnemyService)

local Wave = {}
Wave.__index = Wave

export type Wave = typeof(setmetatable(
	{} :: {
		_trove: Trove.Trove,
		AliveEnemies: { [Normal.Normal]: boolean },
		RemainingToSpawn: number,
		_finishedEvent: BindableEvent,
		Finished: RBXScriptSignal,
		_destroyed: boolean,
	},
	Wave
	))

local waypoints = workspace.Path.Waypoints

local spawnDelays: { [Types.EnemyType]: number } = {
	Normal = 2.5,
	Boss = 1.5,
	MegaBoss = 2.5,
}

local activeWave: Wave? = nil

function Wave.new()
	local finishedEvent = Instance.new("BindableEvent")
	local self = setmetatable({
		_trove = Trove.new(),
		AliveEnemies = {},
		RemainingToSpawn = 0,
		_finishedEvent = finishedEvent,
		Finished = finishedEvent.Event,
		_destroyed = false,
	}, Wave)
	
	self._trove:Add(finishedEvent)
	
	return self :: Wave
end

function Wave.StartWave(self: Wave, enemiesToSpawn: { [Types.EnemyType]: number })
	for _, amount in pairs(enemiesToSpawn) do
		self.RemainingToSpawn += amount
	end
	
	for enemyType, amount in enemiesToSpawn do
		task.spawn(function()
			for _ = 1, amount do
				self.RemainingToSpawn -= 1
				self:SpawnEnemy(enemyType)
				
				local spawnDelay = spawnDelays[enemyType]
				task.wait(spawnDelay * (0.75 + math.random() * 0.5))
			end
		end)
	end
end

function Wave.SpawnEnemy(self: Wave, enemyType: Types.EnemyType)
	local enemy = EnemyService.SpawnEnemy(enemyType, waypoints.Waypoint1.CFrame * CFrame.new(0, 2.5, 0))
	self.AliveEnemies[enemy] = true
	
	task.spawn(function()
		enemy:Pathfind(waypoints)
	end)
	
	self._trove:Connect(enemy.Died, function()
		self.AliveEnemies[enemy] = nil
		if self:IsFinished() then
			self:Destroy()
		end
	end)
end

function Wave.IsFinished(self: Wave): boolean
	return self.RemainingToSpawn == 0 and not next(self.AliveEnemies)
end

function Wave.Destroy(self: Wave)
	if self._destroyed then return end
	self._destroyed = true

	self._finishedEvent:Fire()
	self._trove:Destroy()
end

local function getLivingHumanoid(enemy: Model): Humanoid?
	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function countEntries(t: {[any]: any}): number
	local n = 0
	for _ in t do n += 1 end
	return n
end

function WaveService.GetClosestEnemy(position: Vector3, attackRadius)
	local best: Normal.Normal? = nil
	local bestDistance = math.huge
	if not activeWave or not activeWave.AliveEnemies or countEntries(activeWave.AliveEnemies) < 1 then return nil end 
	
	for enemy, _ in pairs(activeWave.AliveEnemies) do
		if not getLivingHumanoid(enemy.Model) then continue end

		local distance = (enemy.Model:GetPivot().Position - position).Magnitude
		if distance <= attackRadius and distance < bestDistance then
			best = enemy
			bestDistance = distance
		end
	end

	return best
end

function WaveService.OnStart()
	local waves = {
		{ Normal = 5, Boss = 1},
		{ Normal = 8, Boss = 2 },
		{ Normal = 16, Boss = 5, MegaBoss = 3 },
	}
	
	for i, waveData in ipairs(waves) do
		local wave = Wave.new()
		activeWave = wave

		wave:StartWave(waveData) -- always ensure wave data isn't nil or else the ':Wait()' will yield forever
		wave.Finished:Wait()
		
		activeWave = nil
		print(`Wave {i} finished!`)
		task.wait(3)
	end
	print("All waves completed")
end

return WaveService
