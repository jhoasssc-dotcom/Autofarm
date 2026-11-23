local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("CoinHubGui") then
	playerGui.CoinHubGui:Destroy()
end

-- ==========================================
-- CONFIGURAÇÕES
-- ==========================================
local ELITE_PASS_ID = 429957
local COINS_NO_ELITE = 40
local COINS_ELITE = 50
local MIN_DELAY = 0.5
local MAX_DELAY = 20.0
local MAX_TWEEN_SPEED = 40.0
local SKY_PLATFORM_Y = 650
local CACHE_REFRESH = 2.0

local AUTO_RESET_ENABLED = true

local running = false
local noclipEnabled = false
local mode = "TP" -- "TP" | "TWEEN" | "FARM_XP"
local tpDelay = 2.0
local tweenSpeed = 20.0

local needInitialTp = true
local lastCharacter = nil

local coinCache = {}
local lastCacheUpdate = 0
local currentTween = nil
local skyPlatform = nil
local cachedElite = nil
local visitedTpCoins = setmetatable({}, { __mode = "k" })

local function addCorner(parentObj, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parentObj
	return corner
end

-- ==========================================
-- INTERFACE (BOTÃO FLUTUANTE + PAINEL)
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CoinHubGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local floatBtn = Instance.new("TextButton")
floatBtn.Name = "FloatButton"
floatBtn.Size = UDim2.new(0, 56, 0, 56)
floatBtn.Position = UDim2.new(0.06, 0, 0.35, 0)
floatBtn.BackgroundColor3 = Color3.fromRGB(30, 32, 42)
floatBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
floatBtn.Text = "HUB"
floatBtn.Font = Enum.Font.GothamBold
floatBtn.TextSize = 13
floatBtn.Parent = screenGui
addCorner(floatBtn, UDim.new(1, 0))

local floatStroke = Instance.new("UIStroke")
floatStroke.Color = Color3.fromRGB(255, 200, 40)
floatStroke.Thickness = 2
floatStroke.Parent = floatBtn

local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = UDim2.new(0, 276, 0, 266)
panel.Position = UDim2.new(0.06, 66, 0.35, -55)
panel.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
panel.BorderSizePixel = 0
panel.Visible = true
panel.Parent = screenGui
addCorner(panel, UDim.new(0, 12))

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(60, 65, 85)
panelStroke.Thickness = 1.5
panelStroke.Parent = panel

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -16, 0, 22)
titleLabel.Position = UDim2.new(0, 8, 0, 6)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Coin & Murder Hub"
titleLabel.TextColor3 = Color3.fromRGB(240, 242, 248)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = panel

local tabsFrame = Instance.new("Frame")
tabsFrame.Size = UDim2.new(1, -16, 0, 30)
tabsFrame.Position = UDim2.new(0, 8, 0, 32)
tabsFrame.BackgroundTransparency = 1
tabsFrame.Parent = panel

local function makeTab(text, index)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.32, 0, 1, 0)
	btn.Position = UDim2.new((index - 1) * 0.34, 0, 0, 0)
	btn.BackgroundColor3 = Color3.fromRGB(38, 42, 58)
	btn.TextColor3 = Color3.fromRGB(220, 225, 240)
	btn.Text = text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.Parent = tabsFrame
	addCorner(btn, UDim.new(0, 7))
	return btn
end

local tabTP = makeTab("TP", 1)
local tabTween = makeTab("Tween", 2)
local tabFarm = makeTab("Farm XP", 3)

local modeBox = Instance.new("Frame")
modeBox.Size = UDim2.new(1, -16, 0, 78)
modeBox.Position = UDim2.new(0, 8, 0, 68)
modeBox.BackgroundColor3 = Color3.fromRGB(30, 33, 44)
modeBox.BorderSizePixel = 0
modeBox.Parent = panel
addCorner(modeBox, UDim.new(0, 8))

local sliderLabel = Instance.new("TextLabel")
sliderLabel.Size = UDim2.new(1, -12, 0, 18)
sliderLabel.Position = UDim2.new(0, 6, 0, 3)
sliderLabel.BackgroundTransparency = 1
sliderLabel.TextColor3 = Color3.fromRGB(215, 220, 235)
sliderLabel.Font = Enum.Font.GothamMedium
sliderLabel.TextSize = 11
sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
sliderLabel.Parent = modeBox

