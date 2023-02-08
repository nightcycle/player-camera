--!strict

-- Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PlayersService = game:GetService("Players")
local VRService = game:GetService("VRService")
local GameSettings = UserSettings().GameSettings

-- References
local PlayerScripts = PlayersService.LocalPlayer:WaitForChild("PlayerScripts")
local RootCamera = script:WaitForChild("RootCamera")

-- Modules
local AttachCamera = require(RootCamera:WaitForChild("AttachCamera"))()
local FixedCamera = require(RootCamera:WaitForChild("FixedCamera"))()
local ScriptableCamera = require(RootCamera:WaitForChild("ScriptableCamera"))()
local TrackCamera = require(RootCamera:WaitForChild("TrackCamera"))()
local WatchCamera = require(RootCamera:WaitForChild("WatchCamera"))()
local OrbitalCamera = require(RootCamera:WaitForChild("OrbitalCamera"))()
local ClassicCamera = require(RootCamera:WaitForChild("ClassicCamera"))()
local FollowCamera = require(RootCamera:WaitForChild("FollowCamera"))()
local PopperCam = require(script:WaitForChild("PopperCam"))
local Invisicam = require(script:WaitForChild("Invisicam"))
local TransparencyController = require(script:WaitForChild("TransparencyController"))()
local VRCamera = require(RootCamera:WaitForChild("VRCamera"))()

-- Constants
local ALL_CAMERAS_IN_LUA = false
local ALL_CAM_LUA_SUCCESS, ALL_CAM_LUA_MESSAGE = pcall(function() ALL_CAMERAS_IN_LUA = UserSettings():IsUserFeatureEnabled("UserAllCamerasInLua") end)
local FF_NO_CAM_CLIK_TO_MOVE_SUCCESS, FF_NO_CAM_CLIK_TO_MOVE_RESULT = pcall(function() return UserSettings():IsUserFeatureEnabled("UserNoCameraClickToMove") end)
local FF_NO_CAM_CLIK_TO_MOVE = FF_NO_CAM_CLIK_TO_MOVE_SUCCESS and FF_NO_CAM_CLIK_TO_MOVE_RESULT
local CAN_REGISTER_CAMERAS = pcall(function() PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Default) end)
local IS_ORBITAL_CAM_ENAB = pcall(function() local _test = Enum.CameraType.Orbital end)
local CAMERA_TYPE_ENUM_MAP: {[Enum.CameraType]: any} = {
	[Enum.CameraType.Attach] = AttachCamera,
	[Enum.CameraType.Fixed] = FixedCamera,
	[Enum.CameraType.Scriptable] = ScriptableCamera,
	[Enum.CameraType.Track] = TrackCamera,
	[Enum.CameraType.Watch] = WatchCamera,
	[Enum.CameraType.Follow] = FollowCamera,
	[Enum.CameraType.Orbital] = if IS_ORBITAL_CAM_ENAB then OrbitalCamera else nil,
}

-- Modules II
local ClickToMove = if FF_NO_CAM_CLIK_TO_MOVE then nil else require(script:WaitForChild("ClickToMove"))()

-- Types
export type CameraController = {}

-- Warnings
if not ALL_CAM_LUA_SUCCESS then warn("Couldn't get feature UserAllCamerasInLua because:", ALL_CAM_LUA_MESSAGE) end

-- Register what camera scripts we are using
if CAN_REGISTER_CAMERAS then
	PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Follow)
	PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Classic)
	PlayerScripts:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.Default)
	PlayerScripts:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.Follow)
	PlayerScripts:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.Classic)
end

-- Globals
local enabledCamera: CameraController? = nil
local enabledOcclusion = nil
local cameraSubjectChangedConn = nil
local cameraTypeChangedConn = nil

local lastInputType = nil
local hasLastInput = false

-- Private methods
local function shouldUsePlayerScriptsCamera(): boolean
	local player = PlayersService.LocalPlayer
	local currentCamera = workspace.CurrentCamera
	if ALL_CAMERAS_IN_LUA then
		return true
	else
		if player then
			if
				currentCamera == nil
				or (currentCamera.CameraType == Enum.CameraType.Custom)
				or (IS_ORBITAL_CAM_ENAB and currentCamera.CameraType == Enum.CameraType.Orbital)
			then
				return true
			end
		end
	end
	return false
end

