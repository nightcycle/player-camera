--!strict
-- Services
local PlayersService = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local VRService = game:GetService("VRService")
local Settings = UserSettings()

-- Packages
local Package = script.Parent
local Packages = Package.Parent
local Maid = require(Packages:WaitForChild("Maid"))

-- Modules
local CameraScript = script.Parent
local ShiftLockController = require(CameraScript:WaitForChild("ShiftLockController"))

-- Constants
local PORTRAIT_MODE = false
local MIN_Y = math.rad(-80)
local MAX_Y = math.rad(80)

local DEFAULT_CAMERA_ANGLE = 25
local VR_ANGLE = math.rad(15)

local VR_LOW_INTENSITY_ROTATION = Vector2.new(math.rad(15), 0)
local VR_HIGH_INTENSITY_ROTATION = Vector2.new(math.rad(45), 0)
local VR_LOW_INTENSITY_REPEAT = 0.1
local VR_HIGH_INTENSITY_REPEAT = 0.4

local ZERO_VECTOR2 = Vector2.new(0, 0)
local ZERO_VECTOR3 = Vector3.new(0, 0, 0)

local TOUCH_SENSITIVTY = Vector2.new(math.pi * 2.25, math.pi * 2)
local MOUSE_SENSITIVITY = Vector2.new(math.pi * 4, math.pi * 1.9)

local MAX_TAP_POS_DELTA = 15
local MAX_TAP_TIME_DELTA = 0.75

local SEAT_OFFSET = Vector3.new(0, 5, 0)
local VR_SEAT_OFFSET = Vector3.new(0, 4, 0)
local HEAD_OFFSET = Vector3.new(0, 1.5, 0)
local R15_HEAD_OFFSET = Vector3.new(0, 2.0, 0)

local PORTRAIT_MODE_CAMERA_OFFSET = 2
local STATE_DEAD = Enum.HumanoidStateType.Dead
local QUARTER_PI = math.pi / 4

local THUMBSTICK_DEADZONE = 0.2
local LANDSCAPE_DEFAULT_ZOOM = 12.5
local PORTRAIT_DEFAULT_ZOOM = 25

local DEADZONE = 0.1

-- Types
type Maid = Maid.Maid
export type CameraTween = {
	duration: number,
	from: number,
	func: (number, number, number) -> number,
	start: number,
	to: number
}

export type CameraControllerProperties = {
	_Maid: Maid,
	R15HeadHeight: Vector3,
	ShiftLock: boolean,
	Enabled: boolean,
	RotateInput: Vector2,
	DefaultZoom: number,
	GamepadPanningCamera: Vector2?,
	CFrame: CFrame?,

	_VRRotateKeyCooldown: {[Enum.KeyCode]: boolean},
	_Tweens: {[string]: CameraTween},
	_FingerTouches: {[InputObject]: boolean},
	_InputStartPositions: {[InputObject]: Vector3},
	_InputStartTimes: {[InputObject]: number},

	_IsFirstPerson: boolean,
	_IsRightMouseDown: boolean,
	_IsMiddleMouseDown: boolean,
	_IsInFirstPerson: boolean,

	_ActiveGamepad: Enum.UserInputType?,
	_LastSubject: Instance?,
	_LastSubjectPosition: Vector3?,
	_LastVRRotation: number,
	LastUserPanCamera: number?, 
	
	_IsDynamicThumbstickEnabled: boolean,
	_DynamicThumbstickFrame: Frame?,

	_VRRotationIntensityExists: boolean,
	_LastVRRotationCheck: number,	
	_CameraTranslationConstraints: Vector3,
	_HumanoidJumpOrigin: Vector3?,
	_TrackingHumanoid: Humanoid?,

	_StartPos: Vector3?,
	_LastPos: Vector3?,
	_PanBeginLook: Vector3?,
	_LastTapTime: number?,
	_NumUnsunkTouches: number,
	
	_StartingDiff: number?,
	_PinchBeginZoom: number?,
	_CurrentZoom: number?,
	_LastThumbstickRotate: number?,
	_LastVrRotationCheck: number?,

	_ZoomEnabled: boolean,
	_PanEnabled: boolean,
	_KeyPanEnabled: boolean,
	TurningLeft: boolean,
	TurningRight: boolean,
	UserPanningTheCamera: boolean,
	_CameraFrozen: boolean,
	_VRMaxSpeed: number,
	_NumOfSeconds: number,
	_CurrentSpeed: number,
	_MaxSpeed: number,
	_YSensitivity: number,

	_LastThumbstickPos: Vector2,
	_LastVelocity: Vector2?,
	LastCameraFocus: Vector3?,
	_InputBeganConn: RBXScriptConnection?,
	_InputChangedConn: RBXScriptConnection?,
	_InputEndedConn: RBXScriptConnection?,
	_WindowUnfocusConn: RBXScriptConnection?,
	_MenuOpenedConn: RBXScriptConnection?,
	_ShiftLockToggleConn: RBXScriptConnection?,
	_GamepadConnectedConn: RBXScriptConnection?,
	_GamepadDisconnectedConn: RBXScriptConnection?,
	_TouchActivateConn: RBXScriptConnection?,
	_SubjectStateChangedConn: RBXScriptConnection?,
	_CameraSubjectChangedConn: RBXScriptConnection?,
	_WorkspaceChangedConn: RBXScriptConnection?,
	_HumanoidChildAddedConn: RBXScriptConnection?,
	_HumanoidChildRemovedConn: RBXScriptConnection?,
	_CameraChangedConn: RBXScriptConnection?,
	_WorkspaceCameraChangedConn: RBXScriptConnection?,
	_HeightScaleChangedConn: RBXScriptConnection?,

	LastCameraTransform: CFrame?,
	LastSubjectCFrame: CFrame?,

	_GamepadPanningCamera: Vector2,
}

