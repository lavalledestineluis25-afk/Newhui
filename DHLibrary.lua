--[[
    DH UI LIBRARY  |  v2.0  |  LOGIC FILE
    ---------------------------------------------------------------
    Host this file (GitHub raw / pastebin raw) and load it with:
        local Library = loadstring(game:HttpGet("YOUR_RAW_LINK"))()

    Features
      * Themes: Black / Crimson / Violet (live switching)
      * Snow particles in: loader, window, toggle button, notifications
      * Full-screen snow + blur while the window is open
      * Floating circle toggle button (drag it, tap it)
      * Tabs live in a drop-down at the top center (wraps to new rows)
      * Collapsible sections, Left / Right columns
      * Toggle, Slider, Dropdown (multi + search), Input, Keybind,
        ColorPicker, Button, Label, Paragraph, Divider
      * Smooth spring window, smooth drag, minimize + close
      * Player headshot + name in the bottom-left corner
      * Config save / load (needs writefile / readfile)
]]

local cloneref = cloneref or function(x) return x end
local function Service(n) return cloneref(game:GetService(n)) end

local Players          = Service("Players")
local TweenService     = Service("TweenService")
local RunService       = Service("RunService")
local UserInputService = Service("UserInputService")
local Lighting         = Service("Lighting")
local CoreGui          = Service("CoreGui")
local HttpService      = Service("HttpService")
local GuiService       = Service("GuiService")
local TextService      = Service("TextService")

local LocalPlayer = Players.LocalPlayer

-- destroy a previous instance if the script is executed twice
local genv = (getgenv and getgenv()) or _G
if genv.DHLibrary and type(genv.DHLibrary.Destroy) == "function" then
    pcall(function() genv.DHLibrary:Destroy() end)
end

--==================================================================--
--  CORE TABLE + THEMES
--==================================================================--
local Library = {
    Version = "2.0.0",
    Flags = {},
    Options = {},
    Windows = {},
    ThemeNames = { "Black", "Crimson", "Violet" },
    Destroyed = false,
    _conns = {}, _steppers = {}, _themed = {}, _hooks = {}, _guis = {}, _snow = {},
    _time = 0, _nid = 0,
}

Library.Themes = {
    Black = {
        Name = "Black",
        Background = Color3.fromRGB(9, 9, 11),
        Surface = Color3.fromRGB(16, 16, 19),
        Surface2 = Color3.fromRGB(24, 24, 29),
        Surface3 = Color3.fromRGB(36, 36, 43),
        Accent = Color3.fromRGB(232, 234, 242),
        Accent2 = Color3.fromRGB(104, 108, 126),
        Text = Color3.fromRGB(240, 240, 246),
        SubText = Color3.fromRGB(142, 144, 158),
        Stroke = Color3.fromRGB(46, 46, 55),
        Particle = Color3.fromRGB(255, 255, 255),
        OnAccent = Color3.fromRGB(10, 10, 12),
    },
    Crimson = {
        Name = "Crimson",
        Background = Color3.fromRGB(13, 5, 8),
        Surface = Color3.fromRGB(22, 9, 13),
        Surface2 = Color3.fromRGB(32, 13, 18),
        Surface3 = Color3.fromRGB(48, 19, 27),
        Accent = Color3.fromRGB(228, 26, 70),
        Accent2 = Color3.fromRGB(128, 10, 40),
        Text = Color3.fromRGB(252, 238, 240),
        SubText = Color3.fromRGB(176, 130, 138),
        Stroke = Color3.fromRGB(70, 26, 37),
        Particle = Color3.fromRGB(255, 208, 218),
        OnAccent = Color3.fromRGB(255, 255, 255),
    },
    Violet = {
        Name = "Violet",
        Background = Color3.fromRGB(10, 7, 19),
        Surface = Color3.fromRGB(17, 12, 31),
        Surface2 = Color3.fromRGB(26, 18, 45),
        Surface3 = Color3.fromRGB(40, 28, 69),
        Accent = Color3.fromRGB(152, 94, 255),
        Accent2 = Color3.fromRGB(74, 36, 170),
        Text = Color3.fromRGB(243, 239, 255),
        SubText = Color3.fromRGB(152, 142, 184),
        Stroke = Color3.fromRGB(52, 39, 90),
        Particle = Color3.fromRGB(220, 198, 255),
        OnAccent = Color3.fromRGB(255, 255, 255),
    },
}
Library.Theme = Library.Themes.Crimson
Library.ThemeName = "Crimson"

local STATUS_ON  = Color3.fromRGB(144, 238, 144) -- light green
local STATUS_OFF = Color3.fromRGB(220, 20, 60)   -- crimson red

--==================================================================--
--  GENERIC HELPERS
--==================================================================--
local function Viewport()
    local cam = workspace.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

local function Tween(inst, time, props, style, dir)
    if not time or time <= 0 then
        for k, v in pairs(props) do inst[k] = v end
        return nil
    end
    local t = TweenService:Create(inst,
        TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function PointerPos(input)
    local inset = GuiService:GetGuiInset()
    return Vector2.new(input.Position.X + inset.X, input.Position.Y + inset.Y)
end

local function Fire(cb, ...)
    if type(cb) ~= "function" then return end
    local ok, err = pcall(cb, ...)
    if not ok then warn("[DH Library] callback error: " .. tostring(err)) end
end

local function Round(v, inc)
    inc = inc or 1
    return math.floor(v / inc + 0.5) * inc
end

local GUIOBJ = { Frame = 1, TextLabel = 1, TextButton = 1, TextBox = 1, ScrollingFrame = 1, ImageLabel = 1, CanvasGroup = 1 }
local TXT = { TextLabel = 1, TextButton = 1, TextBox = 1 }
local CLEAR = { TextLabel = 1, TextButton = 1, ImageLabel = 1, ScrollingFrame = 1 }

local function New(class, props, kids)
    local inst = Instance.new(class)
    if GUIOBJ[class] then
        inst.BorderSizePixel = 0
        if CLEAR[class] then inst.BackgroundTransparency = 1 end
    end
    if TXT[class] then
        inst.Font = Enum.Font.Gotham
        inst.TextSize = 13
        inst.TextColor3 = Color3.new(1, 1, 1)
    end
    if class == "TextButton" then
        inst.AutoButtonColor = false
        inst.Text = ""
    end
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else inst[k] = v end
    end
    for _, c in ipairs(kids or {}) do c.Parent = inst end
    if parent then inst.Parent = parent end
    return inst
end

local function Corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = (typeof(r) == "UDim") and r or UDim.new(0, r or 8)
    c.Parent = parent
    return c
end

local function Pad(parent, t, b, l, r)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, t or 0)
    p.PaddingBottom = UDim.new(0, b or 0)
    p.PaddingLeft = UDim.new(0, l or 0)
    p.PaddingRight = UDim.new(0, r or 0)
    p.Parent = parent
    return p
end

local function List(parent, pad, props)
    local l = Instance.new("UIListLayout")
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, pad or 0)
    for k, v in pairs(props or {}) do l[k] = v end
    l.Parent = parent
    return l
end

local function Reg(inst, prop, key)
    table.insert(Library._themed, { inst, prop, key })
    inst[prop] = Library.Theme[key]
    return inst
end

local function Stroke(parent, key, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    if key then Reg(s, "Color", key) end
    return s
end

local function Label(parent, text, size, key, font, props)
    local l = New("TextLabel", {
        Text = text, TextSize = size or 13, Font = font or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })
    for k, v in pairs(props or {}) do l[k] = v end
    Reg(l, "TextColor3", key or "Text")
    return l
end

local function Chevron(parent, px, key, pos)
    local h = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(px, px),
        Position = pos or UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = parent,
    })
    local L = px * 0.7
    local function bar(rot, dx)
        local b = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(L, 2),
            Position = UDim2.new(0.5, dx, 0.5, -L * 0.177), Rotation = rot, Parent = h,
        })
        Corner(b, 1)
        Reg(b, "BackgroundColor3", key or "SubText")
    end
    bar(45, -L * 0.354)
    bar(-45, L * 0.354)
    return h
end

--==================================================================--
--  CORE METHODS (connections, steppers, themes, guis)
--==================================================================--
function Library:Connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(self._conns, c)
    return c
end

function Library:Step(fn)
    table.insert(self._steppers, fn)
    if not self._loop then
        self._loop = RunService.RenderStepped:Connect(function(dt)
            Library._time = Library._time + dt
            local list = Library._steppers
            for i = #list, 1, -1 do
                local ok, keep = pcall(list[i], dt, Library._time)
                if not ok then
                    warn("[DH Library] stepper error: " .. tostring(keep))
                    table.remove(list, i)
                elseif keep == false then
                    table.remove(list, i)
                end
            end
        end)
    end
end

function Library:_hook(fn)
    table.insert(self._hooks, fn)
    pcall(fn, self.Theme)
end

local function ResolveParent()
    if Library._parent then return Library._parent end
    local p
    if gethui then
        local ok, r = pcall(gethui)
        if ok and r then p = r end
    end
    if not p then
        local ok = pcall(function()
            local t = Instance.new("ScreenGui")
            t.Parent = CoreGui
            t:Destroy()
        end)
        if ok then p = CoreGui end
    end
    p = p or LocalPlayer:WaitForChild("PlayerGui")
    Library._parent = p
    return p
end

function Library:_NewGui(name, order)
    local g = Instance.new("ScreenGui")
    g.Name = name .. "_" .. HttpService:GenerateGUID(false):sub(1, 6)
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    g.DisplayOrder = order or 1
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(g) end
    end)
    g.Parent = ResolveParent()
    table.insert(self._guis, g)
    return g
end

