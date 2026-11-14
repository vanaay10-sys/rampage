local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local UIS          = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")
local HttpService  = game:GetService("HttpService")
local Stats        = game:GetService("Stats")

local CONFIG = {
	DEFAULT_IMAGE_ID = "",
	MONSTER_NAME     = "ver",
	CONFIG_FILE      = "DogScriptingV10.json",
	VERSION          = "V10 JUBILEE",
}

local player    = Players.LocalPlayer
local guiParent = player:WaitForChild("PlayerGui")

for _, name in ipairs({"DogIsScripting", "DogIsScriptingV8", "DogIsScriptingV9", "DogIsScriptingV10"}) do
	local old = guiParent:FindFirstChild(name)
	if old then old:Destroy() end
end

local THEME = {
	accent  = Color3.fromRGB(255, 35, 55),
	dark    = Color3.fromRGB(12, 12, 18),
	panel   = Color3.fromRGB(24, 24, 33),
	card    = Color3.fromRGB(34, 34, 46),
	white   = Color3.fromRGB(245, 245, 250),
	dim     = Color3.fromRGB(55, 55, 68),
	success = Color3.fromRGB(40, 200, 110),
	danger  = Color3.fromRGB(230, 60, 70),
}
local accent = THEME.accent

local function create(class, props, parent)
	local obj = Instance.new(class)
	for k, v in pairs(props) do pcall(function() obj[k] = v end) end
	obj.Parent = parent
	return obj
end

local function rounded(obj, r) return create("UICorner", {CornerRadius = UDim.new(0, r)}, obj) end
local function outlined(obj, color, t) return create("UIStroke", {Color = color or accent, Thickness = t or 1}, obj) end
local function selectedBg() return accent:Lerp(THEME.dark, 0.78) end
local function tween(obj, time, props)
	return TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
end

local function loadConfig()
	local raw = nil
	pcall(function()
		if isfile and isfile(CONFIG.CONFIG_FILE) then raw = readfile(CONFIG.CONFIG_FILE) end
	end)
	if not raw then return {} end
	local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
	return ok and data or {}
end

local function saveConfig(data)
	pcall(function()
		if writefile then writefile(CONFIG.CONFIG_FILE, HttpService:JSONEncode(data)) end
	end)
end
local SAVED = loadConfig()

local S = {
	connections = {}, themed = {}, highlights = {}, nav = {}, pages = {},
	currentPage = nil, ready = false,
	playerESP = false, monsterESP = false,
	keyESP = false, codeESP = false, closetESP = false, drawerESP = false,
	studsESP = true, antiMonster = false, routeESP = false,
	godmode = false,
	hideInfo = false,
	fullbright = false, noclip = false,
	speedBoost = false, highJump = false, fovEnabled = false,
	infJump = false,
	monsterName = SAVED.monsterName or CONFIG.MONSTER_NAME,
	boostSpeed = SAVED.boostSpeed or 32,
	boostJump = SAVED.boostJump or 100,
	boostFOV = SAVED.boostFOV or 100,
	original = {WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, UseJumpPower = true},
	savedFOV = 70,
	lightingSnapshot = nil,
	noclipConn = nil, infJumpConn = nil,
	noclipCache = setmetatable({}, {__mode = "k"}),
	imageTransparency = SAVED.imageTransparency or 0.65,
	lastImageId = SAVED.lastImageId or "",
	selectedPlayer = nil,
}

if SAVED.accent and #SAVED.accent == 3 then
	accent = Color3.fromRGB(SAVED.accent[1], SAVED.accent[2], SAVED.accent[3])
end

local hideChar = false
local rainbowActive = false
local rainbowConn = nil
local rainbowHue = 0
local rainbowIconActive = true
local rainbowIconConn = nil
local rainbowIconHue = 0
local asmrSound = nil
local asmrEnabled = false
local asmrVolume = 0.25

local function connect(sig, fn)
	local c = sig:Connect(fn)
	table.insert(S.connections, c)
	return c
end

local function track(obj, prop)
	table.insert(S.themed, {obj, prop})
	return obj
end

local function persist()
	SAVED.monsterName       = S.monsterName
	SAVED.boostSpeed        = S.boostSpeed
	SAVED.boostJump         = S.boostJump
	SAVED.boostFOV          = S.boostFOV
	SAVED.imageTransparency = S.imageTransparency
	SAVED.lastImageId       = S.lastImageId
	SAVED.accent            = {math.floor(accent.R*255), math.floor(accent.G*255), math.floor(accent.B*255)}
	saveConfig(SAVED)
end local gui = create("ScreenGui", {
	Name = "DogIsScriptingV10", ResetOnSpawn = false,
	IgnoreGuiInset = true, DisplayOrder = 9999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, guiParent)

local toast = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(280, 38), BackgroundColor3 = THEME.dark,
	BackgroundTransparency = 1, TextTransparency = 1, Text = "",
	TextColor3 = THEME.white, Font = Enum.Font.GothamBold, TextSize = 13, ZIndex = 30,
}, gui)
rounded(toast, 8)
local toastStroke = outlined(toast, accent, 1)
toastStroke.Transparency = 1
local toastId = 0

local function notify(text, color)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.TextColor3 = color or THEME.white
	toastStroke.Color = color or accent
	toastStroke.Transparency = 0
	tween(toast, 0.15, {BackgroundTransparency = 0.1, TextTransparency = 0}):Play()
	task.delay(1.8, function()
		if id == toastId and toast.Parent then
			toastStroke.Transparency = 1
			tween(toast, 0.3, {BackgroundTransparency = 1, TextTransparency = 1}):Play()
		end
	end)
end

local loading = create("CanvasGroup", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(239, 246, 255),
	BorderSizePixel = 0, ZIndex = 20,
}, gui)
create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 235, 248)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 245, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(238, 230, 255)),
	}),
	Rotation = 35,
}, loading)
local loadGlow = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.43),
	Size = UDim2.fromOffset(112, 112), BackgroundTransparency = 1, ZIndex = 21,
}, loading)
rounded(loadGlow, 56)
local loadRing = outlined(loadGlow, Color3.fromRGB(255, 0, 180), 5)
local loadRingGradient = create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 35, 90)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 220, 40)),
		ColorSequenceKeypoint.new(0.68, Color3.fromRGB(0, 230, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 40, 255)),
	}),
	Rotation = 0,
}, loadRing)

local loadTitle = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.25),
	Size = UDim2.fromOffset(520, 60), BackgroundTransparency = 1,
	Text = "DOG IS SCRIPTING " .. CONFIG.VERSION,
	TextColor3 = Color3.fromRGB(45, 48, 85),
	Font = Enum.Font.GothamBlack, TextSize = 34, ZIndex = 21,
}, loading)
local loadTitleStroke = outlined(loadTitle, accent, 2)
tween(loadTitleStroke, 1.1, {Thickness = 5}):Play()

local percent = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.57),
	Size = UDim2.fromOffset(300, 22), BackgroundTransparency = 1, Text = "0%",
	TextColor3 = Color3.fromRGB(90, 75, 160), Font = Enum.Font.GothamBold,
	TextSize = 16, ZIndex = 21,
}, loading)

local loadBack = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.66),
	Size = UDim2.new(0.5, 0, 0, 9), BackgroundColor3 = Color3.fromRGB(218, 225, 245),
	BorderSizePixel = 0, ZIndex = 21,
}, loading)
rounded(loadBack, 8)
outlined(loadBack, Color3.fromRGB(105, 70, 150), 1)
create("UISizeConstraint", {MaxSize = Vector2.new(420, 8)}, loadBack)

local loadFill = create("Frame", {
	Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0, ZIndex = 22,
}, loadBack)
rounded(loadFill, 8)
create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 35, 90)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 40)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 235, 170)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(0, 170, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 40, 255)),
	}),
}, loadFill)

local loadStatus = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.72),
	Size = UDim2.fromOffset(300, 20), BackgroundTransparency = 1, Text = "",
	TextColor3 = Color3.fromRGB(85, 90, 130), Font = Enum.Font.GothamMedium,
	TextSize = 13, ZIndex = 21,
}, loading)

local main = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.new(0.88, 0, 0.8, 0), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = THEME.dark, BorderSizePixel = 0, Visible = false,
	ClipsDescendants = true, ZIndex = 2,
}, gui)
rounded(main, 12)
track(outlined(main, accent, 2), "Color")
create("UISizeConstraint", {MinSize = Vector2.new(320, 320), MaxSize = Vector2.new(880, 660)}, main)

local bgImage = create("ImageLabel", {
	Name = "MenuImage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	ScaleType = Enum.ScaleType.Crop, ZIndex = 1, Visible = false,
}, main)
rounded(bgImage, 12) local header = create("Frame", {
	Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = THEME.panel,
	BorderSizePixel = 0, ZIndex = 5,
}, main)
rounded(header, 12)
create("Frame", {
	Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12),
	BackgroundColor3 = THEME.panel, BorderSizePixel = 0, ZIndex = 5,
}, header)