export type CameraControllerFunctions<S> = {
	__index: S,
	GetActivateValue: (self: S) -> number,
	IsPortraitMode: (self: S) -> boolean,
	GetRotateAmountValue: (self: S, vrRotationIntensity: string) -> Vector2,
	GetRepeatDelayValue: (self: S, vrRotationIntensity: string) -> number,

	GetShiftLock: (self: S) -> boolean,
	GetHumanoid: (self: S) -> Humanoid?,
	GetHumanoidRootPart: (self: S) -> BasePart?,
	GetSubjectPosition: (self: S) -> Vector3?,
	ResetCameraLook: (self: S) -> nil,
	ResetInputStates: (self: S) -> nil,
	GetCameraLook: (self: S) -> Vector3,
	GetCameraZoom: (self: S) -> number,
	GetCameraActualZoom: (self: S) -> number,
	GetCameraHeight: (self: S) -> number,
	ViewSizeX: (self: S) -> number,
	ViewSizeY: (self: S) -> number,
	ScreenTranslationToAngle: (self: S, translationVector: Vector2) -> Vector2,
	MouseTranslationToAngle: (self: S, translationVector: Vector2) -> Vector2,
	RotateVector: (self: S, startVector: Vector3, xyRotateVector: Vector2) -> (Vector3, Vector2),
	RotateCamera: (self: S, startVector: Vector3, xyRotateVector: Vector2) -> (Vector3, Vector2),
	IsInFirstPerson: (self: S) -> boolean,
	UpdateMouseBehavior: (self: S) -> nil,
	ZoomCamera: (self: S, desiredZoom: number) -> number,
	RK4Integrator: (self: S, position: number, velocity: number, t: number) -> (number, number),
	ZoomCameraBy: (self: S, zoomScale: number) -> number,
	ZoomCameraFixedBy: (self: S, zoomScale: number) -> number,
	Update: (self: S) -> nil,
	ApplyVRTransform: (self: S) -> nil,
	ShouldUseVRRotation: (self: S) -> boolean,
	GetVRRotationInput: (self: S) -> Vector2,
	UpdateGamepad: (self: S) -> Vector2,
	GetVRFocus: (self: S, subjectPosition: Vector3, timeDelta: number) -> CFrame,
	DisconnectInputEvents: (self: S) -> nil,
	BindGamepadInputActions: (self: S) -> nil,
	ConnectInputEvents: (self: S) -> nil,
	ProcessTweens: (self: S) -> nil,
	SetEnabled: (self: S, newState: boolean) -> nil,
	Destroy: (self: S) -> nil,
	new: () -> S,

	_GetDynamicThumbstickFrame: (self: S) -> Frame?,
	_OnWorkspaceCameraChanged: (self: S) -> nil,
	_GetRenderCFrame: (self: S, part: BasePart) -> CFrame,
	_GetHumanoidPartToFollow: (self: S, humanoid: Humanoid, humanoidStateType: Enum.HumanoidStateType) -> BasePart,
	_CancelCameraFreeze: (self: S, keepConstraints: boolean) -> nil,
	_StartCameraFreeze: (self: S, subjectPosition: Vector3, humanoidToTrack: Humanoid) -> nil,
	_RescaleCameraOffset: (self: S, newScaleFactor: number) -> nil,
	_OnHumanoidSubjectChildAdded: (self: S, child: Instance) -> nil,
	_OnHumanoidSubjectChildRemoved: (self: S, child: Instance) -> nil,
	_OnNewCameraSubject: (self: S) -> nil,
	_OnCurrentCameraChanged: (self: S) -> nil,
	_OnTouchBegan: (self: S, input: InputObject, processed: boolean) -> nil,
	_OnTouchChanged: (self: S, input: InputObject, processed: boolean) -> nil,
	_CalcLookBehindRotateInput: (self: S, torso: BasePart) -> Vector2,
	_IsTouchTap: (self: S, input: InputObject) -> boolean,
	_OnTouchEnded: (self: S, input: InputObject, processed: boolean) -> nil,
	_OnMousePanButtonPressed: (self: S, input: InputObject, processed: boolean) -> nil,
	_OnMousePanButtonReleased: (self: S, input: InputObject?, processed: boolean?) -> nil,
	_OnMouse2Down: (self: S, input: InputObject, processed: boolean) -> nil,
	_OnMouse2Up: (self: S, input: InputObject, processed: boolean) -> nil,
	_OnMouse3Down: (self: S, input: InputObject, processed: boolean) -> nil,
	_OnMouse3Up: (self: S, input: InputObject, processed: boolean) -> nil,
	_OnMouseMoved: (self: S, input: InputObject, processed: boolean) -> nil,
	_OnMouseWheel: (self: S, input: InputObject, processed: boolean) -> nil,
	_RotateVectorByAngleAndRound: (self: S, camLook: Vector3, rotateAngle: number, roundAmount: number) -> number,
	_OnKeyDown: (self: S, input: InputObject, processed: boolean) -> nil,
	_OnKeyUp: (self: S, input: InputObject, processed: boolean) -> nil,
	_OnWindowFocusReleased: (self: S) -> nil,
	_GetGamepadPan: (self: S, name: string, state: Enum.UserInputState, input: InputObject) -> nil,
	_DoGamepadZoom: (self: S, name: string, state: Enum.UserInputState, input: InputObject) -> nil,
	_OnCharacterAdded: (self: S, player: Player, character: Model) -> nil,
	_OnPlayerAdded: (self: S, player: Player) -> nil,
	_OnGameLoaded: (self: S) -> nil,
	_OnDynamicThumbstickEnabled: (self: S) -> nil,
	_OnDynamicThumbstickDisabled: (self: S) -> nil,
	_OnGameSettingsTouchMovementModeChanged: (self: S) -> nil,
	_OnDevTouchMovementModeChanged: (self: S) -> nil,

}

type BaseCameraController<S> = CameraControllerProperties & CameraControllerFunctions<S>
export type CameraController = BaseCameraController<BaseCameraController<any>>

-- References
local PlayerGui = nil
if PlayersService.LocalPlayer then
	PlayerGui = PlayersService.LocalPlayer:WaitForChild("PlayerGui")
end

-- Globals
local setCameraOnSpawn = true
local hasGameLoaded = false
local gestureArea = nil
local gestureAreaManagedByControlScript = false
local humanoidCache: {[Player]: Humanoid} = {}

local function findAngleBetweenXZVectors(vec2: Vector3, vec1: Vector3)
	return math.atan2(vec1.X * vec2.Z - vec1.Z * vec2.X, vec1.X * vec2.X + vec1.Z * vec2.Z)
end

local function getDynamicInputObject(): InputObject
	-- local DynamicThumbstickModule = require(MasterControl:WaitForChild("DynamicThumbstick") :: ModuleScript)
	-- local dynamicInputObject = DynamicThumbstickModule:GetInputObject()
	return nil :: any
end

-- K is a tunable parameter that changes the shape of the S-curve
-- the larger K is the more straight/linear the curve gets
local function sCurveTranform(t)
	local k = 0.35
	local lowerK = 0.8
	t = math.clamp(t, -1, 1)
	if t >= 0 then
		return (k * t) / (k - t + 1)
	end
	return -((lowerK * -t) / (lowerK + t + 1))
end

local function toSCurveSpace(t: number)
	return (1 + DEADZONE) * (2 * math.abs(t) - 1) - DEADZONE
end

local function fromSCurveSpace(t: number)
	return t / 2 + 0.5
end

local function gamepadLinearToCurve(thumbstickPosition)
	local function onAxis(axisValue)
		local sign = 1
		if axisValue < 0 then
			sign = -1
		end
		local point = fromSCurveSpace(sCurveTranform(toSCurveSpace(math.abs(axisValue))))
		point = point * sign
		return math.clamp(point, -1, 1)
	end
	return Vector2.new(onAxis(thumbstickPosition.X), onAxis(thumbstickPosition.Y))
end

local function isFinite(num: number): boolean
	return num == num and num ~= 1 / 0 and num ~= -1 / 0
end

local function findPlayerHumanoid(player: Player): Humanoid?
	local character = player and player.Character
	if character then
		local resultHumanoid = humanoidCache[player]
		if resultHumanoid and resultHumanoid.Parent == character then
			return resultHumanoid
		else
			humanoidCache[player] = nil -- Bust Old Cache
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoidCache[player] = humanoid
			end
			return humanoid
		end
	end
	return nil
end

-- Reset the camera look vector when the camera is enabled for the first time
local function layoutGestureArea(portraitMode)
	if gestureArea and not gestureAreaManagedByControlScript then
		if portraitMode then
			gestureArea.Size = UDim2.new(1, 0, 0.6, 0)
			gestureArea.Position = UDim2.new(0, 0, 0, 0)
		else
			gestureArea.Size = UDim2.new(1, 0, 0.5, -18)
			gestureArea.Position = UDim2.new(0, 0, 0, 0)
		end
	end
end

-- Setup gesture area that camera uses while DynamicThumbstick is enabled
function onCharacterAdded(character: Model)
	if UserInputService.TouchEnabled then
		if PlayerGui then
			local TouchGui = PlayerGui:FindFirstChild("TouchGui")
			if TouchGui and TouchGui:WaitForChild("gestureArea", 0.5) then
				gestureArea = TouchGui.gestureArea
				gestureAreaManagedByControlScript = true
			else
				gestureAreaManagedByControlScript = false
				local ScreenGui = Instance.new("ScreenGui")
				ScreenGui.Name = "gestureArea"
				ScreenGui.Parent = PlayerGui

				gestureArea = Instance.new("Frame")
				gestureArea.BackgroundTransparency = 1.0
				gestureArea.Visible = true
				gestureArea.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				layoutGestureArea(PORTRAIT_MODE)
				gestureArea.Parent = ScreenGui
			end
		end
	end
end

if PlayersService.LocalPlayer then
	if PlayersService.LocalPlayer.Character ~= nil then
		onCharacterAdded(PlayersService.LocalPlayer.Character)
	end
	PlayersService.LocalPlayer.CharacterAdded:Connect(function(character)
		onCharacterAdded(character)
	end)
end

local function getRenderCFrame(part: BasePart): CFrame
	return (part :: any):GetRenderCFrame()
end

local CameraController: CameraController = {} :: any
CameraController.__index = CameraController :: any

function CameraController:GetActivateValue(): number
	return 0.7
end

function CameraController:IsPortraitMode(): boolean
	return PORTRAIT_MODE
end

function CameraController:GetRotateAmountValue(vrRotationIntensity: string): Vector2
	vrRotationIntensity = vrRotationIntensity or StarterGui:GetCore("VRRotationIntensity")
	if vrRotationIntensity then
		if vrRotationIntensity == "Low" then
			return VR_LOW_INTENSITY_ROTATION
		elseif vrRotationIntensity == "High" then
			return VR_HIGH_INTENSITY_ROTATION
		end
	end
	return ZERO_VECTOR2
end
function CameraController:GetRepeatDelayValue(vrRotationIntensity: string): number
	vrRotationIntensity = vrRotationIntensity or StarterGui:GetCore("VRRotationIntensity")
	if vrRotationIntensity then
		if vrRotationIntensity == "Low" then
			return VR_LOW_INTENSITY_REPEAT
		elseif vrRotationIntensity == "High" then
			return VR_HIGH_INTENSITY_REPEAT
		end
	end
	return 0
end

