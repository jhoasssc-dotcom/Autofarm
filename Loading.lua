local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CONFIG = {
	ELITE_PASS_ID = 429957,
	COINS_NO_ELITE = 40,
	COINS_ELITE = 50,
	MIN_DELAY = 0.5,
	MAX_DELAY = 20.0,
	MAX_TWEEN_SPEED = 21.0,
	SKY_PLATFORM_Y = 650,
	CACHE_REFRESH = 3.5,
}

local state = {
	running = false,
	mode = "TP", -- "TP" | "TWEEN" | "FARM_XP"
	tpDelay = 2.0,
	tweenSpeed = 16.0,
	panelOpen = true,
	draggingSlider = false,
	draggingBar = false,
	dragOffset = Vector2.zero,
}

local coinCache = {}
local lastCacheUpdate = 0
local currentTween = nil
local skyPlatform = nil

-- ==========================================
-- CRIAÇÃO SEGURA DA GUI (SEMPRE APARECE)
-- ==========================================
local gui, floatButton, mainFrame, topBar
local btnTabTP, btnTabTween, btnTabFarm
local modeBox, sliderLabel, sliderBg, sliderFill, sliderDot, farmSummary
local powerButton, statusText

pcall(function()
	local oldGui = playerGui:FindFirstChild("HubZeroGui")
	if oldGui then
		oldGui:Destroy()
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "HubZeroGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	floatButton = Instance.new("TextButton")
	floatButton.Name = "FloatToggle"
	floatButton.Size = UDim2.new(0, 60, 0, 60)
	floatButton.Position = UDim2.new(0.05, 0, 0.35, 0)
	floatButton.BackgroundColor3 = Color3.fromRGB(28, 30, 40)
	floatButton.TextColor3 = Color3.fromRGB(255, 210, 45)
	floatButton.Text = "HUB"
	floatButton.Font = Enum.Font.GothamBold
	floatButton.TextSize = 14
	floatButton.AutoButtonColor = true
	floatButton.ZIndex = 20
	floatButton.Parent = gui

	Instance.new("UICorner", floatButton).CornerRadius = UDim2.new(1, 0)
	local floatBorder = Instance.new("UIStroke", floatButton)
	floatBorder.Color = Color3.fromRGB(255, 200, 40)
	floatBorder.Thickness = 2

	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 272, 0, 228)
	mainFrame.Position = UDim2.new(0.05, 72, 0.35, -45)
	mainFrame.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = state.panelOpen
	mainFrame.ZIndex = 25
	mainFrame.Parent = gui

	Instance.new("UICorner", mainFrame).CornerRadius = UDim2.new(0, 12)
	local frameBorder = Instance.new("UIStroke", mainFrame)
	frameBorder.Color = Color3.fromRGB(65, 70, 92)
	frameBorder.Thickness = 1.5

	topBar = Instance.new("TextButton")
	topBar.Name = "DragTopBar"
	topBar.Size = UDim2.new(1, -16, 0, 24)
	topBar.Position = UDim2.new(0, 8, 0, 6)
	topBar.BackgroundTransparency = 1
	topBar.Text = "≡ Coin & Murder Hub"
	topBar.TextColor3 = Color3.fromRGB(240, 242, 248)
	topBar.Font = Enum.Font.GothamBold
	topBar.TextSize = 13
	topBar.TextXAlignment = Enum.TextXAlignment.Left
	topBar.ZIndex = 26
	topBar.Parent = mainFrame

	local tabsContainer = Instance.new("Frame")
	tabsContainer.Name = "TabsContainer"
	tabsContainer.Size = UDim2.new(1, -16, 0, 30)
	tabsContainer.Position = UDim2.new(0, 8, 0, 34)
	tabsContainer.BackgroundTransparency = 1
	tabsContainer.ZIndex = 26
	tabsContainer.Parent = mainFrame

	local function createTabButton(label, idx)
		local btn = Instance.new("TextButton")
		btn.Name = "Tab_" .. label
		btn.Size = UDim2.new(0.32, 0, 1, 0)
		btn.Position = UDim2.new((idx - 1) * 0.34, 0, 0, 0)
		btn.BackgroundColor3 = Color3.fromRGB(38, 42, 58)
		btn.TextColor3 = Color3.fromRGB(220, 225, 240)
		btn.Text = label
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 11
		btn.AutoButtonColor = true
		btn.ZIndex = 27
		btn.Parent = tabsContainer
		Instance.new("UICorner", btn).CornerRadius = UDim2.new(0, 7)
		return btn
	end

	btnTabTP = createTabButton("TP", 1)
	btnTabTween = createTabButton("Tween", 2)
	btnTabFarm = createTabButton("Farm XP", 3)

	modeBox = Instance.new("Frame")
	modeBox.Name = "ModeBox"
	modeBox.Size = UDim2.new(1, -16, 0, 52)
	modeBox.Position = UDim2.new(0, 8, 0, 70)
	modeBox.BackgroundColor3 = Color3.fromRGB(30, 33, 44)
	modeBox.BorderSizePixel = 0
	modeBox.ZIndex = 26
	modeBox.Parent = mainFrame
	Instance.new("UICorner", modeBox).CornerRadius = UDim2.new(0, 8)

	sliderLabel = Instance.new("TextLabel")
	sliderLabel.Name = "SliderLabel"
	sliderLabel.Size = UDim2.new(1, -12, 0, 20)
	sliderLabel.Position = UDim2.new(0, 6, 0, 3)
	sliderLabel.BackgroundTransparency = 1
	sliderLabel.TextColor3 = Color3.fromRGB(215, 220, 235)
	sliderLabel.Font = Enum.Font.GothamMedium
	sliderLabel.TextSize = 11
	sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
	sliderLabel.ZIndex = 27
	sliderLabel.Parent = modeBox

	sliderBg = Instance.new("TextButton")
	sliderBg.Name = "SliderBg"
	sliderBg.Size = UDim2.new(1, -16, 0, 12)
	sliderBg.Position = UDim2.new(0, 8, 0, 30)
	sliderBg.BackgroundColor3 = Color3.fromRGB(52, 58, 76)
	sliderBg.BorderSizePixel = 0
	sliderBg.Text = ""
	sliderBg.AutoButtonColor = false
	sliderBg.ZIndex = 27
	sliderBg.Parent = modeBox
	Instance.new("UICorner", sliderBg).CornerRadius = UDim2.new(1, 0)

	sliderFill = Instance.new("Frame")
	sliderFill.Name = "SliderFill"
	sliderFill.Size = UDim2.new(0.1, 0, 1, 0)
	sliderFill.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
	sliderFill.BorderSizePixel = 0
	sliderFill.ZIndex = 28
	sliderFill.Parent = sliderBg
	Instance.new("UICorner", sliderFill).CornerRadius = UDim2.new(1, 0)

	sliderDot = Instance.new("TextButton")
	sliderDot.Name = "SliderDot"
	sliderDot.Size = UDim2.new(0, 20, 0, 20)
	sliderDot.AnchorPoint = Vector2.new(0.5, 0.5)
	sliderDot.Position = UDim2.new(0.1, 0, 0.5, 0)
	sliderDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sliderDot.Text = ""
	sliderDot.AutoButtonColor = false
	sliderDot.ZIndex = 29
	sliderDot.Parent = sliderBg
	Instance.new("UICorner", sliderDot).CornerRadius = UDim2.new(1, 0)

	farmSummary = Instance.new("TextLabel")
	farmSummary.Name = "FarmSummary"
	farmSummary.Size = UDim2.new(1, -12, 1, -6)
	farmSummary.Position = UDim2.new(0, 6, 0, 3)
	farmSummary.BackgroundTransparency = 1
	farmSummary.TextColor3 = Color3.fromRGB(190, 210, 235)
	farmSummary.Font = Enum.Font.Gotham
	farmSummary.TextSize = 10
	farmSummary.TextWrapped = true
	farmSummary.TextXAlignment = Enum.TextXAlignment.Left
	farmSummary.TextYAlignment = Enum.TextYAlignment.Center
	farmSummary.Text = "Inocente: Coins + AFK alto | Xerife: Tiro no Murder | Murder: TP em quem tem faca (vivo)"
	farmSummary.Visible = false
	farmSummary.ZIndex = 27
	farmSummary.Parent = modeBox

	powerButton = Instance.new("TextButton")
	powerButton.Name = "PowerButton"
	powerButton.Size = UDim2.new(1, -16, 0, 36)
	powerButton.Position = UDim2.new(0, 8, 0, 130)
	powerButton.BackgroundColor3 = Color3.fromRGB(175, 45, 55)
	powerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	powerButton.Text = "DESLIGADO"
	powerButton.Font = Enum.Font.GothamBold
	powerButton.TextSize = 13
	powerButton.AutoButtonColor = true
	powerButton.ZIndex = 27
	powerButton.Parent = mainFrame
	Instance.new("UICorner", powerButton).CornerRadius = UDim2.new(0, 8)

	statusText = Instance.new("TextLabel")
	statusText.Name = "StatusText"
	statusText.Size = UDim2.new(1, -16, 0, 44)
	statusText.Position = UDim2.new(0, 8, 0, 174)
	statusText.BackgroundTransparency = 1
	statusText.Text = "Status: Pronto"
	statusText.TextColor3 = Color3.fromRGB(170, 178, 198)
	statusText.Font = Enum.Font.Gotham
	statusText.TextSize = 10
	statusText.TextWrapped = true
	statusText.TextXAlignment = Enum.TextXAlignment.Left
	statusText.TextYAlignment = Enum.TextYAlignment.Top
	statusText.ZIndex = 26
	statusText.Parent = mainFrame