local rainbowIcon = create("TextButton", {
	Size = UDim2.fromOffset(48, 42), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	BackgroundColor3 = Color3.fromRGB(15, 12, 28), Text = "🐾",
	TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack,
	TextSize = 23, BorderSizePixel = 0, ZIndex = 10, AutoButtonColor = false,
}, header)
rounded(rainbowIcon, 11)
local rainbowIconStroke = outlined(rainbowIcon, THEME.white, 3)

track(create("TextLabel", {
	Size = UDim2.new(1, -150, 1, 0), Position = UDim2.new(0, 50, 0, 0),
	BackgroundTransparency = 1, Text = "DOG IS SCRIPTING | " .. CONFIG.VERSION,
	TextColor3 = accent, Font = Enum.Font.GothamBlack,
	TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
}, header), "TextColor3")

local close = track(create("TextButton", {
	Size = UDim2.new(0, 34, 0, 32), Position = UDim2.new(1, -40, 0, 8),
	BackgroundColor3 = accent, Text = "X", TextColor3 = THEME.white,
	Font = Enum.Font.GothamBold, TextSize = 16, BorderSizePixel = 0, ZIndex = 7,
}, header), "BackgroundColor3")
rounded(close, 7)

local minimize = create("TextButton", {
	Size = UDim2.new(0, 30, 0, 32), Position = UDim2.new(1, -76, 0, 8),
	BackgroundColor3 = THEME.card, Text = "—", TextColor3 = THEME.white,
	Font = Enum.Font.GothamBold, TextSize = 16, BorderSizePixel = 0, ZIndex = 7,
}, header)
rounded(minimize, 7)
outlined(minimize, THEME.dim, 1)

local sidebar = track(create("ScrollingFrame", {
	Size = UDim2.new(0, 125, 1, -58), Position = UDim2.new(0, 7, 0, 52),
	BackgroundColor3 = THEME.panel, BorderSizePixel = 0, ScrollBarThickness = 3,
	ScrollBarImageColor3 = accent, AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 4,
}, main), "ScrollBarImageColor3")
rounded(sidebar, 8)
create("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, sidebar)
create("UIPadding", {
	PaddingTop = UDim.new(0, 7), PaddingLeft = UDim.new(0, 5),
	PaddingRight = UDim.new(0, 5), PaddingBottom = UDim.new(0, 7),
}, sidebar)

local content = track(create("ScrollingFrame", {
	Size = UDim2.new(1, -140, 1, -58), Position = UDim2.new(0, 132, 0, 52),
	BackgroundColor3 = THEME.panel, BorderSizePixel = 0, ScrollBarThickness = 4,
	ScrollBarImageColor3 = accent, AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 4,
}, main), "ScrollBarImageColor3")
rounded(content, 8)
create("UIPadding", {
	PaddingTop = UDim.new(0, 9), PaddingLeft = UDim.new(0, 9),
	PaddingRight = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9),
}, content)
create("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, content)

local reopen = create("TextButton", {
	Size = UDim2.new(0, 148, 0, 42), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8),
	BackgroundColor3 = THEME.dark, Text = "🐾 DOG MENU", TextColor3 = accent,
	Font = Enum.Font.GothamBlack, TextSize = 12, Visible = false,
	BorderSizePixel = 0, ZIndex = 10,
}, gui)
track(reopen, "TextColor3")
rounded(reopen, 8)
track(outlined(reopen, accent, 2), "Color")

local hud = create("Frame", {
	Size = UDim2.fromOffset(200, 60), Position = UDim2.new(0, 10, 1, -80),
	BackgroundColor3 = THEME.dark, BackgroundTransparency = 0.3,
	BorderSizePixel = 0, ZIndex = 12, Visible = true,
}, gui)
rounded(hud, 8)
outlined(hud, accent, 1)

local hudLabel = create("TextLabel", {
	Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5),
	BackgroundTransparency = 1, Text = "FPS: --\nPING: --\nMEM: --",
	TextColor3 = THEME.white, Font = Enum.Font.Code, TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 13,
}, hud) local frames, fps, lastFps = 0, 60, tick()
connect(RunService.RenderStepped, function()
	frames += 1
	if tick() - lastFps >= 0.5 then
		fps = math.floor(frames / (tick() - lastFps))
		frames = 0
		lastFps = tick()
	end
end)

task.spawn(function()
	while gui.Parent do
		local ping = 0
		pcall(function() ping = math.floor(player:GetNetworkPing() * 1000) end)
		local mem = math.floor(Stats:GetTotalMemoryUsageMb() * 10) / 10
		hudLabel.Text = string.format("FPS: %d\nPING: %d ms\nMEM: %.1f MB", fps, ping, mem)
		task.wait(0.5)
	end
end)

local showPage, refreshPage

local function clearContent()
	for _, child in ipairs(content:GetChildren()) do
		if not child:IsA("UIPadding") and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function label(text, color)
	return create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
		Text = text, TextColor3 = color or accent, Font = Enum.Font.GothamBlack,
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
	}, content)
end

local function button(parent, text, callback, selected)
	local b = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = selected and selectedBg() or THEME.card,
		BorderSizePixel = 0, Text = text, TextColor3 = selected and accent or THEME.white,
		Font = Enum.Font.GothamBold, TextSize = 12, TextWrapped = true,
		AutoButtonColor = false, ZIndex = 5,
	}, parent)
	rounded(b, 7)
	local stroke = outlined(b, selected and accent or THEME.dim, 1)
	b.MouseEnter:Connect(function()
		if not b:GetAttribute("Locked") then
			tween(b, 0.12, {BackgroundColor3 = THEME.card:Lerp(accent, 0.12)}):Play()
			stroke.Color = accent
		end
	end)
	b.MouseLeave:Connect(function()
		if not b:GetAttribute("Locked") then
			tween(b, 0.12, {BackgroundColor3 = THEME.card}):Play()
			stroke.Color = THEME.dim
		end
	end)
	b.Activated:Connect(function()
		local ok, err = pcall(callback)
		if not ok then
			warn("[DogScript] Button error:", err)
			notify("Ошибка: " .. tostring(err):sub(1, 40), THEME.danger)
		end
	end)
	return b, stroke
end

local function addButton(text, callback, selected)
	return button(content, text, callback, selected)
end

local function addToggle(text, getter, setter)
	local b, stroke
	local function refresh()
		local on = getter()
		b.Text = text .. (on and "  ● ON" or "  ○ OFF")
		b.TextColor3 = on and accent or THEME.white
		b.BackgroundColor3 = on and selectedBg() or THEME.card
		stroke.Color = on and accent or THEME.dim
		b:SetAttribute("Locked", on)
	end
	b, stroke = button(content, text, function()
		setter(not getter())
		refresh()
		notify(text .. ": " .. (getter() and "ON" or "OFF"), getter() and THEME.success or THEME.danger)
	end, getter())
	b:SetAttribute("Locked", getter())
	refresh()
	return b
end

local function addTextBox(placeholder, default)
	local box = create("TextBox", {
		Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = THEME.card, BorderSizePixel = 0,
		Text = default or "", PlaceholderText = placeholder,
		PlaceholderColor3 = Color3.fromRGB(150, 150, 165), TextColor3 = THEME.white,
		Font = Enum.Font.Gotham, TextSize = 13, ClearTextOnFocus = false, ZIndex = 5,
	}, content)
	rounded(box, 7)
	outlined(box, accent, 1)
	return box
end local function addSlider(text, min, max, default, onChanged)
	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = THEME.card, BorderSizePixel = 0, ZIndex = 5,
	}, content)
	rounded(frame, 7)
	outlined(frame, THEME.dim, 1)
	local lbl = create("TextLabel", {
		Size = UDim2.new(1, -14, 0, 22), Position = UDim2.new(0, 8, 0, 4),
		BackgroundTransparency = 1, Text = text .. ": " .. default,
		TextColor3 = THEME.white, Font = Enum.Font.GothamBold, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
	}, frame)
	local bar = create("Frame", {
		Size = UDim2.new(1, -16, 0, 8), Position = UDim2.new(0, 8, 0, 32),
		BackgroundColor3 = THEME.dark, BorderSizePixel = 0, ZIndex = 6,
	}, frame)
	rounded(bar, 4)
	local fill = create("Frame", {
		Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
		BackgroundColor3 = accent, BorderSizePixel = 0, ZIndex = 7,
	}, bar)
	rounded(fill, 4)
	local btn = create("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 8,
	}, bar)
	local function setFromX(x)
		local frac = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		local val = math.floor(min + (max - min) * frac + 0.5)
		fill.Size = UDim2.new(frac, 0, 1, 0)
		lbl.Text = text .. ": " .. val
		onChanged(val)
	end
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			btn:SetAttribute("Dragging", true)
			setFromX(input.Position.X)
		end
	end)
	connect(UIS.InputChanged, function(input)
		if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and btn:GetAttribute("Dragging") then
			setFromX(input.Position.X)
		end
	end)
	connect(UIS.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			btn:SetAttribute("Dragging", false)
		end
	end)
	return frame