function CameraController:_GetDynamicThumbstickFrame(): Frame?
	if self._DynamicThumbstickFrame and self._DynamicThumbstickFrame:IsDescendantOf(game) then
		return self._DynamicThumbstickFrame
	else
		local touchGui = PlayerGui:FindFirstChild("TouchGui")
		if not touchGui then
			return nil
		end

		local touchControlFrame = touchGui:FindFirstChild("TouchControlFrame")
		if not touchControlFrame then
			return nil
		end

		self._DynamicThumbstickFrame = touchControlFrame:FindFirstChild("DynamicThumbstickFrame")
		return self._DynamicThumbstickFrame
	end
end

-- Check for changes in ViewportSize to decide if PORTRAIT_MODE
function CameraController:_OnWorkspaceCameraChanged(): nil
	if UserInputService.TouchEnabled then
		if self._CameraChangedConn then
			self._CameraChangedConn:Disconnect()
			self._CameraChangedConn = nil :: any
		end
		local newCamera = workspace.CurrentCamera
		if newCamera then
			local size = newCamera.ViewportSize
			PORTRAIT_MODE = size.X < size.Y
			layoutGestureArea(PORTRAIT_MODE)
			self.DefaultZoom = PORTRAIT_MODE and PORTRAIT_DEFAULT_ZOOM or LANDSCAPE_DEFAULT_ZOOM
			self._CameraChangedConn = newCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				size = newCamera.ViewportSize
				PORTRAIT_MODE = size.X < size.Y
				layoutGestureArea(PORTRAIT_MODE)
				self.DefaultZoom = PORTRAIT_MODE and PORTRAIT_DEFAULT_ZOOM or LANDSCAPE_DEFAULT_ZOOM
			end)
		end
	end
	return nil
end


function CameraController:GetShiftLock(): boolean
	return ShiftLockController:IsShiftLocked()
end

function CameraController:GetHumanoid(): Humanoid?
	local player = PlayersService.LocalPlayer
	return findPlayerHumanoid(player)
end

function CameraController:GetHumanoidRootPart(): BasePart?
	local humanoid = self:GetHumanoid()
	return humanoid and (humanoid :: any).Torso
end

function CameraController:_GetRenderCFrame(part: BasePart): CFrame
	return getRenderCFrame(part)
end

-- HumanoidRootPart when alive, Head part when dead
function CameraController:_GetHumanoidPartToFollow(humanoid: Humanoid, humanoidStateType: Enum.HumanoidStateType): BasePart
	if humanoidStateType == STATE_DEAD then
		local character = humanoid.Parent
		if character then
			return character:FindFirstChild("Head") or (humanoid :: any).Torso
		else
			return (humanoid :: any).Torso
		end
	else
		return (humanoid :: any).Torso
	end
end

function CameraController:GetSubjectPosition(): Vector3?
	local result: Vector3? = nil
	local camera = workspace.CurrentCamera
	local cameraSubject: Instance = if camera then camera.CameraSubject else nil
	if cameraSubject then
		if cameraSubject:IsA("Humanoid") then
			local humanoidStateType = cameraSubject:GetState()
			if VRService.VREnabled and humanoidStateType == STATE_DEAD and cameraSubject == self._LastSubject then
				result = self._LastSubjectPosition
			else
				local humanoidRootPart = self:_GetHumanoidPartToFollow(cameraSubject, humanoidStateType)
				if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
					local subjectCFrame = getRenderCFrame(humanoidRootPart)
					local heightOffset = ZERO_VECTOR3
					if humanoidStateType ~= STATE_DEAD then
						heightOffset = cameraSubject.RigType == Enum.HumanoidRigType.R15 and self.R15HeadHeight
							or HEAD_OFFSET
					end

					if PORTRAIT_MODE then
						heightOffset = heightOffset + Vector3.new(0, PORTRAIT_MODE_CAMERA_OFFSET, 0)
					end

					result = subjectCFrame.Position
						+ subjectCFrame:VectorToWorldSpace(heightOffset + cameraSubject.CameraOffset)
				end
			end
		elseif cameraSubject:IsA("VehicleSeat") then
			local subjectCFrame = getRenderCFrame(cameraSubject)
			local offset = SEAT_OFFSET
			if VRService.VREnabled then
				offset = VR_SEAT_OFFSET
			end
			result = subjectCFrame.Position + subjectCFrame:VectorToWorldSpace(offset)
		elseif cameraSubject:IsA("SkateboardPlatform" :: any) then
			assert(cameraSubject:IsA("BasePart"))
			local subjectCFrame = getRenderCFrame(cameraSubject)
			result = subjectCFrame.Position + SEAT_OFFSET
		elseif cameraSubject:IsA("BasePart") then
			assert(cameraSubject:IsA("BasePart"))
			local subjectCFrame = getRenderCFrame(cameraSubject)
			result = subjectCFrame.Position
		elseif cameraSubject:IsA("Model") then
			result = (cameraSubject :: any):GetModelCFrame().Position
		end
	end
	self._LastSubject = cameraSubject
	self._LastSubjectPosition = result
	return result
end

function CameraController:ResetCameraLook() 
	return nil
end

function CameraController:GetCameraLook(): Vector3
	return if workspace.CurrentCamera then workspace.CurrentCamera.CoordinateFrame.LookVector else Vector3.new(0, 0, 1)
end

function CameraController:GetCameraZoom(): number
	if self._CurrentZoom == nil then
		local player = PlayersService.LocalPlayer
		self._CurrentZoom = if player then math.clamp(self.DefaultZoom, player.CameraMinZoomDistance, player.CameraMaxZoomDistance) else self.DefaultZoom
	end
	assert(self._CurrentZoom ~= nil)
	return self._CurrentZoom
end

function CameraController:GetCameraActualZoom(): number
	local camera = workspace.CurrentCamera
	if camera then
		return (camera.CoordinateFrame.Position - camera.Focus.Position).Magnitude
	end
	error("Bad camera")
end

function CameraController:GetCameraHeight(): number
	if VRService.VREnabled and not self:IsInFirstPerson() then
		local zoom = self:GetCameraZoom()
		return math.sin(VR_ANGLE) * zoom
	end
	return 0
end

function CameraController:ViewSizeX(): number
	local result = 1024
	local camera = workspace.CurrentCamera
	if camera then
		result = camera.ViewportSize.X
	end
	return result
end

function CameraController:ViewSizeY(): number
	local result = 768
	local camera = workspace.CurrentCamera
	if camera then
		result = camera.ViewportSize.Y
	end
	return result
end


function CameraController:ScreenTranslationToAngle(translationVector: Vector2): Vector2
	local screenX = self:ViewSizeX()
	local screenY = self:ViewSizeY()
	local xTheta = (translationVector.X / screenX)
	local yTheta = (translationVector.Y / screenY)
	return Vector2.new(xTheta, yTheta)
end

function CameraController:MouseTranslationToAngle(translationVector: Vector2)
	local xTheta = (translationVector.X / 1920)
	local yTheta = (translationVector.Y / 1200)
	return Vector2.new(xTheta, yTheta)
end

function CameraController:RotateVector(startVector: Vector3, xyRotateVector: Vector2): (Vector3, Vector2)
	local startCFrame = CFrame.new(ZERO_VECTOR3, startVector)
	local resultLookVector = (CFrame.Angles(0, -xyRotateVector.X, 0) * startCFrame * CFrame.Angles(
		-xyRotateVector.Y,
		0,
		0
	)).LookVector
	return resultLookVector, Vector2.new(xyRotateVector.X, xyRotateVector.Y)
end

function CameraController:RotateCamera(startLook: Vector3, xyRotateVector: Vector2): (Vector3, Vector2)
	if VRService.VREnabled then
		local yawRotatedVector
		yawRotatedVector, xyRotateVector = self:RotateVector(startLook, Vector2.new(xyRotateVector.X, 0))
		return Vector3.new(yawRotatedVector.X, 0, yawRotatedVector.Z).Unit, xyRotateVector
	else
		local startVertical = math.asin(startLook.Y)
		local yTheta = math.clamp(xyRotateVector.Y, -MAX_Y + startVertical, -MIN_Y + startVertical)
		return self:RotateVector(startLook, Vector2.new(xyRotateVector.X, yTheta))
	end
end

function CameraController:IsInFirstPerson(): boolean
	return self._IsInFirstPerson
end