function Library:SetTheme(name, instant)
    local th = self.Themes[name]
    if not th then return end
    self.Theme = th
    self.ThemeName = name
    local d = instant and 0 or 0.4
    local alive = {}
    for _, e in ipairs(self._themed) do
        if e[1] and e[1].Parent then
            Tween(e[1], d, { [e[2]] = th[e[3]] })
            alive[#alive + 1] = e
        end
    end
    self._themed = alive
    for _, h in ipairs(self._hooks) do pcall(h, th) end
    for _, s in ipairs(self._snow) do pcall(s.Recolor) end
    if self.OnThemeChanged then Fire(self.OnThemeChanged, name) end
end

function Library:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    if self._loop then self._loop:Disconnect() end
    for _, g in ipairs(self._guis) do pcall(function() g:Destroy() end) end
    if self._blur then pcall(function() self._blur:Destroy() end) end
    self._steppers = {}
    self._themed = {}
    self._hooks = {}
    self._snow = {}
    if genv.DHLibrary == self then genv.DHLibrary = nil end
end

--==================================================================--
--  SNOW PARTICLE SYSTEM
--==================================================================--
local function NewSnow(container, o)
    o = o or {}
    local sys = {
        Flakes = {}, Container = container, Enabled = true,
        Alpha = o.StartHidden and 0 or 1, AlphaTarget = o.StartHidden and 0 or 1,
        Wind = o.Wind or 0.018, Speed = o.Speed or 1,
    }
    local minS, maxS = o.MinSize or 2, o.MaxSize or 5
    for i = 1, (o.Count or 40) do
        local depth = math.random()
        local size = minS + (maxS - minS) * depth
        local f = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size),
            BackgroundColor3 = Library.Theme.Particle, ZIndex = o.ZIndex or 1, Parent = container,
        })
        Corner(f, 999)
        sys.Flakes[i] = {
            Inst = f, depth = depth, x = math.random(), y = math.random(),
            vy = (0.03 + 0.1 * depth) * (o.SpeedScale or 1),
            sway = 0.006 + 0.03 * depth, phase = math.random() * 6.283,
            freq = 0.5 + math.random() * 1.5, tw = 1 + math.random() * 2,
            baseT = 0.82 - 0.62 * depth,
        }
    end
    sys.Recolor = function()
        for _, fl in ipairs(sys.Flakes) do
            fl.Inst.BackgroundColor3 = Library.Theme.Particle:Lerp(Color3.new(1, 1, 1), fl.depth * 0.55)
        end
    end
    sys.Recolor()
    table.insert(Library._snow, sys)

    Library:Step(function(dt, t)
        if not container.Parent then return false end
        local at = sys.Enabled and sys.AlphaTarget or 0
        sys.Alpha = sys.Alpha + (at - sys.Alpha) * math.min(1, dt * 3.5)
        if sys.Alpha < 0.01 and at == 0 then
            if container.Visible then container.Visible = false end
            return
        end
        if not container.Visible then container.Visible = true end
        local wind = sys.Wind * (1 + 0.6 * math.sin(t * 0.35))
        for _, fl in ipairs(sys.Flakes) do
            fl.y = fl.y + fl.vy * dt * sys.Speed
            fl.x = fl.x + (wind * (0.4 + fl.depth) + math.cos(t * fl.freq + fl.phase) * fl.sway) * dt
            if fl.y > 1.03 then fl.y = -0.03; fl.x = math.random() end
            if fl.x > 1.03 then fl.x = -0.03 elseif fl.x < -0.03 then fl.x = 1.03 end
            local edge = math.clamp(math.min(fl.y, 1 - fl.y) * 9, 0, 1) * math.clamp(math.min(fl.x, 1 - fl.x) * 12, 0, 1)
            local twinkle = 0.65 + 0.35 * (0.5 + 0.5 * math.sin(t * fl.tw + fl.phase))
            fl.Inst.Position = UDim2.fromScale(fl.x, fl.y)
            fl.Inst.BackgroundTransparency = 1 - (1 - fl.baseT) * edge * twinkle * sys.Alpha
        end
    end)
    return sys
end

--==================================================================--
--  DRAGGING (smooth, spring-like lerp)
--==================================================================--
local function MakeDraggable(handle, target, opts)
    opts = opts or {}
    local dragging, moved, startPtr, startPos, goal = false, 0, nil, nil, nil

    local function clampGoal(x, y)
        local vp = Viewport()
        local m = opts.Margin or 30
        x = math.clamp(x, m, vp.X - m)
        y = math.clamp(y, opts.MinY or 0, vp.Y - (opts.BottomMargin or m))
        return UDim2.fromOffset(x, y)
    end

    Library:Connect(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = 0
            startPtr = input.Position
            startPos = target.Position
            goal = target.Position
            if opts.OnStart then opts.OnStart() end
            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if conn then conn:Disconnect() end
                    if opts.OnEnd then opts.OnEnd(moved) end
                    if opts.OnClick and moved < 6 then opts.OnClick() end
                end
            end)
        end
    end)

    Library:Connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - startPtr
            moved = math.max(moved, d.Magnitude)
            if moved >= 6 then
                goal = clampGoal(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
            end
        end
    end)

    Library:Step(function(dt)
        if not target.Parent then return false end
        if goal then
            local cur = target.Position
            local dx = goal.X.Offset - cur.X.Offset
            local dy = goal.Y.Offset - cur.Y.Offset
            if math.abs(dx) < 0.35 and math.abs(dy) < 0.35 then
                target.Position = goal
                if not dragging then goal = nil end
            else
                local a = 1 - math.exp(-(opts.Smooth or 16) * dt)
                target.Position = UDim2.fromOffset(cur.X.Offset + dx * a, cur.Y.Offset + dy * a)
            end
        end
    end)
end

--==================================================================--
--  VISUAL PIECES: ripple, logo, title, tag
--==================================================================--
local function Ripple(btn, ptr)
    local ratio = Library:_R()
    local rel = (ptr - btn.AbsolutePosition) / ratio
    local c = New("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(rel.X, rel.Y),
        Size = UDim2.fromOffset(0, 0), ZIndex = 8, Parent = btn,
    })
    Corner(c, 999)
    local sz = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) / ratio * 2.4
    Tween(c, 0.6, { Size = UDim2.fromOffset(sz, sz), BackgroundTransparency = 1 })
    task.delay(0.65, function() c:Destroy() end)
end

function Library:_R()
    local m = self._mainRef
    if m and m.Parent and self._mainW then
        return math.max(m.AbsoluteSize.X / self._mainW, 0.05)
    end
    return 1
end

local function BuildLogo(parent, px, letter)
    local root = New("Frame", { Size = UDim2.fromOffset(px, px), BackgroundTransparency = 1, Parent = parent })

    local ring = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root,
    })
    Corner(ring, 999)
    local rs = Instance.new("UIStroke")
    rs.Thickness = math.max(1.5, px / 24)
    rs.Color = Color3.new(1, 1, 1)
    rs.Parent = ring
    local rg = Instance.new("UIGradient")
    rg.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.9), NumberSequenceKeypoint.new(1, 0),
    })
    rg.Parent = rs

    local dia = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.5, 0.5), Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), Parent = root,
    })
    Corner(dia, math.max(3, px * 0.1))
    local dg = Instance.new("UIGradient")
    dg.Rotation = 90
    dg.Parent = dia
    local ds = Instance.new("UIStroke")
    ds.Thickness = 1
    ds.Transparency = 0.65
    ds.Color = Color3.new(1, 1, 1)
    ds.Parent = dia

    local inner = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.34, 0.34), Rotation = 45, BackgroundTransparency = 1, Parent = root,
    })
    Corner(inner, math.max(2, px * 0.05))
    Stroke(inner, "OnAccent", 1, 0.55)

    local txt = New("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.5, 0.5), Text = letter or "D", Font = Enum.Font.GothamBlack,
        TextSize = math.max(10, math.floor(px * 0.26)), Parent = root,
    })
    Reg(txt, "TextColor3", "OnAccent")

    local orb = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(math.max(4, px * 0.12), math.max(4, px * 0.12)),
        Parent = root,
    })
    Corner(orb, 999)
    Reg(orb, "BackgroundColor3", "Accent")

    Library:_hook(function(th)
        rg.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, th.Accent), ColorSequenceKeypoint.new(0.5, th.Accent2),
            ColorSequenceKeypoint.new(1, th.Accent),
        })
        dg.Color = ColorSequence.new(th.Accent, th.Accent2)
    end)

    Library:Step(function(dt, t)
        if not root.Parent then return false end
        rg.Rotation = (t * 140) % 360
        dia.Rotation = 45 + math.sin(t * 1.2) * 6
        local a = t * 1.6
        orb.Position = UDim2.new(0.5, math.cos(a) * px * 0.5, 0.5, math.sin(a) * px * 0.5)
    end)
    return root
end

local function BuildTitle(parent, text, size)
    local l = New("TextLabel", {
        Text = text, Font = Enum.Font.GothamBlack, TextSize = size or 16,
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, (size or 16) + 2),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })
    local g = Instance.new("UIGradient")
    g.Parent = l
    Library:_hook(function(th)
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, th.Accent), ColorSequenceKeypoint.new(0.5, th.Text),
            ColorSequenceKeypoint.new(1, th.Accent),
        })
    end)
    Library:Step(function(dt, t)
        if not l.Parent then return false end
        g.Offset = Vector2.new(math.sin(t * 0.9) * 0.6, 0)
    end)
    return l
end

local function BuildTag(parent, text)
    local chip = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 15), Parent = parent,
    })
    Reg(chip, "BackgroundColor3", "Accent")
    chip.BackgroundTransparency = 0.86
    Corner(chip, 5)
    Stroke(chip, "Accent", 1, 0.55)
    Pad(chip, 0, 0, 6, 6)
    local l = New("TextLabel", {
        Text = text, Font = Enum.Font.GothamBold, TextSize = 9, AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 15), Parent = chip,
    })
    Reg(l, "TextColor3", "Accent")
    return chip
end