end

local function rootOf(plr)
	local char = plr.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(plr)
	local char = (plr or player).Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function applyMovement()
	local hum = getHumanoid()
	if not hum then return end
	hum.WalkSpeed = S.speedBoost and S.boostSpeed or S.original.WalkSpeed
	if S.highJump then
		if hum.UseJumpPower then hum.JumpPower = S.boostJump
		else hum.JumpHeight = math.max(7.2, S.boostJump / 7) end
	else
		hum.UseJumpPower = S.original.UseJumpPower
		hum.JumpPower = S.original.JumpPower
		hum.JumpHeight = S.original.JumpHeight
	end
end

local movementGuard
local function startMovementGuard()
	if movementGuard then movementGuard:Disconnect(); movementGuard = nil end
	movementGuard = RunService.Heartbeat:Connect(function()
		local hum = getHumanoid()
		if not hum then return end
		if S.speedBoost and math.abs(hum.WalkSpeed - S.boostSpeed) > 0.1 then
			hum.WalkSpeed = S.boostSpeed
		end
		if S.highJump then
			if hum.UseJumpPower then
				if math.abs(hum.JumpPower - S.boostJump) > 0.1 then hum.JumpPower = S.boostJump end
			else
				local wantedHeight = math.max(7.2, S.boostJump / 7)
				if math.abs(hum.JumpHeight - wantedHeight) > 0.1 then hum.JumpHeight = wantedHeight end
			end
		end
	end)
end
startMovementGuard()

local function setSpeedBoost(on)
	local hum = getHumanoid()
	if on and not S.speedBoost and hum then S.original.WalkSpeed = hum.WalkSpeed end
	S.speedBoost = on
	applyMovement()
end

local function setHighJump(on)
	local hum = getHumanoid()
	if on and not S.highJump and hum then
		S.original.JumpPower = hum.JumpPower
		S.original.JumpHeight = hum.JumpHeight
		S.original.UseJumpPower = hum.UseJumpPower
	end
	S.highJump = on
	applyMovement()
end

local function setNoclip(on)
	S.noclip = on
	if S.noclipConn then S.noclipConn:Disconnect(); S.noclipConn = nil end
	if on then
		S.noclipConn = RunService.Stepped:Connect(function()
			local char = player.Character
			if not char then return end
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") and p.CanCollide then
					S.noclipCache[p] = true
					p.CanCollide = false
				end
			end
		end)
	else
		for p in pairs(S.noclipCache) do
			if p.Parent then p.CanCollide = true end
		end
		table.clear(S.noclipCache)
	end
end local function setFOV(on)
	local cam = workspace.CurrentCamera
	if on and not S.fovEnabled and cam then S.savedFOV = cam.FieldOfView end
	S.fovEnabled = on
	if cam then cam.FieldOfView = on and S.boostFOV or S.savedFOV end
end

local function setInfJump(on)
	S.infJump = on
	if S.infJumpConn then S.infJumpConn:Disconnect(); S.infJumpConn = nil end
	if on then
		S.infJumpConn = connect(UIS.JumpRequest, function()
			local hum = getHumanoid()
			if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
		end)
	end
end

local espNames = {player = "DogPlayerESP", monster = "DogMonsterESP"}

local function isMonster(obj)
	return obj:IsA("Model") and obj.Name:lower() == S.monsterName:lower()
end

local espTags = {}
local routeParts = {}
local routeLastPosition = {}
local routeDirections = {}
local function getESPPart(obj)
	if not obj then return nil end
	if obj:IsA("BasePart") then return obj end
	if obj:IsA("Model") then
		return obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
	end
	return obj:FindFirstChildWhichIsA("BasePart", true)
end
local function attachESPTag(obj, labelText, color)
	local part = getESPPart(obj)
	if not part then return end
	local old = espTags[obj]
	if old and old.Parent then old:Destroy() end
	local bill = Instance.new("BillboardGui")
	bill.Name = "DogV10_ESPTag"
	bill.Adornee = part
	bill.Size = UDim2.fromOffset(150, 38)
	bill.StudsOffset = Vector3.new(0, 2.8, 0)
	bill.AlwaysOnTop = true
	bill.MaxDistance = 2000
	bill.Parent = part
	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 13
	text.TextStrokeTransparency = 0.25
	text.TextColor3 = color or Color3.new(1,1,1)
	text.Text = labelText
	text.Parent = bill
	espTags[obj] = bill
end
local function removeESPTag(obj)
	local tag = espTags[obj]
	if tag then tag:Destroy(); espTags[obj] = nil end
end
local function distanceFromPlayer(obj)
	local myRoot = rootOf(player)
	local part = getESPPart(obj)
	if myRoot and part then return (part.Position - myRoot.Position).Magnitude end
	return nil
end
local function updateESPVisuals()
	local espColor = rainbowActive and Color3.fromHSV((os.clock() * 0.18) % 1, 0.9, 1) or accent
	for i = #S.highlights, 1, -1 do
		local h = S.highlights[i]
		if h and h.Parent then h.FillColor = espColor else table.remove(S.highlights, i) end
	end
	for obj, bill in pairs(espTags) do
		if not obj.Parent or not bill.Parent then
			espTags[obj] = nil
		else
			local label = bill:FindFirstChild("Label")
			local dist = distanceFromPlayer(obj)
			if label and dist then
				if rainbowActive then label.TextColor3 = Color3.fromHSV((os.clock() * 0.18) % 1, 0.9, 1) else label.TextColor3 = accent end
				local base = obj.Name
				if isMonster(obj) then base = S.monsterName end
				label.Text = S.studsESP and (base .. "\n" .. math.floor(dist + 0.5) .. " studs") or base
			end
		end
	end
	for obj, line in pairs(routeParts) do
		if not obj.Parent or not line.Parent then
			if line and line.Parent then line:Destroy() end
			routeParts[obj] = nil
			routeLastPosition[obj] = nil
			routeDirections[obj] = nil
		elseif S.routeESP then
			local part = getESPPart(obj)
			if part then
				local pos = part.Position
				local previous = routeLastPosition[obj]
				local delta = previous and (pos - previous) or Vector3.zero
				routeLastPosition[obj] = pos
				local velocity = part.AssemblyLinearVelocity
				local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
				local flatDelta = Vector3.new(delta.X, 0, delta.Z)
				local look = Vector3.new(part.CFrame.LookVector.X, 0, part.CFrame.LookVector.Z)
				if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
				local direction = flatDelta.Magnitude > 0.12 and flatDelta.Unit
					or (flatVelocity.Magnitude > 0.8 and flatVelocity.Unit)
					or routeDirections[obj] or look.Unit
				if direction.Magnitude > 0.01 then routeDirections[obj] = direction end
				local from = pos + Vector3.new(0, 0.35, 0)
				local to = from + direction * 34
				local segment = to - from
				line.Size = Vector3.new(0.42, 0.12, segment.Magnitude)
				line.CFrame = CFrame.lookAt(from + segment * 0.5, to)
				line.Transparency = 0.08
			end
		end
	end
end
local function setRouteESP(on)
	S.routeESP = on
	if not on then
		for obj, line in pairs(routeParts) do if line then line:Destroy() end end
		table.clear(routeParts)
		table.clear(routeLastPosition)
		table.clear(routeDirections)
		return
	end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if isMonster(obj) and not routeParts[obj] then
			local line = Instance.new("Part")
			line.Name = "DogV10_MonsterPredictedPath"
			line.Anchored = true
			line.CanCollide = false
			line.CanTouch = false
			line.CanQuery = false
			line.Material = Enum.Material.Neon
			line.Color = Color3.fromRGB(255, 190, 45)
			line.Size = Vector3.new(0.42, 0.12, 1)
			line.Parent = workspace
			routeParts[obj] = line
			local part = getESPPart(obj)
			if part then routeLastPosition[obj] = part.Position end
		end
	end
