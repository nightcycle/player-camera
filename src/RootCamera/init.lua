--!strict
-- Services
local PlayersService = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local VRService = game:GetService("VRService")
local Settings = UserSettings()

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


-- References
local LocalPlayer = PlayersService.LocalPlayer
local PlayerGui = nil
if LocalPlayer then
	PlayerGui = PlayersService.LocalPlayer:WaitForChild("PlayerGui")
end

-- Globals
local setCameraOnSpawn = true
local hasGameLoaded = false
local gestureArea = nil
local gestureAreaManagedByControlScript = false


local function findAngleBetweenXZVectors(vec2: Vector3, vec1: Vector3)
	return math.atan2(vec1.X * vec2.Z - vec1.Z * vec2.X, vec1.X * vec2.X + vec1.Z * vec2.Z)
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

local function isFinite(num: number): boolean
	return num == num and num ~= 1 / 0 and num ~= -1 / 0
end

local humanoidCache = {}
local function findPlayerHumanoid(player)
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
local function OnCharacterAdded(character)
	if UserInputService.TouchEnabled then
		for _, child in ipairs(LocalPlayer.Character:GetChildren()) do
			if child:IsA("Tool") then
				IsAToolEquipped = true
			end
		end
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				IsAToolEquipped = true
			end
		end)
		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				IsAToolEquipped = false
			end
		end)

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

if LocalPlayer then
	if LocalPlayer.Character ~= nil then
		OnCharacterAdded(LocalPlayer.Character)
	end
	LocalPlayer.CharacterAdded:Connect(function(character)
		OnCharacterAdded(character)
	end)
end

local function getRenderCFrame(part: BasePart): CFrame
	return (part :: any):GetRenderCFrame()
end

local CameraController = {}
CameraController.__index = CameraController

function CameraController:GetActivateValue()
	return 0.7
end

function CameraController:IsPortraitMode()
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
function CameraController:GetRepeatDelayValue(vrRotationIntensity)
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
	return humanoid and humanoid.Torso
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
			result = cameraSubject:GetModelCFrame().Position
		end
	end
	self._LastSubject = cameraSubject
	self._LastSubjectPosition = result
	return result
end

function CameraController:ResetCameraLook() 

end

function CameraController:GetCameraLook(): Vector3
	return if workspace.CurrentCamera then workspace.CurrentCamera.CoordinateFrame.LookVector else Vector3.new(0, 0, 1)
end

function CameraController:GetCameraZoom(): number
	if self._CurrentZoom == nil then
		local player = PlayersService.LocalPlayer
		self._CurrentZoom = player
				and math.clamp(this.DefaultZoom, player.CameraMinZoomDistance, player.CameraMaxZoomDistance)
			or this.DefaultZoom
	end
	return self._CurrentZoom
end

function CameraController:GetCameraActualZoom(): number
	local camera = workspace.CurrentCamera
	if camera then
		return (camera.CoordinateFrame.Position - camera.Focus.Position).Magnitude
	end
end

function CameraController:GetCameraHeight(): number
	if VRService.VREnabled and not this:IsInFirstPerson() then
		local zoom = this:GetCameraZoom()
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
	local screenX = this:ViewSizeX()
	local screenY = this:ViewSizeY()
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
end

function CameraController:ZoomCamera(desiredZoom)
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

function CameraController:ZoomCameraBy(zoomScale)
	local zoom = this:GetCameraActualZoom()

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

function CameraController:Update() end

----- VR STUFF ------
function CameraController:ApplyVRTransform()
	if not VRService.VREnabled then
		return
	end
	--we only want this to happen in first person VR
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

	if this:IsInFirstPerson() and not isInVehicle then
		local vrFrame = VRService:GetUserCFrame(Enum.UserCFrame.Head)
		local vrRotation = vrFrame - vrFrame.Position
		local rootJoint = player.Character.HumanoidRootPart.RootJoint
		rootJoint.C0 = CFrame.new(vrRotation:vectorToObjectSpace(vrFrame.Position))
			* CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	else
		local rootJoint = player.Character.HumanoidRootPart.RootJoint
		rootJoint.C0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	end
end


function CameraController:ShouldUseVRRotation()
	if not VRService.VREnabled then
		return false
	end
	if not self._VRRotationIntensityExists and tick() - self._LastVrRotationCheck < 1 then
		return false
	end

	local success, vrRotationIntensity = pcall(function()
		return StarterGui:GetCore("VRRotationIntensity")
	end)
	self._VRRotationIntensityExists = success and vrRotationIntensity ~= nil
	self._LastVrRotationCheck = tick()

	return success and vrRotationIntensity ~= nil and vrRotationIntensity ~= "Smooth"