end)

-- ==========================================
-- FUNÇÕES DE INTERFACE
-- ==========================================
local function refreshControls()
	if not sliderLabel or not sliderBg or not farmSummary then return end
	if state.mode == "TP" then
		sliderLabel.Visible = true
		sliderBg.Visible = true
		farmSummary.Visible = false

		local alpha = math.clamp((state.tpDelay - CONFIG.MIN_DELAY) / (CONFIG.MAX_DELAY - CONFIG.MIN_DELAY), 0, 1)
		sliderFill.Size = UDim2.new(alpha, 0, 1, 0)
		sliderDot.Position = UDim2.new(alpha, 0, 0.5, 0)
		sliderLabel.Text = string.format("Pausa TP: %.1fs (0.5s - 20s)", state.tpDelay)
	elseif state.mode == "TWEEN" then
		sliderLabel.Visible = true
		sliderBg.Visible = true
		farmSummary.Visible = false

		local alpha = math.clamp(state.tweenSpeed / CONFIG.MAX_TWEEN_SPEED, 0, 1)
		sliderFill.Size = UDim2.new(alpha, 0, 1, 0)
		sliderDot.Position = UDim2.new(alpha, 0, 0.5, 0)
		sliderLabel.Text = string.format("Velocidade Tween: %.1f / 21", state.tweenSpeed)
	else
		sliderLabel.Visible = false
		sliderBg.Visible = false
		farmSummary.Visible = true
	end