--==================================================================--
--  NOTIFICATIONS
--==================================================================--
function Library:Notify(cfg)
    if type(cfg) == "string" then cfg = { Content = cfg } end
    cfg = cfg or {}
    if not self._notifyHolder then
        local gui = self:_NewGui("DHNotify", 300)
        self._notifyHolder = New("Frame", {
            AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -18),
            Size = UDim2.new(0, 310, 1, -36), BackgroundTransparency = 1, Parent = gui,
        })
        List(self._notifyHolder, 8, {
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
        })
    end
    self._nid = self._nid + 1

    local kind = cfg.Type or "Info"
    local th = self.Theme
    local colors = {
        Info = th.Accent, Success = Color3.fromRGB(110, 231, 140),
        Warning = Color3.fromRGB(255, 198, 74), Error = Color3.fromRGB(255, 84, 96),
    }
    local icons = { Info = "i", Success = "✓", Warning = "!", Error = "✕" }
    local color = colors[kind] or th.Accent
    local content = cfg.Content or ""
    local dur = cfg.Duration or 4
    local textH = TextService:GetTextSize(content, 12, Enum.Font.Gotham, Vector2.new(226, 1000)).Y
    local H = math.max(62, 40 + textH + 8)

    local wrap = New("Frame", { Size = UDim2.new(1, 0, 0, H), LayoutOrder = self._nid, BackgroundTransparency = 1, Parent = self._notifyHolder })
    local card = New("Frame", {
        Position = UDim2.new(1.2, 0, 0, 0), Size = UDim2.fromScale(1, 1), ClipsDescendants = true,
        BackgroundColor3 = th.Surface, BackgroundTransparency = 0.04, Parent = wrap,
    })
    Corner(card, 10)
    local cs = Instance.new("UIStroke")
    cs.Thickness = 1
    cs.Color = color
    cs.Transparency = 0.55
    cs.Parent = card
    local sheen = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = card })
    local sg = Instance.new("UIGradient")
    sg.Rotation = 0
    sg.Color = ColorSequence.new(color, th.Surface)
    sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.86), NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1) })
    sg.Parent = sheen

    local snowC = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = card })
    NewSnow(snowC, { Count = 9, MinSize = 1.5, MaxSize = 3, ZIndex = 2 })

    New("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = color, ZIndex = 3, Parent = card })
    local ic = New("Frame", {
        Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(26, 26),
        BackgroundColor3 = color, BackgroundTransparency = 0.8, ZIndex = 3, Parent = card,
    })
    Corner(ic, 999)
    New("TextLabel", {
        Size = UDim2.fromScale(1, 1), Text = icons[kind] or "i", Font = Enum.Font.GothamBlack,
        TextSize = 14, TextColor3 = color, ZIndex = 4, Parent = ic,
    })
    New("TextLabel", {
        Position = UDim2.fromOffset(52, 9), Size = UDim2.new(1, -64, 0, 16), Text = cfg.Title or kind,
        Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = th.Text,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = card,
    })
    New("TextLabel", {
        Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -64, 0, textH), Text = content,
        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = th.SubText, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3, Parent = card,
    })
    local bar = New("Frame", {
        Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = color, ZIndex = 4, Parent = card,
    })

    Tween(card, 0.6, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)
    Tween(bar, dur, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)

    local closed = false
    local function dismiss()
        if closed then return end
        closed = true
        Tween(card, 0.4, { Position = UDim2.new(1.25, 0, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.delay(0.35, function()
            Tween(wrap, 0.25, { Size = UDim2.new(1, 0, 0, 0) })
            task.delay(0.3, function() wrap:Destroy() end)
        end)
    end
    local hit = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 9, Parent = card })
    hit.MouseButton1Click:Connect(dismiss)
    task.delay(dur + 0.3, dismiss)
    return { Dismiss = dismiss }
end

--==================================================================--
--  LOADER
--==================================================================--
function Library:_Loader(cfg)
    local gui = self:_NewGui("DHLoader", 500)
    local th = self.Theme
    local dim = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Parent = gui })
    Tween(dim, 0.6, { BackgroundTransparency = 0.32 })

    local bgSnow = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = dim })
    NewSnow(bgSnow, { Count = 80, MinSize = 2, MaxSize = 6, ZIndex = 2 })

    local card = New("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(410, 244), ZIndex = 5, GroupTransparency = 1, Parent = dim,
    })
    Reg(card, "BackgroundColor3", "Background")
    Corner(card, 18)
    local scale = Instance.new("UIScale")
    scale.Scale = 0.82
    scale.Parent = card
    local cg = Instance.new("UIGradient")
    cg.Rotation = 90
    cg.Parent = card
    Library:_hook(function(t) cg.Color = ColorSequence.new(t.Surface2, t.Background) end)
    local cstroke = Instance.new("UIStroke")
    cstroke.Thickness = 1.5
    cstroke.Color = Color3.new(1, 1, 1)
    cstroke.Parent = card
    local csg = Instance.new("UIGradient")
    csg.Parent = cstroke
    Library:_hook(function(t)
        csg.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, t.Accent), ColorSequenceKeypoint.new(0.5, t.Stroke), ColorSequenceKeypoint.new(1, t.Accent2),
        })
    end)

    local cardSnow = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = card })
    NewSnow(cardSnow, { Count = 34, MinSize = 1.5, MaxSize = 4, ZIndex = 2 })

    local logo = BuildLogo(card, 76, string.upper(string.sub(cfg.Name or "D", 1, 1)))
    logo.AnchorPoint = Vector2.new(0.5, 0)
    logo.Position = UDim2.new(0.5, 0, 0, 22)
    logo.ZIndex = 4

    local holder = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108),
        AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), ZIndex = 4, Parent = card,
    })
    List(holder, 8, { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center })
    BuildTitle(holder, cfg.LoaderTitle or cfg.Name or "DH HUB", 22)
    BuildTag(holder, cfg.Tag or "PREMIUM")

    Label(card, cfg.LoaderSubtitle or "Preparing your experience", 11, "SubText", Enum.Font.GothamMedium, {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 140), Size = UDim2.new(1, -40, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4,
    })

    local status = Label(card, "Starting", 11, "Text", Enum.Font.GothamMedium, {
        Position = UDim2.fromOffset(32, 176), Size = UDim2.new(1, -110, 0, 14), ZIndex = 4,
    })
    local pct = Label(card, "0%", 11, "Accent", Enum.Font.GothamBold, {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -32, 0, 176), Size = UDim2.fromOffset(60, 14),
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4,
    })
    local track = New("Frame", { Position = UDim2.fromOffset(32, 198), Size = UDim2.new(1, -64, 0, 7), ZIndex = 4, Parent = card })
    Reg(track, "BackgroundColor3", "Surface3")
    Corner(track, 999)
    local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5, Parent = track })
    Corner(fill, 999)
    local fg = Instance.new("UIGradient")
    fg.Parent = fill
    Library:_hook(function(t) fg.Color = ColorSequence.new(t.Accent2, t.Accent) end)
    local shine = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(26, 12),
        BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, ZIndex = 6, Parent = fill,
    })
    Corner(shine, 999)
    Label(card, "v" .. self.Version .. "  •  " .. self.ThemeName .. " theme", 9, "SubText", Enum.Font.Gotham, {
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, 0, 0, 12),
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4,
    })

    Tween(card, 0.55, { GroupTransparency = 0 })
    Tween(scale, 0.65, { Scale = 1 }, Enum.EasingStyle.Back)
    task.wait(0.5)

    local steps = cfg.LoadingSteps or {
        "Initializing renderer", "Building interface", "Applying theme", "Spawning particles", "Syncing flags", "Ready",
    }
    local from = 0
    for i, s in ipairs(steps) do
        status.Text = s
        local to = math.floor(100 * i / #steps)
        local dur = 0.22 + math.random() * 0.38
        local t0 = tick()
        while tick() - t0 < dur do
            local a = (tick() - t0) / dur
            a = 1 - (1 - a) * (1 - a)
            local p = from + (to - from) * a
            fill.Size = UDim2.fromScale(p / 100, 1)
            pct.Text = math.floor(p) .. "%"
            RunService.RenderStepped:Wait()
        end
        from = to
    end
    fill.Size = UDim2.fromScale(1, 1)
    pct.Text = "100%"
    task.wait(0.35)
    Tween(scale, 0.5, { Scale = 1.08 })
    Tween(card, 0.45, { GroupTransparency = 1 })
    Tween(dim, 0.5, { BackgroundTransparency = 1 })
    task.wait(0.55)
    gui:Destroy()
end

--==================================================================--
--  FLOATING TOGGLE BUTTON (circle)
--==================================================================--
function Library:_BuildFab(window, name)
    local gui = self:_NewGui("DHToggle", 200)
    local vp = Viewport()
    local root = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 1,
        Position = UDim2.fromOffset(46, math.max(120, vp.Y * 0.3)), Parent = gui,
    })
    local rscale = Instance.new("UIScale")
    rscale.Parent = root

    local pulse = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root,
    })
    Corner(pulse, 999)
    local ps = Instance.new("UIStroke")
    ps.Thickness = 2
    ps.Color = STATUS_OFF
    ps.Parent = pulse

    local disc = New("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = root,
    })
    Corner(disc, 999)
    local dg = Instance.new("UIGradient")
    dg.Rotation = 45
    dg.Parent = disc
    Library:_hook(function(t) dg.Color = ColorSequence.new(t.Accent, t.Accent2) end)

    local snowC = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = disc })
    NewSnow(snowC, { Count = 14, MinSize = 1.5, MaxSize = 3.5, ZIndex = 2, SpeedScale = 1.3 })

    local lbl = New("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.45, 0), Size = UDim2.fromScale(1, 0.5),
        Text = name or "DH", Font = Enum.Font.GothamBlack, TextSize = 19, ZIndex = 5, Parent = disc,
    })
    Reg(lbl, "TextColor3", "OnAccent")
    local st = New("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.74, 0), Size = UDim2.fromScale(1, 0.2),
        Text = "OFF", Font = Enum.Font.GothamBold, TextSize = 8, ZIndex = 5, Parent = disc,
    })
    Reg(st, "TextColor3", "OnAccent")

    local ring = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 6, Parent = root,
    })
    Corner(ring, 999)
    local rs = Instance.new("UIStroke")
    rs.Thickness = 3
    rs.Color = STATUS_OFF
    rs.Parent = ring

    local hit = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = root })
    hit.MouseEnter:Connect(function() Tween(rscale, 0.25, { Scale = 1.1 }, Enum.EasingStyle.Back) end)
    hit.MouseLeave:Connect(function() Tween(rscale, 0.25, { Scale = 1 }) end)
    hit.MouseButton1Down:Connect(function() Tween(rscale, 0.12, { Scale = 0.92 }) end)
    hit.MouseButton1Up:Connect(function() Tween(rscale, 0.2, { Scale = 1.1 }, Enum.EasingStyle.Back) end)

    MakeDraggable(hit, root, { Margin = 34, OnClick = function() window:Toggle() end, Smooth = 20 })

    Library:Step(function(dt, t)
        if not root.Parent then return false end
        dg.Rotation = (t * 50) % 360
        local ph = (t % 2.4) / 2.4
        pulse.Size = UDim2.fromScale(1 + 0.55 * ph, 1 + 0.55 * ph)
        ps.Transparency = 0.35 + 0.65 * ph
        ps.Color = rs.Color
    end)

    local fab = { Root = root, Gui = gui }
    function fab:SetState(on)
        Tween(rs, 0.35, { Color = on and STATUS_ON or STATUS_OFF })
        st.Text = on and "ON" or "OFF"
    end
    return fab
end

--==================================================================--
--  WINDOW
--==================================================================--
local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab
local Section = {}
Section.__index = Section