local sliderTrack = Instance.new("Frame")
sliderTrack.Size = UDim2.new(1, -16, 0, 12)
sliderTrack.Position = UDim2.new(0, 8, 0, 25)
sliderTrack.BackgroundColor3 = Color3.fromRGB(52, 58, 76)
sliderTrack.BorderSizePixel = 0
sliderTrack.Parent = modeBox
addCorner(sliderTrack, UDim.new(1, 0))

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(0.1, 0, 1, 0)
sliderFill.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderTrack
addCorner(sliderFill, UDim.new(1, 0))

local sliderKnob = Instance.new("TextButton")
sliderKnob.Size = UDim2.new(0, 20, 0, 20)
sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
sliderKnob.Position = UDim2.new(0.1, 0, 0.5, 0)
sliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sliderKnob.Text = ""
sliderKnob.Parent = sliderTrack
addCorner(sliderKnob, UDim.new(1, 0))

local farmSummary = Instance.new("TextLabel")
farmSummary.Size = UDim2.new(1, -12, 0, 32)
farmSummary.Position = UDim2.new(0, 6, 0, 43)
farmSummary.BackgroundTransparency = 1
farmSummary.TextColor3 = Color3.fromRGB(190, 210, 235)
farmSummary.Font = Enum.Font.Gotham
farmSummary.TextSize = 9.5
farmSummary.TextWrapped = true
farmSummary.TextXAlignment = Enum.TextXAlignment.Left
farmSummary.TextYAlignment = Enum.TextYAlignment.Center
farmSummary.Text = "Inocente: TP 1ª coin + Tween | Xerife: TP 1ª + Tween/Tiro | Murder: TP faca"
farmSummary.Visible = false
farmSummary.Parent = modeBox

local noclipBtn = Instance.new("TextButton")
noclipBtn.Size = UDim2.new(1, -16, 0, 32)
noclipBtn.Position = UDim2.new(0, 8, 0, 152)
noclipBtn.BackgroundColor3 = Color3.fromRGB(55, 62, 82)
noclipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
noclipBtn.Text = "Noclip: DESLIGADO"
noclipBtn.Font = Enum.Font.GothamBold
noclipBtn.TextSize = 12
noclipBtn.Parent = panel
addCorner(noclipBtn, UDim.new(0, 8))

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(1, -16, 0, 36)
toggleBtn.Position = UDim2.new(0, 8, 0, 190)
toggleBtn.BackgroundColor3 = Color3.fromRGB(175, 45, 55)
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Text = "DESLIGADO"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 13
toggleBtn.Parent = panel
addCorner(toggleBtn, UDim.new(0, 8))

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -16, 0, 30)
statusLabel.Position = UDim2.new(0, 8, 0, 230)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Pronto"
statusLabel.TextColor3 = Color3.fromRGB(170, 178, 198)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 10
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Parent = panel

-- ==========================================
-- NOCLIP (ATRAVESSAR PAREDES NAS 3 ÁREAS)
-- ==========================================
local function setCharacterNoclip(stateActive)
	local char = player.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = not stateActive
		end
	end
end

RunService.Stepped:Connect(function()
	if noclipEnabled then
		setCharacterNoclip(true)
	end
end)

noclipBtn.MouseButton1Click:Connect(function()
	noclipEnabled = not noclipEnabled
	if noclipEnabled then
		noclipBtn.BackgroundColor3 = Color3.fromRGB(45, 130, 215)
		noclipBtn.Text = "Noclip: LIGADO"
		setCharacterNoclip(true)
	else
		noclipBtn.BackgroundColor3 = Color3.fromRGB(55, 62, 82)
		noclipBtn.Text = "Noclip: DESLIGADO"
		setCharacterNoclip(false)
	end
end)

-- ==========================================
-- CONTROLES DE ABA, SLIDER E BOTÃO FLUTUANTE
-- ==========================================
local function refreshControls()
	sliderLabel.Visible = true
	sliderTrack.Visible = true

	if mode == "TP" then
		farmSummary.Visible = false
		sliderTrack.Position = UDim2.new(0, 8, 0, 34)
		local alpha = math.clamp((tpDelay - MIN_DELAY) / (MAX_DELAY - MIN_DELAY), 0, 1)
		sliderFill.Size = UDim2.new(alpha, 0, 1, 0)
		sliderKnob.Position = UDim2.new(alpha, 0, 0.5, 0)
		sliderLabel.Text = string.format("Pausa TP: %.1fs (0.5s - 20s)", tpDelay)
	elseif mode == "TWEEN" then
		farmSummary.Visible = false
		sliderTrack.Position = UDim2.new(0, 8, 0, 34)
		local alpha = math.clamp((tweenSpeed - 1.0) / (MAX_TWEEN_SPEED - 1.0), 0, 1)
		sliderFill.Size = UDim2.new(alpha, 0, 1, 0)
		sliderKnob.Position = UDim2.new(alpha, 0, 0.5, 0)
		sliderLabel.Text = string.format("Velocidade Tween: %.1f / 40", tweenSpeed)
	else
		farmSummary.Visible = true
		sliderTrack.Position = UDim2.new(0, 8, 0, 25)
		local alpha = math.clamp((tweenSpeed - 1.0) / (MAX_TWEEN_SPEED - 1.0), 0, 1)
		sliderFill.Size = UDim2.new(alpha, 0, 1, 0)
		sliderKnob.Position = UDim2.new(alpha, 0, 0.5, 0)
		sliderLabel.Text = string.format("Velocidade Farm XP: %.1f / 40", tweenSpeed)
	end