end

local function selectMode(newMode)
	state.mode = newMode
	if currentTween then
		pcall(function() currentTween:Cancel() end)
		currentTween = nil
	end

	local onColor = Color3.fromRGB(65, 135, 245)
	local offColor = Color3.fromRGB(38, 42, 58)

	if btnTabTP then btnTabTP.BackgroundColor3 = (newMode == "TP") and onColor or offColor end
	if btnTabTween then btnTabTween.BackgroundColor3 = (newMode == "TWEEN") and onColor or offColor end
	if btnTabFarm then btnTabFarm.BackgroundColor3 = (newMode == "FARM_XP") and onColor or offColor end

	refreshControls()
	if statusText then
		statusText.Text = "Status: Aba " .. newMode .. " selecionada"
	end
end

if btnTabTP then btnTabTP.MouseButton1Click:Connect(function() selectMode("TP") end) end
if btnTabTween then btnTabTween.MouseButton1Click:Connect(function() selectMode("TWEEN") end) end
if btnTabFarm then btnTabFarm.MouseButton1Click:Connect(function() selectMode("FARM_XP") end) end
selectMode("TP")

if floatButton and mainFrame then
	floatButton.MouseButton1Click:Connect(function()
		state.panelOpen = not state.panelOpen
		mainFrame.Visible = state.panelOpen
	end)
end

if topBar and mainFrame then
	topBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			state.draggingBar = true
			state.dragOffset = Vector2.new(
				input.Position.X - mainFrame.AbsolutePosition.X,
				input.Position.Y - mainFrame.AbsolutePosition.Y
			)
		end
	end)
end

local function applySliderAtX(xPos)
	if not sliderBg then return end
	local absX = sliderBg.AbsolutePosition.X
	local absW = sliderBg.AbsoluteSize.X
	if absW <= 0 then return end
	local alpha = math.clamp((xPos - absX) / absW, 0, 1)

	if state.mode == "TP" then
		local val = CONFIG.MIN_DELAY + (CONFIG.MAX_DELAY - CONFIG.MIN_DELAY) * alpha
		state.tpDelay = math.floor(val * 10 + 0.5) / 10
	elseif state.mode == "TWEEN" then
		local val = 1.0 + (CONFIG.MAX_TWEEN_SPEED - 1.0) * alpha
		state.tweenSpeed = math.min(CONFIG.MAX_TWEEN_SPEED, math.floor(val * 10 + 0.5) / 10)
	end
	refreshControls()
