--!nonstrict

-- PortableNavigation v2.6 - click to move, with a full settings UI.
--
-- Drop this LocalScript into StarterPlayerScripts, or run it through an
-- executor. Click the ground to walk there. RightShift opens the settings
-- window, RightAlt toggles navigation, X cancels the current route.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local function createNavigationConfig()
local NavigationConfig = {
	Agent = {
		Radius = 2,
		MinPassageRadius = 1.35,
		Height = 5,
		CanJump = true,
		CanClimb = true,
		-- 40 was far below what a Roblox humanoid actually walks. Every downward
		-- probe on a ramp steeper than that returned "no ground", which made the
		-- controller hard stop on ramps and stutter on uneven ground.
		MaxSlopeDegrees = 55,
		UseHumanoidSlopeAngle = true,
		MaxSlopeCeiling = 70,
		WaypointSpacing = 4,
	},
	UpdateRates = {
		PathReplanCooldown = 0.75,
		SegmentRepairCooldown = 0.3,
		ProbeInterval = 0.2,
		ObstacleScanInterval = 0.12,
		GoalDriftThreshold = 6,
	},
	Probe = {
		Angles = { 10, -10, 24, -24, 40, -40, 60, -60, 82, -82 },
		Distances = { 6, 10, 16, 22 },
		MinGain = 2,
		ForcedMinGain = 0.25,
	},
	Shortcut = {
		SampleSpacing = 3,
		SideProbeOffset = 1.5,
		ClearanceProbeOffset = 1.1,
		MinClearanceCheckDistance = 6,
		MaxVerticalSnap = 2.5,
		MaxWalkRise = 3.25,
		MaxWalkDrop = 4,
		MaxRisk = 1.1,
		MissingSidePenalty = 0.45,
		ExposedEdgePenalty = 1.2,
		ClearancePenalty = 1.25,
		SideProbeStride = 2,
	},
	Truss = {
		EntryDepth = 4.5,
		SideClearance = 2.5,
		VerticalProbe = 3,
		TopExitHeight = 6,
		BottomDrop = 6,
		MaxApproachAngleDegrees = 70,
	},
	Climb = {
		Enabled = true,
		LadderTag = "NavigationLadder",
		LadderAttribute = "NavigationLadder",
		PassThroughAttribute = "NavigationPassThrough",
		BlockingAttribute = "NavigationBlocking",
		Speed = 7,
		SurfaceOffset = 1.25,
		ExitOffset = 2,
		MinVerticalTravel = 2,
		TopExitHeight = 4,
		BottomProbeDepth = 5,
		MaxApproachAngleDegrees = 70,
	},
	TargetTracking = {
		Enabled = true,
		Interval = 1,
		MoveThreshold = 1.5,
	},
	Recovery = {
		Enabled = true,
		RetryInterval = 1.5,
		MaxWaitTime = 10,
		OnlyAfterSuccessfulRoute = true,
	},
	Pursuit = {
		Enabled = true,
		VelocityThreshold = 1.5,
		MinPredictionTime = 0.15,
		MaxPredictionTime = 0.7,
		MaxLeadDistance = 8,
		ReplanCooldown = 0.25,
		ReplanDriftThreshold = 2.25,
		RouteGoalSlack = 3,
		TailRefreshDistance = 2,
		ArrivalDistance = 4,
		CompletionVelocityThreshold = 0.75,
		CompletionHoldTime = 0.3,
		BypassCache = true,
	},
	RouteValidation = {
		Enabled = true,
		Interval = 0.3,
		LookAheadNodes = 5,
		LookAheadDistance = 28,
		-- Read by _validateUpcomingRoute via ObstacleDetector:IsNearTruss.
		-- These were missing from the config, so the call silently fell back
		-- to the hardcoded 0 / 3 defaults and could not be tuned per game.
		TrussNodeMinDistance = 0,
		TrussNodeMaxDistance = 3,
	},
	Fallback = {
		GraceTime = 0.4,
		MinProgressDelta = 0.05,
		MaxTrackError = 3.5,
		MinAlignmentDot = 0.45,
	},
	Steering = {
		MaxBlendTurnDegrees = 32,
		MaxBlendRise = 1.25,
	},
	Movement = {
		WaypointReachDistance = 3,
		LookAheadDistance = 5,
		JumpCooldown = 0.45,
		JumpCommitWindow = 0.7,
		HardStopConfirmFrames = 3,
		StuckDistanceEpsilon = 1.5,
		StuckTimeout = 1.25,
		SmallObstacleHeight = 3.5,
		MaxJumpableObstacleHeight = 5.5,
		MaxJumpRise = 5.5,
		MaxJumpDrop = 12,
		GapProbeDistance = 5,
		MaxGapJumpDistance = 9.5,
		JumpProbeDepth = 28,
		JumpSearchStep = 0.75,
		-- A landing only counts once the scan has crossed something worth jumping
		-- over. Without this the search returns the ground the character is
		-- already standing on, and the jump fires straight up on the spot.
		LandingStepTolerance = 1.5,
		LandingScanStart = 1,
		MinJumpProgress = 0.75,
		JumpForceAfterFailures = 3,
		-- Humanoid.Jump is a request the humanoid's own state machine may simply
		-- drop, and it does exactly that in plenty of games. ChangeState is the
		-- authoritative path, so both are issued.
		JumpMethod = "Both",
		GapProbeSamples = 6,
		ActionReevaluateWindow = 1.4,
		ArrivalLockDistance = 7,
		JumpLandingCheckDistances = { 4, 6, 8 },
	},
	-- Task 6: Escalating stuck recovery ladder config.
	StuckRecovery = {
		StuckEnterTime   = 0.6,
		StageTimeout     = 0.5,
		SidestepDistance = 3,
		BackOffDistance  = 2.5,
		MaxStuckTime     = 4,
	},
	Query = {
		MaxPassThroughHits = 24,
	},
	-- String pulling. The raw pathfinder walks the navmesh centre, which swings
	-- wide around every corner; this drags the interior nodes back toward the
	-- straight line until they are CornerClearance studs off the blocker.
	PathSmoothing = {
		Mode = "Taut",
		Passes = 2,
		SearchIterations = 5,
		MinSlack = 0.75,
		MinImprovement = 0.35,
		CornerClearance = 1.5,
		SafetyBias = 0.55,
		GroundSamples = 3,
		DropRedundantNodes = true,
		-- The old smoother probed every node against every later node, so a long
		-- route cost O(n^2) shortcut evaluations and tens of thousands of
		-- raycasts in a single frame. Both caps below exist to stop that.
		MaxLookAheadNodes = 6,
		MaxProbesPerRoute = 900,
		-- Dense waypoints are what makes a long route expensive: the smoother
		-- and the per-frame validator both scale with node count, and nodes a
		-- stud apart carry no information.
		MinNodeSpacing = 2.5,
		MaxNodes = 64,
	},
	-- PathfindingService reports NoPath for anything its navmesh does not join
	-- up, including gaps and offset ledges a player walks across without
	-- thinking. When it refuses, the planner falls back to probing the world
	-- with the same walkability test the follower uses.
	PathFallback = {
		Enabled = true,
		MaxSteps = 48,
		StepDistance = 7,
		MinStepDistance = 3,
		Angles = { 0, 18, -18, 36, -36, 55, -55, 75, -75, 95, -95 },
		ArrivalDistance = 4,
		MinGainRatio = 0.02,
		-- A ratio alone lets a one stud shuffle count as progress on a long route,
		-- and shuffling always looks cheaper than committing to a hop. Requiring
		-- real ground gained is what makes it take the gap instead of pacing at
		-- the edge of it.
		MinAbsoluteGain = 2.5,
		MaxSidesteps = 6,
		VisitCellSize = 3,
		HeadingBias = 0.6,
		-- When walking cannot reach a candidate, the planner asks the emulator
		-- whether the body lands there anyway. A row of ledges with gaps between
		-- them has no ground in between to probe, so this is the only thing that
		-- can plan across it.
		EmulateHops = true,
		-- Running the body forward costs two rays a tick, so it is a last resort
		-- rather than something tried down every angle of the fan. These are the
		-- only directions considered, and the flight is stepped coarsely: a hop
		-- lands inside a second and does not need millisecond resolution.
		HopAngles = { 0, 22, -22, 45, -45 },
		HopStep = 1 / 20,
		HopMaxSteps = 32,
		-- A fallback that gets nowhere is worse than an honest failure: the
		-- controller walks the stub route and reports arrival.
		MinTotalProgress = 6,
	},
	Performance = {
		Preset = "Balanced",
	},
	Hazard = {
		Tag = "Hazard",
		Attribute = "IsHazard",
		NameTokens = { "kill", "lava", "acid", "void", "hazard" },
		ClearanceHeight = 6,
		ProbeDepth = 16,
	},
	-- Trajectory emulation. Runs a stand-in for the character forward under the
	-- game's own gravity, walk speed and jump power to answer whether a step or a
	-- jump actually lands, instead of inferring it from ground probes.
	Emulation = {
		Enabled = true,
		Step = 1 / 30,
		MaxSteps = 90,
		FallLimit = 60,
		-- Raycasts one frame of emulation may spend, kept apart from the planner's
		-- allowance so the two cannot starve each other.
		FrameProbeBudget = 400,
		MaxWalkOffDrop = 8,
		ClearanceProbe = 2,
		-- Run-up left before a jump stops working. While there is this much
		-- slack the jump is not committed, which is what stops it hopping the
		-- instant a gap comes into view.
		CommitMargin = 1.5,
		-- The follower simulates with the speed the body actually has, not the
		-- speed it is aiming for. Jumping from a standstill carries almost no
		-- horizontal velocity and lands where it started, which the optimistic
		-- model could not see: it kept saying the jump clears, the character kept
		-- hopping on the spot, and it took eight seconds to leave the first ledge.
		UseLiveSpeed = true,
		MinLiveSpeed = 1,
		MarginStep = 1.5,
		MarginLimit = 6,
	},
	-- Kill brick awareness. Names and tags only catch what a developer chose to
	-- label; this watches what actually hurts and remembers it. Off by default
	-- because it connects to every character part and to other players.
	KillBricks = {
		Enabled = false,
		LearnFromDamage = true,
		WatchOtherPlayers = true,
		HeuristicScan = true,
		GeneralizeBySignature = true,
		Persist = true,
		-- A part is blamed if it was touched within this many seconds of the hit.
		BlameWindow = 0.4,
		MinDamageFraction = 0.02,
		-- How far a route keeps clear of something known to be lethal.
		AvoidRadius = 4.5,
		MaxLearned = 512,
		ScanBudget = 900,
		ScanInterval = 6,
		RespawnGrace = 1.5,
		AnnounceLearned = true,
	},
	Cache = {
		CellSize = 8,
		TTL = 1.5,
		MaxEntries = 128,
	},
	Debug = {
		Enabled = false,
		FolderName = "NavigationDebug",
		NodeSize = 0.65,
		PathColor = Color3.fromRGB(66, 180, 255),
		NextNodeColor = Color3.fromRGB(104, 255, 148),
		ProbeColor = Color3.fromRGB(255, 223, 95),
		BlockedProbeColor = Color3.fromRGB(255, 110, 110),
		ObstacleColor = Color3.fromRGB(255, 96, 96),
		SteeringColor = Color3.fromRGB(255, 200, 80),
		LandingColor = Color3.fromRGB(120, 255, 120),
		ClimbColor = Color3.fromRGB(180, 120, 255),
		UpdateLifetime = 1.25,
		-- Redrawing the marker pool every step reparents dozens of parts per
		-- frame. Capping it to ~20Hz is invisible and removes the churn.
		DrawInterval = 0.05,
	},

	-- Runtime shell settings (click-to-move front end, not the solver itself).
	Nav = {
		Enabled = true,
		WindowStyle = "Desktop",
		BootSplash = true,
		BootSplashMinTime = 1.4,
		DetailLevel = "Basic",
		ShowDescriptions = false,
		ActivationInput = "MouseButton1",
		RequireModifier = "None",
		LockControls = true,
		ReassertMove = true,
		MoveMethod = "Auto",
		MoveMethodResolved = "Humanoid:Move",
		MoveToLookAhead = 6,
		AutoSwitchTime = 1.5,
		AutoSwitchDistance = 1.5,
		SpeedMode = "Game",
		SpeedMultiplier = 1,
		SpeedAbsolute = 32,
		ApplyWalkSpeed = false,
		WasdThreshold = 0.35,
		WasdBackend = "Auto",
		FaceMoveDirection = true,
		TurnSpeed = 720,
		VelocityMaxForce = 120000,
		CFrameMaxDrift = 3,
		CFrameGroundSnap = true,
		CancelOnManualInput = true,
		StopOnJump = false,
		MaxClickDistance = 0,
		ClickPierce = 10,
		ClickSnapToGround = true,
		ClickIgnoreNonCollidable = true,
		Notifications = true,
		NotificationStyle = "Toast",
		ShowPathWhileMoving = false,
		HoldToRepath = false,
		DoubleClickSprint = false,
		SprintSpeed = 32,
		ToggleUIKey = "RightShift",
		ToggleNavKey = "RightAlt",
		StopKey = "X",
		Theme = "amulet",
		Accent = "blue",
		FontStyle = "inter",
		BlurBackground = true,
		Animations = true,
		AnimationSpeed = 1,
		StatusBar = true,
		LogLevel = "Warn",
	},
}

return table.freeze(NavigationConfig)
end

local NavigationConfig = createNavigationConfig()

-- table.freeze is shallow, so a real deep copy is the only way to keep an
-- untouched reference set. DefaultConfig is the reset target; RuntimeConfig is
-- the single live table every subsystem holds by reference, which is what makes
-- settings edits apply without rebuilding the controller.
local function deepCopyConfig(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, nested in pairs(value) do
		copy[key] = deepCopyConfig(nested)
	end
	return copy
end

local DefaultConfig = deepCopyConfig(NavigationConfig)
local RuntimeConfig = deepCopyConfig(NavigationConfig)
RuntimeConfig.__live = true

local function createNavUtil()
local NavUtil = {}

type RouteNode = {
	Position: Vector3,
	Action: Enum.PathWaypointAction,
}

function NavUtil.ShallowMerge<T>(base: T, overrides: any?): T
	local result = table.clone(base :: any)

	if overrides then
		for key, value in pairs(overrides) do
			local existing = (result :: any)[key]
			if type(existing) == "table" and type(value) == "table" then
				local nested = table.clone(existing)
				for nestedKey, nestedValue in pairs(value) do
					nested[nestedKey] = nestedValue
				end
				(result :: any)[key] = nested
			else
				(result :: any)[key] = value
			end
		end
	end

	return result
end

function NavUtil.CloneNode(node: RouteNode): RouteNode
	return {
		Position = node.Position,
		Action = node.Action,
	}
end

function NavUtil.CloneNodes(nodes: { RouteNode }): { RouteNode }
	local clone = table.create(#nodes)
	for index, node in ipairs(nodes) do
		clone[index] = NavUtil.CloneNode(node)
	end
	return clone
end

function NavUtil.Flatten(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

function NavUtil.SafeUnit(vector: Vector3): Vector3
	local magnitude = vector.Magnitude
	if magnitude <= 1e-4 then
		return Vector3.zero
	end
	return vector / magnitude
end

function NavUtil.AngleDegrees(left: Vector3, right: Vector3): number
	local leftUnit = NavUtil.SafeUnit(NavUtil.Flatten(left))
	local rightUnit = NavUtil.SafeUnit(NavUtil.Flatten(right))
	if leftUnit == Vector3.zero or rightUnit == Vector3.zero then
		return 0
	end
	return math.deg(math.acos(math.clamp(leftUnit:Dot(rightUnit), -1, 1)))
end

function NavUtil.RotateAroundY(direction: Vector3, degrees: number): Vector3
	if direction.Magnitude <= 1e-4 then
		return Vector3.zero
	end
	local rotation = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(degrees))
	return rotation:VectorToWorldSpace(direction.Unit)
end

function NavUtil.Quantize(position: Vector3, cellSize: number): Vector3
	return Vector3.new(
		math.floor(position.X / cellSize + 0.5) * cellSize,
		math.floor(position.Y / cellSize + 0.5) * cellSize,
		math.floor(position.Z / cellSize + 0.5) * cellSize
	)
end

function NavUtil.MakeCacheKey(startPosition: Vector3, goalPosition: Vector3, agentConfig: any, cellSize: number): string
	local startCell = NavUtil.Quantize(startPosition, cellSize)
	local goalCell = NavUtil.Quantize(goalPosition, cellSize)

	return table.concat({
		tostring(startCell.X),
		tostring(startCell.Y),
		tostring(startCell.Z),
		tostring(goalCell.X),
		tostring(goalCell.Y),
		tostring(goalCell.Z),
		tostring(agentConfig.Radius),
		tostring(agentConfig.Height),
		tostring(agentConfig.CanJump),
		tostring(agentConfig.CanClimb),
	}, "|")
end

function NavUtil.GetHumanoid(character: Model?): Humanoid?
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

function NavUtil.GetRootPart(character: Model?): BasePart?
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	if character.PrimaryPart and character.PrimaryPart:IsA("BasePart") then
		return character.PrimaryPart
	end

	return nil
end

function NavUtil.AppendNodes(target: { RouteNode }, source: { RouteNode }, startIndex: number?)
	local startAt = startIndex or 1
	for index = startAt, #source do
		table.insert(target, NavUtil.CloneNode(source[index]))
	end
end

return NavUtil
end

local NavUtil = createNavUtil()

-- ============================================================
-- Task 1: Logger with levels and ring buffer
-- ============================================================

local function createLogger()
	local Logger = {}

	Logger.Level = {
		Verbose = 1,
		Info    = 2,
		Warn    = 3,
		Error   = 4,
	}

	local RING_SIZE = 60
	local _ring = table.create(RING_SIZE)
	local _ringHead = 0
	local _ringCount = 0
	local _consoleLevel = Logger.Level.Warn

	function Logger.setConsoleLevel(level: number)
		_consoleLevel = level
	end

	function Logger.log(level: number, scope: string, message: string)
		-- Always write to ring buffer.
		_ringHead = (_ringHead % RING_SIZE) + 1
		_ring[_ringHead] = {
			Clock   = os.clock(),
			Level   = level,
			Scope   = scope,
			Message = message,
		}
		if _ringCount < RING_SIZE then
			_ringCount += 1
		end

		-- Print to console only when at or above threshold.
		if level >= _consoleLevel then
			local formatted = string.format("[PortableNavigation][%s] %s", scope, message)
			if level >= Logger.Level.Warn then
				warn(formatted)
			else
				print(formatted)
			end
		end
	end

	function Logger.verbose(scope: string, message: string)
		Logger.log(Logger.Level.Verbose, scope, message)
	end

	function Logger.info(scope: string, message: string)
		Logger.log(Logger.Level.Info, scope, message)
	end

	function Logger.warn(scope: string, message: string)
		Logger.log(Logger.Level.Warn, scope, message)
	end

	function Logger.error(scope: string, message: string)
		Logger.log(Logger.Level.Error, scope, message)
	end

	-- Returns up to maxCount most-recent entries, oldest first.
	function Logger.recent(maxCount: number?): { { Clock: number, Level: number, Scope: string, Message: string } }
		local cap = math.min(maxCount or _ringCount, _ringCount)
		local result = table.create(cap)
		-- The ring is filled newest-at-head. Walk backwards to gather, then reverse.
		for offset = cap - 1, 0, -1 do
			local idx = ((_ringHead - 1 - offset) % RING_SIZE) + 1
			local entry = _ring[idx]
			if entry then
				table.insert(result, entry)
			end
		end
		return result
	end

	return Logger
end

local Logger = createLogger()

local DEBUG_CONSOLE_LEVEL = Logger.Level.Warn
Logger.setConsoleLevel(DEBUG_CONSOLE_LEVEL)

-- ============================================================
-- Task 2: DebugRenderer - full pooled, layered implementation
-- ============================================================

local function createDebugRenderer(cfg, _navUtil)

local LAYERS = { "Route", "Rays", "Gaps", "Jumps", "Climb", "Ground" }
local DEFAULT_LAYERS_ON = { Route = true, Rays = true }

local DebugRendererFactory = {}
DebugRendererFactory.__index = DebugRendererFactory

function DebugRendererFactory.new(_options)
	local self = setmetatable({}, DebugRendererFactory)
	self._enabled = false
	self._folder = nil
	-- Pool: list of all created parts; cursor tracks how many used this frame.
	self._pool = {}
	self._cursor = 0
	-- Layer toggles.
	self._layers = {}
	for _, name in ipairs(LAYERS) do
		self._layers[name] = DEFAULT_LAYERS_ON[name] == true
	end
	return self
end

function DebugRendererFactory:SetEnabled(enabled: boolean)
	if enabled == self._enabled then return end
	self._enabled = enabled
	if enabled then
		-- Create the folder in Workspace.
		if not self._folder or not self._folder.Parent then
			local folder = Instance.new("Folder")
			folder.Name = cfg.Debug.FolderName or "NavigationDebug"
			folder.Parent = Workspace
			self._folder = folder
		end
	else
		-- Destroy folder and clear pool.
		if self._folder then
			self._folder:Destroy()
			self._folder = nil
		end
		for _, part in ipairs(self._pool) do
			if part and part.Parent then
				part:Destroy()
			end
		end
		self._pool = {}
		self._cursor = 0
	end
end

function DebugRendererFactory:IsEnabled(): boolean
	return self._enabled
end

function DebugRendererFactory:GetDebugFolder()
	return self._folder
end

function DebugRendererFactory:SetLayer(name: string, on: boolean)
	self._layers[name] = on
end

function DebugRendererFactory:IsLayerOn(name: string): boolean
	return self._layers[name] == true
end

-- Acquire a pooled part (creating if needed). Returns a Part instance.
function DebugRendererFactory:_acquirePart(size: Vector3, color: Color3, shape: Enum.PartType?): Part
	self._cursor += 1
	local part = self._pool[self._cursor]
	-- Reuse the pooled part if the slot is filled. EndFrame unparents unused
	-- parts to hide them, so a nil Parent is normal and must NOT trigger a rebuild;
	-- this method re-parents below, which un-hides the recycled part.
	if not part then
		part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		self._pool[self._cursor] = part
	end
	part.Size = size
	part.Color = color
	part.Shape = shape or Enum.PartType.Block
	part.Parent = self._folder
	return part
end

-- Draw a line between two world points using a thin oriented part.
function DebugRendererFactory:_drawLine(a: Vector3, b: Vector3, color: Color3, thickness: number?)
	local thick = thickness or 0.08
	local delta = b - a
	local dist = delta.Magnitude
	if dist < 0.01 then return end
	local part = self:_acquirePart(Vector3.new(thick, thick, dist), color, Enum.PartType.Block)
	part.CFrame = CFrame.lookAt(a + delta * 0.5, b)
end

-- Draw a sphere marker at a world position.
function DebugRendererFactory:_drawSphere(position: Vector3, color: Color3, radius: number?)
	local r = radius or cfg.Debug.NodeSize or 0.65
	local part = self:_acquirePart(Vector3.new(r * 2, r * 2, r * 2), color, Enum.PartType.Ball)
	part.CFrame = CFrame.new(position)
end

function DebugRendererFactory:BeginFrame()
	if not self._enabled then return end
	-- Reset cursor; parts beyond cursor at EndFrame will be hidden.
	self._cursor = 0
end

function DebugRendererFactory:EndFrame()
	if not self._enabled then return end
	-- Hide/recycle unused pool entries.
	for idx = self._cursor + 1, #self._pool do
		local part = self._pool[idx]
		if part and part.Parent then
			part.Parent = nil
		end
	end
end

function DebugRendererFactory:DrawPath(nodes, nextIndex: number)
	if not self._enabled then return end
	if not self:IsLayerOn("Route") then return end
	if not nodes or #nodes == 0 then return end
	local pathColor = cfg.Debug.PathColor
	local nextColor = cfg.Debug.NextNodeColor
	local nodeSize  = cfg.Debug.NodeSize or 0.65
	for idx = 1, #nodes do
		local node = nodes[idx]
		-- Draw sphere at each node.
		local isNext = (idx == nextIndex)
		local color = if isNext then nextColor else pathColor
		local radius = if isNext then nodeSize * 1.4 else nodeSize
		self:_drawSphere(node.Position, color, radius)
		-- Draw segment line to next node.
		if idx < #nodes then
			self:_drawLine(node.Position, nodes[idx + 1].Position, pathColor, 0.1)
		end
	end
end

function DebugRendererFactory:DrawProbe(origin: Vector3, target: Vector3, blocked: boolean, layer: string?)
	if not self._enabled then return end
	local layerName = layer or "Rays"
	if not self:IsLayerOn(layerName) then return end
	local color = if blocked then cfg.Debug.BlockedProbeColor else cfg.Debug.ProbeColor
	self:_drawLine(origin, target, color, 0.07)
end

function DebugRendererFactory:DrawObstacle(position: Vector3, dynamic: boolean)
	if not self._enabled then return end
	if not self:IsLayerOn("Rays") then return end
	local color = cfg.Debug.ObstacleColor
	self:_drawSphere(position, color, 0.55)
end

function DebugRendererFactory:DrawMarker(position: Vector3, kind: string)
	if not self._enabled then return end
	-- Determine layer by kind.
	local layerName = "Rays"
	local color = cfg.Debug.ProbeColor
	if kind == "Steering" then
		color = cfg.Debug.SteeringColor or Color3.fromRGB(255, 200, 80)
	elseif kind == "Target" then
		color = cfg.Debug.NextNodeColor
	elseif kind == "Landing" then
		layerName = "Jumps"
		color = cfg.Debug.LandingColor or Color3.fromRGB(120, 255, 120)
	end
	if not self:IsLayerOn(layerName) then return end
	self:_drawSphere(position, color, 0.5)
end

function DebugRendererFactory:DrawJump(origin: Vector3, landing: Vector3, safe: boolean)
	if not self._enabled then return end
	if not self:IsLayerOn("Jumps") then return end
	local color = if safe
		then (cfg.Debug.LandingColor or Color3.fromRGB(120, 255, 120))
		else cfg.Debug.BlockedProbeColor
	self:_drawLine(origin, landing, color, 0.1)
	self:_drawSphere(landing, color, 0.55)
end

function DebugRendererFactory:DrawClimb(measurement)
	if not self._enabled then return end
	if not self:IsLayerOn("Climb") then return end
	if not measurement then return end
	local color = cfg.Debug.ClimbColor or Color3.fromRGB(180, 120, 255)
	self:_drawSphere(measurement.EntryPoint, color, 0.55)
	if measurement.TopExitPoint then
		self:_drawSphere(measurement.TopExitPoint, color, 0.45)
		self:_drawLine(measurement.EntryPoint, measurement.TopExitPoint, color, 0.08)
	end
	if measurement.BottomPoint then
		self:_drawSphere(measurement.BottomPoint, Color3.fromRGB(200, 180, 255), 0.45)
	end
end

function DebugRendererFactory:DrawUpdate(position: Vector3, _reason: string)
	if not self._enabled then return end
	-- Short-lived route-update marker. Uses Ground layer as a fallback visual.
	if not self:IsLayerOn("Route") then return end
	self:_drawSphere(position, cfg.Debug.NextNodeColor or Color3.fromRGB(104, 255, 148), 0.45)
end

function DebugRendererFactory:Destroy()
	self:SetEnabled(false)
end

return DebugRendererFactory
end

-- The renderer reads colors straight off the live config, so palette edits made
-- in the settings UI show up on the next drawn frame.
local DebugRenderer = createDebugRenderer(RuntimeConfig, NavUtil)

local function createObstacleDetector(NavigationConfig, NavUtil)
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")


local ObstacleDetector = {}
ObstacleDetector.__index = ObstacleDetector

type TrussMeasurement = {
	EntryClear: boolean,
	SideClear: boolean,
	TopExitClear: boolean,
	BottomSupported: boolean,
	ApproachAligned: boolean,
	ApproachAngle: number,
	EntryPoint: Vector3,
	TopExitPoint: Vector3?,
	BottomPoint: Vector3?,
	Climbable: boolean,
}

type ClimbMeasurement = {
	Kind: string,
	EntryPoint: Vector3,
	FaceNormal: Vector3,
	TopExitPoint: Vector3?,
	BottomPoint: Vector3?,
	ApproachAligned: boolean,
	EntryClear: boolean,
	Climbable: boolean,
}

type ObstacleResult = {
	Blocking: boolean,
	Jumpable: boolean,
	Dynamic: boolean,
	HumanoidBlocker: boolean,
	Height: number?,
	Distance: number?,
	Landing: Vector3?,
	Truss: TrussMeasurement?,
	Climb: ClimbMeasurement?,
	HitKind: string?,
	HitClassName: string?,
	HitModel: Model?,
	Hit: RaycastResult?,
}

type ShortcutEvaluation = {
	Allowed: boolean,
	Risk: number,
	Distance: number,
	Reason: string,
}

function ObstacleDetector.new(character: Model?, options)
	local self = setmetatable({}, ObstacleDetector)
	self._options = options or NavigationConfig
	self._debugRenderer = nil
	self:SetCharacter(character)
	return self
end

function ObstacleDetector:SetCharacter(character: Model?)
	self.Character = character
	self.Humanoid = NavUtil.GetHumanoid(character)
	self.RootPart = NavUtil.GetRootPart(character)
	self._cachedIgnoreList = nil
	self._ignoreListTime = 0
end

function ObstacleDetector:SetDebugRenderer(debugRenderer)
	self._debugRenderer = debugRenderer
end

function ObstacleDetector:ClassifyHit(instance: Instance?): (string?, string?, Model?)
	if not instance then
		return nil, nil, nil
	end

	local humanoidModel = self:_getHumanoidModel(instance)
	if humanoidModel then
		return "Humanoid", instance.ClassName, humanoidModel
	end

	if instance:IsA("TrussPart") then
		return "Truss", instance.ClassName, instance:FindFirstAncestorOfClass("Model")
	end

	local ladderPart = self:_getLadderPart(instance)
	if ladderPart then
		return "Ladder", ladderPart.ClassName, ladderPart:FindFirstAncestorOfClass("Model")
	end

	if instance:IsA("BasePart") then
		return "Part", instance.ClassName, instance:FindFirstAncestorOfClass("Model")
	end

	if instance:IsA("Model") then
		return "Model", instance.ClassName, instance
	end

	return "Instance", instance.ClassName, instance:FindFirstAncestorOfClass("Model")
end

function ObstacleDetector:_getHumanoidModel(instance: Instance?): Model?
	local current = instance
	while current do
		if current:IsA("Model") and current ~= self.Character then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			if humanoid then
				return current
			end
		end
		current = current.Parent
	end

	return nil
end


function ObstacleDetector:_getLadderPart(instance: Instance?): BasePart?
	local current = instance
	while current do
		local isTaggedLadder = false
		if self._options.Climb.LadderAttribute and current:GetAttribute(self._options.Climb.LadderAttribute) == true then
			isTaggedLadder = true
		elseif self._options.Climb.LadderTag and CollectionService:HasTag(current, self._options.Climb.LadderTag) then
			isTaggedLadder = true
		end

		if isTaggedLadder then
			if current:IsA("BasePart") then
				return current
			end
			if current:IsA("Model") then
				local primaryPart = current.PrimaryPart or current:FindFirstChildWhichIsA("BasePart")
				if primaryPart then
					return primaryPart
				end
			end
		end

		current = current.Parent
	end

	return nil
end

function ObstacleDetector:_measureLadder(rootPosition: Vector3, moveDirection: Vector3, ladderPart: BasePart, hitResult: RaycastResult): ClimbMeasurement
	local planarDirection = NavUtil.SafeUnit(NavUtil.Flatten(moveDirection))
	local faceNormal = NavUtil.SafeUnit(NavUtil.Flatten(hitResult.Normal))
	if faceNormal == Vector3.zero then
		faceNormal = -NavUtil.SafeUnit(NavUtil.Flatten(ladderPart.CFrame.LookVector))
	end
	if faceNormal == Vector3.zero then
		faceNormal = -planarDirection
	end

	local entryHeight = math.clamp(rootPosition.Y, ladderPart.Position.Y - ladderPart.Size.Y * 0.45, ladderPart.Position.Y + ladderPart.Size.Y * 0.45)
	local entryPoint = Vector3.new(hitResult.Position.X, entryHeight, hitResult.Position.Z)
	local alignmentDot = 0
	if planarDirection ~= Vector3.zero and faceNormal ~= Vector3.zero then
		alignmentDot = planarDirection:Dot(-faceNormal)
	end
	local approachAligned = alignmentDot >= math.cos(math.rad(self._options.Climb.MaxApproachAngleDegrees))

	local entryTarget = entryPoint + faceNormal * self._options.Climb.SurfaceOffset
	local entryClear = self:HasLineOfSight(rootPosition, entryTarget)
	local topExitOrigin = Vector3.new(ladderPart.Position.X, ladderPart.Position.Y + ladderPart.Size.Y * 0.5 + self._options.Climb.TopExitHeight, ladderPart.Position.Z) + faceNormal * self._options.Climb.ExitOffset
	local topExitPoint = self:FindGroundBelow(topExitOrigin, self._options.Climb.TopExitHeight, self._options.Climb.TopExitHeight * 2)
	local bottomOrigin = Vector3.new(ladderPart.Position.X, ladderPart.Position.Y - ladderPart.Size.Y * 0.5 + self._options.Climb.BottomProbeDepth, ladderPart.Position.Z) + faceNormal * self._options.Climb.ExitOffset
	local bottomPoint = self:FindGroundBelow(bottomOrigin, self._options.Climb.BottomProbeDepth, self._options.Climb.BottomProbeDepth * 2)

	return {
		Kind = "Ladder",
		EntryPoint = entryPoint,
		FaceNormal = if faceNormal == Vector3.zero then Vector3.zAxis else faceNormal,
		TopExitPoint = topExitPoint,
		BottomPoint = bottomPoint,
		ApproachAligned = approachAligned,
		EntryClear = entryClear,
		Climbable = entryClear and approachAligned and (topExitPoint ~= nil or bottomPoint ~= nil),
	}
end
function ObstacleDetector:_getIgnoreList(extraIgnore: { Instance }?): { Instance }
	local now = os.clock()
	local ignoreList = self._cachedIgnoreList

	if not ignoreList or now - self._ignoreListTime > 0.5 then
		ignoreList = {}
		if self.Character then
			table.insert(ignoreList, self.Character)
		end
		if self._debugRenderer and self._debugRenderer:GetDebugFolder() then
			table.insert(ignoreList, self._debugRenderer:GetDebugFolder() :: Instance)
		end
		self._cachedIgnoreList = ignoreList
		self._ignoreListTime = now
	end

	if extraIgnore and #extraIgnore > 0 then
		local merged = table.clone(ignoreList)
		for _, instance in ipairs(extraIgnore) do
			table.insert(merged, instance)
		end
		return merged
	end

	return ignoreList
end

function ObstacleDetector:_buildParams(extraIgnore: { Instance }?): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = self:_getIgnoreList(extraIgnore)
	params.IgnoreWater = false
	return params
end

-- Set by the runtime shell when kill brick awareness is on. Kept as a plain
-- field so the solver has no dependency on the watcher: with nothing installed
-- the detector behaves exactly as it always did.
ObstacleDetector.LethalTest = nil

function ObstacleDetector:IsHazard(instance: Instance?): boolean
	if not instance then
		return false
	end

	local lethalTest = ObstacleDetector.LethalTest
	if lethalTest and lethalTest(instance) then
		return true
	end

	if CollectionService:HasTag(instance, self._options.Hazard.Tag) then
		return true
	end

	local current: Instance? = instance
	while current do
		if current:GetAttribute(self._options.Hazard.Attribute) == true then
			return true
		end
		current = current.Parent
	end

	local loweredName = string.lower(instance.Name)
	for _, token in ipairs(self._options.Hazard.NameTokens) do
		if string.find(loweredName, token, 1, true) then
			return true
		end
	end

	return false
end


function ObstacleDetector:IsPassThrough(instance: Instance?): boolean
	if not instance then
		return true
	end

	if instance:IsA("BasePart") then
		if self:IsHazard(instance) then
			return false
		end

		if instance:GetAttribute(self._options.Climb.PassThroughAttribute) == true then
			return true
		end

		if instance:GetAttribute(self._options.Climb.BlockingAttribute) == true then
			return false
		end

		return not instance.CanCollide
	end

	return false
end
function ObstacleDetector:IsDynamic(instance: Instance?): boolean
	if not instance or not instance:IsA("BasePart") then
		return false
	end

	if self:_getHumanoidModel(instance) then
		return true
	end

	if instance.Anchored then
		return false
	end

	return instance.AssemblyLinearVelocity.Magnitude > 0.5 or instance.AssemblyAngularVelocity.Magnitude > 0.5
end

function ObstacleDetector:_sampleShortcutGround(position: Vector3, referenceY: number?): (Vector3?, RaycastResult?)
	local extraHeight = self._options.Hazard.ClearanceHeight
	if referenceY then
		extraHeight = math.max(extraHeight, math.abs(referenceY - position.Y) + 4)
	end

	local groundPosition, _, hit = self:FindGroundBelow(position, extraHeight, self._options.Movement.JumpProbeDepth)
	if not groundPosition or not hit then
		return nil, hit
	end

	if referenceY then
		local rise = groundPosition.Y - referenceY
		local drop = referenceY - groundPosition.Y
		local span = self._options.Shortcut.SampleSpacing or 4
		if rise > self:RiseAllowance(span) or drop > self:DropAllowance(span) then
			return nil, hit
		end
	end

	return groundPosition, hit
end

function ObstacleDetector:_hasShortcutClearance(startPosition: Vector3, endPosition: Vector3): boolean
	local planarDelta = NavUtil.Flatten(endPosition - startPosition)
	local distance = planarDelta.Magnitude
	local minDistance = self._options.Shortcut.MinClearanceCheckDistance or 0
	if distance < minDistance then
		return true
	end

	local direction = NavUtil.SafeUnit(planarDelta)
	if direction == Vector3.zero then
		return true
	end

	local lateral = Vector3.new(-direction.Z, 0, direction.X)
	local lateralOffset = self._options.Shortcut.ClearanceProbeOffset or (self._options.Agent.Radius * 0.55)
	if lateralOffset <= 0 then
		return true
	end

	local clearanceHeight = math.max(self._options.Agent.Height * 0.45, 2)
	local leftStart = startPosition + Vector3.new(0, clearanceHeight, 0) + lateral * lateralOffset
	local leftEnd = endPosition + Vector3.new(0, clearanceHeight, 0) + lateral * lateralOffset
	if self:Raycast(leftStart, leftEnd - leftStart) ~= nil then
		return false
	end

	local rightStart = startPosition + Vector3.new(0, clearanceHeight, 0) - lateral * lateralOffset
	local rightEnd = endPosition + Vector3.new(0, clearanceHeight, 0) - lateral * lateralOffset
	if self:Raycast(rightStart, rightEnd - rightStart) ~= nil then
		return false
	end

	return true
end

function ObstacleDetector:EvaluateShortcut(startPosition: Vector3, endPosition: Vector3): ShortcutEvaluation
	local planarDelta = NavUtil.Flatten(endPosition - startPosition)
	local distance = planarDelta.Magnitude
	local verticalDelta = math.abs(endPosition.Y - startPosition.Y)
	if distance <= 1e-3 then
		if verticalDelta > (self._options.Shortcut.MaxVerticalSnap or self._options.Shortcut.MaxWalkRise) then
			return {
				Allowed = false,
				Risk = math.huge,
				Distance = 0,
				Reason = "vertical_transition",
			}
		end

		return {
			Allowed = true,
			Risk = 0,
			Distance = 0,
			Reason = "trivial",
		}
	end

	if not self:HasLineOfSight(startPosition, endPosition) then		return {
			Allowed = false,
			Risk = math.huge,
			Distance = distance,
			Reason = "blocked",
		}
	end

	if not self:_hasShortcutClearance(startPosition, endPosition) then
		return {
			Allowed = false,
			Risk = math.huge,
			Distance = distance,
			Reason = "narrow_clearance",
		}
	end

	local currentGround = self:_sampleShortcutGround(startPosition, nil)
	if not currentGround then
		return {
			Allowed = false,
			Risk = math.huge,
			Distance = distance,
			Reason = "no_ground",
		}
	end

	local direction = NavUtil.SafeUnit(planarDelta)
	local lateral = Vector3.new(-direction.Z, 0, direction.X)
	local sampleCount = math.max(1, math.ceil(distance / self._options.Shortcut.SampleSpacing))
	local totalRisk = 0

	for sampleIndex = 1, sampleCount do
		local alpha = sampleIndex / sampleCount
		local samplePosition = startPosition:Lerp(endPosition, alpha)
		local centerGround = self:_sampleShortcutGround(samplePosition, currentGround.Y)
		if not centerGround then
			return {
				Allowed = false,
				Risk = math.huge,
				Distance = distance,
				Reason = "unsupported",
			}
		end

		-- Side probes are the expensive half of this loop (two extra raycasts per
		-- sample), so they run on a stride rather than at every sample.
		local stride = math.max(1, self._options.Shortcut.SideProbeStride or 1)
		if sampleIndex % stride == 0 or sampleIndex == sampleCount then
			local leftGround = self:_sampleShortcutGround(centerGround + lateral * self._options.Shortcut.SideProbeOffset, centerGround.Y)
			local rightGround = self:_sampleShortcutGround(centerGround - lateral * self._options.Shortcut.SideProbeOffset, centerGround.Y)
			if not leftGround and not rightGround then
				totalRisk += self._options.Shortcut.ExposedEdgePenalty * stride
			elseif not leftGround or not rightGround then
				totalRisk += self._options.Shortcut.MissingSidePenalty * stride
			end
		end

		currentGround = centerGround
	end

	return {
		Allowed = totalRisk <= self._options.Shortcut.MaxRisk,
		Risk = totalRisk,
		Distance = distance,
		Reason = if totalRisk <= self._options.Shortcut.MaxRisk then "safe" else "edge_risk",
	}
end
function ObstacleDetector:_measureTruss(rootPosition: Vector3, moveDirection: Vector3, trussPart: TrussPart, hitPosition: Vector3): TrussMeasurement
	local planarDirection = NavUtil.SafeUnit(NavUtil.Flatten(moveDirection))
	local trussLook = NavUtil.SafeUnit(NavUtil.Flatten(trussPart.CFrame.LookVector))
	local trussRight = NavUtil.SafeUnit(NavUtil.Flatten(trussPart.CFrame.RightVector))
	local alignmentDot = 0
	if planarDirection ~= Vector3.zero and trussLook ~= Vector3.zero then
		alignmentDot = math.max(math.abs(planarDirection:Dot(trussLook)), math.abs(planarDirection:Dot(trussRight)))
	end
	local approachAngle = math.deg(math.acos(math.clamp(alignmentDot, -1, 1)))
	local approachAligned = alignmentDot >= math.cos(math.rad(self._options.Truss.MaxApproachAngleDegrees))

	local entryHeight = math.clamp(rootPosition.Y, trussPart.Position.Y - trussPart.Size.Y * 0.45, trussPart.Position.Y + trussPart.Size.Y * 0.45)
	local entryPoint = Vector3.new(hitPosition.X, entryHeight, hitPosition.Z)
	local forwardOffset = if planarDirection == Vector3.zero then Vector3.zero else planarDirection * self._options.Truss.EntryDepth
	local lateral = if trussRight == Vector3.zero then Vector3.new(1, 0, 0) else trussRight

	local frontRay = self:Raycast(entryPoint - forwardOffset + Vector3.new(0, self._options.Truss.VerticalProbe, 0), forwardOffset)
	local entryClear = frontRay ~= nil and frontRay.Instance == trussPart

	local leftBlocked = self:Raycast(entryPoint + lateral * self._options.Truss.SideClearance, Vector3.new(0, -self._options.Truss.VerticalProbe * 2, 0)) == nil
	local rightBlocked = self:Raycast(entryPoint - lateral * self._options.Truss.SideClearance, Vector3.new(0, -self._options.Truss.VerticalProbe * 2, 0)) == nil
	local sideClear = not (leftBlocked and rightBlocked)

	local topExitOrigin = Vector3.new(trussPart.Position.X, trussPart.Position.Y + trussPart.Size.Y * 0.5 + self._options.Truss.TopExitHeight, trussPart.Position.Z)
	local topExitGround = self:FindGroundBelow(topExitOrigin, self._options.Truss.TopExitHeight, self._options.Truss.TopExitHeight * 2)
	local topExitPoint = topExitGround
	local topExitClear = topExitPoint ~= nil and self:HasLineOfSight(topExitOrigin, topExitPoint)

	local bottomOrigin = Vector3.new(trussPart.Position.X, trussPart.Position.Y - trussPart.Size.Y * 0.5 + self._options.Truss.BottomDrop, trussPart.Position.Z)
	local bottomGround = self:FindGroundBelow(bottomOrigin, self._options.Truss.BottomDrop, self._options.Truss.BottomDrop * 2)
	local bottomSupported = bottomGround ~= nil

	return {
		EntryClear = entryClear,
		SideClear = sideClear,
		TopExitClear = topExitClear,
		BottomSupported = bottomSupported,
		ApproachAligned = approachAligned,
		ApproachAngle = approachAngle,
		EntryPoint = entryPoint,
		TopExitPoint = topExitPoint,
		BottomPoint = bottomGround,
		Climbable = entryClear and sideClear and approachAligned and (topExitClear or bottomSupported),
	}
end



-- The walkable slope limit follows the humanoid's own MaxSlopeAngle where the
-- game sets one, clamped into a sane band, so a game that lets players run up
-- steep ramps is not fought by a hardcoded constant.
function ObstacleDetector:MaxSlope(): number
	local configured = self._options.Agent.MaxSlopeDegrees or 55
	if self._options.Agent.UseHumanoidSlopeAngle == false then
		return configured
	end

	local humanoid = self.Character and self.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return configured
	end

	local ceiling = self._options.Agent.MaxSlopeCeiling or 70
	local reported = tonumber(humanoid.MaxSlopeAngle)
	if not reported then
		return configured
	end
	return math.clamp(reported, configured, math.max(configured, ceiling))
end

-- How much height a step of the given horizontal length may gain or lose and
-- still be walked rather than jumped. A flat constant treats every ramp as a
-- cliff once the samples are far enough apart.
function ObstacleDetector:RiseAllowance(horizontalDistance: number): number
	local tangent = math.tan(math.rad(math.min(self:MaxSlope(), 85)))
	return math.max(self._options.Shortcut.MaxWalkRise or 3.25, tangent * math.max(horizontalDistance, 0) + 0.5)
end

function ObstacleDetector:DropAllowance(horizontalDistance: number): number
	local tangent = math.tan(math.rad(math.min(self:MaxSlope(), 85)))
	return math.max(self._options.Shortcut.MaxWalkDrop or 4, tangent * math.max(horizontalDistance, 0) + 0.5)
end

function ObstacleDetector:IsNearTruss(position: Vector3, minDistance: number?, maxDistance: number?): boolean
	local radius = maxDistance or 3
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = self:_getIgnoreList()

	local minAllowed = minDistance or 0
	for _, part in ipairs(Workspace:GetPartBoundsInRadius(position, radius, overlapParams)) do
		if part:IsA("TrussPart") then
			local localPoint = part.CFrame:PointToObjectSpace(position)
			local halfSize = part.Size * 0.5
			local dx = math.max(math.abs(localPoint.X) - halfSize.X, 0)
			local dy = math.max(math.abs(localPoint.Y) - halfSize.Y, 0)
			local dz = math.max(math.abs(localPoint.Z) - halfSize.Z, 0)
			local edgeDistance = Vector3.new(dx, dy, dz).Magnitude
			if edgeDistance >= minAllowed and edgeDistance <= radius then
				return true
			end
		end
	end

	return false
end
function ObstacleDetector:CanTraversePlannedSegment(startPosition: Vector3, endPosition: Vector3, action: Enum.PathWaypointAction?): boolean
	if not self:IsGroundSafe(endPosition) then
		return false
	end

	if action == Enum.PathWaypointAction.Jump then
		local direction = NavUtil.SafeUnit(NavUtil.Flatten(endPosition - startPosition))
		if direction == Vector3.zero then
			return true
		end

		local span = NavUtil.Flatten(endPosition - startPosition).Magnitude
		local landing, _ = self:FindJumpLanding(
			startPosition,
			direction,
			math.max(self._options.Agent.Radius, span * 0.45),
			math.max(self._options.Movement.MaxGapJumpDistance + 2, span + self._options.Agent.Radius * 2)
		)
		if not landing then
			return false
		end

		-- The landing does not have to coincide with the node. A pathfinder jump
		-- node sits at the take off point, so the place the character actually
		-- comes down is routinely several studs past it. Requiring the two to
		-- match declared perfectly ordinary hops invalid, which sent the
		-- controller into a repair and replan loop over the same route.
		local reach = math.max(self._options.Movement.WaypointReachDistance, self._options.Agent.Radius * 1.5)
		local offset = NavUtil.Flatten(landing - endPosition).Magnitude
		return offset <= reach or offset <= span + reach
	end

	local evaluation = self:EvaluateShortcut(startPosition, endPosition)
	return evaluation.Allowed == true
end
-- A fixed-cost walkability test: two body-height sight lines plus a handful of
-- ground samples, regardless of how long the segment is. EvaluateShortcut costs
-- three raycasts per SampleSpacing studs, which is far too expensive to call
-- inside an iterative smoother.
function ObstacleDetector:CanWalkDirect(startPosition: Vector3, endPosition: Vector3, groundSamples: number?): boolean
	local delta = endPosition - startPosition
	local planar = NavUtil.Flatten(delta)
	local distance = planar.Magnitude
	if distance <= 1e-3 then
		return math.abs(delta.Y) <= (self._options.Shortcut.MaxVerticalSnap or 2.5)
	end

	local headHeight = math.max(self._options.Agent.Height * 0.45, 2)
	local kneeHeight = math.max(self._options.Agent.Height * 0.18, 0.75)

	for _, height in ipairs({ headHeight, kneeHeight }) do
		local origin = startPosition + Vector3.new(0, height, 0)
		local target = endPosition + Vector3.new(0, height, 0)
		if self:Raycast(origin, target - origin) then
			return false
		end
	end

	local samples = math.max(1, groundSamples or 3)
	local previousY = startPosition.Y
	for index = 1, samples do
		local alpha = index / samples
		local point = startPosition:Lerp(endPosition, alpha)
		local ground = self:FindGroundBelow(point, self._options.Hazard.ClearanceHeight, self._options.Movement.JumpProbeDepth)
		if not ground then
			return false
		end
		local stride = distance / samples
		local rise = ground.Y - previousY
		if rise > self:RiseAllowance(stride) or -rise > self:DropAllowance(stride) then
			return false
		end
		previousY = ground.Y
	end

	return true
end

-- Finds where a jump would put the character down.
--
-- The scan starts close to the body and walks outward, but a sample only counts
-- as a landing once something worth jumping over has been crossed: a stretch of
-- void, a floor well below the current one, or a ledge above it. Before that
-- fix the scan started at Agent.Radius * 1.1 and happily returned the platform
-- the character was already standing on, so the controller committed to a jump
-- with a "landing" two studs ahead of its own feet. That is what made it hop in
-- place at the near edge of a small gap instead of crossing it.
function ObstacleDetector:FindJumpLanding(
	origin: Vector3,
	moveDirection: Vector3,
	minDistance: number?,
	maxDistance: number?,
	requireDiscontinuity: boolean?
): (Vector3?, number?)
	local direction = NavUtil.SafeUnit(moveDirection)
	if direction == Vector3.zero then
		return nil, nil
	end

	local acceptFrom = math.max(minDistance or (self._options.Agent.Radius * 1.2), self._options.Agent.Radius * 0.75)
	local endDistance = math.max(maxDistance or self._options.Movement.MaxGapJumpDistance, acceptFrom)
	local stepDistance = math.max(self._options.Movement.JumpSearchStep, 0.25)
	local tolerance = self._options.Movement.LandingStepTolerance or 1.5
	local needsDiscontinuity = requireDiscontinuity ~= false

	-- The scan has to begin near the body even when the caller only wants a far
	-- landing, otherwise the discontinuity between here and there is never seen.
	local scanStart = if needsDiscontinuity
		then math.min(acceptFrom, math.max(self._options.Movement.LandingScanStart or 1, stepDistance))
		else acceptFrom

	local standing = self:FindGroundBelow(origin, self._options.Agent.Height, self._options.Movement.JumpProbeDepth)
	local standingY = if standing then standing.Y else (origin.Y - self._options.Agent.Height * 0.5)
	local crossed = not needsDiscontinuity

	local distance = scanStart
	while distance <= endDistance do
		local samplePosition = origin + direction * distance
		local landingPosition, _, hit = self:FindGroundBelow(
			samplePosition,
			self._options.Hazard.ClearanceHeight,
			self._options.Movement.JumpProbeDepth
		)

		if not landingPosition then
			-- Void, a hazard, or ground too steep to stand on. Either way this is
			-- not somewhere to walk, so anything past it has been jumped to.
			crossed = true
		elseif math.abs(landingPosition.Y - standingY) > tolerance then
			crossed = true
		end

		if crossed and landingPosition and hit and distance >= acceptFrom and not self:IsHazard(hit.Instance) then
			local rise = landingPosition.Y - origin.Y
			local drop = origin.Y - landingPosition.Y
			if rise <= self._options.Movement.MaxJumpRise and drop <= self._options.Movement.MaxJumpDrop then
				return landingPosition, distance
			end
		end

		distance += stepDistance
	end

	return nil, nil
end


-- A route computation gets a raycast allowance. Once it runs out the planner
-- stops asking expensive questions and keeps whatever route it already has,
-- which turns a multi-thousand-raycast frame spike into a bounded cost.
function ObstacleDetector:ResetProbeBudget(budget: number?)
	self._probeBudget = budget or math.huge
	self._probeCount = 0
end

-- The route planner spends a whole budget computing a path. The follower's
-- per-frame emulation runs on the same detector, and without its own allowance
-- it inherits an already-empty one: every simulation aborted on its first tick
-- and reported a body that travels zero studs and lands nowhere. That reads as
-- "doomed", which stops the character, which triggers a repair, which spends the
-- budget again. Eighty replans and two hundred repairs later it has not moved.
function ObstacleDetector:PushProbeBudget(budget: number)
	local saved = { budget = self._probeBudget, count = self._probeCount }
	self._probeBudget = budget
	self._probeCount = 0
	return saved
end

function ObstacleDetector:PopProbeBudget(saved)
	if not saved then
		return
	end
	self._probeBudget = saved.budget
	self._probeCount = saved.count
end

function ObstacleDetector:ProbesExhausted(): boolean
	if not self._probeBudget then
		return false
	end
	return (self._probeCount or 0) >= self._probeBudget
end

function ObstacleDetector:ProbeCount(): number
	return self._probeCount or 0
end

-- Query rays skip non-collidable triggers so shortcut checks are not polluted by sensors and FX.
function ObstacleDetector:Raycast(origin: Vector3, direction: Vector3, extraIgnore: { Instance }?): RaycastResult?
	self._probeCount = (self._probeCount or 0) + 1
	local ignoreList = self:_getIgnoreList(extraIgnore)
	local maxPassThroughHits = self._options.Query.MaxPassThroughHits or 24

	for _ = 1, maxPassThroughHits do
		local result = Workspace:Raycast(origin, direction, self:_buildParams(ignoreList))
		if not result then
			return nil
		end

		local hit = result.Instance
		if not self:IsPassThrough(hit) then
			return result
		end

		table.insert(ignoreList, hit)
	end

	return nil
end

function ObstacleDetector:HasLineOfSight(startPosition: Vector3, goalPosition: Vector3, extraIgnore: { Instance }?): boolean
	local direction = goalPosition - startPosition
	if direction.Magnitude <= 1e-3 then
		return true
	end

	local clearance = math.max(self._options.Agent.Height * 0.45, 2)
	local origin = startPosition + Vector3.new(0, clearance, 0)
	local target = goalPosition + Vector3.new(0, clearance, 0)
	local result = self:Raycast(origin, target - origin, extraIgnore)

	return result == nil
end

function ObstacleDetector:FindGroundBelow(position: Vector3, extraHeight: number?, probeDepth: number?): (Vector3?, Vector3?, RaycastResult?)
	local clearanceHeight = extraHeight or self._options.Hazard.ClearanceHeight
	local depth = probeDepth or self._options.Hazard.ProbeDepth
	local origin = position + Vector3.new(0, clearanceHeight, 0)
	local direction = Vector3.new(0, -depth, 0)
	local result = self:Raycast(origin, direction)

	if not result then
		return nil, nil, nil
	end

	if self:IsHazard(result.Instance) then
		return nil, nil, result
	end

	local slopeAngle = math.deg(math.acos(math.clamp(result.Normal:Dot(Vector3.yAxis), -1, 1)))
	if slopeAngle > self:MaxSlope() then
		return nil, result.Normal, result
	end

	return result.Position, result.Normal, result
end

function ObstacleDetector:ProjectToGround(position: Vector3): (Vector3?, Vector3?, RaycastResult?)
	return self:FindGroundBelow(position, self._options.Hazard.ClearanceHeight, self._options.Hazard.ProbeDepth)
end

function ObstacleDetector:IsGroundSafe(position: Vector3): boolean
	local groundPosition = self:ProjectToGround(position)
	if groundPosition == nil then
		return false
	end

	local nearbyTest = ObstacleDetector.LethalNearbyTest
	if nearbyTest and nearbyTest(groundPosition) then
		return false
	end

	return true
end

function ObstacleDetector:GetGroundInfo(position: Vector3)
	local groundPosition, normal, hit = self:ProjectToGround(position)
	if not groundPosition then
		return nil
	end

	return {
		Position = groundPosition,
		Normal = normal,
		Hit = hit,
	}
end

function ObstacleDetector:DetectForwardObstacle(rootCFrame: CFrame, moveDirection: Vector3, lookDistance: number): ObstacleResult
	local direction = NavUtil.SafeUnit(moveDirection)
	if direction == Vector3.zero then
		return {
			Blocking = false,
			Jumpable = false,
			Dynamic = false,
			HumanoidBlocker = false,
			Height = nil,
			Distance = nil,
			Landing = nil,
			Truss = nil,
			Climb = nil,
			HitKind = nil,
			HitClassName = nil,
			HitModel = nil,
			Hit = nil,
		}
	end

	local forwardDistance = math.max(lookDistance, self._options.Agent.Radius * 2.5)
	local rootPosition = rootCFrame.Position
	local lowOrigin = rootPosition + Vector3.new(0, math.max(self._options.Agent.Height * 0.3, 1.5), 0)

	local lowHit = self:Raycast(lowOrigin, direction * forwardDistance)
	if not lowHit then
		return {
			Blocking = false,
			Jumpable = false,
			Dynamic = false,
			HumanoidBlocker = false,
			Height = nil,
			Distance = nil,
			Landing = nil,
			Truss = nil,
			Climb = nil,
			HitKind = nil,
			HitClassName = nil,
			HitModel = nil,
			Hit = nil,
		}
	end

	local hitInstance = lowHit.Instance
	local hitKind, hitClassName, hitModel = self:ClassifyHit(hitInstance)
	local dynamic = self:IsDynamic(hitInstance)
	local humanoidBlocker = self:_getHumanoidModel(hitInstance) ~= nil
	local ladderPart = self:_getLadderPart(hitInstance)
	local isTruss = hitInstance and hitInstance:IsA("TrussPart")
	local isLadder = ladderPart ~= nil and not isTruss
	local trussMeasurement = nil
	local climbMeasurement = nil

	local obstacleTop = lowHit.Position.Y
	if hitInstance and hitInstance:IsA("BasePart") then
		obstacleTop = hitInstance.Position.Y + hitInstance.Size.Y * 0.5
	end

	local currentGround = self:FindGroundBelow(rootPosition, self._options.Agent.Height, self._options.Movement.JumpProbeDepth)
	local referenceGroundY = if currentGround then currentGround.Y else (rootPosition.Y - self._options.Agent.Height * 0.5)
	local obstacleHeight = obstacleTop - referenceGroundY
	local highOrigin = Vector3.new(rootPosition.X, referenceGroundY + self._options.Movement.MaxJumpableObstacleHeight, rootPosition.Z)
	local highHit = self:Raycast(highOrigin, direction * forwardDistance)
	local clearOverTop = highHit == nil or highHit.Instance ~= hitInstance
	local landing = nil

	if isTruss and hitInstance and hitInstance:IsA("TrussPart") then
		trussMeasurement = self:_measureTruss(rootPosition, direction, hitInstance, lowHit.Position)
		local trussFaceNormal = NavUtil.SafeUnit(NavUtil.Flatten(lowHit.Normal))
		if trussFaceNormal == Vector3.zero then
			trussFaceNormal = -direction
		end
		climbMeasurement = {
			Kind = "Truss",
			EntryPoint = trussMeasurement.EntryPoint,
			FaceNormal = trussFaceNormal,
			TopExitPoint = trussMeasurement.TopExitPoint,
			BottomPoint = trussMeasurement.BottomPoint,
			ApproachAligned = trussMeasurement.ApproachAligned,
			EntryClear = trussMeasurement.EntryClear,
			Climbable = trussMeasurement.Climbable,
		}
	elseif isLadder and ladderPart then
		climbMeasurement = self:_measureLadder(rootPosition, direction, ladderPart, lowHit)
	end

	if self._options.Agent.CanJump and not isTruss and not isLadder and not humanoidBlocker and obstacleHeight <= self._options.Movement.MaxJumpableObstacleHeight then
		landing = self:FindJumpLanding(
			rootPosition,
			direction,
			math.max(lowHit.Distance + self._options.Agent.Radius * 0.8, self._options.Agent.Radius * 1.4),
			math.max(self._options.Movement.MaxGapJumpDistance, lowHit.Distance + self._options.Agent.Radius * 2.5)
		)
	end

	local jumpable = self._options.Agent.CanJump
		and not isTruss
		and not isLadder
		and not humanoidBlocker
		and lowHit.Distance <= forwardDistance * 0.9
		and obstacleHeight <= self._options.Movement.MaxJumpableObstacleHeight
		and clearOverTop
		and (landing ~= nil or obstacleHeight <= self._options.Movement.SmallObstacleHeight)

	return {
		Blocking = true,
		Jumpable = jumpable,
		Dynamic = dynamic,
		HumanoidBlocker = humanoidBlocker,
		Height = obstacleHeight,
		Distance = lowHit.Distance,
		Landing = landing,
		Truss = trussMeasurement,
		Climb = climbMeasurement,
		HitKind = hitKind,
		HitClassName = hitClassName,
		HitModel = hitModel,
		Hit = lowHit,
	}
end
function ObstacleDetector:DetectGap(rootPosition: Vector3, moveDirection: Vector3, probeDistance: number)
	local direction = NavUtil.SafeUnit(moveDirection)
	if direction == Vector3.zero then
		return nil
	end

	local aheadDistance = math.max(probeDistance, self._options.Agent.Radius * 1.35)

	-- Sample along the probe, not just at its far end. A single sample at
	-- GapProbeDistance steps clean over any gap narrower than the probe itself,
	-- so a three stud hole was invisible from one stud away and the character
	-- walked straight into it.
	local samples = math.max(2, math.floor(self._options.Movement.GapProbeSamples or 6))
	local near = self._options.Agent.Radius * 0.9
	local gapStart = nil
	for index = 0, samples do
		local distance = near + (aheadDistance - near) * (index / samples)
		if distance > 0 then
			local sampled = self:GetGroundInfo(rootPosition + direction * distance)
			if not sampled then
				gapStart = distance
				break
			end
		end
	end

	if not gapStart then
		return nil
	end

	local ahead = rootPosition + direction * gapStart

	local landingPosition, landingDistance = self:FindJumpLanding(
		rootPosition,
		direction,
		gapStart + self._options.Agent.Radius * 0.3,
		self._options.Movement.MaxGapJumpDistance
	)
	if landingPosition and landingDistance then
		return {
			RequiresJump = self._options.Agent.CanJump,
			Dangerous = false,
			Landing = landingPosition,
			Distance = landingDistance,
		}
	end

	local fallPosition, _, fallHit = self:FindGroundBelow(
		ahead,
		self._options.Hazard.ClearanceHeight,
		self._options.Movement.JumpProbeDepth + self._options.Hazard.ProbeDepth
	)
	local aheadDistanceUsed = gapStart
	local dangerous = true
	if fallPosition then
		dangerous = (rootPosition.Y - fallPosition.Y) > self._options.Movement.MaxJumpDrop
		if fallHit and self:IsHazard(fallHit.Instance) then
			dangerous = true
		end
	end

	return {
		RequiresJump = false,
		Dangerous = dangerous,
		Landing = fallPosition,
		Distance = aheadDistanceUsed,
	}
end

return ObstacleDetector
end

local ObstacleDetector = createObstacleDetector(NavigationConfig, NavUtil)


-- ============================================================================
--  Trajectory emulation
--
--  Instead of asking "is there ground somewhere ahead", this runs the character
--  forward as a physics body: a stand-in with the same walk speed, jump power
--  and gravity the game gives the real one, stepped at a fixed tick, sweeping
--  for walls and probing for floor on the way down. It answers the questions the
--  heuristics could only guess at: does walking off this edge land somewhere or
--  fall forever, would a jump from here clear the gap, and is jumping still
--  optional for another step.
--
--  That last one is the point of "safely, not immediately". A jump is committed
--  at the last tick from which it still lands, not the first tick a gap is
--  visible, which is what made it hop at edges it could have walked around.
-- ============================================================================

local function createTrajectory(NavigationConfig, NavUtil)
local Workspace = game:GetService("Workspace")

local Trajectory = {}
Trajectory.__index = Trajectory

function Trajectory.new(detector, options)
	local self = setmetatable({}, Trajectory)
	self._detector = detector
	self._options = options or NavigationConfig
	return self
end

function Trajectory:SetOptions(options)
	self._options = options
end

function Trajectory:_config()
	return self._options.Emulation or NavigationConfig.Emulation
end

-- Everything the stand-in needs to move the way the real character does. Read
-- fresh each call, so a sprint pad or a low gravity zone is followed rather
-- than baked in at startup.
function Trajectory:Profile(humanoid, rootPart)
	local cfg = self:_config()

	-- Every one of these is read off live instances a game is free to leave
	-- unset, so each falls back to the Roblox default rather than poisoning the
	-- whole simulation with a nil.
	local gravity = tonumber(Workspace.Gravity) or 196.2
	local speed = 16
	local jumpVelocity = 50
	local hipHeight = 2
	local height = self._options.Agent.Height

	if humanoid then
		speed = tonumber(humanoid.WalkSpeed) or speed
		hipHeight = tonumber(humanoid.HipHeight) or hipHeight
		local power = tonumber(humanoid.JumpPower)
		local jumpHeight = tonumber(humanoid.JumpHeight)
		if humanoid.UseJumpPower ~= false and power then
			jumpVelocity = power
		elseif jumpHeight then
			-- v = sqrt(2gh) is the launch speed that reaches JumpHeight exactly.
			jumpVelocity = math.sqrt(2 * gravity * math.max(jumpHeight, 0))
		elseif power then
			jumpVelocity = power
		end
	end

	-- How far the root part rides above the floor it is standing on. HipHeight
	-- plus half the root part, not half of Agent.Height: the configured agent
	-- height is a planning figure and using it here put the modelled feet a stud
	-- and a half under the real ones, so the very first tick of every simulation
	-- found ground and reported an instant landing.
	local rootHalf = 1
	if rootPart then
		local okSize, size = pcall(function()
			return rootPart.Size
		end)
		local half = okSize and size and tonumber(size.Y)
		if half then
			rootHalf = half * 0.5
		end
	end

	return {
		Gravity = gravity,
		Speed = math.max(speed, 0),
		JumpVelocity = math.max(jumpVelocity, 0),
		HipHeight = hipHeight,
		Height = height,
		FootOffset = hipHeight + rootHalf,
		StepTolerance = math.max(hipHeight, 1.5),
		Radius = self._options.Agent.Radius,
		Step = math.max(cfg.Step or (1 / 30), 1 / 240),
		MaxSteps = math.max(math.floor(cfg.MaxSteps or 90), 4),
		FallLimit = cfg.FallLimit or 60,
		ClearanceProbe = cfg.ClearanceProbe or 2,
	}
end

--[[
	Runs the stand-in forward and reports what happens to it.

	origin        where the body starts, in root-part space
	direction     unit heading on the walking plane
	verticalSpeed launch speed; the jump velocity for a jump, 0 for a step off
	profile       from Trajectory:Profile
	options       Speed override, StopAtDistance, CollectPath

	Returns a table:
	  Outcome     "landed" | "fell" | "blocked" | "timeout"
	  Position    where it ended up
	  Normal      the surface it landed on
	  Distance    horizontal studs travelled
	  Time        seconds of flight
	  Drop        how far it fell from the start height
	  PeakHeight  highest point above the start
	  Path        sampled points, when asked for
]]
function Trajectory:Run(origin: Vector3, direction: Vector3, verticalSpeed: number, profile, options)
	options = options or {}
	local detector = self._detector
	local heading = NavUtil.SafeUnit(NavUtil.Flatten(direction))
	local speed = options.Speed or profile.Speed
	local step = profile.Step
	local stopAt = options.StopAtDistance
	local collect = options.CollectPath == true

	local position = origin
	local vertical = verticalSpeed
	local travelled = 0
	local elapsed = 0
	local peak = 0
	local path = if collect then { origin } else nil

	local footOffset = profile.FootOffset or (profile.HipHeight + 1)
	local stepTolerance = profile.StepTolerance or 1.5

	-- A body that starts with no upward speed is standing on something, and it
	-- keeps standing until the floor runs out. Modelling it as ballistic from
	-- tick one made every walk report an instant landing where it already was,
	-- which is no answer at all to "what happens if I keep going".
	local grounded = verticalSpeed <= 0

	local function finish(outcome, extra)
		local result = {
			Outcome = outcome,
			Position = position,
			Distance = travelled,
			Time = elapsed,
			Drop = origin.Y - position.Y,
			PeakHeight = peak,
			Path = path,
		}
		for key, value in pairs(extra or {}) do
			result[key] = value
		end
		return result
	end

	for _ = 1, profile.MaxSteps do
		if detector:ProbesExhausted() then
			return finish("timeout", { Reason = "probe_budget" })
		end

		local previous = position
		local horizontal = heading * speed * step

		if grounded then
			-- Walking. Follow the surface, stepping up and down the way a
			-- humanoid does, until there is nothing left to walk on.
			local candidate = position + Vector3.new(horizontal.X, 0, horizontal.Z)
			local ground, _, hit = detector:FindGroundBelow(
				candidate + Vector3.new(0, stepTolerance, 0),
				0,
				stepTolerance * 2 + footOffset
			)
			if ground and hit and math.abs((ground.Y + footOffset) - position.Y) <= stepTolerance * 1.5 then
				position = Vector3.new(candidate.X, ground.Y + footOffset, candidate.Z)
			else
				-- The floor ran out. From here it is a falling body.
				grounded = false
				vertical = 0
				position = candidate
			end
		else
			vertical -= profile.Gravity * step
			position = previous + Vector3.new(horizontal.X, vertical * step, horizontal.Z)
		end

		elapsed += step
		travelled += horizontal.Magnitude
		peak = math.max(peak, position.Y - origin.Y)

		-- A wall between the last tick and this one stops the body there. Swept
		-- at chest height, which is what a humanoid actually collides with.
		local sweep = position - previous
		if sweep.Magnitude > 1e-4 then
			local chest = Vector3.new(0, profile.Height * 0.25, 0)
			local wall = detector:Raycast(previous + chest, sweep)
			if wall and wall.Instance and wall.Instance.CanCollide then
				local slope = math.deg(math.acos(math.clamp(wall.Normal:Dot(Vector3.yAxis), -1, 1)))
				if slope > detector:MaxSlope() then
					position = wall.Position
					return finish("blocked", { Normal = wall.Normal })
				end
			end
		end

		if collect then
			table.insert(path, position)
		end

		if not grounded and vertical <= 0 then
			local reach = math.max(footOffset + math.abs(vertical) * step + 0.5, footOffset + 1)
			local ground, normal, hit = detector:FindGroundBelow(position, 0.5, reach)
			if ground and hit then
				position = Vector3.new(position.X, ground.Y + footOffset, position.Z)
				return finish("landed", { Ground = ground, Normal = normal, Instance = hit.Instance })
			end
		end

		if origin.Y - position.Y > profile.FallLimit then
			return finish("fell")
		end

		if stopAt and travelled >= stopAt then
			break
		end
	end

	-- Ran out of ticks while still walking on solid ground: that is a good
	-- outcome, not an inconclusive one.
	if grounded then
		local ground, normal, hit = detector:FindGroundBelow(position, stepTolerance, stepTolerance * 2 + footOffset)
		if ground and hit then
			return finish("landed", { Ground = ground, Normal = normal, Instance = hit.Instance })
		end
	end

	return finish("timeout")
end

-- Is this a landing worth committing to? A drop the character survives, ground
-- it can stand on, and nothing lethal underfoot.
function Trajectory:LandingIsGood(result, profile, maxDrop: number?): boolean
	if not result or result.Outcome ~= "landed" then
		return false
	end
	local limit = maxDrop or self._options.Movement.MaxJumpDrop
	if result.Drop > limit then
		return false
	end
	if result.Normal then
		local slope = math.deg(math.acos(math.clamp(result.Normal:Dot(Vector3.yAxis), -1, 1)))
		if slope > self._detector:MaxSlope() then
			return false
		end
	end
	if result.Ground and not self._detector:IsGroundSafe(result.Ground) then
		return false
	end
	return true
end

--[[
	The decision the follower actually needs, once per frame.

	Walks the stand-in forward with no jump, then with one, and reports:
	  WalkSafe      stepping forward from here lands somewhere survivable
	  JumpSafe      jumping from here lands somewhere survivable
	  ShouldJump    walking is not safe and jumping is, so this is the moment
	  Landing       where the jump puts the character down
	  Margin        studs of run-up left before jumping stops working

	Margin is what keeps it from hopping the instant a gap comes into view: while
	the margin is comfortable there is no reason to commit yet.
]]
function Trajectory:Evaluate(origin: Vector3, direction: Vector3, humanoid, options)
	options = options or {}
	local cfg = self:_config()
	if cfg.Enabled == false then
		return nil
	end

	local profile = self:Profile(humanoid, options.RootPart)
	if options.Speed then
		profile.Speed = options.Speed
	end

	local savedBudget = self._detector:PushProbeBudget(cfg.FrameProbeBudget or 400)

	-- Walking and jumping do not run at the same speed, and conflating them is a
	-- trap in both directions. A humanoid accelerates to WalkSpeed in a few
	-- frames, so by the time it reaches an edge it is at full speed: the walk
	-- must be simulated optimistically or the character refuses to set off. A
	-- jump, on the other hand, carries only the horizontal velocity it already
	-- has, so it must be simulated with the live speed or a standstill hop looks
	-- like it clears the gap. Modelling both with one number gave either a
	-- character that hopped on the spot or one that never moved at all.
	local walkProfile = profile
	local jumpProfile = profile
	if options.JumpSpeed and options.JumpSpeed ~= profile.Speed then
		jumpProfile = table.clone(profile)
		jumpProfile.Speed = options.JumpSpeed
	end

	local walk = self:Run(origin, direction, 0, walkProfile, { CollectPath = options.CollectPath })
	local jump = self:Run(origin, direction, jumpProfile.JumpVelocity, jumpProfile, { CollectPath = options.CollectPath })

	local walkSafe = self:LandingIsGood(walk, profile, cfg.MaxWalkOffDrop or self._options.Movement.MaxJumpDrop)
	local jumpSafe = self:LandingIsGood(jump, profile)

	-- How much further the character can walk and still have a jump that lands.
	-- Sampled coarsely: this runs every frame and the answer only needs to be
	-- right to within a stud or so.
	local margin = 0
	if jumpSafe then
		local probeStep = math.max(cfg.MarginStep or 1.5, 0.5)
		local limit = cfg.MarginLimit or 6
		while margin < limit do
			local ahead = origin + direction * (margin + probeStep)
			local later = self:Run(ahead, direction, jumpProfile.JumpVelocity, jumpProfile, {})
			if not self:LandingIsGood(later, profile) then
				break
			end
			margin += probeStep
			if self._detector:ProbesExhausted() then
				break
			end
		end
	end

	local hold = margin >= (cfg.CommitMargin or 1.5)

	self._detector:PopProbeBudget(savedBudget)

	return {
		Profile = profile,
		JumpProfile = jumpProfile,
		Walk = walk,
		Jump = jump,
		WalkSafe = walkSafe,
		JumpSafe = jumpSafe,
		Margin = margin,
		ShouldJump = (not walkSafe) and jumpSafe and not hold,
		CouldJump = jumpSafe,
		Landing = if jumpSafe then jump.Position else nil,
		Doomed = (not walkSafe) and (not jumpSafe),
	}
end

return Trajectory
end

local Trajectory = createTrajectory(NavigationConfig, NavUtil)

local function createPathPlanner(NavigationConfig, NavUtil, Trajectory)
local PathfindingService = game:GetService("PathfindingService")


type RouteNode = { Position: Vector3, Action: Enum.PathWaypointAction }

local PathPlanner = {}
PathPlanner.__index = PathPlanner

-- Shared cache keeps common routes warm for nearby agents in large worlds.
local routeCache: { [string]: { ExpiresAt: number, Nodes: { RouteNode } } } = {}
local cacheOrder = {}

local function trimCache(maxEntries: number)
	while #cacheOrder > maxEntries do
		local oldest = table.remove(cacheOrder, 1)
		routeCache[oldest] = nil
	end
end

local function rememberCacheKey(cacheKey: string)
	for index, value in ipairs(cacheOrder) do
		if value == cacheKey then
			table.remove(cacheOrder, index)
			break
		end
	end
	table.insert(cacheOrder, cacheKey)
end

function PathPlanner.new(obstacleDetector, options)
	local self = setmetatable({}, PathPlanner)
	self._trajectory = Trajectory.new(obstacleDetector, options)
	self._detector = obstacleDetector
	self._options = options or NavigationConfig
	return self
end

function PathPlanner:_createPath(agentRadius: number?)
	return PathfindingService:CreatePath({
		AgentRadius = agentRadius or self._options.Agent.Radius,
		AgentHeight = self._options.Agent.Height,
		AgentCanJump = self._options.Agent.CanJump,
		AgentCanClimb = self._options.Agent.CanClimb,
		WaypointSpacing = self._options.Agent.WaypointSpacing,
		Costs = {
			Hazard = math.huge,
		},
	})
end

function PathPlanner:_cloneRoute(goalPosition: Vector3, nodes: { RouteNode }, revision: number)
	return {
		Goal = goalPosition,
		Nodes = NavUtil.CloneNodes(nodes),
		CreatedAt = os.clock(),
		Revision = revision,
	}
end

function PathPlanner:_rawNodesFromWaypoints(waypoints: { PathWaypoint }): { RouteNode }
	local nodes = table.create(#waypoints)
	for index, waypoint in ipairs(waypoints) do
		nodes[index] = {
			Position = waypoint.Position,
			Action = waypoint.Action,
		}
	end
	return nodes
end

-- Collapses runs of near-coincident waypoints and caps the total, so a long
-- route costs a bounded amount to smooth, validate and follow. A jump waypoint
-- is never merged away: it carries an action the follower needs.
function PathPlanner:_condenseNodes(nodes: { RouteNode }): { RouteNode }
	local cfg = self._options.PathSmoothing
	local minSpacing = cfg.MinNodeSpacing or 0
	local condensed = {}

	for index, node in ipairs(nodes) do
		local last = condensed[#condensed]
		local isJump = node.Action == Enum.PathWaypointAction.Jump
		local isLast = index == #nodes
		if not last or isJump or isLast or (node.Position - last.Position).Magnitude >= minSpacing then
			table.insert(condensed, NavUtil.CloneNode(node))
		elseif isJump then
			last.Action = Enum.PathWaypointAction.Jump
		end
	end

	local maxNodes = cfg.MaxNodes or 0
	if maxNodes > 2 and #condensed > maxNodes then
		local keep = { [1] = true, [#condensed] = true }
		for index, node in ipairs(condensed) do
			if node.Action == Enum.PathWaypointAction.Jump then
				keep[index] = true
			end
		end

		local stride = (#condensed - 1) / (maxNodes - 1)
		local cursor = 1
		while cursor <= #condensed do
			keep[math.floor(cursor + 0.5)] = true
			cursor += stride
		end

		local decimated = {}
		for index, node in ipairs(condensed) do
			if keep[index] then
				table.insert(decimated, node)
			end
		end
		condensed = decimated
	end

	return condensed
end

function PathPlanner:_trimLeadingNode(startPosition: Vector3, nodes: { RouteNode }): { RouteNode }
	local trimmed = {}
	for _, node in ipairs(nodes) do
		if (node.Position - startPosition).Magnitude > self._options.Movement.WaypointReachDistance * 0.5 then
			table.insert(trimmed, NavUtil.CloneNode(node))
		end
	end
	return trimmed
end

function PathPlanner:_canShortcut(startPosition: Vector3, endPosition: Vector3): boolean
	if self._detector:ProbesExhausted() then
		-- Budget spent: fall back to the fixed-cost corridor test instead of
		-- refusing every remaining shortcut, which would leave the route raw.
		return self._detector:CanWalkDirect(startPosition, endPosition, 2)
	end
	local evaluation = self._detector:EvaluateShortcut(startPosition, endPosition)
	return evaluation.Allowed == true
end


function PathPlanner:_hasTightTurn(nodes: { RouteNode }, startIndex: number, endIndex: number): boolean
	if #nodes < 3 then
		return false
	end

	local maxTurn = self._options.Steering.MaxBlendTurnDegrees or 32
	local maxRise = self._options.Steering.MaxBlendRise or 1.25
	for index = math.max(2, startIndex), math.min(#nodes - 1, endIndex) do
		local previous = nodes[index - 1]
		local current = nodes[index]
		local nextNode = nodes[index + 1]
		if math.abs(current.Position.Y - previous.Position.Y) > maxRise
			or math.abs(nextNode.Position.Y - current.Position.Y) > maxRise
		then
			return true
		end

		local turnAngle = NavUtil.AngleDegrees(current.Position - previous.Position, nextNode.Position - current.Position)
		if turnAngle >= maxTurn then
			return true
		end
	end

	return false
end

function PathPlanner:_smoothNodes(nodes: { RouteNode }): { RouteNode }
	if #nodes <= 2 then
		return NavUtil.CloneNodes(nodes)
	end

	local smoothed = { NavUtil.CloneNode(nodes[1]) }
	local currentIndex = 1
	local lookAhead = math.max(1, self._options.PathSmoothing.MaxLookAheadNodes or 6)

	-- Greedily jump to the farthest supported waypoint instead of any visible one.
	-- The probe window is capped: without it this loop is O(n^2) over a raycast
	-- heavy predicate and is the single largest source of frame spikes.
	while currentIndex < #nodes do
		local bestIndex = currentIndex + 1
		local currentNode = nodes[currentIndex]
		local probeLimit = math.min(#nodes, currentIndex + lookAhead)

		if self._detector:ProbesExhausted() then
			-- Out of budget: keep the remaining raw nodes rather than stalling.
			for index = currentIndex + 1, #nodes do
				table.insert(smoothed, NavUtil.CloneNode(nodes[index]))
			end
			return smoothed
		end

		for probeIndex = probeLimit, currentIndex + 1, -1 do
			local candidate = nodes[probeIndex]
			local crossesTightTurn = probeIndex > currentIndex + 1 and self:_hasTightTurn(nodes, currentIndex + 1, probeIndex - 1)
			if not crossesTightTurn and self:_canShortcut(currentNode.Position, candidate.Position) and self._detector:IsGroundSafe(candidate.Position) then
				bestIndex = probeIndex
				break
			end
		end

		local mergedAction = Enum.PathWaypointAction.Walk
		for index = currentIndex + 1, bestIndex do
			if nodes[index].Action == Enum.PathWaypointAction.Jump then
				mergedAction = Enum.PathWaypointAction.Jump
				break
			end
		end

		local chosen = NavUtil.CloneNode(nodes[bestIndex])
		chosen.Action = mergedAction
		table.insert(smoothed, chosen)
		currentIndex = bestIndex
	end

	return smoothed
end

function PathPlanner:_reduceZigZag(nodes: { RouteNode }): { RouteNode }
	if #nodes <= 2 then
		return nodes
	end

	local reduced = { NavUtil.CloneNode(nodes[1]) }

	for index = 2, #nodes - 1 do
		local previous = reduced[#reduced]
		local current = nodes[index]
		local nextNode = nodes[index + 1]
		local segmentA = current.Position - previous.Position
		local segmentB = nextNode.Position - current.Position
		local turnAngle = NavUtil.AngleDegrees(segmentA, segmentB)
		local skipCurrent = false

		if segmentA.Magnitude < 1 then
			skipCurrent = true
		elseif turnAngle <= 12 and not self:_hasTightTurn(nodes, index - 1, index) and self:_canShortcut(previous.Position, nextNode.Position) then
			skipCurrent = true
		end

		if skipCurrent then
			if current.Action == Enum.PathWaypointAction.Jump then
				nextNode.Action = Enum.PathWaypointAction.Jump
			end
		else
			table.insert(reduced, NavUtil.CloneNode(current))
		end
	end

	table.insert(reduced, NavUtil.CloneNode(nodes[#nodes]))
	return reduced
end

-- Closest point on the segment a->b to p, flattened to the walking plane.
local function closestPointOnSegment(a: Vector3, b: Vector3, p: Vector3): Vector3
	local segment = NavUtil.Flatten(b - a)
	local lengthSquared = segment:Dot(segment)
	if lengthSquared <= 1e-6 then
		return a
	end
	local alpha = math.clamp(NavUtil.Flatten(p - a):Dot(segment) / lengthSquared, 0, 1)
	return Vector3.new(a.X + segment.X * alpha, p.Y, a.Z + segment.Z * alpha)
end

-- String pulling. Each interior node is dragged toward the straight line between
-- its neighbours as far as it can go while both halves stay walkable, then eased
-- back by CornerClearance so the route hugs a corner without scraping it. This is
-- what turns the pathfinder's wide navmesh swing into a taut two segment turn.
function PathPlanner:_pullTaut(nodes: { RouteNode }): { RouteNode }
	local cfg = self._options.PathSmoothing
	if cfg.Mode ~= "Taut" or #nodes < 3 then
		return nodes
	end

	local bias = math.clamp(cfg.SafetyBias or 0.5, 0, 1)
	local groundSamples = math.max(1, math.floor((cfg.GroundSamples or 3) + bias * 2 + 0.5))
	local clearance = (cfg.CornerClearance or 1.5) * (0.4 + bias * 1.2)
	local iterations = math.max(1, cfg.SearchIterations or 5)
	local minSlack = cfg.MinSlack or 0.75

	local function walkable(a: Vector3, b: Vector3): boolean
		return self._detector:CanWalkDirect(a, b, groundSamples)
	end

	local function snapToGround(position: Vector3): Vector3?
		local ground = self._detector:FindGroundBelow(
			position,
			self._options.Hazard.ClearanceHeight,
			self._options.Movement.JumpProbeDepth
		)
		return ground
	end

	local function dropRedundant()
		if cfg.DropRedundantNodes == false then
			return
		end
		for index = #nodes - 1, 2, -1 do
			if self._detector:ProbesExhausted() then
				return
			end
			local previous = nodes[index - 1]
			local following = nodes[index + 1]
			if previous.Action ~= Enum.PathWaypointAction.Jump
				and nodes[index].Action ~= Enum.PathWaypointAction.Jump
				and walkable(previous.Position, following.Position)
			then
				table.remove(nodes, index)
			end
		end
	end

	for pass = 1, math.max(1, cfg.Passes or 2) do
		dropRedundant()

		local gained = 0

		for index = 2, #nodes - 1 do
			if self._detector:ProbesExhausted() then
				return nodes
			end

			local previous = nodes[index - 1].Position
			local current = nodes[index].Position
			local following = nodes[index + 1].Position

			local detour = (current - previous).Magnitude + (following - current).Magnitude
			local direct = (following - previous).Magnitude
			if detour - direct >= minSlack then
				local target = closestPointOnSegment(previous, following, current)
				local pullDistance = NavUtil.Flatten(target - current).Magnitude

				if pullDistance > 1e-3 then
					-- Binary search the furthest fraction of the pull that stays walkable.
					local low, high = 0, 1
					local best = current
					for _ = 1, iterations do
						local mid = (low + high) * 0.5
						local candidate = snapToGround(current:Lerp(target, mid))
						if candidate and walkable(previous, candidate) and walkable(candidate, following) then
							best = candidate
							low = mid
						else
							high = mid
						end
					end

					-- Ease back off the blocker by the clearance margin.
					if low > 0 and clearance > 0 then
						local backoff = math.clamp(clearance / pullDistance, 0, low)
						local eased = snapToGround(current:Lerp(target, low - backoff))
						if eased and walkable(previous, eased) and walkable(eased, following) then
							best = eased
						end
					end

					local newDetour = (best - previous).Magnitude + (following - best).Magnitude
					gained += detour - newDetour
					nodes[index].Position = best
				end
			end
		end

		if pass > 1 and gained < (cfg.MinImprovement or 0.35) then
			break
		end
	end

	dropRedundant()

	return nodes
end

function PathPlanner:_tryGetCached(startPosition: Vector3, goalPosition: Vector3)
	local cacheKey = NavUtil.MakeCacheKey(startPosition, goalPosition, self._options.Agent, self._options.Cache.CellSize)
	local cached = routeCache[cacheKey]
	if not cached then
		return nil, cacheKey
	end

	if cached.ExpiresAt < os.clock() then
		routeCache[cacheKey] = nil
		return nil, cacheKey
	end

	return NavUtil.CloneNodes(cached.Nodes), cacheKey
end

function PathPlanner:_storeCache(cacheKey: string, nodes: { RouteNode })
	routeCache[cacheKey] = {
		ExpiresAt = os.clock() + self._options.Cache.TTL,
		Nodes = NavUtil.CloneNodes(nodes),
	}
	rememberCacheKey(cacheKey)
	trimCache(self._options.Cache.MaxEntries)
end

function PathPlanner:_computePathWaypoints(startPosition: Vector3, goalPosition: Vector3, agentRadius: number?): ({ PathWaypoint }?, string?)
	local path = self:_createPath(agentRadius)
	local success, computeError = pcall(function()
		path:ComputeAsync(startPosition, goalPosition)
	end)

	if not success then
		return nil, tostring(computeError)
	end

	if path.Status ~= Enum.PathStatus.Success then
		return nil, tostring(path.Status)
	end

	return path:GetWaypoints(), nil
end

function PathPlanner:_computeBestWaypoints(startPosition: Vector3, goalPosition: Vector3): ({ PathWaypoint }?, string?)
	local waypoints, errorMessage = self:_computePathWaypoints(startPosition, goalPosition, nil)
	if waypoints then
		return waypoints, nil
	end

	local minPassageRadius = self._options.Agent.MinPassageRadius
	if minPassageRadius and minPassageRadius < self._options.Agent.Radius then
		local squeezeWaypoints, squeezeError = self:_computePathWaypoints(startPosition, goalPosition, minPassageRadius)
		if squeezeWaypoints then
			return squeezeWaypoints, nil
		end
		if squeezeError then
			errorMessage = squeezeError
		end
	end

	return nil, errorMessage
end

-- Greedy probe planner. Steps toward the goal, and at each step fans out over
-- the configured angles and distances looking for the reachable point that gets
-- closest to the goal. The edge test is CanWalkDirect, the same predicate the
-- follower uses, so anything a player could walk is considered reachable even
-- when PathfindingService's navmesh says otherwise.
function PathPlanner:_probeRoute(startPosition: Vector3, goalPosition: Vector3): ({ RouteNode }?, string?)
	local cfg = self._options.PathFallback
	if cfg.Enabled == false then
		return nil, "fallback_disabled"
	end

	local detector = self._detector
	local groundSamples = math.max(1, self._options.PathSmoothing.GroundSamples or 3)
	local arrival = cfg.ArrivalDistance or 4
	local maxSteps = cfg.MaxSteps or 28
	local stepDistance = cfg.StepDistance or 7
	local minStep = cfg.MinStepDistance or 3

	local function ground(position: Vector3): Vector3?
		return detector:FindGroundBelow(position, self._options.Hazard.ClearanceHeight, self._options.Movement.JumpProbeDepth)
	end

	local current = ground(startPosition) or startPosition
	local nodes = {}
	local remaining = NavUtil.Flatten(goalPosition - current).Magnitude

	-- Purely greedy probing dead-ends the moment the only way on is sideways,
	-- which is exactly the shape of an offset ledge run. Non-improving steps are
	-- allowed for a bounded stretch, and a coarse visited set stops the search
	-- ping-ponging between two points.
	local visited = {}
	local cellSize = math.max(1, cfg.VisitCellSize or 3)
	local function mark(point: Vector3)
		local cell = NavUtil.Quantize(point, cellSize)
		visited[string.format("%d|%d|%d", cell.X, cell.Y, cell.Z)] = true
	end
	local function seen(point: Vector3): boolean
		local cell = NavUtil.Quantize(point, cellSize)
		return visited[string.format("%d|%d|%d", cell.X, cell.Y, cell.Z)] == true
	end
	mark(current)

	local sidesteps = 0
	local maxSidesteps = cfg.MaxSidesteps or 6
	local heading = nil
	local startRemaining = remaining

	local hopProfile = nil
	if cfg.EmulateHops ~= false and self._trajectory then
		local character = detector.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		hopProfile = self._trajectory:Profile(humanoid, character and character:FindFirstChild("HumanoidRootPart"))
		-- Planning runs the flight coarsely. The follower re-simulates properly
		-- when it actually gets there, so this only has to be right about whether
		-- a landing exists, not about where it is to the inch.
		hopProfile.Step = cfg.HopStep or (1 / 20)
		hopProfile.MaxSteps = math.floor(cfg.HopMaxSteps or 32)
	end

	for _ = 1, maxSteps do
		if detector:ProbesExhausted() then
			break
		end
		if remaining <= arrival then
			break
		end

		local toGoal = NavUtil.SafeUnit(NavUtil.Flatten(goalPosition - current))
		if toGoal == Vector3.zero then
			break
		end

		local reach = math.min(stepDistance, math.max(minStep, remaining))
		local improveThreshold = remaining - math.max(
			(cfg.MinGainRatio or 0.02) * remaining,
			cfg.MinAbsoluteGain or 2.5
		)
		local bestPoint, bestRemaining, bestScore = nil, math.huge, math.huge
		local bestAction = Enum.PathWaypointAction.Walk
		local sidePoint, sideRemaining, sideScore = nil, math.huge, math.huge
		local sideAction = Enum.PathWaypointAction.Walk

		-- Scores one candidate into the best / sideways buckets. Shared so an
		-- emulated hop competes on exactly the same terms as a walked step.
		local function offer(candidate, action)
			if not candidate or seen(candidate) then
				return
			end
			local candidateRemaining = NavUtil.Flatten(goalPosition - candidate).Magnitude
			local direction = NavUtil.SafeUnit(NavUtil.Flatten(candidate - current))
			local momentum = if heading and direction ~= Vector3.zero then direction:Dot(heading) else 1
			local score = candidateRemaining - momentum * (cfg.HeadingBias or 0.6)
			if candidateRemaining < improveThreshold then
				if score < bestScore then
					bestPoint, bestRemaining, bestScore, bestAction = candidate, candidateRemaining, score, action
				end
			elseif score < sideScore then
				sidePoint, sideRemaining, sideScore, sideAction = candidate, candidateRemaining, score, action
			end
		end

		for _, angle in ipairs(cfg.Angles) do
			local direction = NavUtil.RotateAroundY(toGoal, angle)
			if direction ~= Vector3.zero then
				local reached = false
				local distance = reach
				while distance >= minStep do
					local candidate = ground(current + direction * distance)
					if candidate and detector:CanWalkDirect(current, candidate, groundSamples) then
						if seen(candidate) then
							-- Already been here. Shrink instead of abandoning the
							-- whole angle, or the search gives up on its only way on.
							distance -= math.max(1, reach * 0.34)
						else
							-- Ties are broken toward the current heading. Without
							-- it two mirror-image detours look identical and the
							-- search dithers between them.
							offer(candidate, Enum.PathWaypointAction.Walk)
							reached = true
							break
						end
					else
						distance -= math.max(1, reach * 0.34)
					end
				end

			end
			if detector:ProbesExhausted() then
				break
			end
		end

		-- No walking candidate actually advances. Only now is it worth running the
		-- body forward, and only down a handful of headings. Note this fires even
		-- when a sideways shuffle is available: a hop that genuinely gains ground
		-- should win over pacing along the edge, which is what it was doing.
		if not bestPoint and hopProfile then
			for _, angle in ipairs(cfg.HopAngles or { 0 }) do
				if detector:ProbesExhausted() then
					break
				end
				local direction = NavUtil.RotateAroundY(toGoal, angle)
				if direction ~= Vector3.zero then
					local landing, action = self:_hopLanding(current, direction, hopProfile)
					if landing then
						offer(landing, action)
					end
				end
			end
		end

		local chosen, chosenRemaining, chosenAction = bestPoint, bestRemaining, bestAction
		if chosen then
			sidesteps = 0
		elseif sidePoint and sidesteps < maxSidesteps then
			-- Nothing gets closer from here. Take the least bad lateral move and
			-- try again from there; this is what walks around a blocker.
			chosen, chosenRemaining, chosenAction = sidePoint, sideRemaining, sideAction
			sidesteps += 1
		end

		if not chosen then
			break
		end

		mark(chosen)
		heading = NavUtil.SafeUnit(NavUtil.Flatten(chosen - current))
		table.insert(nodes, { Position = chosen, Action = chosenAction })
		current = chosen
		remaining = chosenRemaining
	end

	if #nodes == 0 then
		return nil, "fallback_no_progress"
	end

	-- A route that barely leaves the start is not a route. Handing one back makes
	-- the controller walk two studs and then announce that it arrived.
	if startRemaining - remaining < (cfg.MinTotalProgress or 6) then
		return nil, "fallback_no_progress"
	end

	local goalGround = ground(goalPosition) or goalPosition
	if NavUtil.Flatten(goalGround - current).Magnitude > arrival then
		-- It got closer but not there. A partial route is still worth walking:
		-- the controller replans from the new position when it arrives.
		return nodes, "fallback_partial"
	end

	table.insert(nodes, { Position = goalGround, Action = Enum.PathWaypointAction.Walk })
	return nodes, nil
end

-- Where a hop in this direction actually puts the body down, or nil if it does
-- not put it down anywhere worth being.
--
-- A plain step off the edge is tried first, because falling onto the next ledge
-- is calmer and cheaper than jumping onto it, and only reaches for the jump when
-- the step does not make it. This is the piece that lets the planner cross a row
-- of ledges with gaps between them: there is no ground between them to probe,
-- so probing can never find the way across, but running the body forward can.
function PathPlanner:_hopLanding(origin: Vector3, direction: Vector3, profile)
	local trajectory = self._trajectory
	if not trajectory then
		return nil, nil
	end

	local stepOff = trajectory:Run(origin, direction, 0, profile, {})
	if trajectory:LandingIsGood(stepOff, profile, self._options.Emulation.MaxWalkOffDrop) then
		return stepOff.Position, Enum.PathWaypointAction.Walk
	end

	local hop = trajectory:Run(origin, direction, profile.JumpVelocity, profile, {})
	if trajectory:LandingIsGood(hop, profile) then
		return hop.Position, Enum.PathWaypointAction.Jump
	end

	return nil, nil
end

function PathPlanner:ComputeRoute(startPosition: Vector3, goalPosition: Vector3, overrideOptions)
	local options = overrideOptions or {}
	local revision = options.Revision or 1

	self._detector:ResetProbeBudget(self._options.PathSmoothing.MaxProbesPerRoute)

	if self:_canShortcut(startPosition, goalPosition) and self._detector:IsGroundSafe(goalPosition) then
		return self:_cloneRoute(goalPosition, {
			{
				Position = goalPosition,
				Action = Enum.PathWaypointAction.Walk,
			},
		}, revision)
	end

	local cachedNodes, cacheKey = nil, nil
	if not options.BypassCache then
		cachedNodes, cacheKey = self:_tryGetCached(startPosition, goalPosition)
	end

	if cachedNodes then
		return self:_cloneRoute(goalPosition, cachedNodes, revision)
	end

	local waypoints, errorMessage = self:_computeBestWaypoints(startPosition, goalPosition)
	local rawNodes
	if waypoints then
		rawNodes = self:_rawNodesFromWaypoints(waypoints)
	else
		-- PathfindingService refused. Before failing, try walking it ourselves.
		local probed, probeError = self:_probeRoute(startPosition, goalPosition)
		if not probed then
			return nil, errorMessage or probeError
		end
		rawNodes = probed
	end

	rawNodes = self:_condenseNodes(rawNodes)
	-- The start position is prepended so the first real node can be pulled taut
	-- against where the character actually stands, then trimmed back off below.
	table.insert(rawNodes, 1, { Position = startPosition, Action = Enum.PathWaypointAction.Walk })

	local smoothed = self:_smoothNodes(rawNodes)
	local reduced = self:_reduceZigZag(smoothed)
	local taut = self:_pullTaut(reduced)
	local trimmed = self:_trimLeadingNode(startPosition, taut)

	if #trimmed == 0 then
		trimmed = {
			{
				Position = goalPosition,
				Action = Enum.PathWaypointAction.Walk,
			},
		}
	end

	for index = #trimmed, 1, -1 do
		if self._detector:IsGroundSafe(trimmed[index].Position) then
			break
		end
		table.remove(trimmed, index)
	end

	if #trimmed == 0 then
		return nil, "no_safe_nodes"
	end

	if cacheKey then
		self:_storeCache(cacheKey, trimmed)
	end

	return self:_cloneRoute(goalPosition, trimmed, revision)
end

function PathPlanner:RepairRoute(currentPosition: Vector3, route, nextIndex: number)
	local maxAnchorIndex = math.min(#route.Nodes, nextIndex + 5)

	-- Repair only the blocked front section first, then fall back to a full replan.
	for anchorIndex = maxAnchorIndex, nextIndex, -1 do
		local anchorNode = route.Nodes[anchorIndex]
		if self._detector:IsGroundSafe(anchorNode.Position) then
			local replacement = self:ComputeRoute(currentPosition, anchorNode.Position, {
				BypassCache = true,
				Revision = route.Revision + 1,
			})

			if replacement and #replacement.Nodes > 0 then
				local repairedNodes = NavUtil.CloneNodes(replacement.Nodes)
				for index = anchorIndex + 1, #route.Nodes do
					table.insert(repairedNodes, NavUtil.CloneNode(route.Nodes[index]))
				end

				return {
					Goal = route.Goal,
					Nodes = repairedNodes,
					CreatedAt = os.clock(),
					Revision = route.Revision + 1,
				}
			end
		end
	end

	return self:ComputeRoute(currentPosition, route.Goal, {
		BypassCache = true,
		Revision = route.Revision + 1,
	})
end

return PathPlanner
end

local PathPlanner = createPathPlanner(NavigationConfig, NavUtil, Trajectory)

local function createNavigationProbe(NavigationConfig, NavUtil)
local NavigationProbe = {}
NavigationProbe.__index = NavigationProbe

function NavigationProbe.new(pathPlanner, obstacleDetector, debugRenderer, options)
	local self = setmetatable({}, NavigationProbe)
	self._planner = pathPlanner
	self._detector = obstacleDetector
	self._debug = debugRenderer
	self._options = options or NavigationConfig
	return self
end

function NavigationProbe:_canShortcut(startPosition: Vector3, endPosition: Vector3): boolean
	local evaluation = self._detector:EvaluateShortcut(startPosition, endPosition)
	return evaluation.Allowed == true
end

function NavigationProbe:_routeHasTightTurn(route, startIndex: number, endIndex: number): boolean
	if not route or #route.Nodes < 3 then
		return false
	end

	local maxTurn = self._options.Steering.MaxBlendTurnDegrees or 32
	local maxRise = self._options.Steering.MaxBlendRise or 1.25
	local fromIndex = math.max(2, startIndex)
	local toIndex = math.min(#route.Nodes - 1, endIndex)

	for index = fromIndex, toIndex do
		local previous = route.Nodes[index - 1]
		local current = route.Nodes[index]
		local nextNode = route.Nodes[index + 1]
		if math.abs(current.Position.Y - previous.Position.Y) > maxRise
			or math.abs(nextNode.Position.Y - current.Position.Y) > maxRise
		then
			return true
		end

		local turnAngle = NavUtil.AngleDegrees(current.Position - previous.Position, nextNode.Position - current.Position)
		if turnAngle >= maxTurn then
			return true
		end
	end

	return false
end

function NavigationProbe:_findVisibleRouteNode(origin: Vector3, route, nextIndex: number): number?
	if not route then
		return nil
	end

	for index = #route.Nodes, nextIndex + 1, -1 do
		local node = route.Nodes[index]
		local skipsTightSection = index > nextIndex + 1 and self:_routeHasTightTurn(route, nextIndex, index - 1)
		local visible = not skipsTightSection and self:_canShortcut(origin, node.Position) and self._detector:IsGroundSafe(node.Position)
		if visible then
			return index
		end
	end

	return nil
end

function NavigationProbe:_buildTemporaryRoute(candidatePosition: Vector3, goalPosition: Vector3, spliceIndex: number?)
	local nodes = {
		{
			Position = candidatePosition,
			Action = Enum.PathWaypointAction.Walk,
		},
	}

	if not spliceIndex then
		table.insert(nodes, {
			Position = goalPosition,
			Action = Enum.PathWaypointAction.Walk,
		})
	end

	return {
		Nodes = nodes,
		SpliceIndex = spliceIndex,
	}
end

function NavigationProbe:Scan(state)
	local origin = state.Position
	local goal = state.Goal
	local route = state.Route
	local tightLocalRoute = route and self:_routeHasTightTurn(route, state.NextIndex, math.min(#route.Nodes - 1, state.NextIndex + 2))
	local minGain = if state.Force then self._options.Probe.ForcedMinGain or 0 else self._options.Probe.MinGain

	if not tightLocalRoute and self:_canShortcut(origin, goal) and self._detector:IsGroundSafe(goal) then
		return {
			Type = "DirectGoal",
		}
	end

	local shortcutIndex = self:_findVisibleRouteNode(origin, route, state.NextIndex)
	if shortcutIndex then
		return {
			Type = "RouteShortcut",
			ShortcutIndex = shortcutIndex,
		}
	end

	if tightLocalRoute then
		return nil
	end

	local moveDirection = state.MoveDirection
	if moveDirection.Magnitude <= 1e-3 then
		moveDirection = goal - origin
	end
	moveDirection = NavUtil.SafeUnit(moveDirection)

	if moveDirection == Vector3.zero then
		return nil
	end

	local bestCandidate = nil
	local currentDistance = (goal - origin).Magnitude

	-- Fan probes outward from the current heading so the controller can opportunistically detour or shortcut.
	for _, angle in ipairs(self._options.Probe.Angles) do
		local probeDirection = NavUtil.RotateAroundY(moveDirection, angle)

		for _, distance in ipairs(self._options.Probe.Distances) do
			local probePoint = origin + probeDirection * distance
			local groundPosition = self._detector:ProjectToGround(probePoint)

			if groundPosition then
				local clearFromOrigin = self:_canShortcut(origin, groundPosition)
				if self._debug then
					self._debug:DrawProbe(origin, groundPosition, not clearFromOrigin)
				end

				if clearFromOrigin then
					if self:_canShortcut(groundPosition, goal) then
						local gain = currentDistance - (goal - groundPosition).Magnitude
						if gain >= minGain then
							local score = gain - math.abs(angle) * 0.05
							if not bestCandidate or score > bestCandidate.Score then
								bestCandidate = {
									Score = score,
									Route = self:_buildTemporaryRoute(groundPosition, goal, nil),
								}
							end
						end
					elseif route then
						local spliceIndex = self:_findVisibleRouteNode(groundPosition, route, state.NextIndex)
						if spliceIndex then
							local gain = currentDistance - (route.Nodes[spliceIndex].Position - groundPosition).Magnitude
							local score = gain - math.abs(angle) * 0.08
							if gain >= minGain and (not bestCandidate or score > bestCandidate.Score) then
								bestCandidate = {
									Score = score,
									Route = self:_buildTemporaryRoute(groundPosition, goal, spliceIndex),
								}
							end
						end
					end
				end
			elseif self._debug then
				self._debug:DrawProbe(origin, probePoint, true)
			end
		end
	end

	return if bestCandidate then {
		Type = "TemporaryRoute",
		Route = bestCandidate.Route,
	} else nil
end

return NavigationProbe
end

local NavigationProbe = createNavigationProbe(NavigationConfig, NavUtil)

local function createMovementController(NavUtil, Trajectory)
local MovementController = {}
MovementController.__index = MovementController

local function emptyObstacle()
	return {
		Blocking = false,
		Jumpable = false,
		Dynamic = false,
		HumanoidBlocker = false,
		Height = nil,
		Distance = nil,
		Landing = nil,
		Truss = nil,
		Climb = nil,
		HitKind = nil,
		HitClassName = nil,
		HitModel = nil,
		Hit = nil,
	}
end

function MovementController.new(character: Model?, obstacleDetector, options)
	local self = setmetatable({}, MovementController)
	self._detector = obstacleDetector
	self._options = options
	self._trajectory = Trajectory.new(obstacleDetector, options)
	self._lastJumpTime = 0
	self._jumpCommitUntil = 0
	self._jumpEvalFailures = 0
	self._jumpFailureAt = nil
	self._jumpHoldSince = nil
	self._progressAnchor = nil
	self._progressTime = 0
	self._stuck = false
	self._lastTrackSample = nil
	self._trackFallbackUntil = 0
	self._climbState = nil
	-- Task 6: Escalating stuck recovery state.
	self._stuckSince = nil
	self._recoveryStage = "None"
	self._recoveryStageStart = 0
	self:SetCharacter(character)
	return self
end

function MovementController:SetCharacter(character: Model?)
	self.Character = character
	self.Humanoid = NavUtil.GetHumanoid(character)
	self.RootPart = NavUtil.GetRootPart(character)
end

-- Every movement command in this class funnels through _move so the last
-- commanded direction can be re-asserted right before the physics step. Roblox
-- runs the default ControlModule on RenderStepped, which is AFTER our Heartbeat
-- write in frame order, so without a re-assert the control script's zero vector
-- is what physics actually sees and the character never leaves the spot.
-- The runtime shell installs MovementController.MoveApplier so the actual way a
-- direction reaches the character is swappable. Humanoid:Move is fine in most
-- places but some games override it, run a custom controller, or reset
-- MoveDirection every frame, and then nothing happens at all.
function MovementController:_move(direction: Vector3)
	local humanoid = self.Humanoid
	if not humanoid then
		return
	end
	self._commandedMove = direction
	self._commandedAt = os.clock()

	local applier = MovementController.MoveApplier
	if applier then
		applier(self, humanoid, direction, false)
	else
		humanoid:Move(direction, false)
	end
end

-- Called from the pre-physics Stepped hook owned by the runtime shell.
function MovementController:ReassertMove()
	local humanoid = self.Humanoid
	if not humanoid or not self._commandedMove then
		return
	end

	local applier = MovementController.MoveApplier
	if applier then
		applier(self, humanoid, self._commandedMove, true)
	else
		humanoid:Move(self._commandedMove, false)
	end
end

function MovementController:ClearMove()
	self._commandedMove = nil
	self._commandedAt = nil
end

function MovementController:_isAirborne(humanoid: Humanoid): boolean
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Swimming then
		return false
	end

	if state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Freefall
		or state == Enum.HumanoidStateType.FallingDown
	then
		return true
	end

	return humanoid.FloorMaterial == Enum.Material.Air
end

function MovementController:_resetTrackFallback()
	self._lastTrackSample = nil
	self._trackFallbackUntil = 0
end

function MovementController:_clearClimbState()
	self._climbState = nil
end

function MovementController:_updateTrackFallback(position: Vector3, steeringTarget: Vector3, distanceToWaypoint: number, moveDirection: Vector3): boolean
	local now = os.clock()
	local lastSample = self._lastTrackSample
	if lastSample and moveDirection ~= Vector3.zero then
		local progress = lastSample.DistanceToWaypoint - distanceToWaypoint
		local actualDisplacement = NavUtil.Flatten(position - lastSample.Position)
		local actualDirection = NavUtil.SafeUnit(actualDisplacement)
		local alignment = 1
		if actualDirection ~= Vector3.zero then
			alignment = actualDirection:Dot(moveDirection)
		end

		local expectedSegment = NavUtil.Flatten(steeringTarget - lastSample.Position)
		local lateralError = NavUtil.Flatten(position - steeringTarget).Magnitude
		if expectedSegment.Magnitude > 1e-3 then
			local expectedLengthSquared = expectedSegment:Dot(expectedSegment)
			local offset = NavUtil.Flatten(position - lastSample.Position)
			local alpha = math.clamp(offset:Dot(expectedSegment) / expectedLengthSquared, 0, 1)
			local closestPoint = Vector3.new(
				lastSample.Position.X + expectedSegment.X * alpha,
				position.Y,
				lastSample.Position.Z + expectedSegment.Z * alpha
			)
			lateralError = NavUtil.Flatten(position - closestPoint).Magnitude
		end

		if progress >= self._options.Fallback.MinProgressDelta
			and lateralError <= self._options.Fallback.MaxTrackError
			and alignment >= self._options.Fallback.MinAlignmentDot
		then
			self._trackFallbackUntil = now + self._options.Fallback.GraceTime
		end
	end

	self._lastTrackSample = {
		Position = position,
		DistanceToWaypoint = distanceToWaypoint,
	}

	return now <= self._trackFallbackUntil
end

function MovementController:IsAirborne(): boolean
	local humanoid = self.Humanoid
	if not humanoid then
		return false
	end

	return self:_isAirborne(humanoid)
end

function MovementController:_tryJump()
	if not self.Humanoid then
		return false
	end

	local now = os.clock()
	if now - self._lastJumpTime < self._options.Movement.JumpCooldown then
		return false
	end

	local method = self._options.Movement.JumpMethod or "Both"
	local humanoid = self.Humanoid
	local before = if self.RootPart then self.RootPart.Position.Y else 0

	-- Humanoid.Jump on its own is not reliable. It is a request flag the state
	-- machine reads at its own discretion, and when something else owns the
	-- character's control path it is routinely dropped without a single state
	-- change: the controller believes it jumped, nothing moves, and it settles
	-- into evaluate, refuse, replan over the same node. ChangeState performs the
	-- jump directly, so it is issued as well.
	if method ~= "ChangeState" then
		pcall(function()
			humanoid.Jump = true
		end)
	end
	if method ~= "Jump" then
		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end)
	end

	self._lastJumpTime = now
	self._jumpCommitUntil = now + self._options.Movement.JumpCommitWindow
	self._jumpEvalFailures = 0
	self._jumpFailureAt = nil
	self._jumpHoldSince = nil
	self._jumpTakeoffY = before
	return true
end

function MovementController:_updateStuck(position: Vector3, dt: number, moving: boolean)
	if not moving then
		self._progressAnchor = position
		self._progressTime = 0
		self._stuck = false
		-- Reset stuck-since and recovery stage when not trying to move.
		self._stuckSince = nil
		self._recoveryStage = "None"
		self._recoveryStageStart = 0
		return
	end

	if not self._progressAnchor then
		self._progressAnchor = position
	end

	self._progressTime += dt
	if (position - self._progressAnchor).Magnitude >= self._options.Movement.StuckDistanceEpsilon then
		self._progressAnchor = position
		self._progressTime = 0
		self._stuck = false
		-- Made real progress - clear stuck-since tracking.
		self._stuckSince = nil
		self._recoveryStage = "None"
		self._recoveryStageStart = 0
		return
	end

	if self._progressTime >= self._options.Movement.StuckTimeout then
		self._progressAnchor = position
		self._progressTime = 0
		self._stuck = true
		-- Record when continuous stuck-ness began (only set once per stuck episode).
		if not self._stuckSince then
			self._stuckSince = os.clock()
			self._recoveryStage = "None"
			self._recoveryStageStart = os.clock()
		end
	end
end

-- Task 6: Returns how long the agent has been continuously stuck (seconds).
function MovementController:_stuckDuration(): number
	if not self._stuckSince then return 0 end
	return os.clock() - self._stuckSince
end

-- Task 6: Returns the current recovery state table.
function MovementController:GetRecoveryState(): { Active: boolean, Stage: string, Since: number }
	return {
		Active = self._stuck and self._stuckSince ~= nil,
		Stage  = self._recoveryStage or "None",
		Since  = self._stuckSince or 0,
	}
end

function MovementController:_evaluateJump(waypoint, moveDirection: Vector3, obstacle, gap)
	local rootPart = self.RootPart
	if not rootPart then
		return false, nil, "no_root"
	end

	local rootPosition = rootPart.Position
	-- Task 8: helper to validate that a candidate landing is within waypoint reach
	-- and within the allowed rise/drop envelope.
	-- A landing does not have to sit on the waypoint. A pathfinder jump node marks
	-- the take off, so the place the character actually comes down is normally
	-- several studs past it, and on a low ledge it overshoots the node entirely.
	-- The old check demanded the two coincide within WaypointReachDistance, which
	-- rejected ordinary hops and left the controller replanning the same route
	-- over and over. What matters is that the landing is somewhere the character
	-- can stand and that it does not throw the route backwards.
	local function landingIsValid(candidate: Vector3): boolean
		if not candidate then return false end
		local rise = candidate.Y - rootPosition.Y
		local drop = rootPosition.Y - candidate.Y
		if rise > self._options.Movement.MaxJumpRise then return false end
		if drop > self._options.Movement.MaxJumpDrop then return false end

		local reach = math.max(self._options.Movement.WaypointReachDistance, self._options.Agent.Radius * 1.5)
		local here = NavUtil.Flatten(waypoint.Position - rootPosition).Magnitude
		local there = NavUtil.Flatten(waypoint.Position - candidate).Magnitude
		if there <= reach then
			return true
		end
		-- Past the node is fine. Further from it than the character already is,
		-- by more than one node of slack, is a landing going the wrong way.
		return there <= here + reach
	end

	-- A simulated landing beats a probed one: it is where the body actually
	-- comes down rather than the first patch of floor found along a ray.
	if self._trajectory then
		local humanoid = self.Humanoid
		local walkSpeed = if humanoid then humanoid.WalkSpeed else nil
		local jumpSpeed = walkSpeed
		if walkSpeed and self._options.Emulation.UseLiveSpeed ~= false then
			local velocity = NavUtil.Flatten(rootPart.AssemblyLinearVelocity)
			jumpSpeed = math.clamp(velocity.Magnitude, self._options.Emulation.MinLiveSpeed or 1, walkSpeed)
		end
		local simulated = self._trajectory:Evaluate(rootPosition, moveDirection, humanoid, {
			Speed = walkSpeed,
			JumpSpeed = jumpSpeed,
			RootPart = rootPart,
		})
		if simulated and simulated.JumpSafe and simulated.Landing then
			return true, simulated.Landing, "emulated"
		end
		if simulated and simulated.Doomed then
			return false, nil, "emulated_no_landing"
		end
	end

	local landing = if obstacle then obstacle.Landing else nil
	if not landing and gap then
		landing = gap.Landing
	end

	if landing then
		if landingIsValid(landing) then
			return true, landing, nil
		end
		-- Landing existed but failed strict check - fall through to search.
		landing = nil
	end

	local waypointDistance = NavUtil.Flatten(waypoint.Position - rootPosition).Magnitude
	local searchEnd = math.max(
		self._options.Movement.MaxGapJumpDistance,
		math.min(waypointDistance + self._options.Agent.Radius, self._options.Movement.MaxGapJumpDistance + 2)
	)
	landing = self._detector:FindJumpLanding(
		rootPosition,
		moveDirection,
		self._options.Agent.Radius * 1.1,
		searchEnd
	)
	if landing then
		if landingIsValid(landing) then
			return true, landing, nil
		end
		-- Found a landing but it does not reach the waypoint.
		return false, nil, "no_landing"
	end

	if obstacle
		and obstacle.Jumpable
		and obstacle.Height
		and obstacle.Height <= self._options.Movement.SmallObstacleHeight
	then
		-- Low wall: commit without strict landing (the other side is reachable by hop).
		return true, nil, "low_wall_commit"
	end

	return false, nil, "no_landing"
end

function MovementController:_startClimb(climbMeasurement, waypoint): boolean
	if not self.RootPart or not self.Character then
		return false
	end

	-- Task 9: Only engage when entry is reachable (EntryClear) and an exit exists
	-- in the intended travel direction. Do not flip direction silently; if the
	-- canonical exit is absent the climb would stall.
	if not climbMeasurement.EntryClear then
		return false
	end

	local rootY = self.RootPart.Position.Y
	local waypointY = waypoint.Position.Y
	local direction = if waypointY >= rootY then 1 else -1
	local exitPoint = if direction > 0 then climbMeasurement.TopExitPoint else climbMeasurement.BottomPoint
	if not exitPoint then
		-- Preferred exit missing - try the other direction only if a valid exit exists there.
		direction = -direction
		exitPoint = if direction > 0 then climbMeasurement.TopExitPoint else climbMeasurement.BottomPoint
		if not exitPoint then
			return false
		end
	end

	self._climbState = {
		Kind = climbMeasurement.Kind,
		EntryPoint = climbMeasurement.EntryPoint,
		FaceNormal = climbMeasurement.FaceNormal,
		ExitPoint = exitPoint,
		Direction = direction,
	}
	self._jumpCommitUntil = 0
	self:_resetTrackFallback()
	return true
end

function MovementController:_updateClimb(dt: number, waypoint, actionDecision)
	local climbState = self._climbState
	local humanoid = self.Humanoid
	local rootPart = self.RootPart
	if not climbState or not humanoid or not rootPart or not self.Character then
		self:_clearClimbState()
		return {
			ReachedWaypoint = false,
			MoveDirection = Vector3.zero,
			BlockingObstacle = emptyObstacle(),
			Stuck = false,
			Airborne = false,
			JumpRecoveryActive = false,
			TrackFallbackActive = false,
			ClimbingActive = false,
			ActionDecision = actionDecision,
		}
	end

	local faceNormal = if climbState.FaceNormal == Vector3.zero then -rootPart.CFrame.LookVector else climbState.FaceNormal
	local surfaceOffset = self._options.Climb.SurfaceOffset
	local alignPosition = climbState.EntryPoint + faceNormal * surfaceOffset
	local currentPosition = rootPart.Position
	local nextY = currentPosition.Y + climbState.Direction * self._options.Climb.Speed * dt
	if climbState.Direction > 0 then
		nextY = math.min(nextY, climbState.ExitPoint.Y)
	else
		nextY = math.max(nextY, climbState.ExitPoint.Y)
	end

	local targetPosition = Vector3.new(alignPosition.X, nextY, alignPosition.Z)
	self.Character:PivotTo(CFrame.lookAt(targetPosition, targetPosition - faceNormal))
	rootPart.AssemblyLinearVelocity = Vector3.zero
	self:_move(Vector3.zero)
	humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
	self:_updateStuck(targetPosition, dt, false)

	if math.abs(nextY - climbState.ExitPoint.Y) <= self._options.Movement.WaypointReachDistance * 0.5 then
		-- Task 9: Place agent at exit + forward nudge so they step onto the platform
		-- rather than sliding back onto the climbable surface.
		local nudgeDir = if faceNormal ~= Vector3.zero then faceNormal else -rootPart.CFrame.LookVector
		local exitPosition = climbState.ExitPoint + nudgeDir * self._options.Climb.ExitOffset
		self.Character:PivotTo(CFrame.lookAt(exitPosition, exitPosition - nudgeDir))
		rootPart.AssemblyLinearVelocity = Vector3.zero
		self:_clearClimbState()
		return {
			ReachedWaypoint = (waypoint.Position - exitPosition).Magnitude <= self._options.Movement.WaypointReachDistance,
			MoveDirection = Vector3.zero,
			BlockingObstacle = emptyObstacle(),
			Stuck = false,
			Airborne = false,
			JumpRecoveryActive = false,
			TrackFallbackActive = false,
			ClimbingActive = false,
			ActionDecision = actionDecision,
		}
	end

	return {
		ReachedWaypoint = false,
		MoveDirection = Vector3.zero,
		BlockingObstacle = emptyObstacle(),
		Stuck = false,
		Airborne = false,
		JumpRecoveryActive = false,
		TrackFallbackActive = false,
		ClimbingActive = true,
		ActionDecision = actionDecision,
	}
end

function MovementController:ResetProgress()
	self._progressAnchor = nil
	self._progressTime = 0
	self._stuck = false
	self._jumpCommitUntil = 0
	-- Task 6: Clear recovery ladder state on progress reset.
	self._stuckSince = nil
	self._recoveryStage = "None"
	self._recoveryStageStart = 0
	self:_clearClimbState()
	self:_resetTrackFallback()
end

function MovementController:Stop()
	if self.Humanoid then
		self:_move(Vector3.zero)
	end
	self:ClearMove()
	self:ResetProgress()
end

function MovementController:Update(dt: number, state)
	local humanoid = self.Humanoid
	local rootPart = self.RootPart
	if not humanoid or not rootPart then
		return {
			Blocked = true,
			Stuck = true,
			MoveDirection = Vector3.zero,
			BlockingObstacle = emptyObstacle(),
			Airborne = false,
			JumpRecoveryActive = false,
			TrackFallbackActive = false,
			ClimbingActive = false,
		}
	end

	local waypoint = state.Waypoint
	local steeringTarget = state.SteeringTarget
	local planarOffset = NavUtil.Flatten(steeringTarget - rootPart.Position)
	local moveDirection = NavUtil.SafeUnit(planarOffset)
	-- Distance to a waypoint is measured on the walking plane, not in three
	-- dimensions. Pathfinding waypoints sit on the floor while HumanoidRootPart
	-- rides about three studs above it (HipHeight plus half the root part), so a
	-- straight magnitude spent the whole three stud reach budget on the standing
	-- offset alone. The character would arrive exactly on top of a node, measure
	-- itself four studs away, refuse to advance, and stand there forever with a
	-- flat direction of zero. Height is checked separately against the agent so a
	-- node on a balcony overhead still does not count as reached.
	local flatToWaypoint = NavUtil.Flatten(waypoint.Position - rootPart.Position).Magnitude
	local verticalToWaypoint = math.abs(waypoint.Position.Y - rootPart.Position.Y)
	local distanceToWaypoint = flatToWaypoint
	local withinReach = flatToWaypoint <= self._options.Movement.WaypointReachDistance
		and verticalToWaypoint <= self._options.Agent.Height
	local airborne = self:_isAirborne(humanoid)

	if self._climbState then
		return self:_updateClimb(dt, waypoint, nil)
	end

	-- What actually happens if the body keeps going. Needed before anything else
	-- decides to wait at a jump node, because if walking works there is nothing
	-- to wait for.
	local flight = nil
	if not airborne and moveDirection ~= Vector3.zero and self._trajectory then
		local jumpSpeed = humanoid.WalkSpeed
		if self._options.Emulation.UseLiveSpeed ~= false then
			local velocity = NavUtil.Flatten(rootPart.AssemblyLinearVelocity)
			jumpSpeed = math.clamp(velocity.Magnitude, self._options.Emulation.MinLiveSpeed or 1, humanoid.WalkSpeed)
		end
		flight = self._trajectory:Evaluate(rootPart.Position, moveDirection, humanoid, {
			Speed = humanoid.WalkSpeed,
			JumpSpeed = jumpSpeed,
			RootPart = rootPart,
		})
		self._lastFlight = flight
	end

	-- A jump node sits at the take off point, so it falls inside the reach radius
	-- before the jump has fired. Returning here would halt the character dead on
	-- the lip and advance past the node without ever jumping. The reach handling
	-- is held off briefly so the jump logic below gets a turn, bounded so a jump
	-- that can never be evaluated safe does not park the route on the edge.
	local holdForJump = false
	if not airborne
		and waypoint.Action == Enum.PathWaypointAction.Jump
		and os.clock() > self._jumpCommitUntil
		-- A planned jump node that turns out to be walkable is just a node.
		-- Waiting on it is how the character stood on a ledge hopping in place
		-- while a plain step off would have carried it across.
		and not (flight and flight.WalkSafe)
	then
		self._jumpHoldSince = self._jumpHoldSince or os.clock()
		holdForJump = (os.clock() - self._jumpHoldSince) <= (self._options.Movement.ActionReevaluateWindow or 1.4)
	else
		self._jumpHoldSince = nil
	end

	if withinReach and not holdForJump then
		local jumpRecoveryActive = airborne or os.clock() <= self._jumpCommitUntil
		self:_resetTrackFallback()
		if airborne then
			self:_move(moveDirection)
			self:_updateStuck(rootPart.Position, dt, false)
			return {
				ReachedWaypoint = true,
				MoveDirection = moveDirection,
				Stuck = false,
				BlockingObstacle = emptyObstacle(),
				Airborne = true,
				JumpRecoveryActive = jumpRecoveryActive,
				TrackFallbackActive = false,
				ClimbingActive = false,
			}
		end

		self:_move(Vector3.zero)
		self:_updateStuck(rootPart.Position, dt, false)
		return {
			ReachedWaypoint = true,
			MoveDirection = Vector3.zero,
			Stuck = false,
			BlockingObstacle = emptyObstacle(),
			Airborne = false,
			JumpRecoveryActive = jumpRecoveryActive,
			TrackFallbackActive = false,
			ClimbingActive = false,
		}
	end

	self:_move(moveDirection)

	local obstacle = emptyObstacle()
	local gap = nil
	local blockedBySlope = false
	local hardStop = false

	if not airborne then
		obstacle = self._detector:DetectForwardObstacle(
			rootPart.CFrame,
			moveDirection,
			math.max(humanoid.WalkSpeed * 0.45, self._options.Movement.GapProbeDistance, 5)
		)
		gap = self._detector:DetectGap(rootPart.Position, moveDirection, self._options.Movement.GapProbeDistance)
		local slopeInfo = self._detector:GetGroundInfo(rootPart.Position + moveDirection * 2)
		local climbableSurface = obstacle.Climb and obstacle.Climb.Climbable

		-- Task 7: Edge/hazard hard-stop. If there is no safe ground ahead and no valid
		-- jump landing and the obstacle ahead is not climbable, halt that frame.
		-- One bad ground sample is normal on uneven terrain: the probe lands in a
		-- seam, on a lip, or on a steep facet. Halting on the first one is what
		-- made the character stop dead at random. It now takes several
		-- consecutive misses before movement is cut.
		local noGroundAhead = slopeInfo == nil
		if noGroundAhead
			and (gap == nil or gap.Dangerous == true)
			and not climbableSurface
			and waypoint.Action ~= Enum.PathWaypointAction.Jump
		then
			self._noGroundStreak = (self._noGroundStreak or 0) + 1
		else
			self._noGroundStreak = 0
		end

		if self._noGroundStreak >= (self._options.Movement.HardStopConfirmFrames or 3) then
			self:_move(Vector3.zero)
			hardStop = true
		end

		blockedBySlope = hardStop and gap == nil and not obstacle.Jumpable and not climbableSurface
	end

	-- Task 9: Visualize climb measurement whenever it exists so entry/exit is
	-- observable before the climb is accepted. Attach to result for _drawDebugFrame.
	local climbDebugMeasurement = obstacle.Climb or nil

	local forwardOnTruss = not airborne and obstacle.HitKind == "Truss"
	local requiredClimb = not forwardOnTruss
		and not airborne
		and obstacle.Climb
		and obstacle.Climb.Climbable
		and math.abs(waypoint.Position.Y - rootPart.Position.Y) >= self._options.Climb.MinVerticalTravel
	local requiredJump = not forwardOnTruss and not requiredClimb and not airborne and not hardStop
		and (waypoint.Action == Enum.PathWaypointAction.Jump or (gap and gap.RequiresJump == true))
	local opportunisticJump = not forwardOnTruss and not requiredClimb and not airborne and not hardStop
		and obstacle.Blocking and obstacle.Jumpable

	if flight then
		-- The whole rule, in the order that matters.
		--
		-- 1. Walking off here lands somewhere survivable, so there is no reason
		--    to jump, whatever the route node says. A plan drawn from a coarse
		--    simulation can call a step a jump; the body is standing here now and
		--    knows better.
		if flight.WalkSafe then
			requiredJump = false
			opportunisticJump = false
		end

		-- 2. Walking does not land and jumping does. That is the moment, and
		--    ShouldJump already withheld it while there was run-up left.
		if flight.ShouldJump then
			requiredJump = true
		end

		-- 3. Never commit to a jump the emulator says does not land. Refusing
		--    here is what keeps it from launching into a pit because a waypoint
		--    happened to be flagged.
		if requiredJump and not flight.JumpSafe then
			requiredJump = false
		end

		-- 4. Neither works. Jumping into that is worse than stopping, so it is
		--    treated as a wall and handed to the repair path. Confirmed over
		--    several frames: one pessimistic tick freezing the route is its own
		--    kind of broken.
		if flight.Doomed then
			self._doomStreak = (self._doomStreak or 0) + 1
		else
			self._doomStreak = 0
		end
		if self._doomStreak >= (self._options.Movement.HardStopConfirmFrames or 3) then
			self:_move(Vector3.zero)
			hardStop = true
			requiredJump = false
			opportunisticJump = false
		end
	end
	local actionDecision = nil

	-- Task 6: Escalating stuck recovery ladder (runs when stuck and not airborne and not climbing).
	-- This is evaluated before the normal move/jump/climb path so recovery takes priority.
	if self._stuck and not airborne and not forwardOnTruss and not requiredClimb then
		local cfg = self._options.StuckRecovery
		local stuckDur = self:_stuckDuration()
		local stageElapsed = os.clock() - self._recoveryStageStart

		-- Advance stage when current stage has timed out.
		local function advanceStage(newStage: string)
			self._recoveryStage = newStage
			self._recoveryStageStart = os.clock()
		end

		if stuckDur < cfg.StuckEnterTime then
			-- Too soon - let normal logic try; recovery stage stays None.
			self._recoveryStage = "None"
		elseif self._recoveryStage == "None" then
			advanceStage("Sidestep")
		end

		if self._recoveryStage == "Sidestep" then
			-- Probe left and right for a clear lateral step.
			local lateral = Vector3.new(-moveDirection.Z, 0, moveDirection.X)
			local leftTarget = rootPart.Position + lateral * cfg.SidestepDistance
			local rightTarget = rootPart.Position - lateral * cfg.SidestepDistance
			local leftClear = self._detector:HasLineOfSight(rootPart.Position, leftTarget)
			local rightClear = self._detector:HasLineOfSight(rootPart.Position, rightTarget)

			-- Attach probe data for _drawDebugFrame visualization.
			local sideProbeLeft = leftTarget
			local sideProbeRight = rightTarget

			if leftClear then
				self:_move(lateral)
			elseif rightClear then
				self:_move(-lateral)
			end
			-- Advance stage when this window has elapsed.
			if stageElapsed >= cfg.StageTimeout then
				advanceStage("BackOff")
			end

			self:_updateStuck(rootPart.Position, dt, moveDirection ~= Vector3.zero)
			local trackFallbackActive = self:_updateTrackFallback(rootPart.Position, steeringTarget, distanceToWaypoint, moveDirection)
			return {
				ReachedWaypoint = false,
				MoveDirection = moveDirection,
				BlockingObstacle = obstacle,
				Gap = gap,
				BlockedBySlope = blockedBySlope,
				HardStop = hardStop,
				Stuck = self._stuck,
				RecoveryStage = self._recoveryStage,
				ActionDecision = { Type = "Recovery", Stage = "Sidestep", Safe = leftClear or rightClear, WaypointPosition = waypoint.Position, Required = true, Attempted = true },
				Airborne = false,
				JumpRecoveryActive = false,
				TrackFallbackActive = trackFallbackActive,
				ClimbingActive = false,
				-- Attach probe positions for debug drawing.
				_recoveryProbeLeft  = sideProbeLeft,
				_recoveryProbeRight = sideProbeRight,
				_recoveryProbeLClear = leftClear,
				_recoveryProbeRClear = rightClear,
				_climbDebugMeasurement = climbDebugMeasurement,
			}

		elseif self._recoveryStage == "BackOff" then
			self:_move(-moveDirection)
			if stageElapsed >= cfg.StageTimeout then
				advanceStage("UnstickJump")
			end

			self:_updateStuck(rootPart.Position, dt, moveDirection ~= Vector3.zero)
			local trackFallbackActive = self:_updateTrackFallback(rootPart.Position, steeringTarget, distanceToWaypoint, moveDirection)
			return {
				ReachedWaypoint = false,
				MoveDirection = -moveDirection,
				BlockingObstacle = obstacle,
				Gap = gap,
				BlockedBySlope = blockedBySlope,
				HardStop = hardStop,
				Stuck = self._stuck,
				RecoveryStage = self._recoveryStage,
				ActionDecision = { Type = "Recovery", Stage = "BackOff", Safe = true, WaypointPosition = waypoint.Position, Required = true, Attempted = true },
				Airborne = false,
				JumpRecoveryActive = false,
				TrackFallbackActive = trackFallbackActive,
				ClimbingActive = false,
				_climbDebugMeasurement = climbDebugMeasurement,
			}

		elseif self._recoveryStage == "UnstickJump" then
			self:_tryJump()
			if stageElapsed >= cfg.StageTimeout then
				advanceStage("Escalate")
			end

			self:_updateStuck(rootPart.Position, dt, moveDirection ~= Vector3.zero)
			local trackFallbackActive = self:_updateTrackFallback(rootPart.Position, steeringTarget, distanceToWaypoint, moveDirection)
			return {
				ReachedWaypoint = false,
				MoveDirection = moveDirection,
				BlockingObstacle = obstacle,
				Gap = gap,
				BlockedBySlope = blockedBySlope,
				HardStop = hardStop,
				Stuck = self._stuck,
				RecoveryStage = self._recoveryStage,
				ActionDecision = { Type = "Recovery", Stage = "UnstickJump", Safe = true, WaypointPosition = waypoint.Position, Required = true, Attempted = true },
				Airborne = false,
				JumpRecoveryActive = true,
				TrackFallbackActive = trackFallbackActive,
				ClimbingActive = false,
				_climbDebugMeasurement = climbDebugMeasurement,
			}

		elseif self._recoveryStage == "Escalate" then
			-- Signal to the controller to attempt repair/replan.
			self:_updateStuck(rootPart.Position, dt, moveDirection ~= Vector3.zero)
			local trackFallbackActive = self:_updateTrackFallback(rootPart.Position, steeringTarget, distanceToWaypoint, moveDirection)
			return {
				ReachedWaypoint = false,
				MoveDirection = moveDirection,
				BlockingObstacle = obstacle,
				Gap = gap,
				BlockedBySlope = blockedBySlope,
				HardStop = hardStop,
				Stuck = self._stuck,
				RecoveryStage = "Escalate",
				ActionDecision = { Type = "Recovery", Stage = "Escalate", Safe = false, WaypointPosition = waypoint.Position, Required = true, Attempted = false },
				Airborne = false,
				JumpRecoveryActive = false,
				TrackFallbackActive = trackFallbackActive,
				ClimbingActive = false,
				_climbDebugMeasurement = climbDebugMeasurement,
			}
		end
	end

	if forwardOnTruss then
		self:_updateStuck(rootPart.Position, dt, moveDirection ~= Vector3.zero)
		local trackFallbackActive = self:_updateTrackFallback(rootPart.Position, steeringTarget, distanceToWaypoint, moveDirection)
		return {
			ReachedWaypoint = false,
			MoveDirection = moveDirection,
			BlockingObstacle = obstacle,
			Gap = nil,
			BlockedBySlope = false,
			HardStop = hardStop,
			Stuck = false,
			RecoveryStage = "None",
			ActionDecision = {
				Type = "TrussForward",
				Safe = true,
				Reason = obstacle.HitClassName,
				WaypointPosition = waypoint.Position,
				Required = true,
				Attempted = true,
			},
			Airborne = false,
			JumpRecoveryActive = false,
			TrackFallbackActive = trackFallbackActive,
			ClimbingActive = true,
			_climbDebugMeasurement = climbDebugMeasurement,
		}
	elseif requiredClimb then
		actionDecision = {
			Type = "Climb",
			Safe = true,
			Reason = obstacle.Climb.Kind,
			WaypointPosition = waypoint.Position,
			Required = true,
		}
		actionDecision.Attempted = self:_startClimb(obstacle.Climb, waypoint)
		if actionDecision.Attempted then
			local climbResult = self:_updateClimb(dt, waypoint, actionDecision)
			climbResult._climbDebugMeasurement = climbDebugMeasurement
			return climbResult
		end
	elseif requiredJump and moveDirection ~= Vector3.zero then
		local safe, landing, reason = self:_evaluateJump(waypoint, moveDirection, obstacle, gap)

		if safe then
			self._jumpEvalFailures = 0
		else
			self._jumpEvalFailures = (self._jumpEvalFailures or 0) + 1
			local forceAfter = self._options.Movement.JumpForceAfterFailures or 0
			-- Asking again is not going to produce a different answer at the same
			-- spot, and the caller responds to an unsafe jump by replanning, which
			-- hands back the same route. A player would simply try the jump, so
			-- after a few refusals it is tried, unless the gap is a genuine fall.
			if forceAfter > 0
				and self._jumpEvalFailures >= forceAfter
				and (gap == nil or gap.Dangerous ~= true)
			then
				safe = true
				reason = "forced_after_" .. tostring(self._jumpEvalFailures) .. "_refusals"
			end
		end

		actionDecision = {
			Type = "Jump",
			Safe = safe,
			Landing = landing,
			Reason = reason,
			WaypointPosition = waypoint.Position,
			Required = true,
		}

		if safe then
			actionDecision.Attempted = self:_tryJump()
		else
			actionDecision.Attempted = false
		end
	elseif opportunisticJump then
		self:_tryJump()
	end

	self:_updateStuck(rootPart.Position, dt, not airborne and moveDirection ~= Vector3.zero)
	local trackFallbackActive = false
	if not airborne then
		trackFallbackActive = self:_updateTrackFallback(rootPart.Position, steeringTarget, distanceToWaypoint, moveDirection)
	else
		self:_resetTrackFallback()
	end

	return {
		ReachedWaypoint = false,
		MoveDirection = moveDirection,
		BlockingObstacle = obstacle,
		Gap = gap,
		BlockedBySlope = blockedBySlope,
		HardStop = hardStop,
		Stuck = if airborne then false else self._stuck,
		RecoveryStage = self._recoveryStage or "None",
		ActionDecision = actionDecision,
		Airborne = airborne,
		JumpRecoveryActive = airborne or os.clock() <= self._jumpCommitUntil,
		TrackFallbackActive = trackFallbackActive,
		ClimbingActive = false,
		Flight = flight,
		_climbDebugMeasurement = climbDebugMeasurement,
	}
end

return MovementController
end

local MovementController = createMovementController(NavUtil, Trajectory)

local function createNavigationController(NavigationConfig, NavUtil, DebugRenderer, MovementController, NavigationProbe, ObstacleDetector, PathPlanner)
local RunService = game:GetService("RunService")


local NavigationController = {}
NavigationController.__index = NavigationController

-- A shared heartbeat keeps per-agent overhead low when many controllers are active.
local activeControllers: { [any]: boolean } = {}
local heartbeatConnection: RBXScriptConnection? = nil

local function ensureHeartbeat()
	if heartbeatConnection then
		return
	end

	heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		-- _step can yield (ComputeAsync), and Destroy can run during that yield.
		-- Mutating activeControllers mid-pairs raises "invalid key to 'next'",
		-- so the frame iterates a snapshot instead of the live set.
		local snapshot = {}
		for controller in pairs(activeControllers) do
			table.insert(snapshot, controller)
		end

		for _, controller in ipairs(snapshot) do
			if activeControllers[controller] and not controller._stepping then
				controller._stepping = true
				local ok, errorMessage = pcall(function()
					controller:_step(dt)
				end)
				controller._stepping = false

				if not ok then
					Logger.error("runtime", tostring(errorMessage))
					controller:_fail("runtime_error")
				end
			end
		end
	end)
end

local function releaseHeartbeatIfIdle()
	if next(activeControllers) == nil and heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

function NavigationController.new(character: Model, options)
	-- ShallowMerge clones every nested table, which would detach the controller
	-- from later config edits. A table flagged __live is adopted by reference.
	local mergedOptions
	if type(options) == "table" and options.__live then
		mergedOptions = options
	else
		mergedOptions = NavUtil.ShallowMerge(NavigationConfig, options)
	end

	local self = setmetatable({}, NavigationController)
	self._options = mergedOptions
	self.Character = character
	self.Humanoid = NavUtil.GetHumanoid(character)
	self.RootPart = NavUtil.GetRootPart(character)
	self.State = "Idle"
	self.StatusReason = nil
	self._requestId = 0
	self._destination = nil
	self._destinationTracking = nil
	self._trackedTargetPosition = nil
	self._lastTargetCheckTime = 0
	self._pursuitArrivalTime = nil
	self._route = nil
	self._nextIndex = 1
	self._lastMoveDirection = Vector3.zero
	self._lastProbeTime = 0
	self._lastObstacleScan = 0
	self._lastRouteValidationTime = 0
	self._lastReplanTime = 0
	self._lastRepairTime = 0
	self._completedEvent = Instance.new("BindableEvent")
	self._failedEvent = Instance.new("BindableEvent")
	self._pendingAction = nil
	self._hadUsableRoute = false
	self._routeRecovery = nil
	-- Task 5 counters.
	self._replanCount = 0
	self._repairCount = 0
	self._lastActionDecision = nil
	self._lastFailReason = nil

	self.DebugRenderer = DebugRenderer.new(mergedOptions.Debug)
	self.ObstacleDetector = ObstacleDetector.new(character, mergedOptions)
	self.ObstacleDetector:SetDebugRenderer(self.DebugRenderer)
	self.PathPlanner = PathPlanner.new(self.ObstacleDetector, mergedOptions)
	self.NavigationProbe = NavigationProbe.new(self.PathPlanner, self.ObstacleDetector, self.DebugRenderer, mergedOptions)
	self.MovementController = MovementController.new(character, self.ObstacleDetector, mergedOptions)
	self.Trajectory = self.MovementController._trajectory

	activeControllers[self] = true
	ensureHeartbeat()

	return self
end

function NavigationController:_refreshCharacterReferences()
	if not self.Character or not self.Character.Parent then
		return false
	end

	self.Humanoid = NavUtil.GetHumanoid(self.Character)
	self.RootPart = NavUtil.GetRootPart(self.Character)
	self.ObstacleDetector:SetCharacter(self.Character)
	self.MovementController:SetCharacter(self.Character)

	return self.Humanoid ~= nil and self.RootPart ~= nil
end

function NavigationController:_getDestinationPart(destination: Instance): BasePart?
	if destination:IsA("BasePart") then
		return destination
	end

	if destination:IsA("Attachment") then
		local parent = destination.Parent
		if parent and parent:IsA("BasePart") then
			return parent
		end
		return nil
	end

	if destination:IsA("Model") then
		local primaryPart = destination.PrimaryPart or destination:FindFirstChild("HumanoidRootPart")
		if primaryPart and primaryPart:IsA("BasePart") then
			return primaryPart
		end
	end

	return nil
end

function NavigationController:_resolveDestinationPosition(): Vector3?
	local destination = self._destination
	if typeof(destination) == "Vector3" then
		return destination
	end

	if typeof(destination) == "Instance" then
		if destination:IsA("BasePart") then
			return destination.Position
		end
		if destination:IsA("Attachment") then
			return destination.WorldPosition
		end
		if destination:IsA("Model") then
			local primaryPart = destination.PrimaryPart or destination:FindFirstChild("HumanoidRootPart")
			if primaryPart and primaryPart:IsA("BasePart") then
				return primaryPart.Position
			end
		end
	end

	return nil
end

function NavigationController:_sampleGoalState()
	local rawGoal = self:_resolveDestinationPosition()
	if not rawGoal then
		return nil
	end

	local destination = self._destination
	local isInstanceTarget = typeof(destination) == "Instance"
	self._destinationTracking = {
		Position = rawGoal,
		Time = os.clock(),
		Velocity = Vector3.zero,
		PlannedGoal = rawGoal,
	}

	return {
		RawGoal = rawGoal,
		PlannedGoal = rawGoal,
		Velocity = Vector3.zero,
		PlanarVelocity = Vector3.zero,
		IsInstanceTarget = isInstanceTarget,
		IsPursuit = false,
		IsMoving = false,
	}
end

function NavigationController:_shouldRestartForTargetChange(goalState): boolean
	if self._options.TargetTracking.Enabled ~= true or not goalState.IsInstanceTarget then
		return false
	end

	local now = os.clock()
	if not self._trackedTargetPosition then
		self._trackedTargetPosition = goalState.RawGoal
		self._lastTargetCheckTime = now
		return false
	end

	if now - self._lastTargetCheckTime < self._options.TargetTracking.Interval then
		return false
	end

	self._lastTargetCheckTime = now
	if (goalState.RawGoal - self._trackedTargetPosition).Magnitude >= self._options.TargetTracking.MoveThreshold then
		self._trackedTargetPosition = goalState.RawGoal
		return true
	end

	return false
end
function NavigationController:_resolveNavigableGoal(rawGoalPosition: Vector3): Vector3?
	local directGround = self.ObstacleDetector:FindGroundBelow(rawGoalPosition, 12, 512)
	if directGround then
		return directGround
	end

	local radius = math.max(self._options.Agent.Radius * 2, 4)
	local offsets = {
		Vector3.new(radius, 0, 0),
		Vector3.new(-radius, 0, 0),
		Vector3.new(0, 0, radius),
		Vector3.new(0, 0, -radius),
		Vector3.new(radius, 0, radius),
		Vector3.new(radius, 0, -radius),
		Vector3.new(-radius, 0, radius),
		Vector3.new(-radius, 0, -radius),
		Vector3.new(radius * 2, 0, 0),
		Vector3.new(-radius * 2, 0, 0),
		Vector3.new(0, 0, radius * 2),
		Vector3.new(0, 0, -radius * 2),
	}

	local bestCandidate = nil
	local bestDistance = math.huge

	for _, offset in ipairs(offsets) do
		local candidate = self.ObstacleDetector:FindGroundBelow(rawGoalPosition + offset, 12, 512)
		if candidate then
			local distance = (candidate - rawGoalPosition).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				bestCandidate = candidate
			end
		end
	end

	return bestCandidate
end

function NavigationController:_setRoute(route, reason: string)
	self._route = route
	self._nextIndex = 1
	self._lastMoveDirection = Vector3.zero
	self._pendingAction = nil
	self._routeRecovery = nil
	self._hadUsableRoute = true
	self.State = "Moving"
	self.StatusReason = nil
	self.MovementController:ResetProgress()

	if self.RootPart then
		self.DebugRenderer:DrawUpdate(self.RootPart.Position, reason)
	end
	if route then
		self.DebugRenderer:DrawPath(route.Nodes, self._nextIndex)
	end
end

function NavigationController:_fail(reason: string)
	if self.State == "Failed" then
		return
	end

	self.State = "Failed"
	self.StatusReason = reason
	self._lastFailReason = reason
	self._routeRecovery = nil
	self._pursuitArrivalTime = nil
	self.MovementController:Stop()
	self._failedEvent:Fire(reason)
end

function NavigationController:_complete()
	self.State = "Completed"
	self.StatusReason = nil
	self._route = nil
	self._nextIndex = 1
	self._pendingAction = nil
	self._routeRecovery = nil
	self._pursuitArrivalTime = nil
	self.MovementController:Stop()
	self._completedEvent:Fire()
end

function NavigationController:Stop()
	self.State = "Stopped"
	self.StatusReason = "stopped"
	self._route = nil
	self._nextIndex = 1
	self._pendingAction = nil
	self._routeRecovery = nil
	self._pursuitArrivalTime = nil
	self.MovementController:Stop()
end

function NavigationController:_canRecoverAfterNoPath(reason: string): boolean
	if self._options.Recovery.Enabled ~= true then
		return false
	end

	if self._options.Recovery.OnlyAfterSuccessfulRoute and not self._hadUsableRoute then
		return false
	end

	return string.find(reason, "NoPath", 1, true) ~= nil
end

function NavigationController:_beginRouteRecovery(reason: string, goalPosition: Vector3, contextReason: string): boolean
	if not self:_canRecoverAfterNoPath(reason) then
		return false
	end

	self.State = "WaitingForPath"
	self.StatusReason = reason
	self._route = nil
	self._nextIndex = 1
	self._pendingAction = nil
	self._pursuitArrivalTime = nil
	self.MovementController:Stop()
	self._routeRecovery = {
		StartedAt = os.clock(),
		NextRetryAt = os.clock() + self._options.Recovery.RetryInterval,
		LastReason = reason,
		ContextReason = contextReason,
		Goal = goalPosition,
	}
	if self.RootPart then
		self.DebugRenderer:DrawUpdate(self.RootPart.Position, "waiting_path")
	end
	return true
end

function NavigationController:_computeFreshRoute(goalPosition: Vector3, bypassCache: boolean, reason: string, controlOptions): (boolean, string?)
	-- PathfindingService:ComputeAsync yields. Without this guard a compute that
	-- takes longer than a frame lets the next Heartbeat start another one, and
	-- the overlapping results fight over _route / _nextIndex.
	if self._computing then
		return false, "compute_in_flight"
	end

	self._replanCount = (self._replanCount or 0) + 1
	local options = controlOptions or {}
	if not self.RootPart then
		return false, "missing_root"
	end

	self._computing = true

	local navigableGoal = self:_resolveNavigableGoal(goalPosition)
	if not navigableGoal then
		self._computing = false
		if not options.SuppressFailure then
			self:_fail("invalid_goal_surface")
		end
		return false, "invalid_goal_surface"
	end

	local computeOk, route, errorMessage = pcall(function()
		return self.PathPlanner:ComputeRoute(self.RootPart.Position, navigableGoal, {
			BypassCache = bypassCache,
			Revision = if self._route then self._route.Revision + 1 else 1,
		})
	end)
	self._computing = false

	if not computeOk then
		local failureReason = "planner_error"
		if not options.SuppressFailure then
			self:_fail(failureReason)
		end
		return false, failureReason
	end

	if not route then
		local failureReason = tostring(errorMessage)
		if options.AllowRecovery and self:_beginRouteRecovery(failureReason, goalPosition, reason) then
			return false, failureReason
		end
		if not options.SuppressFailure then
			self:_fail(failureReason)
		end
		return false, failureReason
	end

	self:_setRoute(route, reason)
	self._lastReplanTime = os.clock()
	return true, nil
end

function NavigationController:_attemptRecoveryStep(goalPosition: Vector3)
	local recovery = self._routeRecovery
	if not recovery then
		self:_fail("path_recovery_missing")
		return
	end

	local now = os.clock()
	if now - recovery.StartedAt > self._options.Recovery.MaxWaitTime then
		self:_fail(recovery.LastReason or "path_recovery_timeout")
		return
	end

	if now < recovery.NextRetryAt then
		return
	end

	recovery.NextRetryAt = now + self._options.Recovery.RetryInterval
	recovery.Goal = goalPosition
	local success, failureReason = self:_computeFreshRoute(goalPosition, true, "path_recovered", {
		SuppressFailure = true,
		AllowRecovery = false,
	})
	if success then
		self.StatusReason = nil
		return
	end

	recovery.LastReason = failureReason or recovery.LastReason
end


function NavigationController:_validateUpcomingRoute(): (boolean, string?)
	if not self._route or not self.RootPart or self._options.RouteValidation.Enabled ~= true then
		return true, nil
	end

	local maxNodes = self._options.RouteValidation.LookAheadNodes or 4
	local maxDistance = self._options.RouteValidation.LookAheadDistance or 24
	local startPosition = self.RootPart.Position
	local travelled = 0
	local checkedNodes = 0

	for index = self._nextIndex, #self._route.Nodes do
		local node = self._route.Nodes[index]
		local segmentDistance = (node.Position - startPosition).Magnitude
		travelled += segmentDistance
		checkedNodes += 1
		local nearTrussNode = self.ObstacleDetector:IsNearTruss(
			node.Position,
			self._options.RouteValidation.TrussNodeMinDistance,
			self._options.RouteValidation.TrussNodeMaxDistance
		)

		if not nearTrussNode and not self.ObstacleDetector:IsGroundSafe(node.Position) then
			return false, "future_node_unsupported"
		end

		if not nearTrussNode and not self.ObstacleDetector:CanTraversePlannedSegment(startPosition, node.Position, node.Action) then
			return false, if node.Action == Enum.PathWaypointAction.Jump then "future_jump_invalid" else "future_segment_invalid"
		end

		if checkedNodes >= maxNodes or travelled >= maxDistance then
			break
		end

		startPosition = node.Position
	end

	return true, nil
end

function NavigationController:_attemptRepair(_goalPosition: Vector3, reason: string): boolean
	if not self.RootPart or not self._route then
		return false
	end

	local now = os.clock()
	if now - self._lastRepairTime < self._options.UpdateRates.SegmentRepairCooldown then
		return false
	end

	self._lastRepairTime = now
	local repairedRoute = self.PathPlanner:RepairRoute(self.RootPart.Position, self._route, self._nextIndex)
	if not repairedRoute then
		return false
	end

	self._repairCount = (self._repairCount or 0) + 1
	self:_setRoute(repairedRoute, reason)
	return true
end

function NavigationController:_buildDebugSnapshot()
	local waypointCount = if self._route and self._route.Nodes then #self._route.Nodes else 0
	local stuckTimer = 0
	if self.MovementController and self.MovementController._progressTime then
		stuckTimer = self.MovementController._progressTime
	end
	local recoveryState = nil
	if self.MovementController and self.MovementController.GetRecoveryState then
		recoveryState = self.MovementController:GetRecoveryState()
	end
	return {
		State         = self.State,
		Reason        = self.StatusReason,
		WaypointIndex = self._nextIndex,
		WaypointCount = waypointCount,
		Action        = self._lastActionDecision,
		Stuck         = self.MovementController and self.MovementController._stuck or false,
		StuckTime     = stuckTimer,
		Replans       = self._replanCount or 0,
		Repairs       = self._repairCount or 0,
		LastFail      = self._lastFailReason,
		RecoveryStage = recoveryState and recoveryState.Stage or "None",
	}
end

-- Single source of truth for per-step debug drawing. All draws happen inside one
-- BeginFrame/EndFrame bracket so the pool cursor is consistent and nothing a draw
-- produces gets reset by a later BeginFrame. Safe to call on any _step exit path.
function NavigationController:_drawDebugFrame(movementResult, steeringTarget, obstacle)
	if not self.DebugRenderer or not self.DebugRenderer:IsEnabled() then
		return
	end

	local drawNow = os.clock()
	local drawInterval = self._options.Debug.DrawInterval or 0.05
	if self._lastDebugDraw and drawNow - self._lastDebugDraw < drawInterval then
		return
	end
	self._lastDebugDraw = drawNow
	pcall(function()
		local renderer = self.DebugRenderer
		renderer:BeginFrame()
		if self._route then
			renderer:DrawPath(self._route.Nodes, self._nextIndex)
		end
		if steeringTarget then
			renderer:DrawMarker(steeringTarget, "Steering")
		end
		if obstacle and obstacle.Blocking and obstacle.Hit then
			renderer:DrawObstacle(obstacle.Hit.Position, obstacle.Dynamic)
		end
		local rootPos = self.RootPart and self.RootPart.Position
		if rootPos and movementResult and movementResult.MoveDirection and movementResult.MoveDirection ~= Vector3.zero then
			local probeEnd = rootPos + movementResult.MoveDirection * self._options.Movement.GapProbeDistance
			local obstHit = movementResult.BlockingObstacle and movementResult.BlockingObstacle.Blocking
			renderer:DrawProbe(rootPos, probeEnd, obstHit == true, "Rays")
		end
		if movementResult and movementResult.Gap and movementResult.Gap.Landing then
			local gapSafe = movementResult.Gap.RequiresJump and not movementResult.Gap.Dangerous
			renderer:DrawJump(rootPos or Vector3.zero, movementResult.Gap.Landing, gapSafe)
		end
		-- Task 8: Draw predicted jump arc + landing from the action decision.
		if movementResult and movementResult.ActionDecision then
			local ad = movementResult.ActionDecision
			if ad.Type == "Jump" and rootPos then
				local landing = ad.Landing
				if landing then
					renderer:DrawJump(rootPos, landing, ad.Safe == true)
				end
			end
		end
		-- Task 6: Draw recovery sidestep/backoff probes.
		if movementResult and movementResult._recoveryProbeLeft and rootPos then
			renderer:DrawProbe(rootPos, movementResult._recoveryProbeLeft, not movementResult._recoveryProbeLClear, "Rays")
			renderer:DrawProbe(rootPos, movementResult._recoveryProbeRight, not movementResult._recoveryProbeRClear, "Rays")
		end
		-- Task 7: Draw unsafe-ground probe in red on layer "Ground".
		if movementResult and movementResult.HardStop and rootPos then
			local moveDir = movementResult.MoveDirection
			if moveDir and moveDir ~= Vector3.zero then
				local groundProbeEnd = rootPos + moveDir * self._options.Movement.GapProbeDistance
				renderer:DrawProbe(rootPos, groundProbeEnd, true, "Ground")
			end
		end
		-- Task 9: Draw climb entry/exit whenever obstacle has a Climb measurement.
		if movementResult and movementResult._climbDebugMeasurement then
			renderer:DrawClimb(movementResult._climbDebugMeasurement)
		end
		-- Task 10: blink the most-recent world-changed (newly spawned wall) detection.
		if self._worldChangedMarker and os.clock() < self._worldChangedMarker.Until then
			renderer:DrawObstacle(self._worldChangedMarker.Point, true)
		end
		renderer:EndFrame()
	end)
end

function NavigationController:_applyTemporaryRoute(probeRoute)
	local nodes = {}
	NavUtil.AppendNodes(nodes, probeRoute.Nodes)

	if probeRoute.SpliceIndex and self._route then
		for index = probeRoute.SpliceIndex, #self._route.Nodes do
			table.insert(nodes, NavUtil.CloneNode(self._route.Nodes[index]))
		end
	end

	self:_setRoute({
		Goal = if self._route then self._route.Goal else nodes[#nodes].Position,
		Nodes = nodes,
		CreatedAt = os.clock(),
		Revision = if self._route then self._route.Revision + 1 else 1,
	}, "probe_update")
end

function NavigationController:_getCurrentWaypoint()
	if not self._route then
		return nil
	end
	return self._route.Nodes[self._nextIndex]
end


function NavigationController:_shouldBlendSteeringTarget(waypoint, nextNode): boolean
	if not self.RootPart then
		return false
	end

	local currentSegment = waypoint.Position - self.RootPart.Position
	local nextSegment = nextNode.Position - waypoint.Position
	if math.abs(nextSegment.Y) > (self._options.Steering.MaxBlendRise or 1.25) then
		return false
	end

	if math.abs(waypoint.Position.Y - self.RootPart.Position.Y) > (self._options.Steering.MaxBlendRise or 1.25) then
		return false
	end

	local turnAngle = NavUtil.AngleDegrees(currentSegment, nextSegment)
	if turnAngle >= (self._options.Steering.MaxBlendTurnDegrees or 32) then
		return false
	end

	return self.ObstacleDetector:CanTraversePlannedSegment(self.RootPart.Position, nextNode.Position, nextNode.Action)
end

function NavigationController:_getSteeringTarget(): Vector3?
	local waypoint = self:_getCurrentWaypoint()
	if not waypoint then
		return nil
	end

	local steeringTarget = waypoint.Position
	local nextNode = self._route and self._route.Nodes[self._nextIndex + 1]
	if not nextNode or not self.RootPart then
		return steeringTarget
	end

	-- Flattened for the same reason the reach test is: the root rides above the
	-- floor the waypoints sit on, and counting that offset as distance made the
	-- look ahead think it was still far away while standing on the node.
	local distanceToWaypoint = NavUtil.Flatten(waypoint.Position - self.RootPart.Position).Magnitude

	-- Standing on top of the node leaves nothing to steer by, and a direction of
	-- zero means the character never moves and never leaves the node. Aim at the
	-- one after it instead.
	if distanceToWaypoint <= self._options.Agent.Radius * 0.5 then
		return nextNode.Position
	end

	if distanceToWaypoint > self._options.Movement.LookAheadDistance then
		return steeringTarget
	end

	if not self:_shouldBlendSteeringTarget(waypoint, nextNode) then
		return steeringTarget
	end

	local alpha = math.clamp(1 - (distanceToWaypoint / self._options.Movement.LookAheadDistance), 0, 0.55)
	return waypoint.Position:Lerp(nextNode.Position, alpha)
end

function NavigationController:_getReplanCooldown(goalState): number
	if goalState and goalState.IsPursuit then
		return self._options.Pursuit.ReplanCooldown or self._options.UpdateRates.PathReplanCooldown
	end

	return self._options.UpdateRates.PathReplanCooldown
end

function NavigationController:_shouldReplanForGoal(goalState): boolean
	if not self._route then
		return false
	end

	if goalState.IsPursuit then
		local routeGoalSlack = self._options.Pursuit.RouteGoalSlack
		local pursuitDrift = self._options.Pursuit.ReplanDriftThreshold
		local tailRefreshDistance = self._options.Pursuit.TailRefreshDistance or routeGoalSlack
		local rawGoalDrift = NavUtil.Flatten(goalState.RawGoal - self._route.Goal).Magnitude
		local plannedGoalDrift = NavUtil.Flatten(goalState.PlannedGoal - self._route.Goal).Magnitude
		local tailDrift = rawGoalDrift
		local finalNode = self._route.Nodes[#self._route.Nodes]
		if finalNode then
			tailDrift = NavUtil.Flatten(goalState.RawGoal - finalNode.Position).Magnitude
		end

		return rawGoalDrift >= routeGoalSlack
			or plannedGoalDrift >= pursuitDrift
			or tailDrift >= tailRefreshDistance
	end

	return (goalState.PlannedGoal - self._route.Goal).Magnitude >= self._options.UpdateRates.GoalDriftThreshold
end

function NavigationController:_canCompleteForGoal(goalState, activeGoal: Vector3?): boolean
	if not self.RootPart or not activeGoal or self.MovementController:IsAirborne() then
		self._pursuitArrivalTime = nil
		return false
	end

	if not goalState.IsPursuit then
		self._pursuitArrivalTime = nil
		local reach = self._options.Movement.WaypointReachDistance
		local offset = NavUtil.Flatten(activeGoal - self.RootPart.Position).Magnitude
		if offset > reach then
			return false
		end
		-- Standing on it already counts. Requiring a shortcut evaluation here
		-- meant a goal on a lip or a slight rise could never be declared reached.
		if offset <= reach * 0.6 and math.abs(activeGoal.Y - self.RootPart.Position.Y) <= self._options.Agent.Height then
			return true
		end
		return self.ObstacleDetector:CanTraversePlannedSegment(self.RootPart.Position, activeGoal, Enum.PathWaypointAction.Walk)
	end

	local targetDistance = (goalState.RawGoal - self.RootPart.Position).Magnitude
	local targetVisible = self.ObstacleDetector:HasLineOfSight(self.RootPart.Position, goalState.RawGoal)
	local targetReachable = self.ObstacleDetector:CanTraversePlannedSegment(self.RootPart.Position, activeGoal, Enum.PathWaypointAction.Walk)
	local slowEnough = goalState.PlanarVelocity.Magnitude <= self._options.Pursuit.CompletionVelocityThreshold
	if targetDistance <= self._options.Pursuit.ArrivalDistance and targetVisible and targetReachable and slowEnough then
		if not self._pursuitArrivalTime then
			self._pursuitArrivalTime = os.clock()
		end
		return os.clock() - self._pursuitArrivalTime >= self._options.Pursuit.CompletionHoldTime
	end

	self._pursuitArrivalTime = nil
	return false
end

function NavigationController:_advanceWaypoint(goalState)
	if not self._route then
		return
	end

	self._nextIndex += 1
	self._pendingAction = nil
	if self._nextIndex > #self._route.Nodes then
		if goalState and goalState.IsPursuit then
			self._route = nil
			self._nextIndex = 1
			if self.RootPart then
				self.DebugRenderer:DrawUpdate(self.RootPart.Position, "pursuit_refresh")
			end
			return
		end
		self:_complete()
		return
	end

	self.DebugRenderer:DrawPath(self._route.Nodes, self._nextIndex)
end

function NavigationController:_beginActionTracking(actionDecision)
	if not self.RootPart or not actionDecision or not actionDecision.Attempted or not actionDecision.Required then
		return
	end

	self._pendingAction = {
		Type = actionDecision.Type,
		StartedAt = os.clock(),
		WaypointPosition = actionDecision.WaypointPosition,
	}
end

function NavigationController:_probe(goalOrState): boolean
	local goalPosition: Vector3
	local forceProbe = false
	if typeof(goalOrState) == "Vector3" then
		goalPosition = goalOrState
	else
		goalPosition = goalOrState.Goal
		forceProbe = goalOrState.Force == true
	end

	local now = os.clock()
	if (not forceProbe and now - self._lastProbeTime < self._options.UpdateRates.ProbeInterval) or not self.RootPart then
		return false
	end
	self._lastProbeTime = now

	-- Probes look for direct shots, later visible nodes, or short local detours.
	local probeResult = self.NavigationProbe:Scan({
		Position = self.RootPart.Position,
		Goal = goalPosition,
		Route = self._route,
		NextIndex = self._nextIndex,
		MoveDirection = self._lastMoveDirection,
		Force = forceProbe,
	})

	if not probeResult then
		return false
	end

	if probeResult.Type == "DirectGoal" then
		local navigableGoal = self:_resolveNavigableGoal(goalPosition)
		if not navigableGoal then
			return false
		end

		self:_setRoute({
			Goal = navigableGoal,
			Nodes = {
				{
					Position = navigableGoal,
					Action = Enum.PathWaypointAction.Walk,
				},
			},
			CreatedAt = os.clock(),
			Revision = if self._route then self._route.Revision + 1 else 1,
		}, "direct_shortcut")
		return true
	elseif probeResult.Type == "RouteShortcut" and probeResult.ShortcutIndex then
		self._nextIndex = probeResult.ShortcutIndex
		self.DebugRenderer:DrawPath(self._route.Nodes, self._nextIndex)
		if self.RootPart then
			self.DebugRenderer:DrawUpdate(self.RootPart.Position, "route_shortcut")
		end
		return true
	elseif probeResult.Type == "TemporaryRoute" and probeResult.Route then
		self:_applyTemporaryRoute(probeResult.Route)
		return true
	end

	return false
end

function NavigationController:_step(dt: number)
	if self.State ~= "Moving" and self.State ~= "WaitingForPath" then
		return
	end

	if not self:_refreshCharacterReferences() then
		self:_fail("character_unavailable")
		return
	end

	local goalState = self:_sampleGoalState()
	if not goalState or not self.RootPart then
		self:_fail("invalid_destination")
		return
	end

	local plannerGoal = goalState.RawGoal
	local bypassCache = goalState.IsInstanceTarget
	local replanCooldown = self:_getReplanCooldown(goalState)

	-- Endgame lock. Within ArrivalLockDistance the controller stops replanning,
	-- repairing and validating. Those three kept firing at the destination,
	-- each one handing back a fresh route to a point already underfoot, which is
	-- what made the character hover on the spot instead of finishing.
	local lockDistance = self._options.Movement.ArrivalLockDistance or 0
	local goalOffset = NavUtil.Flatten(goalState.RawGoal - self.RootPart.Position)
	local nearGoal = lockDistance > 0 and goalOffset.Magnitude <= lockDistance
	self._nearGoal = nearGoal

	if nearGoal
		and goalOffset.Magnitude <= self._options.Movement.WaypointReachDistance
		and math.abs(goalState.RawGoal.Y - self.RootPart.Position.Y) <= self._options.Agent.Height
		and not self.MovementController:IsAirborne()
	then
		self:_complete()
		return
	end

	if self.State == "WaitingForPath" then
		self:_attemptRecoveryStep(plannerGoal)
		return
	end

	if not nearGoal and self:_shouldRestartForTargetChange(goalState) then
		local success = self:_computeFreshRoute(goalState.RawGoal, true, "target_relocated", {
			AllowRecovery = true,
		})
		if not success then
			return
		end
		plannerGoal = goalState.RawGoal
	end

	if not nearGoal and self:_shouldReplanForGoal(goalState) then
		local now = os.clock()
		if now - self._lastReplanTime >= replanCooldown then
			local success = self:_computeFreshRoute(plannerGoal, true, if goalState.IsPursuit then "pursuit_drift" else "goal_drift", {
				AllowRecovery = true,
			})
			if not success then
				return
			end
		end
	end

	local activeGoal = if self._route then self._route.Goal else self:_resolveNavigableGoal(plannerGoal)
	if self:_canCompleteForGoal(goalState, activeGoal) then
		self:_complete()
		return
	end

	if not self._route then
		local success = self:_computeFreshRoute(plannerGoal, bypassCache, if goalState.IsPursuit then "pursuit_path" else "initial_path", {
			AllowRecovery = goalState.IsPursuit,
		})
		if not success then
			return
		end
	end

	if self._route and not nearGoal and not self.MovementController:IsAirborne() then
		local now = os.clock()
		if now - self._lastRouteValidationTime >= self._options.RouteValidation.Interval then
			self._lastRouteValidationTime = now
			local routeValid, invalidReason = self:_validateUpcomingRoute()
			if not routeValid then
				if self:_attemptRepair(plannerGoal, invalidReason or "future_route_repair") then
					return
				end

				if now - self._lastReplanTime >= replanCooldown then
					self:_computeFreshRoute(plannerGoal, true, invalidReason or "future_route_replan", {
						AllowRecovery = true,
					})
				end
				return
			end
		end
	end

	self:_probe(plannerGoal)

	local waypoint = self:_getCurrentWaypoint()
	if not waypoint then
		if goalState.IsPursuit then
			local success = self:_computeFreshRoute(plannerGoal, true, "pursuit_refresh", {
				AllowRecovery = true,
			})
			if not success then
				return
			end
			waypoint = self:_getCurrentWaypoint()
		end
		if not waypoint then
			self:_complete()
			return
		end
	end

	local steeringTarget = self:_getSteeringTarget()
	if not steeringTarget then
		self:_fail("no_steering_target")
		return
	end

	local movementResult = self.MovementController:Update(dt, {
		Waypoint = waypoint,
		SteeringTarget = steeringTarget,
		Goal = plannerGoal,
	})
	self._lastMoveDirection = movementResult.MoveDirection or self._lastMoveDirection
	-- Task 5: store last action decision for snapshot.
	if movementResult.ActionDecision then
		self._lastActionDecision = movementResult.ActionDecision
	end

	local now = os.clock()
	if movementResult.ActionDecision then
		if movementResult.ActionDecision.Attempted then
			self:_beginActionTracking(movementResult.ActionDecision)
		elseif movementResult.ActionDecision.Required and not movementResult.ActionDecision.Safe then
			if self:_probe({
				Goal = plannerGoal,
				Force = true,
			}) then
				return
			end

			if self:_attemptRepair(plannerGoal, "jump_repair") then
				return
			end

			if now - self._lastReplanTime >= replanCooldown then
				self:_computeFreshRoute(plannerGoal, true, "jump_replan", {
					AllowRecovery = true,
				})
			end
			return
		end
	end

	if movementResult.ReachedWaypoint then
		if movementResult.Airborne and self._route and self._nextIndex >= #self._route.Nodes then
			return
		end

		self:_advanceWaypoint(goalState)
		return
	end

	if self._pendingAction and now - self._pendingAction.StartedAt > self._options.Movement.ActionReevaluateWindow then
		self._pendingAction = nil
	end

	local obstacle = movementResult.BlockingObstacle
	local inTraversalRecovery = movementResult.JumpRecoveryActive == true or movementResult.ClimbingActive == true
	local dynamicBlocker = obstacle and obstacle.Blocking and obstacle.Dynamic

	-- Obstacle scans are throttled separately from movement so raycasts stay predictable at scale.
	if not nearGoal and not inTraversalRecovery and not dynamicBlocker and now - self._lastObstacleScan >= self._options.UpdateRates.ObstacleScanInterval then
		self._lastObstacleScan = now
		local hasSightToWaypoint = self.ObstacleDetector:HasLineOfSight(self.RootPart.Position, waypoint.Position)
		if not hasSightToWaypoint then
			if self:_attemptRepair(plannerGoal, "segment_repair") then
				self:_drawDebugFrame(movementResult, steeringTarget, obstacle)
				return
			end
		end

		-- Task 10: Cheap throttled forward LOS sweep over the next LookAheadNodes segments.
		-- Catches a static wall that spawned/un-hid with zero velocity (IsDynamic misses it).
		if self._route then
			local lookAhead = self._options.RouteValidation.LookAheadNodes or 5
			local worldChangedBlockPoint = nil
			local segStart = self.RootPart.Position
			for scanIdx = self._nextIndex, math.min(#self._route.Nodes, self._nextIndex + lookAhead - 1) do
				local segEnd = self._route.Nodes[scanIdx].Position
				local losOk = self.ObstacleDetector:HasLineOfSight(segStart, segEnd)
				if not losOk then
					-- Check whether the blocker is climbable to avoid false triggers on truss/ladder.
					local segDir = NavUtil.SafeUnit(segEnd - segStart)
					local scanHit = self.ObstacleDetector:Raycast(
						segStart + Vector3.new(0, math.max(self._options.Agent.Height * 0.3, 1.5), 0),
						segDir * (segEnd - segStart).Magnitude
					)
					local blockerClimbable = false
					if scanHit then
						local hitKind = self.ObstacleDetector:ClassifyHit(scanHit.Instance)
						blockerClimbable = hitKind == "Truss" or hitKind == "Ladder"
					end
					if not blockerClimbable then
						worldChangedBlockPoint = segEnd
						break
					end
				end
				segStart = segEnd
			end

			if worldChangedBlockPoint then
				-- Stash the detected static blocker so _drawDebugFrame can draw it INSIDE its
				-- BeginFrame/EndFrame bracket. Drawing it here directly would be wiped by the
				-- next BeginFrame before it ever renders. Short lifetime so it blinks then clears.
				self._worldChangedMarker = { Point = worldChangedBlockPoint, Until = now + 0.6 }
				if self:_attemptRepair(plannerGoal, "world_changed") then
					self:_drawDebugFrame(movementResult, steeringTarget, obstacle)
					return
				end
				if now - self._lastReplanTime >= replanCooldown then
					self:_computeFreshRoute(plannerGoal, true, "world_changed_replan", {
						AllowRecovery = true,
					})
				end
				self:_drawDebugFrame(movementResult, steeringTarget, obstacle)
				return
			end
		end
	end

	-- Task 7: HardStop - treat like blocked (route into repair/replan).
	if movementResult.HardStop then
		self:_drawDebugFrame(movementResult, steeringTarget, obstacle)
		if self:_attemptRepair(plannerGoal, "hard_stop_repair") then
			return
		end
		if now - self._lastReplanTime >= replanCooldown then
			self:_computeFreshRoute(plannerGoal, true, "hard_stop_replan", {
				AllowRecovery = true,
			})
		end
		return
	end

	local blocked = false
	if not inTraversalRecovery then
		local trussForward = obstacle and obstacle.HitKind == "Truss"
		local trussClimbable = obstacle and obstacle.Truss and obstacle.Truss.Climbable
		local climbableSurface = obstacle and obstacle.Climb and obstacle.Climb.Climbable
		blocked = movementResult.BlockedBySlope
			or (dynamicBlocker == true)
			or (obstacle and obstacle.Blocking and not obstacle.Jumpable and not trussClimbable and not climbableSurface and not trussForward)
			or (movementResult.Gap and movementResult.Gap.Dangerous == true)
			-- Task 6: Only escalate stuck handling when MovementController signals Escalate.
			-- Sidestep/BackOff/UnstickJump are handled inside MovementController itself.
			or (movementResult.RecoveryStage == "Escalate")
	end

	if blocked then
		if movementResult.TrackFallbackActive and not dynamicBlocker and movementResult.RecoveryStage ~= "Escalate" then
			self:_drawDebugFrame(movementResult, steeringTarget, obstacle)
			return
		end

		if dynamicBlocker and self:_probe({
			Goal = plannerGoal,
			Force = true,
		}) then
			self:_drawDebugFrame(movementResult, steeringTarget, obstacle)
			return
		end

		if self:_attemptRepair(plannerGoal, if dynamicBlocker then "dynamic_repair" else "local_repair") then
			self:_drawDebugFrame(movementResult, steeringTarget, obstacle)
			return
		end

		local enoughTimePassed = now - self._lastReplanTime >= replanCooldown
		if enoughTimePassed then
			self:_computeFreshRoute(plannerGoal, true, if dynamicBlocker then "dynamic_replan" else "full_replan", {
				AllowRecovery = true,
			})
		end

		-- Task 6: Terminal - if still Escalate after repair AND replan both failed past MaxStuckTime*2, fail cleanly.
		if movementResult.RecoveryStage == "Escalate" and self.MovementController then
			local stuckDur = self.MovementController:_stuckDuration()
			local maxTime = (self._options.StuckRecovery and self._options.StuckRecovery.MaxStuckTime or 4) * 2
			if stuckDur >= maxTime then
				self:_fail("stuck_unrecoverable")
				return
			end
		end
	end

	self:_drawDebugFrame(movementResult, steeringTarget, obstacle)
end

function NavigationController:MoveTo(destination: Vector3 | Instance)
	self._requestId += 1
	self._destination = destination
	self._destinationTracking = nil
	self._trackedTargetPosition = nil
	self._lastTargetCheckTime = 0
	self._pursuitArrivalTime = nil
	self.State = "Moving"
	self.StatusReason = nil
	self._route = nil
	self._nextIndex = 1
	self._lastMoveDirection = Vector3.zero
	self._lastProbeTime = 0
	self._lastObstacleScan = 0
	self._lastRouteValidationTime = 0
	self._lastReplanTime = 0
	self._lastRepairTime = 0
	self._pendingAction = nil
	self._routeRecovery = nil
	self._hadUsableRoute = false
	-- Reset per-trip debug counters.
	self._replanCount = 0
	self._repairCount = 0
	self._lastActionDecision = nil
	self._lastFailReason = nil
	self.MovementController:ResetProgress()

	local goalPosition = self:_resolveDestinationPosition()
	if goalPosition and typeof(destination) == "Instance" then
		self._trackedTargetPosition = goalPosition
	end
	if not goalPosition then
		self:_fail("invalid_destination")
	end

	return self._requestId
end

function NavigationController:MoveToAsync(destination: Vector3 | Instance)
	local requestId = self:MoveTo(destination)
	while self._requestId == requestId do
		if self.State == "Completed" then
			return true
		end
		if self.State == "Failed" or self.State == "Stopped" then
			return false, self.StatusReason
		end
		RunService.Heartbeat:Wait()
	end

	return false, "superseded"
end

function NavigationController:GetCompletedSignal()
	return self._completedEvent.Event
end

function NavigationController:GetFailedSignal()
	return self._failedEvent.Event
end

function NavigationController:Destroy()
	self:Stop()
	self._computing = false
	self._stepping = false
	activeControllers[self] = nil
	releaseHeartbeatIfIdle()
	self.DebugRenderer:Destroy()
	self._completedEvent:Destroy()
	self._failedEvent:Destroy()
end

return NavigationController
end

local NavigationController = createNavigationController(
	NavigationConfig,
	NavUtil,
	DebugRenderer,
	MovementController,
	NavigationProbe,
	ObstacleDetector,
	PathPlanner
)

-- ============================================================================
--  PORTABLE NAVIGATION - RUNTIME SHELL
--  Click-to-move front end, live config store, and the settings UI.
--  Everything above this line is the solver; everything below drives it.
-- ============================================================================

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer

-- Re-running the script tears the previous instance down first so an executor
-- re-inject never leaves two UIs and two Stepped hooks fighting each other.
if _G.__PortableNavigationV2 and type(_G.__PortableNavigationV2.Teardown) == "function" then
	pcall(_G.__PortableNavigationV2.Teardown)
end

local SCRIPT_NAME = "PortableNavigation"
local SCRIPT_VERSION = "2.7.0"
local SESSION_START = os.clock()

-- ============================================================================
--  Logging bridge
-- ============================================================================

local MOVEMENT_LOG_INTERVAL = 0.35
local STEP_LOG_INTERVAL = 0.5

local function formatVector3(value)
	if typeof(value) ~= "Vector3" then
		return tostring(value)
	end
	return string.format("(%.2f, %.2f, %.2f)", value.X, value.Y, value.Z)
end

local function describeAction(actionDecision)
	if not actionDecision then
		return "none"
	end
	return string.format(
		"%s safe=%s attempted=%s reason=%s",
		tostring(actionDecision.Type),
		tostring(actionDecision.Safe),
		tostring(actionDecision.Attempted),
		tostring(actionDecision.Reason)
	)
end

local function navLog(scope, message, level)
	Logger.log(level or Logger.Level.Info, scope, tostring(message))
end

do
	local originalMovementUpdate = MovementController.Update
	function MovementController:Update(dt, state)
		local result = originalMovementUpdate(self, dt, state)
		local now = os.clock()
		self._portableLastMoveLog = self._portableLastMoveLog or 0
		if now - self._portableLastMoveLog >= MOVEMENT_LOG_INTERVAL then
			self._portableLastMoveLog = now
			local obstacle = result and result.BlockingObstacle
			local waypoint = state and state.Waypoint
			navLog(
				"move",
				string.format(
					"root=%s waypoint=%s move=%s reached=%s airborne=%s stuck=%s slope=%s track=%s climb=%s action=%s obstacle=%s/%s blocking=%s jumpable=%s dynamic=%s",
					formatVector3(self.RootPart and self.RootPart.Position),
					formatVector3(waypoint and waypoint.Position),
					formatVector3(result and result.MoveDirection),
					tostring(result and result.ReachedWaypoint),
					tostring(result and result.Airborne),
					tostring(result and result.Stuck),
					tostring(result and result.BlockedBySlope),
					tostring(result and result.TrackFallbackActive),
					tostring(result and result.ClimbingActive),
					describeAction(result and result.ActionDecision),
					tostring(obstacle and obstacle.HitKind),
					tostring(obstacle and obstacle.HitClassName),
					tostring(obstacle and obstacle.Blocking),
					tostring(obstacle and obstacle.Jumpable),
					tostring(obstacle and obstacle.Dynamic)
				),
				Logger.Level.Verbose
			)
		end
		return result
	end

	local originalComputeFreshRoute = NavigationController._computeFreshRoute
	function NavigationController:_computeFreshRoute(goalPosition, bypassCache, reason, controlOptions)
		local success, failureReason = originalComputeFreshRoute(self, goalPosition, bypassCache, reason, controlOptions)
		if success then
			navLog("route", string.format("computed reason=%s goal=%s", tostring(reason), formatVector3(goalPosition)), Logger.Level.Info)
		elseif failureReason ~= "compute_in_flight" then
			navLog("route", string.format("compute FAILED reason=%s failure=%s", tostring(reason), tostring(failureReason)), Logger.Level.Warn)
		end
		return success, failureReason
	end

	local originalFail = NavigationController._fail
	function NavigationController:_fail(reason)
		navLog("state", string.format("fail reason=%s nextIndex=%s", tostring(reason), tostring(self._nextIndex)), Logger.Level.Warn)
		return originalFail(self, reason)
	end

	local originalComplete = NavigationController._complete
	function NavigationController:_complete()
		navLog("state", string.format("complete position=%s", formatVector3(self.RootPart and self.RootPart.Position)), Logger.Level.Info)
		return originalComplete(self)
	end

	local originalStep = NavigationController._step
	function NavigationController:_step(dt)
		local beforeState = self.State
		originalStep(self, dt)
		local now = os.clock()
		self._portableLastStepLog = self._portableLastStepLog or 0
		self._portableLastState = self._portableLastState or beforeState
		if self.State ~= self._portableLastState then
			navLog("step", string.format("state %s -> %s reason=%s", tostring(self._portableLastState), tostring(self.State), tostring(self.StatusReason)), Logger.Level.Info)
			self._portableLastState = self.State
		end
		if now - self._portableLastStepLog >= STEP_LOG_INTERVAL then
			self._portableLastStepLog = now
			local routeNodeCount = if self._route and self._route.Nodes then #self._route.Nodes else 0
			navLog("step", string.format("state=%s nodes=%s index=%s root=%s", tostring(self.State), tostring(routeNodeCount), tostring(self._nextIndex), formatVector3(self.RootPart and self.RootPart.Position)), Logger.Level.Verbose)
		end
	end

	-- MoveTo no longer computes synchronously. The old version yielded inside the
	-- input handler on ComputeAsync, which raced the Heartbeat step that was
	-- already computing the same route. The step loop owns route computation now;
	-- acceptance is reported through the Completed / Failed signals.
	local originalMoveTo = NavigationController.MoveTo
	function NavigationController:MoveTo(destination)
		navLog("move_to", string.format("request %s", formatVector3(typeof(destination) == "Vector3" and destination or nil)), Logger.Level.Info)
		local requestId = originalMoveTo(self, destination)
		if self.State == "Failed" then
			return requestId, false, self.StatusReason
		end
		return requestId, true, nil
	end
end

-- ============================================================================
--  Persistence - executor filesystem when present, session memory otherwise
-- ============================================================================

local Storage = {}
do
	local hasFS = (type(writefile) == "function")
		and (type(readfile) == "function")
		and (type(isfile) == "function")
	local hasFolders = (type(makefolder) == "function") and (type(isfolder) == "function")

	local ROOT = SCRIPT_NAME
	local PROFILES = ROOT .. "/profiles"
	local memory = {}

	Storage.Mode = if hasFS then "filesystem" else "session"

	local function ensureFolders()
		if not hasFS or not hasFolders then
			return
		end
		pcall(function()
			if not isfolder(ROOT) then
				makefolder(ROOT)
			end
			if not isfolder(PROFILES) then
				makefolder(PROFILES)
			end
		end)
	end

	local function pathFor(name)
		if hasFolders then
			return PROFILES .. "/" .. name .. ".json"
		end
		return ROOT .. "_" .. name .. ".json"
	end

	function Storage.Write(name, text)
		if hasFS then
			ensureFolders()
			local ok, err = pcall(writefile, pathFor(name), text)
			if ok then
				return true
			end
			navLog("storage", string.format("write failed: %s", tostring(err)), Logger.Level.Warn)
		end
		memory[name] = text
		return hasFS == false
	end

	function Storage.Read(name)
		if hasFS then
			local ok, exists = pcall(isfile, pathFor(name))
			if ok and exists then
				local readOk, contents = pcall(readfile, pathFor(name))
				if readOk then
					return contents
				end
			end
		end
		return memory[name]
	end

	function Storage.Exists(name)
		return Storage.Read(name) ~= nil
	end

	function Storage.Delete(name)
		memory[name] = nil
		if hasFS and type(delfile) == "function" then
			pcall(delfile, pathFor(name))
		end
	end

	function Storage.List()
		local names = {}
		if hasFS and type(listfiles) == "function" and hasFolders then
			ensureFolders()
			local ok, files = pcall(listfiles, PROFILES)
			if ok and type(files) == "table" then
				for _, file in ipairs(files) do
					local name = tostring(file):match("([^/\\]+)%.json$")
					if name then
						table.insert(names, name)
					end
				end
			end
		end
		for name in pairs(memory) do
			local duplicate = false
			for _, existing in ipairs(names) do
				if existing == name then
					duplicate = true
					break
				end
			end
			if not duplicate then
				table.insert(names, name)
			end
		end
		table.sort(names)
		return names
	end
end

-- ============================================================================
--  Config serialisation - Color3 / EnumItem survive a JSON round trip
-- ============================================================================

local function encodeValue(value)
	local kind = typeof(value)
	if kind == "Color3" then
		return { __t = "Color3", r = value.R, g = value.G, b = value.B }
	elseif kind == "Vector3" then
		return { __t = "Vector3", x = value.X, y = value.Y, z = value.Z }
	elseif kind == "EnumItem" then
		return { __t = "EnumItem", e = tostring(value.EnumType), n = value.Name }
	elseif kind == "table" then
		local out = {}
		for key, nested in pairs(value) do
			if key ~= "__live" then
				out[tostring(key)] = encodeValue(nested)
			end
		end
		return out
	end
	return value
end

local function decodeValue(value)
	if type(value) ~= "table" then
		return value
	end
	if value.__t == "Color3" then
		return Color3.new(value.r, value.g, value.b)
	elseif value.__t == "Vector3" then
		return Vector3.new(value.x, value.y, value.z)
	elseif value.__t == "EnumItem" then
		local enumType = (Enum :: any)[(value.e :: string):gsub("^Enum%.", "")]
		if enumType then
			local ok, item = pcall(function()
				return enumType[value.n]
			end)
			if ok then
				return item
			end
		end
		return nil
	end
	local out = {}
	for key, nested in pairs(value) do
		local numericKey = tonumber(key)
		out[numericKey or key] = decodeValue(nested)
	end
	return out
end

-- Paths look like "Movement.JumpCooldown". Reads and writes go through these so
-- the schema can address any tunable without a hand written getter per field.
local function getPath(root, path)
	local node = root
	for segment in string.gmatch(path, "[^%.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[segment]
	end
	return node
end

local function setPath(root, path, value)
	local node = root
	local segments = {}
	for segment in string.gmatch(path, "[^%.]+") do
		table.insert(segments, segment)
	end
	for index = 1, #segments - 1 do
		local key = segments[index]
		if type(node[key]) ~= "table" then
			node[key] = {}
		end
		node = node[key]
	end
	node[segments[#segments]] = value
end

-- Debug layer toggles live on the config so they persist with a profile.
RuntimeConfig.Debug.Layers = {
	Route = true,
	Rays = true,
	Gaps = false,
	Jumps = false,
	Climb = false,
	Ground = false,
}
DefaultConfig.Debug.Layers = deepCopyConfig(RuntimeConfig.Debug.Layers)

local Config = {}
do
	local listeners = {}

	function Config.Get(path)
		return getPath(RuntimeConfig, path)
	end

	function Config.Default(path)
		return getPath(DefaultConfig, path)
	end

	function Config.OnChanged(callback)
		table.insert(listeners, callback)
	end

	function Config.Set(path, value, silent)
		local previous = getPath(RuntimeConfig, path)
		if previous == value then
			return
		end
		setPath(RuntimeConfig, path, value)
		if not silent then
			for _, callback in ipairs(listeners) do
				pcall(callback, path, value, previous)
			end
		end
	end

	function Config.Broadcast()
		for _, callback in ipairs(listeners) do
			pcall(callback, "*", nil, nil)
		end
	end

	function Config.Serialize()
		return HttpService:JSONEncode(encodeValue(RuntimeConfig))
	end

	-- Merges instead of replacing, so a profile written by an older build does
	-- not wipe fields that were added since.
	function Config.Apply(decoded, silent)
		local function merge(target, source)
			for key, value in pairs(source) do
				if key ~= "__live" then
					if type(value) == "table" and type(target[key]) == "table" and value.__t == nil then
						merge(target[key], value)
					else
						target[key] = value
					end
				end
			end
		end
		merge(RuntimeConfig, decoded)
		RuntimeConfig.__live = true
		if not silent then
			Config.Broadcast()
		end
	end

	function Config.Deserialize(text)
		local ok, decoded = pcall(function()
			return decodeValue(HttpService:JSONDecode(text))
		end)
		if not ok or type(decoded) ~= "table" then
			return false, tostring(decoded)
		end
		Config.Apply(decoded)
		return true
	end

	function Config.ResetAll()
		for key in pairs(RuntimeConfig) do
			if key ~= "__live" then
				RuntimeConfig[key] = nil
			end
		end
		for key, value in pairs(DefaultConfig) do
			RuntimeConfig[key] = deepCopyConfig(value)
		end
		RuntimeConfig.__live = true
		Config.Broadcast()
	end

	function Config.ResetPath(path)
		Config.Set(path, deepCopyConfig(getPath(DefaultConfig, path)))
	end
end

local PLACE_PROFILE = tostring(game.PlaceId)

local function saveProfile(name)
	local ok = Storage.Write(name, Config.Serialize())
	navLog("config", string.format("saved profile %s (%s)", name, Storage.Mode), Logger.Level.Info)
	return ok ~= false
end

local function loadProfile(name)
	local text = Storage.Read(name)
	if not text then
		return false, "not_found"
	end
	local ok, err = Config.Deserialize(text)
	if ok then
		navLog("config", string.format("loaded profile %s", name), Logger.Level.Info)
	end
	return ok, err
end


-- ============================================================================
--  Kill brick awareness
--
--  Names and tags only catch what a developer chose to label. This watches what
--  actually hurts: every character part reports what it touches, and when health
--  drops the parts touched just before are blamed. Anything learned that way is
--  generalised by signature, because a kill brick is almost never alone, and
--  remembered per place so the next session starts already knowing.
-- ============================================================================

local KillBricks = {}
do
	local CollectionServiceUI = game:GetService("CollectionService")
	-- signature -> { Learned, Source, At, Hits }
	local lethalSignatures = {}
	-- instance -> true, for parts confirmed directly
	local lethalParts = setmetatable({}, { __mode = "k" })
	-- instance -> os.clock() when touched
	local recentTouches = setmetatable({}, { __mode = "k" })
	local characterConnections = {}
	local playerConnections = {}
	local worldConnections = {}
	local learnedCount = 0
	local lastScan = 0
	local scanCursor = nil
	local dirty = false
	local watchedCharacter = nil
	local lastHealth = nil
	local graceUntil = 0

	KillBricks.OnLearned = nil
	KillBricks.Stats = { learned = 0, blamed = 0, heuristic = 0, touchesSeen = 0 }

	local HEURISTIC_TOKENS = {
		"kill", "lava", "acid", "void", "hazard", "damage", "death", "deadly",
		"spike", "trap", "poison", "fire", "burn", "electr", "laser", "toxic",
	}

	local function cfg(key)
		return Config.Get("KillBricks." .. key)
	end

	local function enabled(): boolean
		return cfg("Enabled") == true
	end

	-- A kill brick is almost never a one off. Matching on shape plus look means
	-- learning one instance of a repeated hazard immediately covers the rest of
	-- them, which is what makes a single death enough.
	local function signatureOf(part: BasePart): string?
		if not part or not part:IsA("BasePart") then
			return nil
		end

		-- Built from whatever the part actually carries. Name and size are the
		-- backbone; colour and material sharpen it when they are readable. One
		-- missing property must not throw the whole signature away, or a part
		-- that cannot be described is a part that can never be recognised again.
		local pieces = { part.Name }

		local okSize, size = pcall(function()
			return part.Size
		end)
		if okSize and size then
			table.insert(pieces, string.format("%.1f,%.1f,%.1f", size.X, size.Y, size.Z))
		end

		local okColour, colour = pcall(function()
			return part.BrickColor.Number
		end)
		if okColour and colour then
			table.insert(pieces, tostring(colour))
		end

		local okMaterial, material = pcall(function()
			return tostring(part.Material)
		end)
		if okMaterial and material then
			table.insert(pieces, material)
		end

		if #pieces < 2 then
			return nil
		end
		return table.concat(pieces, "|")
	end

	local function isLethalPart(instance: Instance?): boolean
		if not instance or not enabled() then
			return false
		end
		if lethalParts[instance] then
			return true
		end
		if cfg("GeneralizeBySignature") ~= false and instance:IsA("BasePart") then
			local signature = signatureOf(instance)
			if signature and lethalSignatures[signature] then
				return true
			end
		end
		return false
	end

	local function remember(part: BasePart, source: string)
		if not part or not part:IsA("BasePart") then
			return false
		end
		if lethalParts[part] then
			return false
		end
		if learnedCount >= (tonumber(cfg("MaxLearned")) or 512) then
			return false
		end

		lethalParts[part] = true
		local signature = signatureOf(part)
		local isNew = signature ~= nil and lethalSignatures[signature] == nil
		if signature then
			local entry = lethalSignatures[signature]
			if entry then
				entry.Hits += 1
			else
				lethalSignatures[signature] = { Source = source, At = os.clock(), Hits = 1 }
				learnedCount += 1
				dirty = true
			end
		end

		KillBricks.Stats.learned = learnedCount
		if source == "heuristic" then
			KillBricks.Stats.heuristic += 1
		else
			KillBricks.Stats.blamed += 1
		end

		if isNew and KillBricks.OnLearned then
			pcall(KillBricks.OnLearned, part, source)
		end
		return isNew
	end

	KillBricks.IsLethal = isLethalPart
	KillBricks.Remember = remember

	function KillBricks.Count(): number
		return learnedCount
	end

	function KillBricks.Forget()
		lethalSignatures = {}
		lethalParts = setmetatable({}, { __mode = "k" })
		learnedCount = 0
		dirty = true
		KillBricks.Stats = { learned = 0, blamed = 0, heuristic = 0, touchesSeen = KillBricks.Stats.touchesSeen }
	end

	-- ---------------------------------------------------------------- nearby --

	-- Anything lethal within AvoidRadius of a point makes that point unsafe to
	-- route through. Standing next to lava is not survivable just because the
	-- ground underfoot is solid.
	function KillBricks.NearbyLethal(position: Vector3): boolean
		if not enabled() or learnedCount == 0 then
			return false
		end
		local radius = tonumber(cfg("AvoidRadius")) or 0
		if radius <= 0 then
			return false
		end

		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { watchedCharacter }
		params.MaxParts = 12

		local ok, parts = pcall(function()
			return Workspace:GetPartBoundsInRadius(position, radius, params)
		end)
		if not ok or type(parts) ~= "table" then
			return false
		end
		for _, part in ipairs(parts) do
			if isLethalPart(part) then
				return true
			end
		end
		return false
	end

	-- ------------------------------------------------------------ persistence --

	local function storageName(): string
		return "killbricks_" .. PLACE_PROFILE
	end

	function KillBricks.Save(): boolean
		if cfg("Persist") == false then
			return false
		end
		local list = {}
		for signature, entry in pairs(lethalSignatures) do
			table.insert(list, { s = signature, k = entry.Source, h = entry.Hits })
		end
		local ok, encoded = pcall(function()
			return HttpService:JSONEncode({ version = 1, place = PLACE_PROFILE, signatures = list })
		end)
		if not ok then
			return false
		end
		dirty = false
		return Storage.Write(storageName(), encoded) ~= false
	end

	function KillBricks.Load(): number
		local text = Storage.Read(storageName())
		if not text then
			return 0
		end
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(text)
		end)
		if not ok or type(decoded) ~= "table" or type(decoded.signatures) ~= "table" then
			return 0
		end
		local loaded = 0
		for _, entry in ipairs(decoded.signatures) do
			if type(entry) == "table" and type(entry.s) == "string" and not lethalSignatures[entry.s] then
				lethalSignatures[entry.s] = { Source = entry.k or "saved", At = 0, Hits = entry.h or 1 }
				learnedCount += 1
				loaded += 1
			end
		end
		KillBricks.Stats.learned = learnedCount
		return loaded
	end

	-- --------------------------------------------------------------- learning --

	local function blameRecentTouches(reason: string)
		if cfg("LearnFromDamage") == false then
			return
		end
		local window = tonumber(cfg("BlameWindow")) or 0.4
		local now = os.clock()
		local blamed = 0
		for part, at in pairs(recentTouches) do
			if now - at <= window then
				if part.Parent and remember(part, reason) then
					blamed += 1
					navLog("killbricks", string.format("learned %s from %s", part:GetFullName(), reason), Logger.Level.Info)
				end
			end
		end
		if blamed > 0 then
			dirty = true
		end
	end

	local function trackTouch(part: BasePart?)
		if not part or not part:IsA("BasePart") then
			return
		end
		if part:IsDescendantOf(watchedCharacter) then
			return
		end
		recentTouches[part] = os.clock()
		KillBricks.Stats.touchesSeen += 1
	end

	local function clearConnections(list)
		for _, connection in ipairs(list) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		table.clear(list)
	end

	function KillBricks.WatchCharacter(character)
		clearConnections(characterConnections)
		watchedCharacter = character
		lastHealth = nil
		graceUntil = os.clock() + (tonumber(cfg("RespawnGrace")) or 1.5)
		if not character or not enabled() then
			return
		end

		local function listen(descendant)
			if not descendant:IsA("BasePart") then
				return
			end
			-- Touched is not guaranteed on everything a character can contain, and
			-- one odd accessory should not take the whole watcher down.
			pcall(function()
				table.insert(characterConnections, descendant.Touched:Connect(trackTouch))
			end)
		end

		for _, descendant in ipairs(character:GetDescendants()) do
			listen(descendant)
		end
		pcall(function()
			table.insert(characterConnections, character.DescendantAdded:Connect(listen))
		end)

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.HealthChanged then
			lastHealth = humanoid.Health
			table.insert(characterConnections, humanoid.HealthChanged:Connect(function(health)
				local previous = lastHealth or health
				lastHealth = health
				if os.clock() < graceUntil then
					return
				end
				local drop = previous - health
				if drop <= 0 then
					return
				end
				local fraction = drop / math.max(humanoid.MaxHealth, 1)
				if fraction < (tonumber(cfg("MinDamageFraction")) or 0.02) then
					return
				end
				blameRecentTouches(if health <= 0 then "death" else "damage")
			end))
		end
	end

	-- Other players walk into the same hazards, and watching them means a map can
	-- be learned without dying for it once.
	local function watchOtherPlayer(other)
		if other == player then
			return
		end
		local function bind(character)
			if not character then
				return
			end
			local humanoid = character:WaitForChild("Humanoid", 5)
			if not humanoid then
				return
			end
			local root = character:FindFirstChild("HumanoidRootPart")
			table.insert(playerConnections, humanoid.Died:Connect(function()
				if not enabled() or cfg("WatchOtherPlayers") == false then
					return
				end
				if not root or not root.Parent then
					return
				end
				local params = OverlapParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { character }
				params.MaxParts = 8
				local ok, parts = pcall(function()
					return Workspace:GetPartBoundsInRadius(root.Position, 5, params)
				end)
				if not ok or type(parts) ~= "table" then
					return
				end
				for _, part in ipairs(parts) do
					-- Only blame something already shaped like a hazard. A player
					-- dying next to a wall should not condemn the wall.
					local lowered = string.lower(part.Name)
					for _, token in ipairs(HEURISTIC_TOKENS) do
						if string.find(lowered, token, 1, true) then
							if remember(part, "other_player") then
								navLog("killbricks", string.format("learned %s from another player's death", part.Name), Logger.Level.Info)
							end
							break
						end
					end
				end
			end))
		end
		bind(other.Character)
		table.insert(playerConnections, other.CharacterAdded:Connect(bind))
	end

	function KillBricks.WatchWorld()
		clearConnections(playerConnections)
		clearConnections(worldConnections)
		if not enabled() then
			return
		end
		pcall(function()
			for _, other in ipairs(Players:GetPlayers()) do
				watchOtherPlayer(other)
			end
			table.insert(worldConnections, Players.PlayerAdded:Connect(watchOtherPlayer))
		end)
	end

	-- ------------------------------------------------------ heuristic sweep ---

	-- A budgeted, resumable pass over the world. It never scans everything in one
	-- frame: it takes ScanBudget instances, remembers where it stopped, and picks
	-- the same walk up again next interval.
	function KillBricks.Sweep()
		if not enabled() or cfg("HeuristicScan") == false then
			return 0
		end
		local now = os.clock()
		if now - lastScan < (tonumber(cfg("ScanInterval")) or 6) then
			return 0
		end
		lastScan = now

		local budget = math.max(50, tonumber(cfg("ScanBudget")) or 900)
		local ok, descendants = pcall(function()
			return Workspace:GetDescendants()
		end)
		if not ok or type(descendants) ~= "table" then
			return 0
		end

		local start = (scanCursor or 0)
		if start >= #descendants then
			start = 0
		end
		local found = 0
		local index = start
		while index < #descendants and index - start < budget do
			index += 1
			local instance = descendants[index]
			if instance and instance:IsA("BasePart") and not lethalParts[instance] then
				local lowered = string.lower(instance.Name)
				local matched = false
				for _, token in ipairs(HEURISTIC_TOKENS) do
					if string.find(lowered, token, 1, true) then
						matched = true
						break
					end
				end
				if not matched and instance:GetAttribute("Damage") ~= nil then
					matched = true
				end
				if not matched and CollectionServiceUI:HasTag(instance, "Kill") then
					matched = true
				end
				if matched then
					if remember(instance, "heuristic") then
						found += 1
					end
				end
			end
		end
		scanCursor = index

		if found > 0 then
			dirty = true
			navLog("killbricks", string.format("sweep learned %d part shapes", found), Logger.Level.Info)
		end
		return found
	end

	function KillBricks.Flush()
		if dirty and enabled() then
			KillBricks.Save()
		end
	end

	function KillBricks.Detach()
		clearConnections(characterConnections)
		clearConnections(playerConnections)
		clearConnections(worldConnections)
		watchedCharacter = nil
	end
end

-- ============================================================================
--  Theme
-- ============================================================================

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

local THEMES = {
	["catppuccin-mocha"] = {
		bg = hex("1e1e2e"), bg2 = hex("181825"), bg3 = hex("11111b"),
		card = hex("313244"), line = hex("45475a"),
		text = hex("cdd6f4"), dim = hex("a6adc8"), faint = hex("6c7086"),
		red = hex("f38ba8"), orange = hex("fab387"), yellow = hex("f9e2af"),
		green = hex("a6e3a1"), teal = hex("94e2d5"), blue = hex("89b4fa"),
		purple = hex("cba6f7"), pink = hex("f5c2e7"),
	},
	["gruvbox-dark"] = {
		bg = hex("282828"), bg2 = hex("1d2021"), bg3 = hex("141414"),
		card = hex("3c3836"), line = hex("504945"),
		text = hex("ebdbb2"), dim = hex("bdae93"), faint = hex("928374"),
		red = hex("fb4934"), orange = hex("fe8019"), yellow = hex("fabd2f"),
		green = hex("b8bb26"), teal = hex("8ec07c"), blue = hex("83a598"),
		purple = hex("d3869b"), pink = hex("d5c4a1"),
	},
	["tokyo-night"] = {
		bg = hex("1a1b26"), bg2 = hex("16161e"), bg3 = hex("101014"),
		card = hex("24283b"), line = hex("414868"),
		text = hex("c0caf5"), dim = hex("a9b1d6"), faint = hex("565f89"),
		red = hex("f7768e"), orange = hex("ff9e64"), yellow = hex("e0af68"),
		green = hex("9ece6a"), teal = hex("73daca"), blue = hex("7aa2f7"),
		purple = hex("bb9af7"), pink = hex("ff75a0"),
	},
	["nord"] = {
		bg = hex("2e3440"), bg2 = hex("292e39"), bg3 = hex("242933"),
		card = hex("3b4252"), line = hex("4c566a"),
		text = hex("eceff4"), dim = hex("d8dee9"), faint = hex("7b88a1"),
		red = hex("bf616a"), orange = hex("d08770"), yellow = hex("ebcb8b"),
		green = hex("a3be8c"), teal = hex("8fbcbb"), blue = hex("88c0d0"),
		purple = hex("b48ead"), pink = hex("c9a1b8"),
	},
	["dracula"] = {
		bg = hex("282a36"), bg2 = hex("21222c"), bg3 = hex("191a21"),
		card = hex("343746"), line = hex("44475a"),
		text = hex("f8f8f2"), dim = hex("bfbfbf"), faint = hex("6272a4"),
		red = hex("ff5555"), orange = hex("ffb86c"), yellow = hex("f1fa8c"),
		green = hex("50fa7b"), teal = hex("8be9fd"), blue = hex("79b8ff"),
		purple = hex("bd93f9"), pink = hex("ff79c6"),
	},
	["everforest"] = {
		bg = hex("2d353b"), bg2 = hex("272e33"), bg3 = hex("232a2e"),
		card = hex("343f44"), line = hex("475258"),
		text = hex("d3c6aa"), dim = hex("9da9a0"), faint = hex("7a8478"),
		red = hex("e67e80"), orange = hex("e69875"), yellow = hex("dbbc7f"),
		green = hex("a7c080"), teal = hex("83c092"), blue = hex("7fbbb3"),
		purple = hex("d699b6"), pink = hex("e3a4bd"),
	},
	["rose-pine"] = {
		bg = hex("191724"), bg2 = hex("1f1d2e"), bg3 = hex("14121f"),
		card = hex("26233a"), line = hex("403d52"),
		text = hex("e0def4"), dim = hex("908caa"), faint = hex("6e6a86"),
		red = hex("eb6f92"), orange = hex("ebbcba"), yellow = hex("f6c177"),
		green = hex("5ec49e"), teal = hex("9ccfd8"), blue = hex("31a8c4"),
		purple = hex("c4a7e7"), pink = hex("ebbcba"),
	},
}

local THEME_NAMES = {}
for name in pairs(THEMES) do
	table.insert(THEME_NAMES, name)
end
table.sort(THEME_NAMES)

local ACCENT_NAMES = { "blue", "purple", "teal", "green", "yellow", "orange", "red", "pink" }

-- The blue grey of a native editor: panel greys with a little blue in them, a
-- flat mid blue for selection, and borders dark enough to actually read as
-- borders rather than as a suggestion.
THEMES["amulet"] = {
	bg = hex("353b48"), bg2 = hex("2f343f"), bg3 = hex("262a33"),
	card = hex("3d4452"), line = hex("1c1f26"),
	text = hex("dfe3ea"), dim = hex("aeb6c4"), faint = hex("7a8393"),
	red = hex("c25b5b"), orange = hex("c8874a"), yellow = hex("c9b458"),
	green = hex("6da05a"), teal = hex("55a3a0"), blue = hex("4a7ab8"),
	purple = hex("8b74bd"), pink = hex("b06a95"),
}

local Theme = {}
Theme.palette = THEMES["catppuccin-mocha"]
Theme.accent = Theme.palette.blue
Theme.radius = 2

function Theme.resolve()
	local name = Config.Get("Nav.Theme")
	Theme.palette = THEMES[name] or THEMES["catppuccin-mocha"]
	local accentName = Config.Get("Nav.Accent")
	Theme.accent = Theme.palette[accentName] or Theme.palette.blue
	-- One number decides whether the whole window reads as a console or as a
	-- native tool. Two pixels rather than zero: a hairline of rounding is what
	-- real toolkits draw, and a perfectly square corner looks like a mistake.
	Theme.radius = if tostring(Config.Get("Nav.WindowStyle")) == "Terminal" then 12 else 2
	return Theme.palette
end

local themeHooks = {}
local function onTheme(callback)
	table.insert(themeHooks, callback)
	pcall(callback, Theme.palette, Theme.accent)
end

local function refreshTheme()
	Theme.resolve()
	for _, callback in ipairs(themeHooks) do
		pcall(callback, Theme.palette, Theme.accent)
	end
end

Theme.resolve()

-- Enum.Font.Code renders rough at the sizes this UI uses. RobotoMono is the
-- clean monospace face and the Gotham family carries the labels. These three
-- values double as role markers: `new` tags whichever one it was handed, so the
-- whole tree can be restyled later without tracking every label by hand.
local FONT_MONO = Enum.Font.RobotoMono
local FONT_UI = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

-- Font.fromName reaches the real font registry rather than the legacy Enum.Font
-- list, so Inter and Inconsolata are available without uploading anything. It is
-- wrapped because a name that is not installed throws, and a missing font should
-- cost a fallback, not the window.
local FONT_SETS
do
	-- Font.fromName reaches the real font registry rather than the legacy
	-- Enum.Font list, so Inter and Inconsolata are available without uploading
	-- anything. Everything about it is guarded: the weight enum is resolved
	-- inside the pcall too, because this runs at load time before any of the
	-- error reporting exists and a throw here takes the whole script with it,
	-- silently.
	local function face(name: string, weightName: string?)
		local ok, font = pcall(function()
			local weight = Enum.FontWeight.Regular
			if weightName then
				weight = (Enum.FontWeight :: any)[weightName] or weight
			end
			return Font.fromName(name, weight)
		end)
		if ok and font then
			return font
		end
		return nil
	end

	FONT_SETS = {
	inter = {
		mono = face("Inconsolata") or Enum.Font.RobotoMono,
		ui = face("Inter", "Medium") or Enum.Font.GothamMedium,
		bold = face("Inter", "Bold") or Enum.Font.GothamBold,
	},
	desktop = {
		mono = face("Inconsolata") or Enum.Font.Code,
		ui = face("Arimo") or Enum.Font.SourceSans,
		bold = face("Arimo", "Bold") or Enum.Font.SourceSansBold,
	},
	mixed = { mono = Enum.Font.RobotoMono, ui = Enum.Font.GothamMedium, bold = Enum.Font.GothamBold },
	mono = { mono = Enum.Font.RobotoMono, ui = Enum.Font.RobotoMono, bold = Enum.Font.RobotoMono },
	sans = { mono = Enum.Font.GothamMedium, ui = Enum.Font.GothamMedium, bold = Enum.Font.GothamBold },
	terminal = { mono = Enum.Font.Code, ui = Enum.Font.Code, bold = Enum.Font.Code },
	}
end

local function fontSet()
	return FONT_SETS[tostring(Config.Get("Nav.FontStyle"))] or FONT_SETS.mixed
end

local function fontRoleOf(font): string
	if font == FONT_MONO then
		return "mono"
	elseif font == FONT_BOLD then
		return "bold"
	end
	return "ui"
end

-- ============================================================================
--  Tiny instance / tween helpers
-- ============================================================================

local function new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	if props then
		for key, value in pairs(props) do
			if key ~= "Parent" then
				(instance :: any)[key] = value
			end
		end
	end
	if props and props.Font then
		-- The construction call always names a legacy Enum.Font so the role can be
		-- read off it, but the active set may hold a Font from the registry, and
		-- those go to FontFace. Assigning one to Font throws, which is exactly how
		-- the first caption button took the whole window down.
		local role = fontRoleOf(props.Font)
		instance:SetAttribute("FontRole", role)
		local chosen = fontSet()[role]
		if chosen then
			pcall(function()
				if typeof(chosen) == "Font" then
					instance.FontFace = chosen
				else
					instance.Font = chosen
				end
			end)
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local function corner(radius: number)
	return new("UICorner", { CornerRadius = UDim.new(0, math.min(radius, Theme.radius or radius)) })
end

local function stroke(color: Color3, thickness: number?, transparency: number?)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function padding(top: number, right: number, bottom: number, left: number)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom),
		PaddingLeft = UDim.new(0, left),
	})
end

local function listLayout(pad: number, direction: Enum.FillDirection?)
	return new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, pad),
	})
end

local activeTweens = {}

local function tween(instance: Instance, props: { [string]: any }, duration: number?, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local animate = Config.Get("Nav.Animations") ~= false
	local speed = tonumber(Config.Get("Nav.AnimationSpeed")) or 1
	if speed <= 0 then
		speed = 1
	end
	local time = (duration or 0.18) / speed
	if not animate or time <= 0.01 then
		for key, value in pairs(props) do
			(instance :: any)[key] = value
		end
		return nil
	end
	local existing = activeTweens[instance]
	if existing then
		pcall(function()
			existing:Cancel()
		end)
	end
	local info = TweenInfo.new(time, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out)
	local created = TweenService:Create(instance, info, props)
	activeTweens[instance] = created
	created.Completed:Connect(function()
		if activeTweens[instance] == created then
			activeTweens[instance] = nil
		end
	end)
	created:Play()
	return created
end

local function lerpColor(a: Color3, b: Color3, alpha: number): Color3
	return a:Lerp(b, alpha)
end

local function roundTo(value: number, step: number): number
	if step <= 0 then
		return value
	end
	return math.floor(value / step + 0.5) * step
end

local function formatNumber(value: number, step: number): string
	if step >= 1 then
		return tostring(math.floor(value + 0.5))
	elseif step >= 0.1 then
		return string.format("%.1f", value)
	end
	return string.format("%.2f", value)
end

local function humanTime(seconds: number): string
	local total = math.floor(seconds)
	local hours = math.floor(total / 3600)
	local minutes = math.floor((total % 3600) / 60)
	local secs = total % 60
	if hours > 0 then
		return string.format("%dh %dm %ds", hours, minutes, secs)
	elseif minutes > 0 then
		return string.format("%dm %ds", minutes, secs)
	end
	return string.format("%ds", secs)
end

-- ============================================================================
--  Settings schema. The UI is generated from this, so adding a tunable is one
--  table entry rather than a new panel.
-- ============================================================================

local function sliderItem(path, label, min, max, step, desc)
	return { path = path, label = label, type = "slider", min = min, max = max, step = step, desc = desc }
end

local function toggleItem(path, label, desc)
	return { path = path, label = label, type = "toggle", desc = desc }
end

local SCHEMA = {
	{
		id = "overview",
		title = "overview",
		glyph = "",
		custom = "fastfetch",
	},
	{
		id = "navigation",
		title = "navigation",
		glyph = "",
		sections = {
			{
				title = "Activation",
				items = {
					toggleItem("Nav.Enabled", "Navigation enabled", "Master switch. Off means clicks are ignored and the character is released."),
					{ path = "Nav.ActivationInput", label = "Activation button", type = "dropdown", options = { "MouseButton1", "MouseButton2", "MouseButton3" }, desc = "Mouse button that starts a route." },
					{ path = "Nav.RequireModifier", label = "Modifier required", type = "dropdown", options = { "None", "LeftShift", "LeftControl", "LeftAlt" }, desc = "Hold this key for the click to register. Useful when left click is already bound in game." },
					sliderItem("Nav.MaxClickDistance", "Max click distance", 0, 1000, 10, "Reject clicks farther than this many studs. 0 disables the limit."),
					toggleItem("Nav.ClickIgnoreNonCollidable", "Click through what you cannot stand on", "A click ray stops on the first thing it touches, and a great deal of what it touches is not floor: invisible kill volumes, trigger pads, decoration. Measured on one obby, a third of the screen resolved to something unwalkable. With this on the ray keeps going until it finds a surface the character could actually stand on."),
					toggleItem("Nav.ClickSnapToGround", "Snap the click to the floor", "Clicking the side of a wall or a steep face aims at the floor beneath it rather than at the wall."),
					sliderItem("Nav.ClickPierce", "Click pierce limit", 1, 32, 1, "How many unwalkable surfaces one click may pass through before giving up."),
					toggleItem("Nav.HoldToRepath", "Hold to repath", "While the button is held, keep retargeting the point under the cursor."),
				},
			},
			{
				title = "Control handoff",
				items = {
					toggleItem("Nav.LockControls", "Lock player controls", "Disables the default control module while a route is active."),
					{ path = "Nav.MoveMethod", label = "Movement method", type = "dropdown", options = { "Auto", "Humanoid:Move", "Humanoid:MoveTo", "WalkToPoint", "WASD", "LinearVelocity", "AssemblyVelocity", "CFrame" }, desc = "How the direction actually reaches the character. Auto starts with Humanoid:Move and escalates when the character is being commanded but not moving. Every method reads the game's own WalkSpeed." },
					{ path = "Nav.MoveMethodResolved", label = "Method in use", type = "label", desc = "What Auto settled on. Saved with the place profile so the next session starts on the one that worked." },
					toggleItem("Nav.ReassertMove", "Re-assert move each frame", "Rewrites the movement vector immediately before physics. Keep this on: without it the default control script overwrites navigation every frame and the character never moves."),
					sliderItem("Nav.MoveToLookAhead", "MoveTo look ahead", 2, 24, 0.5, "How far ahead the MoveTo and WalkToPoint methods aim."),
					sliderItem("Nav.AutoSwitchTime", "Auto switch delay", 0.5, 8, 0.1, "Seconds of being commanded without moving before Auto tries the next method."),
					sliderItem("Nav.AutoSwitchDistance", "Auto switch distance", 0.25, 10, 0.25, "Movement over that window that counts as working."),
					{ path = "Nav.SpeedMode", label = "Speed source", type = "dropdown", options = { "Game", "Multiply", "Absolute" }, desc = "Game follows Humanoid.WalkSpeed exactly. Multiply scales it. Absolute ignores it. Applies to the drivers that supply their own displacement." },
					sliderItem("Nav.SpeedMultiplier", "Speed multiplier", 0.25, 8, 0.05, "Used when the speed source is Multiply."),
					sliderItem("Nav.SpeedAbsolute", "Absolute speed", 4, 250, 1, "Studs per second used when the speed source is Absolute."),
					toggleItem("Nav.ApplyWalkSpeed", "Write the speed to the humanoid", "Also sets Humanoid.WalkSpeed while a route runs, so Humanoid:Move, MoveTo and WASD go at the chosen speed too. Restored when the route ends. Far more visible to a game than the direct drivers."),
					{ path = "Nav.WasdBackend", label = "WASD backend", type = "dropdown", options = { "Auto", "keypress", "VirtualInputManager", "VirtualUser" }, desc = "How WASD emulation reaches the game. A plain LocalScript cannot synthesise input at all, so this needs an executor global or VirtualInputManager." },
					sliderItem("Nav.WasdThreshold", "WASD key threshold", 0.05, 0.9, 0.05, "How far the direction must lean along a camera axis before that key is held. Lower holds two keys more often and gives smoother diagonals."),
					toggleItem("Nav.FaceMoveDirection", "Face the movement direction", "The direct drivers turn the character themselves, because writing velocity or CFrame bypasses the humanoid's own AutoRotate and would otherwise leave you sliding sideways."),
					sliderItem("Nav.TurnSpeed", "Turn speed", 90, 1440, 10, "Degrees per second the character rotates toward the direction of travel."),
					sliderItem("Nav.VelocityMaxForce", "Velocity force", 10000, 1000000, 10000, "Force budget the LinearVelocity driver may spend holding walk speed. Higher pushes through friction and up slopes; too high looks floaty."),
					sliderItem("Nav.CFrameMaxDrift", "CFrame max drift", 0.5, 12, 0.25, "How far the CFrame driver's internal track may run ahead of the real character before it resyncs. This is what stops it walking through a wall when you are actually stuck."),
					toggleItem("Nav.CFrameGroundSnap", "CFrame ground snap", "Follows the floor height so slopes and stairs work instead of walking into them."),
					toggleItem("Nav.CancelOnManualInput", "Cancel on manual input", "Pressing a movement key stops the current route."),
					toggleItem("Nav.StopOnJump", "Cancel on jump", "Space also cancels the route."),
					toggleItem("Nav.DoubleClickSprint", "Double click to sprint", "Raises walk speed for the duration of a route started by a double click."),
					sliderItem("Nav.SprintSpeed", "Sprint speed", 16, 100, 1, "Walk speed applied while sprinting."),
				},
			},
			{
				title = "Feedback",
				items = {
					toggleItem("Nav.Notifications", "Notifications", "Show route accepted / failed messages."),
					{ path = "Nav.NotificationStyle", label = "Notification style", type = "dropdown", options = { "Toast", "Roblox", "Off" }, desc = "Toast is drawn by this UI, Roblox uses the core notification popup." },
					toggleItem("Nav.ShowPathWhileMoving", "Draw path while moving", "Renders route nodes even when the debug panel is closed."),
					toggleItem("Nav.StatusBar", "Status bar", "Bottom bar with live navigation state."),
				},
			},
		},
	},
	{
		id = "agent",
		title = "agent",
		glyph = "",
		sections = {
			{
				title = "Body",
				items = {
					sliderItem("Agent.Radius", "Radius", 0.5, 8, 0.05, "Half width the planner reserves for the character."),
					sliderItem("Agent.MinPassageRadius", "Squeeze radius", 0.5, 8, 0.05, "Fallback radius retried when the normal radius finds no path. Lower means tighter gaps are allowed."),
					sliderItem("Agent.Height", "Height", 2, 12, 0.1, "Vertical clearance required along the route."),
					sliderItem("Agent.WaypointSpacing", "Waypoint spacing", 1, 20, 0.5, "Distance between raw pathfinder waypoints before smoothing."),
					sliderItem("Agent.MaxSlopeDegrees", "Max slope", 5, 89, 1, "Steepest ground counted as walkable. Too low and every ramp reads as a cliff, which makes the controller stop dead partway up."),
					toggleItem("Agent.UseHumanoidSlopeAngle", "Follow the game's slope angle", "Reads Humanoid.MaxSlopeAngle so a game that lets players run up steep ramps is not fought by a fixed number."),
					sliderItem("Agent.MaxSlopeCeiling", "Slope ceiling", 30, 89, 1, "Upper bound applied to the game's own slope angle."),
				},
			},
			{
				title = "Abilities",
				items = {
					toggleItem("Agent.CanJump", "Can jump", "Allows jump waypoints and gap crossing."),
					toggleItem("Agent.CanClimb", "Can climb", "Allows truss and ladder traversal."),
				},
			},
		},
	},
	{
		id = "movement",
		title = "movement",
		glyph = "",
		sections = {
			{
				title = "Following",
				items = {
					sliderItem("Movement.WaypointReachDistance", "Waypoint reach distance", 0.5, 12, 0.1, "How close counts as arriving at a node. Too large makes the character cut corners and stop short of the goal."),
					sliderItem("Movement.LookAheadDistance", "Look ahead distance", 0, 20, 0.5, "Distance at which steering starts blending toward the next node."),
					sliderItem("Steering.MaxBlendTurnDegrees", "Max blend turn", 0, 90, 1, "Sharper corners than this are taken squarely instead of blended."),
					sliderItem("Steering.MaxBlendRise", "Max blend rise", 0, 6, 0.05, "Vertical change above which blending is skipped."),
				},
			},
			{
				title = "Jumping",
				items = {
					{ path = "Movement.JumpMethod", label = "Jump method", type = "dropdown", options = { "Both", "ChangeState", "Jump" }, desc = "How a jump is issued. Humanoid.Jump is only a request and some games drop it entirely, leaving the controller convinced it jumped while the character never left the ground. ChangeState performs the jump directly. Both issues each of them." },
					sliderItem("Movement.JumpCooldown", "Jump cooldown", 0, 3, 0.05, "Minimum seconds between jump attempts."),
					sliderItem("Movement.JumpCommitWindow", "Jump commit window", 0, 3, 0.05, "How long a jump is treated as still in progress."),
					sliderItem("Movement.SmallObstacleHeight", "Small obstacle height", 0, 10, 0.1, "Below this a blocker is stepped over rather than jumped."),
					sliderItem("Movement.MaxJumpableObstacleHeight", "Max jumpable height", 0, 20, 0.1, "Tallest blocker the agent will try to jump."),
					sliderItem("Movement.MaxJumpRise", "Max jump rise", 0, 20, 0.1, "Highest upward landing accepted."),
					sliderItem("Movement.MaxJumpDrop", "Max jump drop", 0, 60, 0.5, "Deepest downward landing accepted."),
					sliderItem("Movement.GapProbeDistance", "Gap probe distance", 0, 20, 0.25, "How far ahead the floor is sampled for holes."),
					sliderItem("Movement.MaxGapJumpDistance", "Max gap jump", 0, 30, 0.25, "Widest gap the agent will attempt."),
					sliderItem("Movement.JumpProbeDepth", "Jump probe depth", 4, 80, 1, "Downward raycast length used to find a landing."),
					sliderItem("Movement.LandingStepTolerance", "Landing step tolerance", 0.25, 8, 0.25, "How far a ground sample must differ in height from the ground underfoot before it counts as something worth jumping over. Without this the landing search returns the platform the character is already standing on and the jump fires straight up on the spot."),
					sliderItem("Movement.LandingScanStart", "Landing scan start", 0.25, 8, 0.25, "How close to the body the landing scan begins. It has to start near the feet even when only a far landing is wanted, otherwise the gap between here and there is never seen."),
					sliderItem("Movement.GapProbeSamples", "Gap probe samples", 2, 16, 1, "How many points are sampled along the forward gap probe. One sample at the far end steps clean over any gap narrower than the probe itself."),
					sliderItem("Movement.JumpForceAfterFailures", "Force jump after refusals", 0, 10, 1, "After this many consecutive refusals at the same spot the jump is attempted anyway, unless the gap is a genuine fall. Zero disables it and restores the old behaviour of replanning forever."),
					sliderItem("Movement.JumpSearchStep", "Jump search step", 0.25, 5, 0.05, "Sampling resolution when scanning for a landing."),
					sliderItem("Movement.ActionReevaluateWindow", "Action reevaluate window", 0.1, 6, 0.05, "How long a pending jump or climb is trusted before re-deciding."),
					sliderItem("Movement.ArrivalLockDistance", "Arrival lock distance", 0, 20, 0.5, "Inside this distance from the goal the controller stops replanning and repairing and simply finishes. Without it the endgame can loop between repair and approach and never settle."),
				},
			},
			{
				title = "Stuck detection",
				items = {
					sliderItem("Movement.StuckDistanceEpsilon", "Progress threshold", 0.1, 8, 0.05, "Movement below this over the timeout counts as stuck."),
					sliderItem("Movement.StuckTimeout", "Stuck timeout", 0.2, 8, 0.05, "Seconds of no progress before the stuck flag raises."),
					sliderItem("Movement.HardStopConfirmFrames", "Hard stop confirmations", 1, 12, 1, "Consecutive frames with no ground ahead before movement is cut. 1 reproduces the old behaviour of stopping on a single bad probe."),
				},
			},
		},
	},
	{
		id = "pathing",
		title = "pathing",
		glyph = "",
		sections = {
			{
				title = "Route shape",
				items = {
					{ path = "PathSmoothing.Mode", label = "Smoothing mode", type = "dropdown", options = { "Taut", "Shortcut", "Off" }, desc = "Taut drags the route against corners so it stops swinging wide around obstacles. Shortcut is the old greedy pass only." },
					sliderItem("PathSmoothing.SafetyBias", "Safety bias", 0, 1, 0.05, "0 is the shortest route it can prove walkable, 1 keeps the most margin from ledges and corners. Safety wins ties."),
					sliderItem("PathSmoothing.CornerClearance", "Corner clearance", 0, 6, 0.1, "How far the route stays off a corner it is hugging."),
					sliderItem("PathSmoothing.Passes", "Smoothing passes", 1, 6, 1, "More passes pull tighter and cost more raycasts."),
					sliderItem("PathSmoothing.SearchIterations", "Search iterations", 2, 10, 1, "Binary search steps per node when finding how far it can be pulled."),
					sliderItem("PathSmoothing.MinSlack", "Minimum slack", 0, 5, 0.05, "Corners with less detour than this are left alone."),
					sliderItem("PathSmoothing.GroundSamples", "Ground samples", 1, 8, 1, "Floor checks per candidate segment. More is safer and slower."),
					toggleItem("PathSmoothing.DropRedundantNodes", "Drop redundant nodes", "Removes a node when its neighbours can already see each other."),
					sliderItem("PathSmoothing.MaxLookAheadNodes", "Shortcut look ahead", 2, 24, 1, "How many nodes ahead the greedy pass probes. This is the main cost control: the old uncapped version was the biggest source of frame spikes."),
					sliderItem("PathSmoothing.MaxProbesPerRoute", "Raycast budget", 100, 4000, 50, "Hard ceiling on raycasts for one route computation. Once spent the planner keeps what it has instead of stalling the frame."),
					sliderItem("PathSmoothing.MinNodeSpacing", "Minimum node spacing", 0, 10, 0.25, "Waypoints closer together than this are merged. Dense nodes cost smoothing, validation and follow time while carrying no extra information."),
					sliderItem("PathSmoothing.MaxNodes", "Maximum nodes", 8, 200, 4, "Hard cap on route length. Jump waypoints are never dropped."),
				},
			},
			{
				title = "When pathfinding refuses",
				items = {
					toggleItem("PathFallback.Enabled", "Probe the world ourselves", "PathfindingService reports NoPath for anything its navmesh does not join up, including gaps and offset ledges a player walks across without thinking. When it refuses, the planner fans out from the current position looking for reachable ground using the same walkability test the follower uses."),
					sliderItem("PathFallback.MaxSteps", "Max probe steps", 4, 80, 1, "How many hops the fallback will chain before giving up."),
					sliderItem("PathFallback.StepDistance", "Probe step distance", 2, 24, 0.5, "How far each hop reaches."),
					sliderItem("PathFallback.MinStepDistance", "Minimum step distance", 1, 12, 0.5, "Shortest hop it will settle for when the full reach is blocked."),
					sliderItem("PathFallback.ArrivalDistance", "Fallback arrival distance", 1, 16, 0.5, "How close a probe hop must get before the goal counts as reached."),
					sliderItem("PathFallback.MaxSidesteps", "Max sidesteps", 0, 20, 1, "Consecutive hops allowed that do not get closer to the goal. This is what lets it walk around a blocker instead of stopping at it. 0 makes the search purely greedy."),
					sliderItem("PathFallback.VisitCellSize", "Visit cell size", 1, 12, 0.5, "Grid used to remember where the probe has already been, so it cannot ping-pong between two points."),
					sliderItem("PathFallback.HeadingBias", "Heading bias", 0, 4, 0.05, "How strongly the search prefers carrying on in the direction it was already going. Two mirror-image detours score the same without it, and the search dithers."),
				},
			},
			{
				title = "Update rates",
				items = {
					sliderItem("UpdateRates.PathReplanCooldown", "Replan cooldown", 0.05, 5, 0.05, "Minimum seconds between full replans."),
					sliderItem("UpdateRates.SegmentRepairCooldown", "Repair cooldown", 0.05, 5, 0.05, "Minimum seconds between local route repairs."),
					sliderItem("UpdateRates.ProbeInterval", "Probe interval", 0.02, 2, 0.02, "How often the sideways escape probe runs."),
					sliderItem("UpdateRates.ObstacleScanInterval", "Obstacle scan interval", 0.02, 2, 0.02, "How often the forward line of sight sweep runs."),
					sliderItem("UpdateRates.GoalDriftThreshold", "Goal drift threshold", 0.5, 40, 0.5, "Goal movement that forces a replan."),
				},
			},
			{
				title = "Route validation",
				items = {
					toggleItem("RouteValidation.Enabled", "Validate upcoming route", "Re-checks the next few nodes for ground and clearance."),
					sliderItem("RouteValidation.Interval", "Validation interval", 0.05, 3, 0.05, "Seconds between validation passes."),
					sliderItem("RouteValidation.LookAheadNodes", "Look ahead nodes", 1, 20, 1, "How many upcoming nodes are checked."),
					sliderItem("RouteValidation.LookAheadDistance", "Look ahead distance", 4, 120, 1, "Distance cap for the validation sweep."),
					sliderItem("RouteValidation.TrussNodeMinDistance", "Truss node min distance", 0, 10, 0.1, "Nodes at least this far from a truss edge are exempt from ground checks."),
					sliderItem("RouteValidation.TrussNodeMaxDistance", "Truss node max distance", 0.5, 20, 0.1, "Search radius used to detect a truss near a node."),
				},
			},
			{
				title = "Shortcutting",
				items = {
					sliderItem("Shortcut.SampleSpacing", "Sample spacing", 0.5, 12, 0.25, "Distance between clearance samples along a candidate shortcut."),
					sliderItem("Shortcut.SideProbeOffset", "Side probe offset", 0, 6, 0.05, "Lateral offset used to test shoulder clearance."),
					sliderItem("Shortcut.ClearanceProbeOffset", "Clearance probe offset", 0, 6, 0.05, "Vertical offset used to test head clearance."),
					sliderItem("Shortcut.MinClearanceCheckDistance", "Min clearance distance", 0, 40, 0.5, "Shortcuts shorter than this skip the clearance test."),
					sliderItem("Shortcut.MaxVerticalSnap", "Max vertical snap", 0, 12, 0.05, "Height difference tolerated when snapping a shortcut to ground."),
					sliderItem("Shortcut.MaxWalkRise", "Max walk rise", 0, 12, 0.05, "Steepest step up a shortcut may include."),
					sliderItem("Shortcut.MaxWalkDrop", "Max walk drop", 0, 20, 0.05, "Deepest step down a shortcut may include."),
					sliderItem("Shortcut.MaxRisk", "Max risk", 0, 5, 0.05, "Total penalty budget before a shortcut is rejected. Raise for straighter paths, lower for safer ones."),
					sliderItem("Shortcut.MissingSidePenalty", "Missing side penalty", 0, 3, 0.05, "Risk added when a shoulder probe finds nothing."),
					sliderItem("Shortcut.ExposedEdgePenalty", "Exposed edge penalty", 0, 3, 0.05, "Risk added near an unsupported edge."),
					sliderItem("Shortcut.ClearancePenalty", "Clearance penalty", 0, 3, 0.05, "Risk added when head clearance is marginal."),
				},
			},
			{
				title = "Escape probe",
				items = {
					sliderItem("Probe.MinGain", "Min gain", 0, 20, 0.25, "Improvement a probe direction must offer to be taken."),
					sliderItem("Probe.ForcedMinGain", "Forced min gain", 0, 20, 0.05, "Lower bar used when the agent is already blocked."),
				},
			},
			{
				title = "Route cache",
				items = {
					sliderItem("Cache.CellSize", "Cell size", 1, 40, 1, "Grid size used to bucket cached routes. Larger reuses more aggressively."),
					sliderItem("Cache.TTL", "Cache lifetime", 0, 20, 0.25, "Seconds a cached route stays valid. 0 effectively disables the cache."),
					sliderItem("Cache.MaxEntries", "Max entries", 8, 1024, 8, "Cached route budget."),
					sliderItem("Query.MaxPassThroughHits", "Max pass-through hits", 1, 128, 1, "Raycast retries allowed when punching through non blocking parts."),
				},
			},
		},
	},
	{
		id = "traversal",
		title = "traversal",
		glyph = "",
		sections = {
			{
				title = "Truss",
				items = {
					sliderItem("Truss.EntryDepth", "Entry depth", 0, 20, 0.25, "How far into a truss the entry probe reaches."),
					sliderItem("Truss.SideClearance", "Side clearance", 0, 12, 0.1, "Lateral room needed to mount a truss."),
					sliderItem("Truss.VerticalProbe", "Vertical probe", 0, 20, 0.25, "Vertical sample length used to measure a truss."),
					sliderItem("Truss.TopExitHeight", "Top exit height", 0, 20, 0.25, "Clearance needed above a truss to step off the top."),
					sliderItem("Truss.BottomDrop", "Bottom drop", 0, 30, 0.25, "Drop tolerated when leaving a truss at the bottom."),
					sliderItem("Truss.MaxApproachAngleDegrees", "Max approach angle", 0, 180, 1, "Widest angle to a truss face that still allows mounting."),
				},
			},
			{
				title = "Climbing",
				items = {
					toggleItem("Climb.Enabled", "Climbing enabled", "Allows tagged ladders and climbable surfaces."),
					sliderItem("Climb.Speed", "Climb speed", 1, 40, 0.5, "Studs per second while climbing."),
					sliderItem("Climb.SurfaceOffset", "Surface offset", 0, 6, 0.05, "Distance kept from the climbed surface."),
					sliderItem("Climb.ExitOffset", "Exit offset", 0, 8, 0.05, "Step out distance when leaving a climb."),
					sliderItem("Climb.MinVerticalTravel", "Min vertical travel", 0, 20, 0.25, "Height difference required before a climb is worth starting."),
					sliderItem("Climb.TopExitHeight", "Top exit height", 0, 20, 0.25, "Clearance needed above the surface to exit at the top."),
					sliderItem("Climb.BottomProbeDepth", "Bottom probe depth", 0, 20, 0.25, "Downward search length for a bottom exit."),
					sliderItem("Climb.MaxApproachAngleDegrees", "Max approach angle", 0, 180, 1, "Widest angle to the surface that still allows a climb."),
					{ path = "Climb.LadderTag", label = "Ladder tag", type = "text", desc = "CollectionService tag treated as a ladder." },
					{ path = "Climb.LadderAttribute", label = "Ladder attribute", type = "text", desc = "Attribute name treated as a ladder." },
					{ path = "Climb.PassThroughAttribute", label = "Pass-through attribute", type = "text", desc = "Attribute marking parts raycasts should ignore." },
					{ path = "Climb.BlockingAttribute", label = "Blocking attribute", type = "text", desc = "Attribute forcing a part to count as solid." },
				},
			},
		},
	},
	{
		id = "recovery",
		title = "recovery",
		glyph = "",
		sections = {
			{
				title = "Stuck ladder",
				items = {
					sliderItem("StuckRecovery.StuckEnterTime", "Enter time", 0, 5, 0.05, "Seconds stuck before recovery begins."),
					sliderItem("StuckRecovery.StageTimeout", "Stage timeout", 0.05, 5, 0.05, "Seconds spent on each recovery stage."),
					sliderItem("StuckRecovery.SidestepDistance", "Sidestep distance", 0, 12, 0.25, "Lateral distance probed during the sidestep stage."),
					sliderItem("StuckRecovery.BackOffDistance", "Back off distance", 0, 12, 0.25, "Reverse distance used during the back off stage."),
					sliderItem("StuckRecovery.MaxStuckTime", "Max stuck time", 0.5, 20, 0.5, "Total stuck budget before the route is abandoned."),
				},
			},
			{
				title = "Path recovery",
				items = {
					toggleItem("Recovery.Enabled", "Wait and retry on NoPath", "Instead of failing immediately, hold and retry when the pathfinder reports no path."),
					toggleItem("Recovery.OnlyAfterSuccessfulRoute", "Only after a good route", "Restricts retrying to routes that were valid at least once."),
					sliderItem("Recovery.RetryInterval", "Retry interval", 0.1, 10, 0.1, "Seconds between retry attempts."),
					sliderItem("Recovery.MaxWaitTime", "Max wait time", 1, 60, 0.5, "Give up after this long."),
				},
			},
			{
				title = "Tracking fallback",
				items = {
					sliderItem("Fallback.GraceTime", "Grace time", 0, 5, 0.05, "How long good progress keeps the fallback satisfied."),
					sliderItem("Fallback.MinProgressDelta", "Min progress delta", 0, 3, 0.01, "Distance gain that counts as progress."),
					sliderItem("Fallback.MaxTrackError", "Max track error", 0, 20, 0.1, "Lateral drift from the segment that is still acceptable."),
					sliderItem("Fallback.MinAlignmentDot", "Min alignment", -1, 1, 0.05, "Dot product between intent and actual motion required."),
				},
			},
			{
				title = "Target tracking",
				items = {
					toggleItem("TargetTracking.Enabled", "Track moving targets", "Re-routes when an Instance destination moves."),
					sliderItem("TargetTracking.Interval", "Check interval", 0.1, 5, 0.1, "Seconds between target position samples."),
					sliderItem("TargetTracking.MoveThreshold", "Move threshold", 0.1, 20, 0.1, "Target movement that forces a re-route."),
				},
			},
		},
	},
	{
		id = "hazards",
		title = "hazards",
		glyph = "",
		sections = {
			{
				title = "Hazard detection",
				items = {
					{ path = "Hazard.Tag", label = "Hazard tag", type = "text", desc = "CollectionService tag treated as lethal." },
					{ path = "Hazard.Attribute", label = "Hazard attribute", type = "text", desc = "Attribute name treated as lethal." },
					{ path = "Hazard.NameTokens", label = "Name tokens", type = "list", desc = "Comma separated substrings. A part whose name contains one is treated as a hazard." },
					sliderItem("Hazard.ClearanceHeight", "Clearance height", 0, 30, 0.5, "Height above a hazard that still counts as unsafe."),
					sliderItem("Hazard.ProbeDepth", "Probe depth", 1, 60, 1, "Downward ray length used to find hazards under a node."),
				},
			},
			{
				title = "Kill brick awareness",
				open = true,
				items = {
					toggleItem("KillBricks.Enabled", "Learn what actually kills", "Names and tags only catch what a developer chose to label. With this on, every character part reports what it touches, and when health drops the parts touched a moment earlier are blamed and remembered. Off by default because it connects to every character part and to other players."),
					toggleItem("KillBricks.LearnFromDamage", "Learn from damage taken", "Blame recently touched parts when health drops. This is the part that does the actual learning."),
					toggleItem("KillBricks.GeneralizeBySignature", "Generalise by shape", "A kill brick is almost never alone. Learning one covers every part sharing its name, size, colour and material, so a single death teaches the whole set."),
					toggleItem("KillBricks.WatchOtherPlayers", "Watch other players", "Other players walk into the same hazards. Watching where they die means a map can be learned without dying for it once."),
					toggleItem("KillBricks.HeuristicScan", "Sweep for obvious ones", "A budgeted, resumable pass looking for parts named or tagged like hazards. Never scans everything in one frame."),
					toggleItem("KillBricks.Persist", "Remember per place", "Saves what was learned alongside the place profile, so the next session starts already knowing."),
					toggleItem("KillBricks.AnnounceLearned", "Announce discoveries", "Toast when something new is learned."),
					sliderItem("KillBricks.AvoidRadius", "Avoidance radius", 0, 20, 0.5, "How far routes keep clear of something known to be lethal. Standing next to lava is not survivable just because the ground underfoot is solid. 0 means only the surface itself is avoided."),
					sliderItem("KillBricks.BlameWindow", "Blame window", 0.05, 2, 0.05, "How recently a part must have been touched to be blamed for damage."),
					sliderItem("KillBricks.MinDamageFraction", "Minimum damage", 0, 0.5, 0.01, "Fraction of max health a hit must remove before anything is blamed. Filters out chip damage and regeneration noise."),
					sliderItem("KillBricks.RespawnGrace", "Respawn grace", 0, 6, 0.25, "Seconds after spawning during which damage is ignored, so spawn effects do not condemn the spawn platform."),
					sliderItem("KillBricks.ScanBudget", "Sweep budget", 100, 5000, 50, "Instances examined per sweep pass."),
					sliderItem("KillBricks.ScanInterval", "Sweep interval", 1, 60, 1, "Seconds between sweep passes."),
					sliderItem("KillBricks.MaxLearned", "Memory limit", 32, 2048, 32, "How many distinct hazard shapes are held before learning stops."),
					{ path = "KillBricks.Forget", label = "Forget everything learned", type = "button", action = function()
						KillBricks.Forget()
						KillBricks.Save()
					end, desc = "Clears what was learned for this place and deletes the saved copy." },
				},
			},
		},
	},
	{
		id = "debug",
		title = "debug",
		glyph = "",
		sections = {
			{
				title = "Renderer",
				items = {
					toggleItem("Debug.Enabled", "Debug rendering", "Draws the route, probes and obstacles in the world."),
					sliderItem("Debug.NodeSize", "Node size", 0.1, 4, 0.05, "Radius of route node markers."),
					sliderItem("Debug.UpdateLifetime", "Marker lifetime", 0.1, 6, 0.05, "Seconds a transient marker stays visible."),
					sliderItem("Debug.DrawInterval", "Draw interval", 0.016, 0.5, 0.005, "Seconds between debug redraws. Redrawing every frame reparents the whole marker pool and is a real frame cost."),
				},
			},
			{
				title = "Layers",
				items = {
					toggleItem("Debug.Layers.Route", "Route", "Path nodes and the active waypoint."),
					toggleItem("Debug.Layers.Rays", "Rays", "Escape probe rays."),
					toggleItem("Debug.Layers.Gaps", "Gaps", "Gap and landing samples."),
					toggleItem("Debug.Layers.Jumps", "Jumps", "Jump decisions and landing points."),
					toggleItem("Debug.Layers.Climb", "Climb", "Truss and ladder measurements."),
					toggleItem("Debug.Layers.Ground", "Ground", "Ground safety samples."),
				},
			},
			{
				title = "Colors",
				items = {
					{ path = "Debug.PathColor", label = "Path", type = "color" },
					{ path = "Debug.NextNodeColor", label = "Next node", type = "color" },
					{ path = "Debug.ProbeColor", label = "Probe", type = "color" },
					{ path = "Debug.BlockedProbeColor", label = "Blocked probe", type = "color" },
					{ path = "Debug.ObstacleColor", label = "Obstacle", type = "color" },
					{ path = "Debug.SteeringColor", label = "Steering target", type = "color" },
					{ path = "Debug.LandingColor", label = "Landing", type = "color" },
					{ path = "Debug.ClimbColor", label = "Climb", type = "color" },
				},
			},
			{
				title = "Console",
				items = {
					{ path = "Nav.LogLevel", label = "Log level", type = "dropdown", options = { "Verbose", "Info", "Warn", "Error" }, desc = "Lowest severity printed to the developer console." },
				},
			},
		},
	},
	{
		id = "theme",
		title = "theme",
		glyph = "",
		sections = {
			{
				title = "Performance",
				items = {
					{ path = "Performance.Preset", label = "Preset", type = "dropdown", options = { "Quality", "Balanced", "Performance", "Potato" }, desc = "Moves the scan intervals, smoothing effort and raycast budget together. Every value it touches is still individually tunable." },
				},
			},
			{
				title = "Appearance",
				items = {
					{ path = "Nav.WindowStyle", label = "Window style", type = "dropdown", options = { "Desktop", "Terminal" }, desc = "Desktop squares every corner, fills the panel headers and puts a menu bar across the top, the way a native tool looks. Terminal is the rounded dark console look." },
					{ path = "Nav.FontStyle", label = "Font", type = "dropdown", options = { "inter", "desktop", "mixed", "mono", "sans", "terminal" }, desc = "inter and desktop pull real font families through Font.fromName rather than the legacy Enum.Font list: Inter or Arimo for labels, Inconsolata for values." },
					{ path = "Nav.Theme", label = "Palette", type = "dropdown", options = THEME_NAMES, desc = "Colour scheme for this UI." },
					{ path = "Nav.Accent", label = "Accent", type = "dropdown", options = ACCENT_NAMES, desc = "Highlight colour pulled from the active palette." },
					toggleItem("Nav.BlurBackground", "Blur behind window", "Applies a Lighting UI.blur while the window is open."),
					toggleItem("Nav.BootSplash", "Loading screen", "Shows the splash while the window is built. The bar tracks real stages, and the frame it yields between them is what keeps the build from arriving as one hitch."),
					sliderItem("Nav.BootSplashMinTime", "Loading screen floor", 0, 5, 0.1, "Shortest the splash stays up. The bar itself always tracks real work; on a fast machine the whole build finishes inside a few frames, and without a floor the screen would be gone before it registered."),
					toggleItem("Nav.Animations", "Animations", "Tweened transitions. Off makes every change instant."),
					sliderItem("Nav.AnimationSpeed", "Animation speed", 0.25, 4, 0.05, "Multiplier on every transition duration."),
				},
			},
		},
	},
	{
		id = "keybinds",
		title = "keybinds",
		glyph = "",
		sections = {
			{
				title = "Bindings",
				items = {
					{ path = "Nav.ToggleUIKey", label = "Toggle this window", type = "keybind" },
					{ path = "Nav.ToggleNavKey", label = "Toggle navigation", type = "keybind" },
					{ path = "Nav.StopKey", label = "Stop current route", type = "keybind" },
				},
			},
		},
	},
	{
		id = "profiles",
		title = "profiles",
		glyph = "",
		custom = "profiles",
	},
}

-- Every page gets one line saying what it is for. A settings screen that opens
-- straight into forty controls with no framing is the thing that makes a deep
-- tool feel hostile.
-- Window chrome, page registries and the mutable flags the runtime shares. One
-- table instead of fifty top level names: this is a single Luau chunk, a chunk
-- gets 200 registers, and the file had run out of them. Roblox's compiler
-- rejects the whole script when that happens, silently, with no window and no
-- error, which is a genuinely horrible thing to debug.
local UI = {}

-- Page framing, sidebar grouping and detail levels. One table rather than eight
-- top level names: the script is a single chunk and Lua caps a function at 200
-- locals, which this file is close to.
local UIMeta = {}

-- Every page gets one line saying what it is for. A settings screen that opens
-- straight into forty controls with no framing is the thing that makes a deep
-- tool feel hostile.
UIMeta.Blurb = {
	overview = "What is loaded, what it is doing, and the switches worth reaching for.",
	navigation = "How a click becomes a route, and who is allowed to drive the character.",
	agent = "The size and abilities the planner assumes the character has.",
	movement = "How the character follows a route once one exists.",
	pathing = "How a route is found, shaped and kept honest.",
	traversal = "Climbing, trusses and everything that is not plain walking.",
	recovery = "What happens when the route stops working.",
	hazards = "What counts as lethal, and how much room to give it.",
	debug = "Draw what the solver is thinking, and how loudly it talks.",
	theme = "How this window looks and how hard it works.",
	keybinds = "Keys this script owns.",
	profiles = "Save a tuned setup per place and bring it back.",
}

-- Twelve equal entries in one list is a list, not a structure. Grouping them
-- means the sidebar reads as a map of the tool instead of an inventory.
UIMeta.Groups = {
	{ caption = "dashboard", tabs = { "overview" } },
	{ caption = "navigation", tabs = { "navigation", "movement", "agent" } },
	{ caption = "pathing", tabs = { "pathing", "traversal", "recovery" } },
	{ caption = "safety", tabs = { "hazards" } },
	{ caption = "system", tabs = { "theme", "debug", "keybinds", "profiles" } },
}

UIMeta.Rank = { Basic = 1, Advanced = 2, Everything = 3 }
UIMeta.AutoOpenRows = 8
UIMeta.Level = {}
-- head frame -> the outer row that owns it, so layout and filtering act on the
-- whole row rather than just the line the control sits on.
UIMeta.Outer = {}
UIMeta.Descriptions = {}
UIMeta.Open = {}
UIMeta.Touched = {}
UIMeta.Cards = {}

do
	-- Basic is what someone actually reaches for. Everything unlisted is
	-- Advanced, and a handful of genuinely internal knobs are Expert, so a deep
	-- tool can stay deep without putting all of it in the way.
	local basic = {
		"Nav.Enabled", "Nav.ActivationInput", "Nav.RequireModifier", "Nav.HoldToRepath",
		"Nav.MaxClickDistance", "Nav.LockControls", "Nav.MoveMethod", "Nav.MoveMethodResolved",
		"Nav.SpeedMode", "Nav.SpeedMultiplier", "Nav.SpeedAbsolute", "Nav.ApplyWalkSpeed",
		"Nav.WasdBackend", "Nav.Toasts", "Nav.StatusBar",
		"Agent.Radius", "Agent.Height", "Agent.CanJump", "Agent.CanClimb",
		"Movement.JumpMethod", "Movement.WaypointReachDistance",
		"PathSmoothing.Mode", "PathSmoothing.SafetyBias", "PathFallback.Enabled",
		"RouteValidation.Enabled",
		"Hazard.Tag", "Hazard.Attribute", "Hazard.NameTokens",
		"KillBricks.Enabled", "KillBricks.AvoidRadius", "KillBricks.WatchOtherPlayers",
		"KillBricks.Persist", "KillBricks.Forget",
		"Debug.Enabled", "Nav.LogLevel",
		"Performance.Preset", "Nav.Theme", "Nav.Accent", "Nav.FontStyle",
		"Nav.Animations", "Nav.BlurBackground",
		"Nav.ToggleUIKey", "Nav.ToggleNavKey", "Nav.StopKey",
	}
	local expert = {
		"Shortcut.MissingSidePenalty", "Shortcut.ExposedEdgePenalty", "Shortcut.ClearancePenalty",
		"Shortcut.SideProbeStride", "Shortcut.ClearanceProbeOffset", "Shortcut.MinClearanceCheckDistance",
		"Query.MaxPassThroughHits", "Cache.CellSize", "Cache.MaxEntries",
		"PathFallback.VisitCellSize", "PathFallback.HeadingBias", "PathFallback.MinStepDistance",
		"PathSmoothing.SearchIterations", "PathSmoothing.MinSlack", "PathSmoothing.MinImprovement",
		"RouteValidation.TrussNodeMinDistance", "RouteValidation.TrussNodeMaxDistance",
		"Movement.LandingScanStart", "Movement.MinJumpProgress", "Movement.JumpSearchStep",
		"KillBricks.ScanBudget", "KillBricks.ScanInterval", "KillBricks.MaxLearned",
		"KillBricks.MinDamageFraction", "KillBricks.BlameWindow",
	}
	for _, path in ipairs(basic) do
		UIMeta.Level[path] = 1
	end
	for _, path in ipairs(expert) do
		UIMeta.Level[path] = 3
	end
end

function UIMeta.levelOf(item): number
	if item.level then
		return UIMeta.Rank[item.level] or 2
	end
	return UIMeta.Level[item.path or ""] or 2
end

function UIMeta.ceiling(): number
	return UIMeta.Rank[tostring(Config.Get("Nav.DetailLevel"))] or 1
end

-- ============================================================================
--  UI shell
-- ============================================================================

local playerGui = player:WaitForChild("PlayerGui")

for _, existing in ipairs(playerGui:GetChildren()) do
	if existing.Name == "PortableNavigationUI" or existing.Name == "PortableNavigationDebug" or existing.Name == "PortableNavigationNotice" or existing.Name == "PortableNavigationBoot" then
		existing:Destroy()
	end
end

local gui = new("ScreenGui", {
	Name = "PortableNavigationUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})


-- ---------------------------------------------------------------------------
--  Boot splash
--
--  The bar tracks real work. Every page of the settings window is built as its
--  own step with a frame yielded in between, which is also why the window no
--  longer arrives as one three thousand instance hitch. Nothing here is a timed
--  fake: if a stage is slow the bar sits there, because the bar is the stage.
-- ---------------------------------------------------------------------------

UIMeta.Boot = {}
do
	-- Waiting between stages is only meaningful on a running client with a frame
	-- to give back. Anywhere else every stage runs back to back and the splash
	-- simply never appears, which is what should happen off a real client.
	local canYield = false
	do
		local ok, running = pcall(function()
			return game:GetService("RunService"):IsRunning()
		end)
		canYield = ok and running == true
	end
	local splash, bar, fill, stageLabel, percentLabel, card, backdrop
	local total, done = 1, 0
	local active = false
	local startedAt = 0

	-- A stroke between two points in the logo's 80x80 box. A vertical frame's
	-- long axis points down, so the rotation is measured off that.
	local function limb(parent, x1, y1, x2, y2, thickness, colour)
		local dx, dy = x2 - x1, y2 - y1
		local length = math.sqrt(dx * dx + dy * dy)
		return new("Frame", {
			Name = "Limb",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((x1 + x2) * 0.5, (y1 + y2) * 0.5),
			Size = UDim2.fromOffset(thickness, length + thickness * 0.5),
			Rotation = -math.deg(math.atan2(dx, dy)),
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			Parent = parent,
		}, { corner(thickness * 0.5) })
	end

	local function buildLogo(parent)
		local holder = new("Frame", {
			Name = "Arch",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 30),
			Size = UDim2.fromOffset(96, 96),
			BackgroundTransparency = 1,
			Parent = parent,
		})

		-- Apex, two feet, and the V notch cut up out of the base.
		local accent = Theme.accent
		local apexX, apexY = 48, 4
		local footL, footR = 5, 91
		local baseY = 90
		local notchX, notchY = 48, 60
		local notchL = 30

		-- Two legs to the apex, a base broken by a V notch: the Arch mark.
		limb(holder, apexX, apexY, footL, baseY, 6, accent)
		limb(holder, apexX, apexY, footR, baseY, 6, accent)
		limb(holder, footL, baseY, notchL, baseY, 6, accent)
		limb(holder, notchL, baseY, notchX, notchY, 6, accent)
		limb(holder, notchX, notchY, 96 - notchL, baseY, 6, accent)
		limb(holder, 96 - notchL, baseY, footR, baseY, 6, accent)
		return holder
	end

	function UIMeta.Boot.Begin(steps: number)
		if Config.Get("Nav.BootSplash") == false then
			return
		end
		total = math.max(1, steps)
		done = 0
		active = true
		startedAt = os.clock()

		splash = new("ScreenGui", {
			Name = "PortableNavigationBoot",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 1000,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = playerGui,
		})

		backdrop = new("Frame", {
			Name = "Backdrop",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.palette.bg3,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			Parent = splash,
		})

		card = new("Frame", {
			Name = "Card",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(340, 280),
			BackgroundColor3 = Theme.palette.bg,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = splash,
		}, { corner(14) })

		buildLogo(card)

		new("TextLabel", {
			Name = "Wordmark",
			Position = UDim2.new(0, 0, 0, 140),
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			Font = FONT_BOLD,
			Text = "Portable Navigation",
			TextSize = 21,
			TextColor3 = Theme.palette.text,
			Parent = card,
		})

		new("TextLabel", {
			Name = "Version",
			Position = UDim2.new(0, 0, 0, 166),
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Font = FONT_MONO,
			Text = "v" .. SCRIPT_VERSION,
			TextSize = 11,
			TextColor3 = Theme.palette.faint,
			Parent = card,
		})

		bar = new("Frame", {
			Name = "Bar",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 202),
			Size = UDim2.fromOffset(244, 4),
			BackgroundColor3 = Theme.palette.card,
			BorderSizePixel = 0,
			Parent = card,
		}, { corner(2) })

		fill = new("Frame", {
			Name = "Fill",
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = Theme.accent,
			BorderSizePixel = 0,
			Parent = bar,
		}, { corner(2) })

		stageLabel = new("TextLabel", {
			Name = "Stage",
			Position = UDim2.new(0, 24, 0, 218),
			Size = UDim2.new(1, -48, 0, 16),
			BackgroundTransparency = 1,
			Font = FONT_MONO,
			Text = "starting",
			TextSize = 11,
			TextColor3 = Theme.palette.dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})

		percentLabel = new("TextLabel", {
			Name = "Percent",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -24, 0, 218),
			Size = UDim2.fromOffset(40, 16),
			BackgroundTransparency = 1,
			Font = FONT_MONO,
			Text = "0%",
			TextSize = 11,
			TextColor3 = Theme.palette.faint,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = card,
		})

		tween(card, { BackgroundTransparency = 0 }, 0.18)
	end

	function UIMeta.Boot.Step(text: string)
		done += 1
		_G.__PortableNavigationBootStage = text
		if not active or not splash or not splash.Parent then
			return
		end
		local fraction = math.clamp(done / total, 0, 1)
		stageLabel.Text = text
		percentLabel.Text = string.format("%d%%", math.floor(fraction * 100 + 0.5))
		tween(fill, { Size = UDim2.new(fraction, 0, 1, 0) }, 0.12)

		if canYield then
			-- The bar's position is real: it is stage N of M, never a timer. What
			-- the floor does is set a pace, so a build that finishes in four
			-- frames is still legible. If the real work is slower than the pace,
			-- the work wins and the bar simply lags behind it.
			local floor = tonumber(Config.Get("Nav.BootSplashMinTime")) or 0
			local dueAt = startedAt + floor * fraction
			-- Bounded on purpose. Waiting on Heartbeat is supposed to give a frame
			-- back, but under an executor scheduler it can return without the
			-- clock having moved, and an unbounded wait-until-the-clock-catches-up
			-- then spins forever and takes the whole boot with it.
			local guard = 0
			while os.clock() < dueAt and guard < 240 do
				guard += 1
				local waited = pcall(function()
					game:GetService("RunService").Heartbeat:Wait()
				end)
				if not waited then
					break
				end
			end
		end
	end

	function UIMeta.Boot.Finish()
		if not active or not splash or not splash.Parent then
			active = false
			return
		end
		active = false
		fill.Size = UDim2.new(1, 0, 1, 0)
		stageLabel.Text = "done"
		percentLabel.Text = "100%"

		-- The bar is real, so on a fast machine the whole build lands inside a few
		-- frames and the screen would be gone before it registered. Only the
		-- finished state is padded, never the progress.
		local floor = tonumber(Config.Get("Nav.BootSplashMinTime")) or 0
		local remaining = math.max(0, floor - (os.clock() - startedAt))

		local held = splash
		task.delay(0.5 + remaining, function()
			if not held or not held.Parent then
				return
			end
			tween(backdrop, { BackgroundTransparency = 1 }, 0.35)
			tween(card, { BackgroundTransparency = 1 }, 0.35)
			for _, descendant in ipairs(held:GetDescendants()) do
				if descendant:IsA("TextLabel") then
					tween(descendant, { TextTransparency = 1 }, 0.3)
				elseif descendant:IsA("Frame") and descendant.Name ~= "Card" and descendant.Name ~= "Backdrop" then
					tween(descendant, { BackgroundTransparency = 1 }, 0.3)
				end
			end
			task.delay(0.45, function()
				pcall(function()
					held:Destroy()
				end)
			end)
		end)
	end
end

-- Restyling by attribute means a font swap does not need every widget to
-- register its own hook.
-- A set entry is either a legacy Enum.Font or a Font object from the registry,
-- and the two go to different properties.
local function applyFonts()
	local set = fontSet()
	for _, descendant in ipairs(gui:GetDescendants()) do
		local role = descendant:GetAttribute("FontRole")
		if role then
			local chosen = set[role] or set.ui
			pcall(function()
				if typeof(chosen) == "Font" then
					descendant.FontFace = chosen
				else
					descendant.Font = chosen
				end
			end)
		end
	end
end

local refreshers = {}
local function addRefresher(callback)
	table.insert(refreshers, callback)
	pcall(callback)
end

local function refreshAll()
	for _, callback in ipairs(refreshers) do
		pcall(callback)
	end
end

-- ---------------------------------------------------------------------------
--  Toasts
-- ---------------------------------------------------------------------------

-- Toasts sit above the window: they are created before it, and with Sibling
-- ZIndex behaviour creation order would otherwise bury them.
local toastHolder = new("Frame", {
	Name = "Toasts",
	ZIndex = 200,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -16),
	Size = UDim2.fromOffset(300, 400),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}),
})

local toastOrder = 0

local function toast(message: string, kind: string?)
	if Config.Get("Nav.Notifications") == false then
		return
	end
	local style = Config.Get("Nav.NotificationStyle")
	if style == "Off" then
		return
	end
	if style == "Roblox" then
		pcall(function()
			StarterGui:SetCore("SendNotification", { Title = "Navigation", Text = message, Duration = 2 })
		end)
		return
	end

	local palette = Theme.palette
	local tint = palette.blue
	if kind == "error" then
		tint = palette.red
	elseif kind == "good" then
		tint = palette.green
	elseif kind == "warn" then
		tint = palette.yellow
	end

	toastOrder += 1
	local card = new("Frame", {
		Name = "Toast",
		ZIndex = 200,
		LayoutOrder = toastOrder,
		Size = UDim2.new(0, 280, 0, 40),
		BackgroundColor3 = palette.bg2,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = toastHolder,
	}, {
		corner(8),
		stroke(palette.line, 1, 1),
		new("Frame", {
			Name = "Bar",
			ZIndex = 201,
			Size = UDim2.new(0, 3, 1, -12),
			Position = UDim2.new(0, 8, 0, 6),
			BackgroundColor3 = tint,
			BorderSizePixel = 0,
		}, { corner(2) }),
		new("TextLabel", {
			Name = "Body",
			ZIndex = 201,
			Position = UDim2.new(0, 20, 0, 0),
			Size = UDim2.new(1, -30, 1, 0),
			BackgroundTransparency = 1,
			Font = FONT_MONO,
			Text = message,
			TextSize = 12,
			TextColor3 = palette.text,
			TextTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
		}),
	})

	card.Position = UDim2.new(0, 40, 0, 0)
	tween(card, { BackgroundTransparency = 0.05, Position = UDim2.new(0, 0, 0, 0) }, 0.25)
	tween(card:FindFirstChild("Body"), { TextTransparency = 0 }, 0.25)
	local outline = card:FindFirstChildOfClass("UIStroke")
	if outline then
		tween(outline, { Transparency = 0.4 }, 0.25)
	end

	task.delay(2.6, function()
		if not card.Parent then
			return
		end
		tween(card, { BackgroundTransparency = 1, Position = UDim2.new(0, 40, 0, 0) }, 0.22)
		local body = card:FindFirstChild("Body")
		if body then
			tween(body, { TextTransparency = 1 }, 0.22)
		end
		task.delay(0.3, function()
			card:Destroy()
		end)
	end)
end

-- ---------------------------------------------------------------------------
--  Window
-- ---------------------------------------------------------------------------

local WINDOW_SIZE = Vector2.new(940, 620)

local window = new("Frame", {
	Name = "Window",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
	BackgroundColor3 = Theme.palette.bg,
	BorderSizePixel = 0,
	Active = true,
	Visible = false,
	Parent = gui,
}, {
	corner(12),
	stroke(Theme.palette.line, 1, 0.2),
})

local titleBar = new("Frame", {
	Name = "TitleBar",
	Size = UDim2.new(1, 0, 0, 26),
	BackgroundColor3 = Theme.palette.bg3,
	BorderSizePixel = 0,
	Active = true,
	Parent = window,
}, { corner(12) })

-- Square off the bottom corners of the rounded title bar.
new("Frame", {
	Name = "TitleBarFoot",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 12),
	BackgroundColor3 = Theme.palette.bg3,
	BorderSizePixel = 0,
	Parent = titleBar,
})

local titleAccent = new("Frame", {
	Name = "Accent",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 2),
	BackgroundColor3 = Theme.accent,
	BorderSizePixel = 0,
	ZIndex = 3,
	Parent = titleBar,
}, {
	new("UIGradient", {
		Name = "Flow",
		Color = ColorSequence.new(Theme.accent),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.85),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 0.85),
		}),
	}),
})

-- A menu bar, because that is what the top of a real tool has. The entries do
-- actual work rather than standing in for it: everything here is something the
-- window can already do, put where a desktop user reaches for it.
UI.menuBar = new("Frame", {
	Name = "MenuBar",
	Position = UDim2.new(0, 6, 0, 0),
	Size = UDim2.new(0, 320, 1, 0),
	BackgroundTransparency = 1,
	ZIndex = 4,
	Parent = titleBar,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
	}),
})

UI.menuPopup = new("Frame", {
	Name = "MenuPopup",
	Size = UDim2.fromOffset(210, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Theme.palette.bg2,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 60,
	Parent = window,
}, {
	corner(3),
	stroke(Theme.palette.line, 1, 0),
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
	padding(4, 0, 4, 0),
})

function UI.closeMenu()
	UI.menuPopup.Visible = false
	UI.openMenu = nil
end

function UI.buildMenu(label, order, items)
	local button = new("TextButton", {
		Name = "Menu_" .. label,
		LayoutOrder = order,
		Size = UDim2.fromOffset(#label * 8 + 18, 26),
		BackgroundColor3 = Theme.accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = FONT_UI,
		Text = label,
		TextSize = 12,
		TextColor3 = Theme.palette.dim,
		AutoButtonColor = false,
		ZIndex = 5,
		Parent = UI.menuBar,
	})

	local function open()
		for _, child in ipairs(UI.menuPopup:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for index, item in ipairs(items) do
			if item.separator then
				new("Frame", {
					Name = "Sep",
					LayoutOrder = index,
					Size = UDim2.new(1, 0, 0, 1),
					BackgroundColor3 = Theme.palette.line,
					BorderSizePixel = 0,
					ZIndex = 61,
					Parent = UI.menuPopup,
				})
			else
				local entry = new("TextButton", {
					Name = "Item",
					LayoutOrder = index,
					Size = UDim2.new(1, 0, 0, 22),
					BackgroundColor3 = Theme.accent,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Font = FONT_UI,
					Text = "",
					AutoButtonColor = false,
					ZIndex = 61,
					Parent = UI.menuPopup,
				})
				new("TextLabel", {
					Name = "Label",
					Position = UDim2.new(0, 12, 0, 0),
					Size = UDim2.new(1, -24, 1, 0),
					BackgroundTransparency = 1,
					Font = FONT_UI,
					Text = item.text,
					TextSize = 12,
					TextColor3 = Theme.palette.text,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 62,
					Parent = entry,
				})
				entry.MouseEnter:Connect(function()
					entry.BackgroundTransparency = 0.15
				end)
				entry.MouseLeave:Connect(function()
					entry.BackgroundTransparency = 1
				end)
				entry.MouseButton1Click:Connect(function()
					UI.closeMenu()
					pcall(item.run)
				end)
			end
		end

		-- Positioned inside the window in its own coordinates. Placing it on the
		-- ScreenGui and doing the maths in absolute space put it a GUI inset too
		-- high, which is the same class of bug as every other inset mistake: two
		-- coordinate spaces that look identical until something has a topbar.
		UI.menuPopup.Position = UDim2.fromOffset(
			button.AbsolutePosition.X - window.AbsolutePosition.X,
			titleBar.Size.Y.Offset
		)
		UI.menuPopup.Visible = true
		UI.openMenu = label
	end

	button.MouseButton1Click:Connect(function()
		if UI.openMenu == label then
			UI.closeMenu()
		else
			open()
		end
	end)
	button.MouseEnter:Connect(function()
		button.BackgroundTransparency = 0.25
		-- Once one menu is open the others open on hover, the way menu bars work.
		if UI.openMenu and UI.openMenu ~= label then
			open()
		end
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundTransparency = 1
	end)

	onTheme(function(palette, accent)
		button.BackgroundColor3 = accent
		button.TextColor3 = palette.dim
	end)
	return button
end

do
	local function captionButton(order, glyph, name, hover)
		local button = new("TextButton", {
			Name = name,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -(order - 1) * 28 - 4, 0, 0),
			Size = UDim2.fromOffset(28, 26),
			BackgroundColor3 = hover,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = FONT_MONO,
			Text = glyph,
			TextSize = 12,
			TextColor3 = Theme.palette.dim,
			AutoButtonColor = false,
			ZIndex = 5,
			Parent = titleBar,
		})
		button.MouseEnter:Connect(function()
			button.BackgroundTransparency = 0.1
			button.TextColor3 = Theme.palette.text
		end)
		button.MouseLeave:Connect(function()
			button.BackgroundTransparency = 1
			button.TextColor3 = Theme.palette.dim
		end)
		return button
	end

	UI.closeDot = captionButton(1, "X", "Close", Theme.palette.red)
	UI.zoomDot = captionButton(2, "[]", "Zoom", Theme.palette.card)
	UI.minimiseDot = captionButton(3, "_", "Minimise", Theme.palette.card)
end

UI.titleText = new("TextLabel", {
	Name = "Title",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 0),
	Size = UDim2.new(0, 320, 1, 0),
	BackgroundTransparency = 1,
	Font = FONT_MONO,
	Text = "Portable Navigation",
	TextSize = 12,
	TextColor3 = Theme.palette.dim,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 4,
	Parent = titleBar,
})

UI.versionChip = new("TextLabel", {
	Name = "Version",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -84, 0.5, 0),
	Size = UDim2.fromOffset(54, 16),
	BackgroundColor3 = Theme.palette.card,
	BorderSizePixel = 0,
	Font = FONT_MONO,
	Text = "v" .. SCRIPT_VERSION,
	TextSize = 11,
	TextColor3 = Theme.accent,
	ZIndex = 4,
	Parent = titleBar,
}, { corner(6) })

-- Drag the window by its title bar.
do
	local dragging = false
	local dragStart, startPosition

	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPosition = window.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - dragStart
		window.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

-- ---------------------------------------------------------------------------
--  Sidebar
-- ---------------------------------------------------------------------------

local sidebar = new("Frame", {
	Name = "Sidebar",
	Position = UDim2.new(0, 0, 0, 38),
	Size = UDim2.new(0, 176, 1, -38 - 26),
	BackgroundColor3 = Theme.palette.bg2,
	BorderSizePixel = 0,
	Active = true,
	Parent = window,
})

UI.sidebarHeader = new("TextLabel", {
	Name = "Header",
	Position = UDim2.new(0, 16, 0, 12),
	Size = UDim2.new(1, -24, 0, 18),
	BackgroundTransparency = 1,
	Font = FONT_MONO,
	Text = "~/nav",
	TextSize = 12,
	TextColor3 = Theme.palette.faint,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = sidebar,
})

UI.tabList = new("ScrollingFrame", {
	Name = "Tabs",
	Position = UDim2.new(0, 8, 0, 36),
	Size = UDim2.new(1, -16, 1, -80),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 2,
	ScrollBarImageColor3 = Theme.palette.line,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = sidebar,
}, { listLayout(2) })

UI.sidebarStatus = new("Frame", {
	Name = "Status",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundTransparency = 1,
	Parent = sidebar,
})

UI.powerDot = new("Frame", {
	Name = "Dot",
	Position = UDim2.new(0, 16, 0.5, -4),
	Size = UDim2.fromOffset(8, 8),
	BackgroundColor3 = Theme.palette.green,
	BorderSizePixel = 0,
	Parent = UI.sidebarStatus,
}, { corner(4) })

UI.powerLabel = new("TextButton", {
	Name = "PowerLabel",
	Position = UDim2.new(0, 32, 0, 0),
	Size = UDim2.new(1, -40, 1, 0),
	BackgroundTransparency = 1,
	Font = FONT_MONO,
	Text = "enabled",
	TextSize = 12,
	TextColor3 = Theme.palette.green,
	TextXAlignment = Enum.TextXAlignment.Left,
	AutoButtonColor = false,
	Parent = UI.sidebarStatus,
})

-- ---------------------------------------------------------------------------
--  Content region
-- ---------------------------------------------------------------------------

local content = new("Frame", {
	Name = "Content",
	Position = UDim2.new(0, 176, 0, 38),
	Size = UDim2.new(1, -176, 1, -38 - 26),
	BackgroundTransparency = 1,
	Active = true,
	Parent = window,
})

UI.searchBar = new("Frame", {
	Name = "SearchBar",
	Position = UDim2.new(0, 14, 0, 12),
	Size = UDim2.new(1, -28 - 244, 0, 30),
	BackgroundColor3 = Theme.palette.bg2,
	BorderSizePixel = 0,
	Parent = content,
}, {
	corner(8),
	stroke(Theme.palette.line, 1, 0.35),
	new("TextLabel", {
		Name = "Prompt",
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.fromOffset(16, 30),
		BackgroundTransparency = 1,
		Font = FONT_MONO,
		Text = "/",
		TextSize = 13,
		TextColor3 = Theme.accent,
	}),
})

UI.searchBox = new("TextBox", {
	Name = "Search",
	Position = UDim2.new(0, 28, 0, 0),
	Size = UDim2.new(1, -38, 1, 0),
	BackgroundTransparency = 1,
	Font = FONT_MONO,
	PlaceholderText = "filter settings",
	PlaceholderColor3 = Theme.palette.faint,
	Text = "",
	TextSize = 13,
	TextColor3 = Theme.palette.text,
	TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false,
	Parent = UI.searchBar,
})

-- Detail level and descriptions live next to the search box rather than being
-- repeated on every page. Both are the answer to the same complaint: a hundred
-- and fifty controls with a paragraph each, all at once, is not a settings
-- screen, it is a data dump. Basic shows the forty odd that matter.
do
	local levels = { "Basic", "Advanced", "Everything" }
	local segment = new("Frame", {
		Name = "DetailLevel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -52, 0, 12),
		Size = UDim2.fromOffset(186, 30),
		BackgroundColor3 = Theme.palette.bg2,
		BorderSizePixel = 0,
		Parent = content,
	}, {
		corner(8),
		stroke(Theme.palette.line, 1, 0.35),
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),
		padding(3, 3, 3, 3),
	})

	local buttons = {}
	local function paintSegment()
		local current = tostring(Config.Get("Nav.DetailLevel"))
		for name, entry in pairs(buttons) do
			local selected = name == current
			tween(entry.button, { BackgroundTransparency = if selected then 0 else 1 }, 0.14)
			tween(entry.button, { TextColor3 = if selected then Theme.palette.bg3 else Theme.palette.faint }, 0.14)
			entry.button.BackgroundColor3 = Theme.accent
		end
	end

	for index, name in ipairs(levels) do
		local button = new("TextButton", {
			Name = name,
			LayoutOrder = index,
			Size = UDim2.new(1 / #levels, 0, 1, 0),
			BackgroundColor3 = Theme.accent,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = FONT_MONO,
			Text = ({ Basic = "basic", Advanced = "adv", Everything = "all" })[name] or string.lower(name),
			TextSize = 11,
			TextColor3 = Theme.palette.faint,
			AutoButtonColor = false,
			Parent = segment,
		}, { corner(6) })

		button.MouseButton1Click:Connect(function()
			Config.Set("Nav.DetailLevel", name)
			paintSegment()
			UIMeta.applyFilter()
		end)
		buttons[name] = { button = button }
	end

	local descToggle = new("TextButton", {
		Name = "Descriptions",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 12),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Theme.palette.bg2,
		BorderSizePixel = 0,
		Font = FONT_MONO,
		Text = "i",
		TextSize = 13,
		TextColor3 = Theme.palette.faint,
		AutoButtonColor = false,
		Parent = content,
	}, { corner(8), stroke(Theme.palette.line, 1, 0.35) })

	local function paintDesc()
		local on = Config.Get("Nav.ShowDescriptions") == true
		tween(descToggle, { TextColor3 = if on then Theme.accent else Theme.palette.faint }, 0.14)
	end

	descToggle.MouseButton1Click:Connect(function()
		Config.Set("Nav.ShowDescriptions", Config.Get("Nav.ShowDescriptions") ~= true)
		paintDesc()
		UIMeta.applyFilter()
	end)

	UIMeta.paintToolbar = function()
		paintSegment()
		paintDesc()
	end

	onTheme(function(palette)
		segment.BackgroundColor3 = palette.bg2
		descToggle.BackgroundColor3 = palette.bg2
		paintSegment()
		paintDesc()
	end)
end

UI.pages = {}

local function makePage(id: string)
	local page = new("ScrollingFrame", {
		Name = "Page_" .. id,
		Position = UDim2.new(0, 14, 0, 52),
		Size = UDim2.new(1, -28, 1, -64),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.palette.line,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = content,
	}, { listLayout(10), padding(0, 6, 14, 0) })
	UI.pages[id] = page
	return page
end

-- ---------------------------------------------------------------------------
--  Status bar
-- ---------------------------------------------------------------------------

UI.statusBar = new("Frame", {
	Name = "StatusBar",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 26),
	BackgroundColor3 = Theme.palette.bg3,
	BorderSizePixel = 0,
	Active = true,
	Parent = window,
}, { corner(12) })

new("Frame", {
	Name = "StatusHead",
	Size = UDim2.new(1, 0, 0, 12),
	BackgroundColor3 = Theme.palette.bg3,
	BorderSizePixel = 0,
	Parent = UI.statusBar,
})

UI.statusLeft = new("TextLabel", {
	Name = "Left",
	Position = UDim2.new(0, 14, 0, 0),
	Size = UDim2.new(0.6, 0, 1, 0),
	BackgroundTransparency = 1,
	Font = FONT_MONO,
	Text = "",
	TextSize = 11,
	TextColor3 = Theme.palette.dim,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 3,
	Parent = UI.statusBar,
})

UI.statusRight = new("TextLabel", {
	Name = "Right",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 0),
	Size = UDim2.new(0.4, 0, 1, 0),
	BackgroundTransparency = 1,
	Font = FONT_MONO,
	Text = "",
	TextSize = 11,
	TextColor3 = Theme.palette.faint,
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 3,
	Parent = UI.statusBar,
})

-- ---------------------------------------------------------------------------
--  Floating UI.launcher (visible while the window is closed)
-- ---------------------------------------------------------------------------

UI.launcher = new("TextButton", {
	Name = "Launcher",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.fromOffset(38, 38),
	BackgroundColor3 = Theme.palette.bg2,
	BorderSizePixel = 0,
	Font = FONT_MONO,
	Text = "~",
	TextSize = 18,
	TextColor3 = Theme.accent,
	AutoButtonColor = false,
	Parent = gui,
}, {
	corner(10),
	stroke(Theme.palette.line, 1, 0.3),
})

UI.launcherPulse = new("Frame", {
	Name = "Pulse",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -5, 1, -5),
	Size = UDim2.fromOffset(6, 6),
	BackgroundColor3 = Theme.palette.green,
	BorderSizePixel = 0,
	Parent = UI.launcher,
}, { corner(3) })

-- ============================================================================
--  Widgets
-- ============================================================================

-- One global drag owner instead of a pair of UI.connections per slider.
UI.activeDrag = nil

UserInputService.InputChanged:Connect(function(input)
	if not UI.activeDrag then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		UI.activeDrag(input.Position)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		UI.activeDrag = nil
	end
end)

UI.awaitingKeybind = nil

local function makeBar(parent, props)
	local bar = new("Frame", props and props.frame or {}, {})
	bar.Name = "Bar"
	bar.BackgroundColor3 = Theme.palette.card
	bar.BorderSizePixel = 0
	bar.Parent = parent
	corner(4).Parent = bar

	local fill = new("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.accent,
		BorderSizePixel = 0,
		Parent = bar,
	}, { corner(4) })

	local knob = new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(11, 11),
		BackgroundColor3 = Theme.palette.text,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = bar,
	}, { corner(6) })

	onTheme(function(palette, accent)
		bar.BackgroundColor3 = palette.card
		fill.BackgroundColor3 = accent
		knob.BackgroundColor3 = palette.text
	end)

	local api = {}

	function api.SetFraction(fraction: number, animate: boolean?)
		fraction = math.clamp(fraction, 0, 1)
		if animate then
			tween(fill, { Size = UDim2.new(fraction, 0, 1, 0) }, 0.14)
			tween(knob, { Position = UDim2.new(fraction, 0, 0.5, 0) }, 0.14)
		else
			fill.Size = UDim2.new(fraction, 0, 1, 0)
			knob.Position = UDim2.new(fraction, 0, 0.5, 0)
		end
	end

	function api.BindDrag(onFraction)
		local function update(position)
			local width = bar.AbsoluteSize.X
			if width <= 0 then
				return
			end
			local fraction = math.clamp((position.X - bar.AbsolutePosition.X) / width, 0, 1)
			onFraction(fraction)
		end

		bar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				UI.activeDrag = update
				update(input.Position)
			end
		end)
		knob.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				UI.activeDrag = update
			end
		end)
	end

	api.Bar = bar
	return api
end

-- Rows live inside a section card and are separated by a hairline instead of
-- each being its own outlined panel. Forty settings drawn as forty bordered
-- boxes is what made a deep page read as a wall.
--
-- The row is two stacked pieces: a fixed height head that carries the label and
-- the control, and an optional description underneath that wraps and sizes
-- itself. Nothing is clipped and nothing is estimated from character counts.
local function baseRow(parent, item, controlHeight)
	local outer = new("Frame", {
		Name = "Row",
		Size = UDim2.new(1, 0, 0, controlHeight),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.palette.bg2,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = parent,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),
	})

	local head = new("Frame", {
		Name = "Head",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, controlHeight),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = outer,
	})

	local label = new("TextLabel", {
		Name = "Label",
		Position = UDim2.new(0, 14, 0, 0),
		Size = UDim2.new(1, -240, 0, controlHeight),
		BackgroundTransparency = 1,
		Font = FONT_UI,
		Text = item.label,
		TextSize = 13,
		TextColor3 = Theme.palette.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = head,
	})

	local desc
	if item.desc then
		desc = new("TextLabel", {
			Name = "Desc",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = FONT_MONO,
			Text = item.desc,
			TextSize = 11,
			LineHeight = 1.25,
			TextColor3 = Theme.palette.faint,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Visible = false,
			Parent = outer,
		}, { padding(0, 18, 11, 14) })
		UIMeta.Descriptions[desc] = true
	end

	local hairline = new("Frame", {
		Name = "Rule",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.palette.line,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Parent = outer,
	})

	onTheme(function(palette)
		label.TextColor3 = palette.text
		hairline.BackgroundColor3 = palette.line
		if desc then
			desc.TextColor3 = palette.faint
		end
	end)

	outer:SetAttribute("SearchKey", string.lower((item.label or "") .. " " .. (item.path or "") .. " " .. (item.desc or "")))
	UIMeta.Outer[head] = outer
	return head, controlHeight
end

local Widgets = {}

function Widgets.toggle(parent, item)
	local row = baseRow(parent, item, 38)

	local track = new("TextButton", {
		Name = "Track",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 9),
		Size = UDim2.fromOffset(42, 20),
		BackgroundColor3 = Theme.palette.card,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Parent = row,
	}, { corner(10) })

	local knob = new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Theme.palette.faint,
		BorderSizePixel = 0,
		Parent = track,
	}, { corner(7) })

	local function render(animate)
		local value = Config.Get(item.path) == true
		local palette = Theme.palette
		if animate then
			tween(track, { BackgroundColor3 = if value then Theme.accent else palette.card }, 0.16)
			tween(knob, {
				Position = if value then UDim2.new(1, -17, 0.5, 0) else UDim2.new(0, 3, 0.5, 0),
				BackgroundColor3 = if value then palette.bg3 else palette.faint,
			}, 0.16, Enum.EasingStyle.Back)
		else
			track.BackgroundColor3 = if value then Theme.accent else palette.card
			knob.Position = if value then UDim2.new(1, -17, 0.5, 0) else UDim2.new(0, 3, 0.5, 0)
			knob.BackgroundColor3 = if value then palette.bg3 else palette.faint
		end
	end

	track.MouseButton1Click:Connect(function()
		Config.Set(item.path, not (Config.Get(item.path) == true))
		render(true)
	end)

	addRefresher(function()
		render(false)
	end)
	onTheme(function()
		render(false)
	end)
	return row
end

function Widgets.slider(parent, item)
	local row = baseRow(parent, item, 54)

	local valueChip = new("TextLabel", {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 9),
		Size = UDim2.fromOffset(62, 18),
		BackgroundColor3 = Theme.palette.card,
		BorderSizePixel = 0,
		Font = FONT_MONO,
		Text = "0",
		TextSize = 11,
		TextColor3 = Theme.accent,
		Parent = row,
	}, { corner(5) })

	local bar = makeBar(row, {
		frame = {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 36),
			Size = UDim2.new(0, 170, 0, 5),
		},
	})

	local span = item.max - item.min

	local function render(animate)
		local value = tonumber(Config.Get(item.path)) or item.min
		valueChip.Text = formatNumber(value, item.step)
		bar.SetFraction(if span > 0 then (value - item.min) / span else 0, animate)
	end

	bar.BindDrag(function(fraction)
		local raw = item.min + fraction * span
		local value = math.clamp(roundTo(raw, item.step), item.min, item.max)
		Config.Set(item.path, value)
		render(false)
	end)

	-- Right click the value to put this one setting back to its default.
	local resetButton = new("TextButton", {
		Name = "Reset",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 9),
		Size = UDim2.fromOffset(62, 18),
		BackgroundTransparency = 1,
		Text = "",
		Parent = row,
	})
	resetButton.MouseButton2Click:Connect(function()
		Config.ResetPath(item.path)
		render(true)
	end)

	addRefresher(function()
		render(false)
	end)
	onTheme(function(palette, accent)
		valueChip.BackgroundColor3 = palette.card
		valueChip.TextColor3 = accent
		render(false)
	end)
	return row
end

function Widgets.dropdown(parent, item)
	local row, baseHeight = baseRow(parent, item, 38)

	local options = item.options or {}
	local optionHeight = 24
	local open = false

	local button = new("TextButton", {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.fromOffset(196, 22),
		BackgroundColor3 = Theme.palette.card,
		BorderSizePixel = 0,
		Font = FONT_MONO,
		Text = "",
		TextSize = 11,
		TextColor3 = Theme.palette.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		Parent = row,
	}, { corner(6), padding(0, 22, 0, 8) })

	local caret = new("TextLabel", {
		Name = "Caret",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		Font = FONT_MONO,
		Text = "v",
		TextSize = 10,
		TextColor3 = Theme.accent,
		Parent = button,
	})

	local menu = new("Frame", {
		Name = "Menu",
		Position = UDim2.new(0, 14, 0, baseHeight),
		Size = UDim2.new(1, -28, 0, #options * optionHeight),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = row,
	}, { listLayout(0) })

	local optionButtons = {}
	for index, option in ipairs(options) do
		local entry = new("TextButton", {
			Name = "Option_" .. option,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, optionHeight),
			BackgroundColor3 = Theme.palette.bg3,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = FONT_MONO,
			Text = "  " .. option,
			TextSize = 11,
			TextColor3 = Theme.palette.dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false,
			Parent = menu,
		}, { corner(4) })
		optionButtons[option] = entry

		entry.MouseEnter:Connect(function()
			tween(entry, { BackgroundTransparency = 0.15 }, 0.1)
		end)
		entry.MouseLeave:Connect(function()
			tween(entry, { BackgroundTransparency = 1 }, 0.1)
		end)
	end

	local function setOpen(state)
		open = state
		menu.Visible = state
		tween(row, { Size = UDim2.new(1, 0, 0, if state then baseHeight + #options * optionHeight + 10 else baseHeight) }, 0.2)
		tween(caret, { Rotation = if state then 180 else 0 }, 0.2)
	end

	local function render()
		local value = tostring(Config.Get(item.path))
		button.Text = value
		for option, entry in pairs(optionButtons) do
			entry.TextColor3 = if option == value then Theme.accent else Theme.palette.dim
		end
	end

	for option, entry in pairs(optionButtons) do
		entry.MouseButton1Click:Connect(function()
			Config.Set(item.path, option)
			render()
			setOpen(false)
		end)
	end

	button.MouseButton1Click:Connect(function()
		setOpen(not open)
	end)

	addRefresher(render)
	onTheme(function(palette, accent)
		button.BackgroundColor3 = palette.card
		button.TextColor3 = palette.text
		caret.TextColor3 = accent
		for _, entry in pairs(optionButtons) do
			entry.BackgroundColor3 = palette.bg3
		end
		render()
	end)
	return row
end

function Widgets.keybind(parent, item)
	local row = baseRow(parent, item, 38)

	local button = new("TextButton", {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.fromOffset(196, 22),
		BackgroundColor3 = Theme.palette.card,
		BorderSizePixel = 0,
		Font = FONT_MONO,
		Text = "",
		TextSize = 11,
		TextColor3 = Theme.palette.text,
		AutoButtonColor = false,
		Parent = row,
	}, { corner(6) })

	local function render()
		button.Text = tostring(Config.Get(item.path))
		button.TextColor3 = Theme.palette.text
	end

	button.MouseButton1Click:Connect(function()
		if UI.awaitingKeybind then
			UI.awaitingKeybind.cancel()
		end
		button.Text = "press a key  (esc cancels)"
		button.TextColor3 = Theme.accent
		UI.awaitingKeybind = {
			accept = function(keyName)
				Config.Set(item.path, keyName)
				UI.awaitingKeybind = nil
				render()
			end,
			cancel = function()
				UI.awaitingKeybind = nil
				render()
			end,
		}
	end)

	addRefresher(render)
	onTheme(function(palette)
		button.BackgroundColor3 = palette.card
		render()
	end)
	return row
end

function Widgets.label(parent, item)
	local row = baseRow(parent, item, 38)

	local value = new("TextLabel", {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 11),
		Size = UDim2.fromOffset(196, 16),
		BackgroundTransparency = 1,
		Font = FONT_MONO,
		Text = "",
		TextSize = 11,
		TextColor3 = Theme.accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})

	local function render()
		value.Text = tostring(Config.Get(item.path))
	end

	addRefresher(render)
	onTheme(function(_, accent)
		value.TextColor3 = accent
		render()
	end)
	return row
end

function Widgets.color(parent, item)
	local row, baseHeight = baseRow(parent, item, 38)
	local open = false

	local swatch = new("TextButton", {
		Name = "Swatch",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 9),
		Size = UDim2.fromOffset(52, 20),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Parent = row,
	}, { corner(5), stroke(Theme.palette.line, 1, 0.4) })

	local hexLabel = new("TextLabel", {
		Name = "Hex",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -74, 0, 11),
		Size = UDim2.fromOffset(74, 16),
		BackgroundTransparency = 1,
		Font = FONT_MONO,
		Text = "#ffffff",
		TextSize = 11,
		TextColor3 = Theme.palette.faint,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})

	local editor = new("Frame", {
		Name = "Editor",
		Position = UDim2.new(0, 14, 0, baseHeight + 2),
		Size = UDim2.new(1, -28, 0, 66),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = row,
	}, { listLayout(6) })

	local channels = {}
	for index, channelName in ipairs({ "R", "G", "B" }) do
		local line = new("Frame", {
			Name = channelName,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Parent = editor,
		}, {
			new("TextLabel", {
				Name = "Tag",
				Size = UDim2.fromOffset(14, 16),
				BackgroundTransparency = 1,
				Font = FONT_MONO,
				Text = channelName,
				TextSize = 11,
				TextColor3 = Theme.palette.faint,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		})
		channels[channelName] = makeBar(line, {
			frame = {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 20, 0.5, 0),
				Size = UDim2.new(1, -20, 0, 5),
			},
		})
	end

	local function currentColor(): Color3
		local value = Config.Get(item.path)
		if typeof(value) == "Color3" then
			return value
		end
		return Color3.new(1, 1, 1)
	end

	local function render()
		local color = currentColor()
		swatch.BackgroundColor3 = color
		hexLabel.Text = "#" .. color:ToHex()
		channels.R.SetFraction(color.R, false)
		channels.G.SetFraction(color.G, false)
		channels.B.SetFraction(color.B, false)
	end

	local function bindChannel(name, apply)
		channels[name].BindDrag(function(fraction)
			Config.Set(item.path, apply(currentColor(), fraction))
			render()
		end)
	end
	bindChannel("R", function(color, value)
		return Color3.new(value, color.G, color.B)
	end)
	bindChannel("G", function(color, value)
		return Color3.new(color.R, value, color.B)
	end)
	bindChannel("B", function(color, value)
		return Color3.new(color.R, color.G, value)
	end)

	swatch.MouseButton1Click:Connect(function()
		open = not open
		editor.Visible = open
		tween(row, { Size = UDim2.new(1, 0, 0, if open then baseHeight + 74 else baseHeight) }, 0.2)
	end)

	addRefresher(render)
	onTheme(function(palette)
		hexLabel.TextColor3 = palette.faint
		render()
	end)
	return row
end

local function textRow(parent, item, width, toText, fromText)
	local row = baseRow(parent, item, 38)

	local box = new("TextBox", {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.fromOffset(width, 22),
		BackgroundColor3 = Theme.palette.card,
		BorderSizePixel = 0,
		Font = FONT_MONO,
		Text = "",
		TextSize = 11,
		TextColor3 = Theme.palette.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ClearTextOnFocus = false,
		Parent = row,
	}, { corner(6), padding(0, 8, 0, 8) })

	local function render()
		box.Text = toText(Config.Get(item.path))
	end

	box.FocusLost:Connect(function()
		Config.Set(item.path, fromText(box.Text))
		render()
	end)

	addRefresher(render)
	onTheme(function(palette)
		box.BackgroundColor3 = palette.card
		box.TextColor3 = palette.text
	end)
	return row
end

function Widgets.text(parent, item)
	return textRow(parent, item, 196, function(value)
		return tostring(value or "")
	end, function(text)
		return text
	end)
end

function Widgets.list(parent, item)
	return textRow(parent, item, 220, function(value)
		if type(value) == "table" then
			return table.concat(value, ", ")
		end
		return ""
	end, function(text)
		local parsed = {}
		for token in string.gmatch(text, "[^,]+") do
			local trimmed = token:match("^%s*(.-)%s*$")
			if trimmed ~= "" then
				table.insert(parsed, trimmed)
			end
		end
		return parsed
	end)
end

function Widgets.button(parent, item)
	local holder = new("Frame", {
		Name = "ButtonRow",
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { padding(6, 14, 6, 14) })

	local row = new("TextButton", {
		Name = "Button",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Theme.palette.card,
		BorderSizePixel = 0,
		Font = FONT_MONO,
		Text = item.label,
		TextSize = 12,
		TextColor3 = Theme.palette.text,
		AutoButtonColor = false,
		Parent = holder,
	}, { corner(8), stroke(Theme.palette.line, 1, 0.6) })

	row.MouseEnter:Connect(function()
		tween(row, { BackgroundColor3 = lerpColor(Theme.palette.card, Theme.accent, 0.28) }, 0.14)
	end)
	row.MouseLeave:Connect(function()
		tween(row, { BackgroundColor3 = Theme.palette.card }, 0.14)
	end)
	row.MouseButton1Click:Connect(function()
		pcall(item.action)
	end)

	onTheme(function(palette)
		row.BackgroundColor3 = palette.card
		row.TextColor3 = palette.text
		local outline = row:FindFirstChildOfClass("UIStroke")
		if outline then
			outline.Color = palette.line
		end
	end)

	holder:SetAttribute("SearchKey", string.lower(item.label .. " " .. (item.desc or "")))
	UIMeta.Outer[row] = holder
	return row
end

-- A page opens with a line saying what it is for, then a stack of collapsible
-- cards. Framing first, controls second.
function UIMeta.pageIntro(page, tab)
	local holder = new("Frame", {
		Name = "Intro",
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = page,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		padding(2, 0, 12, 2),
	})

	local title = new("TextLabel", {
		Name = "Title",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = FONT_BOLD,
		Text = tab.title,
		TextSize = 18,
		TextColor3 = Theme.palette.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})

	local blurb = new("TextLabel", {
		Name = "Blurb",
		LayoutOrder = 2,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = FONT_UI,
		Text = UIMeta.Blurb[tab.id] or "",
		TextSize = 12,
		TextColor3 = Theme.palette.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = holder,
	})

	onTheme(function(palette)
		title.TextColor3 = palette.text
		blurb.TextColor3 = palette.dim
	end)
	return holder
end

-- A plain heading, for the hand built UI.pages that are not a stack of settings.
function UIMeta.sectionHeader(parent, title)
	local holder = new("Frame", {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Parent = parent,
	})

	local accentBar = new("Frame", {
		Name = "Accent",
		Position = UDim2.new(0, 0, 0, 10),
		Size = UDim2.fromOffset(3, 12),
		BackgroundColor3 = Theme.accent,
		BorderSizePixel = 0,
		Parent = holder,
	}, { corner(2) })

	local label = new("TextLabel", {
		Name = "Title",
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(1, -12, 1, 0),
		BackgroundTransparency = 1,
		Font = FONT_BOLD,
		Text = string.upper(title),
		TextSize = 11,
		TextColor3 = Theme.palette.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})

	onTheme(function(palette, accent)
		accentBar.BackgroundColor3 = accent
		label.TextColor3 = palette.dim
	end)
	return holder
end

-- A collapsible card. Open state is remembered per section for the session, so
-- opening the one group you care about does not get undone by every tab change.
function UIMeta.sectionCard(page, tab, section)
	local key = tab.id .. "/" .. section.title
	local container = new("Frame", {
		Name = "Card",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.palette.bg2,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = page,
	}, {
		corner(10),
		stroke(Theme.palette.line, 1, 0.6),
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),
	})

	local header = new("TextButton", {
		Name = "Header",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Parent = container,
	})

	local chevron = new("TextLabel", {
		Name = "Chevron",
		Position = UDim2.new(0, 14, 0, 0),
		Size = UDim2.fromOffset(12, 38),
		BackgroundTransparency = 1,
		Font = FONT_MONO,
		Text = ">",
		TextSize = 12,
		TextColor3 = Theme.accent,
		Parent = header,
	})

	local title = new("TextLabel", {
		Name = "Title",
		Position = UDim2.new(0, 32, 0, 0),
		Size = UDim2.new(1, -110, 1, 0),
		BackgroundTransparency = 1,
		Font = FONT_BOLD,
		Text = string.upper(section.title),
		TextSize = 11,
		TextColor3 = Theme.palette.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})

	local count = new("TextLabel", {
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 0),
		Size = UDim2.fromOffset(60, 38),
		BackgroundTransparency = 1,
		Font = FONT_MONO,
		Text = "",
		TextSize = 11,
		TextColor3 = Theme.palette.faint,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})

	local body = new("Frame", {
		Name = "Body",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = container,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),
	})

	local card = { Container = container, Body = body, Count = count, Rows = {}, Key = key }

	function card.SetOpen(open, animate)
		UIMeta.Open[key] = open
		body.Visible = open
		if animate then
			tween(chevron, { Rotation = if open then 90 else 0 }, 0.16)
		else
			chevron.Rotation = if open then 90 else 0
		end
	end

	header.MouseButton1Click:Connect(function()
		-- Once it has been opened or closed by hand, the adaptive default stops
		-- second guessing the person using it.
		UIMeta.Touched[key] = true
		card.SetOpen(not (UIMeta.Open[key] == true), true)
	end)
	header.MouseEnter:Connect(function()
		tween(title, { TextColor3 = Theme.palette.text }, 0.12)
	end)
	header.MouseLeave:Connect(function()
		tween(title, { TextColor3 = Theme.palette.dim }, 0.12)
	end)

	onTheme(function(palette, accent)
		container.BackgroundColor3 = palette.bg2
		chevron.TextColor3 = accent
		title.TextColor3 = palette.dim
		count.TextColor3 = palette.faint
		local outline = container:FindFirstChildOfClass("UIStroke")
		if outline then
			outline.Color = palette.line
		end
	end)

	if UIMeta.Open[key] == nil then
		UIMeta.Open[key] = section.open == true
	end
	card.SetOpen(UIMeta.Open[key], false)
	return card
end


-- ============================================================================
--  Page construction
-- ============================================================================

UI.searchable = {}

local function buildSettingsPage(tab)
	local page = makePage(tab.id)
	UIMeta.pageIntro(page, tab)

	local order = 0
	for _, section in ipairs(tab.sections or {}) do
		order += 1
		local card = UIMeta.sectionCard(page, tab, section)
		card.Container.LayoutOrder = order

		local rows = {}
		for index, item in ipairs(section.items) do
			local builder = Widgets[item.type]
			if builder then
				local built = builder(card.Body, item)
				local row = UIMeta.Outer[built] or built
				row.LayoutOrder = index
				row:SetAttribute("DetailLevel", UIMeta.levelOf(item))
				table.insert(rows, row)
			end
		end

		card.Rows = rows
		table.insert(UIMeta.Cards, card)
		table.insert(UI.searchable, { card = card, rows = rows })
	end

	return page
end

-- ---------------------------------------------------------------------------
--  Overview page - fastfetch style readout
-- ---------------------------------------------------------------------------

UI.FETCH_LOGO = table.concat({
	"        /\\        ",
	"       /  \\       ",
	"      /\\   \\      ",
	"     /      \\     ",
	"    /   ,,   \\    ",
	"   /   |  |  -\\   ",
	"  /_-''    ''-_\\  ",
}, "\n")

UI.fetchRows = {}
UI.fetchValueLabels = {}
local placeName = "unknown"

task.spawn(function()
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId)
	end)
	if ok and type(info) == "table" and info.Name then
		placeName = info.Name
	end
end)

local function buildOverviewPage()
	local page = makePage("overview")

	-- Fixed heights here were the reason the fetch block spilled out of its card
	-- and over the buttons underneath. The card and the info column both size to
	-- their contents now, so adding a row can never overlap anything again.
	local card = new("Frame", {
		Name = "Fetch",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.palette.bg2,
		BorderSizePixel = 0,
		Parent = page,
	}, { corner(10), stroke(Theme.palette.line, 1, 0.65), padding(0, 0, 18, 0) })

	local logo = new("TextLabel", {
		Name = "Logo",
		Position = UDim2.new(0, 16, 0, 22),
		Size = UDim2.fromOffset(170, 130),
		BackgroundTransparency = 1,
		Font = FONT_MONO,
		Text = UI.FETCH_LOGO,
		TextSize = 13,
		TextColor3 = Theme.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})

	local info = new("Frame", {
		Name = "Info",
		Position = UDim2.new(0, 196, 0, 18),
		Size = UDim2.new(1, -212, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card,
	}, { listLayout(2) })

	local function fetchRow(key, order)
		local holder = new("Frame", {
			Name = key,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
			Parent = info,
		})
		local keyLabel = new("TextLabel", {
			Name = "Key",
			Size = UDim2.fromOffset(82, 14),
			BackgroundTransparency = 1,
			Font = FONT_MONO,
			Text = key,
			TextSize = 12,
			TextColor3 = Theme.accent,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = holder,
		})
		local valueLabel = new("TextLabel", {
			Name = "Value",
			Position = UDim2.new(0, 84, 0, 0),
			Size = UDim2.new(1, -84, 0, 14),
			BackgroundTransparency = 1,
			Font = FONT_MONO,
			Text = "",
			TextSize = 12,
			TextColor3 = Theme.palette.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = holder,
		})
		UI.fetchRows[key] = { key = keyLabel, value = valueLabel }
		UI.fetchValueLabels[key] = valueLabel
		return holder
	end

	local title = new("TextLabel", {
		Name = "Title",
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Font = FONT_MONO,
		Text = "",
		TextSize = 13,
		TextColor3 = Theme.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = info,
	})

	local rule = new("TextLabel", {
		Name = "Rule",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundTransparency = 1,
		Font = FONT_MONO,
		Text = string.rep("-", 46),
		TextSize = 12,
		TextColor3 = Theme.palette.faint,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = info,
	})

	local keys = {
		"script", "engine", "place", "placeid", "profile", "storage",
		"theme", "state", "route", "replans", "speed", "fps", "ping", "uptime",
	}
	for index, key in ipairs(keys) do
		fetchRow(key, index + 1)
	end

	local swatches = new("Frame", {
		Name = "Swatches",
		LayoutOrder = 100,
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Parent = info,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local swatchFrames = {}
	for index, name in ipairs(ACCENT_NAMES) do
		swatchFrames[name] = new("Frame", {
			Name = name,
			LayoutOrder = index,
			Size = UDim2.fromOffset(22, 14),
			BackgroundColor3 = Theme.palette[name],
			BorderSizePixel = 0,
			Parent = swatches,
		}, { corner(3) })
	end

	-- Quick actions under the fetch card.
	local actions = new("Frame", {
		Name = "Actions",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Parent = page,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local hintCard = new("TextLabel", {
		Name = "Hint",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.palette.bg2,
		BorderSizePixel = 0,
		Font = FONT_MONO,
		Text = "",
		TextSize = 12,
		TextColor3 = Theme.palette.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = page,
	}, { corner(10), stroke(Theme.palette.line, 1, 0.65), padding(12, 12, 12, 14) })

	onTheme(function(palette, accent)
		card.BackgroundColor3 = palette.bg2
		logo.TextColor3 = accent
		title.TextColor3 = accent
		rule.TextColor3 = palette.faint
		hintCard.BackgroundColor3 = palette.bg2
		hintCard.TextColor3 = palette.dim
		for key, pair in pairs(UI.fetchRows) do
			pair.key.TextColor3 = accent
			pair.value.TextColor3 = palette.text
		end
		for name, frame in pairs(swatchFrames) do
			frame.BackgroundColor3 = palette[name]
		end
		for _, outline in ipairs({ card:FindFirstChildOfClass("UIStroke"), hintCard:FindFirstChildOfClass("UIStroke") }) do
			if outline then
				outline.Color = palette.line
			end
		end
	end)

	return page, title, actions, hintCard
end

-- ---------------------------------------------------------------------------
--  Profiles page
-- ---------------------------------------------------------------------------

local refreshProfileList

local function buildProfilesPage()
	local page = makePage("profiles")

	local summary = new("TextLabel", {
		Name = "Summary",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.palette.bg2,
		BorderSizePixel = 0,
		Font = FONT_MONO,
		Text = "",
		TextSize = 12,
		TextColor3 = Theme.palette.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = page,
	}, { corner(10), stroke(Theme.palette.line, 1, 0.65), padding(12, 12, 12, 14) })

	local head1 = UIMeta.sectionHeader(page, "This place")
	head1.LayoutOrder = 2

	local placeActions = new("Frame", {
		Name = "PlaceActions",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Parent = page,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local function actionButton(parent, order, text, action)
		local button = Widgets.button(parent, { label = text, action = action })
		button.LayoutOrder = order
		button.Size = UDim2.new(0.25, -6, 1, 0)
		return button
	end

	actionButton(placeActions, 1, "save place", function()
		saveProfile(PLACE_PROFILE)
		toast(if Storage.Mode == "filesystem" then "saved " .. PLACE_PROFILE .. ".json" else "saved to session memory", if Storage.Mode == "filesystem" then "good" else "warn")
		if refreshProfileList then
			refreshProfileList()
		end
	end)
	actionButton(placeActions, 2, "load place", function()
		local ok = loadProfile(PLACE_PROFILE)
		toast(if ok then "loaded " .. PLACE_PROFILE else "no profile saved for this place", if ok then "good" else "error")
	end)
	actionButton(placeActions, 3, "save global", function()
		saveProfile("global")
		toast("saved global profile", "good")
		if refreshProfileList then
			refreshProfileList()
		end
	end)
	actionButton(placeActions, 4, "load global", function()
		local ok = loadProfile("global")
		toast(if ok then "loaded global" else "no global profile", if ok then "good" else "error")
	end)

	local head2 = UIMeta.sectionHeader(page, "Transfer")
	head2.LayoutOrder = 4

	local transferActions = new("Frame", {
		Name = "TransferActions",
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Parent = page,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local importBox

	actionButton(transferActions, 1, "copy config", function()
		local text = Config.Serialize()
		if type(setclipboard) == "function" then
			local ok = pcall(setclipboard, text)
			toast(if ok then "config copied to clipboard" else "clipboard unavailable", if ok then "good" else "error")
		else
			if importBox then
				importBox.Text = text
			end
			toast("no clipboard here, config placed in the box below", "warn")
		end
	end)
	actionButton(transferActions, 2, "paste config", function()
		if not importBox or importBox.Text == "" then
			toast("paste JSON into the box first", "warn")
			return
		end
		local ok, err = Config.Deserialize(importBox.Text)
		toast(if ok then "config applied" else "invalid config: " .. tostring(err), if ok then "good" else "error")
	end)
	actionButton(transferActions, 3, "defaults", function()
		Config.ResetAll()
		toast("every setting restored to default", "good")
	end)
	actionButton(transferActions, 4, "reload theme", function()
		refreshTheme()
		toast("theme reapplied")
	end)

	importBox = new("TextBox", {
		Name = "Import",
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 92),
		BackgroundColor3 = Theme.palette.bg2,
		BorderSizePixel = 0,
		Font = FONT_MONO,
		PlaceholderText = "paste an exported config here, then press paste config",
		PlaceholderColor3 = Theme.palette.faint,
		Text = "",
		TextSize = 11,
		TextColor3 = Theme.palette.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ClearTextOnFocus = false,
		MultiLine = true,
		Parent = page,
	}, { corner(10), stroke(Theme.palette.line, 1, 0.65), padding(10, 10, 10, 10) })

	local head3 = UIMeta.sectionHeader(page, "Stored profiles")
	head3.LayoutOrder = 7

	local listHolder = new("Frame", {
		Name = "Stored",
		LayoutOrder = 8,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = page,
	}, { listLayout(6) })

	function refreshProfileList()
		for _, child in ipairs(listHolder:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		local names = Storage.List()
		if #names == 0 then
			new("TextLabel", {
				Name = "Empty",
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				Font = FONT_MONO,
				Text = "  no saved profiles yet",
				TextSize = 12,
				TextColor3 = Theme.palette.faint,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = listHolder,
			})
			return
		end

		for index, name in ipairs(names) do
			local entry = new("Frame", {
				Name = "Profile_" .. name,
				LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundColor3 = Theme.palette.bg2,
				BorderSizePixel = 0,
				Parent = listHolder,
			}, { corner(7), stroke(Theme.palette.line, 1, 0.7) })

			new("TextLabel", {
				Name = "Name",
				Position = UDim2.new(0, 12, 0, 0),
				Size = UDim2.new(1, -180, 1, 0),
				BackgroundTransparency = 1,
				Font = FONT_MONO,
				Text = name .. (if name == PLACE_PROFILE then "   (this place)" else ""),
				TextSize = 12,
				TextColor3 = Theme.palette.text,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = entry,
			})

			local loadButton = new("TextButton", {
				Name = "Load",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -78, 0.5, 0),
				Size = UDim2.fromOffset(62, 20),
				BackgroundColor3 = Theme.palette.card,
				BorderSizePixel = 0,
				Font = FONT_MONO,
				Text = "load",
				TextSize = 11,
				TextColor3 = Theme.palette.text,
				AutoButtonColor = false,
				Parent = entry,
			}, { corner(5) })

			local deleteButton = new("TextButton", {
				Name = "Delete",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(62, 20),
				BackgroundColor3 = Theme.palette.card,
				BorderSizePixel = 0,
				Font = FONT_MONO,
				Text = "delete",
				TextSize = 11,
				TextColor3 = Theme.palette.red,
				AutoButtonColor = false,
				Parent = entry,
			}, { corner(5) })

			loadButton.MouseButton1Click:Connect(function()
				local ok = loadProfile(name)
				toast(if ok then "loaded " .. name else "failed to load " .. name, if ok then "good" else "error")
			end)
			deleteButton.MouseButton1Click:Connect(function()
				Storage.Delete(name)
				toast("deleted " .. name, "warn")
				refreshProfileList()
			end)
		end
	end

	addRefresher(function()
		summary.Text = string.format(
			"place      %s\nplace id   %s\nstorage    %s\nprofile    %s",
			placeName,
			PLACE_PROFILE,
			Storage.Mode .. (if Storage.Mode == "session" then "  (no executor filesystem: settings last for this session)" else ""),
			if Storage.Exists(PLACE_PROFILE) then PLACE_PROFILE .. ".json" else "none saved"
		)
	end)

	onTheme(function(palette)
		summary.BackgroundColor3 = palette.bg2
		summary.TextColor3 = palette.dim
		importBox.BackgroundColor3 = palette.bg2
		importBox.TextColor3 = palette.text
		importBox.PlaceholderColor3 = palette.faint
		refreshProfileList()
	end)

	return page
end

-- ---------------------------------------------------------------------------
--  Tab buttons
-- ---------------------------------------------------------------------------

UI.activeTab = nil
UI.tabButtons = {}

local function selectTab(id: string)
	if UI.activeTab == id then
		return
	end
	UI.activeTab = id

	for tabId, entry in pairs(UI.tabButtons) do
		local selected = tabId == id
		tween(entry.button, { BackgroundTransparency = if selected then 0 else 1 }, 0.15)
		tween(entry.label, { TextColor3 = if selected then Theme.palette.text else Theme.palette.faint }, 0.15)
		tween(entry.marker, { Size = UDim2.new(0, 3, 0, if selected then 16 else 0) }, 0.18)
	end

	for pageId, page in pairs(UI.pages) do
		if pageId == id then
			page.Visible = true
			page.Position = UDim2.new(0, 14, 0, 64)
			tween(page, { Position = UDim2.new(0, 14, 0, 52) }, 0.22)
		else
			page.Visible = false
		end
	end
end

local function sidebarCaption(text, order)
	local label = new("TextLabel", {
		Name = "Caption_" .. text,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Font = FONT_MONO,
		Text = text,
		TextSize = 10,
		TextColor3 = Theme.palette.faint,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Parent = UI.tabList,
	}, { padding(0, 0, 4, 12) })

	onTheme(function(palette)
		label.TextColor3 = palette.faint
	end)
	return label
end

local function makeTabButton(tab, order)
	local button = new("TextButton", {
		Name = "Tab_" .. tab.id,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Theme.palette.card,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Parent = UI.tabList,
	}, { corner(7) })

	local marker = new("Frame", {
		Name = "Marker",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 3, 0, 0),
		BackgroundColor3 = Theme.accent,
		BorderSizePixel = 0,
		Parent = button,
	}, { corner(2) })

	local label = new("TextLabel", {
		Name = "Label",
		Position = UDim2.new(0, 14, 0, 0),
		Size = UDim2.new(1, -20, 1, 0),
		BackgroundTransparency = 1,
		Font = FONT_MONO,
		Text = tab.title,
		TextSize = 13,
		TextColor3 = Theme.palette.faint,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = button,
	})

	button.MouseEnter:Connect(function()
		if UI.activeTab ~= tab.id then
			tween(button, { BackgroundTransparency = 0.7 }, 0.12)
		end
	end)
	button.MouseLeave:Connect(function()
		if UI.activeTab ~= tab.id then
			tween(button, { BackgroundTransparency = 1 }, 0.12)
		end
	end)
	button.MouseButton1Click:Connect(function()
		selectTab(tab.id)
	end)

	onTheme(function(palette, accent)
		button.BackgroundColor3 = palette.card
		marker.BackgroundColor3 = accent
		label.TextColor3 = if UI.activeTab == tab.id then palette.text else palette.faint
	end)

	UI.tabButtons[tab.id] = { button = button, label = label, marker = marker }
	return button
end

-- ============================================================================
--  Build everything
-- ============================================================================


do
	local byId = {}
	for _, tab in ipairs(SCHEMA) do
		byId[tab.id] = tab
	end

	-- One step per page plus the four stages around them.
	UIMeta.Boot.Begin(#SCHEMA + 4)
	UIMeta.Boot.Step("storage: " .. Storage.Mode)
	UIMeta.Boot.Step("reading configuration")

	local order = 0
	local function buildTab(tab)
		order += 1
		makeTabButton(tab, order)
		UIMeta.Boot.Step("building " .. tab.title)
		if tab.custom == "fastfetch" then
			local _, title, actions, hint = buildOverviewPage()
			UI.overviewTitle = title
			UI.overviewActions = actions
			UI.overviewHint = hint
		elseif tab.custom == "profiles" then
			buildProfilesPage()
		else
			buildSettingsPage(tab)
		end
	end

	local placed = {}
	for _, group in ipairs(UIMeta.Groups) do
		order += 1
		sidebarCaption(group.caption, order)
		for _, id in ipairs(group.tabs) do
			local tab = byId[id]
			if tab then
				placed[id] = true
				buildTab(tab)
			end
		end
	end

	-- Anything the grouping forgot still gets a page rather than vanishing.
	local leftovers = {}
	for _, tab in ipairs(SCHEMA) do
		if not placed[tab.id] then
			table.insert(leftovers, tab)
		end
	end
	if #leftovers > 0 then
		order += 1
		sidebarCaption("other", order)
		for _, tab in ipairs(leftovers) do
			buildTab(tab)
		end
	end
end

-- ---------------------------------------------------------------------------
--  Search filtering
-- ---------------------------------------------------------------------------

-- Search and detail level are the same operation: decide which rows survive,
-- then hide any card left with nothing in it. Running them separately meant a
-- card could sit there empty with a header and no contents.
function UIMeta.applyFilter()
	local query = string.lower(UI.searchBox.Text)
	local searching = query ~= ""
	local ceiling = UIMeta.ceiling()
	local showDescriptions = Config.Get("Nav.ShowDescriptions") == true

	for description in pairs(UIMeta.Descriptions) do
		description.Visible = showDescriptions
	end

	for _, group in ipairs(UI.searchable) do
		local shown = 0
		local total = #group.rows
		for _, row in ipairs(group.rows) do
			local level = row:GetAttribute("DetailLevel") or 2
			local matches = true
			if searching then
				matches = string.find(row:GetAttribute("SearchKey") or "", query, 1, true) ~= nil
			else
				matches = level <= ceiling
			end
			row.Visible = matches
			if matches then
				shown += 1
			end
		end

		local card = group.card
		if card then
			card.Container.Visible = shown > 0
			card.Count.Text = if shown == total then string.format("%d", total) else string.format("%d/%d", shown, total)
			if searching and shown > 0 then
				-- A search should show what it found, not make you open cards to see it.
				card.SetOpen(true, false)
			elseif not UIMeta.Touched[card.Key] then
				card.SetOpen(shown > 0 and shown <= (UIMeta.AutoOpenRows or 8), false)
			end
		end
	end
end

UI.searchBox:GetPropertyChangedSignal("Text"):Connect(UIMeta.applyFilter)

-- ============================================================================
--  Runtime wiring
-- ============================================================================

UI.connections = {}
local function track(connection)
	table.insert(UI.connections, connection)
	return connection
end

local Lighting = game:GetService("Lighting")
UI.blur = Lighting:FindFirstChild("PortableNavigationBlur")
if UI.blur then
	UI.blur:Destroy()
end
UI.blur = new("BlurEffect", {
	Name = "PortableNavigationBlur",
	Size = 0,
	Enabled = false,
	Parent = Lighting,
})

local controller = nil
local completedConnection = nil
local failedConnection = nil
UI.windowOpen = false

local function notify(message: string, kind: string?)
	navLog("notify", message, if kind == "error" then Logger.Level.Warn else Logger.Level.Info)
	toast(message, kind)
end

-- ---------------------------------------------------------------------------
--  Player control handoff
-- ---------------------------------------------------------------------------

UI.playerControls = nil
UI.lastControlsAttempt = -math.huge
UI.controlsLocked = false
UI.controlsWarned = false

local function resolvePlayerControls()
	if UI.playerControls then
		return UI.playerControls
	end
	-- The original latched after one failure and never retried, so a controller
	-- that was not ready at inject time stayed unavailable for the whole session.
	if os.clock() - UI.lastControlsAttempt < 2 then
		return nil
	end
	UI.lastControlsAttempt = os.clock()

	local playerScripts = player:FindFirstChildOfClass("PlayerScripts")
	if not playerScripts then
		return nil
	end
	local playerModule = playerScripts:FindFirstChild("PlayerModule")
	if not playerModule then
		return nil
	end
	local moduleOk, moduleResult = pcall(require, playerModule)
	if not moduleOk then
		return nil
	end
	local controlsOk, controlsResult = pcall(function()
		return moduleResult:GetControls()
	end)
	if not controlsOk or not controlsResult then
		return nil
	end

	UI.playerControls = controlsResult
	navLog("controls", "resolved PlayerModule controls", Logger.Level.Info)
	return UI.playerControls
end

local function setControlsLocked(locked: boolean)
	if locked and Config.Get("Nav.LockControls") == false then
		locked = false
	end
	if UI.controlsLocked == locked then
		return
	end

	local controls = resolvePlayerControls()
	if not controls then
		if locked and not UI.controlsWarned then
			UI.controlsWarned = true
			navLog("controls", "PlayerModule controls unavailable, relying on the per-frame move re-assert", Logger.Level.Warn)
		end
		return
	end

	local ok = pcall(function()
		if locked then
			controls:Disable()
		else
			controls:Enable()
		end
	end)
	if ok then
		UI.controlsLocked = locked
	end
end

-- ---------------------------------------------------------------------------
--  Sprint bookkeeping
-- ---------------------------------------------------------------------------

UI.sprintActive = false
UI.sprintOriginalSpeed = nil

local function stopSprint()
	if not UI.sprintActive then
		return
	end
	UI.sprintActive = false
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and UI.sprintOriginalSpeed then
		pcall(function()
			humanoid.WalkSpeed = UI.sprintOriginalSpeed
		end)
	end
	UI.sprintOriginalSpeed = nil
end

local function startSprint()
	if UI.sprintActive or Config.Get("Nav.DoubleClickSprint") ~= true then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	UI.sprintOriginalSpeed = humanoid.WalkSpeed
	UI.sprintActive = true
	pcall(function()
		humanoid.WalkSpeed = tonumber(Config.Get("Nav.SprintSpeed")) or 32
	end)
end

-- ---------------------------------------------------------------------------
--  Controller lifecycle
-- ---------------------------------------------------------------------------

-- Defined further down with the movement drivers; the controller signal
-- handlers above need to call it, so the name is reserved here.
local releaseMove

local function disconnectControllerSignals()
	if completedConnection then
		completedConnection:Disconnect()
		completedConnection = nil
	end
	if failedConnection then
		failedConnection:Disconnect()
		failedConnection = nil
	end
end

local function clearDebugMarkers()
	if not controller or not controller.DebugRenderer then
		return
	end
	pcall(function()
		controller.DebugRenderer:BeginFrame()
		controller.DebugRenderer:EndFrame()
	end)
end

local function applyDebugState()
	if not controller then
		return
	end
	local renderer = controller.DebugRenderer
	if not renderer then
		return
	end
	local wantRoute = Config.Get("Debug.Enabled") == true or Config.Get("Nav.ShowPathWhileMoving") == true
	pcall(function()
		renderer:SetEnabled(wantRoute)
		local layers = Config.Get("Debug.Layers") or {}
		for name, on in pairs(layers) do
			-- ShowPathWhileMoving forces the route layer on even when the rest of
			-- the debug renderer is off, so the player always sees where they are going.
			if name == "Route" and Config.Get("Debug.Enabled") ~= true then
				renderer:SetLayer(name, Config.Get("Nav.ShowPathWhileMoving") == true)
			else
				renderer:SetLayer(name, Config.Get("Debug.Enabled") == true and on == true)
			end
		end
	end)
end

local function bindCharacter(character: Model)
	navLog("bind", string.format("binding %s", character:GetFullName()), Logger.Level.Info)
	stopSprint()
	UI.controlsLocked = false
	setControlsLocked(false)
	disconnectControllerSignals()

	if controller then
		controller:Destroy()
		controller = nil
	end

	controller = NavigationController.new(character, RuntimeConfig)
	KillBricks.WatchCharacter(character)

	completedConnection = controller:GetCompletedSignal():Connect(function()
		setControlsLocked(false)
		stopSprint()
		releaseMove()
		clearDebugMarkers()
		notify("arrived", "good")
	end)

	failedConnection = controller:GetFailedSignal():Connect(function(reason)
		setControlsLocked(false)
		stopSprint()
		releaseMove()
		clearDebugMarkers()
		if reason ~= "superseded" and reason ~= "stopped" and reason ~= "compute_in_flight" then
			notify("cannot get there: " .. tostring(reason), "error")
		end
	end)

	applyDebugState()
end

local function stopNavigation(silent: boolean?)
	if controller then
		controller:Stop()
	end
	setControlsLocked(false)
	stopSprint()
	releaseMove()
	clearDebugMarkers()
	if not silent then
		notify("route cancelled", "warn")
	end
end

-- ---------------------------------------------------------------------------
--  Movement methods
--
--  Humanoid:Move is the right default, but plenty of games run a custom
--  character controller, reset MoveDirection every frame, or ignore the
--  humanoid entirely. Each driver below pushes the same direction through a
--  different mechanism, and Auto escalates through them when the character is
--  being told to move and demonstrably is not.
-- ---------------------------------------------------------------------------

UI.AUTO_ORDER = { "Humanoid:Move", "LinearVelocity", "AssemblyVelocity", "Humanoid:MoveTo", "WalkToPoint", "WASD", "CFrame" }

UI.moveState = {
	autoIndex = 1,
	lastPointAt = 0,
	lastPoint = nil,
	lastDriveAt = nil,
	facing = nil,
	groundOffset = nil,
	track = nil,
	watchAnchor = nil,
	watchSince = 0,
	usedVelocity = false,
	constraint = nil,
	attachment = nil,
	autoRotateWas = nil,
}

-- Speed the direct drivers should produce. Game mode reads the humanoid every
-- frame so sprint pads and slows are followed; the other two are for going
-- faster than the game intends.
local function resolveSpeed(humanoid): number
	local mode = tostring(Config.Get("Nav.SpeedMode"))
	local base = humanoid and humanoid.WalkSpeed or 16
	if mode == "Multiply" then
		return base * (tonumber(Config.Get("Nav.SpeedMultiplier")) or 1)
	elseif mode == "Absolute" then
		return tonumber(Config.Get("Nav.SpeedAbsolute")) or base
	end
	return base
end

-- ---------------------------------------------------------------------------
--  WASD emulation
--
--  A plain LocalScript cannot synthesise keyboard input, so this needs a
--  backend: an executor's keypress/keyrelease globals, VirtualInputManager, or
--  VirtualUser. The direction is resolved against the camera because that is
--  what W actually means to the character.
-- ---------------------------------------------------------------------------

UI.WASD_KEYS = { W = 0x57, A = 0x41, S = 0x53, D = 0x44 }
UI.WASD_ORDER = { "W", "A", "S", "D" }

UI.wasdState = { held = {}, backend = nil, captured = false }

local function detectWasdBackend(): string?
	local preferred = tostring(Config.Get("Nav.WasdBackend"))
	local function usable(name: string): boolean
		if name == "keypress" then
			return type(keypress) == "function" and type(keyrelease) == "function"
		elseif name == "VirtualInputManager" then
			local ok, service = pcall(function()
				return game:GetService("VirtualInputManager")
			end)
			return ok and service ~= nil
		elseif name == "VirtualUser" then
			local ok, service = pcall(function()
				return game:GetService("VirtualUser")
			end)
			return ok and service ~= nil
		end
		return false
	end

	if preferred ~= "Auto" then
		return if usable(preferred) then preferred else nil
	end
	for _, name in ipairs({ "keypress", "VirtualInputManager", "VirtualUser" }) do
		if usable(name) then
			return name
		end
	end
	return nil
end

local function setWasdKey(key: string, down: boolean)
	local backend = UI.wasdState.backend
	if not backend then
		return
	end

	pcall(function()
		if backend == "keypress" then
			if down then
				keypress(UI.WASD_KEYS[key])
			else
				keyrelease(UI.WASD_KEYS[key])
			end
		elseif backend == "VirtualInputManager" then
			local service = game:GetService("VirtualInputManager")
			service:SendKeyEvent(down, (Enum.KeyCode :: any)[key], false, game)
		elseif backend == "VirtualUser" then
			local service = game:GetService("VirtualUser")
			if not UI.wasdState.captured then
				service:CaptureController()
				UI.wasdState.captured = true
			end
			if down then
				service:SetKeyDown(string.lower(key))
			else
				service:SetKeyUp(string.lower(key))
			end
		end
	end)
end

local function releaseWasd()
	for _, key in ipairs(UI.WASD_ORDER) do
		if UI.wasdState.held[key] then
			setWasdKey(key, false)
			UI.wasdState.held[key] = false
		end
	end
	UI.wasdState.captured = false
end

local function driveWasd(direction: Vector3): boolean
	if not UI.wasdState.backend then
		UI.wasdState.backend = detectWasdBackend()
		if not UI.wasdState.backend then
			return false
		end
		navLog("wasd", "using backend " .. UI.wasdState.backend, Logger.Level.Info)
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return false
	end

	local wanted = { W = false, A = false, S = false, D = false }
	if direction.Magnitude > 1e-3 then
		local look = NavUtil.SafeUnit(NavUtil.Flatten(camera.CFrame.LookVector))
		local right = NavUtil.SafeUnit(NavUtil.Flatten(camera.CFrame.RightVector))
		if look ~= Vector3.zero and right ~= Vector3.zero then
			local threshold = tonumber(Config.Get("Nav.WasdThreshold")) or 0.35
			local forwardLean = direction:Dot(look)
			local rightLean = direction:Dot(right)
			wanted.W = forwardLean > threshold
			wanted.S = forwardLean < -threshold
			wanted.D = rightLean > threshold
			wanted.A = rightLean < -threshold
		end
	end

	-- Only the edges are sent: holding a key is a press followed by silence, and
	-- re-pressing every frame reads as key repeat to the game.
	for _, key in ipairs(UI.WASD_ORDER) do
		if wanted[key] ~= (UI.wasdState.held[key] == true) then
			setWasdKey(key, wanted[key])
			UI.wasdState.held[key] = wanted[key]
		end
	end

	return true
end

local function activeMoveMethod(): string
	local configured = tostring(Config.Get("Nav.MoveMethod"))
	if configured ~= "Auto" then
		return configured
	end
	return UI.AUTO_ORDER[UI.moveState.autoIndex] or UI.AUTO_ORDER[1]
end

-- Methods that supply the displacement themselves rather than letting the
-- humanoid walk. These need a per-frame pre-physics tick and their own facing.
local function methodDrivesDirectly(method: string): boolean
	return method == "LinearVelocity" or method == "AssemblyVelocity" or method == "CFrame" or method == "WASD"
end

UI.groundParams = RaycastParams.new()

local function groundBelow(character: Model?, from: Vector3): RaycastResult?
	if not character then
		return nil
	end
	UI.groundParams.FilterType = Enum.RaycastFilterType.Exclude
	UI.groundParams.FilterDescendantsInstances = { character }
	UI.groundParams.IgnoreWater = true
	return Workspace:Raycast(from, Vector3.new(0, -60, 0), UI.groundParams)
end

-- Turning is done in world angles rather than by rotating a vector, so the
-- character always takes the short way round.
local function updateFacing(root: BasePart, direction: Vector3, dt: number): Vector3?
	local target = NavUtil.SafeUnit(NavUtil.Flatten(direction))
	if target == Vector3.zero then
		return UI.moveState.facing
	end

	local current = UI.moveState.facing
	if not current or current == Vector3.zero then
		current = NavUtil.SafeUnit(NavUtil.Flatten(root.CFrame.LookVector))
	end
	if current == Vector3.zero then
		current = target
	end

	local maxTurn = math.rad((tonumber(Config.Get("Nav.TurnSpeed")) or 720) * math.max(dt, 1 / 240))
	local currentAngle = math.atan2(current.X, current.Z)
	local targetAngle = math.atan2(target.X, target.Z)
	local difference = (targetAngle - currentAngle + math.pi) % (2 * math.pi) - math.pi
	difference = math.clamp(difference, -maxTurn, maxTurn)
	local blended = currentAngle + difference

	UI.moveState.facing = Vector3.new(math.sin(blended), 0, math.cos(blended))
	return UI.moveState.facing
end

-- A plane constrained LinearVelocity holds walk speed through ground friction
-- and up slopes, which a raw AssemblyLinearVelocity write does not: that one is
-- damped away again during the same physics step.
local function ensureVelocityConstraint(root: BasePart)
	if UI.moveState.constraint and UI.moveState.constraint.Parent then
		UI.moveState.constraint.MaxForce = tonumber(Config.Get("Nav.VelocityMaxForce")) or 120000
		return UI.moveState.constraint
	end

	local created = nil
	local ok = pcall(function()
		local attachment = Instance.new("Attachment")
		attachment.Name = "PortableNavigationAttachment"
		attachment.Parent = root

		local constraint = Instance.new("LinearVelocity")
		constraint.Name = "PortableNavigationVelocity"
		constraint.Attachment0 = attachment
		constraint.RelativeTo = Enum.ActuatorRelativeTo.World
		constraint.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		constraint.PrimaryTangentAxis = Vector3.new(1, 0, 0)
		constraint.SecondaryTangentAxis = Vector3.new(0, 0, 1)
		constraint.PlaneVelocity = Vector2.new(0, 0)
		constraint.MaxForce = tonumber(Config.Get("Nav.VelocityMaxForce")) or 120000
		constraint.Parent = root

		UI.moveState.attachment = attachment
		UI.moveState.constraint = constraint
		created = constraint
	end)

	if not ok then
		return nil
	end
	return created
end

function releaseMove()
	UI.moveState.watchAnchor = nil
	UI.moveState.watchSince = 0
	UI.moveState.lastPoint = nil
	UI.moveState.lastDriveAt = nil
	UI.moveState.facing = nil
	UI.moveState.groundOffset = nil
	UI.moveState.track = nil

	if UI.moveState.constraint then
		pcall(function()
			UI.moveState.constraint:Destroy()
		end)
		UI.moveState.constraint = nil
	end
	if UI.moveState.attachment then
		pcall(function()
			UI.moveState.attachment:Destroy()
		end)
		UI.moveState.attachment = nil
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and UI.moveState.autoRotateWas ~= nil then
		pcall(function()
			humanoid.AutoRotate = UI.moveState.autoRotateWas
		end)
	end
	UI.moveState.autoRotateWas = nil

	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and UI.moveState.usedVelocity then
		pcall(function()
			local velocity = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
		end)
	end
	UI.moveState.usedVelocity = false

	releaseWasd()
	UI.wasdState.backend = nil

	if humanoid and UI.moveState.walkSpeedWas then
		pcall(function()
			humanoid.WalkSpeed = UI.moveState.walkSpeedWas
		end)
	end
	UI.moveState.walkSpeedWas = nil
end

local function applyMove(movement, humanoid, direction: Vector3, isReassert: boolean)
	local method = activeMoveMethod()
	local root = movement.RootPart

	-- Optional write-through so the humanoid backed methods and WASD also run at
	-- the chosen speed. Off by default: changing WalkSpeed is far more visible to
	-- a game than the direct drivers are.
	if Config.Get("Nav.ApplyWalkSpeed") == true then
		local target = resolveSpeed(humanoid)
		if UI.moveState.walkSpeedWas == nil then
			UI.moveState.walkSpeedWas = humanoid.WalkSpeed
		end
		if math.abs(humanoid.WalkSpeed - target) > 1e-3 then
			pcall(function()
				humanoid.WalkSpeed = target
			end)
		end
	end

	-- Move is always issued: it is what drives the walk animation and, on the
	-- humanoid backed methods, the facing too.
	humanoid:Move(direction, false)

	if method == "Humanoid:Move" or not root then
		return
	end

	local speed = resolveSpeed(humanoid)
	local moving = direction.Magnitude > 1e-3

	if method == "WASD" then
		if not isReassert then
			return
		end
		if not driveWasd(direction) then
			navLog("wasd", "no input backend available on this executor", Logger.Level.Warn)
		end
		return
	end

	if method == "Humanoid:MoveTo" or method == "WalkToPoint" then
		if isReassert or not moving then
			return
		end
		-- Retargeting every frame restarts the internal walk, so these are
		-- throttled and only re-aimed when the direction actually shifts.
		local lookAhead = tonumber(Config.Get("Nav.MoveToLookAhead")) or 6
		local target = root.Position + direction * lookAhead
		local now = os.clock()
		local shifted = UI.moveState.lastPoint == nil or (target - UI.moveState.lastPoint).Magnitude > lookAhead * 0.35
		if not shifted and now - UI.moveState.lastPointAt < 0.25 then
			return
		end
		UI.moveState.lastPointAt = now
		UI.moveState.lastPoint = target
		pcall(function()
			if method == "Humanoid:MoveTo" then
				humanoid:MoveTo(target)
			else
				humanoid.WalkToPart = nil
				humanoid.WalkToPoint = target
			end
		end)
		return
	end

	-- The direct drivers only run on the pre-physics tick, where a real frame
	-- delta exists and the write is the last one before the solver.
	if not isReassert then
		return
	end

	local now = os.clock()
	local dt = math.clamp(now - (UI.moveState.lastDriveAt or now), 0, 0.1)
	UI.moveState.lastDriveAt = now
	if dt <= 0 then
		dt = 1 / 60
	end

	-- Writing velocity or CFrame bypasses the humanoid's own AutoRotate, so it
	-- is taken over here instead of left fighting for the same rotation.
	local wantFacing = Config.Get("Nav.FaceMoveDirection") ~= false
	if wantFacing then
		if UI.moveState.autoRotateWas == nil then
			UI.moveState.autoRotateWas = humanoid.AutoRotate
		end
		pcall(function()
			humanoid.AutoRotate = false
		end)
	end
	local facing = if wantFacing and moving then updateFacing(root, direction, dt) else nil

	if method == "LinearVelocity" then
		local constraint = ensureVelocityConstraint(root)
		if not constraint then
			-- Constraint creation refused: fall through to the raw write so the
			-- method still does something rather than silently doing nothing.
			method = "AssemblyVelocity"
		else
			UI.moveState.usedVelocity = true
			constraint.PlaneVelocity = Vector2.new(direction.X * speed, direction.Z * speed)
			if facing then
				pcall(function()
					root.CFrame = CFrame.lookAt(root.Position, root.Position + facing)
				end)
			end
			return
		end
	end

	if method == "AssemblyVelocity" then
		UI.moveState.usedVelocity = true
		pcall(function()
			local velocity = root.AssemblyLinearVelocity
			if moving then
				root.AssemblyLinearVelocity = Vector3.new(direction.X * speed, velocity.Y, direction.Z * speed)
			else
				root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
			end
		end)
		if facing then
			pcall(function()
				root.CFrame = CFrame.lookAt(root.Position, root.Position + facing)
			end)
		end
		return
	end

	if method == "CFrame" then
		if not moving then
			UI.moveState.track = nil
			return
		end

		-- An internal track advances at exactly WalkSpeed and the root is written
		-- onto it every frame, so whatever physics contributed in between is
		-- absorbed rather than added. That is what makes this match the game's
		-- speed instead of doubling it.
		local position = root.Position
		local maxDrift = tonumber(Config.Get("Nav.CFrameMaxDrift")) or 3
		if not UI.moveState.track or NavUtil.Flatten(UI.moveState.track - position).Magnitude > maxDrift then
			UI.moveState.track = position
		end

		local step = Vector3.new(direction.X, 0, direction.Z) * speed * dt
		local target = Vector3.new(UI.moveState.track.X + step.X, position.Y, UI.moveState.track.Z + step.Z)

		if Config.Get("Nav.CFrameGroundSnap") ~= false then
			local character = movement.Character
			if not UI.moveState.groundOffset then
				local under = groundBelow(character, position + Vector3.new(0, 2, 0))
				if under then
					UI.moveState.groundOffset = position.Y - under.Position.Y
				end
			end
			if UI.moveState.groundOffset then
				local ahead = groundBelow(character, Vector3.new(target.X, position.Y + 3, target.Z))
				if ahead then
					local desiredY = ahead.Position.Y + UI.moveState.groundOffset
					-- Only follow steps the character could actually walk; a big
					-- gap is left to gravity so falling still looks like falling.
					if math.abs(desiredY - position.Y) <= math.max(3, speed * dt * 6) then
						target = Vector3.new(target.X, desiredY, target.Z)
					end
				end
			end
		end

		UI.moveState.track = target
		local look = facing or NavUtil.SafeUnit(Vector3.new(direction.X, 0, direction.Z))
		pcall(function()
			if look and look ~= Vector3.zero then
				root.CFrame = CFrame.lookAt(target, target + look)
			else
				root.CFrame = root.CFrame - root.Position + target
			end
		end)
	end
end

MovementController.MoveApplier = applyMove

-- Auto escalation watchdog.
local function updateAutoMethod()
	if tostring(Config.Get("Nav.MoveMethod")) ~= "Auto" then
		return
	end
	if not controller or controller.State ~= "Moving" then
		UI.moveState.watchAnchor = nil
		return
	end

	local movement = controller.MovementController
	local root = controller.RootPart
	if not root or not movement or not movement._commandedMove then
		UI.moveState.watchAnchor = nil
		return
	end
	if movement._commandedMove.Magnitude <= 1e-3 then
		UI.moveState.watchAnchor = nil
		return
	end

	local now = os.clock()
	if not UI.moveState.watchAnchor then
		UI.moveState.watchAnchor = root.Position
		UI.moveState.watchSince = now
		return
	end

	local window = tonumber(Config.Get("Nav.AutoSwitchTime")) or 1.5
	if now - UI.moveState.watchSince < window then
		return
	end

	local travelled = (root.Position - UI.moveState.watchAnchor).Magnitude
	local threshold = tonumber(Config.Get("Nav.AutoSwitchDistance")) or 1.5
	UI.moveState.watchAnchor = root.Position
	UI.moveState.watchSince = now

	if travelled >= threshold then
		Config.Set("Nav.MoveMethodResolved", UI.AUTO_ORDER[UI.moveState.autoIndex])
		return
	end

	releaseMove()
	for _ = 1, #UI.AUTO_ORDER do
		UI.moveState.autoIndex += 1
		if UI.moveState.autoIndex > #UI.AUTO_ORDER then
			UI.moveState.autoIndex = 1
			navLog("move_method", "every movement method failed to produce motion", Logger.Level.Warn)
			return
		end
		-- WASD needs an input backend that only some environments provide.
		if UI.AUTO_ORDER[UI.moveState.autoIndex] ~= "WASD" or detectWasdBackend() ~= nil then
			break
		end
	end

	local nextMethod = UI.AUTO_ORDER[UI.moveState.autoIndex]
	Config.Set("Nav.MoveMethodResolved", nextMethod)
	navLog("move_method", string.format("no motion in %.1fs, switching to %s", window, nextMethod), Logger.Level.Warn)
	notify("no movement, trying " .. nextMethod, "warn")
end

-- ---------------------------------------------------------------------------
--  THE FIX: re-assert the movement vector immediately before physics.
--
--  Frame order in Roblox is RenderStepped -> Stepped -> physics -> Heartbeat.
--  The navigation step runs on Heartbeat, which is after physics, so its
--  Humanoid:Move call only lands on the following frame - and the default
--  PlayerModule control script writes its own zero vector on RenderStepped
--  before that ever happens. The result was a perfectly computed, perfectly
--  drawn route that the character never walked. Writing the last commanded
--  direction again on Stepped makes navigation the final writer before physics.
-- ---------------------------------------------------------------------------

track(RunService.Stepped:Connect(function()
	if not controller or Config.Get("Nav.Enabled") ~= true then
		return
	end
	if controller.State ~= "Moving" then
		return
	end
	-- The direct drivers need this tick regardless of the re-assert setting:
	-- it is the only place they get a real frame delta before the solver runs.
	if Config.Get("Nav.ReassertMove") == false and not methodDrivesDirectly(activeMoveMethod()) then
		return
	end
	local movement = controller.MovementController
	if movement and movement.ReassertMove then
		movement:ReassertMove()
	end
	updateAutoMethod()
end))

-- ---------------------------------------------------------------------------
--  Click to move
-- ---------------------------------------------------------------------------

local function pointerOverInterface(): boolean
	local location = UserInputService:GetMouseLocation()
	local ok, objects = pcall(function()
		return playerGui:GetGuiObjectsAtPosition(location.X, location.Y)
	end)
	if not ok or type(objects) ~= "table" then
		return false
	end
	for _, object in ipairs(objects) do
		if object:IsDescendantOf(gui) then
			return true
		end
	end
	return false
end

-- Where a click should actually send the character.
--
-- The ray maths was never the problem: ViewportPointToRay on GetMouseLocation
-- agrees with Roblox's own Mouse.Hit to the stud. What was wrong is what the ray
-- lands on. A click ray stops at the first thing it touches, and on a real map a
-- lot of that is not floor. Sampling one obby on a grid, 24 of 96 rays ended on
-- non collidable parts, 21 of those inside a single invisible kill volume
-- stretched across the level. From the outside that reads as the cursor being
-- broken.
--
-- So the ray keeps going until it finds something worth walking to, and a hit on
-- a wall resolves to the floor under it.
local function getClickPosition(character: Model?): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local location = UserInputService:GetMouseLocation()
	local unitRay = camera:ViewportPointToRay(location.X, location.Y)

	local exclude = {}
	if character then
		table.insert(exclude, character)
	end
	if controller and controller.DebugRenderer then
		local folder = controller.DebugRenderer:GetDebugFolder()
		if folder then
			table.insert(exclude, folder)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = false

	local detector = controller and controller.ObstacleDetector
	local skipGhosts = Config.Get("Nav.ClickIgnoreNonCollidable") ~= false
	local snapToGround = Config.Get("Nav.ClickSnapToGround") ~= false
	local pierce = math.max(1, math.floor(tonumber(Config.Get("Nav.ClickPierce")) or 10))
	local maxSlope = if detector then detector:MaxSlope() else 55

	local origin = unitRay.Origin
	local remaining = 2048
	local fallback = nil

	for _ = 1, pierce do
		local result = Workspace:Raycast(origin, unitRay.Direction * remaining, params)
		if not result then
			break
		end

		local part = result.Instance
		local standable = true

		if skipGhosts and part and part:IsA("BasePart") and not part.CanCollide then
			standable = false
		end
		if standable and detector and detector:IsHazard(part) then
			standable = false
		end

		if standable then
			local slope = math.deg(math.acos(math.clamp(result.Normal:Dot(Vector3.yAxis), -1, 1)))
			if slope <= maxSlope then
				return result.Position
			end
			-- A wall. Worth remembering in case nothing better turns up, but the
			-- floor at its foot is what was actually meant.
			fallback = fallback or result.Position
			if snapToGround and detector then
				local floor = detector:FindGroundBelow(
					result.Position + Vector3.new(0, 1, 0),
					2,
					64
				)
				if floor then
					return floor
				end
			end
		end

		-- Step past this surface and keep looking.
		table.insert(exclude, part)
		params.FilterDescendantsInstances = exclude
		local travelled = (result.Position - origin).Magnitude
		remaining -= travelled
		if remaining <= 1 then
			break
		end
		origin = result.Position + unitRay.Direction * 0.05
	end

	return fallback
end

UI.lastClickTime = -math.huge
UI.holdingActivation = false

local function requestMove(doubleClick: boolean)
	local character = player.Character
	if not controller or not character then
		return
	end

	local clickPosition = getClickPosition(character)
	if not clickPosition then
		notify("nothing under the cursor", "error")
		return
	end

	local maxDistance = tonumber(Config.Get("Nav.MaxClickDistance")) or 0
	if maxDistance > 0 then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and (clickPosition - root.Position).Magnitude > maxDistance then
			notify(string.format("too far (%d > %d studs)", math.floor((clickPosition - root.Position).Magnitude), math.floor(maxDistance)), "error")
			return
		end
	end

	local _, accepted, reason = controller:MoveTo(clickPosition)
	if not accepted then
		setControlsLocked(false)
		notify("cannot path there: " .. tostring(reason), "error")
		return
	end

	setControlsLocked(true)
	if doubleClick then
		startSprint()
	end
	applyDebugState()
end

UI.MOVEMENT_KEYS = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true,
	[Enum.KeyCode.Down] = true,
	[Enum.KeyCode.Left] = true,
	[Enum.KeyCode.Right] = true,
}

local function keyCodeFromName(name: string): EnumItem?
	local ok, keyCode = pcall(function()
		return (Enum.KeyCode :: any)[name]
	end)
	if ok then
		return keyCode
	end
	return nil
end

local setWindowOpen

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- Keybind capture deliberately runs before the gameProcessed gate so a bind
	-- can still be set while a UI element holds focus.
	if input.UserInputType == Enum.UserInputType.Keyboard and UI.awaitingKeybind then
		if input.KeyCode == Enum.KeyCode.Escape then
			UI.awaitingKeybind.cancel()
		elseif input.KeyCode ~= Enum.KeyCode.Unknown then
			UI.awaitingKeybind.accept(input.KeyCode.Name)
		end
		return
	end

	if UserInputService:GetFocusedTextBox() then
		return
	end

	if input.UserInputType == Enum.UserInputType.Keyboard then
		local pressed = input.KeyCode
		if pressed == keyCodeFromName(tostring(Config.Get("Nav.ToggleUIKey"))) then
			setWindowOpen(not UI.windowOpen)
			return
		end
		if pressed == keyCodeFromName(tostring(Config.Get("Nav.ToggleNavKey"))) then
			Config.Set("Nav.Enabled", Config.Get("Nav.Enabled") ~= true)
			return
		end
		if pressed == keyCodeFromName(tostring(Config.Get("Nav.StopKey"))) then
			stopNavigation()
			return
		end
		if controller and controller.State == "Moving" then
			if UI.MOVEMENT_KEYS[pressed] and Config.Get("Nav.CancelOnManualInput") == true then
				stopNavigation()
			elseif pressed == Enum.KeyCode.Space and Config.Get("Nav.StopOnJump") == true then
				stopNavigation()
			end
		end
		return
	end

	if gameProcessed then
		return
	end
	if Config.Get("Nav.Enabled") ~= true then
		return
	end

	local activation = tostring(Config.Get("Nav.ActivationInput"))
	local expected = (Enum.UserInputType :: any)[activation]
	if input.UserInputType ~= expected then
		return
	end
	if pointerOverInterface() then
		return
	end

	local modifier = tostring(Config.Get("Nav.RequireModifier"))
	if modifier ~= "None" then
		local modifierKey = keyCodeFromName(modifier)
		if not modifierKey or not UserInputService:IsKeyDown(modifierKey) then
			return
		end
	end

	local now = os.clock()
	local doubleClick = (now - UI.lastClickTime) <= 0.32
	UI.lastClickTime = now
	UI.holdingActivation = true
	requestMove(doubleClick)
end))

track(UserInputService.InputEnded:Connect(function(input)
	local activation = tostring(Config.Get("Nav.ActivationInput"))
	local expected = (Enum.UserInputType :: any)[activation]
	if input.UserInputType == expected then
		UI.holdingActivation = false
	end
end))

-- Hold to repath: keeps retargeting the point under the cursor while held.
task.spawn(function()
	while gui.Parent do
		task.wait(0.22)
		if UI.holdingActivation
			and Config.Get("Nav.HoldToRepath") == true
			and Config.Get("Nav.Enabled") == true
			and not pointerOverInterface()
		then
			requestMove(false)
		end
	end
end)

-- ============================================================================
--  Window chrome theming, open / close, live readouts
-- ============================================================================

onTheme(function(palette, accent)
	window.BackgroundColor3 = palette.bg
	local windowStroke = window:FindFirstChildOfClass("UIStroke")
	if windowStroke then
		windowStroke.Color = palette.line
	end

	titleBar.BackgroundColor3 = palette.bg3
	local foot = titleBar:FindFirstChild("TitleBarFoot")
	if foot then
		foot.BackgroundColor3 = palette.bg3
	end
	titleAccent.BackgroundColor3 = accent
	local flow = titleAccent:FindFirstChild("Flow")
	if flow then
		flow.Color = ColorSequence.new(accent)
	end
	UI.titleText.TextColor3 = palette.dim
	UI.versionChip.BackgroundColor3 = palette.card
	UI.versionChip.TextColor3 = accent
	UI.closeDot.BackgroundColor3 = palette.red
	UI.closeDot.TextColor3 = palette.dim
	UI.minimiseDot.BackgroundColor3 = palette.card
	UI.minimiseDot.TextColor3 = palette.dim
	UI.zoomDot.BackgroundColor3 = palette.card
	UI.zoomDot.TextColor3 = palette.dim

	sidebar.BackgroundColor3 = palette.bg2
	UI.sidebarHeader.TextColor3 = palette.faint
	UI.tabList.ScrollBarImageColor3 = palette.line

	UI.searchBar.BackgroundColor3 = palette.bg2
	local searchStroke = UI.searchBar:FindFirstChildOfClass("UIStroke")
	if searchStroke then
		searchStroke.Color = palette.line
	end
	local prompt = UI.searchBar:FindFirstChild("Prompt")
	if prompt then
		prompt.TextColor3 = accent
	end
	UI.searchBox.TextColor3 = palette.text
	UI.searchBox.PlaceholderColor3 = palette.faint

	UI.statusBar.BackgroundColor3 = palette.bg3
	local statusHead = UI.statusBar:FindFirstChild("StatusHead")
	if statusHead then
		statusHead.BackgroundColor3 = palette.bg3
	end
	UI.statusLeft.TextColor3 = palette.dim
	UI.statusRight.TextColor3 = palette.faint

	UI.launcher.BackgroundColor3 = palette.bg2
	UI.launcher.TextColor3 = accent
	local launcherStroke = UI.launcher:FindFirstChildOfClass("UIStroke")
	if launcherStroke then
		launcherStroke.Color = palette.line
	end

	for _, page in pairs(UI.pages) do
		page.ScrollBarImageColor3 = palette.line
	end
end)

-- Slow accent sweep across the title bar. Cheap, and it makes the window feel alive.
do
	local flow = titleAccent:FindFirstChild("Flow")
	if flow then
		task.spawn(function()
			while gui.Parent do
				if Config.Get("Nav.Animations") ~= false and UI.windowOpen then
					flow.Offset = Vector2.new(((os.clock() * 0.25) % 2) - 1, 0)
					task.wait(0.04)
				else
					task.wait(0.25)
				end
			end
		end)
	end
end

function setWindowOpen(state: boolean)
	if UI.windowOpen == state then
		return
	end
	UI.windowOpen = state

	if state then
		window.Visible = true
		window.Size = UDim2.fromOffset(WINDOW_SIZE.X * 0.94, WINDOW_SIZE.Y * 0.94)
		window.BackgroundTransparency = 1
		tween(window, {
			Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
			BackgroundTransparency = 0,
		}, 0.26, Enum.EasingStyle.Quint)
		tween(UI.launcher, { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }, 0.16)
		task.delay(0.18, function()
			if UI.windowOpen then
				UI.launcher.Visible = false
			end
		end)
		if Config.Get("Nav.BlurBackground") == true then
			UI.blur.Enabled = true
			tween(UI.blur, { Size = 14 }, 0.3)
		end
	else
		tween(window, {
			Size = UDim2.fromOffset(WINDOW_SIZE.X * 0.94, WINDOW_SIZE.Y * 0.94),
			BackgroundTransparency = 1,
		}, 0.2)
		task.delay(0.22, function()
			if not UI.windowOpen then
				window.Visible = false
			end
		end)
		UI.launcher.Visible = true
		UI.launcher.Size = UDim2.fromOffset(0, 0)
		tween(UI.launcher, { Size = UDim2.fromOffset(38, 38), BackgroundTransparency = 0 }, 0.22, Enum.EasingStyle.Back)
		tween(UI.blur, { Size = 0 }, 0.2)
		task.delay(0.25, function()
			if not UI.windowOpen then
				UI.blur.Enabled = false
			end
		end)
	end
end

UI.closeDot.MouseButton1Click:Connect(function()
	setWindowOpen(false)
end)
UI.minimiseDot.MouseButton1Click:Connect(function()
	setWindowOpen(false)
end)
UI.zoomDot.MouseButton1Click:Connect(function()
	window.Position = UDim2.fromScale(0.5, 0.5)
end)
UI.launcher.MouseButton1Click:Connect(function()
	setWindowOpen(true)
end)
UI.launcher.MouseEnter:Connect(function()
	tween(UI.launcher, { Size = UDim2.fromOffset(42, 42) }, 0.12)
end)
UI.launcher.MouseLeave:Connect(function()
	tween(UI.launcher, { Size = UDim2.fromOffset(38, 38) }, 0.12)
end)

UI.powerLabel.MouseButton1Click:Connect(function()
	Config.Set("Nav.Enabled", Config.Get("Nav.Enabled") ~= true)
end)

-- ---------------------------------------------------------------------------
--  Overview quick actions
-- ---------------------------------------------------------------------------

if UI.overviewActions then
	local function quick(order, text, action)
		local button = Widgets.button(UI.overviewActions, { label = text, action = action })
		button.LayoutOrder = order
		button.Size = UDim2.new(0.25, -6, 1, 0)
	end
	quick(1, "toggle nav", function()
		Config.Set("Nav.Enabled", Config.Get("Nav.Enabled") ~= true)
	end)
	quick(2, "stop route", function()
		stopNavigation()
	end)
	quick(3, "toggle debug", function()
		Config.Set("Debug.Enabled", Config.Get("Debug.Enabled") ~= true)
	end)
	quick(4, "save place cfg", function()
		saveProfile(PLACE_PROFILE)
		toast("saved profile " .. PLACE_PROFILE, "good")
	end)
end

-- ---------------------------------------------------------------------------
--  Runtime sync
-- ---------------------------------------------------------------------------

-- Bulk knobs. Every value here also exists as an individual slider; the preset
-- just moves the ones that actually cost frame time together.
UI.PERFORMANCE_PRESETS = {
	Quality = {
		["UpdateRates.ProbeInterval"] = 0.12,
		["UpdateRates.ObstacleScanInterval"] = 0.08,
		["RouteValidation.Interval"] = 0.2,
		["RouteValidation.LookAheadNodes"] = 7,
		["PathSmoothing.Passes"] = 3,
		["PathSmoothing.SearchIterations"] = 6,
		["PathSmoothing.MaxLookAheadNodes"] = 10,
		["PathSmoothing.MaxProbesPerRoute"] = 2000,
		["Shortcut.SampleSpacing"] = 3,
		["Shortcut.SideProbeStride"] = 1,
		["Debug.DrawInterval"] = 0.033,
	},
	Balanced = {
		["UpdateRates.ProbeInterval"] = 0.2,
		["UpdateRates.ObstacleScanInterval"] = 0.12,
		["RouteValidation.Interval"] = 0.3,
		["RouteValidation.LookAheadNodes"] = 5,
		["PathSmoothing.Passes"] = 2,
		["PathSmoothing.SearchIterations"] = 5,
		["PathSmoothing.MaxLookAheadNodes"] = 6,
		["PathSmoothing.MaxProbesPerRoute"] = 900,
		["Shortcut.SampleSpacing"] = 4,
		["Shortcut.SideProbeStride"] = 2,
		["Debug.DrawInterval"] = 0.05,
	},
	Performance = {
		["UpdateRates.ProbeInterval"] = 0.3,
		["UpdateRates.ObstacleScanInterval"] = 0.2,
		["RouteValidation.Interval"] = 0.5,
		["RouteValidation.LookAheadNodes"] = 4,
		["PathSmoothing.Passes"] = 1,
		["PathSmoothing.SearchIterations"] = 4,
		["PathSmoothing.MaxLookAheadNodes"] = 4,
		["PathSmoothing.MaxProbesPerRoute"] = 450,
		["Shortcut.SampleSpacing"] = 6,
		["Shortcut.SideProbeStride"] = 3,
		["Debug.DrawInterval"] = 0.1,
	},
	Potato = {
		["UpdateRates.ProbeInterval"] = 0.5,
		["UpdateRates.ObstacleScanInterval"] = 0.35,
		["RouteValidation.Interval"] = 0.8,
		["RouteValidation.LookAheadNodes"] = 3,
		["PathSmoothing.Passes"] = 1,
		["PathSmoothing.SearchIterations"] = 3,
		["PathSmoothing.MaxLookAheadNodes"] = 3,
		["PathSmoothing.MaxProbesPerRoute"] = 220,
		["Shortcut.SampleSpacing"] = 8,
		["Shortcut.SideProbeStride"] = 4,
		["Debug.DrawInterval"] = 0.2,
	},
}

UI.lastPreset = nil

local function syncPerformancePreset()
	UI.lastPreset = tostring(Config.Get("Performance.Preset"))
end

local function applyPerformancePreset()
	local name = tostring(Config.Get("Performance.Preset"))
	if name == UI.lastPreset then
		return
	end
	local preset = UI.PERFORMANCE_PRESETS[name]
	if not preset then
		return
	end
	UI.lastPreset = name
	for path, value in pairs(preset) do
		Config.Set(path, value, true)
	end
	refreshAll()
end

-- Installs or removes the kill brick hooks on the solver. The detector holds
-- plain function fields, so switching the feature off leaves it exactly as it
-- was rather than paying for a disabled code path on every raycast.
local function applyKillBricks()
	local on = Config.Get("KillBricks.Enabled") == true
	if on then
		ObstacleDetector.LethalTest = KillBricks.IsLethal
		ObstacleDetector.LethalNearbyTest = KillBricks.NearbyLethal
		if not KillBricks.Armed then
			KillBricks.Armed = true
			local loaded = KillBricks.Load()
			KillBricks.WatchWorld()
			if controller and controller.Character then
				KillBricks.WatchCharacter(controller.Character)
			end
			if loaded > 0 then
				navLog("killbricks", string.format("recalled %d hazard shapes for this place", loaded), Logger.Level.Info)
			end
		end
	else
		ObstacleDetector.LethalTest = nil
		ObstacleDetector.LethalNearbyTest = nil
		if KillBricks.Armed then
			KillBricks.Armed = false
			KillBricks.Flush()
			KillBricks.Detach()
		end
	end
end

local function applyRuntime()
	local levelName = tostring(Config.Get("Nav.LogLevel"))
	local level = Logger.Level[levelName] or Logger.Level.Warn
	Logger.setConsoleLevel(level)

	local enabled = Config.Get("Nav.Enabled") == true
	local palette = Theme.palette
	tween(UI.powerDot, { BackgroundColor3 = if enabled then palette.green else palette.red }, 0.15)
	UI.powerLabel.Text = if enabled then "enabled" else "disabled"
	UI.powerLabel.TextColor3 = if enabled then palette.green else palette.red
	UI.launcherPulse.BackgroundColor3 = if enabled then palette.green else palette.red

	UI.statusBar.Visible = Config.Get("Nav.StatusBar") ~= false

	if not enabled then
		if controller and (controller.State == "Moving" or controller.State == "WaitingForPath") then
			stopNavigation(true)
		end
		setControlsLocked(false)
	end

	if UI.windowOpen and Config.Get("Nav.BlurBackground") ~= true then
		tween(UI.blur, { Size = 0 }, 0.2)
		task.delay(0.25, function()
			if Config.Get("Nav.BlurBackground") ~= true then
				UI.blur.Enabled = false
			end
		end)
	elseif UI.windowOpen and Config.Get("Nav.BlurBackground") == true then
		UI.blur.Enabled = true
		tween(UI.blur, { Size = 14 }, 0.2)
	end

	applyKillBricks()
	applyDebugState()
end

Config.OnChanged(function(path)
	if path == "*" or path == "Nav.Theme" or path == "Nav.Accent" then
		refreshTheme()
	end
	if path == "*" or path == "Nav.FontStyle" then
		applyFonts()
	end
	if path == "*" then
		syncPerformancePreset()
	elseif path == "Performance.Preset" then
		applyPerformancePreset()
	end
	if path == "*" then
		refreshAll()
	end
	if path == "*" or path == "Nav.DetailLevel" or path == "Nav.ShowDescriptions" then
		UIMeta.paintToolbar()
		UIMeta.applyFilter()
	end
	applyRuntime()
end)

if UI.overviewHint then
	local function renderHint()
		UI.overviewHint.Text = string.format(
			"click the ground to walk there. the route is planned with PathfindingService,\nthen smoothed, validated and repaired every frame while you move.\n\n  %s   open and close this window\n  %s   turn navigation on and off\n  %s   cancel the current route\n\nright click any slider value to reset that one setting.",
			tostring(Config.Get("Nav.ToggleUIKey")),
			tostring(Config.Get("Nav.ToggleNavKey")),
			tostring(Config.Get("Nav.StopKey"))
		)
	end
	addRefresher(renderHint)
end

-- ---------------------------------------------------------------------------
--  Live readouts
-- ---------------------------------------------------------------------------

local fps = 60
do
	local accumulated, frames = 0, 0
	track(RunService.RenderStepped:Connect(function(dt)
		accumulated += dt
		frames += 1
		if accumulated >= 0.4 then
			fps = frames / accumulated
			accumulated, frames = 0, 0
		end
	end))
end

local function currentPing(): number
	local ok, value = pcall(function()
		return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	if ok and type(value) == "number" then
		return value
	end
	return 0
end

UI.statusDot = new("Frame", {
	Name = "Dot",
	Position = UDim2.new(0, 0, 0.5, -3),
	Size = UDim2.fromOffset(6, 6),
	BackgroundColor3 = Theme.palette.green,
	BorderSizePixel = 0,
	ZIndex = 4,
	Parent = UI.statusLeft,
}, { corner(3) })
UI.statusLeft.Position = UDim2.new(0, 24, 0, 0)
UI.statusDot.Position = UDim2.new(0, -14, 0.5, -3)

local function snapshotOf()
	if controller and controller._buildDebugSnapshot then
		local ok, snapshot = pcall(function()
			return controller:_buildDebugSnapshot()
		end)
		if ok then
			return snapshot
		end
	end
	return { State = "Idle", WaypointIndex = 0, WaypointCount = 0, Replans = 0, Repairs = 0 }
end

KillBricks.OnLearned = function(part, source)
	if Config.Get("KillBricks.AnnounceLearned") == false then
		return
	end
	toast(string.format("kill brick learned: %s (%s)", part.Name, source), "warn")
end

task.spawn(function()
	local lastFlush = os.clock()
	while gui.Parent do
		task.wait(1)
		if Config.Get("KillBricks.Enabled") == true then
			pcall(KillBricks.Sweep)
			if os.clock() - lastFlush >= 20 then
				lastFlush = os.clock()
				pcall(KillBricks.Flush)
			end
		end
	end
end)

task.spawn(function()
	while gui.Parent do
		task.wait(if UI.windowOpen then 0.12 else 0.4)
		local ok = pcall(function()
			local snapshot = snapshotOf()
			local palette = Theme.palette
			local enabled = Config.Get("Nav.Enabled") == true
			local moving = snapshot.State == "Moving"

			if UI.statusBar.Visible then
				local dotColor = palette.faint
				if not enabled then
					dotColor = palette.red
				elseif moving then
					dotColor = if math.floor(os.clock() * 3) % 2 == 0 then palette.green else palette.teal
				elseif snapshot.State == "Completed" then
					dotColor = palette.green
				elseif snapshot.State == "Failed" then
					dotColor = palette.red
				end
				UI.statusDot.BackgroundColor3 = dotColor

				UI.statusLeft.Text = string.format(
					"%s   state %s   wp %s/%s   stuck %s",
					if enabled then "nav on" else "nav off",
					string.lower(tostring(snapshot.State)),
					tostring(snapshot.WaypointIndex or 0),
					tostring(snapshot.WaypointCount or 0),
					if snapshot.Stuck then "yes" else "no"
				)
				UI.statusRight.Text = string.format(
					"replans %s   repairs %s   %d fps   %d ms",
					tostring(snapshot.Replans or 0),
					tostring(snapshot.Repairs or 0),
					math.floor(fps + 0.5),
					math.floor(currentPing() + 0.5)
				)
			end

			if UI.windowOpen and UI.activeTab == "overview" and UI.overviewTitle then
				UI.overviewTitle.Text = string.format("%s@%s", player.Name, string.gsub(placeName, "%s+", "-"))

				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")

				local values = {
					script = string.format("%s %s", SCRIPT_NAME, SCRIPT_VERSION),
					engine = "Roblox / Luau",
					place = placeName,
					placeid = string.format("%d", game.PlaceId),
					profile = if Storage.Exists(PLACE_PROFILE) then PLACE_PROFILE .. ".json" else "unsaved",
					storage = Storage.Mode,
					theme = string.format("%s / %s", tostring(Config.Get("Nav.Theme")), tostring(Config.Get("Nav.Accent"))),
					state = string.format("%s%s", string.lower(tostring(snapshot.State)), if enabled then "" else "  (navigation off)"),
					route = string.format("%s / %s waypoints", tostring(snapshot.WaypointIndex or 0), tostring(snapshot.WaypointCount or 0)),
					replans = string.format("%s replans   %s repairs", tostring(snapshot.Replans or 0), tostring(snapshot.Repairs or 0)),
					speed = if humanoid then string.format("%.1f studs/s", humanoid.WalkSpeed) else "no humanoid",
					fps = string.format("%d", math.floor(fps + 0.5)),
					ping = string.format("%d ms", math.floor(currentPing() + 0.5)),
					uptime = humanTime(os.clock() - SESSION_START),
				}

				for key, label in pairs(UI.fetchValueLabels) do
					label.Text = values[key] or ""
				end
			end
		end)
		if not ok then
			task.wait(0.5)
		end
	end
end)

-- ---------------------------------------------------------------------------
--  Boot
-- ---------------------------------------------------------------------------

if player.Character then
	bindCharacter(player.Character)
end
track(player.CharacterAdded:Connect(function(character)
	bindCharacter(character)
end))

selectTab("overview")

-- Prefer a config saved for this specific place, then a global one.
do
	local loaded = false
	if Storage.Exists(PLACE_PROFILE) then
		loaded = loadProfile(PLACE_PROFILE)
	elseif Storage.Exists("global") then
		loaded = loadProfile("global")
	end
	if not loaded then
		Config.Broadcast()
	end
end

UI.Meta = UIMeta
UI.Cards = UIMeta.Cards
UI.Schema = SCHEMA

do
	local function toggle(path)
		return function()
			Config.Set(path, Config.Get(path) ~= true)
		end
	end

	UI.buildMenu("Nav", 1, {
		{ text = "Toggle navigation", run = toggle("Nav.Enabled") },
		{ text = "Stop current route", run = function()
			stopNavigation(true)
		end },
		{ separator = true },
		{ text = "Lock player controls", run = toggle("Nav.LockControls") },
		{ text = "Hold to repath", run = toggle("Nav.HoldToRepath") },
	})

	UI.buildMenu("View", 2, {
		{ text = "Detail: Basic", run = function()
			Config.Set("Nav.DetailLevel", "Basic")
		end },
		{ text = "Detail: Advanced", run = function()
			Config.Set("Nav.DetailLevel", "Advanced")
		end },
		{ text = "Detail: Everything", run = function()
			Config.Set("Nav.DetailLevel", "Everything")
		end },
		{ separator = true },
		{ text = "Show descriptions", run = toggle("Nav.ShowDescriptions") },
		{ text = "Status bar", run = toggle("Nav.StatusBar") },
		{ text = "Blur behind window", run = toggle("Nav.BlurBackground") },
		{ separator = true },
		{ text = "Window style: Desktop", run = function()
			Config.Set("Nav.WindowStyle", "Desktop")
			notify("reopen the window to redraw the chrome", "info")
		end },
		{ text = "Window style: Terminal", run = function()
			Config.Set("Nav.WindowStyle", "Terminal")
			notify("reopen the window to redraw the chrome", "info")
		end },
	})

	UI.buildMenu("Tools", 3, {
		{ text = "Debug overlay", run = toggle("Debug.Enabled") },
		{ text = "Emulate trajectories", run = toggle("Emulation.Enabled") },
		{ text = "Learn kill bricks", run = toggle("KillBricks.Enabled") },
		{ text = "Forget kill bricks", run = function()
			KillBricks.Forget()
			KillBricks.Save()
			notify("kill brick memory cleared", "good")
		end },
		{ separator = true },
		{ text = "Save profile for this place", run = function()
			if saveProfile(PLACE_PROFILE) then
				notify("saved " .. PLACE_PROFILE, "good")
			end
		end },
		{ text = "Reset every setting", run = function()
			Config.ResetAll()
			notify("settings reset", "good")
		end },
	})

	UI.buildMenu("Help", 4, {
		{ text = "About", run = function()
			notify(string.format("%s %s  -  storage %s", SCRIPT_NAME, SCRIPT_VERSION, Storage.Mode), "info")
		end },
		{ text = "Keys", run = function()
			notify(string.format("%s window   %s navigation   %s stop",
				tostring(Config.Get("Nav.ToggleUIKey")),
				tostring(Config.Get("Nav.ToggleNavKey")),
				tostring(Config.Get("Nav.StopKey"))), "info")
		end },
	})
end

UIMeta.Boot.Step("wiring runtime")
refreshTheme()
refreshAll()
applyRuntime()
UIMeta.paintToolbar()
UIMeta.applyFilter()
UIMeta.Boot.Step("ready")
UIMeta.Boot.Finish()
navLog("boot", string.format("%s %s ready  storage=%s  place=%s", SCRIPT_NAME, SCRIPT_VERSION, Storage.Mode, PLACE_PROFILE), Logger.Level.Warn)
toast(string.format("%s %s loaded  -  press %s", SCRIPT_NAME, SCRIPT_VERSION, tostring(Config.Get("Nav.ToggleUIKey"))), "good")

-- ---------------------------------------------------------------------------
--  Teardown
-- ---------------------------------------------------------------------------

_G.__PortableNavigationV2 = {
	Version = SCRIPT_VERSION,
	Config = Config,
	Runtime = RuntimeConfig,
	GetController = function()
		return controller
	end,
	Toggle = function(state)
		Config.Set("Nav.Enabled", if state == nil then Config.Get("Nav.Enabled") ~= true else state == true)
	end,
	OpenUI = function(state)
		setWindowOpen(if state == nil then not UI.windowOpen else state == true)
	end,
	KillBricks = KillBricks,
	UI = UI,
	GetClickPosition = function()
		return getClickPosition(player.Character)
	end,
	Teardown = function()
		KillBricks.Flush()
		KillBricks.Detach()
		for _, connection in ipairs(UI.connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		disconnectControllerSignals()
		stopSprint()
		releaseMove()
		setControlsLocked(false)
		MovementController.MoveApplier = nil
		if controller then
			pcall(function()
				controller:Destroy()
			end)
			controller = nil
		end
		if UI.blur then
			UI.blur:Destroy()
		end
		if gui then
			gui:Destroy()
		end
		_G.__PortableNavigationV2 = nil
	end,
}