end
local function setGodmode(on)
	S.godmode = on
	if S.godmodeConn then S.godmodeConn:Disconnect(); S.godmodeConn = nil end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if char then
		local ff = char:FindFirstChild("DogV10_LocalForceField")
		if on and not ff then
			ff = Instance.new("ForceField")
			ff.Name = "DogV10_LocalForceField"
			ff.Visible = false
			ff.Parent = char
		elseif not on and ff then ff:Destroy() end
	end
	if on and hum then
		hum.Health = hum.MaxHealth
		S.godmodeConn = hum.HealthChanged:Connect(function(health)
			if S.godmode and health > 0 and health < hum.MaxHealth then
				task.defer(function()
					if S.godmode and hum.Parent and hum.Health > 0 then hum.Health = hum.MaxHealth end
				end)
			end
		end)
	end
	notify(on and "Godmode client attempt enabled" or "Godmode disabled", on and THEME.success or THEME.white)
end
local function setAntiMonster(on)
	S.antiMonster = on
	if S.antiMonsterConn then S.antiMonsterConn:Disconnect(); S.antiMonsterConn = nil end
	if not on then
		if S.antiMonsterReturn then
			local root = rootOf(player)
			if root then root.CFrame = S.antiMonsterReturn end
		end
		S.antiMonsterReturn = nil
		return
	end
	local lifted = false
	local savedCFrame = nil
	local savedCharacter = nil
	local lastScan = 0
	S.antiMonsterConn = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastScan < 0.1 then return end
		lastScan = now
		local char = player.Character
		local myRoot = rootOf(player)
		if not char or not myRoot then return end
		local nearest = math.huge
		for _, obj in ipairs(workspace:GetDescendants()) do
			if isMonster(obj) then
				local monsterRoot = getESPPart(obj)
				if monsterRoot then
					local d = (monsterRoot.Position - myRoot.Position).Magnitude
					if d < nearest then nearest = d end
				end
			end
		end
		if not lifted and nearest <= 10 then
			if not savedCFrame or savedCharacter ~= char then
				savedCFrame = myRoot.CFrame
				savedCharacter = char
			end
			S.antiMonsterReturn = savedCFrame
			myRoot.AssemblyLinearVelocity = Vector3.zero
			myRoot.CFrame = savedCFrame + Vector3.new(0, 24, 0)
			lifted = true
			notify("Монстр рядом: временный подъём", THEME.success)
		elseif lifted and (nearest >= 30 or nearest == math.huge) then
			if player.Character == savedCharacter and myRoot.Parent then
				myRoot.AssemblyLinearVelocity = Vector3.zero
				myRoot.CFrame = savedCFrame
			end
			lifted = false
			savedCFrame = nil
			savedCharacter = nil
			S.antiMonsterReturn = nil
			notify("Монстр отошёл: возвращение", THEME.white)
		end
	end)
end
connect(RunService.RenderStepped, updateESPVisuals)

local function setHighlight(model, kind, enabled)
	local name = espNames[kind]
	local h = model:FindFirstChild(name)
	if enabled then
		if not h then
			h = Instance.new("Highlight")
			h.Name = name
			h.FillColor = accent
			h.OutlineColor = THEME.white
			h.FillTransparency = 0.4
			h.OutlineTransparency = 0
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = model
			table.insert(S.highlights, h)
		end
	elseif h then
		h:Destroy()
	end
	if enabled and kind == "monster" then attachESPTag(model, S.monsterName, accent) else removeESPTag(model) end
end

local function setESP(kind, enabled)
	if kind == "player" then
		S.playerESP = enabled
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player and plr.Character then
				setHighlight(plr.Character, "player", enabled)
				if enabled then attachESPTag(plr.Character, plr.Name, Color3.fromRGB(80, 190, 255)) else removeESPTag(plr.Character) end
			end
		end
	else
		S.monsterESP = enabled
		for _, obj in ipairs(workspace:GetDescendants()) do
			if isMonster(obj) then setHighlight(obj, "monster", enabled) end
		end
	end
end

local function snapshotLighting()
	if S.lightingSnapshot then return end
	local props = {"Brightness","ClockTime","GlobalShadows","Ambient","OutdoorAmbient","FogEnd","ColorShift_Top","FogStart","FogColor"}
	S.lightingSnapshot = {}
	for _, k in ipairs(props) do S.lightingSnapshot[k] = Lighting[k] end
end

local function restoreLighting()
	S.fullbright = false
	if not S.lightingSnapshot then return end
	for k, v in pairs(S.lightingSnapshot) do Lighting[k] = v end
	S.lightingSnapshot = nil
end

local function setFullbright(on)
	if on then
		snapshotLighting()
		S.fullbright = true
		Lighting.Brightness = 3
		Lighting.ClockTime = 14
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.new(1, 1, 1)
		Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
		Lighting.FogEnd = 100000
	else
		restoreLighting()
	end
end

local objectESPNames = {key = "DogKeyESP", code = "DogCodeESP", closet = "DogClosetESP", drawer = "DogDrawerESP"}
local function classifyObject(obj)
	local n = obj.Name:lower()
	if n:find("key") or n:find("keycard") then return "key" end
	if n:find("code") or n:find("paper") or n:find("combination") then return "code" end
	if n:find("closet") or n:find("wardrobe") or n:find("locker") or n:find("hide") then return "closet" end
	if n:find("drawer") or n:find("dresser") or n:find("nightstand") then return "drawer" end
	return nil
end
local function objectAdornee(obj)
	if obj:IsA("Model") or obj:IsA("BasePart") then return obj end
	if obj:IsA("Tool") then return obj:FindFirstChildWhichIsA("BasePart", true) end
	return nil
end
local function setObjectHighlight(obj, kind, enabled)
	local adornee = objectAdornee(obj)
	if not adornee then return end
	local host = obj:IsA("Model") and obj or adornee
	local name = objectESPNames[kind]
	local existing = host:FindFirstChild(name)
	if enabled then
		if not existing then
			local h = Instance.new("Highlight")
			h.Name = name
			h.Adornee = adornee
			h.FillColor = kind == "key" and Color3.fromRGB(255, 210, 55)
				or kind == "code" and Color3.fromRGB(70, 190, 255)
				or kind == "drawer" and Color3.fromRGB(255, 145, 75)
				or Color3.fromRGB(80, 255, 150)
			h.OutlineColor = Color3.new(1, 1, 1)
			h.FillTransparency = 0.35
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = host
			table.insert(S.highlights, h)
		end
		local display = kind == "key" and "Key" or kind == "code" and "Code" or kind == "closet" and "Closet" or "Drawer"
		attachESPTag(obj, display, kind == "key" and Color3.fromRGB(255,210,55) or kind == "code" and Color3.fromRGB(70,190,255) or kind == "drawer" and Color3.fromRGB(255,145,75) or Color3.fromRGB(80,255,150))
	elseif existing then existing:Destroy(); removeESPTag(obj) end
end
local function setObjectESP(kind, enabled)
	S[kind .. "ESP"] = enabled
	for _, obj in ipairs(workspace:GetDescendants()) do
		if classifyObject(obj) == kind then setObjectHighlight(obj, kind, enabled) end
	end
end

local skyPresets = {
	{"❄ Snowy Sky",   {20,30,50},   {160,190,220},{210,230,255},8},
	{"🌌 Galaxy Sky",  {8,0,30},     {65,20,120},  {120,70,200}, 0},
	{"🌅 Sunset Sky",  {80,20,40},   {255,100,50}, {255,180,90}, 18},
	{"🌑 Dark Sky",    {0,0,0},      {10,10,20},   {20,20,35},   0},
	{"🌊 Ocean Sky",   {0,40,80},    {0,130,180},  {80,210,230}, 12},
	{"🌋 Lava Sky",    {40,0,0},     {180,25,0},   {255,100,10}, 19},
	{"💜 Purple Sky",  {30,0,60},    {120,40,180}, {210,100,255},17},
	{"🌧 Storm Sky",   {15,20,30},   {55,65,80},   {90,100,120}, 15},
	{"🌿 Toxic Sky",   {10,30,0},    {60,130,0},   {160,255,30}, 13},
	{"🌸 Pink Sky",    {80,20,60},   {220,100,180},{255,190,230},17},
	{"🔥 Blood Moon",  {20,0,0},     {100,0,10},   {200,20,30},  0},
	{"☁ Cloudy Sky",  {50,55,65},   {130,140,155},{200,205,215},12},
	{"🌠 Meteor Sky",  {5,0,20},     {80,20,60},   {255,120,90}, 3},
	{"🩸 Bloodmoon",   {30,0,0},     {150,0,5},    {255,10,20},  0},
	{"🌁 Foggy Morn",  {60,70,80},  {170,180,190},{220,225,235},7},
	{"🍭 Candy Sky",   {90,40,90},  {255,140,200},{255,220,240},16},
	{"🧊 Ice Age",     {40,60,90},  {150,200,240},{220,240,255},11},
	{"🌙 Midnight",    {2,2,10},    {15,20,40},   {40,50,90},   0},
	{"🟣 Neon Nights", {20,0,40},   {140,0,180},  {255,0,200},  1},
	{"🌋 Volcanic",    {50,10,0},   {200,50,0},   {255,160,20}, 19},
	{"💚 Matrix Sky",  {0,20,0},    {0,120,40},   {40,255,80},  13},
	{"🏖 Tropical",    {30,120,180},{100,200,240},{255,240,180},13},
	{"🌪 Tornado Sky", {40,45,55},  {100,110,125},{160,165,180},14},
	{"☀ Desert",       {120,90,50}, {230,190,130},{255,230,190},13},
	{"🌌 Cosmos",      {0,0,5},     {30,0,60},    {100,20,180}, 0},
	{"🩵 Aqua Sky",    {10,60,90},  {40,180,220}, {140,240,255},12},
	{"🌺 Floral",      {100,60,80}, {255,180,210},{255,220,235},15},
	{"⚡ Thunder",      {20,20,30},  {70,70,100},  {180,180,255},15},
	{"🩶 Silver Sky",  {70,75,85},  {180,185,195},{230,235,245},12},
	{"🟡 Golden Hour", {90,60,20},  {255,190,80}, {255,230,150},17},
	{"🌃 City Lights", {10,10,25},  {60,40,90},   {180,120,255},0},
	{"🔴 Mars Sky",    {80,30,10},  {190,90,50},  {255,170,120},10},
} local function applySky(sky)
	snapshotLighting()
	S.fullbright = false
	Lighting.ClockTime = sky[5]
	Lighting.Brightness = 2
	Lighting.FogEnd = 100000
	Lighting.Ambient = Color3.fromRGB(sky[2][1], sky[2][2], sky[2][3])
	Lighting.OutdoorAmbient = Color3.fromRGB(sky[3][1], sky[3][2], sky[3][3])
	Lighting.ColorShift_Top = Color3.fromRGB(sky[4][1], sky[4][2], sky[4][3])