end

if sliderBg then
	sliderBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			state.draggingSlider = true
			applySliderAtX(input.Position.X)
		end
	end)
end

if sliderDot then
	sliderDot.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			state.draggingSlider = true
			applySliderAtX(input.Position.X)
		end
	end)
end

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		if state.draggingSlider then
			applySliderAtX(input.Position.X)
		elseif state.draggingBar and mainFrame then
			mainFrame.Position = UDim2.fromOffset(
				input.Position.X - state.dragOffset.X,
				input.Position.Y - state.dragOffset.Y
			)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		state.draggingSlider = false
		state.draggingBar = false
	end
end)

if powerButton then
	powerButton.MouseButton1Click:Connect(function()
		state.running = not state.running
		if not state.running and currentTween then
			pcall(function() currentTween:Cancel() end)
			currentTween = nil
		end

		if state.running then
			powerButton.BackgroundColor3 = Color3.fromRGB(40, 165, 90)
			powerButton.Text = "LIGADO"
			if statusText then statusText.Text = "Status: Ligado (" .. state.mode .. ")" end
		else
			powerButton.BackgroundColor3 = Color3.fromRGB(175, 45, 55)
			powerButton.Text = "DESLIGADO"
			if statusText then statusText.Text = "Status: Desligado" end
		end
	end)
end

-- ==========================================
-- GAMEPASS ELITE (ID 429957) & AUTO-RESET (40 / 50)
-- ==========================================
local cachedElite = nil

local function ownsElitePass()
	if cachedElite ~= nil then
		return cachedElite
	end
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, CONFIG.ELITE_PASS_ID)
	end)
	cachedElite = (ok and result == true)
	return cachedElite
end

local function getCoinCapacity()
	return ownsElitePass() and CONFIG.COINS_ELITE or CONFIG.COINS_NO_ELITE
end

local function readCoinCount()
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		for _, item in ipairs(ls:GetChildren()) do
			local lower = string.lower(item.Name)
			if string.find(lower, "coin") or string.find(lower, "bag") or string.find(lower, "moeda") then
				local num = tonumber(item.Value)
				if num then return num end
			end
		end
	end

	local attr = player:GetAttribute("Coins") or player:GetAttribute("Bag")
	if tonumber(attr) then
		return tonumber(attr)
	end

	for _, desc in ipairs(playerGui:GetDescendants()) do
		if desc:IsA("TextLabel") and (not gui or not desc:IsDescendantOf(gui)) then
			local pName = string.lower(desc.Parent and desc.Parent.Name or "")
			local dName = string.lower(desc.Name)
			if string.find(pName, "coin") or string.find(pName, "bag") or string.find(dName, "coin") or string.find(dName, "bag") then
				local digits = tonumber(string.match(desc.Text, "%d+"))
				if digits then return digits end
			end
		end
	end

	return nil
end

local function handleBagLimitReset()
	local limit = getCoinCapacity()
	local current = readCoinCount()
	if current and current >= limit then
		if statusText then
			statusText.Text = string.format("Bag cheia (%d/%d)! Resetando...", current, limit)
		end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = 0
		end
		task.wait(2.5)
		return true
	end
	return false
end

-- ==========================================
-- BUSCA DE MOEDAS ("coin")
-- ==========================================
local function gatherCoinParts(node, outList, seenSet, charModel)
	if charModel and node:IsDescendantOf(charModel) then return end

	if node:IsA("BasePart") then
		if not seenSet[node] and node.Size.Magnitude < 25 then
			seenSet[node] = true
			table.insert(outList, node)
		end
	elseif node:IsA("Model") then
		for _, child in ipairs(node:GetDescendants()) do
			if child:IsA("BasePart") and not seenSet[child] and child.Size.Magnitude < 25 then
				seenSet[child] = true
				table.insert(outList, child)
			end
		end
	end
end

local function rebuildCoinCache(charModel)
	local list = {}
	local seen = {}

	local folder = workspace:FindFirstChild("Coins") or workspace:FindFirstChild("CoinFolder") or workspace
	local entries = (folder ~= workspace) and folder:GetChildren() or workspace:GetDescendants()

	for _, entry in ipairs(entries) do
		if string.find(string.lower(entry.Name), "coin") then
			gatherCoinParts(entry, list, seen, charModel)
		end
	end

	coinCache = list
