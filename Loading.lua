local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

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

local modeRunning = {
	TP = false,
	TWEEN = false,
	FARM_XP = false,
}

local needInitialTpByMode = {
	TP = true,
	TWEEN = true,
	FARM_XP = true,
}

-- Opções da aba Settings
local farmEndMode = "TIME_END" -- "TIME_END" | "END_ROUND"
local autoGetGunEnabled = false
local autoShotMurderEnabled = false
local espEnabled = false

local noclipEnabled = false
local mode = "TP" -- "TP" | "TWEEN" | "FARM_XP" | "SETTINGS"
local tpDelay = 2.0
local tweenSpeed = 20.0

local lastCharacter = nil
local coinCache = {}
local lastCacheUpdate = 0
local currentTween = nil
local activeFlightGoal = nil
local skyPlatform = nil
local cachedElite = nil
local lastAutoGunTime = 0
local visitedTpCoins = setmetatable({}, { __mode = "k" })

-- Controle de papéis para ESP (Sheriff inicial vs Herói)
local initialSheriffUserId = nil
local sheriffHasDied = false
local heroUserIds = {}
local espHighlights = {}

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
panel.Size = UDim2.new(0, 290, 0, 286)
panel.Position = UDim2.new(0.06, 66, 0.35, -65)
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

-- 4 Abas (TP, Tween, Farm XP, Settings)
local tabsFrame = Instance.new("Frame")
tabsFrame.Size = UDim2.new(1, -16, 0, 28)
tabsFrame.Position = UDim2.new(0, 8, 0, 30)
tabsFrame.BackgroundTransparency = 1
tabsFrame.Parent = panel

local function makeTab(text, index, total)
	local gap = 0.02
	local width = (1 - gap * (total - 1)) / total
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(width, 0, 1, 0)
	btn.Position = UDim2.new((index - 1) * (width + gap), 0, 0, 0)
	btn.BackgroundColor3 = Color3.fromRGB(38, 42, 58)
	btn.TextColor3 = Color3.fromRGB(220, 225, 240)
	btn.Text = text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 10
	btn.Parent = tabsFrame
	addCorner(btn, UDim.new(0, 7))
	return btn
end

local tabTP = makeTab("TP", 1, 4)
local tabTween = makeTab("Tween", 2, 4)
local tabFarm = makeTab("Farm XP", 3, 4)
local tabSettings = makeTab("Settings", 4, 4)

-- Área dinâmica para TP / Tween / Farm XP
local modeBox = Instance.new("Frame")
modeBox.Size = UDim2.new(1, -16, 0, 80)
modeBox.Position = UDim2.new(0, 8, 0, 64)
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
farmSummary.Text = "Inocente: TP 1ª coin + Tween reto | Xerife: Tween + Tiro | Murder: TP faca"
farmSummary.Visible = false
farmSummary.Parent = modeBox

-- Container da aba Settings
local settingsBox = Instance.new("ScrollingFrame")
settingsBox.Name = "SettingsBox"
settingsBox.Size = UDim2.new(1, -16, 0, 136)
settingsBox.Position = UDim2.new(0, 8, 0, 64)
settingsBox.BackgroundColor3 = Color3.fromRGB(28, 31, 42)
settingsBox.BorderSizePixel = 0
settingsBox.ScrollBarThickness = 4
settingsBox.CanvasSize = UDim2.new(0, 0, 0, 232)
settingsBox.Visible = false
settingsBox.Parent = panel
addCorner(settingsBox, UDim.new(0, 8))

-- Opção 1: Alternância XP Farm ("Time end" / "End round")
local lblFarmEnd = Instance.new("TextLabel")
lblFarmEnd.Size = UDim2.new(1, -12, 0, 18)
lblFarmEnd.Position = UDim2.new(0, 6, 0, 6)
lblFarmEnd.BackgroundTransparency = 1
lblFarmEnd.Text = "XP Farm ao concluir / bag cheia:"
lblFarmEnd.TextColor3 = Color3.fromRGB(220, 225, 240)
lblFarmEnd.Font = Enum.Font.GothamBold
lblFarmEnd.TextSize = 10.5
lblFarmEnd.TextXAlignment = Enum.TextXAlignment.Left
lblFarmEnd.Parent = settingsBox