end

local function selectMode(newMode)
	mode = newMode
	needInitialTp = true
	if currentTween then
		pcall(function() currentTween:Cancel() end)
		currentTween = nil
	end

	local onColor = Color3.fromRGB(65, 135, 245)
	local offColor = Color3.fromRGB(38, 42, 58)

	tabTP.BackgroundColor3 = (mode == "TP") and onColor or offColor
	tabTween.BackgroundColor3 = (mode == "TWEEN") and onColor or offColor
	tabFarm.BackgroundColor3 = (mode == "FARM_XP") and onColor or offColor

	refreshControls()
	statusLabel.Text = "Status: Aba " .. mode .. " selecionada"
end

tabTP.MouseButton1Click:Connect(function() selectMode("TP") end)
tabTween.MouseButton1Click:Connect(function() selectMode("TWEEN") end)
tabFarm.MouseButton1Click:Connect(function() selectMode("FARM_XP") end)
selectMode("TP")

local draggingSlider = false

local function updateSliderFromX(xPos)
	local absX = sliderTrack.AbsolutePosition.X
	local absW = sliderTrack.AbsoluteSize.X
	if absW <= 0 then return end
	local alpha = math.clamp((xPos - absX) / absW, 0, 1)

	if mode == "TP" then
		local val = MIN_DELAY + (MAX_DELAY - MIN_DELAY) * alpha
		tpDelay = math.floor(val * 10 + 0.5) / 10
	else
		local val = 1.0 + (MAX_TWEEN_SPEED - 1.0) * alpha
		tweenSpeed = math.min(MAX_TWEEN_SPEED, math.floor(val * 10 + 0.5) / 10)
	end
	refreshControls()
end

sliderKnob.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingSlider = true
	end
end)

sliderTrack.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingSlider = true
		updateSliderFromX(input.Position.X)
	end
end)

local draggingFloat = false
local movedWhileDragging = false
local dragStartPos, floatStartPos

floatBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingFloat = true
		movedWhileDragging = false
		dragStartPos = input.Position
		floatStartPos = floatBtn.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		updateSliderFromX(input.Position.X)
	elseif draggingFloat and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStartPos
		if delta.Magnitude > 6 then
			movedWhileDragging = true
		end
		floatBtn.Position = UDim2.new(
			floatStartPos.X.Scale,
			floatStartPos.X.Offset + delta.X,
			floatStartPos.Y.Scale,
			floatStartPos.Y.Offset + delta.Y
		)
		panel.Position = UDim2.new(
			floatBtn.Position.X.Scale,
			floatBtn.Position.X.Offset + 66,
			floatBtn.Position.Y.Scale,
			floatBtn.Position.Y.Offset - 55
		)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingSlider = false
		if draggingFloat then
			draggingFloat = false
			if not movedWhileDragging then
				panel.Visible = not panel.Visible
			end
		end
	end
end)

toggleBtn.MouseButton1Click:Connect(function()
	running = not running
	if not running and currentTween then
		pcall(function() currentTween:Cancel() end)
		currentTween = nil
	end

	if running then
		-- Ao ativar, marca para teleportar apenas na primeira moeda e depois seguir por Tween
		needInitialTp = true
		toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 165, 90)
		toggleBtn.Text = "LIGADO"
		statusLabel.Text = "Status: Ligado (" .. mode .. ")"
	else
		toggleBtn.BackgroundColor3 = Color3.fromRGB(175, 45, 55)
		toggleBtn.Text = "DESLIGADO"
		statusLabel.Text = "Status: Desligado"
	end
end)