end

local function getClosestCoin(origin, charModel)
	local now = os.clock()
	if #coinCache == 0 or (now - lastCacheUpdate) >= CONFIG.CACHE_REFRESH then
		lastCacheUpdate = now
		rebuildCoinCache(charModel)
	end

	local bestPart = nil
	local bestDist = math.huge

	for i = #coinCache, 1, -1 do
		local p = coinCache[i]
		if not p or not p:IsDescendantOf(workspace) then
			table.remove(coinCache, i)
		else
			local d = (p.Position - origin).Magnitude
			if d < bestDist then
				bestDist = d
				bestPart = p
			end
		end
	end

	return bestPart, bestDist
end

-- ==========================================
-- MOVIMENTO: TP & TWEEN (ABAIXO DA MOEDA)
-- ==========================================
local function placeBelowPart(charModel, hrp, part)
	local targetCf = CFrame.new(part.Position - Vector3.new(0, 3.2, 0))
	pcall(function() charModel:PivotTo(targetCf) end)
	pcall(function()
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.CFrame = targetCf
	end)
end

local function flyBelowPart(hrp, part)
	if currentTween then
		pcall(function() currentTween:Cancel() end)
		currentTween = nil
	end

	local speed = math.clamp(state.tweenSpeed, 1, CONFIG.MAX_TWEEN_SPEED)
	local goalPos = part.Position - Vector3.new(0, 3.2, 0)
	local dist = (goalPos - hrp.Position).Magnitude
	local timeSec = math.max(0.05, dist / speed)

	local tw = TweenService:Create(
		hrp,
		TweenInfo.new(timeSec, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(goalPos) }
	)
	currentTween = tw

	local done = false
	tw.Completed:Connect(function()
		done = true
	end)

	tw:Play()
	while not done and state.running and state.mode == "TWEEN" and part:IsDescendantOf(workspace) do
		task.wait(0.05)
	end

	if not done then
		pcall(function() tw:Cancel() end)
	end
	if currentTween == tw then
		currentTween = nil
	end
end

-- ==========================================
-- FARM XP: INOCENTE, XERIFE E MURDER
-- ==========================================
local function isAlive(plr)
	local ch = plr.Character
	local hm = ch and ch:FindFirstChildOfClass("Humanoid")
	local rp = ch and ch:FindFirstChild("HumanoidRootPart")
	return hm and hm.Health > 0 and rp ~= nil
end

local function holdsKnife(plr)
	local ch = plr.Character
	if not ch then return false end
	for _, tool in ipairs(ch:GetChildren()) do
		if tool:IsA("Tool") then
			local n = string.lower(tool.Name)
			if string.find(n, "knife") or string.find(n, "faca") or string.find(n, "blade") then
				return true
			end
		end
	end
	return false
end

local function findGunTool()
	local ch = player.Character
	local bp = player:FindFirstChildOfClass("Backpack")
	local function search(container)
		if not container then return nil end
		for _, tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") then
				local n = string.lower(tool.Name)
				if string.find(n, "gun") or string.find(n, "revolver") or string.find(n, "pistol") or string.find(n, "arma") then
					return tool
				end
			end
		end
		return nil
	end
	return search(ch) or search(bp)
end

local function getMyRole()
	local ch = player.Character
	local bp = player:FindFirstChildOfClass("Backpack")

	for _, container in ipairs({ ch, bp }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") then
					local n = string.lower(tool.Name)
					if string.find(n, "knife") or string.find(n, "faca") then
						return "MURDER"
					end
				end
			end
		end
	end

	if findGunTool() then
		return "SHERIFF"
	end

	return "INNOCENT"
end

local function getLivingMurder()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player and isAlive(plr) and holdsKnife(plr) then
			return plr
		end
	end
	return nil
end

local function fireAtMurder(charModel, hrp)
	local murder = getLivingMurder()
	if not murder or not murder.Character then
		if statusText then statusText.Text = "XP Xerife: Aguardando Murder com faca..." end
		return
	end

	local mRoot = murder.Character:FindFirstChild("HumanoidRootPart")
	if not mRoot then return end

	hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(mRoot.Position.X, hrp.Position.Y, mRoot.Position.Z))

	local gun = findGunTool()
	local hum = charModel:FindFirstChildOfClass("Humanoid")
	if gun and gun.Parent == player:FindFirstChildOfClass("Backpack") and hum then
		hum:EquipTool(gun)
		task.wait(0.1)
	end

	if gun then
		pcall(function() gun:Activate() end)
		for _, rem in ipairs(gun:GetDescendants()) do
			if rem:IsA("RemoteEvent") then
				pcall(function() rem:FireServer(mRoot.Position, mRoot) end)
			end
		end
	end

	for _, rem in ipairs(ReplicatedStorage:GetDescendants()) do
		if rem:IsA("RemoteEvent") then
			local n = string.lower(rem.Name)
			if string.find(n, "shoot") or string.find(n, "fire") or string.find(n, "gun") or string.find(n, "tiro") then
				pcall(function() rem:FireServer(mRoot.Position, mRoot) end)
			end
		end
	end

	if statusText then statusText.Text = "XP Xerife: Atirando em " .. murder.Name .. "!" end