function Library:CreateWindow(cfg)
    cfg = cfg or {}
    if cfg.Theme and self.Themes[cfg.Theme] then self:SetTheme(cfg.Theme, true) end

    local W = (cfg.Size and cfg.Size.X) or 640
    local H = (cfg.Size and cfg.Size.Y) or 430
    local TOP, FOOT = 50, 36

    local win = setmetatable({
        Tabs = {}, Visible = false, Minimized = false, PanelOpen = false, Cfg = cfg,
        SnowOn = cfg.Snow ~= false, BlurOn = cfg.Blur ~= false, BlurSize = cfg.BlurSize or 20,
        ToggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift,
    }, Window)
    table.insert(self.Windows, win)
    genv.DHLibrary = self

    ---------------- background layer (fullscreen snow + tint) ----------------
    local bgGui = self:_NewGui("DHBackdrop", 10)
    bgGui.Enabled = false
    local tint = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Parent = bgGui })
    local tg = Instance.new("UIGradient")
    tg.Rotation = 35
    tg.Parent = tint
    self:_hook(function(t) tg.Color = ColorSequence.new(t.Background, t.Surface3:Lerp(t.Background, 0.55)) end)
    local bgSnowC = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = bgGui })
    local bgSnow = NewSnow(bgSnowC, { Count = cfg.BackgroundSnow or 110, MinSize = 2, MaxSize = 7, ZIndex = 2, StartHidden = true, Wind = 0.03 })

    local blur = Instance.new("BlurEffect")
    blur.Size = 0
    blur.Name = "DHBlur_" .. HttpService:GenerateGUID(false):sub(1, 5)
    blur.Parent = Lighting
    self._blur = blur

    ---------------- main frame ----------------
    local gui = self:_NewGui("DHMain", 50)
    win.Gui = gui
    local vp = Viewport()
    local fit = math.clamp(math.min(vp.X / (W + 40), vp.Y / (H + 60)), 0.45, 1)
    local Main = New("Frame", {
        Name = "Main", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(W, H), Visible = false,
        Position = UDim2.fromOffset(vp.X / 2, math.max(16, (vp.Y - H * fit) / 2)),
        ClipsDescendants = true, BackgroundColor3 = Color3.new(1, 1, 1), Parent = gui,
    })
    win.Main = Main
    self._mainRef = Main
    self._mainW = W
    Corner(Main, 14)
    local ui = Instance.new("UIScale")
    ui.Scale = fit * 0.88
    ui.Parent = Main
    local mg = Instance.new("UIGradient")
    mg.Rotation = 90
    mg.Parent = Main
    self:_hook(function(t) mg.Color = ColorSequence.new(t.Surface, t.Background) end)

    local ms = Instance.new("UIStroke")
    ms.Thickness = 1.6
    ms.Color = Color3.new(1, 1, 1)
    ms.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    ms.Parent = Main
    local msg = Instance.new("UIGradient")
    msg.Parent = ms
    self:_hook(function(t)
        msg.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, t.Accent), ColorSequenceKeypoint.new(0.35, t.Stroke),
            ColorSequenceKeypoint.new(0.65, t.Stroke), ColorSequenceKeypoint.new(1, t.Accent2),
        })
    end)

    -- soft glow orbs
    local orbA = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(240, 240), Position = UDim2.new(0.8, 0, 0.2, 0), BackgroundTransparency = 0.93, ZIndex = 1, Parent = Main })
    Reg(orbA, "BackgroundColor3", "Accent")
    Corner(orbA, 999)
    local orbB = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(220, 220), Position = UDim2.new(0.2, 0, 0.82, 0), BackgroundTransparency = 0.94, ZIndex = 1, Parent = Main })
    Reg(orbB, "BackgroundColor3", "Accent2")
    Corner(orbB, 999)
    self:Step(function(dt, t)
        if not Main.Parent then return false end
        orbA.Position = UDim2.new(0.8 + math.sin(t * 0.25) * 0.05, 0, 0.2 + math.cos(t * 0.3) * 0.05, 0)
        orbB.Position = UDim2.new(0.2 + math.cos(t * 0.22) * 0.05, 0, 0.82 + math.sin(t * 0.28) * 0.05, 0)
    end)

    local winSnowC = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = Main })
    local winSnow = NewSnow(winSnowC, { Count = cfg.WindowSnow or 60, MinSize = 1.5, MaxSize = 4.5, ZIndex = 2, StartHidden = true })

    ---------------- top bar ----------------
    local Top = New("Frame", { Name = "Top", Size = UDim2.new(1, 0, 0, TOP), BackgroundTransparency = 1, ZIndex = 6, Parent = Main })

    local logo = BuildLogo(Top, 34, string.upper(string.sub(cfg.Name or "D", 1, 1)))
    logo.Position = UDim2.fromOffset(16, (TOP - 34) / 2)

    local tblock = New("Frame", {
        Position = UDim2.fromOffset(60, 8), Size = UDim2.fromOffset(190, 20), BackgroundTransparency = 1, Parent = Top,
    })
    List(tblock, 7, { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center })
    BuildTitle(tblock, cfg.Name or "DH HUB", 16)
    BuildTag(tblock, cfg.Tag or "PREMIUM")
    Label(Top, cfg.Subtitle or ("RightShift to toggle  •  v" .. self.Version), 10, "SubText", Enum.Font.Gotham, {
        Position = UDim2.fromOffset(60, 29), Size = UDim2.fromOffset(190, 12),
    })

    -- window control buttons
    local function ControlButton(xOff, kind)
        local b = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xOff, 0.5, 0), Size = UDim2.fromOffset(28, 28),
            BackgroundTransparency = 0.2, ClipsDescendants = true, Parent = Top,
        })
        Reg(b, "BackgroundColor3", "Surface3")
        Corner(b, 8)
        Stroke(b, "Stroke", 1, 0.3)
        local parts = {}
        local function bar(w, rot)
            local f = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(w, 2), Rotation = rot or 0, Parent = b,
            })
            Corner(f, 1)
            Reg(f, "BackgroundColor3", "Text")
            return f
        end
        if kind == "close" then
            parts[1] = bar(13, 45)
            parts[2] = bar(13, -45)
        else
            parts[1] = bar(12, 0)
            local sq = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(11, 11),
                BackgroundTransparency = 1, Visible = false, Parent = b,
            })
            Corner(sq, 3)
            Stroke(sq, "Text", 1.6, 0)
            parts.sq = sq
        end
        b.MouseEnter:Connect(function()
            Tween(b, 0.2, { BackgroundColor3 = kind == "close" and STATUS_OFF or self.Theme.Accent2, BackgroundTransparency = 0 })
        end)
        b.MouseLeave:Connect(function()
            Tween(b, 0.25, { BackgroundColor3 = self.Theme.Surface3, BackgroundTransparency = 0.2 })
        end)
        b.MouseButton1Down:Connect(function(x, y) Ripple(b, Vector2.new(x, y + GuiService:GetGuiInset().Y)) end)
        return b, parts
    end
    local closeBtn = ControlButton(-14, "close")
    local minBtn, minParts = ControlButton(-48, "min")

    -- center tab button
    local tabBtn = New("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, TOP / 2), Size = UDim2.fromOffset(168, 32),
        BackgroundTransparency = 0.1, ClipsDescendants = true, Parent = Top,
    })
    Reg(tabBtn, "BackgroundColor3", "Surface2")
    Corner(tabBtn, 9)
    local tbs = Stroke(tabBtn, "Accent2", 1.2, 0.2)
    local tbGrad = Instance.new("UIGradient")
    tbGrad.Rotation = 90
    tbGrad.Parent = tabBtn
    self:_hook(function(t) tbGrad.Color = ColorSequence.new(t.Surface3, t.Surface2) end)
    local tabLabel = Label(tabBtn, "No tabs", 12, "Text", Enum.Font.GothamBold, {
        Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -68, 1, 0), TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local tabCount = Label(tabBtn, "0/0", 9, "Accent", Enum.Font.GothamBold, {
        Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(26, 32), TextXAlignment = Enum.TextXAlignment.Left,
    })
    local tabChev = Chevron(tabBtn, 12, "Accent", UDim2.new(1, -18, 0.5, 0))
    tabBtn.MouseEnter:Connect(function() Tween(tbs, 0.2, { Transparency = 0 }); Tween(tabBtn, 0.2, { Size = UDim2.fromOffset(176, 32) }) end)
    tabBtn.MouseLeave:Connect(function() Tween(tbs, 0.25, { Transparency = 0.2 }); Tween(tabBtn, 0.25, { Size = UDim2.fromOffset(168, 32) }) end)
    tabBtn.MouseButton1Down:Connect(function(x, y) Ripple(tabBtn, Vector2.new(x, y + GuiService:GetGuiInset().Y)) end)

    -- animated accent line
    local line = New("Frame", {
        Position = UDim2.fromOffset(16, TOP), Size = UDim2.new(1, -32, 0, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 6, Parent = Main,
    })
    local lg = Instance.new("UIGradient")
    lg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.05), NumberSequenceKeypoint.new(1, 1) })
    lg.Parent = line
    self:_hook(function(t) lg.Color = ColorSequence.new(t.Accent, t.Accent2) end)
    self:Step(function(dt, t)
        if not line.Parent then return false end
        lg.Offset = Vector2.new(math.sin(t * 0.8) * 0.35, 0)
    end)

    MakeDraggable(Top, Main, { Margin = 120, BottomMargin = 60, Smooth = 17 })

    ---------------- content ----------------
    local Content = New("Frame", {
        Position = UDim2.fromOffset(0, TOP + 2), Size = UDim2.new(1, 0, 1, -(TOP + 2 + FOOT)),
        BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 3, Parent = Main,
    })
    win.Content = Content

    ---------------- footer ----------------
    local Foot = New("Frame", { Position = UDim2.new(0, 0, 1, -FOOT), Size = UDim2.new(1, 0, 0, FOOT), BackgroundTransparency = 1, ZIndex = 6, Parent = Main })
    local fline = New("Frame", { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 0, 1), ZIndex = 6, Parent = Foot })
    Reg(fline, "BackgroundColor3", "Stroke")
    fline.BackgroundTransparency = 0.3

    local avatar = New("ImageLabel", {
        Position = UDim2.fromOffset(16, 6), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 0, ZIndex = 7, Parent = Foot,
    })
    Reg(avatar, "BackgroundColor3", "Surface3")
    Corner(avatar, 999)
    Stroke(avatar, "Accent", 1.5, 0.1)
    task.spawn(function()
        local ok, img = pcall(function()
            return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok and img and avatar.Parent then avatar.Image = img end
    end)
    Label(Foot, LocalPlayer.DisplayName, 11, "Text", Enum.Font.GothamBold, {
        Position = UDim2.fromOffset(48, 5), Size = UDim2.fromOffset(170, 14), ZIndex = 7, TextTruncate = Enum.TextTruncate.AtEnd,
    })
    Label(Foot, "@" .. LocalPlayer.Name, 9, "SubText", Enum.Font.Gotham, {
        Position = UDim2.fromOffset(48, 18), Size = UDim2.fromOffset(170, 12), ZIndex = 7, TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local status = Label(Foot, "FPS 60", 10, "SubText", Enum.Font.GothamMedium, {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(190, 14),
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 7,
    })
    local acc, frames = 0, 0
    self:Step(function(dt)
        if not status.Parent then return false end
        acc = acc + dt
        frames = frames + 1
        if acc >= 0.5 then
            status.Text = "FPS " .. math.floor(frames / acc + 0.5) .. "  •  " .. Library.ThemeName
            acc, frames = 0, 0
        end
    end)

    ---------------- tab drop-down panel ----------------
    local backdrop = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 55, Visible = false, Parent = Main })
    local Panel = New("CanvasGroup", {
        Name = "TabPanel", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, TOP - 6),
        Size = UDim2.fromOffset(math.min(W - 90, 440), 0), AutomaticSize = Enum.AutomaticSize.Y,
        GroupTransparency = 1, Visible = false, ZIndex = 60, Parent = Main,
    })
    Reg(Panel, "BackgroundColor3", "Surface")
    Corner(Panel, 12)
    Stroke(Panel, "Accent2", 1.3, 0.1)
    Pad(Panel, 10, 12, 12, 12)
    List(Panel, 7, { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, HorizontalAlignment = Enum.HorizontalAlignment.Left })
    local panelHead = Label(Panel, "NAVIGATION", 10, "SubText", Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 0 })

    function win:_OpenPanel(state)
        if state and (self.Minimized or #self.Tabs == 0) then return end
        self.PanelOpen = state
        Tween(tabChev, 0.35, { Rotation = state and 180 or 0 }, Enum.EasingStyle.Back)
        if state then
            Panel.Visible = true
            backdrop.Visible = true
            Panel.Position = UDim2.new(0.5, 0, 0, TOP - 8)
            Tween(Panel, 0.4, { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0, TOP + 8) }, Enum.EasingStyle.Back)
        else
            backdrop.Visible = false
            Tween(Panel, 0.22, { GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0, TOP - 8) })
            task.delay(0.24, function()
                if not self.PanelOpen then Panel.Visible = false end
            end)
        end
    end
    tabBtn.MouseButton1Click:Connect(function() win:_OpenPanel(not win.PanelOpen) end)
    backdrop.MouseButton1Click:Connect(function() win:_OpenPanel(false) end)

    ---------------- window state / animation ----------------
    local anim = { x = 0, v = 0, target = 0 }
    self:Step(function(dt)
        if not Main.Parent then return false end
        dt = math.min(dt, 1 / 30)
        if math.abs(anim.target - anim.x) > 0.0005 or math.abs(anim.v) > 0.001 then
            local acc2 = (anim.target - anim.x) * 230 - anim.v * 21
            anim.v = anim.v + acc2 * dt
            anim.x = anim.x + anim.v * dt
            ui.Scale = fit * (0.88 + 0.12 * math.max(anim.x, 0))
            if anim.target == 0 and anim.x < 0.03 then Main.Visible = false end
        end
    end)

    function win:SetVisible(v)
        self.Visible = v
        anim.target = v and 1 or 0
        if v then Main.Visible = true end
        if not v then self:_OpenPanel(false) end
        winSnow.AlphaTarget = (v and self.SnowOn) and 1 or 0
        bgSnow.AlphaTarget = (v and self.SnowOn) and 1 or 0
        if v then bgGui.Enabled = true end
        Tween(tint, 0.6, { BackgroundTransparency = v and 0.5 or 1 })
        Tween(blur, 0.6, { Size = (v and self.BlurOn) and self.BlurSize or 0 })
        if win.Fab then win.Fab:SetState(v) end
        if not v then
            task.delay(0.8, function()
                if not win.Visible and bgGui.Parent then bgGui.Enabled = false end
            end)
        end
    end
    function win:Toggle() self:SetVisible(not self.Visible) end
    function win:SetSnow(on)
        self.SnowOn = on
        winSnow.AlphaTarget = (self.Visible and on) and 1 or 0
        bgSnow.AlphaTarget = (self.Visible and on) and 1 or 0
    end
    function win:SetBlur(on)
        self.BlurOn = on
        Tween(blur, 0.5, { Size = (self.Visible and on) and self.BlurSize or 0 })
    end
    function win:SetTheme(name) Library:SetTheme(name) end

    function win:Minimize(state)
        if state == nil then state = not self.Minimized end
        self.Minimized = state
        self:_OpenPanel(false)
        minParts[1].Visible = not state
        minParts.sq.Visible = state
        Tween(Main, 0.5, { Size = UDim2.fromOffset(W, state and (TOP + 2) or H) }, Enum.EasingStyle.Quint)
    end
    minBtn.MouseButton1Click:Connect(function() win:Minimize() end)

    function win:Close()
        anim.target = 0
        Tween(blur, 0.4, { Size = 0 })
        Tween(tint, 0.4, { BackgroundTransparency = 1 })
        task.delay(0.45, function()
            if cfg.OnClose then Fire(cfg.OnClose) end
            Library:Destroy()
        end)
    end
    closeBtn.MouseButton1Click:Connect(function() win:Close() end)
    function win:Destroy() Library:Destroy() end

    self:Connect(UserInputService.InputBegan, function(input, gp)
        if not gp and input.KeyCode == win.ToggleKey then win:Toggle() end
    end)

    ---------------- tab selection ----------------
    function win:_Select(tab)
        if self.Selected == tab then
            self:_OpenPanel(false)
            return
        end
        local prev = self.Selected
        self.Selected = tab
        if prev then prev:_Hide() end
        tab:_Show()
        local idx = 1
        for i, t in ipairs(self.Tabs) do
            t:_Paint()
            if t == tab then idx = i end
        end
        tabCount.Text = idx .. "/" .. #self.Tabs
        tabLabel.TextTransparency = 1
        tabLabel.Position = UDim2.fromOffset(34, 8)
        tabLabel.Text = tab.Name
        Tween(tabLabel, 0.35, { TextTransparency = 0, Position = UDim2.fromOffset(34, 0) }, Enum.EasingStyle.Back)
        self:_OpenPanel(false)
    end

    function win:SelectTab(t)
        if type(t) == "number" then t = self.Tabs[t] end
        if type(t) == "string" then
            for _, x in ipairs(self.Tabs) do if x.Name == t then t = x end end
        end
        if type(t) == "table" then self:_Select(t) end
    end

    function win:CreateTab(tcfg)
        if type(tcfg) == "string" then tcfg = { Name = tcfg } end
        tcfg = tcfg or {}
        local tab = setmetatable({ Window = self, Name = tcfg.Name or "Tab", Sections = {}, Selected = false, _token = 0 }, Tab)
        local idx = #self.Tabs + 1
        self.Tabs[idx] = tab

        local chip = New("TextButton", {
            Text = tab.Name, Font = Enum.Font.GothamBold, TextSize = 12, AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 30), LayoutOrder = idx, BackgroundTransparency = 0.05, ClipsDescendants = true, Parent = Panel,
        })
        Corner(chip, 8)
        Pad(chip, 0, 0, 14, 14)
        local cst = Stroke(chip, "Stroke", 1, 0.2)
        local under = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(0, 0, 0, 2), Parent = chip,
        })
        Reg(under, "BackgroundColor3", "OnAccent")
        tab.Chip = chip

        function tab:_Paint()
            local th = Library.Theme
            Tween(chip, 0.3, { BackgroundColor3 = self.Selected and th.Accent or th.Surface2, TextColor3 = self.Selected and th.OnAccent or th.SubText })
            Tween(cst, 0.3, { Color = self.Selected and th.Accent or th.Stroke })
            Tween(under, 0.35, { Size = UDim2.new(self.Selected and 0.7 or 0, 0, 0, 2) }, Enum.EasingStyle.Back)
        end
        Library:_hook(function() tab:_Paint() end)
        chip.MouseEnter:Connect(function()
            if not tab.Selected then Tween(chip, 0.2, { BackgroundColor3 = Library.Theme.Surface3, TextColor3 = Library.Theme.Text }) end
        end)
        chip.MouseLeave:Connect(function()
            if not tab.Selected then Tween(chip, 0.25, { BackgroundColor3 = Library.Theme.Surface2, TextColor3 = Library.Theme.SubText }) end
        end)
        chip.MouseButton1Down:Connect(function(x, y) Ripple(chip, Vector2.new(x, y + GuiService:GetGuiInset().Y)) end)
        chip.MouseButton1Click:Connect(function() win:_Select(tab) end)

        -- page
        local page = New("CanvasGroup", {
            Size = UDim2.fromScale(1, 1), Visible = false, GroupTransparency = 1, BackgroundTransparency = 1, Parent = Content,
        })
        tab.Page = page
        local function column(xs, xo)
            local sf = New("ScrollingFrame", {
                Position = UDim2.new(xs, xo, 0, 8), Size = UDim2.new(0.5, -15, 1, -14),
                CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.Y,
                ScrollBarImageTransparency = 0.3, Parent = page,
            })
            Reg(sf, "ScrollBarImageColor3", "Accent")
            List(sf, 9)
            Pad(sf, 0, 8, 0, 6)
            return sf
        end
        tab.Left = column(0, 10)
        tab.Right = column(0.5, 5)

        function tab:_Show()
            self.Selected = true
            self._token = self._token + 1
            page.Visible = true
            page.Position = UDim2.fromOffset(0, 14)
            Tween(page, 0.45, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
        end
        function tab:_Hide()
            self.Selected = false
            self._token = self._token + 1
            local tok = self._token
            Tween(page, 0.18, { GroupTransparency = 1 })
            task.delay(0.2, function()
                if self._token == tok then page.Visible = false end
            end)
        end

        if idx == 1 then
            win:_Select(tab)
        else
            tab:_Paint()
            tabCount.Text = (win.Selected and table.find(win.Tabs, win.Selected) or 1) .. "/" .. #win.Tabs
        end
        return tab
    end

    ---------------- avatar done; build FAB, loader, show ----------------
    win.Fab = self:_BuildFab(win, cfg.ToggleName or "DH")

    if cfg.LoadingEnabled ~= false then
        self:_Loader(cfg)
    end
    win:SetVisible(true)
    if cfg.Welcome ~= false then
        self:Notify({
            Title = "Welcome, " .. LocalPlayer.DisplayName,
            Content = (cfg.Name or "DH HUB") .. " loaded. Press " .. win.ToggleKey.Name .. " or tap the circle to toggle.",
            Type = "Success", Duration = 5,
        })
    end
    return win
end

--==================================================================--
--  SECTIONS
--==================================================================--
function Tab:CreateSection(a, b)
    local cfg = type(a) == "table" and a or { Name = a, Side = b }
    local parent = (cfg.Side == "Right") and self.Right or self.Left
    local sec = setmetatable({ Tab = self, Window = self.Window, Count = 0, Collapsed = false }, Section)
    table.insert(self.Sections, sec)

    local frame = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 0.12,
        LayoutOrder = #self.Sections, Parent = parent,
    })
    Reg(frame, "BackgroundColor3", "Surface")
    Corner(frame, 11)
    Stroke(frame, "Stroke", 1, 0.2)
    List(frame, 0)

    local header = New("TextButton", { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 0, ClipsDescendants = true, Parent = frame })
    local accentBar = New("Frame", { Position = UDim2.fromOffset(10, 11), Size = UDim2.fromOffset(3, 14), Parent = header })
    Reg(accentBar, "BackgroundColor3", "Accent")
    Corner(accentBar, 2)
    Label(header, cfg.Name or "Section", 12, "Text", Enum.Font.GothamBold, {
        Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -80, 1, 0),
    })
    local badge = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -34, 0.5, 0), Size = UDim2.fromOffset(22, 16), Parent = header,
    })
    Reg(badge, "BackgroundColor3", "Surface3")
    Corner(badge, 5)
    sec.CountLabel = Label(badge, "0", 9, "SubText", Enum.Font.GothamBold, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
    local chev = Chevron(header, 12, "SubText", UDim2.new(1, -16, 0.5, 0))
    header.MouseButton1Down:Connect(function(x, y) Ripple(header, Vector2.new(x, y + GuiService:GetGuiInset().Y)) end)

    local body = New("Frame", { Size = UDim2.new(1, 0, 0, 0), ClipsDescendants = true, LayoutOrder = 1, Parent = frame })
    local inner = New("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = body })
    local ilist = List(inner, 6)
    Pad(inner, 2, 10, 10, 10)
    sec.Inner = inner
    sec.Frame = frame

    local function contentH()
        return ilist.AbsoluteContentSize.Y / Library:_R() + 12
    end
    local function resize()
        if not sec.Collapsed and not sec._animating then
            body.Size = UDim2.new(1, 0, 0, contentH())
        end
    end
    ilist:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)

    function sec:SetCollapsed(state)
        self.Collapsed = state
        self._animating = true
        Tween(chev, 0.35, { Rotation = state and -90 or 0 }, Enum.EasingStyle.Back)
        Tween(body, 0.4, { Size = UDim2.new(1, 0, 0, state and 0 or contentH()) }, Enum.EasingStyle.Quint)
        task.delay(0.42, function() self._animating = false; resize() end)
    end
    function sec:Toggle() self:SetCollapsed(not self.Collapsed) end
    header.MouseButton1Click:Connect(function() sec:Toggle() end)
    if cfg.Collapsed then
        sec.Collapsed = true
        chev.Rotation = -90
    end
    return sec
end

function Tab:CollapseAll(state)
    for _, s in ipairs(self.Sections) do s:SetCollapsed(state ~= false) end
end

function Section:_Row(h)
    self.Count = self.Count + 1
    self.CountLabel.Text = tostring(self.Count)
    local row = New("Frame", {
        Size = UDim2.new(1, 0, 0, h), ClipsDescendants = true, BackgroundTransparency = 0.08, LayoutOrder = self.Count, Parent = self.Inner,
    })
    Reg(row, "BackgroundColor3", "Surface2")
    Corner(row, 8)
    local st = Stroke(row, "Stroke", 1, 0.35)
    return row, st
end

local function Hover(hit, row, st)
    hit.MouseEnter:Connect(function()
        Tween(row, 0.2, { BackgroundColor3 = Library.Theme.Surface3 })
        Tween(st, 0.2, { Color = Library.Theme.Accent2, Transparency = 0 })
    end)
    hit.MouseLeave:Connect(function()
        Tween(row, 0.25, { BackgroundColor3 = Library.Theme.Surface2 })
        Tween(st, 0.25, { Color = Library.Theme.Stroke, Transparency = 0.35 })
    end)
    hit.MouseButton1Down:Connect(function(x, y) Ripple(hit, Vector2.new(x, y + GuiService:GetGuiInset().Y)) end)
end

local function RegisterOption(cfg, obj)
    if cfg.Flag then
        Library.Flags[cfg.Flag] = obj.Value
        Library.Options[cfg.Flag] = obj
    end
end
local function Publish(cfg, obj)
    if cfg.Flag then Library.Flags[cfg.Flag] = obj.Value end
end

--------------------------- Label / Paragraph / Divider ---------------------------
function Section:CreateLabel(cfg)
    if type(cfg) == "string" then cfg = { Text = cfg } end
    local row = self:_Row(30)
    local l = Label(row, cfg.Text or "Label", 12, cfg.Color or "SubText", Enum.Font.GothamMedium, {
        Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0),
    })
    local obj = {}
    function obj:Set(t) l.Text = t end
    return obj
