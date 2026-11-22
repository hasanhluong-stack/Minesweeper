-- V6.4
-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- PlaceId check
local TARGET_PLACE_ID = 7871169780
if game.PlaceId ~= TARGET_PLACE_ID then
    warn(string.format("[Minesweeper Script] Wrong PlaceId (%s). Expected %s.", tostring(game.PlaceId), tostring(TARGET_PLACE_ID)))
    return
end

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- Determine GUI parent
local guiParent
if type(gethui) == "function" then
    guiParent = gethui()
else
    local success = pcall(function()
        return game:GetService("CoreGui").Name
    end)
    if success then
        guiParent = game:GetService("CoreGui")
    else
        guiParent = player:WaitForChild("PlayerGui")
    end
end

-- Single instance: nếu chạy lại script, dọn bản cũ để không có 2 solver / 2 lớp ESP chạy chồng nhau
local env = (typeof(getgenv) == "function" and getgenv()) or _G
if type(env.__MS_CLEANUP) == "function" then
    pcall(env.__MS_CLEANUP)
end
env.__MS_CLEANUP = nil
for _, ch in ipairs(Workspace:GetChildren()) do
    if ch:IsA("Folder") and string.sub(ch.Name, 1, 14) == "TopEspVisuals_" then
        pcall(function() ch:Destroy() end)
    end
end

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Gui_" .. math.random(10000, 99999)
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 2147483647
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
screenGui.Parent = guiParent

-- GUI: thanh tiêu đề (kéo thả) + thân (nút) + icon nổi để ẩn/hiện
local PANEL_W, TITLE_H, BODY_H = 200, 26, 170
local DRAG_THRESHOLD = 6
local MENU_EDGE_SLACK = 6          -- cho menu lấn nhẹ ra mép trái/phải/dưới để chạm viền
local MENU_TOP_EXTRA = 10          -- nâng mép trên thêm ngần này px (tăng nếu muốn lên cao hơn)
local uiConns = {}

local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.Parent = screenGui
mainFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
mainFrame.Size = UDim2.new(0, PANEL_W, 0, TITLE_H + BODY_H)
mainFrame.Position = UDim2.new(0.3, 0, 0.5, -75)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Active = true

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Parent = mainFrame
titleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
titleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
titleBar.BorderSizePixel = 0
titleBar.Active = true

local titleLabel = Instance.new("TextLabel")
titleLabel.Parent = titleBar
titleLabel.BackgroundTransparency = 1
titleLabel.Position = UDim2.new(0, 8, 0, 0)
titleLabel.Size = UDim2.new(1, -96, 1, 0)
titleLabel.Text = "Minesweeper"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 13
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextTruncate = Enum.TextTruncate.AtEnd

local function createTitleButton(text, xOffset)
    local b = Instance.new("TextButton")
    b.Parent = titleBar
    b.Text = text
    b.Size = UDim2.new(0, 26, 0, 20)
    b.Position = UDim2.new(1, xOffset, 0, 3)
    b.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.AutoButtonColor = true
    b.BorderSizePixel = 0
    return b
end

local collapseBtn = createTitleButton("-", -86)
local gearBtn = createTitleButton("⚙", -58)
gearBtn.Font = Enum.Font.SourceSansBold
gearBtn.TextSize = 18
local closeBtn = createTitleButton("X", -30)

local body = Instance.new("Frame")
body.Name = "Body"
body.Parent = mainFrame
body.BackgroundTransparency = 1
body.Position = UDim2.new(0, 0, 0, TITLE_H)
body.Size = UDim2.new(1, 0, 1, -TITLE_H)
body.BorderSizePixel = 0
body.Active = true

local status = Instance.new("TextLabel")
status.Parent = body
status.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
status.Size = UDim2.new(0, 188, 0, 20)
status.Position = UDim2.new(0, 6, 0, 2)
status.Text = "Status: Offline"
status.TextColor3 = Color3.fromRGB(255, 0, 0)
status.TextScaled = true
status.BorderSizePixel = 0

local function createButton(name, text, x, y, width, height, textColor)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Parent = body
    btn.Text = text
    btn.Size = UDim2.new(0, width, 0, height)
    btn.Position = UDim2.new(0, x, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
    btn.TextScaled = true
    btn.AutoButtonColor = true
    btn.BorderSizePixel = 0
    return btn
end

local toggleBtn  = createButton("ToggleBtn", "ESP: OFF", 8, 26, 88, 26, Color3.fromRGB(255, 120, 120))
local autoFlagBtn = createButton("AutoFlagBtn", "AUTO FLAG: OFF", 104, 26, 88, 26, Color3.fromRGB(255, 120, 120))
local antiLagBtn = createButton("AntiLagBtn", "ANTI-LAG: OFF", 8, 56, 88, 26, Color3.fromRGB(255, 255, 255))
local endlessBtn = createButton("EndlessBtn", "ENDLESS: OFF", 104, 56, 88, 26, Color3.fromRGB(255, 170, 0))
local autoOpenBtn = createButton("AutoOpenBtn", "AUTO OPEN: OFF", 8, 86, 184, 24, Color3.fromRGB(0, 255, 255))

local flagWarningLabel = Instance.new("TextLabel")
flagWarningLabel.Name = "FlagWarningLabel"
flagWarningLabel.Parent = body
flagWarningLabel.Text = "Flag skins can cause bugs."
flagWarningLabel.Size = UDim2.new(0, 184, 0, 14)
flagWarningLabel.Position = UDim2.new(0, 8, 0, 114)
flagWarningLabel.BackgroundTransparency = 1
flagWarningLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
flagWarningLabel.TextScaled = true
flagWarningLabel.Font = Enum.Font.SourceSansBold
flagWarningLabel.BorderSizePixel = 0

local antiLagNoteLabel = Instance.new("TextLabel")
antiLagNoteLabel.Name = "AntiLagNoteLabel"
antiLagNoteLabel.Parent = body
antiLagNoteLabel.Text = "Anti-Lag: lighter Endless (60 studs)."
antiLagNoteLabel.Size = UDim2.new(0, 184, 0, 14)
antiLagNoteLabel.Position = UDim2.new(0, 8, 0, 128)
antiLagNoteLabel.BackgroundTransparency = 1
antiLagNoteLabel.TextColor3 = Color3.fromRGB(255, 170, 100)
antiLagNoteLabel.TextScaled = true
antiLagNoteLabel.Font = Enum.Font.SourceSansBold
antiLagNoteLabel.BorderSizePixel = 0

local destroyBtn = createButton("DestroyBtn", "Destroy UI", 8, 146, 184, 20, Color3.fromRGB(255, 100, 100))

-- Icon nổi (kéo được, chạm để ẩn/hiện bảng)
local iconBtn = Instance.new("TextButton")
iconBtn.Name = "ToggleIcon"
iconBtn.Parent = screenGui
iconBtn.Size = UDim2.new(0, 38, 0, 38)
iconBtn.Position = UDim2.new(0, 10, 0.5, -19)
iconBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
iconBtn.BackgroundTransparency = 0.15
iconBtn.Text = "MS"
iconBtn.TextColor3 = Color3.fromRGB(0, 255, 0)
iconBtn.Font = Enum.Font.GothamBold
iconBtn.TextSize = 14
iconBtn.AutoButtonColor = false
iconBtn.BorderSizePixel = 0
local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(0, 19)
iconCorner.Parent = iconBtn

-- Cài đặt có thể chỉnh trong trang Settings (bánh răng). Giá trị mặc định = giá trị đang dùng trong script.
local SET = {
    flagDelay = 0.02,  -- giây giữa mỗi lô cờ được đặt / tháo
    flagBatch = 1,     -- số cờ đặt / tháo trong mỗi lô (tốc độ ≈ flagBatch / flagDelay cờ mỗi giây; 1 = mỗi flagDelay một cờ)
    openDelay = 0.05,  -- giây giữa mỗi lô ô được mở
    openBatch = 30,    -- số ô mở trong mỗi lô (tốc độ mở ≈ openBatch / openDelay ô mỗi giây)
    actRange = 60,        -- phạm vi thao tác của Auto Flag / Auto Open (studs)
    totalMines = 100,     -- tổng số mìn của bàn (dùng cho suy luận theo tổng số mìn + hiển thị)
    hereThreshold = 90,   -- thanh Here chỉ hiện khi số mìn script đã biết >= giá trị này
    markLeftover = true,  -- Đánh dấu ô còn sót: bật thanh Here (độc lập với ESP) - mặc định BẬT
    antiStatic = false, -- Anti-Static: vô hiệu hóa mọi thứ trong PlayerGui.Gui
    noStep = false,    -- Không giẫm mìn: tắt CanTouch của các ô script biết là mìn
    open = false,      -- đang ở trang Settings?
    page = nil,
}
-- Khoảng giá trị cho phép của các ô nhập: { min, max, là số nguyên }
SET.limits = {
    flagDelay = { 0.01, 5, false },
    flagBatch = { 1, 60, true },
    openDelay = { 0.01, 5, false },
    openBatch = { 1, 60, true },
    actRange = { 10, 300, false },
    totalMines = { 1, 99999, true },
    hereThreshold = { 0, 99999, true },
}
SET.boolKeys = { "noStep", "antiStatic", "markLeftover" } -- các công tắc được lưu (không lưu ESP / Auto Flag / Auto Open)

local DEFAULTS = {}
for key in pairs(SET.limits) do DEFAULTS[key] = SET[key] end

-- LƯU / NẠP cài đặt (JSON). File: <Workspace của Delta>/MinesweeperS/Save
--   = /storage/emulated/0/Delta/Workspace/MinesweeperS/Save
SET.saveDir = "MinesweeperS"
SET.savePath = "MinesweeperS/Save"
SET.saveAbs = "/storage/emulated/0/Delta/Workspace/MinesweeperS/Save"
SET.saveMsg = ""
SET.saveQueued = false

function SET.setMsg(text)
    SET.saveMsg = text
    if SET.msgLabel then SET.msgLabel.Text = text end
end

function SET.collect()
    local t = {}
    for key in pairs(SET.limits) do t[key] = SET[key] end
    for _, key in ipairs(SET.boolKeys) do t[key] = SET[key] == true end
    return t
end

function SET.save()
    if type(writefile) ~= "function" then
        SET.setMsg("Save: writefile unavailable")
        return false
    end

    local okEnc, data = pcall(function()
        return game:GetService("HttpService"):JSONEncode(SET.collect())
    end)
    if not okEnc then
        SET.setMsg("Save: encode failed")
        return false
    end

    -- tạo thư mục MinesweeperS nếu chưa có
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(SET.saveDir) then
            makefolder(SET.saveDir)
        end
    end)

    local ok = pcall(writefile, SET.savePath, data)
    if not ok then
        ok = pcall(writefile, SET.saveAbs, data) -- phòng khi executor nhận đường dẫn tuyệt đối
    end
    SET.setMsg(ok and "Saved: MinesweeperS/Save" or "Save: write failed")
    return ok
end

-- Lưu tự động sau khi đổi cài đặt (gộp nhiều thay đổi liên tiếp thành một lần ghi)
function SET.queueSave()
    if SET.saveQueued then return end
    SET.saveQueued = true
    task.delay(0.6, function()
        SET.saveQueued = false
        SET.save()
    end)
end

function SET.load()
    if type(readfile) ~= "function" then
        SET.setMsg("Save: readfile unavailable")
        return false
    end

    local function try(path)
        local ok, res = pcall(function()
            if type(isfile) == "function" and not isfile(path) then return nil end
            return readfile(path)
        end)
        if ok and type(res) == "string" and #res > 0 then return res end
        return nil
    end

    local raw = try(SET.savePath) or try(SET.saveAbs)
    if not raw then
        SET.setMsg("No save file yet (defaults)")
        return false
    end

    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(raw)
    end)
    if not ok or type(data) ~= "table" then
        SET.setMsg("Save file unreadable (defaults)")
        return false
    end

    for key, lim in pairs(SET.limits) do
        local v = tonumber(data[key])
        if v then
            v = math.clamp(v, lim[1], lim[2])
            if lim[3] then v = math.floor(v + 0.5) end
            SET[key] = v
        end
    end
    for _, key in ipairs(SET.boolKeys) do
        if type(data[key]) == "boolean" then SET[key] = data[key] end
    end

    SET.setMsg("Loaded: MinesweeperS/Save")
    if SET.refreshUI then SET.refreshUI() end
    return true
end
local requestEngine -- shared solver lifecycle; assigned after solver functions are defined

local collapsed = false

local function applyPages()
    body.Visible = (not collapsed) and not SET.open
    if SET.page then SET.page.Visible = (not collapsed) and SET.open end
    -- trang Settings cao hơn trang chính một chút
    mainFrame.Size = UDim2.new(0, PANEL_W, 0, collapsed and TITLE_H or (TITLE_H + (SET.open and 230 or BODY_H)))
end

local function setCollapsed(c)
    collapsed = c
    applyPages()
    collapseBtn.Text = c and "+" or "-"
    titleLabel.Text = c and status.Text or "Minesweeper"
end

local function setPanelVisible(v)
    mainFrame.Visible = v
    iconBtn.TextColor3 = v and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
end

-- Khi thu gọn, thanh tiêu đề hiện luôn trạng thái
status:GetPropertyChangedSignal("Text"):Connect(function()
    if collapsed then titleLabel.Text = status.Text end
end)

-- Kéo thả dùng chung (PC + Mobile): theo dõi toàn màn hình, giới hạn trong khung nhìn,
-- ngưỡng 6px để phân biệt "chạm" và "kéo"
local function makeDraggable(handle, target, onTap)
    local dragging, moved = false, false
    local dragStart, startAbs, startPosition

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragStart = input.Position
            startAbs = target.AbsolutePosition
            startPosition = target.Position

            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    conn:Disconnect()
                    if not moved and onTap then onTap() end
                end
            end)
        end
    end)

    table.insert(uiConns, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart
        if not moved and delta.Magnitude < DRAG_THRESHOLD then return end
        moved = true

        -- Giới hạn theo đúng vùng vẽ của ScreenGui (ViewportSize có thể lệch phần inset),
        -- cho lấn nhẹ ra mép để menu chạm viền; mép trên được nâng thêm MENU_TOP_EXTRA px
        local gp = screenGui.AbsolutePosition
        local gs = screenGui.AbsoluteSize
        if gs.X < 1 or gs.Y < 1 then
            local cam = Workspace.CurrentCamera
            gs = cam and cam.ViewportSize or Vector2.new(1280, 720)
        end
        local size = target.AbsoluteSize
        local minX, minY = gp.X - MENU_EDGE_SLACK, gp.Y - MENU_TOP_EXTRA
        local maxX = math.max(minX, gp.X + gs.X - size.X + MENU_EDGE_SLACK)
        local maxY = math.max(minY, gp.Y + gs.Y - size.Y + MENU_EDGE_SLACK)
        local x = math.clamp(startAbs.X + delta.X, minX, maxX)
        local y = math.clamp(startAbs.Y + delta.Y, minY, maxY)
        local clampedDelta = Vector2.new(x - startAbs.X, y - startAbs.Y)

        -- Preserve the original scale components; only apply the pointer delta.
        -- This avoids converting screen coordinates directly into parent-local offsets,
        -- which can make the GUI jump upward when dragged on mobile.
        target.Position = UDim2.new(
            startPosition.X.Scale, startPosition.X.Offset + clampedDelta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + clampedDelta.Y
        )
    end))