local btnFarmEndToggle = Instance.new("TextButton")
btnFarmEndToggle.Size = UDim2.new(1, -12, 0, 28)
btnFarmEndToggle.Position = UDim2.new(0, 6, 0, 26)
btnFarmEndToggle.BackgroundColor3 = Color3.fromRGB(52, 92, 168)
btnFarmEndToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
btnFarmEndToggle.Text = "XP Farm: Time end"
btnFarmEndToggle.Font = Enum.Font.GothamBold
btnFarmEndToggle.TextSize = 11
btnFarmEndToggle.Parent = settingsBox
addCorner(btnFarmEndToggle, UDim.new(0, 7))

-- Opção 2: Auto Get Gun
local btnAutoGun = Instance.new("TextButton")
btnAutoGun.Size = UDim2.new(1, -12, 0, 28)
btnAutoGun.Position = UDim2.new(0, 6, 0, 60)
btnAutoGun.BackgroundColor3 = Color3.fromRGB(55, 62, 82)
btnAutoGun.TextColor3 = Color3.fromRGB(255, 255, 255)
btnAutoGun.Text = "Auto Get Gun: DESLIGADO"
btnAutoGun.Font = Enum.Font.GothamBold
btnAutoGun.TextSize = 11
btnAutoGun.Parent = settingsBox
addCorner(btnAutoGun, UDim.new(0, 7))

-- Opção 3: Auto Shot Murder
local btnAutoShotMurder = Instance.new("TextButton")
btnAutoShotMurder.Size = UDim2.new(1, -12, 0, 28)
btnAutoShotMurder.Position = UDim2.new(0, 6, 0, 94)
btnAutoShotMurder.BackgroundColor3 = Color3.fromRGB(55, 62, 82)
btnAutoShotMurder.TextColor3 = Color3.fromRGB(255, 255, 255)
btnAutoShotMurder.Text = "Auto Shot Murder: DESLIGADO"
btnAutoShotMurder.Font = Enum.Font.GothamBold
btnAutoShotMurder.TextSize = 11
btnAutoShotMurder.Parent = settingsBox
addCorner(btnAutoShotMurder, UDim.new(0, 7))

-- Opção 4: ESP
local btnEsp = Instance.new("TextButton")
btnEsp.Size = UDim2.new(1, -12, 0, 28)
btnEsp.Position = UDim2.new(0, 6, 0, 128)
btnEsp.BackgroundColor3 = Color3.fromRGB(55, 62, 82)
btnEsp.TextColor3 = Color3.fromRGB(255, 255, 255)
btnEsp.Text = "ESP: DESLIGADO"
btnEsp.Font = Enum.Font.GothamBold
btnEsp.TextSize = 11
btnEsp.Parent = settingsBox
addCorner(btnEsp, UDim.new(0, 7))

local lblSettingsInfo = Instance.new("TextLabel")
lblSettingsInfo.Size = UDim2.new(1, -12, 0, 56)
lblSettingsInfo.Position = UDim2.new(0, 6, 0, 162)
lblSettingsInfo.BackgroundTransparency = 1
lblSettingsInfo.Text = "ESP: Vermelho = Murder | Azul = Sheriff | Verde = Inocente | Amarelo = Herói | Cinza = Morto"
lblSettingsInfo.TextColor3 = Color3.fromRGB(175, 185, 210)
lblSettingsInfo.Font = Enum.Font.Gotham
lblSettingsInfo.TextSize = 9.5
lblSettingsInfo.TextWrapped = true
lblSettingsInfo.TextXAlignment = Enum.TextXAlignment.Left
lblSettingsInfo.Parent = settingsBox

-- Botão Noclip
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

-- Botão Liga / Desliga
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(1, -16, 0, 36)
toggleBtn.Position = UDim2.new(0, 8, 0, 208)
toggleBtn.BackgroundColor3 = Color3.fromRGB(175, 45, 55)
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Text = "DESLIGADO"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 13
toggleBtn.Parent = panel
addCorner(toggleBtn, UDim.new(0, 8))

-- Status inferior
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -16, 0, 32)
statusLabel.Position = UDim2.new(0, 8, 0, 248)
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
-- BOTÃO RETANGULAR MÓVEL "Shot murder"
-- ==========================================
local shotMurderBtn = Instance.new("TextButton")
shotMurderBtn.Name = "ShotMurderButton"
shotMurderBtn.Size = UDim2.new(0, 132, 0, 44)
shotMurderBtn.Position = UDim2.new(0.68, 0, 0.62, 0)
shotMurderBtn.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
shotMurderBtn.BackgroundTransparency = 0.65
shotMurderBtn.BorderSizePixel = 0
shotMurderBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
shotMurderBtn.Text = "Shot murder"
shotMurderBtn.Font = Enum.Font.GothamBold
shotMurderBtn.TextSize = 14
shotMurderBtn.Visible = false
shotMurderBtn.ZIndex = 35
shotMurderBtn.Parent = screenGui
addCorner(shotMurderBtn, UDim.new(0, 8))