end

local function setClock(hour)
	snapshotLighting()
	Lighting.ClockTime = hour
end

local function setMenuImage(id)
	if not id then
		bgImage.Visible = false
		sidebar.BackgroundTransparency = 0
		content.BackgroundTransparency = 0
		return
	end
	bgImage.Image = "rbxassetid://" .. id
	bgImage.ImageTransparency = S.imageTransparency
	bgImage.Visible = true
	sidebar.BackgroundTransparency = 0.3
	content.BackgroundTransparency = 0.3
end

local function setMenuVisible(visible)
	if not S.ready then return end
	main.Visible = visible
	reopen.Visible = not visible
end

local function setHideChar(on)
	hideChar = on
	local char = player.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then part.LocalTransparencyModifier = on and 1 or 0 end
	end
end

local function setRainbowTheme(on)
	rainbowActive = on
	if rainbowConn then rainbowConn:Disconnect(); rainbowConn = nil end
	if not on then return end
	rainbowConn = RunService.RenderStepped:Connect(function(dt)
		rainbowHue = (rainbowHue + dt * 0.25) % 1
		accent = Color3.fromHSV(rainbowHue, 1, 1)
		for i = #S.themed, 1, -1 do
			local e = S.themed[i]
			if e[1].Parent then e[1][e[2]] = accent else table.remove(S.themed, i) end
		end
		for i = #S.highlights, 1, -1 do
			local h = S.highlights[i]
			if h.Parent then h.FillColor = accent else table.remove(S.highlights, i) end
		end
		for _, entry in pairs(S.nav) do
			if entry.button.BackgroundColor3 ~= THEME.card then entry.stroke.Color = accent end
		end
		close.BackgroundColor3 = accent
		reopen.TextColor3 = accent
		toastStroke.Color = accent
	end)
end

local function setRainbowIcon(on)
	rainbowIconActive = on
	if rainbowIconConn then rainbowIconConn:Disconnect(); rainbowIconConn = nil end
	if not on then
		rainbowIcon.BackgroundColor3 = Color3.fromRGB(15, 12, 28)
		rainbowIconStroke.Color = THEME.white
		return
	end
	rainbowIconConn = RunService.RenderStepped:Connect(function(dt)
		rainbowIconHue = (rainbowIconHue + dt * 0.5) % 1
		rainbowIcon.BackgroundColor3 = Color3.fromRGB(15, 12, 28)
		rainbowIconStroke.Color = Color3.fromHSV(rainbowIconHue, 1, 1)
	end)
end
setRainbowIcon(true)
rainbowIcon.Activated:Connect(function()
	setRainbowTheme(not rainbowActive)
	notify("Rainbow Theme: " .. (rainbowActive and "ON" or "OFF"))
end)

local function applyTheme(color)
	setRainbowTheme(false)
	accent = color
	for i = #S.themed, 1, -1 do
		local e = S.themed[i]
		if e[1].Parent then e[1][e[2]] = accent else table.remove(S.themed, i) end
	end
	for i = #S.highlights, 1, -1 do
		local h = S.highlights[i]
		if h.Parent then h.FillColor = accent else table.remove(S.highlights, i) end
	end
	refreshPage()
end

showPage = function(name)
	S.currentPage = name
	clearContent()
	for pageName, entry in pairs(S.nav) do
		local active = pageName == name
		entry.button.BackgroundColor3 = active and selectedBg() or THEME.card
		entry.stroke.Color = active and accent or THEME.dim
		entry.button.TextColor3 = active and accent or THEME.white
		entry.button:SetAttribute("Locked", active)
	end
	if S.pages[name] then S.pages[name]() end
end

refreshPage = function()
	local pos = content.CanvasPosition
	if S.currentPage then showPage(S.currentPage) end
	task.defer(function()
		if content.Parent then content.CanvasPosition = pos end
	end)
end

local function addPage(name, icon, callback)
	S.pages[name] = callback
	local b, stroke = button(sidebar, icon .. " " .. name, function()
		content.CanvasPosition = Vector2.zero
		showPage(name)
	end)
	b.TextXAlignment = Enum.TextXAlignment.Left
	S.nav[name] = {button = b, stroke = stroke}
end

addPage("Visual", "◉", function()
	label("ESP")
	addToggle("Monster ESP: " .. S.monsterName, function() return S.monsterESP end, function(v) setESP("monster", v) end)
	addToggle("Player ESP", function() return S.playerESP end, function(v) setESP("player", v) end)
	addToggle("🔑 Keys ESP", function() return S.keyESP end, function(v) setObjectESP("key", v) end)
	addToggle("📄 Code ESP", function() return S.codeESP end, function(v) setObjectESP("code", v) end)
	addToggle("🚪 Closets ESP", function() return S.closetESP end, function(v) setObjectESP("closet", v) end)
	addToggle("🗄 Drawer ESP", function() return S.drawerESP end, function(v) setObjectESP("drawer", v) end)
	addToggle("📏 ESP Studs / Distance", function() return S.studsESP end, function(v) S.studsESP = v end)
	addToggle("🧭 Monster trajectory", function() return S.routeESP end, setRouteESP)
	addToggle("Fullbright", function() return S.fullbright end, setFullbright)
	addToggle("Wide FOV", function() return S.fovEnabled end, setFOV)
	addButton("Open extra Visuals script (coming soon)", function() notify("Дополнительный скрипт добавим позже") end)
	addToggle("👤 Hide Character", function() return hideChar end, setHideChar)
	label("MONSTER NAME")
	local input = addTextBox("Имя монстра", S.monsterName)
	addButton("Apply monster name", function()
		local name = input.Text:match("^%s*(.-)%s*$")
		if name == "" then
			notify("Введи имя монстра")
			return
		end
		local wasOn = S.monsterESP
		if wasOn then setESP("monster", false) end
		S.monsterName = name
		persist()
		if wasOn then setESP("monster", true) end
		notify("Monster name: " .. name)
		refreshPage()
	end)
	addButton("Refresh ESP", function()
		setESP("monster", S.monsterESP)
		setESP("player", S.playerESP)
		notify("ESP refreshed")
	end)
end) addPage("Players", "♙", function()
	label("PLAYER LIST")
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player and plr.Parent then
			addButton(plr.Name, function()
				local target = rootOf(plr)
				local root = rootOf(player)
				if target and root then
					root.CFrame = target.CFrame * CFrame.new(0, 0, -5)
					S.selectedPlayer = plr
					refreshPage()
				else
					notify("Игрок недоступен")
				end
			end, S.selectedPlayer == plr)
		end
	end
	addButton("Teleport forward +10", function()
		local root = rootOf(player)
		if root then root.CFrame = root.CFrame * CFrame.new(0, 0, -10) end
	end)
	addButton("Teleport to Spawn", function()
		local root = rootOf(player)
		local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		if root and spawn then
			root.CFrame = spawn.CFrame + Vector3.new(0, 4, 0)
		else
			notify("Spawn не найден")
		end
	end)
	addButton("Refresh list", refreshPage)
end)