-- there are several cases to consider based on the state of input and camera rotation mode
function CameraController:UpdateMouseBehavior()
	-- first time transition to first person mode or shiftlock
	local camera = workspace.CurrentCamera
	if camera.CameraType == Enum.CameraType.Scriptable then
		return
	end

	if self._IsInFirstPerson or self:GetShiftLock() then
		pcall(function()
			Settings.GameSettings.RotationType = Enum.RotationType.CameraRelative
		end)
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
	else
		pcall(function()
			Settings.GameSettings.RotationType = Enum.RotationType.MovementRelative
		end)
		if self._IsRightMouseDown or self._IsMiddleMouseDown then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		else
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end
	return nil
end

function CameraController:ZoomCamera(desiredZoom: number): number
	local player = PlayersService.LocalPlayer
	if player then
		if player.CameraMode == Enum.CameraMode.LockFirstPerson then
			self._CurrentZoom = 0
		else
			self._CurrentZoom = math.clamp(desiredZoom, player.CameraMinZoomDistance, player.CameraMaxZoomDistance)
		end
	end

	self._IsInFirstPerson = self:GetCameraZoom() < 2

	ShiftLockController:SetIsInFirstPerson(self._IsInFirstPerson)
	-- set mouse behavior
	self:UpdateMouseBehavior()
	return self:GetCameraZoom()
end

function CameraController:RK4Integrator(position: number, velocity: number, t: number): (number, number)
	local direction = velocity < 0 and -1 or 1
	local function acceleration(p: number, v: number)
		local accel = direction * math.max(1, (p / 3.3) + 0.5)
		return accel
	end

	local p1 = position
	local v1 = velocity
	local a1 = acceleration(p1, v1)
	local p2 = p1 + v1 * (t / 2)
	local v2 = v1 + a1 * (t / 2)
	local a2 = acceleration(p2, v2)
	local p3 = p1 + v2 * (t / 2)
	local v3 = v1 + a2 * (t / 2)
	local a3 = acceleration(p3, v3)
	local p4 = p1 + v3 * t
	local v4 = v1 + a3 * t
	local a4 = acceleration(p4, v4)

	local positionResult = position + (v1 + 2 * v2 + 2 * v3 + v4) * (t / 6)
	local velocityResult = velocity + (a1 + 2 * a2 + 2 * a3 + a4) * (t / 6)
	return positionResult, velocityResult
end

function CameraController:ZoomCameraBy(zoomScale: number): number
	local zoom = self:GetCameraActualZoom()

	if zoom then
		-- Can break into more steps to get more accurate integration
		zoom = self:RK4Integrator(zoom, zoomScale, 1)
		self:ZoomCamera(zoom)
	end
	return self:GetCameraZoom()
end

function CameraController:ZoomCameraFixedBy(zoomIncrement)
	return self:ZoomCamera(self:GetCameraZoom() + zoomIncrement)
end

function CameraController:Update()
	return nil
end

----- VR STUFF ------
function CameraController:ApplyVRTransform()
	if not VRService.VREnabled then
		return
	end
	--we only want self to happen in first person VR
	local player = PlayersService.LocalPlayer
	if
		not (
			player
			and player.Character
			and player.Character:FindFirstChild("HumanoidRootPart")
			and player.Character.HumanoidRootPart:FindFirstChild("RootJoint")
		)
	then
		return
	end

	local camera = workspace.CurrentCamera
	local cameraSubject = camera.CameraSubject
	local isInVehicle = cameraSubject and cameraSubject:IsA("VehicleSeat")

	if self:IsInFirstPerson() and not isInVehicle then
		local vrFrame = VRService:GetUserCFrame(Enum.UserCFrame.Head)
		local vrRotation = vrFrame - vrFrame.Position
		local rootJoint = player.Character.HumanoidRootPart.RootJoint
		rootJoint.C0 = CFrame.new(vrRotation:vectorToObjectSpace(vrFrame.Position))
			* CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	else
		local rootJoint = player.Character.HumanoidRootPart.RootJoint
		rootJoint.C0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	end
	return nil
end


function CameraController:ShouldUseVRRotation(): boolean
	if not VRService.VREnabled then
		return false
	end
	if not self._VRRotationIntensityExists then
		assert(self._LastVrRotationCheck ~= nil)
		if tick() - self._LastVrRotationCheck < 1 then
			return false
		end
	end

	local success, vrRotationIntensity = pcall(function()
		return StarterGui:GetCore("VRRotationIntensity")
	end)
	self._VRRotationIntensityExists = success and vrRotationIntensity ~= nil
	self._LastVrRotationCheck = tick()

	return success and vrRotationIntensity ~= nil and vrRotationIntensity ~= "Smooth"
end

function CameraController:GetVRRotationInput(): Vector2
	local vrRotateSum = ZERO_VECTOR2

	local vrRotationIntensity = StarterGui:GetCore("VRRotationIntensity")

	local vrGamepadRotation = self.GamepadPanningCamera or ZERO_VECTOR2
	local delayExpired = (tick() - self._LastVRRotation) >= self:GetRepeatDelayValue(vrRotationIntensity)

	if math.abs(vrGamepadRotation.X) >= self:GetActivateValue() then
		if delayExpired or not self._VRRotateKeyCooldown[Enum.KeyCode.Thumbstick2] then
			local sign = 1
			if vrGamepadRotation.X < 0 then
				sign = -1
			end
			vrRotateSum = vrRotateSum + self:GetRotateAmountValue(vrRotationIntensity) * sign
			self._VRRotateKeyCooldown[Enum.KeyCode.Thumbstick2] = true
		end
	elseif math.abs(vrGamepadRotation.X) < self:GetActivateValue() - 0.1 then
		self._VRRotateKeyCooldown[Enum.KeyCode.Thumbstick2] = nil
	end
	if self.TurningLeft then
		if delayExpired or not self._VRRotateKeyCooldown[Enum.KeyCode.Left] then
			vrRotateSum = vrRotateSum - self:GetRotateAmountValue(vrRotationIntensity)
			self._VRRotateKeyCooldown[Enum.KeyCode.Left] = true
		end
	else
		self._VRRotateKeyCooldown[Enum.KeyCode.Left] = nil
	end
	if self.TurningRight then
		if delayExpired or not self._VRRotateKeyCooldown[Enum.KeyCode.Right] then
			vrRotateSum = vrRotateSum + self:GetRotateAmountValue(vrRotationIntensity)
			self._VRRotateKeyCooldown[Enum.KeyCode.Right] = true
		end
	else
		self._VRRotateKeyCooldown[Enum.KeyCode.Right] = nil
	end

	if vrRotateSum ~= ZERO_VECTOR2 then
		self._LastVRRotation = tick()
	end

	return vrRotateSum
end

function CameraController:UpdateGamepad(): Vector2
	local gamepadPan = self._GamepadPanningCamera
	if gamepadPan and (hasGameLoaded or not VRService.VREnabled) then
		gamepadPan = gamepadLinearToCurve(gamepadPan)
		local currentTime = tick()
		if gamepadPan.X ~= 0 or gamepadPan.Y ~= 0 then
			self.UserPanningTheCamera = true
		elseif gamepadPan == ZERO_VECTOR2 then
			self._LastThumbstickRotate = nil
			if self._LastThumbstickPos == ZERO_VECTOR2 then
				self._CurrentSpeed = 0
			end
		end

		local finalConstant = 0

		if self._LastThumbstickRotate then
			if VRService.VREnabled then
				self._CurrentSpeed = self._VRMaxSpeed
			else
				local elapsedTime = (currentTime - self._LastThumbstickRotate) * 10
				self._CurrentSpeed = self._CurrentSpeed + (self._MaxSpeed * ((elapsedTime * elapsedTime) / self._NumOfSeconds))

				if self._CurrentSpeed > self._MaxSpeed then
					self._CurrentSpeed = self._MaxSpeed
				end

				if self._LastVelocity then
					local velocity = (gamepadPan - self._LastThumbstickPos) / (currentTime - self._LastThumbstickRotate)
					local velocityDeltaMag = (velocity - self._LastVelocity).Magnitude

					if velocityDeltaMag > 12 then
						self._CurrentSpeed = self._CurrentSpeed * (20 / velocityDeltaMag)
						if self._CurrentSpeed > self._MaxSpeed then
							self._CurrentSpeed = self._MaxSpeed
						end
					end
				end
			end

			local success, gamepadCameraSensitivity = pcall(function()
				return Settings.GameSettings.GamepadCameraSensitivity
			end)
			finalConstant = success and (gamepadCameraSensitivity * self._CurrentSpeed) or self._CurrentSpeed
			self._LastVelocity = (gamepadPan - self._LastThumbstickPos) / (currentTime - self._LastThumbstickRotate)
		end

		self._LastThumbstickPos = gamepadPan
		self._LastThumbstickRotate = currentTime

		return Vector2.new(
			gamepadPan.X * finalConstant,
			gamepadPan.Y * finalConstant * self._YSensitivity * Settings.GameSettings:GetCameraYInvertValue()
		)
	end

	return ZERO_VECTOR2
