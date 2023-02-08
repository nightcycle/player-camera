--!strict
-- Services
local PlayersService = game:GetService("Players")
local VRService = game:GetService("VRService")

-- Modules
local RootCamera = require(script.Parent)

-- Types
type CameraControllerProperties = RootCamera.CameraControllerProperties
type CameraControllerFunctions<S> = RootCamera.CameraControllerFunctions<S>
export type FollowCameraControllerPropertiesFunctions<S> = CameraControllerFunctions<S>
export type FollowCameraControllerProperties = {
	_TweenAcceleration: number,
	_TweenSpeed: number,
	_TweenMaxSpeed: number,
	_TimeBeforeAutoRotate: number,
	_LastUpdate: number,
} & CameraControllerProperties
type BaseFollowCameraController<S> = FollowCameraControllerProperties & FollowCameraControllerPropertiesFunctions<S>
export type FollowCameraController = BaseFollowCameraController<BaseFollowCameraController<any>>

-- Constants
local HUMANOIDSTATE_CLIMBING = Enum.HumanoidStateType.Climbing
local ZERO_VECTOR2 = Vector2.new(0, 0)
local UP_VECTOR = Vector3.new(0, 1, 0)
local XZ_VECTOR = Vector3.new(1, 0, 1)
local PORTRAIT_OFFSET = Vector3.new(0, -3, 0)

-- Private methods
local function isFinite(num: number): boolean
	return num == num and num ~= 1 / 0 and num ~= -1 / 0
end

local function isFiniteVector3(vec3: Vector3): boolean
	return isFinite(vec3.X) and isFinite(vec3.Y) and isFinite(vec3.Z)
end

-- May return NaN or inf or -inf
local function findAngleBetweenXZVectors(vec2: Vector3, vec1: Vector3): number
	-- This is a way of finding the angle between the two vectors:
	return math.atan2(vec1.X * vec2.Z - vec1.Z * vec2.X, vec1.X * vec2.X + vec1.Z * vec2.Z)
end

local FollowCameraController: FollowCameraController = {} :: any
FollowCameraController.__index = FollowCameraController :: any
setmetatable(FollowCameraController, RootCamera)