end

makeDraggable(titleBar, mainFrame)
makeDraggable(body, mainFrame)
makeDraggable(iconBtn, iconBtn, function() setPanelVisible(not mainFrame.Visible) end)

do
    local page = Instance.new("ScrollingFrame")
    page.Name = "SettingsPage"
    page.Parent = mainFrame
    page.BackgroundTransparency = 1
    page.Position = UDim2.new(0, 0, 0, TITLE_H)
    page.Size = UDim2.new(1, 0, 1, -TITLE_H)
    page.BorderSizePixel = 0
    page.Active = true
    page.Visible = false
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.ScrollBarThickness = 4
    page.CanvasSize = UDim2.new(0, 0, 0, 360)
    SET.page = page

    local function makeLabel(text, x, y, w, h, color, size)
        local l = Instance.new("TextLabel")
        l.Parent = page
        l.BackgroundTransparency = 1
        l.Position = UDim2.new(0, x, 0, y)
        l.Size = UDim2.new(0, w, 0, h)
        l.Text = text
        l.TextColor3 = color or Color3.fromRGB(255, 255, 255)
        l.Font = Enum.Font.GothamMedium
        l.TextSize = size or 13
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.BorderSizePixel = 0
        return l
    end

    local function makeButton(x, y, w, text, color)
        local b = Instance.new("TextButton")
        b.Parent = page
        b.Position = UDim2.new(0, x, 0, y)
        b.Size = UDim2.new(0, w, 0, 22)
        b.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        b.TextColor3 = color or Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 13
        b.Text = text
        b.AutoButtonColor = true
        b.BorderSizePixel = 0
        return b
    end

    makeLabel("Settings (scroll)", 8, 2, 184, 18, Color3.fromRGB(255, 220, 100), 14).Font = Enum.Font.GothamBold

    local info = makeLabel("", 8, 288, 184, 16, Color3.fromRGB(170, 220, 255), 12)
    local boxes = {}

    local function fmt(v)
        return tostring(math.floor(v * 1000 + 0.5) / 1000)
    end

    local function refreshInfo()
        local flagsPerSec = SET.flagBatch / SET.flagDelay
        local opensPerSec = SET.openBatch / SET.openDelay
        info.Text = string.format("~%.0f flags/s | ~%.0f opens/s", flagsPerSec, opensPerSec)
    end

    local function refreshBoxes()
        for key, box in pairs(boxes) do
            box.Text = SET.limits[key][3] and tostring(SET[key]) or fmt(SET[key])
        end
        refreshInfo()
    end

    -- Một dòng: nhãn + ô nhập. Nhập sai thì trả về giá trị cũ; nhập ngoài khoảng thì bị kẹp lại.
    local function makeRow(key, label, y)
        local lim = SET.limits[key]
        makeLabel(label, 8, y, 112, 22)
        local box = Instance.new("TextBox")
        box.Parent = page
        box.Position = UDim2.new(0, 124, 0, y)
        box.Size = UDim2.new(0, 68, 0, 22)
        box.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        box.TextColor3 = Color3.fromRGB(255, 255, 255)
        box.Font = Enum.Font.GothamMedium
        box.TextSize = 13
        box.ClearTextOnFocus = false
        box.BorderSizePixel = 0
        box.Text = ""
        boxes[key] = box

        box.FocusLost:Connect(function()
            local v = tonumber(box.Text)
            if v then
                v = math.clamp(v, lim[1], lim[2])
                if lim[3] then v = math.floor(v + 0.5) end
                SET[key] = v
                SET.queueSave()
            end
            refreshBoxes()
        end)
    end

    makeRow("flagDelay", "Flag delay (s)", 24)
    makeRow("flagBatch", "Flag batch", 50)
    makeRow("openDelay", "Open delay (s)", 76)
    makeRow("openBatch", "Open batch", 102)
    makeRow("actRange", "Action range", 128)
    makeRow("totalMines", "Total mines", 154)
    makeRow("hereThreshold", "Here at mines", 180)

    -- Công tắc bật / tắt
    local function makeToggle(y, name, getter)
        local b = makeButton(8, y, 184, name)
        local function refresh()
            if getter() then
                b.Text = name .. ": ON"
                b.TextColor3 = Color3.fromRGB(0, 255, 0)
            else
                b.Text = name .. ": OFF"
                b.TextColor3 = Color3.fromRGB(255, 120, 120)
            end
        end
        refresh()
        return b, refresh
    end

    -- Không giẫm mìn: khi bật, mọi ô script đánh dấu / biết là mìn sẽ bị tắt CanTouch
    local noStepBtn, refreshNoStep = makeToggle(208, "NO-STEP MINES", function() return SET.noStep end)
    noStepBtn.MouseButton1Click:Connect(function()
        SET.noStep = not SET.noStep
        refreshNoStep()
        if not SET.noStep and SET.restore then SET.restore() end
        if requestEngine and not requestEngine() then
            SET.noStep = false
            if SET.restore then SET.restore() end
            refreshNoStep()
        end
        SET.queueSave()
    end)

    -- Anti-Static: bật = vô hiệu hóa mọi thứ trong game.Players.LocalPlayer.PlayerGui.Gui; tắt = hoạt động lại
    local antiBtn, refreshAnti = makeToggle(234, "ANTI-STATIC", function() return SET.antiStatic end)
    antiBtn.MouseButton1Click:Connect(function()
        if SET.setAntiStatic then SET.setAntiStatic(not SET.antiStatic) end
        refreshAnti()
        SET.queueSave()
    end)

    -- Đánh dấu ô còn sót: bật / tắt thanh Here, riêng với ESP
    local markBtn, refreshMark = makeToggle(260, "MARK LEFTOVER", function() return SET.markLeftover end)
    markBtn.MouseButton1Click:Connect(function()
        SET.markLeftover = not SET.markLeftover
        -- bật: khởi động bộ giải dùng chung nếu cần; tắt: dừng nó nếu không còn tính năng nào cần
        if requestEngine and not requestEngine() then
            SET.markLeftover = false
        end
        refreshMark()
        SET.queueSave()
    end)

    -- Lưu / đặt lại
    local saveBtn = makeButton(8, 308, 90, "Save now", Color3.fromRGB(0, 255, 0))
    saveBtn.MouseButton1Click:Connect(function() SET.save() end)

    local reset = makeButton(102, 308, 90, "Reset defaults", Color3.fromRGB(255, 170, 0))
    reset.MouseButton1Click:Connect(function()
        for key, v in pairs(DEFAULTS) do SET[key] = v end
        refreshBoxes()
        SET.queueSave()
    end)

    SET.msgLabel = makeLabel(SET.saveMsg, 8, 334, 184, 16, Color3.fromRGB(170, 220, 255), 11)

    SET.refreshUI = function()
        refreshBoxes()
        refreshNoStep()
        refreshAnti()
        refreshMark()
    end

    refreshBoxes()
end

gearBtn.MouseButton1Click:Connect(function()
    if collapsed then setCollapsed(false) end
    SET.open = not SET.open
    gearBtn.TextColor3 = SET.open and Color3.fromRGB(255, 220, 100) or Color3.fromRGB(255, 255, 255)
    applyPages()
end)
collapseBtn.MouseButton1Click:Connect(function() setCollapsed(not collapsed) end)
closeBtn.MouseButton1Click:Connect(function() setPanelVisible(false) end)

-------------------------------------------------------------------------------
-- CONFIG
-------------------------------------------------------------------------------

local BATCH_SIZE = 30                -- số ô chạm song song mỗi vòng
local LAST_TILE_DEDUCTION = true     -- tự suy ra các ô còn lại khi đã biết hết phần còn lại (dựa trên tổng số mìn)
local GLOBAL_MINES_ENABLED = true    -- dùng ràng buộc "tổng số mìn" (tự tắt nếu dữ liệu mâu thuẫn)
local SOLVE_RANGE = 120              -- phạm vi giải khi Anti-Lag OFF (studs)
local ANTI_LAG_DISTANCE = 60         -- phạm vi giải khi Anti-Lag ON (studs)
local SOLVER_CONTEXT_PADDING = 8
local FLAG_REFRESH_INTERVAL = 0.5
local VISUALS_IN_WORKSPACE = true
local LOOP_INTERVAL = 0.1
local FORCE_SOLVE_INTERVAL = 2       -- ép giải lại tối thiểu mỗi 2s dù trạng thái không đổi
local MAX_COMPONENT_CELLS = 26       -- cụm biên lớn hơn mức này dùng suy luận tập hợp thay vì liệt kê
local MAX_ENUM_NODES = 40000         -- trần số nút backtracking mỗi cụm
local BULK_CHANGE_THRESHOLD = 150    -- số part thêm/xoá cùng lúc coi là "ván mới"
local FLAG_CELL = 6                  -- kích thước ô lưới băm vị trí cờ

-------------------------------------------------------------------------------
-- STATE
-------------------------------------------------------------------------------

-- Endless mode: phạm vi giải dùng chung SOLVE_RANGE / ANTI_LAG_DISTANCE
local ENDLESS_RANGE = SOLVE_RANGE
local ENDLESS_REFRESH_DIST = 8        -- di chuyển quá mức này thì quét lại cửa sổ part
local ENDLESS_REFRESH_INTERVAL = 2    -- hoặc mỗi 2s (bắt tile mới sinh ra)
local ENDLESS_GUESS_OUTSIDE = false   -- false: Endless chỉ đoán trên ô biên (không đoán ô vàng ở vùng chưa có thông tin)
local CONFIRM_DELAY = 0.2             -- (Endless) ô mìn/an toàn phải tồn tại >= 0.2s mới được auto touch
local ENDLESS_DEFAULT_DENSITY = 0.2   -- xác suất mìn ước lượng cho ô chưa có thông tin

local isEndlessOn = false
local endlessLastCenter = nil
local endlessTileDim = 8
local customUnrevealed = nil           -- màu ô chưa mở đã học thêm (Endless), dùng song song với màu mặc định
local markTime = setmetatable({}, { __mode = "k" })
local endlessLastRefresh = 0
local ENDLESS_FULL_RING = 8            -- Endless: chỉ tin ô số có đủ 8 ô xung quanh (kể cả ô đã mở trống)
-- Endless engine: state + profile gói trong 1 bảng (tránh vượt giới hạn 200 biến local của Luau)
local EL = {
    grid = {},       -- [cellKey] = { [part] = true }: mọi part trong cửa sổ (kể cả ô đã mở trống)
    cand = {},       -- [part] = true nếu là ô (tile candidate)
    ring = {},       -- [part] = số ô thực sự nằm quanh nó
    pkey = {},       -- [part] = cellKey đã dùng khi thêm vào grid
    ringValid = false,
    cell = 8,
    built = false,
    cursor = 1,
    version = 0,     -- tăng mỗi khi trạng thái ô / cửa sổ đổi -> quyết định có cần giải lại không
    epoch = 0,       -- tăng khi reset, để huỷ lần dựng cửa sổ đang dở
    dirty = false,
    lastCalib = -100,
    lastSync = 0,
    accU = 0, accN = 0,
    stats = { unrev = 0, num = 0 },
    done = setmetatable({}, { __mode = "k" }), -- ô số mà mọi ô xung quanh đã mở (không còn ràng buộc)
    -- Anti-Lag OFF
    full = {
        solveRange = 100, visualRange = 100, visualCap = 220,
        scanBudget = 0.008, solveBudget = 0.015, tick = 0.1,
        maxCells = 24, maxNodes = 15000,
        refreshGap = 0.6, refreshInterval = 2, flagInterval = 0.8, forceSolve = 2,
    },
    -- Anti-Lag ON: nhẹ hơn cho Endless (phạm vi nhỏ, quét/giải ít hơn, ít ESP hơn)
    light = {
        solveRange = 60, visualRange = 60, visualCap = 90,
        scanBudget = 0.005, solveBudget = 0.008, tick = 0.2,
        maxCells = 20, maxNodes = 6000,
        refreshGap = 1.2, refreshInterval = 3, flagInterval = 1.2, forceSolve = 3,
    },
}
function EL.prof()
    return isAntiLagOn and EL.light or EL.full
end

local lastConflictTime = -10           -- thời điểm solver phát hiện mâu thuẫn gần nhất

local isScanning = false -- shared analysis engine, not the ESP switch
local isEspOn = false
local isAutoFlagging = false
local isAutoOpening = false
local isAntiLagOn = false

local solverGeneration = 0
local autoFlagGeneration = 0
local autoOpenGeneration = 0

local cachedParts = {}
local cachedSet = {}
local neighborMap = {}
local numberTiles = {}
local knownMines = {}
local knownSafe = {}
local probabilityMap = {}
local currentBestGuess = nil
local connections = {}
local trackedVisuals = {}
local checkedNoNumber = {}     -- [part] = {n = lần thử, t = thời điểm thử gần nhất}
local flagGrid = {}
local lastUnknown = {}
local lastSig = nil
local lastSolveTime = 0
local lastSoftReset = 0
local conflicts = 0

local actionCooldown = setmetatable({}, { __mode = "k" })

local addedQueue = {}
local removedSinceFlush = 0
local flushScheduled = false

-- Thanh "Here": hẹp + dài, hiện trên ô chưa mở gần nhất, ô an toàn gần nhất và ô đoán (vàng)
local HERE = {
    marks = {},        -- [kind] = { part, bb, label, target }   kind: "unrev" | "safe" | "guess"
    conn = nil,
    height = 12,       -- chiều dài (dọc) của thanh, studs (trước đây 8)
    widthFactor = 0.2, -- bề ngang = cạnh ô * hệ số này (trước đây 0.35 -> hẹp hơn)
    minWidth = 0.3,
    thickness = 0.06,
    lastScan = 0,
    nearestUnrev = nil,
}