end

function CameraController:_CancelCameraFreeze(keepConstraints: boolean)
	if not keepConstraints then
		self._CameraTranslationConstraints =
			Vector3.new(self._CameraTranslationConstraints.X, 1, self._CameraTranslationConstraints.Z)
	end
	if self._CameraFrozen then
		self._TrackingHumanoid = nil
		self._CameraFrozen = false
	end
	return nil
end

function CameraController:_StartCameraFreeze(subjectPosition: Vector3, humanoidToTrack: Humanoid)
	if not self._CameraFrozen then
		self._HumanoidJumpOrigin = subjectPosition
		self._TrackingHumanoid = humanoidToTrack
		self._CameraTranslationConstraints =
			Vector3.new(self._CameraTranslationConstraints.X, 0, self._CameraTranslationConstraints.Z)
		self._CameraFrozen = true
	end
	return nil
end

function CameraController:_RescaleCameraOffset(newScaleFactor: number)
	self.R15HeadHeight = R15_HEAD_OFFSET * newScaleFactor
	return nil
end

function CameraController:_OnHumanoidSubjectChildAdded(child: Instance)
	if child.Name == "BodyHeightScale" and child:IsA("NumberValue") then
		if self._HeightScaleChangedConn then
			self._HeightScaleChangedConn:Disconnect()
		end
		self._HeightScaleChangedConn = child.Changed:Connect(function()
			self:_RescaleCameraOffset(child.Value)
		end)
		self:_RescaleCameraOffset(child.Value)
	end
	return nil
end

function CameraController:_OnHumanoidSubjectChildRemoved(child: Instance)
	if child.Name == "BodyHeightScale" then
		self:_RescaleCameraOffset(1)
		if self._HeightScaleChangedConn then
			self._HeightScaleChangedConn:Disconnect()
			self._HeightScaleChangedConn = nil
		end
	end
	return nil
end

function CameraController:_OnNewCameraSubject()
	if self._SubjectStateChangedConn then
		self._SubjectStateChangedConn:Disconnect()
		self._SubjectStateChangedConn = nil
	end
	if self._HumanoidChildAddedConn then
		self._HumanoidChildAddedConn:Disconnect()
		self._HumanoidChildAddedConn = nil
	end
	if self._HumanoidChildRemovedConn then
		self._HumanoidChildRemovedConn:Disconnect()
		self._HumanoidChildRemovedConn = nil
	end
	if self._HeightScaleChangedConn then
		self._HeightScaleChangedConn:Disconnect()
		self._HeightScaleChangedConn = nil
	end

	local humanoid = workspace.CurrentCamera and workspace.CurrentCamera.CameraSubject
	if self._TrackingHumanoid ~= humanoid then
		self:_CancelCameraFreeze(false)
	end
	if humanoid and humanoid:IsA("Humanoid") then
		self._HumanoidChildAddedConn = humanoid.ChildAdded:Connect(function(child: Instance)
			self:_OnHumanoidSubjectChildAdded(child)
		end)
		self._HumanoidChildRemovedConn = humanoid.ChildRemoved:Connect(function(child: Instance)
			self:_OnHumanoidSubjectChildRemoved(child)
		end)
		for _, child: Instance in ipairs(humanoid:GetChildren()) do
			self:_OnHumanoidSubjectChildAdded(child)
		end

		self._SubjectStateChangedConn = humanoid.StateChanged:Connect(function(oldState: Enum.HumanoidStateType, newState: Enum.HumanoidStateType)
			if
				VRService.VREnabled
				and newState == Enum.HumanoidStateType.Jumping
				and not self:IsInFirstPerson()
			then
				local position = self:GetSubjectPosition()
				assert(position ~= nil)
				self:_StartCameraFreeze(position, humanoid)
			elseif newState ~= Enum.HumanoidStateType.Jumping and newState ~= Enum.HumanoidStateType.Freefall then
				self:_CancelCameraFreeze(true)
			end
		end)
	end
	return nil
end

function CameraController:_OnCurrentCameraChanged()
	if self._CameraSubjectChangedConn then
		self._CameraSubjectChangedConn:Disconnect()
		self._CameraSubjectChangedConn = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		self._CameraSubjectChangedConn = camera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
				self:_OnNewCameraSubject()
			end)
		self:_OnNewCameraSubject()
	end
	return nil
end

function CameraController:GetVRFocus(subjectPosition: Vector3, timeDelta: number): CFrame
	local newFocus = nil

	local lastFocus = self.LastCameraFocus or subjectPosition
	if not self._CameraFrozen then
		self._CameraTranslationConstraints = Vector3.new(
			self._CameraTranslationConstraints.X,
			math.min(1, self._CameraTranslationConstraints.Y + 0.42 * timeDelta),
			self._CameraTranslationConstraints.Z
		)
	end
	if self._CameraFrozen and self._HumanoidJumpOrigin and self._HumanoidJumpOrigin.Y > lastFocus.Y then
		newFocus = CFrame.new(
			Vector3.new(
				subjectPosition.X,
				math.min(self._HumanoidJumpOrigin.Y, lastFocus.Y + 5 * timeDelta),
				subjectPosition.Z
			)
		)
	else
		newFocus = CFrame.new(
			Vector3.new(subjectPosition.X, lastFocus.Y, subjectPosition.Z)
				:Lerp(subjectPosition, self._CameraTranslationConstraints.Y)
		)
	end

	if self._CameraFrozen then
		-- No longer in 3rd person
		if self:IsInFirstPerson() then -- not VRService.VREnabled
			self:_CancelCameraFreeze(false)
		end
		-- This case you jumped off a cliff and want to keep your character in view
		-- 0.5 is to fix floating point error when not jumping off cliffs
		if self._HumanoidJumpOrigin and subjectPosition.Y < (self._HumanoidJumpOrigin.Y - 0.5) then
			self:_CancelCameraFreeze(false)
		end
	end

	return newFocus
end

function CameraController:_OnTouchBegan(input: InputObject, processed: boolean)
	--If self._IsDynamicThumbstickEnabled, then only process TouchBegan event if it starts in gestureArea

	-- local dtFrame = self:_GetDynamicThumbstickFrame()

	local isDynamicThumbstickUsingThisInput = false
	if self._IsDynamicThumbstickEnabled then
		local ControlScript = CameraScript.Parent:FindFirstChild("ControlScript")
		if ControlScript then
			local MasterControl = ControlScript:FindFirstChild("MasterControl")
			if MasterControl then
				local dynamicInputObject = getDynamicInputObject()
				isDynamicThumbstickUsingThisInput = (dynamicInputObject == input)
			end
		end
	end

	if not isDynamicThumbstickUsingThisInput then
		self._FingerTouches[input] = processed
		if not processed then
			self._InputStartPositions[input] = input.Position
			self._InputStartTimes[input] = tick()
			self._NumUnsunkTouches += 1
		end
	end
	return nil
end

function CameraController:_OnTouchChanged(input: InputObject, processed: boolean)
	if self._FingerTouches[input] == nil then
		if self._IsDynamicThumbstickEnabled then
			return
		end
		self._FingerTouches[input] = processed
		if not processed then
			self._NumUnsunkTouches = self._NumUnsunkTouches + 1
		end
	end

	if self._NumUnsunkTouches == 1 then
		if self._FingerTouches[input] == false then
			self._PanBeginLook = self._PanBeginLook or self:GetCameraLook()
			self._StartPos = self._StartPos or input.Position
			self._LastPos = self._LastPos or self._StartPos
			self.UserPanningTheCamera = true
			assert(self._LastPos ~= nil)
			local delta = input.Position - self._LastPos
			
			local flatDelta = Vector2.new(delta.X, delta.Y * Settings.GameSettings:GetCameraYInvertValue())

			if self._PanEnabled then
				local desiredXYVector = self:ScreenTranslationToAngle(flatDelta) * TOUCH_SENSITIVTY
				self.RotateInput = self.RotateInput + desiredXYVector
			end

			self._LastPos = input.Position
		end
	else
		self._PanBeginLook = nil
		self._StartPos = nil
		self._LastPos = nil
		self.UserPanningTheCamera = false
	end
	if self._NumUnsunkTouches == 2 then
		local unsunkTouches = {}
		for touch, wasSunk in pairs(self._FingerTouches) do
			if not wasSunk then
				table.insert(unsunkTouches, touch)
			end
		end
		if #unsunkTouches == 2 then
			local difference = (unsunkTouches[1].Position - unsunkTouches[2].Position).Magnitude
			if self._StartingDiff and self._PinchBeginZoom then
				local scale = difference / math.max(0.01, self._StartingDiff)
				local clampedScale = math.clamp(scale, 0.1, 10)
				if self._ZoomEnabled then
					self:ZoomCamera(self._PinchBeginZoom / clampedScale)
				end
			else
				self._StartingDiff = difference
				self._PinchBeginZoom = self:GetCameraActualZoom()
			end
		end
	else
		self._StartingDiff = nil
		self._PinchBeginZoom = nil
	end
	return nil