local shotMurderStroke = Instance.new("UIStroke")
shotMurderStroke.Color = Color3.fromRGB(0, 0, 0)
shotMurderStroke.Thickness = 2.5
shotMurderStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
shotMurderStroke.Parent = shotMurderBtn

local function refreshShotMurderButtonVisibility()
	shotMurderBtn.Visible = autoShotMurderEnabled
end

-- ==========================================
-- PAPÉIS, ARMA ("Gun"), MURDER, TIRO E FLING
-- ==========================================
local function isAlive(plr)
	local ch = plr and plr.Character
	local hm = ch and ch:FindFirstChildOfClass("Humanoid")
	local rp = ch and ch:FindFirstChild("HumanoidRootPart")
	return hm and hm.Health > 0 and rp ~= nil
end

local function holdsKnife(plr)
	local ch = plr and plr.Character
	local bp = plr and plr:FindFirstChildOfClass("Backpack")
	for _, container in ipairs({ ch, bp }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") then
					local n = string.lower(tool.Name)
					if string.find(n, "knife") or string.find(n, "faca") or string.find(n, "blade") then
						return true
					end
				end
			end
		end
	end
	return false
end

local function isGunToolName(toolName)
	local n = string.lower(tostring(toolName or ""))
	return n == "gun"
		or string.find(n, "gun", 1, true) ~= nil
		or string.find(n, "revolver", 1, true) ~= nil
		or string.find(n, "pistol", 1, true) ~= nil
		or string.find(n, "arma", 1, true) ~= nil
end

local function playerHasGun(plr)
	if not plr then return false end
	local ch = plr.Character
	local bp = plr:FindFirstChildOfClass("Backpack")
	for _, container in ipairs({ ch, bp }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and isGunToolName(tool.Name) then
					return true
				end
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
			if tool:IsA("Tool") and string.lower(tool.Name) == "gun" then
				return tool
			end
		end
		for _, tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") and isGunToolName(tool.Name) then
				return tool
			end
		end
		return nil
	end
	return search(ch) or search(bp)
end

local function getMyRole()
	if holdsKnife(player) then
		return "MURDER"
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

local function shootAtTargetPart(charModel, hrp, targetPart)
	if not charModel or not hrp or not targetPart then return false end

	local gun = findGunTool()
	if not gun then
		return false, "no_gun"
	end

	local hum = charModel:FindFirstChildOfClass("Humanoid")
	if gun.Parent ~= charModel and hum then
		pcall(function() hum:EquipTool(gun) end)
		local waitStart = os.clock()
		while gun.Parent ~= charModel and (os.clock() - waitStart) < 0.35 do
			task.wait(0.03)
		end
	end

	local aimPos = targetPart.Position
	local lookCf = CFrame.lookAt(hrp.Position, Vector3.new(aimPos.X, hrp.Position.Y, aimPos.Z))
	pcall(function()
		hrp.CFrame = lookCf
	end)

	-- Disparo via Tool:Activate() + RemoteEvents da Gun e do jogo
	pcall(function()
		gun:Activate()
	end)

	for _, rem in ipairs(gun:GetDescendants()) do
		if rem:IsA("RemoteEvent") then
			pcall(function() rem:FireServer(aimPos, targetPart) end)
			pcall(function() rem:FireServer(targetPart.CFrame) end)
			pcall(function() rem:FireServer(aimPos) end)
		end
	end

	for _, rem in ipairs(ReplicatedStorage:GetDescendants()) do
		if rem:IsA("RemoteEvent") then
			local n = string.lower(rem.Name)
			if string.find(n, "shoot", 1, true)
				or string.find(n, "fire", 1, true)
				or string.find(n, "gun", 1, true)
				or string.find(n, "bullet", 1, true)
				or string.find(n, "tiro", 1, true)
			then
				pcall(function() rem:FireServer(aimPos, targetPart) end)
				pcall(function() rem:FireServer(targetPart.CFrame) end)
				pcall(function() rem:FireServer(aimPos) end)
			end
		end
	end

	-- Fallback de clique na tela/centro para armas baseadas em input/mouse
	pcall(function()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
		local cx, cy = math.floor(vp.X * 0.5), math.floor(vp.Y * 0.5)
		VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
		task.wait(0.03)
		VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
	end)

	return true, "ok"
end

local function triggerShotMurderButtonAction()
	local charModel = player.Character
	local hrp = charModel and charModel:FindFirstChild("HumanoidRootPart")
	local gun = findGunTool()
	if not gun then
		statusLabel.Text = "Shot murder: Gun não encontrada no inventário!"
		return
	end

	local murder = getLivingMurder()
	if not murder or not murder.Character then
		statusLabel.Text = "Shot murder: Murder não encontrado"
		return
	end

	local mRoot = murder.Character:FindFirstChild("HumanoidRootPart")
	if mRoot and charModel and hrp then
		local ok = shootAtTargetPart(charModel, hrp, mRoot)
		if ok then
			statusLabel.Text = "Shot murder: Disparou em " .. murder.Name .. "!"
		else
			statusLabel.Text = "Shot murder: Falha ao disparar"
		end
	end
end

-- ==========================================
-- ESP (VIVOS POR FUNÇÃO + MORTOS EM CINZA)
-- ==========================================
local function clearAllEsp()
	for plr, hl in pairs(espHighlights) do
		if hl and hl.Parent then
			pcall(function() hl:Destroy() end)
		end
		espHighlights[plr] = nil
	end
end

local function syncRoleTracking()
	if initialSheriffUserId == nil then
		for _, plr in ipairs(Players:GetPlayers()) do
			if isAlive(plr) and playerHasGun(plr) then
				initialSheriffUserId = plr.UserId
				break
			end
		end
	else
		local sheriffPlr = Players:GetPlayerByUserId(initialSheriffUserId)
		if not sheriffPlr or not isAlive(sheriffPlr) then
			sheriffHasDied = true
		end
	end

	for _, plr in ipairs(Players:GetPlayers()) do
		if isAlive(plr) and playerHasGun(plr) then
			if initialSheriffUserId == nil or (plr.UserId ~= initialSheriffUserId and sheriffHasDied) then
				heroUserIds[plr.UserId] = true
			end
		end
	end
end

local function getEspStyleForPlayer(plr)
	if not isAlive(plr) then
		return Color3.fromRGB(155, 160, 170), 0.72, 0.35 -- Morto (Dead): Cinza
	end

	if holdsKnife(plr) then
		return Color3.fromRGB(235, 45, 55), 0.42, 0.05 -- Murder: Vermelho
	end

	if heroUserIds[plr.UserId] then
		return Color3.fromRGB(255, 215, 35), 0.42, 0.05 -- Herói: Amarelo
	end

	if playerHasGun(plr) or plr.UserId == initialSheriffUserId then
		return Color3.fromRGB(45, 130, 255), 0.42, 0.05 -- Sheriff: Azul
	end

	return Color3.fromRGB(45, 215, 95), 0.42, 0.05 -- Inocente: Verde
end

local function updateEspHighlights()
	if not espEnabled then
		clearAllEsp()
		return
	end

	syncRoleTracking()

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			local charModel = plr.Character
			if charModel and charModel.Parent then
				local hl = espHighlights[plr]
				if not hl or not hl.Parent or hl.Adornee ~= charModel then
					if hl and hl.Parent then
						pcall(function() hl:Destroy() end)
					end
					hl = Instance.new("Highlight")
					hl.Name = "RoleEspHighlight"
					hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					hl.Adornee = charModel
					hl.Parent = charModel
					espHighlights[plr] = hl
				end

				local color, fillTransp, outlineTransp = getEspStyleForPlayer(plr)
				hl.FillColor = color
				hl.OutlineColor = color
				hl.FillTransparency = fillTransp
				hl.OutlineTransparency = outlineTransp
			else
				local hl = espHighlights[plr]
				if hl and hl.Parent then
					pcall(function() hl:Destroy() end)
				end
				espHighlights[plr] = nil
			end
		end
	end
end

Players.PlayerRemoving:Connect(function(plr)
	local hl = espHighlights[plr]
	if hl and hl.Parent then
		pcall(function() hl:Destroy() end)
	end
	espHighlights[plr] = nil
	heroUserIds[plr.UserId] = nil
	if initialSheriffUserId == plr.UserId then
		sheriffHasDied = true
	end
end)

RunService.RenderStepped:Connect(function()
	if espEnabled then
		updateEspHighlights()
	end
end)

-- ==========================================
-- NOCLIP & ESTABILIZAÇÃO DE VELOCIDADE
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

RunService.Heartbeat:Connect(function()
	if currentTween and activeFlightGoal then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			pcall(function()
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
			end)
		end
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
-- CONTROLES DE ABA, SETTINGS, SLIDER E BOTÃO FLUTUANTE
-- ==========================================
local function syncPowerButtonVisual()
	if mode == "SETTINGS" then
		toggleBtn.Visible = false
		return
	end
	toggleBtn.Visible = true
	if modeRunning[mode] then
		toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 165, 90)
		toggleBtn.Text = "LIGADO (" .. mode .. ")"
	else
		toggleBtn.BackgroundColor3 = Color3.fromRGB(175, 45, 55)
		toggleBtn.Text = "DESLIGADO (" .. mode .. ")"
	end
end

local function refreshControls()
	if mode == "SETTINGS" then
		modeBox.Visible = false
		noclipBtn.Visible = false
		settingsBox.Visible = true
		return
	end

	modeBox.Visible = true
	noclipBtn.Visible = true
	settingsBox.Visible = false
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
	elseif mode == "FARM_XP" then
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
	if currentTween then
		pcall(function() currentTween:Cancel() end)
		currentTween = nil
		activeFlightGoal = nil
	end

	local onColor = Color3.fromRGB(65, 135, 245)
	local offColor = Color3.fromRGB(38, 42, 58)

	tabTP.BackgroundColor3 = (mode == "TP") and onColor or offColor
	tabTween.BackgroundColor3 = (mode == "TWEEN") and onColor or offColor
	tabFarm.BackgroundColor3 = (mode == "FARM_XP") and onColor or offColor
	tabSettings.BackgroundColor3 = (mode == "SETTINGS") and onColor or offColor

	refreshControls()
	syncPowerButtonVisual()

	if mode == "SETTINGS" then
		statusLabel.Text = "Aba Settings ativa"
	else
		statusLabel.Text = string.format("Aba %s (%s)", mode, modeRunning[mode] and "LIGADO" or "DESLIGADO")
	end
end

tabTP.MouseButton1Click:Connect(function() selectMode("TP") end)
tabTween.MouseButton1Click:Connect(function() selectMode("TWEEN") end)
tabFarm.MouseButton1Click:Connect(function() selectMode("FARM_XP") end)
tabSettings.MouseButton1Click:Connect(function() selectMode("SETTINGS") end)
selectMode("TP")

btnFarmEndToggle.MouseButton1Click:Connect(function()
	if farmEndMode == "TIME_END" then
		farmEndMode = "END_ROUND"
		btnFarmEndToggle.Text = "XP Farm: End round"
		btnFarmEndToggle.BackgroundColor3 = Color3.fromRGB(168, 62, 62)
	else
		farmEndMode = "TIME_END"
		btnFarmEndToggle.Text = "XP Farm: Time end"
		btnFarmEndToggle.BackgroundColor3 = Color3.fromRGB(52, 92, 168)
	end
	statusLabel.Text = "XP Farm fim: " .. (farmEndMode == "TIME_END" and "Time end" or "End round")
end)

btnAutoGun.MouseButton1Click:Connect(function()
	autoGetGunEnabled = not autoGetGunEnabled
	if autoGetGunEnabled then
		btnAutoGun.Text = "Auto Get Gun: LIGADO"
		btnAutoGun.BackgroundColor3 = Color3.fromRGB(40, 165, 90)
	else
		btnAutoGun.Text = "Auto Get Gun: DESLIGADO"
		btnAutoGun.BackgroundColor3 = Color3.fromRGB(55, 62, 82)
	end
	statusLabel.Text = "Auto Get Gun: " .. (autoGetGunEnabled and "LIGADO" or "DESLIGADO")
end)

btnAutoShotMurder.MouseButton1Click:Connect(function()
	autoShotMurderEnabled = not autoShotMurderEnabled
	if autoShotMurderEnabled then
		btnAutoShotMurder.Text = "Auto Shot Murder: LIGADO"
		btnAutoShotMurder.BackgroundColor3 = Color3.fromRGB(40, 165, 90)
	else
		btnAutoShotMurder.Text = "Auto Shot Murder: DESLIGADO"
		btnAutoShotMurder.BackgroundColor3 = Color3.fromRGB(55, 62, 82)
	end
	refreshShotMurderButtonVisibility()
	statusLabel.Text = "Auto Shot Murder: " .. (autoShotMurderEnabled and "LIGADO" or "DESLIGADO")
end)

btnEsp.MouseButton1Click:Connect(function()
	espEnabled = not espEnabled
	if espEnabled then
		btnEsp.Text = "ESP: LIGADO"
		btnEsp.BackgroundColor3 = Color3.fromRGB(40, 165, 90)
		updateEspHighlights()
	else
		btnEsp.Text = "ESP: DESLIGADO"
		btnEsp.BackgroundColor3 = Color3.fromRGB(55, 62, 82)
		clearAllEsp()
	end
	statusLabel.Text = "ESP: " .. (espEnabled and "LIGADO" or "DESLIGADO")
end)

local draggingSlider = false
local draggingFloat = false
local movedWhileDraggingFloat = false
local dragStartPosFloat, floatStartPos

local draggingShotBtn = false
local movedWhileDraggingShot = false
local dragStartPosShot, shotStartPos

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

floatBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingFloat = true
		movedWhileDraggingFloat = false
		dragStartPosFloat = input.Position
		floatStartPos = floatBtn.Position
	end
end)

shotMurderBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingShotBtn = true
		movedWhileDraggingShot = false
		dragStartPosShot = input.Position
		shotStartPos = shotMurderBtn.Position
		task.spawn(triggerShotMurderButtonAction)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		updateSliderFromX(input.Position.X)
	elseif draggingFloat and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStartPosFloat
		if delta.Magnitude > 6 then
			movedWhileDraggingFloat = true
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
			floatBtn.Position.Y.Offset - 65
		)
	elseif draggingShotBtn and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStartPosShot
		if delta.Magnitude > 6 then
			movedWhileDraggingShot = true
		end
		shotMurderBtn.Position = UDim2.new(
			shotStartPos.X.Scale,
			shotStartPos.X.Offset + delta.X,
			shotStartPos.Y.Scale,
			shotStartPos.Y.Offset + delta.Y
		)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingSlider = false
		if draggingFloat then
			draggingFloat = false
			if not movedWhileDraggingFloat then
				panel.Visible = not panel.Visible
			end
		end
		if draggingShotBtn then
			draggingShotBtn = false
		end
	end