addPage("Movement", "↗", function()
	label("MOVEMENT")
	addToggle("Speed Boost (" .. S.boostSpeed .. ")", function() return S.speedBoost end, setSpeedBoost)
	addToggle("High Jump", function() return S.highJump end, setHighJump)
	addSlider("WalkSpeed value", 16, 100, S.boostSpeed, function(v)
		S.boostSpeed = v
		if S.speedBoost then applyMovement() end
		persist()
	end)
	addSlider("Jump value", 50, 150, S.boostJump, function(v)
		S.boostJump = v
		if S.highJump then applyMovement() end
		persist()
	end)
	addToggle("🛡 Anti-Monster (10 studs up / 30 studs return)", function() return S.antiMonster end, setAntiMonster)
	addToggle("Noclip", function() return S.noclip end, setNoclip)
	addToggle("Godmode (client attempt)", function() return S.godmode end, setGodmode)
	label("Godmode не гарантируется: сервер игры может отменять локальную защиту.")
	addToggle("🦘 Infinite Jump", function() return S.infJump end, setInfJump)
	for _, value in ipairs({32, 50, 100}) do
		addButton("Speed " .. value, function()
			S.boostSpeed = value
			setSpeedBoost(true)
			persist()
			refreshPage()
		end, S.speedBoost and S.boostSpeed == value)
	end
	addButton("Normal movement", function()
		S.speedBoost = false
		S.highJump = false
		applyMovement()
		refreshPage()
	end)
	addButton("Reset character", function()
		local hum = getHumanoid()
		if hum then hum.Health = 0 end
	end)
end)

addPage("World", "◇", function()
	label("WORLD SETTINGS")
	addButton("☀️ Day", function() setClock(14) end)
	addButton("🌙 Night", function() setClock(0) end)
	addButton("🌅 Sunset", function() setClock(18) end)
	addButton("🌫 Remove fog", function()
		snapshotLighting()
		Lighting.FogEnd = 100000
	end)
	addButton("💡 Toggle Fullbright", function()
		setFullbright(not S.fullbright)
		refreshPage()
	end)
	label("SKY PRESETS")
	for _, sky in ipairs(skyPresets) do
		addButton(sky[1], function() applySky(sky) end)
	end
	label("120 COLOR LIGHTING PRESETS")
	for i = 1, 120 do
		local presetIndex = i
		local hue = (presetIndex - 1) / 120
		local c = Color3.fromHSV(hue, 0.72, 1)
		local presetName = string.format("Lighting %03d", presetIndex)
		addButton(presetName, function()
			snapshotLighting()
			S.fullbright = false
			Lighting.Brightness = 2.2
			Lighting.ClockTime = (presetIndex * 0.19) % 24
			Lighting.Ambient = c:Lerp(Color3.new(0.08,0.08,0.12), 0.35)
			Lighting.OutdoorAmbient = c:Lerp(Color3.new(1,1,1), 0.35)
			Lighting.ColorShift_Top = c
			Lighting.FogColor = c:Lerp(Color3.new(1,1,1), 0.5)
			Lighting.FogEnd = 100000
			notify(presetName .. " applied", c)
		end)
	end
	addButton("↩ Restore original lighting", function()
		restoreLighting()
		notify("Lighting restored")
	end)
end) addPage("Monsters", "👾", function()
	label("МОНСТРЫ В МИРЕ")
	local found = 0
	local myPos = rootOf(player) and rootOf(player).Position or Vector3.zero
	for _, obj in ipairs(workspace:GetDescendants()) do
		if isMonster(obj) then
			found += 1
			local root = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
			if root then
				local dist = math.floor((root.Position - myPos).Magnitude)
				addButton("👾 " .. obj.Name .. " [" .. dist .. " studs]", function()
					notify("Монстр отмечен через ESP и траекторию")
				end)
			end
		end
	end
	if found == 0 then
		label("Монстров не найдено", THEME.danger)
	end
	addButton("🔄 Refresh", refreshPage)
end)