function FollowCameraController:Update()
	self:ProcessTweens()
	local now = tick()
	local timeDelta = (now - self._LastUpdate)

	local userPanningTheCamera = (self.UserPanningTheCamera == true)
	local camera = workspace.CurrentCamera
	local player = PlayersService.LocalPlayer
	local humanoid = self:GetHumanoid()
	local cameraSubject = camera and camera.CameraSubject
	local isClimbing = humanoid and humanoid:GetState() == HUMANOIDSTATE_CLIMBING
	local isInVehicle = cameraSubject and cameraSubject:IsA("VehicleSeat")
	local isOnASkateboard = cameraSubject and cameraSubject:IsA("SkateboardPlatform")

	if self._LastUpdate == nil or now - self._LastUpdate > 1 then
		self:ResetCameraLook()
		self.LastCameraTransform = nil
	end

	if self._LastUpdate then
		if self:ShouldUseVRRotation() then
			self.RotateInput = self.RotateInput + self:GetVRRotationInput()
		else
			-- Cap out the delta to 0.1 so we don't get some crazy things when we re-resume from
			local delta = math.min(0.1, now - self._LastUpdate)
			local angle = 0
			-- NOTE: Traditional follow camera does not rotate with arrow keys
			if not (isInVehicle or isOnASkateboard) then
				angle = angle + (self.TurningLeft and -120 or 0)
				angle = angle + (self.TurningRight and 120 or 0)
			end

			local gamepadRotation = self:UpdateGamepad()
			if gamepadRotation ~= Vector2.new(0, 0) then
				userPanningTheCamera = true
				self.RotateInput = self.RotateInput + (gamepadRotation * delta)
			end

			if angle ~= 0 then
				userPanningTheCamera = true
				self.RotateInput = self.RotateInput + Vector2.new(math.rad(angle * delta), 0)
			end
		end
	end

	-- Reset tween speed if user is panning
	if userPanningTheCamera then
		self._TweenSpeed = 0
		self.LastUserPanCamera = tick()
	end

	local lastUserPan = self.LastUserPanCamera or 0
	local userRecentlyPannedCamera = now - lastUserPan < self._TimeBeforeAutoRotate

	local subjectPosition = self:GetSubjectPosition()
	if subjectPosition and player and camera then
		local zoom = self:GetCameraZoom()
		if zoom < 0.5 then
			zoom = 0.5
		end

		if self:GetShiftLock() and not self:IsInFirstPerson() then
			local newLookVector = self:RotateCamera(self:GetCameraLook(), self.RotateInput)
			local offset = ((newLookVector * XZ_VECTOR):Cross(UP_VECTOR).Unit * 1.75)
			if isFiniteVector3(offset) then
				subjectPosition = subjectPosition + offset
			end
		else
			if self.LastCameraTransform and not userPanningTheCamera then
				local isInFirstPerson = self:IsInFirstPerson()
				if
					(isClimbing or isInVehicle or isOnASkateboard)
					and self._LastUpdate
					and humanoid
					and (humanoid :: any).Torso
				then
					if isInFirstPerson then
						if
							self.LastSubjectCFrame
							and (isInVehicle or isOnASkateboard)
							and cameraSubject:IsA("BasePart")
						then
							local y = -findAngleBetweenXZVectors(
								self.LastSubjectCFrame.LookVector,
								cameraSubject.CFrame.lookVector
							)
							if isFinite(y) then
								self.RotateInput = self.RotateInput + Vector2.new(y, 0)
							end
							self._TweenSpeed = 0
						end
					elseif not userRecentlyPannedCamera then
						local forwardVector: Vector3 = (humanoid :: any).Torso.CFrame.LookVector
						if isOnASkateboard then
							forwardVector = cameraSubject.CFrame.lookVector
						end

						self._TweenSpeed = math.clamp(self._TweenSpeed + self._TweenAcceleration * timeDelta, 0, self._TweenMaxSpeed)

						local percent = math.clamp(self._TweenSpeed * timeDelta, 0, 1)
						if not isClimbing and self:IsInFirstPerson() then
							percent = 1
						end
						local y = findAngleBetweenXZVectors(forwardVector, self:GetCameraLook())
						-- Check for NaN
						if isFinite(y) and math.abs(y) > 0.0001 then
							self.RotateInput = self.RotateInput + Vector2.new(y * percent, 0)
						end
					end
				elseif not (isInFirstPerson or userRecentlyPannedCamera) and not VRService.VREnabled then
					local lastVec = -(self.LastCameraTransform.Position - subjectPosition)

					local y = findAngleBetweenXZVectors(lastVec, self:GetCameraLook())

					-- This cutoff is to decide if the humanoid's angle of movement,
					-- relative to the camera's look vector, is enough that
					-- we want the camera to be following them. The point is to provide
					-- a sizable deadzone to allow more precise forward movements.
					local thetaCutoff = 0.4

					-- Check for NaNs
					if isFinite(y) and math.abs(y) > 0.0001 and math.abs(y) > thetaCutoff * timeDelta then
						self.RotateInput = self.RotateInput + Vector2.new(y, 0)
					end
				end
			end
		end
		local newLookVector = self:RotateCamera(self:GetCameraLook(), self.RotateInput)
		self.RotateInput = ZERO_VECTOR2

		if VRService.VREnabled then
			camera.Focus = self:GetVRFocus(subjectPosition, timeDelta)
		elseif self:IsPortraitMode() then
			camera.Focus = CFrame.new(subjectPosition + PORTRAIT_OFFSET)
		else
			camera.Focus = CFrame.new(subjectPosition)
		end
		camera.CFrame = CFrame.new(camera.Focus.Position - (zoom * newLookVector), camera.Focus.Position)
			+ Vector3.new(0, self:GetCameraHeight(), 0)

		self.LastCameraTransform = camera.CFrame
		self.LastCameraFocus = camera.Focus
		if isInVehicle or isOnASkateboard and cameraSubject:IsA("BasePart") then
			self.LastSubjectCFrame = cameraSubject.CFrame
		else
			self.LastSubjectCFrame = nil
		end
	end

	self._LastUpdate = now
	return nil
end

function FollowCameraController.new()
	local self: FollowCameraController = setmetatable(RootCamera.new(), FollowCameraController) :: any

	self._TweenAcceleration = math.rad(220)
	self._TweenSpeed = math.rad(0)
	self._TweenMaxSpeed = math.rad(250)
	self._TimeBeforeAutoRotate = 2

	self._LastUpdate = tick()
	
	return self
end

return FollowCameraController