end

function CameraController:_CalcLookBehindRotateInput(torso: BasePart): Vector2
	if torso then
		local newDesiredLook = (torso.CFrame.LookVector - Vector3.new(
			0,
			math.sin(math.rad(DEFAULT_CAMERA_ANGLE)), 
			0
		)).Unit
		local horizontalShift = findAngleBetweenXZVectors(newDesiredLook, self:GetCameraLook())
		local vertShift = math.asin(self:GetCameraLook().Y) - math.asin(newDesiredLook.Y)
		if not isFinite(horizontalShift) then
			horizontalShift = 0
		end
		if not isFinite(vertShift) then
			vertShift = 0
		end

		return Vector2.new(horizontalShift, vertShift)
	end
	error("Bad torso")
end

function CameraController:_IsTouchTap(input: InputObject): boolean
	-- We can't make the assumption that the input exists in the self._InputStartPositions because we may have switched from a different camera type.
	if self._InputStartPositions[input] then
		local posDelta = (self._InputStartPositions[input] - input.Position).Magnitude
		if posDelta < MAX_TAP_POS_DELTA then
			local timeDelta = self._InputStartTimes[input] - tick()
			if timeDelta < MAX_TAP_TIME_DELTA then
				return true
			end
		end
	end
	return false
end

function CameraController:_OnTouchEnded(input: InputObject, processed: boolean)
	if self._FingerTouches[input] == false then
		if self._NumUnsunkTouches == 1 then
			self._PanBeginLook = nil
			self._StartPos = nil
			self._LastPos = nil
			self.UserPanningTheCamera = false
		elseif self._NumUnsunkTouches == 2 then
			self._StartingDiff = nil
			self._PinchBeginZoom = nil
		end
	end

	if self._FingerTouches[input] ~= nil and self._FingerTouches[input] == false then
		self._NumUnsunkTouches = self._NumUnsunkTouches - 1
	end
	self._FingerTouches[input] = nil
	self._InputStartPositions[input] = nil
	self._InputStartTimes[input] = nil
	return nil
end

function CameraController:_OnMousePanButtonPressed(input: InputObject, processed: boolean)
	if processed then
		return
	end
	self:UpdateMouseBehavior()
	self._PanBeginLook = self._PanBeginLook or self:GetCameraLook()
	self._StartPos = self._StartPos or input.Position
	self._LastPos = self._LastPos or self._StartPos
	self.UserPanningTheCamera = true
	return nil
end

function CameraController:_OnMousePanButtonReleased(input: InputObject?, processed: boolean?)
	self:UpdateMouseBehavior()
	if not (self._IsRightMouseDown or self._IsMiddleMouseDown) then
		self._PanBeginLook = nil
		self._StartPos = nil
		self._LastPos = nil
		self.UserPanningTheCamera = false
	end
	return nil
end

function CameraController:_OnMouse2Down(input: InputObject, processed: boolean)
	if processed then
		return
	end

	self._IsRightMouseDown = true
	self:_OnMousePanButtonPressed(input, processed)
	return nil
end

function CameraController:_OnMouse2Up(input: InputObject, processed: boolean)
	self._IsRightMouseDown = false
	self:_OnMousePanButtonReleased(input, processed)
	return nil
end

function CameraController:_OnMouse3Down(input: InputObject, processed: boolean)
	if processed then
		return
	end

	self._IsMiddleMouseDown = true
	self:_OnMousePanButtonPressed(input, processed)
	return nil
end

function CameraController:_OnMouse3Up(input: InputObject, processed: boolean)
	self._IsMiddleMouseDown = false
	self:_OnMousePanButtonReleased(input, processed)
	return nil
end

function CameraController:_OnMouseMoved(input: InputObject, processed: boolean)
	if not hasGameLoaded and VRService.VREnabled then
		return
	end

	local inputDelta3 = input.Delta
	local inputDelta = Vector2.new(inputDelta3.X, inputDelta3.Y * Settings.GameSettings:GetCameraYInvertValue())

	if self._StartPos and self._LastPos and self._PanBeginLook then
		local currPos = self._LastPos + input.Delta
		if self._PanEnabled then
			local desiredXYVector = self:MouseTranslationToAngle(inputDelta) * MOUSE_SENSITIVITY
			self.RotateInput = self.RotateInput + desiredXYVector
		end
		self._LastPos = currPos
	elseif self:IsInFirstPerson() or self:GetShiftLock() then
		if self._PanEnabled then
			local desiredXYVector = self:MouseTranslationToAngle(inputDelta) * MOUSE_SENSITIVITY
			self.RotateInput = self.RotateInput + desiredXYVector
		end
	end
	return nil
end

function CameraController:_OnMouseWheel(input: InputObject, processed: boolean)
	if not hasGameLoaded and VRService.VREnabled then
		return
	end
	if not processed then
		if self._ZoomEnabled then
			self:ZoomCameraBy(math.clamp(-input.Position.Z, -1, 1) * 1.4)
		end
	end
	return nil
end


function CameraController:_RotateVectorByAngleAndRound(camLook: Vector3, rotateAngle: number, roundAmount: number): number
	if camLook ~= ZERO_VECTOR3 then
		camLook = camLook.Unit
		local currAngle = math.atan2(camLook.Z, camLook.X)
		local newAngle = math.floor(((math.atan2(camLook.Z, camLook.X) + rotateAngle) / roundAmount)+0.5) * roundAmount
		return newAngle - currAngle
	end
	return 0
end

function CameraController:_OnKeyDown(input: InputObject, processed: boolean)
	if not hasGameLoaded and VRService.VREnabled then
		return
	end
	if processed then
		return
	end
	if self._ZoomEnabled then
		if input.KeyCode == Enum.KeyCode.I then
			self:ZoomCameraBy(-5)
		elseif input.KeyCode == Enum.KeyCode.O then
			self:ZoomCameraBy(5)
		end
	end
	if self._PanBeginLook == nil and self._KeyPanEnabled then
		if input.KeyCode == Enum.KeyCode.Left then
			self.TurningLeft = true
		elseif input.KeyCode == Enum.KeyCode.Right then
			self.TurningRight = true
		elseif input.KeyCode == Enum.KeyCode.Comma then
			local angle = self:_RotateVectorByAngleAndRound(
				self:GetCameraLook() * Vector3.new(1, 0, 1),
				-QUARTER_PI * (3 / 4),
				QUARTER_PI
			)
			if angle ~= 0 then
				self.RotateInput = self.RotateInput + Vector2.new(angle, 0)
				self.LastUserPanCamera = tick()
				self.LastCameraTransform = nil
			end
		elseif input.KeyCode == Enum.KeyCode.Period then
			local angle = self:_RotateVectorByAngleAndRound(
				self:GetCameraLook() * Vector3.new(1, 0, 1),
				QUARTER_PI * (3 / 4),
				QUARTER_PI
			)
			if angle ~= 0 then
				self.RotateInput = self.RotateInput + Vector2.new(angle, 0)
				self.LastUserPanCamera = tick()
				self.LastCameraTransform = nil
			end
		elseif input.KeyCode == Enum.KeyCode.PageUp then
			--elseif input.KeyCode == Enum.KeyCode.Home then
			self.RotateInput = self.RotateInput + Vector2.new(0, math.rad(15))
			self.LastCameraTransform = nil
		elseif input.KeyCode == Enum.KeyCode.PageDown then
			--elseif input.KeyCode == Enum.KeyCode.End then
			self.RotateInput = self.RotateInput + Vector2.new(0, math.rad(-15))
			self.LastCameraTransform = nil
		end
	end
	return nil
end

function CameraController:_OnKeyUp(input: InputObject, processed: boolean)
	if input.KeyCode == Enum.KeyCode.Left then
		self.TurningLeft = false
	elseif input.KeyCode == Enum.KeyCode.Right then
		self.TurningRight = false
	end
	return nil
end

function CameraController:_OnWindowFocusReleased()
	self:ResetInputStates()
	return nil
end