end

function Section:CreateParagraph(cfg)
    cfg = cfg or {}
    local row = self:_Row(0)
    row.AutomaticSize = Enum.AutomaticSize.Y
    Pad(row, 9, 10, 12, 12)
    List(row, 3)
    Label(row, cfg.Title or "Paragraph", 12, "Text", Enum.Font.GothamBold, { Size = UDim2.new(1, 0, 0, 16) })
    local body = Label(row, cfg.Content or "", 11, "SubText", Enum.Font.Gotham, {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2,
    })
    local obj = {}
    function obj:Set(t, c) if t then row:FindFirstChildOfClass("TextLabel").Text = t end if c then body.Text = c end end
    return obj
end

function Section:CreateDivider(text)
    local f = New("Frame", { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = self.Count + 1, Parent = self.Inner })
    self.Count = self.Count + 1
    local l = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 1), Parent = f })
    Reg(l, "BackgroundColor3", "Stroke")
    if text then
        local t = Label(f, " " .. text .. " ", 10, "SubText", Enum.Font.GothamBold, {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 14), BackgroundTransparency = 0,
        })
        Reg(t, "BackgroundColor3", "Surface")
    end
end

--------------------------- Button ---------------------------
function Section:CreateButton(cfg)
    cfg = cfg or {}
    local row, st = self:_Row(cfg.Description and 46 or 36)
    local hit = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = row })
    local dot = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(6, 6), Parent = row })
    Reg(dot, "BackgroundColor3", "Accent")
    Corner(dot, 999)
    Label(row, cfg.Name or "Button", 13, "Text", Enum.Font.GothamMedium, {
        Position = UDim2.fromOffset(28, cfg.Description and 6 or 0), Size = UDim2.new(1, -60, 0, cfg.Description and 18 or 36), ZIndex = 2,
    })
    if cfg.Description then
        Label(row, cfg.Description, 10, "SubText", Enum.Font.Gotham, { Position = UDim2.fromOffset(28, 24), Size = UDim2.new(1, -60, 0, 14), ZIndex = 2 })
    end
    local arrow = Chevron(row, 11, "Accent", UDim2.new(1, -18, 0.5, 0))
    arrow.Rotation = -90
    Hover(hit, row, st)
    hit.MouseEnter:Connect(function() Tween(arrow, 0.25, { Position = UDim2.new(1, -13, 0.5, 0) }, Enum.EasingStyle.Back) end)
    hit.MouseLeave:Connect(function() Tween(arrow, 0.25, { Position = UDim2.new(1, -18, 0.5, 0) }) end)
    hit.MouseButton1Click:Connect(function()
        Tween(dot, 0.12, { Size = UDim2.fromOffset(14, 14) }, Enum.EasingStyle.Quad)
        task.delay(0.12, function() Tween(dot, 0.35, { Size = UDim2.fromOffset(6, 6) }, Enum.EasingStyle.Back) end)
        Fire(cfg.Callback)
    end)
    local obj = {}
    function obj:Fire() Fire(cfg.Callback) end
    return obj