local fiftyFiftyAlertActive = false
local activeAlertLabel = nil
local activeAlertTween = nil
local alertToken = 0

local visualsFolder = Instance.new("Folder")
visualsFolder.Name = "TopEspVisuals_" .. tostring(screenGui.Name)
if VISUALS_IN_WORKSPACE then
    pcall(function() visualsFolder.Parent = Workspace end)
end
if not visualsFolder.Parent then
    visualsFolder.Parent = guiParent
end

-------------------------------------------------------------------------------
-- 50/50 NOTIFICATION
-------------------------------------------------------------------------------

local function clearFiftyFiftyAlert()
    alertToken = alertToken + 1
    fiftyFiftyAlertActive = false
    if activeAlertTween then
        pcall(function() activeAlertTween:Cancel() end)
        activeAlertTween = nil
    end
    if activeAlertLabel then
        pcall(function() activeAlertLabel:Destroy() end)
        activeAlertLabel = nil
    end
end

local function triggerFiftyFiftyAlert()
    if fiftyFiftyAlertActive then return end
    fiftyFiftyAlertActive = true
    alertToken = alertToken + 1
    local currentToken = alertToken

    local lbl = Instance.new("TextLabel")
    lbl.Name = "FiftyFiftyAlert"
    lbl.AnchorPoint = Vector2.new(0.5, 0.5)
    lbl.Position = UDim2.new(0.5, 0, 0.75, 0)
    lbl.Size = UDim2.new(0, 420, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Text = "Open other boxes to reduce the chances of having to guess."
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextSize = 14
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextWrapped = false
    lbl.TextScaled = false
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.Parent = screenGui
    activeAlertLabel = lbl

    task.delay(3, function()
        if currentToken ~= alertToken or not lbl or not lbl.Parent then return end
        local tween = TweenService:Create(lbl,
            TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Position = UDim2.new(0.5, 0, 1.08, 0), TextTransparency = 1 })
        activeAlertTween = tween
        tween.Completed:Connect(function()
            if currentToken == alertToken then
                if activeAlertLabel == lbl then activeAlertLabel = nil end
                activeAlertTween = nil
                fiftyFiftyAlertActive = false
                pcall(function() lbl:Destroy() end)
            end
        end)
        tween:Play()
    end)
end

-------------------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------------------

local function getTileRoot()
    local flagObj = Workspace:FindFirstChild("Flag")
    if not flagObj then return nil end
    return flagObj:FindFirstChild("Parts")
end

local function getCharPos()
    local char = player.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
    return root and root.Position or nil
end

local function isWithinDistance(part, charPos, maxDist)
    if not charPos or not part then return true end
    return (part.Position - charPos).Magnitude <= maxDist
end

-- Solver luôn có giới hạn phạm vi:
-- Cả chế độ thường và Endless: Anti-Lag OFF = 100 studs, ON = 60 studs.
-- Không dùng suy luận tổng mìn toàn bàn khi chỉ quét một vùng giới hạn.
local function isRangeLimited()
    return true
end

local function getRangeLimit()
    if isEndlessOn then return EL.prof().solveRange end
    return isAntiLagOn and ANTI_LAG_DISTANCE or SOLVE_RANGE
end

local function isWithinActiveRange(part, charPos, extraPadding)
    if not isRangeLimited() then return true end
    if not charPos or not part then return true end
    return (part.Position - charPos).Magnitude <= getRangeLimit() + (extraPadding or 0)
end

local function sortByProximity(list, charPos)
    if not charPos or #list <= 1 then return end
    table.sort(list, function(a, b)
        return (a.Position - charPos).Magnitude < (b.Position - charPos).Magnitude
    end)
end

local function countKnownMines()
    local count = 0
    for part, isMine in pairs(knownMines) do
        if isMine and part and part.Parent then
            count = count + 1
        end
    end
    return count
end

local function countKnownSafeUnrevealed()
    local count = 0
    for part, isSafe in pairs(knownSafe) do
        if isSafe and part and part.Parent then
            count = count + 1
        end
    end
    return count
end

local function isColorMatch(c1, r, g, b)
    return math.abs(c1.R - r) < 0.05 and math.abs(c1.G - g) < 0.05 and math.abs(c1.B - b) < 0.05
end

-- Ô rác: RGB(255,255,125)
local function isExcluded(part)
    if not part:IsA("BasePart") then return true end
    return isColorMatch(part.Color, 1.000, 1.000, 0.490)
end

-- Ô số: RGB(230,230,113)
local function isNumberColor(part)
    if not part or not part:IsA("BasePart") then return false end
    return isColorMatch(part.Color, 0.902, 0.902, 0.443)
end

-- Ô chưa mở: chỉ dựa trên màu (không phụ thuộc cache số) để phát hiện ván reset
-- Hai màu ô chưa mở mặc định: RGB(205,142,100) & RGB(180,125,88)
local function isDefaultUnrevealedColor(c)
    return isColorMatch(c, 0.804, 0.557, 0.392) or isColorMatch(c, 0.706, 0.490, 0.345)
end

local function isUnrevealed(part)
    if not part or not part.Parent or not part:IsA("BasePart") then return false end
    local c = part.Color
    if isColorMatch(c, 1.000, 1.000, 0.490) then return false end
    if isDefaultUnrevealedColor(c) then return true end
    if customUnrevealed then
        for _, u in ipairs(customUnrevealed) do
            if isColorMatch(c, u.R, u.G, u.B) then return true end
        end
    end
    return false
end

-- FIX: bản gốc có thể lặp vô hạn ở đây (FindFirstChildWhichIsA không nhận tham số thứ 3)
local function getNumber(part)
    if not part or not part:IsA("BasePart") or isExcluded(part) then return nil end

    -- Cấu trúc ô số: part.NumberGui.TextLabel (đọc thuộc tính Text)
    local ng = part:FindFirstChild("NumberGui")
    local direct = ng and ng:FindFirstChild("TextLabel")
    if direct and direct:IsA("TextLabel") then
        local num = tonumber(string.match(direct.Text, "%d+"))
        if num and num >= 1 and num <= 8 then return num end
        return nil
    end

    for _, d in ipairs(part:GetDescendants()) do
        if d:IsA("TextLabel") and d.Visible then
            local num = tonumber(string.match(d.Text, "%d+"))
            if num and num >= 1 and num <= 8 then return num end
        end
    end
    return nil
end

local function isTileCandidate(part)
    if not part or not part:IsA("BasePart") then return false end
    if isExcluded(part) then return false end
    if isNumberColor(part) or isUnrevealed(part) then return true end
    if part.Name == "Part" and part.Parent and string.find(string.lower(part.Parent.Name), "part") then
        return true
    end
    if part:FindFirstChildWhichIsA("TextLabel", true) then
        return getNumber(part) ~= nil
    end
    return false
end

local function countUnrevealedNeighbors(part)
    local neighbors = neighborMap[part]
    if not neighbors then return 0 end
    local c = 0
    for _, n in ipairs(neighbors) do
        if isUnrevealed(n) and not knownMines[n] and not knownSafe[n] then c = c + 1 end
    end
    return c
end

local function countRevealedNumberNeighbors(part)
    local neighbors = neighborMap[part]
    if not neighbors then return 0 end
    local c = 0
    for _, n in ipairs(neighbors) do
        if n.Parent and numberTiles[n] then c = c + 1 end
    end
    return c
end

local function onCooldown(part, secs)
    local t = actionCooldown[part]
    return t ~= nil and (os.clock() - t) < secs
end

local function stamp(part)
    actionCooldown[part] = os.clock()
end

-------------------------------------------------------------------------------
-- FLAG CACHE (lưới băm không gian -> hasFlag O(1))
-------------------------------------------------------------------------------

local function addFlagPos(pos)
    local k = math.floor(pos.X / FLAG_CELL) .. ":" .. math.floor(pos.Z / FLAG_CELL)
    local b = flagGrid[k]
    if not b then b = {}; flagGrid[k] = b end
    b[#b + 1] = pos
end

local function refreshFlagCache()
    flagGrid = {}

    local flagFolder = Workspace:FindFirstChild("Flag") or Workspace:FindFirstChild("Flags")
    if flagFolder then
        local charPos = isEndlessOn and getCharPos() or nil
        if charPos then
            -- Endless: chỉ lấy cờ trong cửa sổ quanh người chơi (không duyệt cả bàn vô tận)
            local params = OverlapParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            params.FilterDescendantsInstances = { flagFolder }
            local radius = SET.actRange + 30
            for _, desc in ipairs(Workspace:GetPartBoundsInRadius(charPos, radius, params)) do
                -- Loại trừ các ô (tile). Ở Endless, cachedSet chứa MỌI part trong cửa sổ (kể cả part cờ)
                -- nên phải dùng EL.cand (chỉ các ô) - nếu không cờ bị bỏ sót và Auto Flag bấm lặp lại mãi.
                if not EL.cand[desc] and not isExcluded(desc) then addFlagPos(desc.Position) end
            end

            -- Dự phòng: part cờ có CanQuery = false thì truy vấn không gian bỏ sót -> quét các nhánh khác của thư mục Flag
            local tileRootNow = getTileRoot()
            for _, child in ipairs(flagFolder:GetChildren()) do
                if child ~= tileRootNow then
                    if child:IsA("BasePart") then
                        if (child.Position - charPos).Magnitude <= radius then addFlagPos(child.Position) end
                    else
                        for _, d in ipairs(child:GetDescendants()) do
                            if d:IsA("BasePart") and (d.Position - charPos).Magnitude <= radius then
                                addFlagPos(d.Position)
                            end
                        end
                    end
                end
            end
        else
            for _, desc in ipairs(flagFolder:GetDescendants()) do
                if desc:IsA("BasePart") and not cachedSet[desc] then
                    addFlagPos(desc.Position)
                end
            end
        end
    end

    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and string.find(string.lower(obj.Name), "flag") then
            local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if primary then addFlagPos(primary.Position) end
        end
    end
end

local function hasFlag(part)
    if not part or not part.Parent then return false end
    local pPos = part.Position
    local sx = part.Size.X * 0.55
    local sz = part.Size.Z * 0.55
    local cx = math.floor(pPos.X / FLAG_CELL)
    local cz = math.floor(pPos.Z / FLAG_CELL)
    for ix = cx - 1, cx + 1 do
        for iz = cz - 1, cz + 1 do
            local b = flagGrid[ix .. ":" .. iz]
            if b then
                for _, f in ipairs(b) do
                    local dy = f.Y - pPos.Y
                    if math.abs(f.X - pPos.X) < sx and math.abs(f.Z - pPos.Z) < sz and dy > 0.3 and dy < 6 then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function clickTile(part)
    if not part or not part.Parent then return end
    local cd = part:FindFirstChildOfClass("ClickDetector") or part:FindFirstChildWhichIsA("ClickDetector", true)
    if cd and typeof(fireclickdetector) == "function" then
        fireclickdetector(cd, 0)
    end
end

-------------------------------------------------------------------------------
-- TOUCH TRIGGER
-------------------------------------------------------------------------------

local function triggerTileTouch(targetTile)
    if not targetTile or not targetTile.Parent then return end
    local char = player.Character
    if not char then return end

    local limb = char:FindFirstChild("RightFoot")
        or char:FindFirstChild("Right Leg")
        or char:FindFirstChild("LeftFoot")
        or char:FindFirstChild("Left Leg")
        or char:FindFirstChild("HumanoidRootPart")
    if not limb then return end

    if typeof(firetouchinterest) == "function" then
        firetouchinterest(limb, targetTile, 0)
        task.wait(0.015)
        firetouchinterest(limb, targetTile, 1)
    else
        local probe = Instance.new("Part")
        probe.Name = "LegProbe"
        probe.Size = limb.Size
        probe.CanCollide = false
        probe.CanQuery = false
        probe.CanTouch = true
        probe.Massless = true
        probe.Transparency = 1
        probe.CFrame = targetTile.CFrame
        probe.Parent = char
        task.wait(0.02)
        pcall(function() probe:Destroy() end)
    end
end

-------------------------------------------------------------------------------
-- "HERE": thanh dựng đứng + nhãn trên ô chưa mở gần nhất, ô an toàn gần nhất, ô đoán;
-- tất cả chỉ hiện khi số mìn script đã biết >= SET.hereThreshold.
-- Không bị giới hạn bởi Anti-Lag: không lọc theo phạm vi giải / phạm vi ESP.
-------------------------------------------------------------------------------

local function hereStop()
    if HERE.conn then
        HERE.conn:Disconnect()
        HERE.conn = nil
    end
end

local function hereRemove(kind)
    local m = HERE.marks[kind]
    if m then
        pcall(function() m.bb:Destroy() end)
        pcall(function() m.part:Destroy() end)
        HERE.marks[kind] = nil
    end
end

local function clearHerePillar()
    hereStop()
    for kind in pairs(HERE.marks) do
        hereRemove(kind)
    end
    HERE.nearestUnrev = nil
end

-- Cập nhật vị trí + hướng của mọi thanh (thanh luôn đứng thẳng, mặt phẳng hướng về camera)
local function hereFace()
    local cam = Workspace.CurrentCamera
    for _, m in pairs(HERE.marks) do
        local t = m.target
        if m.part.Parent and t and t.Parent then
            local topY = t.Position.Y + (t.Size.Y * 0.5)
            local center = Vector3.new(t.Position.X, topY + (HERE.height * 0.5), t.Position.Z)
            local look = cam and Vector3.new(cam.CFrame.Position.X, center.Y, cam.CFrame.Position.Z)
            if look and (look - center).Magnitude > 0.01 then
                m.part.CFrame = CFrame.lookAt(center, look)
            else
                m.part.CFrame = CFrame.new(center)
            end
        end
    end
end

local function hereStart()
    if HERE.conn then return end
    HERE.conn = RunService.RenderStepped:Connect(function()
        if not isScanning or not SET.markLeftover or next(HERE.marks) == nil then
            hereStop()
            return
        end
        hereFace()
    end)
end

-- Tạo / cập nhật thanh Here của một loại ô (target = nil thì gỡ)
local function hereSet(kind, target, color)
    if not target then
        hereRemove(kind)
        return
    end

    local width = math.max(HERE.minWidth, math.min(target.Size.X, target.Size.Z) * HERE.widthFactor)
    local size = Vector3.new(width, HERE.height, HERE.thickness)

    local m = HERE.marks[kind]
    if not m or not m.part.Parent then
        local p = Instance.new("Part")
        p.Name = "HereFlatRay_" .. kind
        p.Anchored = true
        p.CanCollide = false
        p.CanTouch = false
        p.CanQuery = false
        p.CastShadow = false
        p.Massless = true
        p.Material = Enum.Material.Neon
        p.Transparency = 0.25
        p.Size = size
        p.Parent = visualsFolder

        local bb = Instance.new("BillboardGui")
        bb.Name = "HereBillboard"
        bb.Adornee = p
        bb.AlwaysOnTop = true
        bb.Size = UDim2.new(0, 76, 0, 26)
        bb.Parent = guiParent

        local lbl = Instance.new("TextLabel")
        lbl.Name = "HereLabel"
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = "Here"
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.TextStrokeTransparency = 0.35
        lbl.TextScaled = true
        lbl.Font = Enum.Font.GothamBold
        lbl.Parent = bb

        m = { part = p, bb = bb, label = lbl }
        HERE.marks[kind] = m
    end

    m.target = target
    m.part.Size = size
    m.part.Color = color
    m.label.TextColor3 = color
    m.bb.StudsOffset = Vector3.new(0, (HERE.height * 0.5) + 1.2, 0)
end

-- Ô chưa mở gần nhất trên TOÀN bàn (không giới hạn phạm vi), quét thưa mỗi 0.6s
local function hereScanUnrevealed(charPos)
    local best, bestD = nil, math.huge
    for _, part in ipairs(cachedParts) do
        if part.Parent and isUnrevealed(part)
            and not knownMines[part] and not knownSafe[part] then
            local d = charPos and (part.Position - charPos).Magnitude or 0
            if d < bestD and not hasFlag(part) then
                best, bestD = part, d
            end
        end
    end
    return best
end

local function updateHerePillar(charPos, foundMinesCount)
    -- Thanh Here (trắng / xanh / vàng) chỉ hiện khi số mìn script đã biết >= SET.hereThreshold (90)
    if not isScanning or not SET.markLeftover or foundMinesCount < SET.hereThreshold then
        clearHerePillar()
        return
    end

    -- 1) Ô an toàn gần nhất (xanh) - không lọc theo phạm vi
    local safeT, safeD = nil, math.huge
    for part, ok in pairs(knownSafe) do
        if ok and part.Parent and isUnrevealed(part) then
            local d = charPos and (part.Position - charPos).Magnitude or 0
            if d < safeD then safeT, safeD = part, d end
        end
    end
    hereSet("safe", safeT, Color3.fromRGB(0, 255, 0))

    -- 2) Ô đoán (vàng)
    local g = currentBestGuess
    if g and g.Parent and isUnrevealed(g) and not knownMines[g] and not knownSafe[g] then
        hereSet("guess", g, Color3.fromRGB(255, 255, 0))
    else
        hereRemove("guess")
    end

    -- 3) Ô chưa mở gần nhất (trắng): chỉ ở chế độ thường (Endless không có tổng số mìn cố định)
    if isEndlessOn then
        HERE.nearestUnrev = nil
        hereRemove("unrev")
    else
        local cur = HERE.nearestUnrev
        local now = os.clock()
        if cur and not (cur.Parent and isUnrevealed(cur) and not knownMines[cur] and not knownSafe[cur]) then
            cur = nil
        end
        if not cur or now - HERE.lastScan >= 0.6 then
            HERE.lastScan = now
            cur = hereScanUnrevealed(charPos)
        end
        HERE.nearestUnrev = cur
        hereSet("unrev", cur, Color3.fromRGB(255, 255, 255))
    end

    if next(HERE.marks) ~= nil then
        hereFace()
        hereStart()
    else
        hereStop()
    end
