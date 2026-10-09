local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)

local Normal = {}
Normal.__index = Normal

export type Normal = typeof(setmetatable(
	{} :: {
		_trove: Trove.Trove,
		Model: Model,
		IsDead: boolean,
		_diedEvent: BindableEvent,
		Died: RBXScriptSignal,
		HeightOffset: number,
	},
	Normal
	))

function Normal.new(model: Model, positionAt: CFrame?): Normal
	local diedEvent = Instance.new("BindableEvent")
	local pivot = model:GetPivot()
	local boundingCFrame, boundingSize = model:GetBoundingBox()
	local bottomY = boundingCFrame.Position.Y - boundingSize.Y / 2

	local self = setmetatable({
		_trove = Trove.new(),
		Model = model,
		IsDead = false,
		_diedEvent = diedEvent,
		Died = diedEvent.Event,
		HeightOffset = pivot.Position.Y - bottomY,
	}, Normal)

	self._trove:Add(model)
	self._trove:Add(diedEvent)

	self.Model.Parent = workspace.Enemies
	if positionAt and typeof(positionAt) == 'CFrame' then
		model:PivotTo(positionAt)
	end

	return self :: Normal
end

function Normal.TakeDamage(self: Normal, amount: number)
	if self.IsDead then return end
	
	local humanoid: Humanoid = self.Model:FindFirstChild("Humanoid")
	if not humanoid then return end

	humanoid:TakeDamage(amount)
	
	if humanoid.Health <= 0 then
		self:Destroy()
	end
end

function Normal.Pathfind(self: Normal, waypoints: Folder)
	local humanoid = self.Model:FindFirstChildOfClass("Humanoid")
	if not humanoid then end

	for i = 2, #waypoints:GetChildren() do
		local waypoint = waypoints:FindFirstChild("Waypoint" .. i)
		if not waypoint or not waypoint:IsA("BasePart") then
			warn("Pathfind: missing waypoint", i)
			continue
		end

		local reached = false
		while not reached and not self.IsDead do
			humanoid:MoveTo(waypoint.Position)
			reached = humanoid.MoveToFinished:Wait()
		end
	end
	
	self:Destroy()
end

function Normal.Move(self: Normal, position: CFrame)
	self.Model:PivotTo(position)
end

function Normal.Destroy(self: Normal)
	if self.IsDead then return end
	self.IsDead = true

	self._diedEvent:Fire()
	self._trove:Destroy()
end

return Normal
