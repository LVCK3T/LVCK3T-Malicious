

		--// Cache
	local game, workspace = game, workspace
	local getrawmetatable, getmetatable, setmetatable, pcall, getgenv, next, tick = getrawmetatable, getmetatable, setmetatable, pcall, getgenv, next, tick
	local Vector2new, Vector3zero, CFramenew, Color3fromRGB, Color3fromHSV, Drawingnew, TweenInfonew = Vector2.new, Vector3.zero, CFrame.new, Color3.fromRGB, Color3.fromHSV, Drawing.new, TweenInfo.new
	local getupvalue, mousemoverel, tablefind, tableremove, stringlower, stringsub, mathclamp = debug.getupvalue, mousemoverel or (Input and Input.MouseMove), table.find, table.remove, string.lower, string.sub, math.clamp

	local GameMetatable = getrawmetatable and getrawmetatable(game) or { -- Auxillary functions - if the executor doesn't support "getrawmetatable".
		__index = function(self, Index) return self[Index] end,
		__newindex = function(self, Index, Value) self[Index] = Value end
	}
	local __index = GameMetatable.__index
	local __newindex = GameMetatable.__newindex
	local getrenderproperty, setrenderproperty = getrenderproperty or __index, setrenderproperty or __newindex
	local GetService = setmetatable({}, {
		__index = function(self, name)
			local success, cache = pcall(function()
				return cloneref(game:GetService(name))
			end)
			if success then
				rawset(self, name, cache)
				return cache
			else
				-- error("Invalid Roblox Service: " .. tostring(name))
			end
		end
	})

	--// Services
	local RunService = GetService.RunService
	local UserInputService = GetService.UserInputService
	local TweenService = GetService.TweenService
	local Players = GetService.Players
	local CoreGui = GetService.CoreGui
	local ReplicatedStorage = GetService.ReplicatedStorage
	local Teams = GetService.Teams

	--// Service Methods
	local LocalPlayer = __index(Players, "LocalPlayer")
	local Camera = __index(workspace, "CurrentCamera")
	local FindFirstChild, FindFirstChildOfClass = __index(game, "FindFirstChild"), __index(game, "FindFirstChildOfClass")
	local GetDescendants = __index(game, "GetDescendants")
	local WorldToViewportPoint = __index(Camera, "WorldToViewportPoint")
	local GetPartsObscuringTarget = __index(Camera, "GetPartsObscuringTarget")
	local GetMouseLocation = __index(UserInputService, "GetMouseLocation")
	local GetPlayers = __index(Players, "GetPlayers")

	--// Variables
	local RequiredDistance, Typing, Running, ServiceConnections, Animation, OriginalSensitivity = 2000, false, false, {}
	local Connect, Disconnect = __index(game, "DescendantAdded").Connect

	local Map = workspace:WaitForChild("Map")
	local Filter = workspace:WaitForChild("Filter")
	local BredMakurz = Map:WaitForChild("BredMakurz")
	local Doors = Map:WaitForChild("Doors")
	local ATMz = Map:WaitForChild("ATMz")
	local SpawnedPiles = Filter:WaitForChild("SpawnedPiles")
	local Shopz = Map:WaitForChild("Shopz")

	local Events = ReplicatedStorage:WaitForChild("Events")
	local Values = ReplicatedStorage:WaitForChild("Values")
	local GameMode = Values:WaitForChild("GameMode")

	local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local MainGui = PlayerGui and PlayerGui:FindFirstChild("CoreGUI")
	local MainMobileGui = PlayerGui and PlayerGui:FindFirstChild("MobileButtonGUI")

	local scriptUnloaded = false

	local autoLockpickEnabled = false
	local autoLockpickThread

	local IsOnMobile = false
	local FluentMenu

	xpcall(function()
		IsOnMobile = table.find({Enum.Platform.Android, Enum.Platform.IOS}, UserInputService:GetPlatform())
	end, function()
		IsOnMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	end)

	--// Checking for multiple processes (FIXED)
	-- This check now correctly verifies if the global table and its Exit method exist before trying to call them.
	if getgenv().ExunysDeveloperAimbot and getgenv().ExunysDeveloperAimbot.Exit then
		getgenv().ExunysDeveloperAimbot:Exit()
	end

	--// Environment
	getgenv().ExunysDeveloperAimbot = {
		DeveloperSettings = {
			UpdateMode = "RenderStepped",
			TeamCheckOption = "TeamColor",
			RainbowSpeed = 1 -- Bigger = Slower
		},
		Settings = {
			Enabled = true, -- This will be controlled by the UI
			TeamCheck = false,
			AliveCheck = true,
			WallCheck = false,
			OffsetToMoveDirection = false,
			OffsetIncrement = 15,
			Sensitivity = 0, -- Animation length (in seconds) before fully locking onto target
			Sensitivity2 = 3.5, -- mousemoverel Sensitivity
			LockMode = 1, -- 1 = CFrame; 2 = mousemoverel
			LockPart = "Head", -- Body part to lock on
			TriggerKey = Enum.UserInputType.MouseButton2,
			Toggle = false
		},
		FOVSettings = {
			Enabled = true, -- This will be controlled by the UI
			Visible = true,
			Radius = 90,
			NumSides = 60,
			Thickness = 1,
			Transparency = 1,
			Filled = false,
			RainbowColor = false,
			Color = Color3fromRGB(255, 255, 255),
			LockedColor = Color3fromRGB(255, 150, 150)
		},
		Blacklisted = {},
		FOVCircle = Drawingnew("Circle")
	}

	local Environment = getgenv().ExunysDeveloperAimbot
	setrenderproperty(Environment.FOVCircle, "Visible", false)

	--// Core Functions
	local FixUsername = function(String)
		local Result
		for _, Value in next, GetPlayers(Players) do
			local Name = __index(Value, "Name")
			if stringsub(stringlower(Name), 1, #String) == stringlower(String) then
				Result = Name
			end
		end
		return Result
	end

	local GetRainbowColor = function()
		local RainbowSpeed = Environment.DeveloperSettings.RainbowSpeed
		return Color3fromHSV(tick() % RainbowSpeed / RainbowSpeed, 1, 1)
	end

	local ConvertVector = function(Vector)
		return Vector2new(Vector.X, Vector.Y)
	end

	local CancelLock = function()
		Environment.Locked = nil
		local FOVCircle = Environment.FOVCircle
		setrenderproperty(FOVCircle, "Color", Environment.FOVSettings.Color)
		__newindex(UserInputService, "MouseDeltaSensitivity", OriginalSensitivity)
		if Animation then
			Animation:Cancel()
		end
	end

	local GetClosestPlayer = function()
		local Settings = Environment.Settings
		local LockPart = Settings.LockPart

		-- Use ScreenCenter on mobile, mouse location otherwise
		local Pointer = IsOnMobile and Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2) or GetMouseLocation(UserInputService)

		if not Environment.Locked then
			RequiredDistance = Environment.FOVSettings.Enabled and Environment.FOVSettings.Radius or 2000

			for _, Value in next, GetPlayers(Players) do
				local Character = __index(Value, "Character")
				local Humanoid = Character and FindFirstChildOfClass(Character, "Humanoid")

				if Value ~= LocalPlayer and not tablefind(Environment.Blacklisted, __index(Value, "Name")) and Character and FindFirstChild(Character, LockPart) and Humanoid then
					local PartPosition, TeamCheckOption = __index(Character[LockPart], "Position"), Environment.DeveloperSettings.TeamCheckOption

					if Settings.TeamCheck and __index(Value, TeamCheckOption) == __index(LocalPlayer, TeamCheckOption) then
						continue
					end

					if Settings.AliveCheck and __index(Humanoid, "Health") <= 0 then
						continue
					end

					if Settings.WallCheck then
						local BlacklistTable = GetDescendants(__index(LocalPlayer, "Character"))

						for _, Value in next, GetDescendants(Character) do
							BlacklistTable[#BlacklistTable + 1] = Value
						end

						if #GetPartsObscuringTarget(Camera, {PartPosition}, BlacklistTable) > 0 then
							continue
						end
					end

					local Vector, OnScreen, Distance = WorldToViewportPoint(Camera, PartPosition)
					Vector = ConvertVector(Vector)
					Distance = (Pointer - Vector).Magnitude

					if Distance < RequiredDistance and OnScreen then
						RequiredDistance, Environment.Locked = Distance, Value
					end
				end
			end
		elseif (Pointer - ConvertVector(WorldToViewportPoint(Camera, __index(__index(__index(Environment.Locked, "Character"), LockPart), "Position")))).Magnitude > RequiredDistance then
			CancelLock()
		end
	end

	local Load = function()
		OriginalSensitivity = __index(UserInputService, "MouseDeltaSensitivity")
		local Settings, FOVCircle, FOVSettings = Environment.Settings, Environment.FOVCircle, Environment.FOVSettings
		local Offset
		local AimbotButton 

		--// HYBRID CONTROL SETUP: Create controls based on platform

		if IsOnMobile then
			-- MOBILE: Create the toggle button
			AimbotButton = MainMobileGui:WaitForChild("TouchControlFrame",math.huge):WaitForChild("Gun"):WaitForChild("AimButton")

			local Corner = Instance.new("UICorner")
			Corner.CornerRadius = UDim.new(0, 8)
			Corner.Parent = AimbotButton

			ServiceConnections.AimbotButtonConnection = Connect(AimbotButton.MouseButton1Click, function()
				Running = not Running
				if not Running then
					CancelLock()
				end
				AimbotButton.Text = "Aimbot: " .. (Running and "ON" or "OFF")
				AimbotButton.BackgroundColor3 = Running and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(40, 40, 40)
			end)
		else
			-- DESKTOP: Use the existing keybind system
			ServiceConnections.InputBeganConnection = Connect(__index(UserInputService, "InputBegan"), function(Input)
				local TriggerKey, Toggle = Settings.TriggerKey, Settings.Toggle
				if Typing then return end
				if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
					if Toggle then
						Running = not Running
						if not Running then
							CancelLock()
						end
					else
						Running = true
					end
				end
			end)
			ServiceConnections.InputEndedConnection = Connect(__index(UserInputService, "InputEnded"), function(Input)
				local TriggerKey, Toggle = Settings.TriggerKey, Settings.Toggle
				if Toggle or Typing then return end
				if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
					Running = false
					CancelLock()
				end
			end)
		end
		--// END HYBRID CONTROL SETUP

		ServiceConnections.RenderSteppedConnection = Connect(__index(RunService, Environment.DeveloperSettings.UpdateMode), function()
			local OffsetToMoveDirection, LockPart = Settings.OffsetToMoveDirection, Settings.LockPart
			if FOVSettings.Enabled and Settings.Enabled then
				for Index, Value in next, FOVSettings do
					if Index == "Color" or Index == "LockedColor" then continue end
					if pcall(getrenderproperty, FOVCircle, Index) then setrenderproperty(FOVCircle, Index, Value) end
				end
				setrenderproperty(FOVCircle, "Color", (Environment.Locked and FOVSettings.LockedColor) or FOVSettings.RainbowColor and GetRainbowColor() or FOVSettings.Color)
				
				--// MODIFICATION: Lock the FOV circle to the center of the screen
				local CameraViewport = Camera.ViewportSize
				if IsOnMobile then
				setrenderproperty(FOVCircle, "Position", Vector2new(CameraViewport.X / 2, CameraViewport.Y / 2))
				else
				setrenderproperty(FOVCircle, "Position", GetMouseLocation(UserInputService))
				end
			else
				setrenderproperty(FOVCircle, "Visible", false)
			end
			
			if Running and Settings.Enabled then
				GetClosestPlayer()
				if Environment.Locked then
					local LockedPlayer = Environment.Locked
					local Character = __index(LockedPlayer, "Character")
					local Humanoid = Character and FindFirstChildOfClass(Character, "Humanoid")
					local PartToLock = Character and FindFirstChild(Character, LockPart)
					if not LockedPlayer or not Character or not Humanoid or not PartToLock or Humanoid.Health <= 0 then
						CancelLock()
					else
						Offset = OffsetToMoveDirection and __index(Humanoid, "MoveDirection") * (mathclamp(Settings.OffsetIncrement, 1, 30) / 10) or Vector3zero
						local LockedPosition_Vector3 = __index(PartToLock, "Position")
						local LockedPosition = WorldToViewportPoint(Camera, LockedPosition_Vector3 + Offset)
						if Environment.Settings.LockMode == 2 then
							mousemoverel((LockedPosition.X - GetMouseLocation(UserInputService).X) / Settings.Sensitivity2, (LockedPosition.Y - GetMouseLocation(UserInputService).Y) / Settings.Sensitivity2)
						else
							if Settings.Sensitivity >= 0 then
								Animation = TweenService:Create(Camera, TweenInfonew(Environment.Settings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFramenew(Camera.CFrame.Position, LockedPosition_Vector3)})
								Animation:Play()
							else
								__newindex(Camera, "CFrame", CFramenew(Camera.CFrame.Position, LockedPosition_Vector3 + Offset))
							end
							__newindex(UserInputService, "MouseDeltaSensitivity", 0)
						end
						setrenderproperty(FOVCircle, "Color", FOVSettings.LockedColor)
					end
				end
			end
		end)
	end

	--// Typing Check
	ServiceConnections.TypingStartedConnection = Connect(__index(UserInputService, "TextBoxFocused"), function()
		Typing = true
	end)
	ServiceConnections.TypingEndedConnection = Connect(__index(UserInputService, "TextBoxFocusReleased"), function()
		Typing = false
	end)

	--// Functions
	function Environment.Exit(self) -- METHOD | ExunysDeveloperAimbot:Exit(<void>)
		-- Safely disconnect all active service connections
		for _, Connection in next, ServiceConnections do
			if Connection and Connection.Disconnect then
				Connection:Disconnect()
			end
		end

		-- Cancel any active aimbot animation
		if Animation and Animation.Cancel then
			Animation:Cancel()
		end

		-- Restore original mouse sensitivity
		if OriginalSensitivity then
			__newindex(UserInputService, "MouseDeltaSensitivity", OriginalSensitivity)
		end

		-- Remove the FOV drawings from the screen
		if self.FOVCircle and self.FOVCircle.Remove then
			self.FOVCircle:Remove()
		end

		--// MOBILE COMPATIBILITY CLEANUP ADDITION
		-- Find and remove the mobile aimbot button from the screen if it exists
		local AimbotButton = CoreGui:FindFirstChild("AimbotToggleButton")
		if AimbotButton and AimbotButton.Destroy then
			AimbotButton:Destroy()
		end
		--// END MOBILE COMPATIBILITY CLEANUP ADDITION

		-- Clear the global environment to fully wipe the script
		getgenv().ExunysDeveloperAimbot = nil
	end

	function Environment.Restart() -- ExunysDeveloperAimbot.Restart(<void>)
		for Index, _ in next, ServiceConnections do
			if ServiceConnections[Index] and ServiceConnections[Index].Disconnect then
				Disconnect(ServiceConnections[Index])
			end
		end
		Load()
	end

	function Environment.Blacklist(self, Username) -- METHOD | ExunysDeveloperAimbot:Blacklist(<string> Player Name)
		assert(self, "EXUNYS_AIMBOT-V3.Blacklist: Missing parameter #1 \"self\" <table>.")
		assert(Username, "EXUNYS_AIMBOT-V3.Blacklist: Missing parameter #2 \"Username\" <string>.")
		Username = FixUsername(Username)
		assert(Username, "EXUNYS_AIMBOT-V3.Blacklist: User "..Username.." couldn't be found.")
		self.Blacklisted[#self.Blacklisted + 1] = Username
	end

	function Environment.Whitelist(self, Username) -- METHOD | ExunysDeveloperAimbot:Whitelist(<string> Player Name)
		assert(self, "EXUNYS_AIMBOT-V3.Whitelist: Missing parameter #1 \"self\" <table>.")
		assert(Username, "EXUNYS_AIMBOT-V3.Whitelist: Missing parameter #2 \"Username\" <string>.")
		Username = FixUsername(Username)
		assert(Username, "EXUNYS_AIMBOT-V3.Whitelist: User "..Username.." couldn't be found.")
		local Index = tablefind(self.Blacklisted, Username)
		assert(Index, "EXUNYS_AIMBOT-V3.Whitelist: User "..Username.." is not blacklisted.")
		tableremove(self.Blacklisted, Index)
	end

	function Environment.GetClosestPlayer() -- ExunysDeveloperAimbot.GetClosestPlayer(<void>)
		GetClosestPlayer()
		local Value = Environment.Locked
		CancelLock()
		return Value
	end

	Environment.Load = Load -- ExunysDeveloperAimbot.Load()
	setmetatable(Environment, {__call = Load})

	--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	--// UI Integration
	local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
	local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
	local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

	local Aimbot = getgenv().ExunysDeveloperAimbot -- Use the local environment we just created

	--// Exunys Aimbot Settings
	Aimbot:Load()
	local AimFOV = Aimbot.FOVSettings
	local AimSettings = Aimbot.Settings

	--// Aimbot initial Settings (Set to false, UI will control them)
	AimSettings.Enabled = false

	local PlaceIds = {
		MainMenu = 4588604953,
		Casual = 8343259840,
		MCasual = 15169316384,
		Brawl = 15169306359,
		Standard = 15169303036,
		Infection = 15169310267,
	}

	local function CheckMode()
		for modeName, id in pairs(PlaceIds) do
			if game.PlaceId == id then
				return modeName -- return the string name, e.g. "Casual"
			end
		end
		return nil -- if not found
	end

	local currentMode = CheckMode()

	if currentMode ==  "MainMenu" then
		Fluent:Notify({
			Title = "Criminality Simple Script",
			Content = "You are in Main Menu, please select a game mode to use the script.",
			Duration = 5,
		})
	end
	--// Connections
	local safeConn, registerConn, atmConn, crateConn, playerAddedConn
	local charAddedConns = {}
	local billboardConnections = {}

	--// Utility: Highlight	
	local function getHighlight(target, color, prefix)
		if scriptUnloaded then return nil end

		local adornee
		if target:IsA("Model") then
			adornee = target   -- highlight the whole model
		elseif target:IsA("BasePart") then
			adornee = target   -- highlight just this part
		else
			return nil
		end

		local safeName = target and target.Name or "Unknown"
		local name = prefix .. "_" .. safeName .. "_ESPHighlight"
		local old = CoreGui:FindFirstChild(name)
		if old then old:Destroy() end

		local highlight = Instance.new("Highlight")
		highlight.Name = name
		highlight.Adornee = adornee
		highlight.FillColor = color
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 1
		highlight.Parent = CoreGui
		return highlight
	end

	-- Waits up to timeout seconds for a visible adornee part
	local function getAdorneePart(target, timeout)
		timeout = timeout or 5
		local deadline = os.clock() + timeout

		local function resolve()
			if target:IsA("BasePart") then
				return target
			elseif target:IsA("Model") then
				return target:FindFirstChild("HumanoidRootPart")
					or target:FindFirstChild("Head")
					or target:FindFirstChildWhichIsA("BasePart")
			end
		end

		local part = resolve()
		while not part and os.clock() < deadline do
			task.wait(0.1)
			part = resolve()
		end
		return part
	end

	-- global counters to avoid name collisions
	local espCounters = {}

	local function getUniqueName(prefix, target, kind)
		local safeName = target and target.Name or "Unknown"
		espCounters[safeName] = (espCounters[safeName] or 0) + 1
		return prefix .. "_" .. safeName .. "_" .. espCounters[safeName] .. kind
	end

	-- Highlight creation
	local function getHighlight(target, color, prefix)
		local name = getUniqueName(prefix, target, "_ESPHighlight")
		local existing = CoreGui:FindFirstChild(name)
		if existing then existing:Destroy() end

		local highlight = Instance.new("Highlight")
		highlight.Name = name
		highlight.FillColor = color
		highlight.OutlineTransparency = 1
		highlight.Adornee = target
		highlight.Parent = CoreGui
		return highlight
	end

	-- Mobile Helper
	local function Hidebuttons()
		-- List of target asset IDs
		local targetIds = {
			"rbxassetid://9886659276",
			"rbxassetid://9886659406"
		}

		-- Convert list into a lookup table for faster checks
		local idLookup = {}
		for _, id in ipairs(targetIds) do
			idLookup[id] = true
		end

		-- Reference CoreGui
		local CoreGui = game:GetService("CoreGui")

		-- Function to scan a ScreenGui for ImageLabels with matching IDs
		local function scanScreenGui(screenGui)
			for _, descendant in ipairs(screenGui:GetDescendants()) do
				if descendant:IsA("ImageLabel") then
					if idLookup[descendant.Image] then
						local parent = descendant.Parent
						if parent and parent:IsA("GuiObject") then
							parent.Visible = false
							print("Disabled parent of:", descendant:GetFullName(), "Image:", descendant.Image)
						else
							print("Found ImageLabel but parent is not a GuiObject:", descendant:GetFullName())
						end
					end
				end
			end
		end

		-- Scan all ScreenGuis inside CoreGui
		for _, gui in ipairs(CoreGui:GetChildren()) do
			if gui:IsA("ScreenGui") then
				scanScreenGui(gui)
			end
		end
	end

	-- Billboard creation (safe adornee binding)
	local function ensureBillboard(target, prefix)
		local adorneePart
		repeat
			adorneePart = target:FindFirstChild("HumanoidRootPart")
				or target:FindFirstChild("Head")
				or target:FindFirstChildWhichIsA("BasePart")
			if not adorneePart then task.wait(0.2) end
		until adorneePart or scriptUnloaded

		if not adorneePart then return nil end

		local name = getUniqueName(prefix, target, "_ESPBillboard")
		local existing = CoreGui:FindFirstChild(name)
		if existing then existing:Destroy() end

		local billboard = Instance.new("BillboardGui")
		billboard.Name = name
		billboard.Size = UDim2.new(0, 200, 0, 50)
		billboard.StudsOffset = Vector3.new(0, 4, 0)
		billboard.AlwaysOnTop = true
		billboard.Adornee = adorneePart
		billboard.Parent = CoreGui

		local textLabel = Instance.new("TextLabel")
		textLabel.Name = "Info"
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.TextColor3 = Color3.new(1, 1, 1)
		textLabel.TextSize = 14
		textLabel.Font = Enum.Font.Code
		textLabel.Text = target.Name
		textLabel.Parent = billboard

		return billboard
	end

	--// Utility: Update Billboard Scale
	local function updateBillboardScale(billboard)
		if not billboard or not billboard.Adornee then return end

		local cam = workspace.CurrentCamera
		if not cam then return end

		-- distance from camera to adornee
		local dist = (cam.CFrame.Position - billboard.Adornee.Position).Magnitude

		-- scale factor: shrink when far, clamp between 0.5x and 1.5x
		local scale = math.clamp(100 / dist, 0.5, 1.5)

		-- apply size scaling
		billboard.Size = UDim2.new(0, 200 * scale, 0, 50 * scale)

		-- optional: hide billboards beyond 1000 studs
		if dist > 500 then
			billboard.Enabled = false
		else
			billboard.Enabled = true
		end

		-- optional: refresh text if Info label exists
		local textLabel = billboard:FindFirstChild("Info")
		if textLabel then
			-- you can add distance info here if desired
			-- textLabel.Text = textLabel.Text .. " | " .. math.floor(dist) .. " studs"
		end
	end

	--// ATM
	local function highlightATM(model, baseColor)
		if scriptUnloaded then return end
		local highlight = getHighlight(model, baseColor, "ATM")
		local billboard = ensureBillboard(model, "ATM")

		local textLabel = billboard and billboard:FindFirstChild("Info")
		if textLabel then
			local modelName = (model and model.Name) or "Unknown"
			textLabel.Text = modelName .. " | ATM"
			textLabel.TextColor3 = baseColor -- cyan text
		end

		highlight.FillColor = baseColor
	end

	-- Safes / Registers
	local function highlightModel(model, baseColor, prefix)
		if scriptUnloaded then return end
		local highlight = getHighlight(model, baseColor, prefix)
		local billboard = ensureBillboard(model, prefix)
		local values = model and model:FindFirstChild("Values")
		local broken = values and values:FindFirstChild("Broken")

		local function update()
			local textLabel = billboard and billboard:FindFirstChild("Info")
			if not textLabel then return end
			local modelName = (model and model.Name) or "Unknown"
			if broken and broken.Value == true then
				highlight.FillColor = Color3.fromRGB(255,0,0)
				textLabel.Text = modelName .. " | Broken"
				textLabel.TextColor3 = Color3.fromRGB(255,0,0)
			else
				highlight.FillColor = baseColor
				textLabel.Text = modelName .. " | Intact"
				textLabel.TextColor3 = baseColor
			end
		end

		update()
		if broken then broken:GetPropertyChangedSignal("Value"):Connect(update) end
	end

	-- Crates
	local function highlightCrate(model)
		if scriptUnloaded then return end
		if model.Name ~= "C1" then return end
		local mesh = model:FindFirstChildWhichIsA("MeshPart")
		if not mesh then return end

		local baseColor = Color3.fromRGB(255,128,0)
		local prefix = "Crate"
		if mesh.Material == Enum.Material.Fabric then
			baseColor = Color3.fromRGB(0,255,0); prefix = "C1Green"
		elseif mesh.Material == Enum.Material.Metal then
			baseColor = Color3.fromRGB(255,0,0); prefix = "C1Red"
		end

		local highlight = getHighlight(model, baseColor, prefix)
		local billboard = ensureBillboard(model, prefix)
		if not billboard then return end

		local textLabel = billboard:FindFirstChild("Info")
		if textLabel then
			local modelName = (model and model.Name) or "Unknown"
			textLabel.Text = modelName .. " | " .. (prefix == "C1Red" and "Red Crate" or "Green Crate")
			textLabel.TextColor3 = baseColor
		end
		highlight.FillColor = baseColor
	end

	--// Players
	local function destroyPlayerESP(player)
		local pname = player and player.Name or ""
		for _, obj in ipairs(CoreGui:GetChildren()) do
			if obj:IsA("BillboardGui") and obj.Name:find("Player_" .. pname) then obj:Destroy() end
			if obj:IsA("Highlight")   and obj.Name:find("Player_" .. pname) then obj:Destroy() end
		end
	end


	local function highlightCharacter(character, player)
		if scriptUnloaded then return end

		local espType = "Player"
		local color = Color3.fromRGB(255,255,0)
		local labelPrefix = "Player"

		if Teams and player.Team then
			espType = "Team"
			labelPrefix = "Team"
			if player.Team.TeamColor then
				color = player.Team.TeamColor.Color
			end
		end

		local highlight = getHighlight(character, color, labelPrefix)
		local billboard = ensureBillboard(character, labelPrefix)

		local function update()
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local health = humanoid and humanoid.Health or 0
			local tool = character and character:FindFirstChildOfClass("Tool")
			local toolName = (tool and tool.Name) or "None"
			local playerName = (player and player.Name) or "Unknown"
			local teamName = (player and player.Team and player.Team.Name) or "NoTeam"

			local textLabel = billboard and billboard:FindFirstChild("Info")
			if textLabel then
				if espType == "Team" then
					textLabel.Text = playerName .. " | Team:" .. teamName .. " | HP:" .. math.floor(health) .. " | Tool:" .. toolName
				else
					textLabel.Text = playerName .. " | HP:" .. math.floor(health) .. " | Tool:" .. toolName
				end
				textLabel.TextColor3 = Color3.fromRGB(255,255,255)
			end
		end

		update()
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.HealthChanged:Connect(update) end
			character.ChildAdded:Connect(function(child) if child:IsA("Tool") then update() end end)
			character.ChildRemoved:Connect(function(child) if child:IsA("Tool") then update() end end)
		end
	end

	local function isDealer(model)
		return model:IsA("Model") and (
			model.Name == "Dealer" or
			model.Name == "ArmoryDealer" or
			model.Name == "RebelDealer"
		)
	end

	local function createDealerESP(model)
		local baseColor
		if model.Name == "Dealer" then
			baseColor = Color3.fromRGB(0, 200, 0)      -- green
		elseif model.Name == "ArmoryDealer" then
			baseColor = Color3.fromRGB(0, 128, 255)    -- blue
		elseif model.Name == "RebelDealer" then
			baseColor = Color3.fromRGB(255, 0, 255)    -- magenta
		end

		local highlight = getHighlight(model, baseColor, model.Name)
		local billboard = ensureBillboard(model, model.Name)
		local textLabel = billboard and billboard:FindFirstChild("Info")
		if textLabel then
			textLabel.Text = model.Name
			textLabel.TextColor3 = baseColor
		end
	end

	--// Toggles
	--// Safe ESP
	local function ToggleSafeESP(state)
		if scriptUnloaded then return end
		if state then
			for _, child in ipairs(BredMakurz:GetDescendants()) do
				if child:IsA("Model") and (child.Name:find("SmallSafe") or child.Name:find("MediumSafe")) then
					highlightModel(child, Color3.fromRGB(0, 255, 0), "Safe") -- pass "Safe"
				end
			end
			if not safeConn then
				safeConn = BredMakurz.DescendantAdded:Connect(function(desc)
					if desc:IsA("Model") and (desc.Name:find("SmallSafe") or desc.Name:find("MediumSafe")) then
						highlightModel(desc, Color3.fromRGB(0, 255, 0), "Safe") -- pass "Safe"
					end
				end)
			end
		else
			if safeConn then safeConn:Disconnect(); safeConn = nil end
			for _, obj in ipairs(CoreGui:GetChildren()) do
				if (obj:IsA("BillboardGui") and obj.Name:find("Safe_") and obj.Name:find("_ESPBillboard"))
					or (obj:IsA("Highlight") and obj.Name:find("Safe_") and obj.Name:find("_ESPHighlight")) then
					obj:Destroy()
				end
			end
		end
	end

	--// Register ESP
	local function ToggleRegisterESP(state)
		if scriptUnloaded then return end
		if state then
			for _, child in ipairs(BredMakurz:GetDescendants()) do
				if child:IsA("Model") and child.Name:find("Register") == 1 then
					highlightModel(child, Color3.fromRGB(0, 255, 0), "Register") -- pass "Register"
				end
			end
			if not registerConn then
				registerConn = BredMakurz.DescendantAdded:Connect(function(desc)
					if desc:IsA("Model") and desc.Name:find("Register") == 1 then
						highlightModel(desc, Color3.fromRGB(0, 255, 0), "Register") -- pass "Register"
					end
				end)
			end
		else
			if registerConn then registerConn:Disconnect(); registerConn = nil end
			for _, obj in ipairs(CoreGui:GetChildren()) do
				if (obj:IsA("BillboardGui") and obj.Name:find("Register_") and obj.Name:find("_ESPBillboard"))
					or (obj:IsA("Highlight") and obj.Name:find("Register_") and obj.Name:find("_ESPHighlight")) then
					obj:Destroy()
				end
			end
		end
	end

	--// ATM ESP
	local function ToggleATMESP(state)
		if scriptUnloaded then return end
		if state then
			for _, child in ipairs(ATMz:GetDescendants()) do
				if child:IsA("Model") and child.Name:find("ATM") == 1 then
					highlightATM(child, Color3.fromRGB(0, 200, 255)) -- highlightATM now passes "ATM" internally
				end
			end
			if not atmConn then
				atmConn = ATMz.DescendantAdded:Connect(function(desc)
					if desc:IsA("Model") and desc.Name:find("ATM") == 1 then
						highlightATM(desc, Color3.fromRGB(0, 200, 255))
					end
				end)
			end
		else
			if atmConn then atmConn:Disconnect(); atmConn = nil end
			for _, obj in ipairs(CoreGui:GetChildren()) do
				if (obj:IsA("BillboardGui") and obj.Name:find("ATM_") and obj.Name:find("_ESPBillboard"))
					or (obj:IsA("Highlight") and obj.Name:find("ATM_") and obj.Name:find("_ESPHighlight")) then
					obj:Destroy()
				end
			end
		end
	end

	--// Dealer ESP
	local function ToggleDealerESP(state)
		if scriptUnloaded then return end
		if state then
			-- highlight all existing dealers
			for _, obj in ipairs(Shopz:GetDescendants()) do
				if isDealer(obj) then
					createDealerESP(obj)
				end
			end
			-- listen for new dealers spawning
			if not dealerConn then
				dealerConn = Shopz.DescendantAdded:Connect(function(obj)
					if isDealer(obj) then
						createDealerESP(obj)
					end
				end)
			end
		else
			if dealerConn then dealerConn:Disconnect(); dealerConn = nil end
			for _, obj in ipairs(CoreGui:GetChildren()) do
				if obj:IsA("BillboardGui") and (
					obj.Name:find("Dealer_") or
					obj.Name:find("ArmoryDealer_") or
					obj.Name:find("RebelDealer_")
				) then obj:Destroy() end
				if obj:IsA("Highlight") and (
					obj.Name:find("Dealer_") or
					obj.Name:find("ArmoryDealer_") or
					obj.Name:find("RebelDealer_")
				) then obj:Destroy() end
			end
		end
	end

	--// Crate ESP
	local function ToggleCrateESP(state)
		if scriptUnloaded then return end
		if state then
			for _, model in ipairs(SpawnedPiles:GetDescendants()) do
				if model:IsA("Model") and model.Name == "C1" then
					highlightCrate(model)
				end
			end
			if not crateConn then
				crateConn = SpawnedPiles.DescendantAdded:Connect(function(desc)
					if desc:IsA("Model") and desc.Name == "C1" then
						highlightCrate(desc)
					end
				end)
			end
		else
			if crateConn then crateConn:Disconnect(); crateConn = nil end
			for _, obj in ipairs(CoreGui:GetChildren()) do
				if (obj:IsA("BillboardGui") and (obj.Name:find("C1Red_") or obj.Name:find("C1Green_")) and obj.Name:find("_ESPBillboard"))
					or (obj:IsA("Highlight") and (obj.Name:find("C1Red_") or obj.Name:find("C1Green_")) and obj.Name:find("_ESPHighlight")) then
					obj:Destroy()
				end
			end
		end
	end

	local function TogglePlayerESP(state)
		if scriptUnloaded then return end
		if state then
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= Players.LocalPlayer then
					if player.Character then
						destroyPlayerESP(player)
						player.Character:WaitForChild("HumanoidRootPart", 3)
						highlightCharacter(player.Character, player)
					end
					if not charAddedConns[player] then
						charAddedConns[player] = player.CharacterAdded:Connect(function(character)
							destroyPlayerESP(player)
							character:WaitForChild("HumanoidRootPart", 3)
							highlightCharacter(character, player)
						end)
					end
				end
			end
			if not playerAddedConn then
				playerAddedConn = Players.PlayerAdded:Connect(function(player)
					if player ~= Players.LocalPlayer then
						if player.Character then
							destroyPlayerESP(player)
							player.Character:WaitForChild("HumanoidRootPart", 3)
							highlightCharacter(player.Character, player)
						end
						charAddedConns[player] = player.CharacterAdded:Connect(function(character)
							destroyPlayerESP(player)
							character:WaitForChild("HumanoidRootPart", 3)
							highlightCharacter(character, player)
						end)
					end
				end)
			end
		else
			for player, conn in pairs(charAddedConns) do
				if conn then conn:Disconnect() end
				charAddedConns[player] = nil
			end
			if playerAddedConn then playerAddedConn:Disconnect(); playerAddedConn = nil end
			for _, obj in ipairs(CoreGui:GetChildren()) do
				if obj:IsA("BillboardGui") and (obj.Name:find("Player_") or obj.Name:find("Team_")) then obj:Destroy() end
				if obj:IsA("Highlight")   and (obj.Name:find("Player_") or obj.Name:find("Team_")) then obj:Destroy() end
			end
		end
	end

	local function ToggleAutoLockpick(state)
		if scriptUnloaded then return end

		autoLockpickEnabled = state
		local DISTANCE_THRESHOLD = 10
		local GLOBAL_COOLDOWN = 0.35
		local lastClickTime = 0
		local charConn

		if state then
			if not autoLockpickThread then
				charConn = LocalPlayer.CharacterAdded:Connect(function() end)

				autoLockpickThread = task.spawn(function()
					local barOrder = {"B1","B2","B3"}
					local currentIndex = 1

					while autoLockpickEnabled and not scriptUnloaded do
						local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
						local humanoid = character and character:FindFirstChild("Humanoid")
						local hrp = character and character:FindFirstChild("HumanoidRootPart")
						local backpack = LocalPlayer:FindFirstChild("Backpack")

						if not humanoid or not hrp or humanoid.Health <= 0 then
							task.wait(0.2)
							continue
						end

						----------------------------------------------------
						-- find nearest valid (unbroken) safe or door
						----------------------------------------------------
						local nearestTarget, nearestDist, targetType
						-- Safes
						for _, model in ipairs(BredMakurz:GetChildren()) do
							if model:IsA("Model") and model.Name:find("Safe") then
								local values = model:FindFirstChild("Values")
								local broken = values and values:FindFirstChild("Broken")
								if broken and broken:IsA("BoolValue") and broken.Value then
									continue
								end
								local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
								if primary then
									local dist = (hrp.Position - primary.Position).Magnitude
									if not nearestDist or dist < nearestDist then
										nearestTarget, nearestDist, targetType = model, dist, "Safe"
									end
								end
							end
						end
						-- Doors
						for _, model in ipairs(Doors:GetChildren()) do
							if model:IsA("Model") then
								local values = model:FindFirstChild("Values")
								local broken = values and values:FindFirstChild("Broken")
								local open = values and values:FindFirstChild("Open")
								local locked = values and values:FindFirstChild("Locked")
								if (broken and broken.Value) or (open and open.Value) then
									continue
								end
								if locked and locked.Value then
									local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
									if primary then
										local dist = (hrp.Position - primary.Position).Magnitude
										if not nearestDist or dist < nearestDist then
											nearestTarget, nearestDist, targetType = model, dist, "Door"
										end
									end
								end
							end
						end

						----------------------------------------------------
						-- act on nearest target
						----------------------------------------------------
						if nearestTarget and nearestDist and nearestDist <= DISTANCE_THRESHOLD then
							local values = nearestTarget:FindFirstChild("Values")
							local broken = values and values:FindFirstChild("Broken")
							if broken and broken:IsA("BoolValue") and broken.Value then
								task.wait(0.2)
								continue
							end

							local lockpickTool, crowbar
							if backpack then
								for _, tool in ipairs(backpack:GetChildren()) do
									if tool:IsA("Tool") and tool.Name == "Lockpick" then
										lockpickTool = tool
									elseif tool:IsA("Tool") and tool.Name == "Crowbar" then
										crowbar = tool
									end
								end
							end
							crowbar = crowbar or (character and character:FindFirstChild("Crowbar"))

							if targetType == "Safe" then
								------------------------------------------------
								-- Safe logic: prioritize Lockpick, fallback Crowbar
								------------------------------------------------
								if lockpickTool then
									local currentTool = character:FindFirstChildWhichIsA("Tool")
									if currentTool ~= lockpickTool and humanoid then
										humanoid:EquipTool(lockpickTool)
									end
									local lockpickGUI = PlayerGui:WaitForChild("LockpickGUI", math.huge)
									currentIndex = 1
									while autoLockpickEnabled and not scriptUnloaded
										and lockpickGUI and lockpickGUI.Parent
										and lockpickGUI.Enabled do
										local values2 = nearestTarget:FindFirstChild("Values")
										local broken2 = values2 and values2:FindFirstChild("Broken")
										if broken2 and broken2.Value then break end
										local frames = lockpickGUI:FindFirstChild("MF")
											and lockpickGUI.MF:FindFirstChild("LP_Frame")
											and lockpickGUI.MF.LP_Frame:FindFirstChild("Frames")
										if frames then
											local barName = barOrder[currentIndex]
											local frame = frames:FindFirstChild(barName)
											if frame then
												local bar = frame:FindFirstChild("Bar")
												if bar and bar:IsA("ImageLabel") then
													bar.Size = UDim2.new(0, 9999999, 0, 9999999)
													bar.Visible = false
													local now = os.clock()
													if (now - lastClickTime) > GLOBAL_COOLDOWN then
														mouse1click()
														lastClickTime = now
														currentIndex = currentIndex % #barOrder + 1
													end
												end
											end
										end
										task.wait()
									end
								elseif crowbar then
									local currentTool = character:FindFirstChildWhichIsA("Tool")
									if currentTool ~= crowbar and humanoid then
										humanoid:EquipTool(crowbar)
									end
									local now = os.clock()
									if (now - lastClickTime) > GLOBAL_COOLDOWN then
										keypress(0x46)
										task.wait(0.1)
										keyrelease(0x46)
										lastClickTime = now
									end
								end
							elseif targetType == "Door" then
								------------------------------------------------
								-- Door logic: prioritize Crowbar, fallback Lockpick
								------------------------------------------------
								if crowbar then
									local currentTool = character:FindFirstChildWhichIsA("Tool")
									if currentTool ~= crowbar and humanoid then
										humanoid:EquipTool(crowbar)
									end
									local now = os.clock()
									if (now - lastClickTime) > GLOBAL_COOLDOWN then
										keypress(0x46)
										task.wait(0.1)
										keyrelease(0x46)
										lastClickTime = now
									end
								elseif lockpickTool then
									local currentTool = character:FindFirstChildWhichIsA("Tool")
									if currentTool ~= lockpickTool and humanoid then
										humanoid:EquipTool(lockpickTool)
									end
									local lockpickGUI = PlayerGui:WaitForChild("LockpickGUI", math.huge)
									currentIndex = 1
									while autoLockpickEnabled and not scriptUnloaded
										and lockpickGUI and lockpickGUI.Parent
										and lockpickGUI.Enabled do
										local values2 = nearestTarget:FindFirstChild("Values")
										local broken2 = values2 and values2:FindFirstChild("Broken")
										if broken2 and broken2.Value then break end
										local frames = lockpickGUI:FindFirstChild("MF")
											and lockpickGUI.MF:FindFirstChild("LP_Frame")
											and lockpickGUI.MF.LP_Frame:FindFirstChild("Frames")
										if frames then
											local barName = barOrder[currentIndex]
											local frame = frames:FindFirstChild(barName)
											if frame then
												local bar = frame:FindFirstChild("Bar")
												if bar and bar:IsA("ImageLabel") then
													bar.Size = UDim2.new(0, 500, 0, 500)
													bar.Visible = false
													local now = os.clock()
													if (now - lastClickTime) > GLOBAL_COOLDOWN then
														mouse1click()
														lastClickTime = now
														currentIndex = currentIndex % #barOrder + 1
													end
												end
											end
										end
										task.wait()
									end
								end
							end
						end

						task.wait(0.2)
					end
				end)
			end
		else
			if autoLockpickThread then
				task.cancel(autoLockpickThread)
				autoLockpickThread = nil
			end
			if charConn then
				charConn:Disconnect()
				charConn = nil
			end
		end
	end

	local function ToggleAutoBreakRegister(state)
		if scriptUnloaded then return end

		autoBreakEnabled = state
		local DISTANCE_THRESHOLD = 10
		local GLOBAL_COOLDOWN = 0.35
		local lastClickTime = 0

		if state then
			if not autoBreakThread then
				autoBreakThread = task.spawn(function()
					while autoBreakEnabled and not scriptUnloaded do
						local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
						local humanoid = character and character:FindFirstChild("Humanoid")
						local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
						local isDead = (not humanoid) or humanoid.Health <= 0

						if humanoidRootPart and not isDead then
							local nearestRegister, nearestDist
							for _, model in ipairs(BredMakurz:GetChildren()) do
								if model:IsA("Model") and model.Name:find("Register_") then
									local values = model:FindFirstChild("Values")
									local broken = values and values:FindFirstChild("Broken")
									if broken and broken:IsA("BoolValue") and broken.Value then
										continue
									end

									local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
									if primary then
										local dist = (humanoidRootPart.Position - primary.Position).Magnitude
										if not nearestDist or dist < nearestDist then
											nearestRegister, nearestDist = model, dist
										end
									end
								end
							end

							if nearestRegister and nearestDist and nearestDist <= DISTANCE_THRESHOLD then
								local backpack = LocalPlayer:FindFirstChild("Backpack")
								if backpack then
									local currentTool = character and character:FindFirstChildWhichIsA("Tool")
									local crowbar = (backpack and backpack:FindFirstChild("Crowbar")) or (character and character:FindFirstChild("Crowbar"))
									local fists = (backpack and backpack:FindFirstChild("Fists")) or (character and character:FindFirstChild("Fists"))
									local toolToUse

									if crowbar then
										toolToUse = crowbar
									elseif fists then
										toolToUse = fists
									end

									if toolToUse then
										if currentTool ~= toolToUse then
											humanoid:EquipTool(toolToUse)
										end

										local now = os.clock()
										if (now - lastClickTime) > GLOBAL_COOLDOWN then
											keypress(0x46)
											task.wait(0.1)
											keyrelease(0x46)
											lastClickTime = now
										end
									else
										Fluent:Notify({
											Title = "Auto Break Register",
											Content = "Fists or Crowbar not found",
											Duration = 5,
										})
										task.wait(1)
									end
								end
							end
						else
							local backpack = LocalPlayer:FindFirstChild("Backpack")
							if backpack then
								local fists = backpack:FindFirstChild("Fists")
								if fists then
									humanoid:EquipTool(fists)
								else
									Fluent:Notify({
										Title = "Auto Break Register",
										Content = "Fists or Crowbar not found",
										Duration = 5,
									})
									task.wait(1)
								end
							end
						end

						task.wait(0.2)
					end
				end)
			end
		else
			if autoBreakThread then
				task.cancel(autoBreakThread)
				autoBreakThread = nil
			end
		end
	end

	local fastWalkEnabled = false
	local fastWalkThread

	local function ToggleFastWalk(state)
		fastWalkEnabled = state
		if state then
			if not fastWalkThread then
				fastWalkThread = task.spawn(function()
					local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
					local Humanoid = Character:WaitForChild("Humanoid")
					while fastWalkEnabled and Character and Humanoid and Humanoid.Parent do
						local delta = RunService.Heartbeat:Wait()
						if Humanoid.MoveDirection.Magnitude > 0 then
							Character:TranslateBy(Humanoid.MoveDirection * delta * 10)
						end
					end
					fastWalkThread = nil
				end)
			end
		else
		end
	end


	local function UnloadESPs()
		-- Disconnect all connections first
		if safeConn then safeConn:Disconnect(); safeConn = nil end
		if registerConn then registerConn:Disconnect(); registerConn = nil end
		if atmConn then atmConn:Disconnect(); atmConn = nil end
		if crateConn then crateConn:Disconnect(); crateConn = nil end
		if playerAddedConn then playerAddedConn:Disconnect(); playerAddedConn = nil end

		for bb, conn in pairs(billboardConnections) do
			if conn then
				conn:Disconnect()
			end
			billboardConnections[bb] = nil
		end

		for player, conn in pairs(charAddedConns) do
			if conn then conn:Disconnect() end
			charAddedConns[player] = nil
		end

		-- Safely destroy all ESP objects
		local success, err = pcall(function()
			for _, obj in ipairs(CoreGui:GetChildren()) do
				-- Check if the object is valid before trying to check its properties or destroy it
				if obj and obj.Parent then
					if obj:IsA("BillboardGui") and obj.Name:find("_ESPBillboard") then
						obj:Destroy()
					elseif obj:IsA("Highlight") and obj.Name:find("_ESPHighlight") then
						obj:Destroy()
					end
				end
			end
		end)

		if not success then
			warn("Error during ESP cleanup: " .. tostring(err))
		end
	end

	--// UI

	local Window

	if IsOnMobile then
	Window = Fluent:CreateWindow({
		Title = "Criminality Simple Script",
		SubTitle = "by ustink4040",
		TabWidth = 160,
		Size = UDim2.fromOffset(200,300),
		Acrylic = false,
		Theme = "Darker",
		MinimizeKey = Enum.KeyCode.RightControl,
	})
	else
	Window = Fluent:CreateWindow({
		Title = "Criminality Simple Script",
		SubTitle = "by ustink4040",
		TabWidth = 160,
		Size = UDim2.fromOffset(580,460),
		Acrylic = false,
		Theme = "Darker",
		MinimizeKey = Enum.KeyCode.RightControl,
	})
	end

	for _, gui in ipairs(CoreGui:GetChildren()) do
		 if gui:IsA("ScreenGui") and gui.AbsoluteSize == Vector2.new(580,460) then
			 FluentMenu = gui
			 break
		 end
	end --// Find Menu
	
	local Tabs = {
		Information = Window:AddTab({Title = "Information", Icon = "info"}),
		Combat = Window:AddTab({Title = "Combat", Icon = "crosshair"}),
		Visuals = Window:AddTab({Title = "Visuals", Icon = "eye"}),
		Misc = Window:AddTab({Title = "Misc", Icon = "circle-ellipsis"}),
		Settings = Window:AddTab({Title = "Settings", Icon = "settings"}),
	}

	local Options = Fluent.Options

	--// Information Tab
	do
		Tabs.Information:AddParagraph({
			Title = "Criminality Simple Script",
			Content = "This is a script for Criminality",
		})
		local info = identifyexecutor()
		Tabs.Information:AddParagraph({ Title = "Executor Name",
			Content = type(info) == "table" and tostring(info.Name or "Unknown Executor") or tostring(info).." | All executors that is level 3+ or above are supported."
		})

		Tabs.Information:AddParagraph({ Title = "Game Version",
			Content = game.PlaceVersion and tostring(game.PlaceVersion) or "Unknown Version".. " | The place version of this game is calculated dynamically."
		})

		Tabs.Information:AddParagraph({ Title = "Update Notes",
			Content = [[
			- Initial Release
			]]
		})
	end
	--// Combat Tab
	do
		local CombatTab = Tabs.Combat
		local CombatSection = CombatTab:AddSection("Aimbot")

		CombatSection:AddToggle("Aimbot_Toggle", {
			Title = "Enable Aimbot",
			Default = false,
			Callback = function(Value)
				AimSettings.Enabled = Value
			end
		})

		CombatSection:AddToggle("Aimbot_TeamCheck", {
			Title = "Team Check",
			Default = AimSettings.TeamCheck,
			Callback = function(Value)
				AimSettings.TeamCheck = Value
			end
		})

		CombatSection:AddToggle("Aimbot_WallCheck", {
			Title = "Wall Check",
			Default = AimSettings.WallCheck,
			Callback = function(Value)
				AimSettings.WallCheck = Value
			end
		})

		CombatSection:AddDropdown("Aimbot_LockPart", {
			Title = "Lock Part",
			Values = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"},
			Default = AimSettings.LockPart,
			Callback = function(Value)
				AimSettings.LockPart = Value
			end
		})

		CombatSection:AddSlider("Aimbot_Sensitivity", {
			Title = "Sensitivity",
			Description = "Changes how fast the aimbot locks onto the target.",
			Min = 0,
			Max = 1,
			Default = AimSettings.Sensitivity,
			Rounding = 2,
			Callback = function(Value)
				AimSettings.Sensitivity = tonumber(Value)
			end
		})

		local FOVSection = CombatTab:AddSection("FOV Circle")

		FOVSection:AddToggle("FOV_Toggle", {
			Title = "Draw FOV",
			Default = AimFOV.Enabled,
			Callback = function(Value)
				AimFOV.Enabled = Value
			end
		})

		FOVSection:AddSlider("FOV_Radius", {
			Title = "FOV Radius",
			Description = "Changes the size of the FOV circle.",
			Min = 10,
			Max = 300,
			Default = AimFOV.Radius,
			Rounding = 0,
			Callback = function(Value)
				AimFOV.Radius = Value
			end
		})

		FOVSection:AddSlider("FOV_Thickness", {
			Title = "FOV Thickness",
			Description = "Changes the line thickness.",
			Min = 0.5,
			Max = 5,
			Default = AimFOV.Thickness,
			Rounding = 1,
			Callback = function(Value)
				AimFOV.Thickness = Value
			end
		})

		FOVSection:AddColorpicker("FOV_Color", {
			Title = "FOV Color",
			Default = AimFOV.Color,
			Callback = function(Value)
				AimFOV.Color = Value
			end
		})

		FOVSection:AddColorpicker("FOV_LockedColor", {
			Title = "Locked Target Color",
			Default = AimFOV.LockedColor,
			Callback = function(Value)
				AimFOV.LockedColor = Value
			end
		})
	end
	--// Visuals Tab
	do
		local VisualsTab = Tabs.Visuals
		local VisualsWorldSection = VisualsTab:AddSection("World")

		if currentMode == "Casual" or currentMode == "MCasual" or currentMode == "Standard" then
			-- Shared toggles
			VisualsWorldSection:AddToggle("Safe_ESP", {
				Title = "Safe ESP",
				Default = false,
				Callback = function(Value)
					ToggleSafeESP(Value)
				end
			})

			VisualsWorldSection:AddToggle("Register_ESP", {
				Title = "Register ESP",
				Default = false,
				Callback = function(Value)
					ToggleRegisterESP(Value)
				end
			})

			VisualsWorldSection:AddToggle("ATM_ESP", {
				Title = "ATM ESP",
				Default = false,
				Callback = function(Value)
					ToggleATMESP(Value)
				end
			})

			VisualsWorldSection:AddToggle("Dealer_ESP", {
				Title = "Dealer ESP",
				Default = false,
				Callback = function(Value)
					ToggleDealerESP(Value)
				end
			})

			if currentMode == "Standard" then
				VisualsWorldSection:AddToggle("Crate_ESP", {
					Title = "Crate ESP",
					Default = false,
					Callback = function(Value)
						ToggleCrateESP(Value)
					end
				})
			elseif currentMode == "Casual"  or currentMode == "MCasual" then
				VisualsWorldSection:AddParagraph({
					Title = "Crate ESP Unavailable",
					Content = "Crate ESP is only available in Standard mode.",
				})
			elseif currentMode == "Infection" or currentMode == "Brawl" then
				VisualsWorldSection:AddParagraph({
					Title = "Safe ESP Unavailable",
					Content = "Safe ESP is only available in Standard or Casual mode.",
				})

				VisualsWorldSection:AddParagraph({
					Title = "Register ESP Unavailable",
					Content = "Register ESP is only available in Standard or Casual mode.",
				})

				VisualsWorldSection:AddParagraph({
					Title = "ATM ESP Unavailable",
					Content = "ATM ESP is only available in Standard or Casual mode.",
				})

				VisualsWorldSection:AddParagraph({
					Title = "Dealer ESP Unavailable",
					Content = "Dealer ESP is only available in Standard or Casual mode.",
				})
			end
		else
			VisualsWorldSection:AddParagraph({
				Title = "ESPs Unavailable",
				Content = "Safe, Register, Dealer, and ATM ESP are only available in Casual and Standard modes.",
			})
		end

		local VisualsPlayersSection = VisualsTab:AddSection("Players")
			VisualsPlayersSection:AddToggle("Player_ESP", {
				Title = "Player ESP",
				Default = false,
				Callback = function(Value)
					TogglePlayerESP(Value)
				end
			})
	end

	-- whoever reverse engineer my script should go to hell

	--// Misc Tab
	do
		local MiscTab = Tabs.Misc
		local MiscSection = MiscTab:AddSection("Script")
		if currentMode == "Casual"  or currentMode == "MCasual" or currentMode == "Standard" or currentMode == "Infection" or currentMode == "Brawl" then
		MiscSection:AddButton({
			Title = "Return to Menu",
			Description = "Returns you to the main menu.",
			Callback = function()
				if not Events:WaitForChild("RCTNMEUN",100000) then
					Fluent:Notify({
						Title = "Cannot return to Menu",
						Content = "Event not found or the path has been changed. Please use in-game button.",
						Duration = 5,
					})
				else
					Fluent:Notify({
						Title = "Returning to Menu",
						Content = "Returning, please wait...",
						Duration = 3,
					})
					Events.RCTNMEUN:InvokeServer()
				end
			end
		})
		end
		local MiscWorld = MiscTab:AddSection("World")
		if currentMode == "Casual"  or currentMode == "MCasual" or currentMode == "Standard" then

			MiscWorld:AddToggle("Auto_Lockpick",{
				Title = "Auto Lockpick",
				Default = false,
				Callback = function(Value)
					ToggleAutoLockpick(Value)
				end
			})

			MiscWorld:AddToggle("Auto_BreakReg",{
				Title = "Auto Break Register",
				Default = false,
				Callback = function(Value)
					ToggleAutoBreakRegister(Value)
				end
			})
		end
		
			MiscWorld:AddToggle("Fast_Walk",{
				Title = "Fast Walk",
				Default = false,
				Callback = function(Value)
					ToggleFastWalk(Value)
				end
			})

			MiscWorld:AddButton({
				Title = "Infinite Stamina",
				CallBack = function()
					local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
					ReplicatedStorage:WaitForChild("Events2"):WaitForChild("GotStamina"):Destroy()
					ReplicatedStorage:WaitForChild("Events2"):WaitForChild("CantStamina"):Destroy()
					ReplicatedStorage:WaitForChild("Events2"):WaitForChild("StaminaChange"):Destroy()
				end
			})
	end

	local MobileConn = {}
	if IsOnMobile then
		Hidebuttons()
		local CRIM_01_BTN = Instance.new("ScreenGui")
		local TextButton = Instance.new("TextButton")
		local UICorner = Instance.new("UICorner")

		TextButton.Position = UDim2.new(0.396, 0,0, 0)
		TextButton.Size = UDim2.new(0.02, 0,0.034, 0)
		TextButton.Text = "TG"
		TextButton.Parent = CRIM_01_BTN
		UICorner.CornerRadius = UDim.new(1,0)
		UICorner.Parent = TextButton

		MobileConn[1] = TextButton.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				if FluentMenu then
					FluentMenu.Enabled = not FluentMenu.Enabled
				end
			end
		end)
	end

	--// Privacy protection
	task.spawn(function()
		local target
		repeat
			target = MainGui
			if not target then
				task.wait(1)
			end
		until target
		MainGui:WaitForChild("MFrame"):WaitForChild("DisplayNameLabel").Text = "[PROTECTED BY SCRIPT]"
	end)

	task.spawn(function()
		while not scriptUnloaded do
			for _, billboard in ipairs(CoreGui:GetChildren()) do
				if billboard:IsA("BillboardGui") and billboard.Name:find("_ESPBillboard") then
					if not billboard.Adornee or not billboard.Adornee.Parent then
						-- try to rebind adornee
						local targetName = billboard.Name:match("^(.-)_ESPBillboard")
						local target = workspace:FindFirstChild(targetName, true)
						if target then
							local adorneePart = target:FindFirstChild("HumanoidRootPart")
								or target:FindFirstChild("Head")
								or target:FindFirstChildWhichIsA("BasePart")
							if adorneePart then
								billboard.Adornee = adorneePart
							end
						end
					end
				end
			end
			task.wait(1) -- throttle for performance
		end
	end)
	
	--// Proper Unload Handling
	task.spawn(function()
		while task.wait(1) do
			if Fluent.Unloaded then
				if scriptUnloaded then
					return
				end
				scriptUnloaded = true

				-- Exit the aimbot
				if Aimbot and Aimbot.Exit then
					Aimbot:Exit()
				end

				for _, c in ipairs(MobileConn) do if c then c:Disconnect() end end

				-- Disconnect all ESP-related connections
				local function DisconnectESPConnections()
					if safeConn then safeConn:Disconnect(); safeConn = nil end
					if registerConn then registerConn:Disconnect(); registerConn = nil end
					if atmConn then atmConn:Disconnect(); atmConn = nil end
					if crateConn then crateConn:Disconnect(); crateConn = nil end
					if playerAddedConn then playerAddedConn:Disconnect(); playerAddedConn = nil end
					for player, conn in pairs(charAddedConns) do
						if conn then conn:Disconnect() end
						charAddedConns[player] = nil
					end
				end
				DisconnectESPConnections()

				-- Destroy all ESP objects
				UnloadESPs()
				break
			end
		end	
	end)

	SaveManager:SetLibrary(Fluent)
	InterfaceManager:SetLibrary(Fluent)

	SaveManager:IgnoreThemeSettings()

	SaveManager:SetIgnoreIndexes({})

	InterfaceManager:SetFolder("ustink4040Scripts")
	SaveManager:SetFolder("ustink4040Scripts/Criminality")

	InterfaceManager:BuildInterfaceSection(Tabs.Settings)
	SaveManager:BuildConfigSection(Tabs.Settings)


	Window:SelectTab(1)

	SaveManager:LoadAutoloadConfig()