local function isClickToMoveOn(): boolean
	local usePlayerScripts = shouldUsePlayerScriptsCamera()
	local player = PlayersService.LocalPlayer
	if usePlayerScripts and player then
		if (hasLastInput and lastInputType == Enum.UserInputType.Touch) or UserInputService.TouchEnabled then -- Touch
			if
				player.DevTouchMovementMode == Enum.DevTouchMovementMode.ClickToMove
				or (
					player.DevTouchMovementMode == Enum.DevTouchMovementMode.UserChoice
					and GameSettings.TouchMovementMode == Enum.TouchMovementMode.ClickToMove
				)
			then
				return true
			end
		else -- Computer
			if
				player.DevComputerMovementMode == Enum.DevComputerMovementMode.ClickToMove
				or (
					player.DevComputerMovementMode == Enum.DevComputerMovementMode.UserChoice
					and GameSettings.ComputerMovementMode == Enum.ComputerMovementMode.ClickToMove
				)
			then
				return true
			end
		end
	end
	return false
end

local function getCurrentCameraMode(): string?
	local usePlayerScripts = shouldUsePlayerScriptsCamera()
	local player = PlayersService.LocalPlayer
	if usePlayerScripts and player then
		if (hasLastInput and lastInputType == Enum.UserInputType.Touch) or UserInputService.TouchEnabled then -- Touch (iPad, etc...)
			if not FF_NO_CAM_CLIK_TO_MOVE and isClickToMoveOn() then
				return Enum.DevTouchMovementMode.ClickToMove.Name
			elseif player.DevTouchCameraMode == Enum.DevTouchCameraMovementMode.UserChoice then
				local touchMovementMode = GameSettings.TouchCameraMovementMode
				if touchMovementMode == Enum.TouchCameraMovementMode.Default then
					return Enum.TouchCameraMovementMode.Follow.Name
				end
				return touchMovementMode.Name
			else
				return player.DevTouchCameraMode.Name
			end
		else -- Computer
			if not FF_NO_CAM_CLIK_TO_MOVE and isClickToMoveOn() then
				return Enum.DevComputerMovementMode.ClickToMove.Name
			elseif player.DevComputerCameraMode == Enum.DevComputerCameraMovementMode.UserChoice then
				local computerMovementMode = GameSettings.ComputerCameraMovementMode
				if computerMovementMode == Enum.ComputerCameraMovementMode.Default then
					return Enum.ComputerCameraMovementMode.Classic.Name
				end
				return computerMovementMode.Name
			else
				return player.DevComputerCameraMode.Name
			end
		end
	end
	return nil
end

local function getCameraOcclusionMode(): Enum.DevCameraOcclusionMode?
	local usePlayerScripts = shouldUsePlayerScriptsCamera()
	local player = PlayersService.LocalPlayer
	if usePlayerScripts and player then
		return player.DevCameraOcclusionMode
	end
	return nil
end

-- New for AllCameraInLua support
local function shouldUseOcclusionModule(): boolean
	local player = PlayersService.LocalPlayer
	if
		player
		and game.Workspace.CurrentCamera
		and game.Workspace.CurrentCamera.CameraType == Enum.CameraType.Custom
	then
		return true
	end
	return false
end

local function update()
	if enabledCamera then
		enabledCamera:Update()
	end
	if enabledOcclusion and not VRService.VREnabled then
		enabledOcclusion:Update(enabledCamera)
	end
	if shouldUsePlayerScriptsCamera() then
		TransparencyController:Update()
	end
end

local function setEnabledCamera(newCamera: CameraController?)
	if enabledCamera ~= newCamera then
		if enabledCamera then
			enabledCamera:SetEnabled(false)
		end
		enabledCamera = newCamera
		if enabledCamera then
			enabledCamera:SetEnabled(true)
		end
	end
end