-- ==========================================
-- ELITE (ID 429957) & CONTAGEM DE BAG
-- ==========================================
local function ownsElitePass()
	if cachedElite ~= nil then
		return cachedElite
	end
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, ELITE_PASS_ID)
	end)
	cachedElite = (ok and result == true)
	return cachedElite
end

local function getCoinCapacity()
	return ownsElitePass() and COINS_ELITE or COINS_NO_ELITE
end

local function readBagCoinsCount()
	local limit = getCoinCapacity()

	for _, attrName in ipairs({ "Bag", "BagCoins", "RoundCoins", "CoinsBag" }) do
		local val = player:GetAttribute(attrName)
		local num = tonumber(val)
		if num and num >= 0 and num <= limit then
			return num
		end
	end

	for _, desc in ipairs(playerGui:GetDescendants()) do
		if desc:IsA("TextLabel") and not desc:IsDescendantOf(screenGui) then
			local txt = tostring(desc.Text or "")
			local curStr, maxStr = string.match(txt, "^%s*(%d+)%s*/%s*(%d+)%s*$")
			local curNum, maxNum = tonumber(curStr), tonumber(maxStr)
			if curNum and maxNum and (maxNum == COINS_NO_ELITE or maxNum == COINS_ELITE) then
				return curNum
			end
		end
	end

	return nil
end

local function handleBagLimitReset()
	if not AUTO_RESET_ENABLED then
		return false
	end

	local limit = getCoinCapacity()
	local current = readBagCoinsCount()
	if current ~= nil and current >= limit then
		statusLabel.Text = string.format("Bag cheia (%d/%d)! Resetando...", current, limit)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = 0
		end
		needInitialTp = true
		task.wait(2.5)
		return true
	end
	return false
end

-- ==========================================
-- BUSCA DE MOEDAS ("coin")
-- ==========================================
local function isCoinAvailable(part)
	if not part or not part:IsDescendantOf(workspace) then
		return false
	end
	if part.Transparency >= 0.95 then
		return false
	end
	return true
end

local function gatherCoinParts(node, outList, seenSet, charModel)
	if charModel and node:IsDescendantOf(charModel) then return end

	if node:IsA("BasePart") then
		if not seenSet[node] and node.Size.Magnitude < 25 and isCoinAvailable(node) then
			seenSet[node] = true
			table.insert(outList, node)
		end
	elseif node:IsA("Model") then
		for _, child in ipairs(node:GetDescendants()) do
			if child:IsA("BasePart") and not seenSet[child] and child.Size.Magnitude < 25 and isCoinAvailable(child) then
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

local function getClosestCoin(origin, charModel, ignoreRecentTp)
	local now = os.clock()
	if #coinCache == 0 or (now - lastCacheUpdate) >= CACHE_REFRESH then
		lastCacheUpdate = now
		rebuildCoinCache(charModel)
	end

	local bestPart = nil
	local bestDist = math.huge
	local fallbackPart = nil
	local fallbackDist = math.huge

	for i = #coinCache, 1, -1 do
		local p = coinCache[i]
		if not isCoinAvailable(p) then
			table.remove(coinCache, i)
		else
			local d = (p.Position - origin).Magnitude
			if d < fallbackDist then
				fallbackDist = d
				fallbackPart = p
			end

			local recentlyVisited = false
			if ignoreRecentTp then
				local lastVisit = visitedTpCoins[p]
				if lastVisit and (now - lastVisit) < 2.5 then
					recentlyVisited = true
				end
			end

			if not recentlyVisited and d < bestDist then
				bestDist = d
				bestPart = p
			end
		end
	end

	if bestPart then
		return bestPart, bestDist
	end
	return fallbackPart, fallbackDist
end

-- ==========================================
-- MOVIMENTO: TP & TWEEN (POR CIMA)
-- ==========================================
local function doSingleJump(charModel)
	local hum = charModel and charModel:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		pcall(function()
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
			hum.Jump = true
		end)
	end
end

local function teleportToPart(charModel, hrp, part, checkJumpIfNeeded)
	local coinsBefore = readBagCoinsCount()
	local targetCf = CFrame.new(part.Position + Vector3.new(0, 1.5, 0))
	pcall(function()
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		charModel:PivotTo(targetCf)
		hrp.CFrame = targetCf
	end)
	visitedTpCoins[part] = os.clock()

	if checkJumpIfNeeded then
		task.wait(0.12)
		local coinsAfter = readBagCoinsCount()
		local collectedByCount = (coinsBefore ~= nil and coinsAfter ~= nil and coinsAfter > coinsBefore)
		local stillThere = isCoinAvailable(part)
		if not collectedByCount and stillThere then
			doSingleJump(charModel)
			return true
		end
	end
	return false