end

local function tpSkyAfk(charModel, hrp)
	if not skyPlatform or not skyPlatform.Parent then
		local part = Instance.new("Part")
		part.Name = "SkyAfkPlatform_Zero"
		part.Size = Vector3.new(24, 2, 24)
		part.Anchored = true
		part.CanCollide = true
		part.Transparency = 0.35
		part.Material = Enum.Material.SmoothPlastic
		part.Position = Vector3.new(0, CONFIG.SKY_PLATFORM_Y, 0)
		part.Parent = workspace
		skyPlatform = part
	end

	local cf = CFrame.new(skyPlatform.Position + Vector3.new(0, 4, 0))
	pcall(function() charModel:PivotTo(cf) end)
	pcall(function()
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.CFrame = cf
	end)
end

local function tpLivingKnifePlayers(charModel, hrp)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player and isAlive(plr) and holdsKnife(plr) then
			local tRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if tRoot then
				local cf = tRoot.CFrame * CFrame.new(0, 0, -2.2)
				pcall(function() charModel:PivotTo(cf) end)
				pcall(function() hrp.CFrame = cf end)
				if statusText then statusText.Text = "XP Murder: TP em " .. plr.Name .. " (vivo + faca)" end
				return true
			end
		end
	end
	if statusText then statusText.Text = "XP Murder: Sem alvos vivos com faca" end
	return false
end

-- ==========================================
-- LOOP PRINCIPAL
-- ==========================================
task.spawn(function()
	while true do
		if state.running then
			local charModel = player.Character
			local hrp = charModel and charModel:FindFirstChild("HumanoidRootPart")

			if charModel and hrp then
				if state.mode == "TP" then
					if not handleBagLimitReset() then
						local coin, dist = getClosestCoin(hrp.Position, charModel)
						if coin then
							placeBelowPart(charModel, hrp, coin)
							if statusText then
								statusText.Text = string.format("TP: %s (%.0f) | %.1fs", coin.Name, dist, state.tpDelay)
							end
						else
							if statusText then statusText.Text = "TP: Nenhuma coin encontrada" end
						end
					end
					task.wait(state.tpDelay)

				elseif state.mode == "TWEEN" then
					if not handleBagLimitReset() then
						local coin, dist = getClosestCoin(hrp.Position, charModel)
						if coin then
							if statusText then
								statusText.Text = string.format("Tween (%.1f): %s (%.0f)", state.tweenSpeed, coin.Name, dist)
							end
							flyBelowPart(hrp, coin)
						else
							if statusText then statusText.Text = "Tween: Nenhuma coin encontrada" end
							task.wait(0.5)
						end
					else
						task.wait(1)
					end

				elseif state.mode == "FARM_XP" then
					local role = getMyRole()
					if role == "MURDER" then
						tpLivingKnifePlayers(charModel, hrp)
						task.wait(0.6)
					else
						local coin, dist = getClosestCoin(hrp.Position, charModel)
						if coin then
							placeBelowPart(charModel, hrp, coin)
							if statusText then
								statusText.Text = string.format("XP [%s]: %s (%.0f)", role, coin.Name, dist)
							end
							task.wait(0.5)
						else
							if role == "SHERIFF" then
								fireAtMurder(charModel, hrp)
								task.wait(0.7)
							else
								tpSkyAfk(charModel, hrp)
								if statusText then statusText.Text = "XP [Inocente]: Coins prontas, AFK no céu!" end
								task.wait(1.5)
							end
						end
					end
				end
			else
				if statusText then statusText.Text = "Aguardando personagem..." end
				task.wait(0.5)
			end
		else
			task.wait(0.25)
		end
	end
end)