end

function CameraController:GetVRRotationInput()
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


function CameraController:_CancelCameraFreeze(keepConstraints)
	if not keepConstraints then
		self._CameraTranslationConstraints =
			Vector3.new(self._CameraTranslationConstraints.X, 1, self._CameraTranslationConstraints.Z)
	end
	if self._CameraFrozen then
		self._TrackingHumanoid = nil
		self._CameraFrozen = false
	end
end

function CameraController:_StartCameraFreeze(subjectPosition: Vector3, humanoidToTrack: Humanoid)
	if not self._CameraFrozen then
		self._HumanoidJumpOrigin = subjectPosition
		self._TrackingHumanoid = humanoidToTrack
		self._CameraTranslationConstraints =
			Vector3.new(self._CameraTranslationConstraints.X, 0, self._CameraTranslationConstraints.Z)
		self._CameraFrozen = true
	end
end

function CameraController:_RescaleCameraOffset(newScaleFactor: Vector3)
	self.R15HeadHeight = R15_HEAD_OFFSET * newScaleFactor
end

function CameraController:_OnHumanoidSubjectChildAdded(child: Instance)
	if child.Name == "BodyHeightScale" and child:IsA("NumberValue") then
		if self._HeightScaleChangedConn then
			self._HeightScaleChangedConn:Disconnect()
		end
		self._HeightScaleChangedConn = child.Changed:Connect(function()
			self:_RescaleCameraOffset()
		end)
		self:_RescaleCameraOffset(child.Value)
	end
end

function CameraController:_OnHumanoidSubjectChildRemoved(child: Instance)
	if child.Name == "BodyHeightScale" then
		self:_RescaleCameraOffset(1)
		if self._HeightScaleChangedConn then
			self._HeightScaleChangedConn:Disconnect()
			self._HeightScaleChangedConn = nil
		end
	end
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
		self:_CancelCameraFreeze()
	end
	if humanoid and humanoid:IsA("Humanoid") then
		self._HumanoidChildAddedConn = humanoid.ChildAdded:Connect(function()
			self:_OnHumanoidSubjectChildAdded()
		end)
		self._HumanoidChildRemovedConn = humanoid.ChildRemoved:Connect(function()
			self:_OnHumanoidSubjectChildRemoved()
		end)
		for _, child: Instance in ipairs(humanoid:GetChildren()) do
			self:_OnHumanoidSubjectChildAdded(child)
		end

		self._SubjectStateChangedConn = humanoid.StateChanged:Connect(function(oldState, newState)
			if
				VRService.VREnabled
				and newState == Enum.HumanoidStateType.Jumping
				and not this:IsInFirstPerson()
			then
				self:_StartCameraFreeze(this:GetSubjectPosition(), humanoid)
			elseif newState ~= Enum.HumanoidStateType.Jumping and newState ~= Enum.HumanoidStateType.Freefall then
				self:_CancelCameraFreeze(true)
			end
		end)
	end
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
end

function CameraController:GetVRFocus(subjectPosition, timeDelta)
	local newFocus = nil

	local camera = workspace.CurrentCamera
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
				:lerp(subjectPosition, self._CameraTranslationConstraints.Y)
		)
	end

	if self._CameraFrozen then
		-- No longer in 3rd person
		if self:IsInFirstPerson() then -- not VRService.VREnabled
			cancelCameraFreeze()
		end
		-- This case you jumped off a cliff and want to keep your character in view
		-- 0.5 is to fix floating point error when not jumping off cliffs
		if self._HumanoidJumpOrigin and subjectPosition.Y < (self._HumanoidJumpOrigin.Y - 0.5) then
			cancelCameraFreeze()
		end
	end

	return newFocus
end