end

local function flyAbovePart(hrp, part, stopCondition)
	if currentTween then
		pcall(function() currentTween:Cancel() end)
		currentTween = nil
	end

	local speed = math.clamp(tweenSpeed, 1, MAX_TWEEN_SPEED)
	local goalPos = part.Position + Vector3.new(0, 2.5, 0)
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
	while not done and running and isCoinAvailable(part) and (not stopCondition or stopCondition()) do
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
		statusLabel.Text = "XP Xerife: Aguardando Murder com faca..."
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

	statusLabel.Text = "XP Xerife: Atirando em " .. murder.Name .. "!"
end

local function tpSkyAfk(charModel, hrp)
	if not skyPlatform or not skyPlatform.Parent then
		local part = Instance.new("Part")
		part.Name = "SkyAfkPlatform_Hub"
		part.Size = Vector3.new(24, 2, 24)
		part.Anchored = true
		part.CanCollide = true
		part.Transparency = 0.35
		part.Material = Enum.Material.SmoothPlastic
		part.Position = Vector3.new(0, SKY_PLATFORM_Y, 0)
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
				statusLabel.Text = "XP Murder: TP em " .. plr.Name .. " (vivo + faca)"
				return true
			end
		end
	end
	statusLabel.Text = "XP Murder: Sem alvos vivos com faca"
	return false
end

-- ==========================================
-- LOOP PRINCIPAL
-- ==========================================
task.spawn(function()
	while true do
		if running then
			local charModel = player.Character
			if charModel ~= lastCharacter then
				lastCharacter = charModel
				needInitialTp = true
			end

			local hrp = charModel and charModel:FindFirstChild("HumanoidRootPart")

			if charModel and hrp then
				if mode == "TP" then
					local startTick = os.clock()
					if not handleBagLimitReset() then
						local coin, dist = getClosestCoin(hrp.Position, charModel, true)
						if coin then
							local jumped = teleportToPart(charModel, hrp, coin, true)
							local tag = jumped and "TP+Pulo" or "TP"
							statusLabel.Text = string.format("%s: %s (%.0f) | %.1fs", tag, coin.Name, dist, tpDelay)
						else
							statusLabel.Text = "TP: Nenhuma coin encontrada"
						end
					end
					local elapsed = os.clock() - startTick
					local remaining = math.max(0.05, tpDelay - elapsed)
					task.wait(remaining)

				elseif mode == "TWEEN" then
					if not handleBagLimitReset() then
						local coin, dist = getClosestCoin(hrp.Position, charModel, false)
						if coin then
							if needInitialTp then
								needInitialTp = false
								teleportToPart(charModel, hrp, coin, false)
								statusLabel.Text = string.format("TP 1ª coin -> Tween: %s", coin.Name)
								task.wait(0.15)
							else
								statusLabel.Text = string.format("Tween (%.1f): %s (%.0f)", tweenSpeed, coin.Name, dist)
								flyAbovePart(hrp, coin, function() return mode == "TWEEN" end)
							end
						else
							statusLabel.Text = "Tween: Nenhuma coin encontrada"
							task.wait(0.5)
						end
					else
						task.wait(1)
					end

				elseif mode == "FARM_XP" then
					local role = getMyRole()
					if role == "MURDER" then
						tpLivingKnifePlayers(charModel, hrp)
						task.wait(0.6)
					else
						local coin, dist = getClosestCoin(hrp.Position, charModel, false)
						if coin then
							if needInitialTp then
								needInitialTp = false
								teleportToPart(charModel, hrp, coin, false)
								statusLabel.Text = string.format("XP [%s] TP 1ª -> Tween: %s", role, coin.Name)
								task.wait(0.15)
							else
								statusLabel.Text = string.format("XP [%s] Tween (%.1f): %s", role, tweenSpeed, coin.Name)
								flyAbovePart(hrp, coin, function() return mode == "FARM_XP" end)
							end
						else
							if role == "SHERIFF" then
								fireAtMurder(charModel, hrp)
								task.wait(0.7)
							else
								tpSkyAfk(charModel, hrp)
								statusLabel.Text = "XP [Inocente]: Coins prontas, AFK no céu!"
								task.wait(1.5)
							end
						end
					end
				end
			else
				statusLabel.Text = "Aguardando personagem..."
				task.wait(0.5)
			end
		else
			task.wait(0.25)
		end
	end
end)