function CameraController:DisconnectInputEvents()
	if self._InputBeganConn then
		self._InputBeganConn:Disconnect()
		self._InputBeganConn = nil
	end
	if self._InputChangedConn then
		self._InputChangedConn:Disconnect()
		self._InputChangedConn = nil
	end
	if self._InputEndedConn then
		self._InputEndedConn:Disconnect()
		self._InputEndedConn = nil
	end
	if self._WindowUnfocusConn then
		self._WindowUnfocusConn:Disconnect()
		self._WindowUnfocusConn = nil
	end
	if self._MenuOpenedConn then
		self._MenuOpenedConn:Disconnect()
		self._MenuOpenedConn = nil
	end
	if self._ShiftLockToggleConn then
		self._ShiftLockToggleConn:Disconnect()
		self._ShiftLockToggleConn = nil
	end
	if self._GamepadConnectedConn then
		self._GamepadConnectedConn:Disconnect()
		self._GamepadConnectedConn = nil
	end
	if self._GamepadDisconnectedConn then
		self._GamepadDisconnectedConn:Disconnect()
		self._GamepadDisconnectedConn = nil
	end
	if self._SubjectStateChangedConn then
		self._SubjectStateChangedConn:Disconnect()
		self._SubjectStateChangedConn = nil
	end
	if self._WorkspaceChangedConn then
		self._WorkspaceChangedConn:Disconnect()
		self._WorkspaceChangedConn = nil
	end
	if self._TouchActivateConn then
		self._TouchActivateConn:Disconnect()
		self._TouchActivateConn = nil
	end

	self.TurningLeft = false
	self.TurningRight = false
	self.LastCameraTransform = nil
	self.LastSubjectCFrame = nil
	self.UserPanningTheCamera = false
	self.RotateInput = Vector2.new()
	self._GamepadPanningCamera = Vector2.new(0, 0)

	-- Reset input states
	self._StartPos = nil
	self._LastPos = nil
	self._PanBeginLook = nil
	self._IsRightMouseDown = false
	self._IsMiddleMouseDown = false

	self._FingerTouches = {}
	self._NumUnsunkTouches = 0

	self._StartingDiff = nil
	self._PinchBeginZoom = nil

	-- Unlock mouse for example if right mouse button was being held down
	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	return nil
end

function CameraController:ResetInputStates()
	self._IsRightMouseDown = false
	self._IsMiddleMouseDown = false
	self.TurningRight = false
	self.TurningLeft = false
	self:_OnMousePanButtonReleased() -- self function doesn't seem to actually need parameters

	if UserInputService.TouchEnabled then
		--[[menu opening was causing serious touch issues
		self should disable all active touch events if
		they're active when menu opens.]]
		for inputObject, value in pairs(self._FingerTouches) do
			self._FingerTouches[inputObject] = nil
		end
		self._PanBeginLook = nil
		self._StartPos = nil
		self._LastPos = nil
		self.UserPanningTheCamera = false
		self._StartingDiff = nil
		self._PinchBeginZoom = nil
		self._NumUnsunkTouches = 0
	end
	return nil
end


function CameraController:_GetGamepadPan(name: string, state: Enum.UserInputState, input: InputObject)
	if state == Enum.UserInputState.Cancel then
		self._GamepadPanningCamera = ZERO_VECTOR2
		return
	end

	if input.UserInputType == self._ActiveGamepad and input.KeyCode == Enum.KeyCode.Thumbstick2 then
		local inputVector = Vector2.new(input.Position.X, -input.Position.Y)
		if inputVector.Magnitude > THUMBSTICK_DEADZONE then
			self._GamepadPanningCamera = Vector2.new(input.Position.X, -input.Position.Y)
		else
			self._GamepadPanningCamera = ZERO_VECTOR2
		end
	end
	return nil
end

function CameraController:_DoGamepadZoom(name: string, state: Enum.UserInputState, input: InputObject)
	if
		input.UserInputType == self._ActiveGamepad
		and input.KeyCode == Enum.KeyCode.ButtonR3
		and state == Enum.UserInputState.Begin
	then
		if self._ZoomEnabled then
			if self:GetCameraZoom() > 0.5 then
				self:ZoomCamera(0)
			else
				self:ZoomCamera(10)
			end
		end
	end
	return nil
end

function CameraController:BindGamepadInputActions()
	ContextActionService:BindAction("RootCamGamepadPan", function(name: string, state: Enum.UserInputState, input: InputObject)
		self:_GetGamepadPan(name, state, input)
	end, false, Enum.KeyCode.Thumbstick2)
	ContextActionService:BindAction("RootCamGamepadZoom", function(name: string, state: Enum.UserInputState, input: InputObject)
		self:_DoGamepadZoom(name, state, input)
	end, false, Enum.KeyCode.ButtonR3)
	return nil
end

function CameraController:ConnectInputEvents()
	self._InputBeganConn = UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then
			self:_OnTouchBegan(input, processed)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:_OnMouse2Down(input, processed)
		elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
			self:_OnMouse3Down(input, processed)
		end
		-- Keyboard
		if input.UserInputType == Enum.UserInputType.Keyboard then
			self:_OnKeyDown(input, processed)
		end
	end)

	self._InputChangedConn = UserInputService.InputChanged:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then
			self:_OnTouchChanged(input, processed)
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			self:_OnMouseMoved(input, processed)
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			self:_OnMouseWheel(input, processed)
		end
	end)

	self._InputEndedConn = UserInputService.InputEnded:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then
			self:_OnTouchEnded(input, processed)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:_OnMouse2Up(input, processed)
		elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
			self:_OnMouse3Up(input, processed)
		end
		-- Keyboard
		if input.UserInputType == Enum.UserInputType.Keyboard then
			self:_OnKeyUp(input, processed)
		end
	end)

	self._WindowUnfocusConn = UserInputService.WindowFocusReleased:Connect(function()
		self:_OnWindowFocusReleased()
	end)
	self._MenuOpenedConn = GuiService.MenuOpened:Connect(function()
		self:ResetInputStates()
	end)
	self._WorkspaceChangedConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self:_OnCurrentCameraChanged()
	end)
	if workspace.CurrentCamera then
		self:_OnCurrentCameraChanged()
	end

	self._ShiftLockToggleConn = ShiftLockController.OnShiftLockToggled.Event:Connect(function()
		self:UpdateMouseBehavior()
	end)

	self.RotateInput = Vector2.new()

	self._ActiveGamepad = nil
	local function assignActivateGamepad()
		local connectedGamepads = UserInputService:GetConnectedGamepads()
		if #connectedGamepads > 0 then
			for i = 1, #connectedGamepads do
				if self._ActiveGamepad == nil then
					self._ActiveGamepad = connectedGamepads[i]
				elseif connectedGamepads[i].Value < self._ActiveGamepad.Value then
					self._ActiveGamepad = connectedGamepads[i]
				end
			end
		end

		if self._ActiveGamepad == nil then -- nothing is connected, at least set up for gamepad1
			self._ActiveGamepad = Enum.UserInputType.Gamepad1
		end
	end

	self._GamepadConnectedConn = UserInputService.GamepadDisconnected:Connect(function(gamepadEnum)
		if self._ActiveGamepad ~= gamepadEnum then
			return
		end
		self._ActiveGamepad = nil
		assignActivateGamepad()
	end)

	self._GamepadDisconnectedConn = UserInputService.GamepadConnected:Connect(function(gamepadEnum)
		if self._ActiveGamepad == nil then
			assignActivateGamepad()
		end
	end)

	self:BindGamepadInputActions()

	assignActivateGamepad()

	-- set mouse behavior
	self:UpdateMouseBehavior()
	return nil
end

--Process self._Tweens related to tap-to-recenter and double-tap-to-zoom
--Needs to be called from specific cameras on each update
function CameraController:ProcessTweens()
	for name, tween in pairs(self._Tweens) do
		local alpha = math.min(1.0, (tick() - tween.start) / tween.duration)
		tween.to = tween.func(tween.from, tween.to, alpha)
		if math.abs(1 - alpha) < 0.0001 then
			self._Tweens[name] = nil
		end
	end
	return nil
end

function CameraController:SetEnabled(newState: boolean)
	if newState ~= self.Enabled then
		self.Enabled = newState
		if self.Enabled then
			self:ConnectInputEvents()
			self.CFrame = workspace.CurrentCamera.CFrame
		else
			self:DisconnectInputEvents()
		end
	end
	return nil
end