function CameraController:_OnTouchBegan(input, processed)
	--If self._IsDynamicThumbstickEnabled, then only process TouchBegan event if it starts in gestureArea

	local dtFrame = self:_GetDynamicThumbstickFrame()

	local isDynamicThumbstickUsingThisInput = false
	if self._IsDynamicThumbstickEnabled then
		local ControlScript = CameraScript.Parent:FindFirstChild("ControlScript")
		if ControlScript then
			local MasterControl = ControlScript:FindFirstChild("MasterControl")
			if MasterControl then
				local DynamicThumbstickModule = MasterControl:FindFirstChild("DynamicThumbstick")
				if DynamicThumbstickModule then
					DynamicThumbstickModule = require(DynamicThumbstickModule)
					local dynamicInputObject = DynamicThumbstickModule:GetInputObject()
					isDynamicThumbstickUsingThisInput = (dynamicInputObject == input)
				end
			end
		end
	end

	if not isDynamicThumbstickUsingThisInput then
		fingerTouches[input] = processed
		if not processed then
			inputStartPositions[input] = input.Position
			inputStartTimes[input] = tick()
			NumUnsunkTouches = NumUnsunkTouches + 1
		end
	end
end

function CameraController:_OnTouchChanged(input, processed)
	if fingerTouches[input] == nil then
		if self._IsDynamicThumbstickEnabled then
			return
		end
		fingerTouches[input] = processed
		if not processed then
			NumUnsunkTouches = NumUnsunkTouches + 1
		end
	end

	if NumUnsunkTouches == 1 then
		if fingerTouches[input] == false then
			panBeginLook = panBeginLook or this:GetCameraLook()
			startPos = startPos or input.Position
			lastPos = lastPos or startPos
			this.UserPanningTheCamera = true

			local delta = input.Position - lastPos

			delta = Vector2.new(delta.X, delta.Y * Settings.GameSettings:GetCameraYInvertValue())

			if this.PanEnabled then
				local desiredXYVector = this:ScreenTranslationToAngle(delta) * TOUCH_SENSITIVTY
				this.RotateInput = this.RotateInput + desiredXYVector
			end

			lastPos = input.Position
		end
	else
		panBeginLook = nil
		startPos = nil
		lastPos = nil
		this.UserPanningTheCamera = false
	end
	if NumUnsunkTouches == 2 then
		local unsunkTouches = {}
		for touch, wasSunk in pairs(fingerTouches) do
			if not wasSunk then
				table.insert(unsunkTouches, touch)
			end
		end
		if #unsunkTouches == 2 then
			local difference = (unsunkTouches[1].Position - unsunkTouches[2].Position).Magnitude
			if StartingDiff and pinchBeginZoom then
				local scale = difference / math.max(0.01, StartingDiff)
				local clampedScale = math.clamp(scale, 0.1, 10)
				if this.ZoomEnabled then
					this:ZoomCamera(pinchBeginZoom / clampedScale)
				end
			else
				StartingDiff = difference
				pinchBeginZoom = this:GetCameraActualZoom()
			end
		end
	else
		StartingDiff = nil
		pinchBeginZoom = nil
	end
end

function CameraController:_CalcLookBehindRotateInput(torso)
	if torso then
		local newDesiredLook = (torso.CFrame.lookVector - Vector3.new(
			0,
			math.sin(math.rad(DEFAULT_CAMERA_ANGLE), 0)
		)).Unit
		local horizontalShift = findAngleBetweenXZVectors(newDesiredLook, this:GetCameraLook())
		local vertShift = math.asin(this:GetCameraLook().Y) - math.asin(newDesiredLook.Y)
		if not isFinite(horizontalShift) then
			horizontalShift = 0
		end
		if not isFinite(vertShift) then
			vertShift = 0
		end

		return Vector2.new(horizontalShift, vertShift)
	end
	return nil
end

function CameraController:_IsTouchTap(input)
	-- We can't make the assumption that the input exists in the inputStartPositions because we may have switched from a different camera type.
	if inputStartPositions[input] then
		local posDelta = (inputStartPositions[input] - input.Position).Magnitude
		if posDelta < MAX_TAP_POS_DELTA then
			local timeDelta = inputStartTimes[input] - tick()
			if timeDelta < MAX_TAP_TIME_DELTA then
				return true
			end
		end
	end
	return false
end

function CameraController:_OnTouchEnded(input, processed)
	if fingerTouches[input] == false then
		if NumUnsunkTouches == 1 then
			panBeginLook = nil
			startPos = nil
			lastPos = nil
			this.UserPanningTheCamera = false
		elseif NumUnsunkTouches == 2 then
			StartingDiff = nil
			pinchBeginZoom = nil
		end
	end

	if fingerTouches[input] ~= nil and fingerTouches[input] == false then
		NumUnsunkTouches = NumUnsunkTouches - 1
	end
	fingerTouches[input] = nil
	inputStartPositions[input] = nil
	inputStartTimes[input] = nil