local function onCameraMovementModeChange(newCameraMode: string?)
	if newCameraMode == Enum.DevComputerMovementMode.ClickToMove.Name then
		if FF_NO_CAM_CLIK_TO_MOVE then
			--No longer responding to ClickToMove here!
			return
		end
		assert(ClickToMove ~= nil)
		ClickToMove:Start()
		setEnabledCamera(nil)
		TransparencyController:SetEnabled(true)
	else
		local currentCameraType = workspace.CurrentCamera and workspace.CurrentCamera.CameraType
		if VRService.VREnabled and currentCameraType ~= Enum.CameraType.Scriptable then
			setEnabledCamera(VRCamera)
			TransparencyController:SetEnabled(false)
		elseif
			(currentCameraType == Enum.CameraType.Custom or not ALL_CAMERAS_IN_LUA)
			and newCameraMode == Enum.ComputerCameraMovementMode.Classic.Name
		then
			setEnabledCamera(ClassicCamera)
			TransparencyController:SetEnabled(true)
		elseif
			(currentCameraType == Enum.CameraType.Custom or not ALL_CAMERAS_IN_LUA)
			and newCameraMode == Enum.ComputerCameraMovementMode.Follow.Name
		then
			setEnabledCamera(FollowCamera)
			TransparencyController:SetEnabled(true)
		elseif
			(currentCameraType == Enum.CameraType.Custom or not ALL_CAMERAS_IN_LUA)
			and (IS_ORBITAL_CAM_ENAB and (newCameraMode == Enum.ComputerCameraMovementMode.Orbital.Name))
		then
			setEnabledCamera(OrbitalCamera)
			TransparencyController:SetEnabled(true)
		elseif ALL_CAMERAS_IN_LUA and CAMERA_TYPE_ENUM_MAP[currentCameraType] then
			setEnabledCamera(CAMERA_TYPE_ENUM_MAP[currentCameraType])
			TransparencyController:SetEnabled(false)
		else -- Our camera movement code was disabled by the developer
			setEnabledCamera(nil)
			TransparencyController:SetEnabled(false)
		end
		ClickToMove:Stop()
	end

	local useOcclusion = shouldUseOcclusionModule()
	local newOcclusionMode = getCameraOcclusionMode()
	if
		enabledOcclusion == Invisicam
		and (newOcclusionMode ~= Enum.DevCameraOcclusionMode.Invisicam or not useOcclusion)
	then
		Invisicam:Cleanup()
	end

	-- PopperCam does not work with OrbitalCamera, as OrbitalCamera's distance can be fixed.
	if useOcclusion then
		if
			newOcclusionMode == Enum.DevCameraOcclusionMode.Zoom
			and (IS_ORBITAL_CAM_ENAB and newCameraMode ~= Enum.ComputerCameraMovementMode.Orbital.Name)
		then
			enabledOcclusion = PopperCam
		elseif newOcclusionMode == Enum.DevCameraOcclusionMode.Invisicam then
			enabledOcclusion = Invisicam
		else
			enabledOcclusion = nil
		end
	else
		enabledOcclusion = nil
	end
end

local function OnCameraTypeChanged(newCameraType)
	if newCameraType == Enum.CameraType.Scriptable then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

local function OnCameraSubjectChanged(newSubject)
	TransparencyController:SetSubject(newSubject)
end

local function OnNewCamera()
	onCameraMovementModeChange(getCurrentCameraMode())

	local currentCamera = workspace.CurrentCamera
	if currentCamera then
		if cameraSubjectChangedConn then
			cameraSubjectChangedConn:disconnect()
		end

		if cameraTypeChangedConn then
			cameraTypeChangedConn:disconnect()
		end

		cameraSubjectChangedConn = currentCamera:GetPropertyChangedSignal("CameraSubject"):connect(function()
			OnCameraSubjectChanged(currentCamera.CameraSubject)
		end)

		cameraTypeChangedConn = currentCamera:GetPropertyChangedSignal("CameraType"):connect(function()
			onCameraMovementModeChange(getCurrentCameraMode())
			OnCameraTypeChanged(currentCamera.CameraType)
		end)

		OnCameraSubjectChanged(currentCamera.CameraSubject)
		OnCameraTypeChanged(currentCamera.CameraType)
	end
end

local function OnPlayerAdded(player)
	workspace.Changed:connect(function(prop)
		if prop == "CurrentCamera" then
			OnNewCamera()
		end
	end)

	player.Changed:connect(function(prop)
		onCameraMovementModeChange(getCurrentCameraMode())
	end)

	GameSettings.Changed:connect(function(prop)
		onCameraMovementModeChange(getCurrentCameraMode())
	end)

	RunService:BindToRenderStep("cameraRenderUpdate", Enum.RenderPriority.Camera.Value, Update)

	OnNewCamera()
	onCameraMovementModeChange(getCurrentCameraMode())
end

do
	while PlayersService.LocalPlayer == nil do
		PlayersService.PlayerAdded:wait()
	end
	hasLastInput = pcall(function()
		lastInputType = UserInputService:GetLastInputType()
		UserInputService.LastInputTypeChanged:connect(function(newLastInputType)
			lastInputType = newLastInputType
		end)
	end)
	OnPlayerAdded(PlayersService.LocalPlayer)
end

local function OnVREnabled()
	onCameraMovementModeChange(getCurrentCameraMode())
end

VRService:GetPropertyChangedSignal("VREnabled"):connect(OnVREnabled)