addPage("Themes", "✦", function()
	label("РАДУЖНЫЕ РЕЖИМЫ")
	addToggle("🌈 Rainbow Theme", function() return rainbowActive end, setRainbowTheme)
	addToggle("🌈 Rainbow Icon", function() return rainbowIconActive end, setRainbowIcon)
	addButton("⏹ Остановить радугу", function()
		setRainbowTheme(false)
		accent = THEME.accent
		for i = #S.themed, 1, -1 do
			local e = S.themed[i]
			if e[1].Parent then e[1][e[2]] = accent end
		end
		refreshPage()
		notify("Радуга остановлена", THEME.danger)
	end)
	label("ОСНОВНЫЕ ТЕМЫ")
	local themeList = {
		{"RED NEON",Color3.fromRGB(255,25,55)}, {"BLUE NEON",Color3.fromRGB(25,120,255)},
		{"PURPLE NEON",Color3.fromRGB(180,45,255)}, {"GREEN NEON",Color3.fromRGB(30,255,100)},
		{"CYAN NEON",Color3.fromRGB(0,240,255)}, {"ORANGE NEON",Color3.fromRGB(255,125,20)},
		{"PINK NEON",Color3.fromRGB(255,50,170)}, {"GOLD",Color3.fromRGB(255,205,35)},
		{"WHITE ICE",Color3.fromRGB(235,245,255)}, {"TOXIC",Color3.fromRGB(170,255,0)},
		{"ARCTIC",Color3.fromRGB(100,210,255)}, {"BLOOD",Color3.fromRGB(130,0,15)},
		{"LAVA",Color3.fromRGB(255,70,0)}, {"MATRIX",Color3.fromRGB(0,255,65)},
		{"GHOST",Color3.fromRGB(180,190,210)}, {"AQUA",Color3.fromRGB(0,180,200)},
		{"VIOLET",Color3.fromRGB(110,50,220)}, {"CRIMSON",Color3.fromRGB(190,10,45)},
		{"SILVER",Color3.fromRGB(170,180,195)}, {"ELECTRIC",Color3.fromRGB(255,255,0)},
		{"DARK BLUE",Color3.fromRGB(20,45,130)}, {"ROSE GOLD",Color3.fromRGB(255,150,160)},
		{"MINT",Color3.fromRGB(100,255,190)}, {"LIME",Color3.fromRGB(190,255,0)},
	}
	for _, entry in ipairs(themeList) do
		local b = addButton(entry[1], function()
			applyTheme(entry[2])
			persist()
			notify("Theme: " .. entry[1])
		end, accent == entry[2])
		b.TextColor3 = entry[2]
	end
	label("НОВЫЕ ТЕМЫ")
	local extraThemes = {
		{"NEON RED",Color3.fromRGB(255,30,60)}, {"NEON GREEN",Color3.fromRGB(0,255,120)},
		{"NEON BLUE",Color3.fromRGB(0,180,255)}, {"NEON PINK",Color3.fromRGB(255,40,200)},
		{"CYBER YELLOW",Color3.fromRGB(255,230,0)}, {"ELECTRIC PURPLE",Color3.fromRGB(160,0,255)},
		{"MINT GREEN",Color3.fromRGB(100,255,180)}, {"PEACH",Color3.fromRGB(255,170,130)},
		{"BLOOD RED",Color3.fromRGB(180,0,20)}, {"DEEP PURPLE",Color3.fromRGB(90,20,160)},
		{"OCEAN BLUE",Color3.fromRGB(0,120,200)}, {"SUNSET ORANGE",Color3.fromRGB(255,120,40)},
		{"LAVENDER",Color3.fromRGB(180,140,255)}, {"MATCHA",Color3.fromRGB(140,200,100)},
		{"SNOW WHITE",Color3.fromRGB(240,245,255)}, {"ROSE",Color3.fromRGB(255,100,140)},
		{"TURQUOISE",Color3.fromRGB(0,220,200)}, {"RUBY",Color3.fromRGB(200,0,60)},
		{"EMERALD",Color3.fromRGB(20,180,100)}, {"AMBER",Color3.fromRGB(255,190,0)},
		{"INDIGO",Color3.fromRGB(75,0,180)}, {"SAPPHIRE",Color3.fromRGB(20,60,200)},
		{"COPPER",Color3.fromRGB(200,100,50)}, {"SLATE",Color3.fromRGB(100,120,140)},
	}
	for _, entry in ipairs(extraThemes) do
		local b = addButton(entry[1], function()
			applyTheme(entry[2])
			persist()
			notify("Theme: " .. entry[1])
		end, accent == entry[2])
		b.TextColor3 = entry[2]
	end

	label("100 EXTRA THEMES")
	local megaThemes = {
		{"Ruby Pulse", Color3.fromRGB(224, 18, 18)},
		{"Crimson Core", Color3.fromRGB(56, 114, 255)},
		{"Scarlet Wave", Color3.fromRGB(172, 255, 56)},
		{"Cherry Neon", Color3.fromRGB(255, 56, 230)},
		{"Rose Flame", Color3.fromRGB(20, 255, 216)},
		{"Inferno", Color3.fromRGB(224, 144, 49)},
		{"Magma", Color3.fromRGB(106, 56, 255)},
		{"Solar Flare", Color3.fromRGB(65, 255, 56)},
		{"Amber Glow", Color3.fromRGB(255, 20, 99)},
		{"Golden Circuit", Color3.fromRGB(56, 181, 255)},
		{"Lemon Shock", Color3.fromRGB(210, 224, 49)},
		{"Acid Lime", Color3.fromRGB(213, 56, 255)},
		{"Toxic Pulse", Color3.fromRGB(20, 255, 137)},
		{"Radioactive", Color3.fromRGB(255, 97, 56)},
		{"Jade Matrix", Color3.fromRGB(56, 73, 255)},
		{"Emerald Night", Color3.fromRGB(115, 224, 49)},
		{"Forest Neon", Color3.fromRGB(255, 20, 177)},
		{"Mint Circuit", Color3.fromRGB(56, 247, 255)},
		{"Aqua Pulse", Color3.fromRGB(255, 205, 56)},
		{"Turquoise Wave", Color3.fromRGB(147, 56, 255)},
		{"Teal Storm", Color3.fromRGB(18, 224, 52)},
		{"Ocean Drive", Color3.fromRGB(255, 56, 82)},
		{"Deep Sea", Color3.fromRGB(56, 140, 255)},
		{"Arctic Blue", Color3.fromRGB(198, 255, 56)},
		{"Glacier", Color3.fromRGB(254, 20, 255)},
		{"Ice Crystal", Color3.fromRGB(49, 224, 173)},
		{"Frostbite", Color3.fromRGB(255, 138, 56)},
		{"Electric Cyan", Color3.fromRGB(80, 56, 255)},
		{"Skyline", Color3.fromRGB(60, 255, 20)},
		{"Sapphire Glow", Color3.fromRGB(255, 56, 148)},
		{"Royal Blue", Color3.fromRGB(49, 181, 224)},
		{"Midnight Blue", Color3.fromRGB(255, 246, 56)},
		{"Indigo Night", Color3.fromRGB(176, 20, 255)},
		{"Cosmic Violet", Color3.fromRGB(56, 255, 130)},
		{"Ultra Violet", Color3.fromRGB(255, 72, 56)},
		{"Amethyst", Color3.fromRGB(49, 87, 224)},
		{"Lavender Dream", Color3.fromRGB(139, 255, 20)},
		{"Purple Haze", Color3.fromRGB(255, 56, 215)},
		{"Plum Shadow", Color3.fromRGB(56, 255, 237)},
		{"Magenta Rush", Color3.fromRGB(255, 179, 56)},
		{"Hot Pink", Color3.fromRGB(86, 18, 224)},
		{"Bubblegum", Color3.fromRGB(56, 255, 63)},
		{"Neon Rose", Color3.fromRGB(255, 56, 107)},
		{"Cotton Candy", Color3.fromRGB(56, 165, 255)},
		{"Coral Reef", Color3.fromRGB(217, 255, 20)},
		{"Peach Glow", Color3.fromRGB(202, 49, 224)},
		{"Apricot", Color3.fromRGB(56, 255, 171)},
		{"Sunset Pink", Color3.fromRGB(255, 113, 56)},
		{"Copper Wire", Color3.fromRGB(20, 22, 255)},
		{"Bronze Age", Color3.fromRGB(115, 255, 56)},
		{"Silverline", Color3.fromRGB(224, 49, 153)},
		{"Chrome", Color3.fromRGB(56, 231, 255)},
		{"Titanium", Color3.fromRGB(255, 214, 20)},
		{"Pearl White", Color3.fromRGB(162, 56, 255)},
		{"Ghost White", Color3.fromRGB(56, 255, 104)},
		{"Moonlight", Color3.fromRGB(224, 49, 58)},
		{"Cloud Nine", Color3.fromRGB(20, 100, 255)},
		{"Graphite", Color3.fromRGB(182, 255, 56)},
		{"Slate Storm", Color3.fromRGB(255, 56, 240)},
		{"Obsidian", Color3.fromRGB(56, 255, 212)},
		{"Carbon", Color3.fromRGB(224, 120, 18)},
		{"Dark Matter", Color3.fromRGB(96, 56, 255)},
		{"Stealth", Color3.fromRGB(74, 255, 56)},
		{"Phantom", Color3.fromRGB(255, 56, 132)},
		{"Void", Color3.fromRGB(20, 179, 255)},
		{"Matrix Green", Color3.fromRGB(219, 224, 49)},
		{"Hacker Green", Color3.fromRGB(204, 56, 255)},
		{"Pixel Lime", Color3.fromRGB(56, 255, 146)},
		{"Cyber Yellow", Color3.fromRGB(255, 57, 20)},
		{"Laser Gold", Color3.fromRGB(56, 83, 255)},
		{"Retro Wave", Color3.fromRGB(124, 224, 49)},
		{"Synthwave", Color3.fromRGB(255, 56, 199)},
		{"Vaporwave", Color3.fromRGB(20, 255, 253)},
		{"Arcade", Color3.fromRGB(255, 195, 56)},
		{"Digital Rain", Color3.fromRGB(137, 56, 255)},
		{"Glitch", Color3.fromRGB(49, 224, 70)},
		{"Hologram", Color3.fromRGB(255, 20, 62)},
		{"Prism", Color3.fromRGB(56, 149, 255)},
		{"Spectrum", Color3.fromRGB(207, 255, 56)},
		{"Rainbow Ice", Color3.fromRGB(245, 56, 255)},
		{"Galaxy Core", Color3.fromRGB(18, 224, 153)},
		{"Nebula", Color3.fromRGB(255, 129, 56)},
		{"Starfield", Color3.fromRGB(71, 56, 255)},
		{"Meteor", Color3.fromRGB(100, 255, 56)},
		{"Aurora", Color3.fromRGB(255, 20, 140)},
		{"Northern Lights", Color3.fromRGB(49, 190, 224)},
		{"Solar System", Color3.fromRGB(255, 236, 56)},
		{"Cosmic Dust", Color3.fromRGB(178, 56, 255)},
		{"Blacklight", Color3.fromRGB(20, 255, 96)},
		{"Quantum", Color3.fromRGB(255, 62, 56)},
		{"Cyberpunk", Color3.fromRGB(49, 95, 224)},
		{"Neon City", Color3.fromRGB(166, 255, 56)},
		{"Night Drive", Color3.fromRGB(255, 20, 219)},
		{"Stormfront", Color3.fromRGB(56, 255, 228)},
		{"Thunderbolt", Color3.fromRGB(255, 170, 56)},
		{"Lightning", Color3.fromRGB(98, 49, 224)},
		{"Monochrome Red", Color3.fromRGB(23, 255, 20)},
		{"Monochrome Blue", Color3.fromRGB(255, 56, 117)},
		{"Monochrome Purple", Color3.fromRGB(56, 175, 255)},
		{"Ultra Dark", Color3.fromRGB(233, 255, 56)},
	}
	for _, entry in ipairs(megaThemes) do
		local b = addButton("✦ " .. entry[1], function()
			applyTheme(entry[2])
			persist()
			notify("Theme: " .. entry[1])
		end, accent == entry[2])
		b.TextColor3 = entry[2]
	end
end) addPage("RGB Theme", "🎨", function()
	label("КАСТОМНЫЙ ЦВЕТ АКЦЕНТА")
	local r = math.floor(accent.R * 255)
	local g = math.floor(accent.G * 255)
	local b = math.floor(accent.B * 255)
	addSlider("Red", 0, 255, r, function(v) r = v; applyTheme(Color3.fromRGB(r, g, b)) end)
	addSlider("Green", 0, 255, g, function(v) g = v; applyTheme(Color3.fromRGB(r, g, b)) end)
	addSlider("Blue", 0, 255, b, function(v) b = v; applyTheme(Color3.fromRGB(r, g, b)) end)
	addButton("💾 Save as default", function()
		accent = Color3.fromRGB(r, g, b)
		persist()
		notify("Цвет сохранён", THEME.success)
	end)
end)