end

function CameraController:_OnMousePanButtonPressed(input, processed)
	if processed then
		return
	end
	this:UpdateMouseBehavior()
	panBeginLook = panBeginLook or this:GetCameraLook()
	startPos = startPos or input.Position
	lastPos = lastPos or startPos
	this.UserPanningTheCamera = true
end

function CameraController:_OnMousePanButtonReleased(input, processed)
	this:UpdateMouseBehavior()
	if not (self._IsRightMouseDown or self._IsMiddleMouseDown) then
		panBeginLook = nil
		startPos = nil
		lastPos = nil
		this.UserPanningTheCamera = false
	end
end

function CameraController:_OnMouse2Down(input, processed)
	if processed then
		return
	end

	self._IsRightMouseDown = true
	self:_OnMousePanButtonPressed(input, processed)
end

function CameraController:_OnMouse2Up(input, processed)
	self._IsRightMouseDown = false
	self:_OnMousePanButtonReleased(input, processed)
end

function CameraController:_OnMouse3Down(input, processed)
	if processed then
		return
	end

	self._IsMiddleMouseDown = true
	self:_OnMousePanButtonPressed(input, processed)
end

function CameraController:_OnMouse3Up(input, processed)
	self._IsMiddleMouseDown = false
	OnMousePanButtonReleased(input, processed)
end

function CameraController:_OnMouseMoved(input, processed)
	if not hasGameLoaded and VRService.VREnabled then
		return
	end

	local inputDelta = input.Delta
	inputDelta = Vector2.new(inputDelta.X, inputDelta.Y * Settings.GameSettings:GetCameraYInvertValue())

	if startPos and lastPos and panBeginLook then
		local currPos = lastPos + input.Delta
		local totalTrans = currPos - startPos
		if this.PanEnabled then
			local desiredXYVector = this:MouseTranslationToAngle(inputDelta) * MOUSE_SENSITIVITY
			this.RotateInput = this.RotateInput + desiredXYVector
		end
		lastPos = currPos
	elseif this:IsInFirstPerson() or this:GetShiftLock() then
		if this.PanEnabled then
			local desiredXYVector = this:MouseTranslationToAngle(inputDelta) * MOUSE_SENSITIVITY
			this.RotateInput = this.RotateInput + desiredXYVector
		end
	end
end

function CameraController:_OnMouseWheel(input, processed)
	if not hasGameLoaded and VRService.VREnabled then
		return
	end
	if not processed then
		if this.ZoomEnabled then
			this:ZoomCameraBy(math.clamp(-input.Position.Z, -1, 1) * 1.4)
		end
	end
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

function CameraController:_OnKeyDown(input, processed)
	if not hasGameLoaded and VRService.VREnabled then
		return
	end
	if processed then
		return
	end
	if this.ZoomEnabled then
		if input.KeyCode == Enum.KeyCode.I then
			this:ZoomCameraBy(-5)
		elseif input.KeyCode == Enum.KeyCode.O then
			this:ZoomCameraBy(5)
		end
	end
	if panBeginLook == nil and this.KeyPanEnabled then
		if input.KeyCode == Enum.KeyCode.Left then
			this.TurningLeft = true
		elseif input.KeyCode == Enum.KeyCode.Right then
			this.TurningRight = true
		elseif input.KeyCode == Enum.KeyCode.Comma then
			local angle = rotateVectorByAngleAndRound(
				this:GetCameraLook() * Vector3.new(1, 0, 1),
				-QUARTER_PI * (3 / 4),
				QUARTER_PI
			)
			if angle ~= 0 then
				this.RotateInput = this.RotateInput + Vector2.new(angle, 0)
				this.LastUserPanCamera = tick()
				this.LastCameraTransform = nil
			end
		elseif input.KeyCode == Enum.KeyCode.Period then
			local angle = rotateVectorByAngleAndRound(
				this:GetCameraLook() * Vector3.new(1, 0, 1),
				QUARTER_PI * (3 / 4),
				QUARTER_PI
			)
			if angle ~= 0 then
				this.RotateInput = this.RotateInput + Vector2.new(angle, 0)
				this.LastUserPanCamera = tick()
				this.LastCameraTransform = nil
			end
		elseif input.KeyCode == Enum.KeyCode.PageUp then
			--elseif input.KeyCode == Enum.KeyCode.Home then
			this.RotateInput = this.RotateInput + Vector2.new(0, math.rad(15))
			this.LastCameraTransform = nil
		elseif input.KeyCode == Enum.KeyCode.PageDown then
			--elseif input.KeyCode == Enum.KeyCode.End then
			this.RotateInput = this.RotateInput + Vector2.new(0, math.rad(-15))
			this.LastCameraTransform = nil
		end
	end