end)

toggleBtn.MouseButton1Click:Connect(function()
	if mode == "SETTINGS" then return end
	local targetMode = mode
	local nextState = not modeRunning[targetMode]
	modeRunning[targetMode] = nextState

	if not nextState and currentTween then
		pcall(function() currentTween:Cancel() end)
		currentTween = nil
		activeFlightGoal = nil
	end

	if nextState then
		needInitialTpByMode[targetMode] = true
		statusLabel.Text = "Status: " .. targetMode .. " LIGADO"
	else
		statusLabel.Text = "Status: " .. targetMode .. " DESLIGADO"
	end

	syncPowerButtonVisual()
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

local function isBagFull()
	if not AUTO_RESET_ENABLED then
		return false
	end
	local limit = getCoinCapacity()
	local current = readBagCoinsCount()
	return current ~= nil and current >= limit
end

-- ==========================================
-- BUSCA DE MOEDAS ("coin") & ARMA DROPPADA ("gun")
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

local function findDroppedGunPart()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and isGunToolName(obj.Name) then
			if not obj.Parent:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(obj.Parent) then
				return obj
			end
		elseif (obj:IsA("Model") or obj:IsA("Tool")) and isGunToolName(obj.Name) then
			if not obj:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(obj.Parent) then
				local p = obj:FindFirstChildWhichIsA("BasePart", true)
				if p then
					return p
				end
			end
		end
	end
	return nil
end

-- ==========================================
-- MOVIMENTO: TP, TWEEN RETO, FLING E PLATAFORMA
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

local function getLevelLookVector(cf)
	local lv = cf.LookVector
	local flat = Vector3.new(lv.X, 0, lv.Z)
	if flat.Magnitude < 0.001 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function flySmoothStraight(charModel, hrp, part, modeKey)
	if currentTween then
		pcall(function() currentTween:Cancel() end)
		currentTween = nil
		activeFlightGoal = nil
	end

	local hum = charModel and charModel:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum.PlatformStand = true
			hum:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end

	pcall(function()
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end)

	local speed = math.clamp(tweenSpeed, 1, MAX_TWEEN_SPEED)
	local targetPos = part.Position + Vector3.new(0, 2.5, 0)
	local currentPos = hrp.Position
	local dist = (targetPos - currentPos).Magnitude
	local timeSec = math.max(0.05, dist / speed)

	local levelDir = getLevelLookVector(hrp.CFrame)
	local goalCFrame = CFrame.lookAt(targetPos, targetPos + levelDir, Vector3.yAxis)
	activeFlightGoal = targetPos

	local tw = TweenService:Create(
		hrp,
		TweenInfo.new(timeSec, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{ CFrame = goalCFrame }
	)
	currentTween = tw

	local done = false
	tw.Completed:Connect(function()
		done = true
	end)

	tw:Play()
	while not done and modeRunning[modeKey] and isCoinAvailable(part) do
		task.wait(0.08)
	end

	if not done then
		pcall(function() tw:Cancel() end)
	end
	if currentTween == tw then
		currentTween = nil
		activeFlightGoal = nil
	end

	if hum then
		pcall(function()
			hum.PlatformStand = false
			hum:ChangeState(Enum.HumanoidStateType.Running)
		end)
	end
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

local function flingMurder(charModel, hrp)
	local murder = getLivingMurder()
	if not murder or not murder.Character then
		statusLabel.Text = "End round [Inocente]: Sem Murder vivo"
		return
	end
	local mRoot = murder.Character:FindFirstChild("HumanoidRootPart")
	if not mRoot then return end

	pcall(function()
		charModel:PivotTo(mRoot.CFrame)
		hrp.CFrame = mRoot.CFrame
		hrp.AssemblyAngularVelocity = Vector3.new(9000, 9000, 9000)
		hrp.AssemblyLinearVelocity = Vector3.new(180, 220, 180)
	end)
	statusLabel.Text = "End round [Inocente]: Fling no Murder (" .. murder.Name .. ")"
end

local function eliminateAllAsMurder(charModel, hrp)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player and isAlive(plr) then
			local tRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if tRoot then
				local knife = charModel:FindFirstChildOfClass("Tool") or (player:FindFirstChildOfClass("Backpack") and player.Backpack:FindFirstChildOfClass("Tool"))
				local hum = charModel:FindFirstChildOfClass("Humanoid")
				if knife and knife.Parent ~= charModel and hum then
					pcall(function() hum:EquipTool(knife) end)
				end

				local cf = tRoot.CFrame * CFrame.new(0, 0, -1.8)
				pcall(function()
					charModel:PivotTo(cf)
					hrp.CFrame = cf
				end)
				if knife then
					pcall(function() knife:Activate() end)
				end
				statusLabel.Text = "End round [Murder]: Eliminando " .. plr.Name
				return true
			end
		end
	end
	statusLabel.Text = "End round [Murder]: Todos eliminados"
	return false
end

local function handleFarmXpEndAction(role, charModel, hrp)
	if farmEndMode == "TIME_END" then
		tpSkyAfk(charModel, hrp)
		if mode == "FARM_XP" then
			statusLabel.Text = "XP [" .. role .. " | Time end]: Plataforma segura"
		end
		task.wait(1.5)
	else
		if role == "MURDER" then
			eliminateAllAsMurder(charModel, hrp)
			task.wait(0.35)
		elseif role == "SHERIFF" or findGunTool() then
			local murder = getLivingMurder()
			local mRoot = murder and murder.Character and murder.Character:FindFirstChild("HumanoidRootPart")
			if mRoot then
				shootAtTargetPart(charModel, hrp, mRoot)
				statusLabel.Text = "XP [End round]: Tiro no Murder (" .. murder.Name .. ")"
			else
				statusLabel.Text = "XP [End round]: Aguardando Murder"
			end
			task.wait(0.5)
		else
			flingMurder(charModel, hrp)
			task.wait(0.45)
		end
	end
end

-- ==========================================
-- AUTO GET GUN (QUANDO SEM AUTO FARM ATIVO)
-- ==========================================
task.spawn(function()
	while true do
		local anyFarmActive = modeRunning.TP or modeRunning.TWEEN or modeRunning.FARM_XP
		if autoGetGunEnabled and not anyFarmActive and not findGunTool() then
			local now = os.clock()
			if (now - lastAutoGunTime) >= 0.8 then
				local gunPart = findDroppedGunPart()
				local charModel = player.Character
				local hrp = charModel and charModel:FindFirstChild("HumanoidRootPart")
				if gunPart and charModel and hrp then
					lastAutoGunTime = now
					local returnCf = hrp.CFrame
					pcall(function()
						charModel:PivotTo(gunPart.CFrame)
						hrp.CFrame = gunPart.CFrame
					end)
					task.wait(0.14)
					pcall(function()
						charModel:PivotTo(returnCf)
						hrp.CFrame = returnCf
					end)
					statusLabel.Text = "Auto Get Gun: Pegou arma e voltou!"
				end
			end
		end
		task.wait(0.2)
	end
end)

-- ==========================================
-- LOOP PRINCIPAL (CADA MODO RODA INDEPENDENTEMENTE)
-- ==========================================
task.spawn(function()
	while true do
		local anyRunning = modeRunning.TP or modeRunning.TWEEN or modeRunning.FARM_XP
		if anyRunning then
			local charModel = player.Character
			if charModel ~= lastCharacter then
				lastCharacter = charModel
				needInitialTpByMode.TP = true
				needInitialTpByMode.TWEEN = true
				needInitialTpByMode.FARM_XP = true
				initialSheriffUserId = nil
				sheriffHasDied = false
				table.clear(heroUserIds)
			end

			local hrp = charModel and charModel:FindFirstChild("HumanoidRootPart")

			if charModel and hrp then
				if modeRunning.TP then
					local startTick = os.clock()
					if isBagFull() then
						if farmEndMode == "END_ROUND" then
							handleFarmXpEndAction(getMyRole(), charModel, hrp)
						else
							local hum = charModel:FindFirstChildOfClass("Humanoid")
							if hum then hum.Health = 0 end
							needInitialTpByMode.TP = true
							task.wait(2.5)
						end
					else
						local coin, dist = getClosestCoin(hrp.Position, charModel, true)
						if coin then
							local jumped = teleportToPart(charModel, hrp, coin, true)
							if mode == "TP" then
								local tag = jumped and "TP+Pulo" or "TP"
								statusLabel.Text = string.format("%s: %s (%.0f) | %.1fs", tag, coin.Name, dist, tpDelay)
							end
						elseif mode == "TP" then
							statusLabel.Text = "TP: Nenhuma coin encontrada"
						end
					end
					local elapsed = os.clock() - startTick
					task.wait(math.max(0.05, tpDelay - elapsed))

				elseif modeRunning.TWEEN then
					if isBagFull() then
						if farmEndMode == "END_ROUND" then
							handleFarmXpEndAction(getMyRole(), charModel, hrp)
						else
							local hum = charModel:FindFirstChildOfClass("Humanoid")
							if hum then hum.Health = 0 end
							needInitialTpByMode.TWEEN = true
							task.wait(2.5)
						end
					else
						local coin, dist = getClosestCoin(hrp.Position, charModel, false)
						if coin then
							if needInitialTpByMode.TWEEN then
								needInitialTpByMode.TWEEN = false
								teleportToPart(charModel, hrp, coin, false)
								if mode == "TWEEN" then
									statusLabel.Text = string.format("Tween TP 1ª coin: %s", coin.Name)
								end
								task.wait(0.15)
							else
								if mode == "TWEEN" then
									statusLabel.Text = string.format("Tween reto (%.1f): %s (%.0f)", tweenSpeed, coin.Name, dist)
								end
								flySmoothStraight(charModel, hrp, coin, "TWEEN")
							end
						else
							if mode == "TWEEN" then
								statusLabel.Text = "Tween: Nenhuma coin encontrada"
							end
							task.wait(0.5)
						end
					end

				elseif modeRunning.FARM_XP then
					local role = getMyRole()
					if isBagFull() then
						handleFarmXpEndAction(role, charModel, hrp)
					elseif role == "MURDER" and farmEndMode == "END_ROUND" then
						eliminateAllAsMurder(charModel, hrp)
						task.wait(0.35)
					else
						local coin, dist = getClosestCoin(hrp.Position, charModel, false)
						if coin then
							if needInitialTpByMode.FARM_XP then
								needInitialTpByMode.FARM_XP = false
								teleportToPart(charModel, hrp, coin, false)
								if mode == "FARM_XP" then
									statusLabel.Text = string.format("XP [%s] TP 1ª -> Tween: %s", role, coin.Name)
								end
								task.wait(0.15)
							else
								if mode == "FARM_XP" then
									statusLabel.Text = string.format("XP [%s] Tween reto (%.1f): %s", role, tweenSpeed, coin.Name)
								end
								flySmoothStraight(charModel, hrp, coin, "FARM_XP")
							end
						else
							handleFarmXpEndAction(role, charModel, hrp)
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