end

--------------------------- Toggle ---------------------------
function Section:CreateToggle(cfg)
    cfg = cfg or {}
    local obj = { Type = "Toggle", Value = cfg.Default == true }
    local row, st = self:_Row(cfg.Description and 48 or 38)
    local hit = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = row })
    Label(row, cfg.Name or "Toggle", 13, "Text", Enum.Font.GothamMedium, {
        Position = UDim2.fromOffset(12, cfg.Description and 7 or 0), Size = UDim2.new(1, -78, 0, cfg.Description and 18 or 38), ZIndex = 2,
    })
    if cfg.Description then
        Label(row, cfg.Description, 10, "SubText", Enum.Font.Gotham, { Position = UDim2.fromOffset(12, 25), Size = UDim2.new(1, -78, 0, 14), ZIndex = 2 })
    end
    local sw = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(42, 22), ZIndex = 2, Parent = row,
    })
    Corner(sw, 999)
    local sws = Instance.new("UIStroke")
    sws.Thickness = 1.2
    sws.Parent = sw
    local knob = New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(16, 16), ZIndex = 3, Parent = sw,
    })
    Corner(knob, 999)

    local function render(animate)
        local th = Library.Theme
        local on = obj.Value
        local d = animate and 0.3 or 0
        Tween(sw, d, { BackgroundColor3 = on and th.Accent or th.Surface3 })
        Tween(sws, d, { Color = on and th.Accent or th.Stroke, Transparency = on and 0.2 or 0.1 })
        Tween(knob, d, {
            Position = on and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
            BackgroundColor3 = on and th.OnAccent or th.SubText,
        }, Enum.EasingStyle.Back)
        if animate then
            Tween(knob, 0.12, { Size = UDim2.fromOffset(20, 16) })
            task.delay(0.12, function() Tween(knob, 0.25, { Size = UDim2.fromOffset(16, 16) }) end)
        end
    end
    Library:_hook(function() render(false) end)

    function obj:Set(v, silent)
        self.Value = v and true or false
        render(true)
        Publish(cfg, self)
        if not silent then Fire(cfg.Callback, self.Value) end
    end
    function obj:Get() return self.Value end
    Hover(hit, row, st)
    hit.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
    RegisterOption(cfg, obj)
    if cfg.Default ~= nil and cfg.CallOnCreate ~= false then task.defer(Fire, cfg.Callback, obj.Value) end
    return obj
end