end

function CameraController:_OnKeyUp(input, processed)
	if input.KeyCode == Enum.KeyCode.Left then
		this.TurningLeft = false
	elseif input.KeyCode == Enum.KeyCode.Right then
		this.TurningRight = false
	end
end

function CameraController:_OnWindowFocusReleased()
	self:ResetInputStates()
end

function CameraController.new()
	local self = setmetatable({
		R15HeadHeight = R15_HEAD_OFFSET,
		ShiftLock = false,
		Enabled = false,
		_IsFirstPerson = false,
		_IsRightMouseDown = false,
		_IsMiddleMouseDown = false,
		RotateInput = ZERO_VECTOR2,
		DefaultZoom = LANDSCAPE_DEFAULT_ZOOM,
		_ActiveGamepad = nil,
		_LastSubject = nil,
		_LastSubjectPosition = Vector3.new(0, 5, 0),
		_Tweens = {},
		_LastVRRotation = 0,
		_VRRotateKeyCooldown = {},
		_IsDynamicThumbstickEnabled = false,
		_DynamicThumbstickFrame = nil,
		_CameraChangedConn = nil,
		_WorkspaceCameraChangedConn = nil,
		_VRRotationIntensityExists = true,
		_LastVRRotationCheck = 0,	
		_CameraTranslationConstraints = Vector3.new(1, 1, 1),
		_HumanoidJumpOrigin = nil,
		_TrackingHumanoid = nil,
		_CameraFrozen = false,
		_SubjectStateChangedConn = nil,
		_CameraSubjectChangedConn = nil,
		_WorkspaceChangedConn = nil,
		_HumanoidChildAddedConn = nil,
		_HumanoidChildRemovedConn = nil,
		_StartPos = nil,
		_LastPos = nil,
		_PanBeginLook = nil,
		_LastTapTime = nil,
	
		_FingerTouches = {},
		_NumUnsunkTouches = 0,
	
		_InputStartPositions = {},
		_InputStartTimes = {},
	
		_StartingDiff = nil,
		_PinchBeginZoom = nil,
	
		ZoomEnabled = true,
		PanEnabled = true,
		KeyPanEnabled = true,
	}, CameraController)

	self._WorkspaceCameraChangedConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self:_OnWorkspaceCameraChanged()
	end)

	if workspace.CurrentCamera then
		self:_OnWorkspaceCameraChanged()
	end

	local lastThumbstickRotate = nil
	local numOfSeconds = 0.7
	local currentSpeed = 0
	local maxSpeed = 6
	local vrMaxSpeed = 4
	local lastThumbstickPos = Vector2.new(0, 0)
	local ySensitivity = 0.65
	local lastVelocity = nil



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

	function this:UpdateGamepad()
		local gamepadPan = this.GamepadPanningCamera
		if gamepadPan and (hasGameLoaded or not VRService.VREnabled) then
			gamepadPan = gamepadLinearToCurve(gamepadPan)
			local currentTime = tick()
			if gamepadPan.X ~= 0 or gamepadPan.Y ~= 0 then
				this.userPanningTheCamera = true
			elseif gamepadPan == ZERO_VECTOR2 then
				lastThumbstickRotate = nil
				if lastThumbstickPos == ZERO_VECTOR2 then
					currentSpeed = 0
				end
			end

			local finalConstant = 0

			if lastThumbstickRotate then
				if VRService.VREnabled then
					currentSpeed = vrMaxSpeed
				else
					local elapsedTime = (currentTime - lastThumbstickRotate) * 10
					currentSpeed = currentSpeed + (maxSpeed * ((elapsedTime * elapsedTime) / numOfSeconds))

					if currentSpeed > maxSpeed then
						currentSpeed = maxSpeed
					end

					if lastVelocity then
						local velocity = (gamepadPan - lastThumbstickPos) / (currentTime - lastThumbstickRotate)
						local velocityDeltaMag = (velocity - lastVelocity).Magnitude

						if velocityDeltaMag > 12 then
							currentSpeed = currentSpeed * (20 / velocityDeltaMag)
							if currentSpeed > maxSpeed then
								currentSpeed = maxSpeed
							end
						end
					end
				end

				local success, gamepadCameraSensitivity = pcall(function()
					return Settings.GameSettings.GamepadCameraSensitivity
				end)
				finalConstant = success and (gamepadCameraSensitivity * currentSpeed) or currentSpeed
				lastVelocity = (gamepadPan - lastThumbstickPos) / (currentTime - lastThumbstickRotate)
			end

			lastThumbstickPos = gamepadPan
			lastThumbstickRotate = currentTime

			return Vector2.new(
				gamepadPan.X * finalConstant,
				gamepadPan.Y * finalConstant * ySensitivity * Settings.GameSettings:GetCameraYInvertValue()
			)
		end

		return ZERO_VECTOR2
	end

	local InputBeganConn, InputChangedConn, InputEndedConn, WindowUnfocusConn, MenuOpenedConn, ShiftLockToggleConn, GamepadConnectedConn, GamepadDisconnectedConn, TouchActivateConn =
		nil, nil, nil, nil, nil, nil, nil, nil, nil

	function this:DisconnectInputEvents()
		if InputBeganConn then
			InputBeganConn:Disconnect()
			InputBeganConn = nil
		end
		if InputChangedConn then
			InputChangedConn:Disconnect()
			InputChangedConn = nil
		end
		if InputEndedConn then
			InputEndedConn:Disconnect()
			InputEndedConn = nil
		end
		if WindowUnfocusConn then
			WindowUnfocusConn:Disconnect()
			WindowUnfocusConn = nil
		end
		if MenuOpenedConn then
			MenuOpenedConn:Disconnect()
			MenuOpenedConn = nil
		end
		if ShiftLockToggleConn then
			ShiftLockToggleConn:Disconnect()
			ShiftLockToggleConn = nil
		end
		if GamepadConnectedConn then
			GamepadConnectedConn:Disconnect()
			GamepadConnectedConn = nil
		end
		if GamepadDisconnectedConn then
			GamepadDisconnectedConn:Disconnect()
			GamepadDisconnectedConn = nil
		end
		if self._SubjectStateChangedConn then
			self._SubjectStateChangedConn:Disconnect()
			self._SubjectStateChangedConn = nil
		end
		if self._WorkspaceChangedConn then
			self._WorkspaceChangedConn:Disconnect()
			self._WorkspaceChangedConn = nil
		end
		if TouchActivateConn then
			TouchActivateConn:Disconnect()
			TouchActivateConn = nil
		end

		this.TurningLeft = false
		this.TurningRight = false
		this.LastCameraTransform = nil
		self.LastSubjectCFrame = nil
		this.UserPanningTheCamera = false
		this.RotateInput = Vector2.new()
		this.GamepadPanningCamera = Vector2.new(0, 0)

		-- Reset input states
		startPos = nil
		lastPos = nil
		panBeginLook = nil
		self._IsRightMouseDown = false
		self._IsMiddleMouseDown = false

		fingerTouches = {}
		NumUnsunkTouches = 0

		StartingDiff = nil
		pinchBeginZoom = nil

		-- Unlock mouse for example if right mouse button was being held down
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end

	function this:ResetInputStates()
		self._IsRightMouseDown = false
		self._IsMiddleMouseDown = false
		this.TurningRight = false
		this.TurningLeft = false
		OnMousePanButtonReleased() -- this function doesn't seem to actually need parameters

		if UserInputService.TouchEnabled then
			--[[menu opening was causing serious touch issues
			this should disable all active touch events if
			they're active when menu opens.]]
			for inputObject, value in pairs(fingerTouches) do
				fingerTouches[inputObject] = nil
			end
			panBeginLook = nil
			startPos = nil
			lastPos = nil
			this.UserPanningTheCamera = false
			StartingDiff = nil
			pinchBeginZoom = nil
			NumUnsunkTouches = 0
		end
	end

	function this.getGamepadPan(name, state, input)
		if state == Enum.UserInputState.Cancel then
			this.GamepadPanningCamera = ZERO_VECTOR2
			return
		end

		if input.UserInputType == this.activeGamepad and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			local inputVector = Vector2.new(input.Position.X, -input.Position.Y)
			if inputVector.Magnitude > THUMBSTICK_DEADZONE then
				this.GamepadPanningCamera = Vector2.new(input.Position.X, -input.Position.Y)
			else
				this.GamepadPanningCamera = ZERO_VECTOR2
			end
		end
	end

	function this.doGamepadZoom(name, state, input)
		if
			input.UserInputType == this.activeGamepad
			and input.KeyCode == Enum.KeyCode.ButtonR3
			and state == Enum.UserInputState.Begin
		then
			if this.ZoomEnabled then
				if this:GetCameraZoom() > 0.5 then
					this:ZoomCamera(0)
				else
					this:ZoomCamera(10)
				end
			end
		end
	end

	function this:BindGamepadInputActions()
		ContextActionService:BindAction("RootCamGamepadPan", this.getGamepadPan, false, Enum.KeyCode.Thumbstick2)
		ContextActionService:BindAction("RootCamGamepadZoom", this.doGamepadZoom, false, Enum.KeyCode.ButtonR3)
	end

	function this:ConnectInputEvents()
		InputBeganConn = UserInputService.InputBegan:Connect(function(input, processed)
			if input.UserInputType == Enum.UserInputType.Touch then
				OnTouchBegan(input, processed)
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				OnMouse2Down(input, processed)
			elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
				OnMouse3Down(input, processed)
			end
			-- Keyboard
			if input.UserInputType == Enum.UserInputType.Keyboard then
				OnKeyDown(input, processed)
			end
		end)

		InputChangedConn = UserInputService.InputChanged:Connect(function(input, processed)
			if input.UserInputType == Enum.UserInputType.Touch then
				OnTouchChanged(input, processed)
			elseif input.UserInputType == Enum.UserInputType.MouseMovement then
				OnMouseMoved(input, processed)
			elseif input.UserInputType == Enum.UserInputType.MouseWheel then
				OnMouseWheel(input, processed)
			end
		end)

		InputEndedConn = UserInputService.InputEnded:Connect(function(input, processed)
			if input.UserInputType == Enum.UserInputType.Touch then
				OnTouchEnded(input, processed)
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				OnMouse2Up(input, processed)
			elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
				OnMouse3Up(input, processed)
			end
			-- Keyboard
			if input.UserInputType == Enum.UserInputType.Keyboard then
				OnKeyUp(input, processed)
			end
		end)

		WindowUnfocusConn = UserInputService.WindowFocusReleased:Connect(onWindowFocusReleased)

		MenuOpenedConn = GuiService.MenuOpened:Connect(function()
			this:ResetInputStates()
		end)

		self._WorkspaceChangedConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(onCurrentCameraChanged)
		if workspace.CurrentCamera then
			onCurrentCameraChanged()
		end

		ShiftLockToggleConn = ShiftLockController.OnShiftLockToggled.Event:Connect(function()
			this:UpdateMouseBehavior()
		end)

		this.RotateInput = Vector2.new()

		this.activeGamepad = nil
		local function assignActivateGamepad()
			local connectedGamepads = UserInputService:GetConnectedGamepads()
			if #connectedGamepads > 0 then
				for i = 1, #connectedGamepads do
					if this.activeGamepad == nil then
						this.activeGamepad = connectedGamepads[i]
					elseif connectedGamepads[i].Value < this.activeGamepad.Value then
						this.activeGamepad = connectedGamepads[i]
					end
				end
			end

			if this.activeGamepad == nil then -- nothing is connected, at least set up for gamepad1
				this.activeGamepad = Enum.UserInputType.Gamepad1
			end
		end

		GamepadConnectedConn = UserInputService.GamepadDisconnected:Connect(function(gamepadEnum)
			if this.activeGamepad ~= gamepadEnum then
				return
			end
			this.activeGamepad = nil
			assignActivateGamepad()
		end)

		GamepadDisconnectedConn = UserInputService.GamepadConnected:Connect(function(gamepadEnum)
			if this.activeGamepad == nil then
				assignActivateGamepad()
			end
		end)

		self:BindGamepadInputActions()

		assignActivateGamepad()

		-- set mouse behavior
		self:UpdateMouseBehavior()
	end

	--Process tweens related to tap-to-recenter and double-tap-to-zoom
	--Needs to be called from specific cameras on each update
	function this:ProcessTweens()
		for name, tween in pairs(tweens) do
			local alpha = math.min(1.0, (tick() - tween.start) / tween.duration)
			tween.to = tween.func(tween.from, tween.to, alpha)
			if math.abs(1 - alpha) < 0.0001 then
				tweens[name] = nil
			end
		end
	end

	function this:SetEnabled(newState)
		if newState ~= self.Enabled then
			self.Enabled = newState
			if self.Enabled then
				self:ConnectInputEvents()
				self.cframe = workspace.CurrentCamera.CFrame
			else
				self:DisconnectInputEvents()
			end
		end
	end

	local function OnPlayerAdded(player)
		player.Changed:Connect(function(prop)
			if this.Enabled then
				if prop == "CameraMode" or prop == "CameraMaxZoomDistance" or prop == "CameraMinZoomDistance" then
					this:ZoomCameraFixedBy(0)
				end
			end
		end)

		local function OnCharacterAdded(newCharacter)
			local humanoid = findPlayerHumanoid(player)
			local start = tick()
			while tick() - start < 0.3 and (humanoid == nil or humanoid.Torso == nil) do
				wait()
				humanoid = findPlayerHumanoid(player)
			end

			if humanoid and humanoid.Torso and player.Character == newCharacter then
				local newDesiredLook = (humanoid.Torso.CFrame.lookVector - Vector3.new(
					0,
					math.sin(math.rad(DEFAULT_CAMERA_ANGLE)),
					0
				)).Unit
				local horizontalShift = findAngleBetweenXZVectors(newDesiredLook, this:GetCameraLook())
				local vertShift = math.asin(this:GetCameraLook().Y) - math.asin(newDesiredLook.Y)
				if not isFinite(horizontalShift) then
					horizontalShift = 0
				end
				if not isFinite(vertShift) then
					vertShift = 0
				end
				this.RotateInput = Vector2.new(horizontalShift, vertShift)

				-- reset old camera info so follow cam doesn't rotate us
				this.LastCameraTransform = nil
			end

			-- Need to wait for camera cframe to update before we zoom in
			-- Not waiting will force camera to original cframe
			wait()
			this:ZoomCamera(this.DefaultZoom)
		end

		player.CharacterAdded:Connect(function(character)
			if this.Enabled or setCameraOnSpawn then
				OnCharacterAdded(character)
				setCameraOnSpawn = false
			end
		end)
		if player.Character then
			spawn(function()
				OnCharacterAdded(player.Character)
			end)
		end
	end
	if PlayersService.LocalPlayer then
		OnPlayerAdded(PlayersService.LocalPlayer)
	end
	PlayersService.ChildAdded:Connect(function(child)
		if child and PlayersService.LocalPlayer == child then
			OnPlayerAdded(PlayersService.LocalPlayer)
		end
	end)

	local function OnGameLoaded()
		hasGameLoaded = true
	end

	spawn(function()
		if game:IsLoaded() then
			OnGameLoaded()
		else
			game.Loaded:wait()
			OnGameLoaded()
		end
	end)

	local function OnDynamicThumbstickEnabled()
		if UserInputService.TouchEnabled then
			self._IsDynamicThumbstickEnabled = true
		end
	end

	local function OnDynamicThumbstickDisabled()
		self._IsDynamicThumbstickEnabled = false
	end

	local function OnGameSettingsTouchMovementModeChanged()
		if LocalPlayer.DevTouchMovementMode == Enum.DevTouchMovementMode.UserChoice then
			if Settings.GameSettings.TouchMovementMode.Name == "DynamicThumbstick" then
				OnDynamicThumbstickEnabled()
			else
				OnDynamicThumbstickDisabled()
			end
		end
	end

	local function OnDevTouchMovementModeChanged()
		if LocalPlayer.DevTouchMovementMode.Name == "DynamicThumbstick" then
			OnDynamicThumbstickEnabled()
		else
			OnGameSettingsTouchMovementModeChanged()
		end
	end

	if PlayersService.LocalPlayer then
		PlayersService.LocalPlayer.Changed:Connect(function(prop)
			if prop == "DevTouchMovementMode" then
				OnDevTouchMovementModeChanged()
			end
		end)
		OnDevTouchMovementModeChanged()
	end

	Settings.GameSettings.Changed:Connect(function(prop)
		if prop == "TouchMovementMode" then
			OnGameSettingsTouchMovementModeChanged()
		end
	end)
	OnGameSettingsTouchMovementModeChanged()
	Settings.GameSettings:SetCameraYInvertVisible()
	pcall(function()
		Settings.GameSettings:SetGamepadCameraSensitivityVisible()
	end)

	return this
end

function CameraController.init(maid)

end

return CameraController