addPage("Audio", "♫", function()
	label("ASMR / AMBIENCE PLAYER")
	label("Вставь свой Roblox Audio ID")
	local audioInput = addTextBox("Например: 1234567890", SAVED.asmrId or "")
	addSlider("Volume", 0, 100, math.floor(asmrVolume * 100), function(v)
		asmrVolume = v / 100
		if asmrSound then asmrSound.Volume = asmrVolume end
	end)
	addToggle("Loop ambience", function() return asmrEnabled end, function(v)
		asmrEnabled = v
		if asmrSound then asmrSound.Looped = v end
	end)
	addButton("▶ Play ASMR", function()
		local id = audioInput.Text:match("%d+")
		if not id then notify("Введи числовой Audio ID", THEME.danger); return end
		if asmrSound then asmrSound:Stop(); asmrSound:Destroy() end
		local SoundService = game:GetService("SoundService")
		asmrSound = Instance.new("Sound")
		asmrSound.Name = "DogASMR"
		asmrSound.SoundId = "rbxassetid://" .. id
		asmrSound.Volume = asmrVolume
		asmrSound.Looped = asmrEnabled
		asmrSound.Parent = SoundService
		asmrSound:Play()
		SAVED.asmrId = id
		persist()
		notify("ASMR запущен")
	end)
	addButton("■ Stop audio", function()
		if asmrSound then asmrSound:Stop(); asmrSound:Destroy(); asmrSound = nil end
		notify("Audio stopped")
	end)
	label("Заметка: звук должен быть доступен этому experience.")
end)

addPage("Pictures", "▧", function()
	label("MENU IMAGE ID")
	local input = addTextBox("Вставь ID картинки", S.lastImageId)
	addButton("Apply image", function()
		local id = input.Text:match("%d+")
		if not id then
			notify("Нужен числовой ID")
			return
		end
		S.lastImageId = id
		setMenuImage(id)
		persist()
		notify("Image applied")
	end)
	addButton("More visible", function()
		S.imageTransparency = math.max(0, S.imageTransparency - 0.1)
		bgImage.ImageTransparency = S.imageTransparency
		persist()
	end)
	addButton("Less visible", function()
		S.imageTransparency = math.min(1, S.imageTransparency + 0.1)
		bgImage.ImageTransparency = S.imageTransparency
		persist()
	end)
	addButton("Remove image", function()
		setMenuImage(nil)
		notify("Image removed")
	end)
end)

addPage("Info", "ℹ", function()
	if S.hideInfo then label("Раздел Info скрыт в настройках", THEME.danger); return end
	label("DOG IS SCRIPTING V10 — JUBILEE")
	label("Script by @dooggt4_banmrdj")
	label("TG @UOUKAK")
	label("YT @MEGALOLMAN")
	label("TT @.MEGA_LOLMAN")
	label("ADDED: Code ESP, Drawer ESP, ESP distance in studs")
	label("ADDED: Predicted monster path; lift at 10 studs, return at 30 studs")
	label("ADDED: 120 Lighting presets, rainbow ESP colors, brighter loading")
	label("FIXED: ESP distance labels and predicted monster direction update continuously")
	label("REMOVED: Auto Clicker, PC-only click teleport and keyboard shortcuts")
	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then label("❤ Health: " .. math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)) end
	end
	label("🌍 Place ID: " .. game.PlaceId)
	label("👥 Players: " .. #Players:GetPlayers())
	addButton("🔄 Refresh", refreshPage)
end)

if S.hideInfo and S.nav["Info"] then S.nav["Info"].button.Visible = false end

addPage("Settings", "⚙", function()
	label("SETTINGS")
	addToggle("Скрыть раздел Info", function() return S.hideInfo end, function(v)
		S.hideInfo = v
		local entry = S.nav["Info"]
		if entry then entry.button.Visible = not v end
		if v and S.currentPage == "Info" then showPage("Settings") end
	end)
	addToggle("Показать / скрыть HUD", function() return hud.Visible end, function(v) hud.Visible = v end)
	addButton("Reset menu position", function() main.Position = UDim2.fromScale(0.5, 0.5) end)
	addButton("Run custom Settings script (coming soon)", function() notify("Жду назначение отдельного скрипта") end)
	addButton("🚨 PANIC — выключить всё", function()
		setESP("player", false)
		setESP("monster", false)
		setObjectESP("key", false)
		setObjectESP("code", false)
		setObjectESP("closet", false)
		setObjectESP("drawer", false)
		setAntiMonster(false)
		setGodmode(false)
		setRouteESP(false)
		setFullbright(false)
		setNoclip(false)
		setFOV(false)
		setSpeedBoost(false)
		setHighJump(false)
		setInfJump(false)
		notify("ВСЁ ВЫКЛЮЧЕНО", THEME.danger)
		refreshPage()
	end)
	addButton("Hide menu", function() setMenuVisible(false) end)
	addButton("Unload script", function() gui:Destroy() end)
end)

close.Activated:Connect(function() setMenuVisible(false) end)
reopen.Activated:Connect(function()
	setMenuVisible(true)
	main.Size = UDim2.new(0.84, 0, 0.76, 0)
	tween(main, 0.22, {Size = UDim2.new(0.88, 0, 0.8, 0)}):Play()
end)
minimize.Activated:Connect(function() setMenuVisible(false) end)

local dragging, dragStart, startPosition = false, nil, nil
header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPosition = main.Position
	end
end)
connect(UIS.InputChanged, function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X,
			startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
	end
end)
connect(UIS.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

local function hookPlayer(plr)
	if plr == player then return end
	connect(plr.CharacterAdded, function(char)
		if S.playerESP then
			setHighlight(char, "player", true)
			attachESPTag(char, plr.Name, Color3.fromRGB(80, 190, 255))
		end
	end)
end
for _, plr in ipairs(Players:GetPlayers()) do hookPlayer(plr) end

connect(Players.PlayerAdded, function(plr)
	hookPlayer(plr)
	if S.currentPage == "Players" then refreshPage() end
end)
connect(Players.PlayerRemoving, function(plr)
	if S.selectedPlayer == plr then S.selectedPlayer = nil end
	task.delay(0.2, function()
		if S.currentPage == "Players" and gui.Parent then refreshPage() end
	end)
end)
connect(workspace.DescendantAdded, function(obj)
	if S.monsterESP and isMonster(obj) then setHighlight(obj, "monster", true) end
	local kind = classifyObject(obj)
	if kind and S[kind .. "ESP"] then
		task.defer(function() if obj.Parent then setObjectHighlight(obj, kind, true) end end)
	end
	if S.routeESP and isMonster(obj) then setRouteESP(true) end
end)

local function onCharacter(char)
	S.antiMonsterReturn = nil
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	S.original.WalkSpeed = hum.WalkSpeed
	S.original.JumpPower = hum.JumpPower
	S.original.JumpHeight = hum.JumpHeight
	S.original.UseJumpPower = hum.UseJumpPower
	applyMovement()
	if S.godmode then
		local ff = char:FindFirstChild("DogV10_LocalForceField")
		if not ff then ff = Instance.new("ForceField"); ff.Name = "DogV10_LocalForceField"; ff.Visible = false; ff.Parent = char end
	end
	if hideChar then
		task.wait(0.5)
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then part.LocalTransparencyModifier = 1 end
		end
	end
end
connect(player.CharacterAdded, onCharacter)
if player.Character then task.spawn(onCharacter, player.Character) end

gui.Destroying:Connect(function()
	for _, c in ipairs(S.connections) do c:Disconnect() end
	if movementGuard then movementGuard:Disconnect() end
	if S.antiMonsterConn then S.antiMonsterConn:Disconnect() end
	if rainbowConn then rainbowConn:Disconnect() end
	if rainbowIconConn then rainbowIconConn:Disconnect() end
	if asmrSound then asmrSound:Stop(); asmrSound:Destroy(); asmrSound = nil end
	if S.godmodeConn then S.godmodeConn:Disconnect(); S.godmodeConn = nil end
	for _, line in pairs(routeParts) do if line and line.Parent then line:Destroy() end end
	for _, tag in pairs(espTags) do if tag and tag.Parent then tag:Destroy() end end
end)

local defaultId = CONFIG.DEFAULT_IMAGE_ID:match("%d+")
if defaultId then S.lastImageId = defaultId end
if S.lastImageId and S.lastImageId ~= "" then setMenuImage(S.lastImageId) end

task.spawn(function()
	local steps = {"Initializing", "Loading modules", "Building interface", "Almost ready"}
	for i = 1, 100 do
		if not gui.Parent then return end
		loadRingGradient.Rotation = (loadRingGradient.Rotation + 5) % 360
		loadRing.Color = Color3.fromHSV((i / 100) % 1, 0.9, 1)
		loadFill.Size = UDim2.new(i / 100, 0, 1, 0)
		percent.Text = i .. "%"
		loadStatus.Text = steps[math.min(#steps, math.ceil(i / 25))] .. "..."
		task.wait(0.02)
	end
	showPage("Visual")
	main.Visible = true
	S.ready = true
	local fade = TweenService:Create(loading, TweenInfo.new(0.5), {GroupTransparency = 1})
	fade:Play()
	fade.Completed:Wait()
	loading:Destroy()
	notify("DOG IS SCRIPTING V10 загружен!", THEME.success)
end)