end

-------------------------------------------------------------------------------
-- TOP-FACE VISUALS (ESP)
-------------------------------------------------------------------------------

local function clearVisuals(part)
    if not part then return end
    local entry = trackedVisuals[part]
    if entry then
        if entry.box then pcall(function() entry.box:Destroy() end) end
        if entry.topFill then pcall(function() entry.topFill:Destroy() end) end
        trackedVisuals[part] = nil
    end
end

local function clearAllVisuals()
    for part, entry in pairs(trackedVisuals) do
        if entry then
            if entry.box then pcall(function() entry.box:Destroy() end) end
            if entry.topFill then pcall(function() entry.topFill:Destroy() end) end
        end
        trackedVisuals[part] = nil
    end
end

local function withinVisualRange(part, charPos)
    if not charPos or not part then return true end

    -- ESP: Anti-Lag OFF = 100 studs, ON = 60 studs (cả chế độ thường và Endless).
    local limit
    if isEndlessOn then
        limit = EL.prof().visualRange
    else
        limit = isAntiLagOn and ANTI_LAG_DISTANCE or SOLVE_RANGE
    end
    return (part.Position - charPos).Magnitude <= limit
end

local function createHighlight(part, color, name)
    if not isEspOn then return end
    if not part or not part:IsA("BasePart") or not part.Parent then return end

    -- đã có đúng ESP này rồi -> thoát sớm (tránh gọi getCharPos hàng trăm lần mỗi vòng)
    local ex = trackedVisuals[part]
    if ex and ex.tag == name and ex.topFill and ex.topFill.Parent then return end

    local charPos = getCharPos()
    if not withinVisualRange(part, charPos) then
        clearVisuals(part)
        return
    end

    local existing = trackedVisuals[part]
    if name == "Guess_Highlight" and existing
        and (existing.tag == "Safe_Highlight" or existing.tag == "Mine_Highlight") then
        return
    end
    if existing and existing.tag == name and existing.topFill and existing.topFill.Parent then
        return
    end

    clearVisuals(part)

    local capThickness = 0.06
    local topFill = Instance.new("Part")
    topFill.Name = name .. "_TopCap"
    topFill.Anchored = true
    topFill.CanCollide = false
    topFill.CanTouch = false
    topFill.CanQuery = false
    topFill.CastShadow = false
    topFill.Massless = true
    topFill.Material = Enum.Material.SmoothPlastic
    topFill.Color = color
    topFill.Transparency = 0.45
    topFill.Size = Vector3.new(
        math.max(0.1, part.Size.X * 0.96),
        capThickness,
        math.max(0.1, part.Size.Z * 0.96)
    )
    topFill.CFrame = part.CFrame * CFrame.new(0, (part.Size.Y * 0.5) + (capThickness * 0.5) + 0.02, 0)
    topFill.Parent = visualsFolder

    local box = Instance.new("SelectionBox")
    box.Name = name .. "_Border"
    box.Adornee = topFill
    box.Color3 = color
    box.LineThickness = 0.04
    box.Transparency = 0.05
    box.SurfaceTransparency = 1
    box.Parent = visualsFolder

    trackedVisuals[part] = { tag = name, box = box, topFill = topFill }
end

local function syncVisualsRange(charPos)
    -- gỡ ESP không còn hợp lệ
    for part, entry in pairs(trackedVisuals) do
        local drop = false
        if not part.Parent or isExcluded(part) or numberTiles[part] or not isUnrevealed(part) then
            drop = true
        elseif not withinVisualRange(part, charPos) then
            drop = true
        else
            local tag = entry.tag
            if tag == "Mine_Highlight" and not knownMines[part] then
                drop = true
            elseif tag == "Safe_Highlight" and not knownSafe[part] then
                drop = true
            elseif tag == "Guess_Highlight" and part ~= currentBestGuess then
                drop = true
            end
        end
        if drop then clearVisuals(part) end
    end

    local list = {}
    for part, isMine in pairs(knownMines) do
        if isMine and part.Parent and isUnrevealed(part) and withinVisualRange(part, charPos) then
            list[#list + 1] = { part = part, tag = "Mine_Highlight",
                d = charPos and (part.Position - charPos).Magnitude or 0 }
        end
    end
    for part, isSafe in pairs(knownSafe) do
        if isSafe and part.Parent and isUnrevealed(part) and withinVisualRange(part, charPos) then
            list[#list + 1] = { part = part, tag = "Safe_Highlight",
                d = charPos and (part.Position - charPos).Magnitude or 0 }
        end
    end

    -- Endless: chỉ vẽ ESP cho các ô gần nhất (giới hạn theo profile) để không lag
    local cap = isEndlessOn and EL.prof().visualCap or nil
    local shown = #list
    if cap and shown > cap then
        table.sort(list, function(a, b) return a.d < b.d end)
        for i = cap + 1, shown do
            clearVisuals(list[i].part)
        end
        shown = cap
    end
    for i = 1, shown do
        local e = list[i]
        if e.tag == "Mine_Highlight" then
            createHighlight(e.part, Color3.new(1, 0, 0), e.tag)
        else
            createHighlight(e.part, Color3.new(0, 1, 0), e.tag)
        end
    end

    if currentBestGuess and currentBestGuess.Parent and isUnrevealed(currentBestGuess)
        and not knownMines[currentBestGuess] and not knownSafe[currentBestGuess]
        and withinVisualRange(currentBestGuess, charPos) then
        createHighlight(currentBestGuess, Color3.fromRGB(255, 255, 0), "Guess_Highlight")
    end
end

-------------------------------------------------------------------------------
-- NEIGHBOR CACHING
-------------------------------------------------------------------------------