--------------------------- Slider ---------------------------
function Section:CreateSlider(cfg)
    cfg = cfg or {}
    local min, max = cfg.Min or 0, cfg.Max or 100
    local inc = cfg.Increment or 1
    local suffix = cfg.Suffix or ""
    local decimals = #((tostring(inc):match("%.(%d+)")) or "")
    local function fmt(v)
        if decimals == 0 then return tostring(math.floor(v + 0.5)) .. suffix end
        return string.format("%." .. decimals .. "f", v) .. suffix
    end
    local function clampV(v) return math.clamp(Round(v, inc), min, max) end
    local obj = { Type = "Slider", Value = clampV(cfg.Default or min) }

    local row, st = self:_Row(54)
    Label(row, cfg.Name or "Slider", 13, "Text", Enum.Font.GothamMedium, { Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -90, 0, 16) })
    local vl = Label(row, fmt(obj.Value), 12, "Accent", Enum.Font.GothamBold, {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 7), Size = UDim2.fromOffset(80, 16), TextXAlignment = Enum.TextXAlignment.Right,
    })
    local track = New("Frame", { Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -24, 0, 6), Parent = row })
    Reg(track, "BackgroundColor3", "Surface3")
    Corner(track, 999)
    local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track })
    Corner(fill, 999)
    local fg = Instance.new("UIGradient")
    fg.Parent = fill
    Library:_hook(function(t) fg.Color = ColorSequence.new(t.Accent2, t.Accent) end)
    local knob = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(14, 14), ZIndex = 3, Parent = track,
    })
    Reg(knob, "BackgroundColor3", "Text")
    Corner(knob, 999)
    Stroke(knob, "Accent", 2, 0)
    local tip = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, 0, 0, -9), Size = UDim2.fromOffset(46, 18),
        BackgroundTransparency = 1, ZIndex = 4, Parent = track,
    })
    Reg(tip, "BackgroundColor3", "Accent")
    Corner(tip, 6)
    local tipL = Label(tip, fmt(obj.Value), 10, "OnAccent", Enum.Font.GothamBold, {
        Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, ZIndex = 5,
    })

    local hit = New("TextButton", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 28), ZIndex = 4, Parent = row })
    local alphaOf = function(v) return (v - min) / math.max(max - min, 1e-9) end
    local disp, target = alphaOf(obj.Value), alphaOf(obj.Value)
    local dragging = false

    local function showTip(on)
        Tween(tip, 0.2, { BackgroundTransparency = on and 0 or 1, Position = UDim2.new(0, 0, 0, on and -11 or -6) })
        Tween(tipL, 0.2, { TextTransparency = on and 0 or 1 })
        Tween(knob, 0.2, { Size = on and UDim2.fromOffset(18, 18) or UDim2.fromOffset(14, 14) }, Enum.EasingStyle.Back)
    end

    local function apply(v, silent)
        v = clampV(v)
        target = alphaOf(v)
        if v ~= obj.Value then
            obj.Value = v
            vl.Text = fmt(v)
            tipL.Text = fmt(v)
            Publish(cfg, obj)
            if not silent then Fire(cfg.Callback, v) end
        end
    end
    local function fromX(x)
        local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        apply(min + a * (max - min))
    end

    Library:Step(function(dt)
        if not row.Parent then return false end
        if math.abs(disp - target) > 0.0004 then
            disp = disp + (target - disp) * (1 - math.exp(-24 * dt))
            fill.Size = UDim2.fromScale(disp, 1)
            knob.Position = UDim2.fromScale(disp, 0.5)
            tip.Position = UDim2.new(disp, 0, 0, tip.Position.Y.Offset)
        elseif disp ~= target then
            disp = target
            fill.Size = UDim2.fromScale(disp, 1)
            knob.Position = UDim2.fromScale(disp, 0.5)
            tip.Position = UDim2.new(disp, 0, 0, tip.Position.Y.Offset)
        end
    end)

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            showTip(true)
            fromX(input.Position.X)
        end
    end)
    Library:Connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            fromX(input.Position.X)
        end
    end)
    Library:Connect(UserInputService.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            showTip(false)
        end
    end)
    hit.MouseEnter:Connect(function() Tween(row, 0.2, { BackgroundColor3 = Library.Theme.Surface3 }) end)
    hit.MouseLeave:Connect(function() Tween(row, 0.25, { BackgroundColor3 = Library.Theme.Surface2 }) end)

    function obj:Set(v, silent) apply(v, silent) end
    function obj:Get() return self.Value end
    fill.Size = UDim2.fromScale(disp, 1)
    knob.Position = UDim2.fromScale(disp, 0.5)
    tip.Position = UDim2.new(disp, 0, 0, -6)
    RegisterOption(cfg, obj)
    if cfg.CallOnCreate ~= false then task.defer(Fire, cfg.Callback, obj.Value) end
    return obj
end

--------------------------- Dropdown ---------------------------
function Section:CreateDropdown(cfg)
    cfg = cfg or {}
    local multi = cfg.Multi == true
    local obj = { Type = "Dropdown", Options = cfg.Options or {}, Multi = multi, Value = multi and {} or nil }
    if multi then
        for _, v in ipairs(cfg.Default or {}) do table.insert(obj.Value, v) end
    else
        obj.Value = cfg.Default or nil
    end

    local HEAD = 38
    local row, st = self:_Row(HEAD)
    local hit = New("TextButton", { Size = UDim2.new(1, 0, 0, HEAD), ZIndex = 3, Parent = row })
    Label(row, cfg.Name or "Dropdown", 13, "Text", Enum.Font.GothamMedium, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.5, -12, 0, HEAD), ZIndex = 2 })
    local sel = Label(row, "None", 11, "Accent", Enum.Font.GothamBold, {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -34, 0, 0), Size = UDim2.new(0.5, -40, 0, HEAD),
        TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2,
    })
    local chev = Chevron(row, 12, "Accent", UDim2.new(1, -18, 0, HEAD / 2))
    chev.ZIndex = 2

    local list = New("Frame", { Position = UDim2.fromOffset(8, HEAD + 2), Size = UDim2.new(1, -16, 0, 0), Parent = row })
    local searchH = 0
    local search
    local buttons = {}
    local scroll

    local function listHeight()
        local n = math.min(#obj.Options, 5)
        return searchH + n * 28 + 6
    end

    local function display()
        if multi then
            sel.Text = (#obj.Value == 0) and "None" or table.concat(obj.Value, ", ")
        else
            sel.Text = obj.Value and tostring(obj.Value) or "None"
        end
    end

    local function isSelected(name)
        if multi then return table.find(obj.Value, name) ~= nil end
        return obj.Value == name
    end

    local function paint()
        local th = Library.Theme
        for name, b in pairs(buttons) do
            local s = isSelected(name)
            Tween(b.Btn, 0.2, { BackgroundTransparency = s and 0.78 or 1 })
            Tween(b.Lbl, 0.2, { TextColor3 = s and th.Accent or th.SubText })
            Tween(b.Bar, 0.25, { Size = UDim2.fromOffset(3, s and 14 or 0) }, Enum.EasingStyle.Back)
        end
    end
    Library:_hook(function() paint() end)

    local function fireChange(silent)
        display()
        paint()
        Publish(cfg, obj)
        if not silent then
            if multi then
                local copy = {}
                for _, v in ipairs(obj.Value) do copy[#copy + 1] = v end
                Fire(cfg.Callback, copy)
            else
                Fire(cfg.Callback, obj.Value)
            end
        end
    end

    local function build()
        for _, c in ipairs(list:GetChildren()) do c:Destroy() end
        buttons = {}
        searchH = (#obj.Options > 6) and 30 or 0
        if searchH > 0 then
            search = New("TextBox", {
                Size = UDim2.new(1, 0, 0, 26), Text = "", PlaceholderText = "Search...", Font = Enum.Font.Gotham, TextSize = 12,
                ClearTextOnFocus = false, BackgroundTransparency = 0, Parent = list,
            })
            Reg(search, "BackgroundColor3", "Surface3")
            Reg(search, "TextColor3", "Text")
            Reg(search, "PlaceholderColor3", "SubText")
            Corner(search, 7)
            Pad(search, 0, 0, 10, 10)
            Stroke(search, "Stroke", 1, 0.2)
        end
        scroll = New("ScrollingFrame", {
            Position = UDim2.fromOffset(0, searchH), Size = UDim2.new(1, 0, 0, math.min(#obj.Options, 5) * 28),
            CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, Parent = list,
        })
        Reg(scroll, "ScrollBarImageColor3", "Accent")
        List(scroll, 2)
        for i, name in ipairs(obj.Options) do
            name = tostring(name)
            local b = New("TextButton", { Size = UDim2.new(1, -6, 0, 26), BackgroundTransparency = 1, LayoutOrder = i, ClipsDescendants = true, Parent = scroll })
            Reg(b, "BackgroundColor3", "Accent")
            Corner(b, 6)
            local bar = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.fromOffset(3, 0), Parent = b })
            Reg(bar, "BackgroundColor3", "Accent")
            Corner(bar, 2)
            local lbl = Label(b, name, 12, "SubText", Enum.Font.GothamMedium, { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -20, 1, 0) })
            buttons[name] = { Btn = b, Lbl = lbl, Bar = bar }
            b.MouseEnter:Connect(function() if not isSelected(name) then Tween(lbl, 0.15, { TextColor3 = Library.Theme.Text }) end end)
            b.MouseLeave:Connect(function() if not isSelected(name) then Tween(lbl, 0.2, { TextColor3 = Library.Theme.SubText }) end end)
            b.MouseButton1Down:Connect(function(x, y) Ripple(b, Vector2.new(x, y + GuiService:GetGuiInset().Y)) end)
            b.MouseButton1Click:Connect(function()
                if multi then
                    local idx = table.find(obj.Value, name)
                    if idx then table.remove(obj.Value, idx) else table.insert(obj.Value, name) end
                else
                    obj.Value = name
                end
                fireChange(false)
                if not multi then obj:Toggle(false) end
            end)
        end
        if search then
            search:GetPropertyChangedSignal("Text"):Connect(function()
                local q = string.lower(search.Text)
                for name, b in pairs(buttons) do
                    b.Btn.Visible = (q == "") or (string.find(string.lower(name), q, 1, true) ~= nil)
                end
            end)
        end
        list.Size = UDim2.new(1, -16, 0, listHeight())
        paint()
    end
    build()
    display()

    obj.Open = false
    function obj:Toggle(state)
        if state == nil then state = not self.Open end
        self.Open = state
        Tween(chev, 0.35, { Rotation = state and 180 or 0 }, Enum.EasingStyle.Back)
        Tween(row, 0.4, { Size = UDim2.new(1, 0, 0, state and (HEAD + listHeight() + 8) or HEAD) }, Enum.EasingStyle.Quint)
    end
    function obj:Set(v, silent)
        if multi then
            self.Value = {}
            for _, x in ipairs(v or {}) do table.insert(self.Value, x) end
        else
            self.Value = v
        end
        fireChange(silent)
    end
    function obj:Get() return self.Value end
    function obj:Refresh(newOptions, keep)
        self.Options = newOptions or {}
        if not keep then self.Value = multi and {} or nil end
        build()
        display()
        if self.Open then self:Toggle(true) end
    end
    Hover(hit, row, st)
    hit.MouseButton1Click:Connect(function() obj:Toggle() end)
    RegisterOption(cfg, obj)
    if cfg.Default ~= nil and cfg.CallOnCreate ~= false then
        task.defer(function() fireChange(false) end)
    end
    return obj
end

--------------------------- Input ---------------------------
function Section:CreateInput(cfg)
    cfg = cfg or {}
    local obj = { Type = "Input", Value = cfg.Default or "" }
    local row, st = self:_Row(38)
    Label(row, cfg.Name or "Input", 13, "Text", Enum.Font.GothamMedium, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.5, -12, 1, 0) })
    local box = New("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0.45, 0, 0, 26),
        Text = obj.Value, PlaceholderText = cfg.Placeholder or "Type here...", Font = Enum.Font.GothamMedium, TextSize = 12,
        ClearTextOnFocus = false, BackgroundTransparency = 0, ClipsDescendants = true, Parent = row,
    })
    Reg(box, "BackgroundColor3", "Surface3")
    Reg(box, "TextColor3", "Text")
    Reg(box, "PlaceholderColor3", "SubText")
    Corner(box, 7)
    Pad(box, 0, 0, 8, 8)
    local bs = Stroke(box, "Stroke", 1, 0.1)
    box.Focused:Connect(function() Tween(bs, 0.2, { Color = Library.Theme.Accent, Thickness = 1.6 }) end)
    box.FocusLost:Connect(function(enter)
        Tween(bs, 0.25, { Color = Library.Theme.Stroke, Thickness = 1 })
        if cfg.Numeric then
            local n = tonumber(box.Text)
            if n then box.Text = tostring(n) else box.Text = obj.Value end
        end
        obj.Value = box.Text
        Publish(cfg, obj)
        if enter or cfg.CallOnBlur then Fire(cfg.Callback, obj.Value) end
    end)
    function obj:Set(v, silent)
        self.Value = tostring(v)
        box.Text = self.Value
        Publish(cfg, self)
        if not silent then Fire(cfg.Callback, self.Value) end
    end
    function obj:Get() return self.Value end
    RegisterOption(cfg, obj)
    return obj