function CameraController:_OnCharacterAdded(player: Player, character: Model)

	local humanoid = findPlayerHumanoid(player)
	local start = tick()
	while tick() - start < 0.3 and (humanoid == nil or (humanoid :: any).Torso == nil) do
		wait()
		humanoid = findPlayerHumanoid(player)
	end

	if humanoid and (humanoid :: any).Torso and player.Character == character then
		local newDesiredLook = ((humanoid :: any).Torso.CFrame.lookVector - Vector3.new(
			0,
			math.sin(math.rad(DEFAULT_CAMERA_ANGLE)),
			0
		)).Unit
		local horizontalShift = findAngleBetweenXZVectors(newDesiredLook, self:GetCameraLook())
		local vertShift = math.asin(self:GetCameraLook().Y) - math.asin(newDesiredLook.Y)
		if not isFinite(horizontalShift) then
			horizontalShift = 0
		end
		if not isFinite(vertShift) then
			vertShift = 0
		end
		self.RotateInput = Vector2.new(horizontalShift, vertShift)

		-- reset old camera info so follow cam doesn't rotate us
		self.LastCameraTransform = nil
	end

	-- Need to wait for camera cframe to update before we zoom in
	-- Not waiting will force camera to original cframe
	wait()
	self:ZoomCamera(self.DefaultZoom)
	return nil
end

function CameraController:_OnPlayerAdded(player)
	player.Changed:Connect(function(prop)
		if self.Enabled then
			if prop == "CameraMode" or prop == "CameraMaxZoomDistance" or prop == "CameraMinZoomDistance" then
				self:ZoomCameraFixedBy(0)
			end
		end
	end)
	
	player.CharacterAdded:Connect(function(character)
		if self.Enabled or setCameraOnSpawn then
			self:_OnCharacterAdded(player, character)
			setCameraOnSpawn = false
		end
	end)
	if player.Character then
		spawn(function()
			local character: Model? = player.Character
			assert(character ~= nil)
			self:_OnCharacterAdded(player, character)
		end)
	end
	return nil
end

function CameraController:_OnGameLoaded()
	hasGameLoaded = true
	return nil
end


function CameraController:_OnDynamicThumbstickEnabled()
	if UserInputService.TouchEnabled then
		self._IsDynamicThumbstickEnabled = true
	end
	return nil
end

function CameraController:_OnDynamicThumbstickDisabled()
	self._IsDynamicThumbstickEnabled = false
	return nil
end

function CameraController:_OnGameSettingsTouchMovementModeChanged()
	if PlayersService.LocalPlayer.DevTouchMovementMode == Enum.DevTouchMovementMode.UserChoice then
		if Settings.GameSettings.TouchMovementMode.Name == "DynamicThumbstick" then
			self:_OnDynamicThumbstickEnabled()
		else
			self:_OnDynamicThumbstickDisabled()
		end
	end
	return nil
end

function CameraController:_OnDevTouchMovementModeChanged()
	if PlayersService.LocalPlayer.DevTouchMovementMode.Name == "DynamicThumbstick" then
		self:_OnDynamicThumbstickEnabled()
	else
		self:_OnGameSettingsTouchMovementModeChanged()
	end
	return nil
end

function CameraController:Destroy()
	self._Maid:Destroy()
	self:DisconnectInputEvents()
	local tabl = setmetatable(self, nil) :: any
	for k, v in pairs(tabl) do
		tabl[k] = nil
	end
	return nil
end

function CameraController.new(): CameraController
	local maid = Maid.new()

	local self: CameraController = setmetatable({
		_Maid = maid,
		R15HeadHeight = R15_HEAD_OFFSET,
		ShiftLock = false,
		Enabled = false,
		RotateInput = ZERO_VECTOR2,
		DefaultZoom = LANDSCAPE_DEFAULT_ZOOM,
		CFrame = nil,
		GamepadPanningCamera = nil,

		_VRRotateKeyCooldown = {} :: {[Enum.KeyCode]: boolean},
		_Tweens = {} :: {[string]: CameraTween},
		_FingerTouches = {} :: {[InputObject]: boolean},
		_InputStartPositions = {} :: {[InputObject]: Vector3},
		_InputStartTimes = {} :: {[InputObject]: number},

		_IsFirstPerson = false,
		_IsRightMouseDown = false,
		_IsMiddleMouseDown = false,

		_ActiveGamepad = nil :: Enum.UserInputType?,
		_LastSubject = nil :: Instance?,
		_LastSubjectPosition = Vector3.new(0, 5, 0),
		_LastVRRotation = 0,

		_IsDynamicThumbstickEnabled = false,
		_DynamicThumbstickFrame = nil :: Frame?,

		_VRRotationIntensityExists = true,
		_LastVRRotationCheck = 0,	
		_CameraTranslationConstraints = Vector3.new(1, 1, 1),
		_HumanoidJumpOrigin = nil :: Vector3?,
		_TrackingHumanoid = nil :: Humanoid?,

		_StartPos = nil,
		_LastPos = nil,
		_PanBeginLook = nil,
		_LastTapTime = nil,
	
		_NumUnsunkTouches = 0,
		
		_StartingDiff = nil,
		_PinchBeginZoom = nil,
		_CurrentZoom = nil,
		_LastThumbstickRotate = nil,
		_LastVrRotationCheck = nil :: number?,
		LastUserPanCamera = nil,

		_ZoomEnabled = true,
		_PanEnabled = true,
		_KeyPanEnabled = true,
		TurningLeft = false,
		TurningRight = false,
		UserPanningTheCamera = false,
		_IsInFirstPerson = false,
		_CameraFrozen = false,
		_VRMaxSpeed = 4,
		_NumOfSeconds = 0.7,
		_CurrentSpeed = 0,
		_MaxSpeed = 6,
		_YSensitivity = 0.65,

		_LastThumbstickPos = Vector2.new(0, 0),
		_LastVelocity = nil :: Vector3?,
		LastCameraFocus = nil :: Vector3?,
		_InputBeganConn = nil :: RBXScriptConnection?,
		_InputChangedConn = nil :: RBXScriptConnection?,
		_InputEndedConn = nil :: RBXScriptConnection?,
		_WindowUnfocusConn = nil :: RBXScriptConnection?,
		_MenuOpenedConn = nil :: RBXScriptConnection?,
		_ShiftLockToggleConn = nil :: RBXScriptConnection?,
		_GamepadConnectedConn = nil :: RBXScriptConnection?,
		_GamepadDisconnectedConn = nil :: RBXScriptConnection?,
		_TouchActivateConn = nil :: RBXScriptConnection?,
		_SubjectStateChangedConn = nil :: RBXScriptConnection?,
		_CameraSubjectChangedConn = nil :: RBXScriptConnection?,
		_WorkspaceChangedConn = nil :: RBXScriptConnection?,
		_HumanoidChildAddedConn = nil :: RBXScriptConnection?,
		_HumanoidChildRemovedConn = nil :: RBXScriptConnection?,
		_CameraChangedConn = nil :: RBXScriptConnection?,
		_WorkspaceCameraChangedConn = nil :: RBXScriptConnection?,
		_HeightScaleChangedConn = nil :: RBXScriptConnection?,

		LastCameraTransform = nil :: CFrame?,
		LastSubjectCFrame = nil :: CFrame?,

		_GamepadPanningCamera = Vector2.new(0, 0),
	}, CameraController) :: any

	self._WorkspaceCameraChangedConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self:_OnWorkspaceCameraChanged()
	end)

	if workspace.CurrentCamera then
		self:_OnWorkspaceCameraChanged()
	end

	if PlayersService.LocalPlayer then
		self:_OnPlayerAdded(PlayersService.LocalPlayer)
	end
	maid:GiveTask(PlayersService.ChildAdded:Connect(function(child)
		if child and PlayersService.LocalPlayer == child then
			self:_OnPlayerAdded(PlayersService.LocalPlayer)
		end
	end))

	spawn(function()
		if game:IsLoaded() then
			self:_OnGameLoaded()
		else
			game.Loaded:wait()
			self:_OnGameLoaded()
		end
	end)

	if PlayersService.LocalPlayer then
		maid:GiveTask(PlayersService.LocalPlayer.Changed:Connect(function(prop)
			if prop == "DevTouchMovementMode" then
				self:_OnDevTouchMovementModeChanged()
			end
		end))
		self:_OnDevTouchMovementModeChanged()
	end

	maid:GiveTask(Settings.GameSettings.Changed:Connect(function(prop)
		if prop == "TouchMovementMode" then
			self:_OnGameSettingsTouchMovementModeChanged()
		end
	end))
	self:_OnGameSettingsTouchMovementModeChanged()

	Settings.GameSettings:SetCameraYInvertVisible()
	pcall(function()
		Settings.GameSettings:SetGamepadCameraSensitivityVisible()
	end)

	return self
end

return CameraController