local function buildNeighborMapBulk(parts)
    local maxDim = 1
    for _, p in ipairs(parts) do
        local d = math.max(p.Size.X, p.Size.Z)
        if d > maxDim then maxDim = d end
    end
    local cellSize = math.max(4, maxDim * 2)

    local buckets = {}
    for _, p in ipairs(parts) do
        local key = math.floor(p.Position.X / cellSize) .. ":" .. math.floor(p.Position.Z / cellSize)
        local b = buckets[key]
        if not b then b = {}; buckets[key] = b end
        b[#b + 1] = p
    end

    for _, center in ipairs(parts) do
        local cx = math.floor(center.Position.X / cellSize)
        local cz = math.floor(center.Position.Z / cellSize)
        local radius = center.Size.X * 1.85
        local neighbors = {}
        for ix = cx - 1, cx + 1 do
            for iz = cz - 1, cz + 1 do
                local b = buckets[ix .. ":" .. iz]
                if b then
                    for _, p in ipairs(b) do
                        if p ~= center
                            and math.abs(p.Position.Y - center.Position.Y) < 1.5
                            and (p.Position - center.Position).Magnitude < radius then
                            neighbors[#neighbors + 1] = p
                        end
                    end
                end
            end
        end
        neighborMap[center] = neighbors
    end
end

local function cacheNeighbors(centerPart, forceRefresh)
    if not forceRefresh and neighborMap[centerPart] then return end

    local neighbors = {}
    local partsInBox = Workspace:GetPartBoundsInBox(centerPart.CFrame, centerPart.Size * 2.5)
    for _, p in ipairs(partsInBox) do
        if p ~= centerPart and isTileCandidate(p) then
            if math.abs(p.Position.Y - centerPart.Position.Y) < 1.5
                and (p.Position - centerPart.Position).Magnitude < (centerPart.Size.X * 1.85) then
                neighbors[#neighbors + 1] = p
            end
        end
    end
    neighborMap[centerPart] = neighbors
end

local function rescanBoard()
    customUnrevealed = nil
    cachedParts = {}
    cachedSet = {}
    neighborMap = {}
    local tileRoot = getTileRoot()
    if not tileRoot then return end

    local candidates = {}
    for _, obj in ipairs(tileRoot:GetDescendants()) do
        if isTileCandidate(obj) then
            candidates[#candidates + 1] = obj
            cachedSet[obj] = true
        end
    end
    cachedParts = candidates
    buildNeighborMapBulk(candidates)
end

-- ENDLESS: lấy các part trong ENDLESS_RANGE (+đệm) quanh người chơi làm "cửa sổ" giải
-- Học màu "ô chưa mở" cho Endless:
--  * Ô số RGB(230,230,113) / ô rác RGB(255,255,125) / ô đọc được NumberGui số: loại khỏi thống kê
--  * Thấy ô chưa mở màu mặc định -> không cần học
--  * KHÔNG thấy ô mặc định nào mà có các màu khác -> lấy tối đa 2 màu xuất hiện nhiều nhất làm ô chưa mở
--  * Màu đã học được GIỮ và dùng song song với màu mặc định (không bật/tắt theo từng vùng)
local function calibrateUnrevealedColors(found)
    local defaultCount = 0
    local groups = {}

    for _, p in ipairs(found) do
        if p:IsA("BasePart") and not isExcluded(p) and not isNumberColor(p) and not getNumber(p) then
            local c = p.Color
            if isDefaultUnrevealedColor(c) then
                defaultCount = defaultCount + 1
            else
                local key = string.format("%d,%d,%d",
                    math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
                local g = groups[key]
                if not g then g = { color = c, n = 0 }; groups[key] = g end
                g.n = g.n + 1
            end
        end
    end

    if defaultCount > 0 then return end

    if customUnrevealed then
        for _, p in ipairs(found) do
            if p:IsA("BasePart") and isUnrevealed(p) then return end -- bảng màu đã học vẫn còn khớp
        end
    end

    local list = {}
    for _, g in pairs(groups) do list[#list + 1] = g end
    table.sort(list, function(a, b) return a.n > b.n end)
    if #list == 0 or list[1].n < 4 then return end -- quá ít dữ liệu để kết luận

    customUnrevealed = { list[1].color }
    if list[2] and list[2].n >= 4 then customUnrevealed[2] = list[2].color end
    EL.done = setmetatable({}, { __mode = "k" })
    clearAllVisuals()
    lastSig = nil
end

-- Reset toàn bộ cửa sổ Endless (dựng lại từ đầu ở vòng solver kế tiếp)
function EL.reset(clearBoard)
    EL.epoch = EL.epoch + 1
    EL.grid, EL.cand, EL.ring, EL.pkey = {}, {}, {}, {}
    EL.ringValid = false
    EL.built = false
    EL.cursor = 1
    EL.dirty = false
    EL.accU, EL.accN = 0, 0
    EL.stats.unrev, EL.stats.num = 0, 0
    EL.done = setmetatable({}, { __mode = "k" })
    endlessLastCenter = nil
    lastSig = nil
    if clearBoard then
        cachedParts, cachedSet, neighborMap = {}, {}, {}
    end
end

-- Tính lại danh sách ô lân cận + số ô thực tế quanh một ô (dùng lưới băm của cửa sổ).
-- Ô số ở rìa "thế giới đã sinh ra" / rìa vùng stream có < 8 ô quanh nó: số mìn của nó còn tính cả
-- các ô CHƯA TỒN TẠI nên không được dùng làm ràng buộc (dùng sẽ suy luận sai -> nổ).
function EL.recompute(c, grid, cand, ring, nmap, cell)
    local pos = c.Position
    local size = c.Size.X
    local radius = size * 1.85
    local cx = math.floor(pos.X / cell)
    local cz = math.floor(pos.Z / cell)
    local list, cnt = {}, 0
    for ix = cx - 1, cx + 1 do
        for iz = cz - 1, cz + 1 do
            local b = grid[ix * 131071 + iz]
            if b then
                for q in pairs(b) do
                    if q ~= c then
                        local qp = q.Position
                        if math.abs(qp.Y - pos.Y) < 1.5 and (qp - pos).Magnitude < radius then
                            if q.Size.X > size * 0.75 then cnt = cnt + 1 end
                            if cand[q] then list[#list + 1] = q end
                        end
                    end
                end
            end
        end
    end
    nmap[c] = list
    ring[c] = cnt
end

-- Quét cửa sổ part quanh người chơi. Lần đầu dựng đầy đủ; các lần sau chỉ xử lý part MỚI vào / part RỜI đi
-- (rẻ hơn nhiều so với dựng lại toàn bộ mỗi lần).
function EL.refresh(charPos)
    local tileRoot = getTileRoot()
    if not tileRoot or not charPos then return end

    local myEpoch = EL.epoch
    local prof = EL.prof()
    local trust = prof.solveRange + SOLVER_CONTEXT_PADDING + ENDLESS_REFRESH_DIST + 4
    local margin = math.max(16, endlessTileDim * 3)

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { tileRoot }
    local found = Workspace:GetPartBoundsInRadius(charPos, trust + margin, params)

    if not EL.built then
        for _, q in ipairs(found) do
            endlessTileDim = math.clamp(math.max(q.Size.X, q.Size.Z), 2, 16)
            break
        end
        EL.cell = math.max(4, endlessTileDim * 2)
    end

    local now = os.clock()
    if not EL.built or now - EL.lastCalib > 8 then
        EL.lastCalib = now
        calibrateUnrevealedColors(found)
    end

    local grid, cand, ring, pkey, cell = EL.grid, EL.cand, EL.ring, EL.pkey, EL.cell
    local nmap = neighborMap
    local wasBuilt = EL.built

    local nowSet, fresh, departed = {}, {}, {}
    for _, q in ipairs(found) do
        nowSet[q] = true
        if not cachedSet[q] then fresh[#fresh + 1] = q end
    end
    for q in pairs(cachedSet) do
        if not nowSet[q] then departed[#departed + 1] = q end
    end

    local dirty = {}
    local function markNear(f)
        local pos = f.Position
        local radius = f.Size.X * 1.85
        local cx, cz = math.floor(pos.X / cell), math.floor(pos.Z / cell)
        for ix = cx - 1, cx + 1 do
            for iz = cz - 1, cz + 1 do
                local b = grid[ix * 131071 + iz]
                if b then
                    for q in pairs(b) do
                        if q ~= f and cand[q] then
                            local qp = q.Position
                            if math.abs(qp.Y - pos.Y) < 1.5 and (qp - pos).Magnitude < radius then
                                dirty[q] = true
                            end
                        end
                    end
                end
            end
        end
    end

    -- 1) part rời cửa sổ: đánh dấu hàng xóm cần tính lại rồi gỡ khỏi lưới + xoá tri thức
    for _, q in ipairs(departed) do markNear(q) end
    for _, q in ipairs(departed) do
        local k = pkey[q]
        if k then
            local b = grid[k]
            if b then b[q] = nil end
            pkey[q] = nil
        end
        cand[q], ring[q], nmap[q] = nil, nil, nil
        dirty[q] = nil
        clearVisuals(q)
        numberTiles[q] = nil
        knownMines[q] = nil
        knownSafe[q] = nil
        checkedNoNumber[q] = nil
    end

    -- 2) part mới vào: thêm vào lưới (chia lát + nhường frame khi cửa sổ lớn)
    for i, q in ipairs(fresh) do
        local pos = q.Position
        local k = math.floor(pos.X / cell) * 131071 + math.floor(pos.Z / cell)
        local b = grid[k]
        if not b then b = {}; grid[k] = b end
        b[q] = true
        pkey[q] = k
        if isTileCandidate(q) then cand[q] = true end

        if i % 400 == 0 then
            task.wait()
            if EL.epoch ~= myEpoch or not isScanning or not isEndlessOn then return end
        end
    end

    if wasBuilt then
        for _, q in ipairs(fresh) do markNear(q) end
    end
    for _, q in ipairs(fresh) do
        if cand[q] then dirty[q] = true end
    end

    -- 3) tính lại lân cận + vòng ô cho các ô bị ảnh hưởng
    local n = 0
    for q in pairs(dirty) do
        if nowSet[q] and cand[q] then
            EL.recompute(q, grid, cand, ring, nmap, cell)
        end
        n = n + 1
        if n % 300 == 0 then
            task.wait()
            if EL.epoch ~= myEpoch or not isScanning or not isEndlessOn then return end
        end
    end

    -- 4) danh sách quét: chỉ các ô nằm trong bán kính tin cậy
    local newList = {}
    for q in pairs(nowSet) do
        if cand[q] and (q.Position - charPos).Magnitude <= trust then
            newList[#newList + 1] = q
        end
    end

    cachedParts = newList
    cachedSet = nowSet
    EL.built = true
    EL.dirty = false

    local valid = false
    for _, v in pairs(ring) do
        if v >= ENDLESS_FULL_RING then valid = true; break end
    end
    EL.ringValid = valid

    endlessLastCenter = charPos
    endlessLastRefresh = os.clock()
    if #fresh > 0 or #departed > 0 then EL.version = EL.version + 1 end
end

-------------------------------------------------------------------------------
-- RESET HELPERS
-------------------------------------------------------------------------------

-- Reset "mềm": chỉ xoá suy luận (giữ số đã đọc)
local function softResetKnowledge()
    clearAllVisuals()
    clearFiftyFiftyAlert()
    clearHerePillar()
    knownMines = {}
    knownSafe = {}
    probabilityMap = {}
    currentBestGuess = nil
    lastSig = nil
    lastSoftReset = os.clock()
end

-- Reset "cứng": ván mới -> xoá cả số đã đọc
local function hardResetKnowledge()
    softResetKnowledge()
    numberTiles = {}
    checkedNoNumber = {}
    lastUnknown = {}
    endlessLastCenter = nil
    EL.done = setmetatable({}, { __mode = "k" })
    if isEndlessOn then EL.reset(true) end
end

-------------------------------------------------------------------------------
-- SOLVER
-------------------------------------------------------------------------------

local function markMine(p)
    if not p or not p.Parent or knownMines[p] then return false end
    if knownSafe[p] then
        conflicts = conflicts + 1 -- suy luận mâu thuẫn -> dữ liệu có thể cũ
        return false
    end
    knownMines[p] = true
    markTime[p] = os.clock()
    createHighlight(p, Color3.new(1, 0, 0), "Mine_Highlight")
    return true
end

local function markSafe(p)
    if not p or not p.Parent or knownSafe[p] then return false end
    if knownMines[p] then
        conflicts = conflicts + 1
        return false
    end
    knownSafe[p] = true
    markTime[p] = os.clock()
    createHighlight(p, Color3.new(0, 1, 0), "Safe_Highlight")
    return true
end

-- Endless: chỉ cho auto touch hành động trên ô đã tồn tại đủ CONFIRM_DELAY
local function isMarkConfirmed(part)
    -- solver vừa phát hiện dữ liệu mâu thuẫn -> không tin kết quả, tạm dừng hành động 2s
    if os.clock() - lastConflictTime < 2 then return false end
    if not isEndlessOn then return true end
    local t = markTime[part]
    return t ~= nil and (os.clock() - t) >= CONFIRM_DELAY
end

-- Thu thập ràng buộc: mỗi ô số -> {cells = ô chưa rõ, need = số mìn còn thiếu}
local function collectConstraints(charPos)
    local cons = {}
    for centerPart, targetNum in pairs(numberTiles) do
        if not centerPart.Parent then
            numberTiles[centerPart] = nil
        elseif EL.done[centerPart] then
            -- mọi ô xung quanh đã mở: ô số này không còn ràng buộc nào
        elseif isWithinActiveRange(centerPart, charPos, SOLVER_CONTEXT_PADDING)
            and (not isEndlessOn or not EL.ringValid
                or (EL.ring[centerPart] or 0) >= ENDLESS_FULL_RING)
            and (not isEndlessOn or not endlessLastCenter
                or (centerPart.Position - endlessLastCenter).Magnitude
                    <= getRangeLimit() + SOLVER_CONTEXT_PADDING + ENDLESS_REFRESH_DIST + 4) then
            local neighbors = neighborMap[centerPart]
            if neighbors then
                local cells, need = {}, targetNum
                local hasMarked = false
                for _, n in ipairs(neighbors) do
                    if knownMines[n] then
                        need = need - 1
                        hasMarked = true
                    elseif knownSafe[n] then
                        hasMarked = true -- an toàn: bỏ khỏi tập
                    elseif isUnrevealed(n) then
                        cells[#cells + 1] = n
                    end
                end
                if #cells > 0 then
                    cons[#cons + 1] = { part = centerPart, cells = cells, need = need }
                elseif not hasMarked then
                    EL.done[centerPart] = true -- ô đã mở không bao giờ đóng lại: bỏ qua ở các vòng sau
                end
            end
        end
    end
    return cons
end

-- Lan truyền: luật cơ bản (need=0 / need=số ô) + luật hiệu tập con, lặp đến khi hết tiến triển
local function propagate(cons, deadline)
    for _ = 1, (deadline and 4 or 10) do
        local progressed = false
        local index = {}

        for _, c in ipairs(cons) do
            if not c.dead then
                local need = c.need
                local cells, set = {}, {}
                for _, p in ipairs(c.cells) do
                    if knownMines[p] then
                        need = need - 1
                    elseif not knownSafe[p] then
                        cells[#cells + 1] = p
                        set[p] = true
                    end
                end
                c.cells, c.need, c.set = cells, need, set

                if #cells == 0 then
                    c.dead = true
                elseif need < 0 or need > #cells then
                    c.dead = true
                    conflicts = conflicts + 1
                elseif need == 0 then
                    for _, p in ipairs(cells) do
                        if markSafe(p) then progressed = true end
                    end
                    c.dead = true
                elseif need == #cells then
                    for _, p in ipairs(cells) do
                        if markMine(p) then progressed = true end
                    end
                    c.dead = true
                else
                    for _, p in ipairs(cells) do
                        local l = index[p]
                        if not l then l = {}; index[p] = l end
                        l[#l + 1] = c
                    end
                end
            end
        end

        -- Subset rule: A ⊂ B  =>  (B \ A) chứa đúng (needB - needA) mìn
        for _, A in ipairs(cons) do
            if not A.dead and A.set then
                local list = index[A.cells[1]]
                if list then
                    for _, B in ipairs(list) do
                        if B ~= A and not B.dead and B.set and #B.cells > #A.cells then
                            local sub = true
                            for _, p in ipairs(A.cells) do
                                if not B.set[p] then sub = false; break end
                            end
                            if sub then
                                local diff = {}
                                for _, p in ipairs(B.cells) do
                                    if not A.set[p] then diff[#diff + 1] = p end
                                end
                                local dn = B.need - A.need
                                if dn == 0 then
                                    for _, p in ipairs(diff) do
                                        if markSafe(p) then progressed = true end
                                    end
                                elseif dn == #diff then
                                    for _, p in ipairs(diff) do
                                        if markMine(p) then progressed = true end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if not progressed then break end
        if deadline and os.clock() > deadline then break end
    end
end

-- Chia ràng buộc thành các cụm liên thông (độc lập nhau)
local function buildComponents(cons)
    local cellCons = {}
    for ci, c in ipairs(cons) do
        for _, p in ipairs(c.cells) do
            local l = cellCons[p]
            if not l then l = {}; cellCons[p] = l end
            l[#l + 1] = ci
        end
    end

    local visitedCon, comps = {}, {}
    for ci = 1, #cons do
        if not visitedCon[ci] then
            visitedCon[ci] = true
            local stack = { ci }
            local conList, cellList, cellSeen = {}, {}, {}
            while #stack > 0 do
                local cur = table.remove(stack)
                conList[#conList + 1] = cons[cur]
                for _, p in ipairs(cons[cur].cells) do
                    if not cellSeen[p] then
                        cellSeen[p] = true
                        cellList[#cellList + 1] = p
                        for _, cj in ipairs(cellCons[p]) do
                            if not visitedCon[cj] then
                                visitedCon[cj] = true
                                stack[#stack + 1] = cj
                            end
                        end
                    end
                end
            end
            comps[#comps + 1] = { cons = conList, cells = cellList }
        end
    end
    return comps
end

-- Liệt kê chính xác mọi cấu hình mìn hợp lệ của một cụm (backtracking có cắt tỉa)
-- Trả về: countByK[k] = số nghiệm có k mìn; cellByK[k][i] = số nghiệm đó có mìn ở ô i
local function enumerateComponent(comp)
    local cells = comp.cells
    local n = #cells
    local cellIndex = {}
    for i, c in ipairs(cells) do cellIndex[c] = i end

    local cellCons = {}
    for i = 1, n do cellCons[i] = {} end
    local conCells, conNeed, conAssigned, conUnassigned = {}, {}, {}, {}
    for ci, c in ipairs(comp.cons) do
        local idxs = {}
        for _, p in ipairs(c.cells) do
            local ix = cellIndex[p]
            idxs[#idxs + 1] = ix
            table.insert(cellCons[ix], ci)
        end
        conCells[ci] = idxs
        conNeed[ci] = c.need
        conAssigned[ci] = 0
        conUnassigned[ci] = #idxs
    end

    -- Thứ tự BFS để các ràng buộc được "đóng" sớm -> cắt tỉa mạnh
    local order, seen, queue, qi = {}, { [1] = true }, { 1 }, 1
    while qi <= #queue do
        local u = queue[qi]
        qi = qi + 1
        order[#order + 1] = u
        for _, ci in ipairs(cellCons[u]) do
            for _, v in ipairs(conCells[ci]) do
                if not seen[v] then
                    seen[v] = true
                    queue[#queue + 1] = v
                end
            end
        end
    end
    if #order ~= n then return nil end

    local assign = {}
    for i = 1, n do assign[i] = 0 end
    local countByK, cellByK = {}, {}
    local nodes, aborted, mines = 0, false, 0
    local maxNodes = isEndlessOn and EL.prof().maxNodes or MAX_ENUM_NODES

    local function rec(pos)
        if aborted then return end
        nodes = nodes + 1
        if nodes > maxNodes then
            aborted = true
            return
        end
        if pos > n then
            countByK[mines] = (countByK[mines] or 0) + 1
            local arr = cellByK[mines]
            if not arr then
                arr = {}
                for i = 1, n do arr[i] = 0 end
                cellByK[mines] = arr
            end
            for i = 1, n do
                if assign[i] == 1 then arr[i] = arr[i] + 1 end
            end
            return
        end

        local u = order[pos]
        local cl = cellCons[u]
        for v = 0, 1 do
            local ok = true
            for _, ci in ipairs(cl) do
                local a = conAssigned[ci] + v
                local un = conUnassigned[ci] - 1
                if a > conNeed[ci] or a + un < conNeed[ci] then
                    ok = false
                    break
                end
            end
            if ok then
                assign[u] = v
                for _, ci in ipairs(cl) do
                    conAssigned[ci] = conAssigned[ci] + v
                    conUnassigned[ci] = conUnassigned[ci] - 1
                end
                mines = mines + v
                rec(pos + 1)
                mines = mines - v
                for _, ci in ipairs(cl) do
                    conAssigned[ci] = conAssigned[ci] - v
                    conUnassigned[ci] = conUnassigned[ci] + 1
                end
                assign[u] = 0
            end
        end
    end

    rec(1)
    if aborted then return nil end
    return { countByK = countByK, cellByK = cellByK, n = n }
end

local function clamp(x, lo, hi)
    if x < lo then return lo end
    if x > hi then return hi end
    return x
end

-- Phân tích biên: xác suất từng ô + ô chắc chắn mìn/an toàn.
-- R = số mìn còn lại, O = số ô chưa rõ nằm ngoài biên, useGlobal = dùng ràng buộc tổng số mìn.
local function analyzeFrontier(cons, R, O, useGlobal, priorDensity, deadline, charPos)
    local comps = buildComponents(cons)

    -- Có giới hạn thời gian: giải cụm gần người chơi trước, cụm xa để lượt sau
    if deadline and charPos then
        for _, comp in ipairs(comps) do
            local best = math.huge
            for _, cp in ipairs(comp.cells) do
                local d = (cp.Position - charPos).Magnitude
                if d < best then best = d end
            end
            comp.dist = best
        end
        table.sort(comps, function(x, y) return x.dist < y.dist end)
    end

    local res = {
        probs = {}, mines = {}, safes = {}, frontier = {},
        rho = nil, outsideSafe = false, outsideMine = false, conflict = false,
    }

    local sumMin, sumMax, totalFrontier = 0, 0, 0
    local activeComps = {}
    local maxCells = isEndlessOn and EL.prof().maxCells or MAX_COMPONENT_CELLS
    for _, comp in ipairs(comps) do
      if deadline and os.clock() > deadline then
        res.partial = true -- hết ngân sách thời gian: bỏ qua các cụm còn lại trong lượt này
      else
        activeComps[#activeComps + 1] = comp
        for _, p in ipairs(comp.cells) do res.frontier[p] = true end
        totalFrontier = totalFrontier + #comp.cells

        if #comp.cells <= maxCells then
            comp.enum = enumerateComponent(comp)
        end

        if comp.enum then
            local kmin, kmax = math.huge, -1
            for k in pairs(comp.enum.countByK) do
                if k < kmin then kmin = k end
                if k > kmax then kmax = k end
            end
            if kmax < 0 then
                res.conflict = true -- cụm vô nghiệm => số liệu không nhất quán
                comp.enum = nil
                comp.kmin, comp.kmax = 0, #comp.cells
            else
                comp.kmin, comp.kmax = kmin, kmax
            end
        else
            comp.kmin, comp.kmax = 0, #comp.cells
        end

        -- Xác suất heuristic cho cụm quá lớn
        if not comp.enum then
            comp.heur = {}
            local e = 0
            for _, c in ipairs(comp.cons) do
                local pr = c.need / #c.cells
                for _, p in ipairs(c.cells) do
                    if not comp.heur[p] or pr > comp.heur[p] then comp.heur[p] = pr end
                end
            end
            for _, p in ipairs(comp.cells) do e = e + (comp.heur[p] or 0.5) end
            comp.heurE = e
        end

        sumMin = sumMin + comp.kmin
        sumMax = sumMax + comp.kmax
      end
    end
    comps = activeComps

    local globalOk = useGlobal and not res.partial and R >= 0 and sumMin <= R and (sumMax + O) >= R
    local useDensity = globalOk and O > 0

    local function allowed(comp, k)
        if not globalOk then return true end
        return (k + (sumMin - comp.kmin) <= R) and (k + (sumMax - comp.kmax) + O >= R)
    end

    -- Mật độ mìn ngoài biên (rho) hội tụ lặp: rho = (R - E[mìn biên]) / O
    local rho = 0.5
    if useDensity then
        rho = clamp(R / (O + math.max(1, totalFrontier)), 0.001, 0.999)
    elseif not useGlobal and priorDensity then
        -- Endless không có tổng số mìn toàn bàn, nhưng vẫn cần prior density
        -- để cân trọng số các cấu hình có số mìn khác nhau trong cùng cụm.
        rho = clamp(priorDensity, 0.001, 0.999)
    end
    local priorOdds = rho / (1 - rho)
    local usePrior = not useGlobal and priorDensity ~= nil
    local r = 1
    for _ = 1, 3 do
        r = useDensity and (rho / (1 - rho)) or (usePrior and priorOdds or 1)
        local sumE = 0
        for _, comp in ipairs(comps) do
            if comp.enum then
                local wsum, ksum = 0, 0
                for k, cnt in pairs(comp.enum.countByK) do
                    if allowed(comp, k) then
                        local w = cnt * (r ^ k)
                        wsum = wsum + w
                        ksum = ksum + w * k
                    end
                end
                comp.E = wsum > 0 and (ksum / wsum) or 0
            else
                comp.E = comp.heurE
            end
            sumE = sumE + comp.E
        end
        if useDensity then
            rho = clamp((R - sumE) / O, 0.001, 0.999)
        end
    end
    r = useDensity and (rho / (1 - rho)) or 1

    -- Xác suất cuối + ô chắc chắn
    for _, comp in ipairs(comps) do
        if comp.enum then
            local n = comp.enum.n
            local cellW, mineSol = {}, {}
            for i = 1, n do cellW[i] = 0; mineSol[i] = 0 end
            local wsum, totalSol = 0, 0

            for k, cnt in pairs(comp.enum.countByK) do
                if allowed(comp, k) then
                    local rk = r ^ k
                    wsum = wsum + cnt * rk
                    totalSol = totalSol + cnt
                    local arr = comp.enum.cellByK[k]
                    for i = 1, n do
                        cellW[i] = cellW[i] + arr[i] * rk
                        mineSol[i] = mineSol[i] + arr[i]
                    end
                end
            end

            if wsum > 0 and totalSol > 0 then
                for i, p in ipairs(comp.cells) do
                    res.probs[p] = cellW[i] / wsum
                    if mineSol[i] == 0 then
                        res.safes[#res.safes + 1] = p
                    elseif mineSol[i] == totalSol then
                        res.mines[#res.mines + 1] = p
                    end
                end
            else
                res.conflict = true
                for _, p in ipairs(comp.cells) do res.probs[p] = 0.5 end
            end
        else
            for _, p in ipairs(comp.cells) do
                res.probs[p] = comp.heur[p] or 0.5
            end
        end
    end

    if globalOk and O > 0 then
        res.rho = rho
        if sumMin >= R then res.outsideSafe = true end
        if sumMax + O <= R then res.outsideMine = true end
    elseif useGlobal and not globalOk and #comps > 0 then
        res.globalInconsistent = true
    end

    return res
end

local function gatherUnknown(charPos)
    local list = {}
    for _, p in ipairs(cachedParts) do
        if p.Parent and isUnrevealed(p) and not knownMines[p] and not knownSafe[p]
            and isWithinActiveRange(p, charPos, 0) then
            list[#list + 1] = p
        end
    end
    return list
end

local function applyAnalysis(res, unknown)
    local progressed = false
    for _, p in ipairs(res.safes) do
        if markSafe(p) then progressed = true end
    end
    for _, p in ipairs(res.mines) do
        if markMine(p) then progressed = true end
    end
    if res.outsideSafe then
        for _, p in ipairs(unknown) do
            if not res.frontier[p] and markSafe(p) then progressed = true end
        end
    elseif res.outsideMine then
        for _, p in ipairs(unknown) do
            if not res.frontier[p] and markMine(p) then progressed = true end
        end
    end
    return progressed
end

-- Chọn ô đoán tốt nhất (xác suất thấp nhất, hoà thì ưu tiên ô nhiều thông tin / gần người chơi)
local function pickGuess(res, unknown, charPos, R)
    local endgame = (not isEndlessOn) and R <= 2
    local list = {}

    for p, prob in pairs(res.probs) do
        if p.Parent and isUnrevealed(p) and not knownMines[p] and not knownSafe[p]
            and isWithinActiveRange(p, charPos, 0) then
            local info = countUnrevealedNeighbors(p) * 0.6 + countRevealedNumberNeighbors(p) * 0.3
            if endgame then info = info * 2 end
            local dist = charPos and (p.Position - charPos).Magnitude or 0
            list[#list + 1] = { part = p, prob = prob, score = prob * 1000 - info + dist * 0.005 }
        end
    end

    -- Ô ngoài biên: chỉ thêm ứng viên gần người chơi nhất
    local outsideProb = res.rho
    if isEndlessOn then
        outsideProb = ENDLESS_DEFAULT_DENSITY
    elseif not outsideProb then
        outsideProb = (R > 0 and #unknown > 0) and clamp(R / #unknown, 0.001, 0.999) or 0.5
    end
    local nearest, nd = nil, math.huge
    for _, p in ipairs((not isEndlessOn or ENDLESS_GUESS_OUTSIDE) and unknown or {}) do
        if not res.frontier[p] and not hasFlag(p) then
            local d = charPos and (p.Position - charPos).Magnitude or 0
            if d < nd then nd = d; nearest = p end
        end
    end
    if nearest and (not isEndlessOn or ENDLESS_GUESS_OUTSIDE) then
        list[#list + 1] = { part = nearest, prob = outsideProb, score = outsideProb * 1000 + nd * 0.005 }
    end

    if #list == 0 then return nil, 1 end
    table.sort(list, function(a, b) return a.score < b.score end)

    local chosen
    for i = 1, math.min(#list, 6) do
        if not hasFlag(list[i].part) then chosen = list[i]; break end
    end
    chosen = chosen or list[1]

    -- Phát hiện 50/50: tốt nhất vẫn ~50% và có >= 2 ô ~50%
    local fifty = 0
    for _, e in ipairs(list) do
        if math.abs(e.prob - 0.5) < 0.03 then fifty = fifty + 1 end
    end
    if chosen.prob >= 0.45 and fifty >= 2 then
        triggerFiftyFiftyAlert()
    end

    return chosen.part, chosen.prob
end

-- Suy luận ô còn lại: khi mọi ô khác đã được xác định (mìn / an toàn),
-- các ô chưa rõ còn sót lại được quyết định hoàn toàn bởi tổng số mìn.
--   R = TOTAL - số mìn đã biết,  U = số ô chưa mở và chưa xác định
--   R == 0 -> toàn bộ U an toàn;  R == U -> toàn bộ U là mìn
-- Chỉ chạy khi Anti-Lag OFF (cần nhìn thấy cả bàn).
local function deduceLastTiles(charPos)
    if not LAST_TILE_DEDUCTION or not GLOBAL_MINES_ENABLED or isRangeLimited() then return false end

    local unknown = gatherUnknown(charPos)
    local U = #unknown
    local R = SET.totalMines - countKnownMines()
    if U == 0 or R < 0 or R > U then return false end -- dữ liệu không nhất quán -> bỏ qua

    local progressed = false
    if R == 0 then
        for _, p in ipairs(unknown) do
            if markSafe(p) then progressed = true end
        end
    elseif R == U then
        for _, p in ipairs(unknown) do
            if markMine(p) then progressed = true end
        end
    end
    return progressed
end

local function solveBoard(charPos, deadline)
    conflicts = 0
    local useGlobal = GLOBAL_MINES_ENABLED and not isRangeLimited()
    local analysis, unknown

    for iter = 1, (isEndlessOn and 2 or 3) do
        if iter > 1 and deadline and os.clock() > deadline then break end
        local cons = collectConstraints(charPos)
        propagate(cons, deadline)

        local alive = {}
        for _, c in ipairs(cons) do
            if not c.dead and #c.cells > 0 then alive[#alive + 1] = c end
        end

        -- Danh sách "ô chưa rõ" chỉ cần cho suy luận tổng số mìn (không dùng khi chỉ giải một vùng giới hạn)
        local O = 0
        if useGlobal then
            unknown = gatherUnknown(charPos)
            local frontierProbe = {}
            for _, c in ipairs(alive) do
                for _, p in ipairs(c.cells) do frontierProbe[p] = true end
            end
            for _, p in ipairs(unknown) do
                if not frontierProbe[p] then O = O + 1 end
            end
        else
            unknown = {}
        end

        local R = SET.totalMines - countKnownMines()
        analysis = analyzeFrontier(alive, R, O, useGlobal, isEndlessOn and ENDLESS_DEFAULT_DENSITY or nil, deadline, charPos)
        if analysis.conflict then conflicts = conflicts + 1 end

        local progressed = applyAnalysis(analysis, unknown)
        if deduceLastTiles(charPos) then progressed = true end
        if not progressed then break end
    end

    probabilityMap = analysis and analysis.probs or {}
    if isEndlessOn and not ENDLESS_GUESS_OUTSIDE then
        lastUnknown = {}
    else
        lastUnknown = gatherUnknown(charPos)
    end

    -- Có nước an toàn trong tầm?
    local hasSafe = false
    for part, isSafe in pairs(knownSafe) do
        if isSafe and part.Parent and isUnrevealed(part) and isWithinActiveRange(part, charPos, 0) then
            hasSafe = true
            break
        end
    end

    if currentBestGuess and (
        not currentBestGuess.Parent
        or knownSafe[currentBestGuess]
        or knownMines[currentBestGuess]
        or hasSafe
        or not isWithinActiveRange(currentBestGuess, charPos, 0)
    ) then
        local e = trackedVisuals[currentBestGuess]
        if e and e.tag == "Guess_Highlight" then clearVisuals(currentBestGuess) end
        currentBestGuess = nil
    end

    if not hasSafe and analysis then
        local R = SET.totalMines - countKnownMines()
        local best = pickGuess(analysis, lastUnknown, charPos, R)
        if best and best ~= currentBestGuess then
            if currentBestGuess then
                local e = trackedVisuals[currentBestGuess]
                if e and e.tag == "Guess_Highlight" then clearVisuals(currentBestGuess) end
            end
            currentBestGuess = best
            createHighlight(best, Color3.fromRGB(255, 255, 0), "Guess_Highlight")
        end
    end
end

-------------------------------------------------------------------------------
-- MAIN SOLVER LOOP
-------------------------------------------------------------------------------

-- Không giẫm mìn: tắt CanTouch trên các ô script biết là mìn; khôi phục giá trị gốc khi bỏ đánh dấu
-- (có độ trễ 1.5s để không nhấp nháy lúc script reset mềm), khi tắt tính năng, STOP hoặc Destroy.
SET.touchOff = setmetatable({}, { __mode = "k" })

function SET.restore()
    for part, rec in pairs(SET.touchOff) do
        if part.Parent then
            pcall(function() part.CanTouch = rec.orig end)
        end
        SET.touchOff[part] = nil
    end
end

function SET.syncNoStep(now)
    local off = SET.touchOff
    if not SET.noStep then
        if next(off) then SET.restore() end
        return
    end

    for part, isMine in pairs(knownMines) do
        if isMine and part.Parent then
            local rec = off[part]
            if not rec then
                off[part] = { orig = part.CanTouch, lost = nil }
                part.CanTouch = false
            else
                rec.lost = nil
                if part.CanTouch then part.CanTouch = false end -- game bật lại thì tắt tiếp
            end
        end
    end

    for part, rec in pairs(off) do
        if not part.Parent then
            off[part] = nil
        elseif not knownMines[part] then
            if not rec.lost then
                rec.lost = now
            elseif now - rec.lost > 1.5 then
                pcall(function() part.CanTouch = rec.orig end)
                off[part] = nil
            end
        end
    end
end

-- ANTI-STATIC: khi bật, vô hiệu hóa mọi thứ trong game.Players.LocalPlayer.PlayerGui.Gui
--   * ScreenGui/BillboardGui/SurfaceGui -> Enabled = false;  GuiObject -> Visible = false
--   * Script/LocalScript -> Enabled = false;  Sound -> Playing = false, Volume = 0
--   * ParticleEmitter, Beam, Trail, Light, PostEffect, UIStroke, UIGradient... -> Enabled = false
-- Giá trị gốc được lưu lại; tắt Anti-Static thì khôi phục để mọi thứ hoạt động lại như cũ.
-- Khi đang bật, đối tượng mới sinh ra trong Gui cũng bị vô hiệu hóa ngay, và trạng thái "tắt" được giữ lại
-- (quét lại mỗi 0.5s phòng khi game bật lại).
SET.stat = {
    orig = setmetatable({}, { __mode = "k" }),
    conns = {},
    gen = 0,
    classes = { "ParticleEmitter", "Beam", "Trail", "Light", "PostEffect", "Highlight",
                "UIStroke", "UIGradient", "Fire", "Smoke", "Sparkles" },
}

function SET.staticRoot()
    local pg = player:FindFirstChild("PlayerGui")
    return pg and pg:FindFirstChild("Gui") or nil
end

function SET.staticDisable(inst)
    if inst == screenGui or inst:IsDescendantOf(screenGui) then return end -- không đụng vào menu của chính script

    local st = SET.stat
    local function setProp(name, value)
        local ok, cur = pcall(function() return inst[name] end)
        if not ok then return end
        local rec = st.orig[inst]
        if not rec then
            rec = {}
            st.orig[inst] = rec
        end
        if rec[name] == nil then rec[name] = cur end
        if cur ~= value then pcall(function() inst[name] = value end) end
    end

    if inst:IsA("LayerCollector") then
        setProp("Enabled", false)
    elseif inst:IsA("GuiObject") then
        setProp("Visible", false)
    elseif inst:IsA("BaseScript") then
        setProp("Enabled", false)
    elseif inst:IsA("Sound") then
        setProp("Playing", false)
        setProp("Volume", 0)
    else
        for _, cls in ipairs(st.classes) do
            if inst:IsA(cls) then
                setProp("Enabled", false)
                break
            end
        end
    end
end

function SET.staticApply()
    local root = SET.staticRoot()
    if not root then return end
    SET.staticDisable(root)
    for _, d in ipairs(root:GetDescendants()) do
        SET.staticDisable(d)
    end
end

function SET.staticRestore()
    local st = SET.stat
    for inst, rec in pairs(st.orig) do
        if inst.Parent then
            for name, value in pairs(rec) do
                pcall(function() inst[name] = value end)
            end
        end
        st.orig[inst] = nil
    end
end

function SET.setAntiStatic(on)
    local st = SET.stat
    SET.antiStatic = on
    st.gen = st.gen + 1
    local myGen = st.gen

    for _, c in ipairs(st.conns) do c:Disconnect() end
    st.conns = {}

    if not on then
        SET.staticRestore()
        return
    end

    local function hookRoot(root)
        if st.gen ~= myGen then return end
        SET.staticApply()
        table.insert(st.conns, root.DescendantAdded:Connect(function(d)
            if SET.antiStatic and st.gen == myGen then
                task.defer(function() SET.staticDisable(d) end)
            end
        end))
    end

    local root = SET.staticRoot()
    if root then hookRoot(root) end

    -- Gui bị game tạo lại -> hook lại
    local pg = player:FindFirstChild("PlayerGui")
    if pg then
        table.insert(st.conns, pg.ChildAdded:Connect(function(child)
            if child.Name == "Gui" then hookRoot(child) end
        end))
    end

    task.spawn(function()
        while SET.antiStatic and st.gen == myGen do
            SET.staticApply()
            task.wait(0.5)
        end
    end)
end

-- Chống bấm lặp: một ô chỉ được bấm cờ tối đa 2 lần trong 10 giây (phòng khi không nhận ra cờ làm cờ bật / tắt liên tục)
SET.flagClicks = setmetatable({}, { __mode = "k" })

function SET.flagAllowed(part)
    local rec = SET.flagClicks[part]
    if not rec then return true end
    if os.clock() - rec.t0 > 10 then return true end
    return rec.n < 2
end

function SET.flagNote(part)
    local now = os.clock()
    local rec = SET.flagClicks[part]
    if rec and now - rec.t0 <= 10 then
        rec.n = rec.n + 1
    else
        SET.flagClicks[part] = { n = 1, t0 = now }
    end
end

local lastFlagRefresh = 0
local lastStatusText = ""

-- Quét trạng thái MỘT ô. Trả về: kind ("u" chưa mở / "n" ô số / nil), changed (trạng thái đổi), stale (ô số quay về chưa mở)
local function scanPart(part, charPos, now)
    if isRangeLimited() and not isWithinActiveRange(part, charPos, SOLVER_CONTEXT_PADDING) then
        clearVisuals(part)
        return nil, false, false
    end

    if not neighborMap[part] then cacheNeighbors(part, false) end

    local kind, changed, stale = nil, false, false

    if isExcluded(part) then
        if numberTiles[part] or knownSafe[part] or knownMines[part] then
            numberTiles[part] = nil; knownSafe[part] = nil; knownMines[part] = nil
            clearVisuals(part)
            changed = true
        end
    elseif isUnrevealed(part) then
        kind = "u"
        if numberTiles[part] then
            -- ô số quay lại trạng thái chưa mở => ván được reset
            numberTiles[part] = nil
            checkedNoNumber[part] = nil
            stale = true
            changed = true
        end
    else
        if knownSafe[part] then
            knownSafe[part] = nil
            clearVisuals(part)
            changed = true
        end
        if numberTiles[part] then
            kind = "n"
        else
            local rec = checkedNoNumber[part]
            if not rec or (rec.n < 4 and now - rec.t > 0.4) then
                local num = getNumber(part)
                if num then
                    numberTiles[part] = num
                    checkedNoNumber[part] = nil
                    kind = "n"
                    clearVisuals(part)
                    changed = true
                else
                    checkedNoNumber[part] = { n = (rec and rec.n or 0) + 1, t = now }
                end
            end
        end
    end

    return kind, changed, stale
end

local function solverTick()
    local charPos = getCharPos()
    local now = os.clock()
    local prof = EL.prof()

    if isEndlessOn then
        if charPos and (not EL.built or not endlessLastCenter
            or ((charPos - endlessLastCenter).Magnitude >= ENDLESS_REFRESH_DIST
                and now - endlessLastRefresh >= 0.35)
            or now - endlessLastRefresh >= prof.refreshInterval
            or (EL.dirty and now - endlessLastRefresh >= prof.refreshGap)) then
            EL.refresh(charPos)
        end
        if not EL.built then return end -- cửa sổ chưa dựng xong
    end

    local flagInterval = isEndlessOn and prof.flagInterval or FLAG_REFRESH_INTERVAL
    if now - lastFlagRefresh >= flagInterval then
        lastFlagRefresh = now
        refreshFlagCache()
    end

    local unrevCount, numCount, staleNumbers = 0, 0, 0
    local changedAny = false

    if isEndlessOn then
        -- Quét theo lát có ngân sách thời gian, vòng tròn qua danh sách (không quét cả cửa sổ mỗi tick)
        local list = cachedParts
        local n = #list
        local cur = EL.cursor
        local deadline = os.clock() + prof.scanBudget
        local scanned = 0
        while scanned < n do
            if cur > n then
                EL.stats.unrev, EL.stats.num = EL.accU, EL.accN
                EL.accU, EL.accN = 0, 0
                cur = 1
                if n == 0 then break end
            end
            local part = list[cur]
            if part and part.Parent then
                local kind, changed, wasStale = scanPart(part, charPos, now)
                if kind == "u" then
                    EL.accU = EL.accU + 1
                elseif kind == "n" then
                    EL.accN = EL.accN + 1
                end
                if changed then changedAny = true end
                if wasStale then staleNumbers = staleNumbers + 1 end
                cur = cur + 1
                scanned = scanned + 1
                if scanned % 48 == 0 and os.clock() > deadline then break end
            else
                if part then
                    clearVisuals(part)
                    neighborMap[part] = nil
                    numberTiles[part] = nil
                    knownMines[part] = nil
                    knownSafe[part] = nil
                    checkedNoNumber[part] = nil
                end
                list[cur] = list[n]
                list[n] = nil
                n = n - 1
                changedAny = true
            end
        end
        if cur > n then cur = 1 end
        EL.cursor = cur
        unrevCount, numCount = EL.stats.unrev, EL.stats.num
    else
        local writeIndex = 1
        for readIndex = 1, #cachedParts do
            local part = cachedParts[readIndex]
            if part and part.Parent then
                cachedParts[writeIndex] = part
                writeIndex = writeIndex + 1

                local kind, changed, wasStale = scanPart(part, charPos, now)
                if kind == "u" then
                    unrevCount = unrevCount + 1
                elseif kind == "n" then
                    numCount = numCount + 1
                end
                if wasStale then staleNumbers = staleNumbers + 1 end
            else
                if part then
                    clearVisuals(part)
                    neighborMap[part] = nil
                    numberTiles[part] = nil
                    knownMines[part] = nil
                    knownSafe[part] = nil
                    checkedNoNumber[part] = nil
                    cachedSet[part] = nil
                end
            end
        end
        for i = writeIndex, #cachedParts do cachedParts[i] = nil end
    end

    if staleNumbers >= 3 then
        hardResetKnowledge()
        return
    end

    if changedAny then EL.version = EL.version + 1 end

    local minesCount = countKnownMines()
    local safeCount = countKnownSafeUnrevealed()
    local bx = charPos and math.floor(charPos.X / 6) or 0
    local bz = charPos and math.floor(charPos.Z / 6) or 0
    local sig
    if isEndlessOn then
        sig = string.format("E%d|%d|%d|%d|%d|%s", EL.version, minesCount, safeCount, bx, bz, tostring(isAntiLagOn))
    else
        sig = string.format("%d|%d|%d|%d|%d|%d|%s", unrevCount, numCount, minesCount, safeCount, bx, bz, tostring(isAntiLagOn) .. tostring(isEndlessOn))
    end

    local solved = false
    local forceInt = isEndlessOn and prof.forceSolve or FORCE_SOLVE_INTERVAL
    if sig ~= lastSig or now - lastSolveTime >= forceInt then
        solveBoard(charPos, isEndlessOn and (os.clock() + prof.solveBudget) or nil)
        lastSig = sig
        lastSolveTime = now
        solved = true

        -- Mâu thuẫn -> dữ liệu suy luận có thể cũ, reset mềm (có cooldown tránh nhấp nháy)
        if conflicts > 0 then lastConflictTime = now end
        if conflicts > 0 and now - lastSoftReset > 1.5 then
            softResetKnowledge()
            return
        end
    end

    SET.syncNoStep(now)

    if isEspOn and (solved or ((isAntiLagOn or isEndlessOn) and now - EL.lastSync >= 0.3)) then
        EL.lastSync = now
        syncVisualsRange(charPos)
    end
    if SET.markLeftover or next(HERE.marks) ~= nil then
        updateHerePillar(charPos, countKnownMines()) -- khi tắt thì hàm này gỡ các thanh còn lại
    end

    local autoTag = (isAutoFlagging or isAutoOpening)
        and ("+" .. (isAutoFlagging and "F" or "") .. (isAutoOpening and "O" or "")) or ""
    local text
    if isEndlessOn then
        text = string.format("%s t%d u%d n%d | m%d s%d",
            "Endless" .. (isAntiLagOn and "(AL)" or "") .. autoTag,
            #cachedParts, unrevCount, numCount,
            minesCount, safeCount)
    else
        text = string.format("%s %d/%d | safe %d",
            "Scan" .. autoTag,
            minesCount, SET.totalMines, safeCount)
    end
    if text ~= lastStatusText then
        lastStatusText = text
        status.Text = text
    end
end

local function startSolverLoop()
    solverGeneration = solverGeneration + 1
    local myGeneration = solverGeneration

    task.spawn(function()
        local lastErr = nil
        while isScanning and myGeneration == solverGeneration do
            local t0 = os.clock()
            local ok, err = pcall(solverTick)
            if not ok and err ~= lastErr then
                lastErr = err
                warn("[Minesweeper Script] solver error: " .. tostring(err))
            end
            -- Tự giãn nhịp: tick nặng thì nghỉ lâu hơn để không chiếm quá ~40% CPU
            local base = isEndlessOn and EL.prof().tick or LOOP_INTERVAL
            task.wait(math.max(base, (os.clock() - t0) * 1.5))
        end
        clearHerePillar()
    end)
end

-------------------------------------------------------------------------------
-- BOARD CHANGE HANDLING (gộp sự kiện thêm/xoá part)
-------------------------------------------------------------------------------

local function flushBoardChanges()
    flushScheduled = false
    if not isScanning then
        addedQueue = {}
        removedSinceFlush = 0
        return
    end

    local q = addedQueue
    local removed = removedSinceFlush
    addedQueue = {}
    removedSinceFlush = 0

    if #q + removed >= BULK_CHANGE_THRESHOLD then
        -- Khả năng cao là ván mới: quét lại bàn và xoá toàn bộ tri thức cũ
        hardResetKnowledge()
        rescanBoard()
        return
    end

    local touched = {}
    for _, part in ipairs(q) do
        if part.Parent then touched[part] = true end
    end
    for part in pairs(touched) do
        cacheNeighbors(part, true)
        for _, nb in ipairs(neighborMap[part] or {}) do
            cacheNeighbors(nb, true)
        end
    end
    lastSig = nil -- buộc giải lại
end

local function scheduleFlush()
    if flushScheduled then return end
    flushScheduled = true
    task.delay(0.15, flushBoardChanges)
end

local function onDescendantAdded(descendant)
    if not isScanning then return end

    if isEndlessOn then
        -- chỉ đánh dấu "cần quét lại" (được gộp + giới hạn tần suất ở vòng solver)
        if descendant:IsA("BasePart") then EL.dirty = true end
        return
    end

    if isTileCandidate(descendant) then
        if not cachedSet[descendant] then
            cachedSet[descendant] = true
            cachedParts[#cachedParts + 1] = descendant
        end
        addedQueue[#addedQueue + 1] = descendant
        scheduleFlush()
    end
end

local function onDescendantRemoving(descendant)
    if not isScanning then return end

    if isEndlessOn then
        if cachedSet[descendant] then EL.dirty = true end
        return
    end

    if cachedSet[descendant] then
        removedSinceFlush = removedSinceFlush + 1
        scheduleFlush()
    end
end

-------------------------------------------------------------------------------
-- UI CONNECTIONS
-------------------------------------------------------------------------------

local function stopAutoActions()
    isAutoFlagging = false
    isAutoOpening = false
    autoFlagGeneration = autoFlagGeneration + 1
    autoOpenGeneration = autoOpenGeneration + 1
    autoFlagBtn.Text = "AUTO FLAG: OFF"
    autoFlagBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
    autoOpenBtn.Text = "AUTO OPEN: OFF"
    autoOpenBtn.TextColor3 = Color3.fromRGB(0, 255, 255)
    lastStatusText = ""
end

local function startSharedEngine()
    local tileRoot = getTileRoot()
    if not tileRoot then
        warn("[Minesweeper Script] Cannot find workspace.Flag.Parts")
        status.Text = "Status: Flag.Parts Not Found"
        status.TextColor3 = Color3.fromRGB(255, 170, 0)
        return false
    end

    isScanning = true
    status.Text = "Status: Starting analysis..."
    status.TextColor3 = Color3.fromRGB(0, 255, 0)
    lastStatusText = ""

    hardResetKnowledge()
    if isEndlessOn then
        EL.reset(true)
    else
        rescanBoard()
    end
    refreshFlagCache()

    table.insert(connections, tileRoot.DescendantAdded:Connect(onDescendantAdded))
    table.insert(connections, tileRoot.DescendantRemoving:Connect(onDescendantRemoving))
    startSolverLoop()
    return true
end

local function stopSharedEngine()
    if not isScanning then return end
    isScanning = false
    solverGeneration = solverGeneration + 1

    for _, conn in pairs(connections) do conn:Disconnect() end
    connections = {}
    if SET.restore then SET.restore() end
    hardResetKnowledge()
    cachedParts = {}
    cachedSet = {}
    neighborMap = {}
    addedQueue = {}
    removedSinceFlush = 0
    clearAllVisuals()
    clearHerePillar()
    status.Text = "Status: Idle"
    status.TextColor3 = Color3.fromRGB(255, 0, 0)
end

-- One shared analysis loop serves ESP, Auto Flag, Auto Open and No-Step.
-- Anti-Static remains independent and does not start the solver.
requestEngine = function()
    local needed = isEspOn or isAutoFlagging or isAutoOpening or SET.noStep or SET.markLeftover
    if needed then
        if not isScanning then
            return startSharedEngine()
        end
        return true
    end

    stopSharedEngine()
    return true
end

toggleBtn.MouseButton1Click:Connect(function()
    isEspOn = not isEspOn
    if isEspOn then
        if not requestEngine() then
            isEspOn = false
            toggleBtn.Text = "ESP: OFF"
            toggleBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
            return
        end
        toggleBtn.Text = "ESP: ON"
        toggleBtn.TextColor3 = Color3.fromRGB(0, 255, 0)
        -- If another feature already runs the shared solver, display its latest results immediately.
        if isScanning then syncVisualsRange(getCharPos()) end
    else
        toggleBtn.Text = "ESP: OFF"
        toggleBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
        clearAllVisuals()
        requestEngine() -- keep the solver alive only if another feature still needs it
    end
end)

-- AUTO FLAG: tháo cờ sai (cờ nằm trên ô đã chắc chắn an toàn) + đặt cờ lên mìn đã chắc chắn
autoFlagBtn.MouseButton1Click:Connect(function()
    isAutoFlagging = not isAutoFlagging
    lastStatusText = ""

    if not isAutoFlagging then
        autoFlagGeneration = autoFlagGeneration + 1
        autoFlagBtn.Text = "AUTO FLAG: OFF"
        autoFlagBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
        requestEngine()
        return
    end

    if not requestEngine() then
        isAutoFlagging = false
        autoFlagBtn.Text = "AUTO FLAG: OFF"
        autoFlagBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
        return
    end

    autoFlagBtn.Text = "AUTO FLAG: ON"
    autoFlagBtn.TextColor3 = Color3.fromRGB(0, 255, 0)
    autoFlagGeneration = autoFlagGeneration + 1
    local myGeneration = autoFlagGeneration

    task.spawn(function()
        local lastErr = nil
        while isAutoFlagging and isScanning and myGeneration == autoFlagGeneration do
            local ok, err = pcall(function()
                local charPos = getCharPos()
                if not charPos then
                    task.wait(0.1)
                    return
                end

                if os.clock() - lastFlagRefresh >= 0.3 then
                    lastFlagRefresh = os.clock()
                    refreshFlagCache()
                end
                local didWork = false
                local sinceWait = 0 -- số cờ đã thao tác trong lô hiện tại

                -- 1. Tháo cờ sai (gần nhất trước)
                local misplaced = {}
                for part in pairs(knownSafe) do
                    if part.Parent and isUnrevealed(part) and hasFlag(part)
                        and not onCooldown(part, 2.0) and SET.flagAllowed(part) and isMarkConfirmed(part)
                        and isWithinDistance(part, charPos, SET.actRange) then
                        misplaced[#misplaced + 1] = part
                    end
                end
                sortByProximity(misplaced, charPos)
                for _, part in ipairs(misplaced) do
                    if not isAutoFlagging or not isScanning then break end
                    local latest = getCharPos()
                    if latest and knownSafe[part] and isUnrevealed(part)
                        and isWithinDistance(part, latest, SET.actRange) then
                        clickTile(part)
                        stamp(part)
                        SET.flagNote(part)
                        didWork = true
                        sinceWait = sinceWait + 1
                        if sinceWait >= SET.flagBatch then
                            sinceWait = 0
                            task.wait(SET.flagDelay)
                        end
                    end
                end

                -- 2. Đặt cờ lên mìn chắc chắn (gần nhất trước)
                local toFlag = {}
                for part in pairs(knownMines) do
                    if part.Parent and isUnrevealed(part) and not hasFlag(part)
                        and not onCooldown(part, 2.0) and SET.flagAllowed(part) and isMarkConfirmed(part)
                        and isWithinDistance(part, charPos, SET.actRange) then
                        toFlag[#toFlag + 1] = part
                    end
                end
                sortByProximity(toFlag, charPos)
                for _, part in ipairs(toFlag) do
                    if not isAutoFlagging or not isScanning then break end
                    local latest = getCharPos()
                    if latest and knownMines[part] and isUnrevealed(part)
                        and isWithinDistance(part, latest, SET.actRange) then
                        clickTile(part)
                        stamp(part)
                        SET.flagNote(part)
                        didWork = true
                        sinceWait = sinceWait + 1
                        if sinceWait >= SET.flagBatch then
                            sinceWait = 0
                            task.wait(SET.flagDelay)
                        end
                    end
                end

                if sinceWait > 0 then task.wait(SET.flagDelay) end -- lô cuối chưa đủ số cờ vẫn phải nghỉ
                if not didWork then task.wait(0.1) end
            end)

            if not ok and err ~= lastErr then
                lastErr = err
                warn("[Minesweeper Script] auto-flag error: " .. tostring(err))
                task.wait(0.2)
            end
        end

        if myGeneration == autoFlagGeneration then
            isAutoFlagging = false
            if autoFlagBtn and autoFlagBtn.Parent then
                autoFlagBtn.Text = "AUTO FLAG: OFF"
                autoFlagBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
            end
        end
    end)
end)

-- AUTO OPEN: tự mở các ô đã chắc chắn an toàn (theo lô, gần nhất trước, bỏ qua ô đang có cờ)
autoOpenBtn.MouseButton1Click:Connect(function()
    isAutoOpening = not isAutoOpening
    lastStatusText = ""

    if not isAutoOpening then
        autoOpenGeneration = autoOpenGeneration + 1
        autoOpenBtn.Text = "AUTO OPEN: OFF"
        autoOpenBtn.TextColor3 = Color3.fromRGB(0, 255, 255)
        requestEngine()
        return
    end

    if not requestEngine() then
        isAutoOpening = false
        autoOpenBtn.Text = "AUTO OPEN: OFF"
        autoOpenBtn.TextColor3 = Color3.fromRGB(0, 255, 255)
        return
    end

    autoOpenBtn.Text = "AUTO OPEN: ON"
    autoOpenBtn.TextColor3 = Color3.fromRGB(0, 255, 0)
    autoOpenGeneration = autoOpenGeneration + 1
    local myGeneration = autoOpenGeneration

    task.spawn(function()
        local lastErr = nil
        while isAutoOpening and isScanning and myGeneration == autoOpenGeneration do
            local ok, err = pcall(function()
                local charPos = getCharPos()
                if not charPos then
                    task.wait(0.1)
                    return
                end

                local toReveal = {}
                for part in pairs(knownSafe) do
                    if part.Parent and isUnrevealed(part) and not hasFlag(part)
                        and not onCooldown(part, 0.35) and isMarkConfirmed(part)
                        and isWithinDistance(part, charPos, SET.actRange) then
                        toReveal[#toReveal + 1] = part
                    end
                end

                if #toReveal == 0 then
                    task.wait(0.08)
                    return
                end

                sortByProximity(toReveal, charPos)
                for i = 1, math.min(#toReveal, SET.openBatch) do
                    local part = toReveal[i]
                    stamp(part)
                    task.spawn(function()
                        if isAutoOpening and isScanning then
                            local latest = getCharPos()
                            if latest and knownSafe[part] and isUnrevealed(part)
                                and isWithinDistance(part, latest, SET.actRange) then
                                triggerTileTouch(part)
                            end
                        end
                    end)
                end
                task.wait(SET.openDelay)
            end)

            if not ok and err ~= lastErr then
                lastErr = err
                warn("[Minesweeper Script] auto-open error: " .. tostring(err))
                task.wait(0.2)
            end
        end

        if myGeneration == autoOpenGeneration then
            isAutoOpening = false
            if autoOpenBtn and autoOpenBtn.Parent then
                autoOpenBtn.Text = "AUTO OPEN: OFF"
                autoOpenBtn.TextColor3 = Color3.fromRGB(0, 255, 255)
            end
        end
    end)
end)

antiLagBtn.MouseButton1Click:Connect(function()
    isAntiLagOn = not isAntiLagOn
    if isAntiLagOn then
        antiLagBtn.Text = "ANTI-LAG: ON"
        antiLagBtn.TextColor3 = Color3.fromRGB(0, 255, 0)
    else
        antiLagBtn.Text = "ANTI-LAG: OFF"
        antiLagBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end

    lastSig = nil -- buộc giải lại với phạm vi mới
    endlessLastCenter = nil -- Endless: đổi profile (Full <-> Light) nên quét lại cửa sổ
    EL.version = EL.version + 1
    if isScanning and (isEspOn or SET.markLeftover) then
        local charPos = getCharPos()
        if isEspOn then syncVisualsRange(charPos) end
        if SET.markLeftover then updateHerePillar(charPos, countKnownMines()) end
    end
end)

endlessBtn.MouseButton1Click:Connect(function()
    isEndlessOn = not isEndlessOn
    if isEndlessOn then
        endlessBtn.Text = "ENDLESS: ON"
        endlessBtn.TextColor3 = Color3.fromRGB(0, 255, 0)
    else
        endlessBtn.Text = "ENDLESS: OFF"
        endlessBtn.TextColor3 = Color3.fromRGB(255, 170, 0)
    end

    lastSig = nil
    endlessLastCenter = nil
    if isScanning then
        softResetKnowledge()
        EL.reset(true) -- Endless ON: dựng lại cửa sổ ở vòng solver kế tiếp
        if not isEndlessOn then
            rescanBoard() -- Endless OFF: quay lại quét cả bàn
        end
    end
end)

local function destroyAll()
    pcall(SET.restore)
    pcall(SET.setAntiStatic, false)
    isEspOn = false
    isScanning = false
    isAutoFlagging = false
    isAutoOpening = false
    SET.noStep = false
    SET.markLeftover = false
    isAntiLagOn = false
    solverGeneration = solverGeneration + 1
    stopAutoActions()

    for _, conn in pairs(connections) do conn:Disconnect() end
    connections = {}
    clearAllVisuals()
    clearFiftyFiftyAlert()
    clearHerePillar()
    pcall(function() visualsFolder:Destroy() end)
    for _, c in ipairs(uiConns) do c:Disconnect() end
    uiConns = {}
    pcall(function() screenGui:Destroy() end)
end

destroyBtn.MouseButton1Click:Connect(destroyAll)
env.__MS_CLEANUP = destroyAll

-- Khởi tạo: nạp cài đặt đã lưu rồi áp dụng các tính năng đang bật (MARK LEFTOVER mặc định BẬT)
SET.load()
if SET.antiStatic then SET.setAntiStatic(true) end
if SET.markLeftover or SET.noStep then
    task.defer(function()
        if requestEngine then requestEngine() end
    end)
end