end

--------------------------- Keybind ---------------------------
function Section:CreateKeybind(cfg)
    cfg = cfg or {}
    local obj = { Type = "Keybind", Value = cfg.Default }
    local row, st = self:_Row(38)
    local hit = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = row })
    Label(row, cfg.Name or "Keybind", 13, "Text", Enum.Font.GothamMedium, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.6, -12, 1, 0), ZIndex = 2 })
    local kb = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(78, 24), ZIndex = 2, Parent = row,
    })
    Reg(kb, "BackgroundColor3", "Surface3")
    Corner(kb, 7)
    local ks = Stroke(kb, "Accent2", 1, 0.3)
    local kl = Label(kb, "None", 11, "Accent", Enum.Font.GothamBold, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
    local listening = false
    local function show() kl.Text = obj.Value and obj.Value.Name or "None" end
    show()
    Hover(hit, row, st)
    hit.MouseButton1Click:Connect(function()
        listening = true
        kl.Text = "..."
        Tween(ks, 0.2, { Transparency = 0, Thickness = 1.6 })
    end)
    Library:Connect(UserInputService.InputBegan, function(input, gp)
        if listening then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                listening = false
                Tween(ks, 0.25, { Transparency = 0.3, Thickness = 1 })
                if input.KeyCode == Enum.KeyCode.Escape then
                    obj.Value = nil
                else
                    obj.Value = input.KeyCode
                end
                show()
                if cfg.ChangedCallback then Fire(cfg.ChangedCallback, obj.Value) end
            end
        elseif not gp and obj.Value and input.KeyCode == obj.Value then
            Fire(cfg.Callback, obj.Value)
        end
    end)
    function obj:Set(k, silent)
        self.Value = k
        show()
        if not silent and cfg.ChangedCallback then Fire(cfg.ChangedCallback, k) end
    end
    function obj:Get() return self.Value end
    RegisterOption(cfg, obj)
    return obj
end

--------------------------- ColorPicker ---------------------------
function Section:CreateColorPicker(cfg)
    cfg = cfg or {}
    local obj = { Type = "ColorPicker", Value = cfg.Default or Color3.fromRGB(255, 255, 255) }
    local h, s, v = obj.Value:ToHSV()
    local HEAD, FULL = 38, 170

    local row, st = self:_Row(HEAD)
    local hit = New("TextButton", { Size = UDim2.new(1, 0, 0, HEAD), ZIndex = 3, Parent = row })
    Label(row, cfg.Name or "Color", 13, "Text", Enum.Font.GothamMedium, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.5, -12, 0, HEAD), ZIndex = 2 })
    local hex = Label(row, "#FFFFFF", 11, "SubText", Enum.Font.GothamMedium, {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -52, 0, HEAD / 2), Size = UDim2.fromOffset(70, 16),
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 2,
    })
    local sw = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, HEAD / 2), Size = UDim2.fromOffset(30, 18), ZIndex = 2, Parent = row,
    })
    Corner(sw, 5)
    Stroke(sw, "Stroke", 1, 0)

    local area = New("Frame", { Position = UDim2.fromOffset(12, HEAD + 2), Size = UDim2.new(1, -24, 0, FULL - HEAD - 14), Parent = row })
    local sv = New("Frame", { Size = UDim2.new(1, -30, 1, 0), BackgroundColor3 = Color3.fromHSV(h, 1, 1), Parent = area })
    Corner(sv, 6)
    local white = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = sv })
    Corner(white, 6)
    local wg = Instance.new("UIGradient")
    wg.Transparency = NumberSequence.new(0, 1)
    wg.Parent = white
    local black = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = sv })
    Corner(black, 6)
    local bg = Instance.new("UIGradient")
    bg.Rotation = 90
    bg.Transparency = NumberSequence.new(1, 0)
    bg.Parent = black
    local cur = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 5, Parent = sv,
    })
    Corner(cur, 999)
    local cst = Instance.new("UIStroke")
    cst.Thickness = 2
    cst.Color = Color3.new(1, 1, 1)
    cst.Parent = cur

    local hue = New("Frame", {
        Position = UDim2.new(1, -18, 0, 0), Size = UDim2.new(0, 18, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = area,
    })
    Corner(hue, 6)
    local hg = Instance.new("UIGradient")
    hg.Rotation = 90
    hg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)), ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
        ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)), ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
        ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)), ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
        ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 1, 1)),
    })
    hg.Parent = hue
    local hcur = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 4, 0, 6), BackgroundTransparency = 1, ZIndex = 5, Parent = hue,
    })
    Corner(hcur, 3)
    local hst = Instance.new("UIStroke")
    hst.Thickness = 2
    hst.Color = Color3.new(1, 1, 1)
    hst.Parent = hcur

    local function apply(silent)
        obj.Value = Color3.fromHSV(h, s, v)
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        sw.BackgroundColor3 = obj.Value
        cur.Position = UDim2.fromScale(s, 1 - v)
        hcur.Position = UDim2.fromScale(0.5, h)
        hex.Text = string.format("#%02X%02X%02X", math.floor(obj.Value.R * 255 + 0.5), math.floor(obj.Value.G * 255 + 0.5), math.floor(obj.Value.B * 255 + 0.5))
        Publish(cfg, obj)
        if not silent then Fire(cfg.Callback, obj.Value) end
    end
    apply(true)

    local mode
    local function upSV(p)
        s = math.clamp((p.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
        v = 1 - math.clamp((p.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
        apply(false)
    end
    local function upHue(p)
        h = math.clamp((p.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 0.999)
        apply(false)
    end
    sv.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then mode = "sv"; upSV(PointerPos(i)) end
    end)
    hue.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then mode = "hue"; upHue(PointerPos(i)) end
    end)
    Library:Connect(UserInputService.InputChanged, function(i)
        if mode and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            if mode == "sv" then upSV(PointerPos(i)) else upHue(PointerPos(i)) end
        end
    end)
    Library:Connect(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then mode = nil end
    end)

    obj.Open = false
    Hover(hit, row, st)
    hit.MouseButton1Click:Connect(function()
        obj.Open = not obj.Open
        Tween(row, 0.4, { Size = UDim2.new(1, 0, 0, obj.Open and FULL or HEAD) })
    end)
    function obj:Set(c, silent)
        h, s, v = c:ToHSV()
        apply(silent)
    end
    function obj:Get() return self.Value end
    RegisterOption(cfg, obj)
    return obj
end

--==================================================================--
--  CONFIG SAVE / LOAD
--==================================================================--
function Library:SaveConfig(name)
    if not writefile then return false, "writefile unavailable" end
    local data = {}
    for flag, opt in pairs(self.Options) do
        local val = opt.Value
        if opt.Type == "ColorPicker" then
            val = { val.R, val.G, val.B }
        elseif opt.Type == "Keybind" then
            val = val and val.Name or false
        end
        data[flag] = val
    end
    local folder = self.ConfigFolder or "DHLibrary"
    pcall(function() if makefolder and not isfolder(folder) then makefolder(folder) end end)
    local ok, err = pcall(function() writefile(folder .. "/" .. name .. ".json", HttpService:JSONEncode(data)) end)
    return ok, err
end

function Library:LoadConfig(name)
    if not (readfile and isfile) then return false, "readfile unavailable" end
    local path = (self.ConfigFolder or "DHLibrary") .. "/" .. name .. ".json"
    if not isfile(path) then return false, "config not found" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok then return false, "invalid config" end
    for flag, val in pairs(data) do
        local opt = self.Options[flag]
        if opt then
            pcall(function()
                if opt.Type == "ColorPicker" then
                    opt:Set(Color3.new(val[1], val[2], val[3]))
                elseif opt.Type == "Keybind" then
                    opt:Set(val and Enum.KeyCode[val] or nil)
                else
                    opt:Set(val)
                end
            end)
        end
    end
    return true
end

function Library:ListConfigs()
    local out = {}
    if listfiles and isfolder and isfolder(self.ConfigFolder or "DHLibrary") then
        for _, f in ipairs(listfiles(self.ConfigFolder or "DHLibrary")) do
            local n = f:match("([^/\\]+)%.json$")
            if n then out[#out + 1] = n end
        end
    end
    return out
end

genv.DHLibrary = Library
return Library
