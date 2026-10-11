-- [[ Deep Fishing - Fishy Hub v6.3 (Full Capacity + Item Collector + Landing Predictor) ]] --
-- Совместимо с Real Executor
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

-- Очистка старых потоков и GUI чтобы не двоились
if getgenv()._FishyHubCleanup then
    pcall(getgenv()._FishyHubCleanup)
end

local myHubToken = os.clock()
getgenv()._FishyHubToken = myHubToken
getgenv()._FishyHubCleanup = function()
    getgenv()._FishyHubToken = nil
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
    pcall(function()
        local p = workspace:FindFirstChild("FishyWaterWalk")
        if p then p:Destroy() end
    end)
    pcall(function()
        local g = game:GetService("CoreGui"):FindFirstChild("FishyGpuAfkScreen")
        if g then g:Destroy() end
    end)
    pcall(function()
        local h = game:GetService("CoreGui"):FindFirstChild("FishyStatsHUD")
        if h then h:Destroy() end
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
            local ph = LocalPlayer.PlayerGui:FindFirstChild("FishyStatsHUD")
            if ph then ph:Destroy() end
        end
    end)
end

pcall(function()
    local cg = game:GetService("CoreGui")
    for _, g in ipairs(cg:GetChildren()) do
        if g.Name:find("Fishy Hub") or g.Name == "FishyStatsHUD" or g.Name == "FishyGpuAfkScreen" then
            g:Destroy()
        end
    end
    if gethui then
        for _, g in ipairs(gethui():GetChildren()) do
            if g.Name:find("Fishy Hub") or g.Name == "FishyStatsHUD" or g.Name == "FishyGpuAfkScreen" then
                g:Destroy()
            end
        end
    end
end)

-- Загрузка современной UI библиотеки WindUI (Glassmorphism & Acrylic)
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Fishy Hub | Deep Fishing",
    Icon = "fish-symbol",
    Author = "by Real MCP",
    Folder = "FishyHubDeepFishing",
    Size = UDim2.fromOffset(660, 520),
    MinSize = Vector2.new(580, 420),
    Transparent = true,
    Theme = "Dark",
    Resizable = true,
    ToggleKey = Enum.KeyCode.RightShift,
    OpenButton = {
        Title = "Fishy Hub",
        Icon = "fish-symbol",
        CornerRadius = UDim.new(0, 12),
        Enabled = true,
        Draggable = true,
    }
})

-- Предварительные ссылки на экраны для управления слоями
local gpuScreenGui = nil
local statsHudGui = nil

-- Гарантия приоритета слоев: WindUI (верх) > HUD (середина) > 3D бекдроп (низ)
local function ensureGuiLayering()
    pcall(function()
        if WindUI then
            if WindUI.ScreenGui then
                WindUI.ScreenGui.DisplayOrder = 500
            end
            if WindUI.NotificationGui then
                WindUI.NotificationGui.DisplayOrder = 600
            end
            if WindUI.DropdownGui then
                WindUI.DropdownGui.DisplayOrder = 601
            end
            if WindUI.TooltipGui then
                WindUI.TooltipGui.DisplayOrder = 602
            end
        end
        if statsHudGui then
            statsHudGui.DisplayOrder = 200
        end
        if gpuScreenGui then
            gpuScreenGui.DisplayOrder = -1000000
        end
    end)
end
ensureGuiLayering()

-- Надежный глобальный бинд открытия/закрытия GUI (Insert, RightShift, RightControl, F4)
local toggleKeys = {
    [Enum.KeyCode.RightShift] = true,
    [Enum.KeyCode.RightControl] = true,
    [Enum.KeyCode.Insert] = true,
    [Enum.KeyCode.F4] = true,
}
UserInputService.InputBegan:Connect(function(input, gpe)
    if UserInputService:GetFocusedTextBox() then return end
    if toggleKeys[input.KeyCode] then
        if Window then
            if Window.Toggle then
                Window:Toggle()
            elseif Window.Closed ~= nil then
                if Window.Closed then Window:Open() else Window:Close() end
            end
        end
    end
end)

-- Гарантированная система уведомлений (Roblox Core + WindUI)
local StarterGui = game:GetService("StarterGui")
local function showNotification(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title),
            Text = tostring(text),
            Duration = 3.5
        })
    end)
    pcall(function()
        if WindUI and WindUI.Notify then
            WindUI:Notify({
                Title = tostring(title),
                Content = tostring(text),
                Duration = 3.5,
                Icon = "sparkles"
            })
        end
    end)
end


-- Игровые конфигурации и модули
local RS = ReplicatedStorage
local FishConfig = require(RS.Shared.Content.Item.Fish)
local RarityConfig = require(RS.Shared.Config.RarityConfig)
local ChestConfig = RS.Shared.Content.Item:FindFirstChild("Chest") and require(RS.Shared.Content.Item.Chest)
local KeyConfig = RS.Shared.Content.Item:FindFirstChild("Key") and require(RS.Shared.Content.Item.Key)
local ScrollConfig = RS.Shared.Content.Item:FindFirstChild("Scroll") and require(RS.Shared.Content.Item.Scroll)
local SummonConfig = RS.Shared.Content.Item:FindFirstChild("Summon") and require(RS.Shared.Content.Item.Summon)
local CageConfig = RS.Shared.Content.Item:FindFirstChild("Cage") and require(RS.Shared.Content.Item.Cage)
local JunkConfig = RS.Shared.Content.Item:FindFirstChild("Junk") and require(RS.Shared.Content.Item.Junk)

-- Контроллеры клиента
local AutoFishingCtrl, CatchMinigameCtrl, FishingCtrl, FishSchoolCtrl, ThrowCinematicCtrl, NpcSellCtrl
pcall(function() AutoFishingCtrl = require(LocalPlayer.PlayerScripts.Client.Controllers.Fishing.AutoFishing) end)
pcall(function() CatchMinigameCtrl = require(LocalPlayer.PlayerScripts.Client.Controllers.ThrowCinematic.CatchMinigame) end)
pcall(function() FishingCtrl = require(LocalPlayer.PlayerScripts.Client.Controllers.Fishing) end)
pcall(function() FishSchoolCtrl = require(LocalPlayer.PlayerScripts.Client.Controllers.ThrowCinematic.FishSchool) end)
pcall(function() ThrowCinematicCtrl = require(LocalPlayer.PlayerScripts.Client.Controllers.ThrowCinematic) end)
pcall(function() NpcSellCtrl = require(LocalPlayer.PlayerScripts.Client.Controllers.Tags.NPC_Sell) end)

-- Переменные состояния
local autoFishEnabled = (AutoFishingCtrl and AutoFishingCtrl.On == true) or false
local autoPerfectEnabled = true
local instantCatchEnabled = true
local turboCastEnabled = true
local fastArcEnabled = true          -- ⚡ Мгновенный перелёт поплавка в воду (Arc Skip)
local fastDiveEnabled = true         -- 🌊 Мгновенное погружение на дно (Dive Skip)
local instantPullEnabled = true       -- ⏩ Мгновенный подъем со дна и возврат (Skip Pull-Up & Return Animations)
local freeWalkEnabled = true          -- 🚶 Свободный ход во время и после заброса (Анти-заморозка)
local currentWalkSpeed = 16           -- Текущая скорость ходьбы
local fpsBoostEnabled = false         -- 🚀 Оптимизация FPS (Boost Performance)
local potatoGfxEnabled = false        -- 🥔 Картофельная графика (Potato PC / Smooth Plastic & No Textures)
local clearFogEnabled = false         -- 🌫️ Удаление тумана и атмосферы (Clear Horizon / No Fog Lag)
local unlockFpsEnabled = true         -- ⚡ Разблокировка FPS (999 FPS)
local infJumpEnabled = false          -- 🦘 Бесконечные прыжки в воздухе
local waterWalkEnabled = false        -- 🌊 Хождение по воде / Jesus Mode (без плавания)
local flyEnabled = false              -- 🚀 Плавный полёт (WASD + Space/Shift)
local flySpeed = 50                   -- Скорость полёта
local sessionFishCaught = 0           -- Всего поймано рыб за сессию
local sessionMoneyEarned = 0          -- Всего заработано монет за сессию
local sessionStartTime = os.clock()   -- Время старта скрипта
local autoFightEnabled = true
local instantReelEnabled = true
local autoSellEnabled = true
local autoSellInterval = 10
local autoPondEnabled = true        -- Авто-помещение лучших рыб в пруд перед продажей
local notifyCatchValue = true       -- Уведомление о заработке за заброс
local collectItemsEnabled = true   -- Сбор сундуков, бутылок, мусора и артефактов
local landingPredictorEnabled = true -- Показ точки приземления поплавка на полоске
local autoUpgradeCapacity = false  -- Авто-покупка слотов вместимости
local autoUpgradeAll = false       -- Авто-покупка всех статов
local fishEspEnabled = true
local espLabelsEnabled = true
local noclipEnabled = false
local fallbackToBest = true
local catchMode = "Rarest" -- "Secret", "Rarest", "Money", "Biggest", "Any"
local activeBossFight = false
local wasBossFight = false
local sellRarities = {
    Common = true,
    Uncommon = true,
    Rare = true,
    Epic = true,
    Legendary = false, -- Защита ценной рыбы от случайной продажи
    Mythic = false,    -- Защита мифической рыбы
    Secret = false,    -- Защита секретной рыбы
    Exotic = false     -- Защита экзотической рыбы
}

-- 🚀 Функция применения комплексной оптимизации FPS
local function applyFpsBoost(enable)
    pcall(function()
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.WaterWaveSize = enable and 0 or 0.15
            terrain.WaterWaveSpeed = enable and 0 or 10
            terrain.WaterReflectance = enable and 0 or 0.05
            terrain.WaterTransparency = enable and 1 or 0.8
            terrain.Decoration = not enable -- Отключает ресурсоемкую 3D траву
        end
        local lighting = game:GetService("Lighting")
        lighting.GlobalShadows = not enable
        for _, obj in ipairs(lighting:GetChildren()) do
            if obj:IsA("PostProcessEffect") or obj:IsA("BloomEffect") or obj:IsA("BlurEffect") 
               or obj:IsA("SunRaysEffect") or obj:IsA("DepthOfFieldEffect") or obj:IsA("ColorCorrectionEffect") then
                obj.Enabled = not enable
            end
        end
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") 
               or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("Beam") then
                obj.Enabled = not enable
            end
        end
        if enable and setfpscap then
            setfpscap(999)
        end
    end)
end

-- 🥔 Картофельная графика (Potato PC: убирает текстуры, декали и тени деталей)
local originalMaterials = {}
local function applyPotatoGfx(enable)
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                if enable then
                    if not originalMaterials[obj] then
                        originalMaterials[obj] = {
                            Material = obj.Material,
                            CastShadow = obj.CastShadow
                        }
                    end
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.CastShadow = false
                elseif originalMaterials[obj] then
                    obj.Material = originalMaterials[obj].Material
                    obj.CastShadow = originalMaterials[obj].CastShadow
                end
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = enable and 1 or 0
            end
        end
    end)
end

-- 🌫️ Удаление тумана и атмосферы (Clear Horizon: убирает лаги от дымки лавы и тумана)
local function applyClearFog(enable)
    pcall(function()
        local lighting = game:GetService("Lighting")
        if enable then
            lighting.FogEnd = 100000
            lighting.FogStart = 0
            for _, obj in ipairs(lighting:GetChildren()) do
                if obj:IsA("Atmosphere") or obj:IsA("Clouds") then
                    obj.Density = 0
                end
            end
        else
            lighting.FogEnd = 1000
        end
    end)
end

-- 🥔 0% GPU AFK Режим с настраиваемым цветом экрана (RGB Палетка)
local gpuScreenFrame = nil
local gpuScreenColor = Color3.fromRGB(15, 15, 22)
local gpuAfkEnabled = false

local function setGpuAfkMode(enable)
    gpuAfkEnabled = enable
    pcall(function()
        RunService:Set3dRenderingEnabled(not enable)
    end)
    ensureGuiLayering()
    if enable then
        if not gpuScreenGui then
            gpuScreenGui = Instance.new("ScreenGui")
            gpuScreenGui.Name = "FishyGpuAfkScreen"
            gpuScreenGui.DisplayOrder = -1000000 -- Гарантированно самый нижний слой под меню и HUD
            gpuScreenGui.IgnoreGuiInset = true
            gpuScreenGui.ResetOnSpawn = false

            local targetParent = nil
            pcall(function()
                if WindUI and WindUI.ScreenGui and WindUI.ScreenGui.Parent then
                    targetParent = WindUI.ScreenGui.Parent
                elseif gethui then
                    targetParent = gethui()
                elseif syn and syn.protect_gui then
                    syn.protect_gui(gpuScreenGui)
                    targetParent = game:GetService("CoreGui")
                else
                    targetParent = game:GetService("CoreGui")
                end
            end)
            if not targetParent then
                targetParent = LocalPlayer:WaitForChild("PlayerGui")
            end
            gpuScreenGui.Parent = targetParent

            gpuScreenFrame = Instance.new("Frame")
            gpuScreenFrame.Size = UDim2.fromScale(1, 1)
            gpuScreenFrame.BackgroundColor3 = gpuScreenColor
            gpuScreenFrame.BorderSizePixel = 0
            gpuScreenFrame.ZIndex = 0
            gpuScreenFrame.Parent = gpuScreenGui

            local lbl = Instance.new("TextLabel")
            lbl.Name = "AfkStatusLabel"
            lbl.Size = UDim2.new(1, 0, 0, 30)
            lbl.Position = UDim2.new(0, 0, 0.94, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = "GPU 0% Potato AFK Active | 3D Rendering Disabled"
            lbl.TextColor3 = Color3.fromRGB(200, 205, 215)
            lbl.TextTransparency = 0.5
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextSize = 12
            lbl.Parent = gpuScreenFrame
        else
            gpuScreenGui.Enabled = true
            gpuScreenGui.DisplayOrder = -1000000
            if gpuScreenFrame then
                gpuScreenFrame.BackgroundColor3 = gpuScreenColor
            end
        end
    else
        if gpuScreenGui then
            gpuScreenGui.Enabled = false
        end
    end
    ensureGuiLayering()
end

-- 🎁 Мгновенное открытие всех пойманных сундуков
local function openAllChests()
    pcall(function()
        local ev = require(RS.Shared.Events).Client("Chest")
        if ev then
            ev:Fire("OpenAll")
            ev:Fire("Open")
        end
        local evItem = require(RS.Shared.Events).Client("Item")
        if evItem then
            evItem:Fire("OpenChests")
        end
    end)
    pcall(function()
        local int = LocalPlayer.PlayerGui:FindFirstChild("Interfaces")
        if int and int:FindFirstChild("OpenChest") then
            local btn = int.OpenChest:FindFirstChild("Open", true)
            if btn and firesignal then firesignal(btn.MouseButton1Click) end
        end
    end)
    showNotification("🎁 Chests", "Запрос на открытие сундуков отправлен!")
end

-- Цвета редкостей
local rarityColors = {
    Common    = Color3.fromRGB(200, 200, 200),
    Uncommon  = Color3.fromRGB(60, 220, 60),
    Rare      = Color3.fromRGB(40, 160, 255),
    Epic      = Color3.fromRGB(190, 80, 255),
    Legendary = Color3.fromRGB(255, 150, 0),
    Mythic    = Color3.fromRGB(255, 45, 45),
    Secret    = Color3.fromRGB(255, 0, 140),
    Exotic    = Color3.fromRGB(255, 220, 0),
    Special   = Color3.fromRGB(0, 255, 200),
    Chest     = Color3.fromRGB(255, 215, 0),
    Junk      = Color3.fromRGB(160, 140, 120)
}

local CollectionService = game:GetService("CollectionService")

-- Форматирование чисел в валюту ($1.25M, $45.2K, $6.36T, $1Qa, $1Qi)
local moneySuffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
local function formatMoney(val)
    if not val or val <= 0 then return "$0" end
    if val < 1000 then
        return string.format("$%d", math.floor(val))
    end
    local exp = math.floor(math.log10(val) / 3)
    if exp > #moneySuffixes - 1 then
        exp = #moneySuffixes - 1
    end
    local num = val / (10 ^ (exp * 3))
    if num >= 999.995 and exp < #moneySuffixes - 1 then
        num = num / 1000
        exp = exp + 1
    end
    return string.format("$%.2f%s", num, moneySuffixes[exp + 1])
end

-- 🌐 Двуязычная локализация скрипта (English дефолтный / Русский)
local currentLanguage = "en"
local locElements = {}

local function registerLoc(element, enTitle, ruTitle, enDesc, ruDesc)
    if not element then return end
    table.insert(locElements, {
        element = element,
        enTitle = enTitle,
        ruTitle = ruTitle,
        enDesc = enDesc,
        ruDesc = ruDesc,
    })
    return element
end

local function locText(enStr, ruStr)
    return (currentLanguage == "ru") and ruStr or enStr
end

-- 📊 Экранный HUD и статистика AFK сессии (слева по центру экрана)
local hudEnabled = true
local hudTimeLabel = nil
local hudTotalValue = nil
local hudMpmValue = nil
local hudMphValue = nil
local hudSpeedValue = nil
local hudHeaderTitleLabel = nil
local hudRowTitles = {}
local statsParagraph = nil

local function createStatsHud()
    if statsHudGui then return end
    statsHudGui = Instance.new("ScreenGui")
    statsHudGui.Name = "FishyStatsHUD"
    statsHudGui.ResetOnSpawn = false
    statsHudGui.DisplayOrder = 200 -- Выше 3D бекдропа (-1000000), под окном WindUI (500)
    statsHudGui.IgnoreGuiInset = true

    local targetParent = nil
    pcall(function()
        if WindUI and WindUI.ScreenGui and WindUI.ScreenGui.Parent then
            targetParent = WindUI.ScreenGui.Parent
        elseif gethui then
            targetParent = gethui()
        elseif syn and syn.protect_gui then
            syn.protect_gui(statsHudGui)
            targetParent = game:GetService("CoreGui")
        else
            targetParent = game:GetService("CoreGui")
        end
    end)
    if not targetParent then
        targetParent = LocalPlayer:WaitForChild("PlayerGui")
    end
    statsHudGui.Parent = targetParent

    local frame = Instance.new("Frame")
    frame.Name = "HudFrame"
    frame.Size = UDim2.new(0, 226, 0, 134)
    frame.Position = UDim2.new(0, 16, 0.5, -67) -- Слева по центру экрана
    frame.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = statsHudGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(48, 54, 70)
    stroke.Transparency = 0.45
    stroke.Thickness = 1
    stroke.Parent = frame

    -- Хедер: минималистичная иконка + заголовок
    local headerIcon = Instance.new("ImageLabel")
    headerIcon.Name = "HeaderIcon"
    headerIcon.Size = UDim2.new(0, 12, 0, 12)
    headerIcon.Position = UDim2.new(0, 12, 0, 8)
    headerIcon.BackgroundTransparency = 1
    headerIcon.Image = "rbxassetid://85473888890506" -- Lucide timer
    headerIcon.ImageColor3 = Color3.fromRGB(220, 225, 235)
    headerIcon.Parent = frame

    hudHeaderTitleLabel = Instance.new("TextLabel")
    hudHeaderTitleLabel.Name = "HeaderTitle"
    hudHeaderTitleLabel.Size = UDim2.new(0, 105, 0, 20)
    hudHeaderTitleLabel.Position = UDim2.new(0, 28, 0, 4)
    hudHeaderTitleLabel.BackgroundTransparency = 1
    hudHeaderTitleLabel.Text = (currentLanguage == "ru") and "AFK СТАТИСТИКА" or "AFK STATS"
    hudHeaderTitleLabel.Font = Enum.Font.GothamBold
    hudHeaderTitleLabel.TextSize = 10
    hudHeaderTitleLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
    hudHeaderTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    hudHeaderTitleLabel.Parent = frame

    -- Правая часть хедера: часы и время сессии
    local clockIcon = Instance.new("ImageLabel")
    clockIcon.Name = "ClockIcon"
    clockIcon.Size = UDim2.new(0, 11, 0, 11)
    clockIcon.Position = UDim2.new(1, -72, 0, 8)
    clockIcon.BackgroundTransparency = 1
    clockIcon.Image = "rbxassetid://121808839832144" -- Lucide clock
    clockIcon.ImageColor3 = Color3.fromRGB(160, 165, 180)
    clockIcon.Parent = frame

    hudTimeLabel = Instance.new("TextLabel")
    hudTimeLabel.Name = "TimeLabel"
    hudTimeLabel.Size = UDim2.new(0, 56, 0, 20)
    hudTimeLabel.Position = UDim2.new(1, -58, 0, 4)
    hudTimeLabel.BackgroundTransparency = 1
    hudTimeLabel.Text = "00:00:00"
    hudTimeLabel.Font = Enum.Font.GothamMedium
    hudTimeLabel.TextSize = 10
    hudTimeLabel.TextColor3 = Color3.fromRGB(175, 180, 195)
    hudTimeLabel.TextXAlignment = Enum.TextXAlignment.Right
    hudTimeLabel.Parent = frame

    -- Тонкий разделитель
    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.Size = UDim2.new(1, -24, 0, 1)
    divider.Position = UDim2.new(0, 12, 0, 26)
    divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    divider.BackgroundTransparency = 0.92
    divider.BorderSizePixel = 0
    divider.Parent = frame

    -- Конструктор строк статистики (монохромная иконка + заголовок + белое значение справа)
    local function createHudRow(yPos, iconAsset, key, defaultLabel)
        local rowIcon = Instance.new("ImageLabel")
        rowIcon.Size = UDim2.new(0, 13, 0, 13)
        rowIcon.Position = UDim2.new(0, 12, 0, yPos + 3)
        rowIcon.BackgroundTransparency = 1
        rowIcon.Image = iconAsset
        rowIcon.ImageColor3 = Color3.fromRGB(230, 235, 245)
        rowIcon.Parent = frame

        local rowTitle = Instance.new("TextLabel")
        rowTitle.Size = UDim2.new(0, 85, 0, 20)
        rowTitle.Position = UDim2.new(0, 30, 0, yPos)
        rowTitle.BackgroundTransparency = 1
        rowTitle.Text = defaultLabel
        rowTitle.Font = Enum.Font.GothamMedium
        rowTitle.TextSize = 11
        rowTitle.TextColor3 = Color3.fromRGB(160, 165, 180)
        rowTitle.TextXAlignment = Enum.TextXAlignment.Left
        rowTitle.Parent = frame
        hudRowTitles[key] = rowTitle

        local rowValue = Instance.new("TextLabel")
        rowValue.Size = UDim2.new(1, -125, 0, 20)
        rowValue.Position = UDim2.new(0, 115, 0, yPos)
        rowValue.BackgroundTransparency = 1
        rowValue.Text = "-"
        rowValue.Font = Enum.Font.GothamBold
        rowValue.TextSize = 11
        rowValue.TextColor3 = Color3.fromRGB(255, 255, 255)
        rowValue.TextXAlignment = Enum.TextXAlignment.Right
        rowValue.Parent = frame

        return rowValue
    end

    -- Строка 1: Всего заработано монет и рыб
    hudTotalValue = createHudRow(30, "rbxassetid://116510979641930", "total", (currentLanguage == "ru") and "Всего доход" or "Total Earned")
    hudTotalValue.Text = "$0 (0 fish)"

    -- Строка 2: Доход в минуту
    hudMpmValue = createHudRow(54, "rbxassetid://130551565616516", "mpm", (currentLanguage == "ru") and "Доход / Мин" or "Money / Min")
    hudMpmValue.Text = "$0/m"

    -- Строка 3: Доход в час
    hudMphValue = createHudRow(78, "rbxassetid://81819858538839", "mph", (currentLanguage == "ru") and "Доход / Час" or "Money / Hour")
    hudMphValue.Text = "$0/h"

    -- Строка 4: Скорость вылова в минуту
    hudSpeedValue = createHudRow(102, "rbxassetid://124360663785796", "speed", (currentLanguage == "ru") and "Темп вылова" or "Catch Rate")
    hudSpeedValue.Text = "0.0 / min"

    ensureGuiLayering()
end

local function updateStatsHud()
    local elapsed = os.clock() - sessionStartTime
    local hrs = math.floor(elapsed / 3600)
    local mins = math.floor((elapsed % 3600) / 60)
    local secs = math.floor(elapsed % 60)
    local timeStr = string.format("%02d:%02d:%02d", hrs, mins, secs)

    local mpm = 0
    local mph = 0
    local cpm = 0
    if elapsed > 2 then
        mpm = (sessionMoneyEarned / elapsed) * 60
        mph = (sessionMoneyEarned / elapsed) * 3600
        cpm = (sessionFishCaught / elapsed) * 60
    end

    local isRu = (currentLanguage == "ru")
    if statsParagraph and statsParagraph.SetDesc then
        if isRu then
            statsParagraph:SetDesc(string.format(
                "Поймано: %d шт. | Общая выручка: %s\nДоход / Мин: %s/мин | Доход / Час: %s/час\nВремя сессии: %s | Скорость: %.1f / мин",
                sessionFishCaught,
                formatMoney(sessionMoneyEarned),
                formatMoney(mpm),
                formatMoney(mph),
                timeStr,
                cpm
            ))
        else
            statsParagraph:SetDesc(string.format(
                "Fish Caught: %d | Total Revenue: %s\nMoney / Min: %s/m | Money / Hour: %s/h\nSession Time: %s | Catch Rate: %.1f / min",
                sessionFishCaught,
                formatMoney(sessionMoneyEarned),
                formatMoney(mpm),
                formatMoney(mph),
                timeStr,
                cpm
            ))
        end
    end

    if hudTimeLabel then
        hudTimeLabel.Text = timeStr
    end
    if hudTotalValue then
        hudTotalValue.Text = string.format(isRu and "%s (%d рыб)" or "%s (%d fish)", formatMoney(sessionMoneyEarned), sessionFishCaught)
    end
    if hudMpmValue then
        hudMpmValue.Text = string.format(isRu and "%s/мин" or "%s/m", formatMoney(mpm))
    end
    if hudMphValue then
        hudMphValue.Text = string.format(isRu and "%s/час" or "%s/h", formatMoney(mph))
    end
    if hudSpeedValue then
        hudSpeedValue.Text = string.format(isRu and "%.1f / мин" or "%.1f / min", cpm)
    end
end

local function setScriptLanguage(lang)
    currentLanguage = lang
    local isRu = (lang == "ru")
    if hudHeaderTitleLabel then
        hudHeaderTitleLabel.Text = isRu and "AFK СТАТИСТИКА" or "AFK STATS"
    end
    if hudRowTitles.total then
        hudRowTitles.total.Text = isRu and "Всего доход" or "Total Earned"
    end
    if hudRowTitles.mpm then
        hudRowTitles.mpm.Text = isRu and "Доход / Мин" or "Money / Min"
    end
    if hudRowTitles.mph then
        hudRowTitles.mph.Text = isRu and "Доход / Час" or "Money / Hour"
    end
    if hudRowTitles.speed then
        hudRowTitles.speed.Text = isRu and "Темп вылова" or "Catch Rate"
    end
    if updateStatsHud then
        updateStatsHud()
    end
    for _, item in ipairs(locElements) do
        pcall(function()
            if item.element then
                local title = isRu and item.ruTitle or item.enTitle
                local desc = isRu and item.ruDesc or item.enDesc
                if title and item.element.SetTitle then item.element:SetTitle(title) end
                if desc and item.element.SetDesc then item.element:SetDesc(desc) end
            end
        end)
    end
    showNotification(
        isRu and "Язык" or "Language",
        isRu and "Установлен русский язык интерфейса" or "Interface language set to English"
    )
end

createStatsHud()

task.spawn(function()
    while true do
        task.wait(1)
        if hudEnabled and statsHudGui and statsHudGui.Enabled then
            updateStatsHud()
        end
    end
end)

-- Поиск активного продавца в текущем активном мире (World 1, World 2, World 3, World 4)
local function getActiveSellNPC()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local myPos = hrp and hrp.Position or Vector3.zero

    -- 1. Сначала ищем NPC_Sell напрямую в текущей активной папке мира: Workspace.World[ActiveWorld].Interactable.NPC_Sell
    local worldFolder = workspace:FindFirstChild("World")
    if worldFolder then
        -- Сначала проверяем мир, ближе всего к которому находится игрок
        local bestWorldNpc = nil
        local bestWorldDist = math.huge
        for _, w in ipairs(worldFolder:GetChildren()) do
            local interactable = w:FindFirstChild("Interactable")
            local npc = interactable and interactable:FindFirstChild("NPC_Sell")
            if npc and npc:IsDescendantOf(workspace) then
                local dist = (npc:GetPivot().Position - myPos).Magnitude
                if dist < bestWorldDist then
                    bestWorldDist = dist
                    bestWorldNpc = npc
                end
            end
        end
        if bestWorldNpc then
            return bestWorldNpc
        end
    end

    -- 2. Поиск среди всех объектов с тегом "NPC_Sell" в workspace — выбираем БЛИЖАЙШЕГО к игроку в текущем мире!
    local bestNpc = nil
    local bestDist = math.huge
    for _, npc in ipairs(CollectionService:GetTagged("NPC_Sell")) do
        if npc:IsDescendantOf(workspace) then
            local pos = npc:GetPivot().Position
            local dist = (pos - myPos).Magnitude
            if dist < bestDist then
                bestDist = dist
                bestNpc = npc
            end
        end
    end
    if bestNpc then return bestNpc end

    -- 3. Резервный поиск по имени "NPC_Sell" среди всех потомков workspace
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "NPC_Sell" and obj:IsDescendantOf(workspace) and obj ~= char and not obj:IsDescendantOf(char) then
            local pos = obj:GetPivot().Position
            local dist = (pos - myPos).Magnitude
            if dist < bestDist then
                bestDist = dist
                bestNpc = obj
            end
        end
    end

    return bestNpc
end

-- Определение текущего мира (World 1, World 2, World 3, World 4)
local function getCurrentWorldName()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local myPos = hrp and hrp.Position or Vector3.zero

    local worldFolder = workspace:FindFirstChild("World")
    if worldFolder then
        local bestWorld = nil
        local bestDist = math.huge
        for _, w in ipairs(worldFolder:GetChildren()) do
            local p = w:GetPivot().Position
            local d = (p - myPos).Magnitude
            if d < bestDist then
                bestDist = d
                bestWorld = w.Name
            end
        end
        if bestWorld then
            local bw = string.lower(bestWorld)
            if bw:find("2") or bw:find("desert") or bw:find("sand") or bw:find("dune") then
                return "World 2 (Desert & Dunes)"
            elseif bw:find("3") or bw:find("frost") or bw:find("ice") or bw:find("tundra") then
                return "World 3 (Frostmere & Tundra)"
            elseif bw:find("4") or bw:find("volcano") or bw:find("lava") then
                return "World 4 (Volcano Caldera)"
            elseif bw:find("1") or bw:find("ocean") or bw:find("starter") or bw:find("main") then
                return "World 1 (Starter Sea)"
            else
                return "World (" .. tostring(bestWorld) .. ")"
            end
        end
    end

    local npc = getActiveSellNPC()
    if npc then
        local pos = npc:GetPivot().Position
        if (pos - Vector3.new(-1226.75, 22, 144.58)).Magnitude < 80 then
            return "World 1 (Starter Sea)"
        elseif (pos - Vector3.new(-1335.45, 20.8, 141.23)).Magnitude < 80 then
            return "World 2 (Desert & Dunes)"
        elseif (pos - Vector3.new(-1325.44, 23.5, 157.35)).Magnitude < 80 then
            return "World 3 (Frostmere & Tundra)"
        elseif (pos - Vector3.new(-1340.18, 20.5, 100.98)).Magnitude < 80 then
            return "World 4 (Volcano Caldera)"
        end
    end

    return "World 1 (Starter Sea)"
end

-- Авто-помещение лучших рыб в пруд
local function putBestFishInPond()
    pcall(function()
        local ev = require(RS.Shared.Events).Client("Pond")
        if ev then
            ev:Fire(true, "Collect")     -- собираем пассивный доход из пруда
            ev:Fire(true, "SellAllDead") -- очищаем погибших если были
            ev:Fire(true, "EquipBest")   -- экипируем лучших рыб из инвентаря
        end
        local btn = LocalPlayer.PlayerGui:FindFirstChild("Interfaces")
            and LocalPlayer.PlayerGui.Interfaces:FindFirstChild("ManagePond")
            and LocalPlayer.PlayerGui.Interfaces.ManagePond.Content.Buttons.Container:FindFirstChild("EquipBest")
        if btn and firesignal then
            firesignal(btn.MouseButton1Click)
        end
    end)
end

-- ==================== 💰 НАДЕЖНАЯ АВТО-ПРОДАЖА (DISTANCE VALIDATION + AUTO-POND) ====================
local isSelling = false
local function sellFishNow()
    if isSelling then return end
    if ThrowCinematicCtrl and (ThrowCinematicCtrl.Active or (ThrowCinematicCtrl.Sub and ThrowCinematicCtrl.Sub.ThrowCamera and ThrowCinematicCtrl.Sub.ThrowCamera.OutroConn)) then
        return -- Не продаем прямо посреди полета поплавка или анимации камеры
    end
    isSelling = true

    task.spawn(function()
        local success, result = pcall(function()
            -- 1. Сначала экипируем лучших рыб в пруд (сохраняет топ рыб)
            if autoPondEnabled then
                putBestFishInPond()
                task.wait(0.2)
            end

            local npc = getActiveSellNPC()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp or not npc then
                return nil
            end

            local oldCF = hrp.CFrame
            local npcPos = npc:GetPivot().Position

            -- Фиксируем камеру, чтобы экран не дергался при мгновенном смещении к NPC
            local cam = workspace.CurrentCamera
            local oldCamType = cam.CameraType
            pcall(function() cam.CameraType = Enum.CameraType.Scriptable end)

            -- Смещаемся к NPC для серверной валидации дистанции
            hrp.CFrame = CFrame.new(npcPos + Vector3.new(0, 2, 2))
            task.wait(0.18)

            local res = nil
            -- Официальный вызов ремоута торговца (требует nil для продажи всей рыбы)
            pcall(function()
                if NpcSellCtrl and NpcSellCtrl.Events and NpcSellCtrl.Events.Client then
                    local ev = NpcSellCtrl.Events.Client("SellAll")
                    if ev then
                        res = ev:Invoke(5, "Fish", nil)
                    end
                end
            end)

            if not res then
                pcall(function()
                    local rf = ReplicatedStorage:FindFirstChild("Events")
                        and ReplicatedStorage.Events:FindFirstChild("RemoteFunctions")
                        and ReplicatedStorage.Events.RemoteFunctions:FindFirstChild("SellAll")
                    if rf then
                        res = rf:InvokeServer(5, "Fish", false)
                    end
                end)
            end

            -- Возвращаемся обратно на место ловли
            hrp.CFrame = oldCF
            task.wait(0.02)
            pcall(function()
                cam.CameraType = Enum.CameraType.Custom
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    cam.CameraSubject = hum
                end
            end)

            return res
        end)

        isSelling = false

        if success and result then
            local count = (type(result) == "table" and (result.Amount or result.Count)) or nil
            local val = (type(result) == "table" and (result.Value or result.Money or result.Price)) or nil
            if count and count > 0 then
                showNotification("💰 Auto-Sell", string.format(locText("Sold: %d fish for %s", "Продано: %d рыб за %s"), count, formatMoney(val or 0)))
            elseif type(result) == "number" and result > 0 then
                showNotification("💰 Auto-Sell", string.format(locText("Revenue: %s", "Выручка: %s"), formatMoney(result)))
            else
                showNotification("💰 Auto-Sell", locText("Fish successfully sold to merchant!", "Рыба успешно продана торговцу!"))
            end
        end
    end)
end

-- ==================== 🏛️ MAZE & DUNGEON AUTOCOMPLETE (SAND & FROST) ====================
local function unlockMazeDoor(mazeType)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    showNotification("Maze Key", "Поиск ворот " .. mazeType .. "...")

    local doorCF = nil
    for _, obj in ipairs(workspace:GetDescendants()) do
        local n = obj.Name:lower()
        if (n:find(mazeType:lower()) or n:find("temple") or n:find("gate") or n:find("door")) and
           (n:find("door") or n:find("gate") or n:find("lock") or n:find("enter")) then
            if obj:IsA("BasePart") then
                doorCF = obj.CFrame
                break
            elseif obj:IsA("Model") and obj.PrimaryPart then
                doorCF = obj.PrimaryPart.CFrame
                break
            end
        end
    end

    if doorCF then
        hrp.CFrame = doorCF + Vector3.new(0, 3, 3)
        task.wait(0.2)
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt") and (p.Parent:GetPivot().Position - hrp.Position).Magnitude < 25 then
                if fireproximityprompt then fireproximityprompt(p) end
            end
        end
        showNotification("Maze Key", "Ворота открыты!")
    else
        showNotification("Maze Key", "Ворота рядом не найдены.")
    end
end

local function autocompleteSandMaze()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    showNotification("Sand Maze", "🏛️ Решение Песчаного Лабиринта (Temple of the Sun)...")

    local goalCF = nil
    local goalPrompt = nil

    -- 1. Динамический поиск алтаря, сундука или финишной зоны
    for _, obj in ipairs(workspace:GetDescendants()) do
        local n = obj.Name:lower()
        if (n:find("sand") or n:find("sun") or n:find("dune") or n:find("temple")) and
           (n:find("altar") or n:find("chest") or n:find("finish") or n:find("end") or n:find("relic") or n:find("reward")) then
            if obj:IsA("BasePart") then
                goalCF = obj.CFrame + Vector3.new(0, 3, 0)
                goalPrompt = obj:FindFirstChildOfClass("ProximityPrompt") or obj.Parent:FindFirstChildOfClass("ProximityPrompt")
                break
            elseif obj:IsA("Model") and obj.PrimaryPart then
                goalCF = obj.PrimaryPart.CFrame + Vector3.new(0, 3, 0)
                goalPrompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                break
            end
        end
    end

    -- 2. Поиск по имени модели
    if not goalCF then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "SunAltar" or obj.Name == "SandAltar" or obj.Name == "SandChest" or obj.Name == "SunChest" then
                if obj:IsA("BasePart") then
                    goalCF = obj.CFrame + Vector3.new(0, 3, 0)
                    goalPrompt = obj:FindFirstChildOfClass("ProximityPrompt")
                    break
                elseif obj:IsA("Model") and obj.PrimaryPart then
                    goalCF = obj.PrimaryPart.CFrame + Vector3.new(0, 3, 0)
                    goalPrompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                    break
                end
            end
        end
    end

    -- 3. Резервные координаты храма солнца (Dunes)
    local finalCF = goalCF or CFrame.new(2450, 45, -1820)
    hrp.CFrame = finalCF
    task.wait(0.3)

    -- Авто-взаимодействие с алтарем / сундуком
    pcall(function()
        if goalPrompt and fireproximityprompt then
            fireproximityprompt(goalPrompt)
        end
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt") and (p.Parent:GetPivot().Position - hrp.Position).Magnitude < 35 then
                if fireproximityprompt then fireproximityprompt(p) end
            end
        end
        local evChest = require(RS.Shared.Events).Client("Chest")
        if evChest then evChest:Fire("OpenAll") end
    end)

    showNotification("Sand Maze", "🏆 Песчаный лабиринт пройден! Награды собраны.")
end

local function autocompleteFrostMaze()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    showNotification("Frost Maze", "❄️ Решение Ледяного Лабиринта (Frozen Caves)...")

    local goalCF = nil
    local goalPrompt = nil

    for _, obj in ipairs(workspace:GetDescendants()) do
        local n = obj.Name:lower()
        if (n:find("frost") or n:find("ice") or n:find("frozen") or n:find("tundra")) and
           (n:find("altar") or n:find("chest") or n:find("finish") or n:find("end") or n:find("relic") or n:find("reward")) then
            if obj:IsA("BasePart") then
                goalCF = obj.CFrame + Vector3.new(0, 3, 0)
                goalPrompt = obj:FindFirstChildOfClass("ProximityPrompt") or obj.Parent:FindFirstChildOfClass("ProximityPrompt")
                break
            elseif obj:IsA("Model") and obj.PrimaryPart then
                goalCF = obj.PrimaryPart.CFrame + Vector3.new(0, 3, 0)
                goalPrompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                break
            end
        end
    end

    if not goalCF then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "IceAltar" or obj.Name == "FrozenAltar" or obj.Name == "IceChest" or obj.Name == "FrostChest" then
                if obj:IsA("BasePart") then
                    goalCF = obj.CFrame + Vector3.new(0, 3, 0)
                    goalPrompt = obj:FindFirstChildOfClass("ProximityPrompt")
                    break
                elseif obj:IsA("Model") and obj.PrimaryPart then
                    goalCF = obj.PrimaryPart.CFrame + Vector3.new(0, 3, 0)
                    goalPrompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                    break
                end
            end
        end
    end

    local finalCF = goalCF or CFrame.new(-3120, -60, 4280)
    hrp.CFrame = finalCF
    task.wait(0.3)

    pcall(function()
        if goalPrompt and fireproximityprompt then
            fireproximityprompt(goalPrompt)
        end
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt") and (p.Parent:GetPivot().Position - hrp.Position).Magnitude < 35 then
                if fireproximityprompt then fireproximityprompt(p) end
            end
        end
        local evChest = require(RS.Shared.Events).Client("Chest")
        if evChest then evChest:Fire("OpenAll") end
    end)

    showNotification("Frost Maze", "🏆 Ледяной лабиринт пройден! Награды собраны.")
end

-- Авто-экипировка удочки
local function equipRod()
    local char = LocalPlayer.Character
    if char and char:FindFirstChildOfClass("Tool") then
        return
    end
    if AutoFishingCtrl and AutoFishingCtrl.EquipRod then
        pcall(function() AutoFishingCtrl:EquipRod() end)
    end
    char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and not (char and char:FindFirstChildOfClass("Tool")) then
        for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if item:IsA("Tool") and item.Name:lower():find("rod") then
                hum:EquipTool(item)
                break
            end
        end
    end
end

-- Покупка улучшений через ремоут
local function buyUpgrade(statName)
    pcall(function()
        local ev = require(RS.Shared.Events).Client("Upgrades")
        if ev and ev.Fire then
            ev:Fire("Buy", statName)
        end
    end)
end

-- ==================== 🚶 FREE MOVEMENT & UNFREEZE WATCHDOG ====================
local function unfreezeCharacter()
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")

        -- 1. Снимаем Anchored со всех частей персонажа
        if hrp and hrp.Anchored and not (waterPlatform and waterPlatform.Parent and math.abs(hrp.Position.Y - waterPlatform.Position.Y) < 4) then
            hrp.Anchored = false
        end
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") and part.Anchored and part ~= waterPlatform then
                part.Anchored = false
            end
        end

        -- 2. Восстанавливаем WalkSpeed и состояние гуманоида
        if hum then
            if hum.WalkSpeed <= 0 then
                hum.WalkSpeed = (currentWalkSpeed and currentWalkSpeed > 0) and currentWalkSpeed or 16
            end
            if hum.PlatformStand then
                hum.PlatformStand = false
            end
            if hum.Sit and not (char:FindFirstChildOfClass("VehicleSeat") or (char.Parent and char.Parent:FindFirstChildOfClass("VehicleSeat"))) then
                hum.Sit = false
            end
        end

        -- 3. Восстанавливаем PlayerModule Controls (WASD)
        local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
        local playerModuleObj = playerScripts and playerScripts:FindFirstChild("PlayerModule")
        if playerModuleObj then
            local PlayerModule = require(playerModuleObj)
            local Controls = PlayerModule and PlayerModule:GetControls()
            if Controls and Controls.Enable then
                Controls:Enable()
            end
        end

        -- 4. Восстанавливаем камеру если она застряла в Scriptable
        local cam = workspace.CurrentCamera
        if cam and cam.CameraType == Enum.CameraType.Scriptable and hum then
            cam.CameraType = Enum.CameraType.Custom
            cam.CameraSubject = hum
        end

        -- 5. Если застряла мини-игра босса или висит рыба, принудительно завершаем победой и забираем рыбу
        if CatchMinigameCtrl and CatchMinigameCtrl.Fight then
            local fight = CatchMinigameCtrl.Fight
            fight.made = math.max(fight.made or 0, fight.required or 30)
            fight.progress = 1
            pcall(function() CatchMinigameCtrl:Finish(true) end)
        end
        if ThrowCinematicCtrl then
            if ThrowCinematicCtrl.Active and not ThrowCinematicCtrl.ReelRequested then
                pcall(function() ThrowCinematicCtrl:RequestReel() end)
            end
            pcall(function()
                if ThrowCinematicCtrl.Cleanup then
                    ThrowCinematicCtrl:Cleanup()
                end
            end)
            ThrowCinematicCtrl.Active = false
            ThrowCinematicCtrl.Catchable = false
        end
        if FishSchoolCtrl then
            pcall(function()
                if FishSchoolCtrl.Despawn then
                    FishSchoolCtrl:Despawn()
                end
            end)
        end
    end)
end

-- Перехватываем попытки игры заглушить WASD управление
pcall(function()
    local playerScripts = LocalPlayer:WaitForChild("PlayerScripts", 5)
    local playerModuleObj = playerScripts and playerScripts:FindFirstChild("PlayerModule")
    if playerModuleObj then
        local PlayerModule = require(playerModuleObj)
        local Controls = PlayerModule and PlayerModule:GetControls()
        if Controls then
            Controls:Enable()
            if not Controls._fishyHooked then
                Controls._fishyHooked = true
                local oldDisable = Controls.Disable
                Controls.Disable = function(self, ...)
                    if freeWalkEnabled then
                        return -- Не даем игре выключать управление во время заброса!
                    end
                    return oldDisable(self, ...)
                end
            end
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    unfreezeCharacter()
end)

-- Мгновенная разморозка при старте скрипта
task.defer(unfreezeCharacter)

-- ==================== SMART ENTITY SCORING (FISH + ITEMS) ====================
local function getEntityScore(f, mode)
    local name = f.name or (f.model and f.model.Name) or (f.data and f.data.Name) or f.findName or ""
    local lower = name:lower()
    
    -- 1. Особые предметы, фрагменты (Lava/Sand/Frozen), ключи, свитки, сундуки, камни и реликвии
    local isSpecialItem = false
    local itemType = "Special"
    
    if f.bypassRoom or f.special or f.isItem or f.Kind == "Fragment" or f.kind == "Fragment" or f.findRarity == "Special" then
        isSpecialItem = true
        itemType = f.Kind or f.kind or "Special"
    elseif KeyConfig and KeyConfig.Items and KeyConfig.Items[name] then
        isSpecialItem = true
        itemType = "Key/Fragment"
    elseif ScrollConfig and ScrollConfig.Items and ScrollConfig.Items[name] then
        isSpecialItem = true
        itemType = "Scroll"
    elseif SummonConfig and SummonConfig.Items and SummonConfig.Items[name] then
        isSpecialItem = true
        itemType = "Summon"
    elseif CageConfig and CageConfig.Items and CageConfig.Items[name] then
        isSpecialItem = true
        itemType = "Cage"
    elseif ChestConfig and ChestConfig.Items and ChestConfig.Items[name] then
        isSpecialItem = true
        itemType = "Chest"
    else
        if lower:find("fragment") or lower:find("key") or lower:find("scroll") 
           or lower:find("stone") or lower:find("crown") or lower:find("chest") 
           or lower:find("bottle") or lower:find("relic") or lower:find("cage") 
           or lower:find("trap") or lower:find("heart") or lower:find("lucky")
           or lower:find("lava") or lower:find("sand") or lower:find("frozen")
           or lower:find("orb") or lower:find("pearl") or lower:find("coin")
           or lower:find("gem") or lower:find("crystal") or lower:find("fossil")
           or lower:find("totem") or lower:find("skull") or lower:find("egg")
           or lower:find("ancient") or lower:find("runic") or lower:find("enchant") then
            isSpecialItem = true
            itemType = "Special"
        end
    end
    
    if isSpecialItem or f.bypassRoom then
        local info = {
            name = (name ~= "" and name) or "Special Item",
            rarity = "Special",
            order = 10,
            price = 100000,
            isBoss = false,
            isSecret = true,
            isSpecial = true,
            isItem = true,
            itemType = itemType
        }
        -- Абсолютный наивысший приоритет (100M): фрагменты и предметы ловятся первыми всегда!
        return 100000000, info
    end
    
    -- 2. Мусор
    local isJunk = false
    if JunkConfig and JunkConfig.Items and JunkConfig.Items[name] then
        isJunk = true
    else
        if lower:find("boot") or lower:find("sneaker") or lower:find("tire") or lower:find("can") or lower:find("bucket") then
            isJunk = true
        end
    end
    
    if isJunk then
        local info = {
            name = name,
            rarity = "Junk",
            order = 0,
            price = 50,
            isBoss = false,
            isSecret = false,
            isJunk = true
        }
        if collectItemsEnabled then
            return 5000, info
        else
            return 0, info
        end
    end
    
    -- 3. Обычная рыба
    local cfg = FishConfig:Get(name, true) or {}
    local rarity = cfg.Rarity or "Common"
    local rInfo = RarityConfig.Get(rarity)
    local order = rInfo and rInfo.Order or 1
    local price = cfg.SellPrice or 10
    local odds = cfg.RollOdds or 1
    local size = (f.model and f.model.PrimaryPart and f.model.PrimaryPart.Size.Magnitude) or (f.size or 1)
    
    local isBoss = f.boss == true
    local isSecret = (rarity == "Secret" or rarity == "Exotic" or order >= 7)
    local isMutation = f.mutation ~= nil
    
    local info = {
        name = name,
        rarity = rarity,
        order = order,
        price = price,
        isBoss = isBoss,
        isSecret = isSecret,
        mutation = f.mutation
    }
    
    if mode == "Secret" then
        if isBoss or isSecret then
            return 15000000 + order * 100000 + price, info
        else
            return 0, info
        end
    elseif mode == "Rarest" then
        local score = order * 1000000 + odds
        if isBoss then score = score + 5000000 end
        if isMutation then score = score + 500000 end
        return score, info
    elseif mode == "Money" then
        local mult = isMutation and 2.5 or 1.0
        if isBoss then mult = mult * 5 end
        return price * mult * size, info
    elseif mode == "Biggest" then
        return size, info
    else -- "Any"
        return 1, info
    end
end

-- ==================== FULL CAPACITY MULTI-GRAB & ITEM COLLECTOR ====================
local function grabAllEntities(school)
    if not (instantCatchEnabled and school and school.Fish and #school.Fish > 0 and school.Cinematic and school.Cinematic.Catchable) then
        return
    end
    
    local maxCap = school.Cinematic:GetBaitCapacity()
    local currentCaught = school.Cinematic:CaughtFishCount()
    local slotsFree = math.max(0, maxCap - currentCaught)
    
    -- ПАСС 1: Забираем ВСЕ специальные предметы и фрагменты (Lava/Sand/Frozen, ключи, сундуки). Они bypassRoom и не тратят вместимость!
    for _, f in ipairs(school.Fish) do
        if not f.caught and not f.escaped and not f.fighting and f.model and f.model.Parent then
            local score, info = getEntityScore(f, catchMode)
            if info.isSpecial or f.bypassRoom then
                if not (school.Cinematic.Sub and school.Cinematic.Sub.CatchMinigame and school.Cinematic.Sub.CatchMinigame:Offer(f)) then
                    school:CompleteGrab(f)
                end
            end
        end
    end
    
    -- ПАСС 2: Забиваем оставшиеся слоты рыбой по выбранному моду
    if slotsFree > 0 then
        local candidates = {}
        for _, f in ipairs(school.Fish) do
            if not f.caught and not f.escaped and not f.fighting and f.model and f.model.Parent then
                local score, info = getEntityScore(f, catchMode)
                if not (info.isSpecial or f.bypassRoom) then
                    table.insert(candidates, { fish = f, score = score, info = info })
                end
            end
        end
        
        table.sort(candidates, function(a, b) return a.score > b.score end)
        
        for _, cand in ipairs(candidates) do
            if slotsFree <= 0 then break end
            if catchMode == "Secret" and cand.score <= 0 and not fallbackToBest then break end
            
            slotsFree = slotsFree - 1
            if not (school.Cinematic.Sub and school.Cinematic.Sub.CatchMinigame and school.Cinematic.Sub.CatchMinigame:Offer(cand.fish)) then
                school:CompleteGrab(cand.fish)
            end
        end
    end
end

if FishSchoolCtrl then
    FishSchoolCtrl._rawTryGrab = FishSchoolCtrl._rawTryGrab or FishSchoolCtrl.TryGrab
    local rawTryGrab = FishSchoolCtrl._rawTryGrab
    
    FishSchoolCtrl.TryGrab = function(self, point)
        if instantCatchEnabled and self.Fish and #self.Fish > 0 and self.Cinematic and self.Cinematic.Catchable then
            grabAllEntities(self)
            return
        end
        return rawTryGrab(self, point)
    end
end

-- ==================== PREDICTED LANDING MARKER НА ПОЛОСКЕ ====================
-- Рассчитывает точную точку приземления по заспавненной рыбе и формуле DistanceScale игры
local function updateLandingHUD(hudInstance, totalDist)
    local content = hudInstance and hudInstance.DistanceContent
    if not content then return end
    
    -- Очистка старых маркеров
    local legacy = content:FindFirstChild("PredictedLanding")
    if legacy then legacy:Destroy() end
    
    local playersFrame = content:FindFirstChild("Players")
    if not playersFrame then return end
    local you = playersFrame:FindFirstChild("You")
    if not you then return end
    
    local target = playersFrame:FindFirstChild("PredictedTarget")
    if not landingPredictorEnabled then
        if target then target.Visible = false end
        return
    end
    
    -- 1. Вычисляем дистанцию прямо по позиции заспавненной рыбы / активного лендинга
    local landingPos = (FishSchoolCtrl and FishSchoolCtrl.SpawnCtx and FishSchoolCtrl.SpawnCtx.landing)
        or (ThrowCinematicCtrl and ThrowCinematicCtrl.ActiveLanding)
    local origin = ThrowCinematicCtrl and ThrowCinematicCtrl.ThrowOrigin
    
    local calcDist = nil
    if landingPos and origin then
        calcDist = ((landingPos - origin) * Vector3.new(1, 0, 1)).Magnitude
    elseif ThrowCinematicCtrl and ThrowCinematicCtrl.ThrowDistance and ThrowCinematicCtrl.ThrowDistance > 0 then
        calcDist = ThrowCinematicCtrl.ThrowDistance
    elseif totalDist and totalDist > 0 then
        calcDist = totalDist
    end
    
    if not calcDist or calcDist <= 0 then
        if target then target.Visible = false end
        return
    end
    
    -- 2. Точный расчет позиции на шкале по внутренней математике SetDistance:
    local record = hudInstance.RecordToBeat or 0
    local finalRatio
    if record > 0 then
        if calcDist > record then
            finalRatio = 0.92 -- При новом рекорде игра динамически держит финиш на 0.92
        else
            finalRatio = math.clamp(calcDist / (record / 0.85), 0, 1)
        end
    else
        finalRatio = 1.0
    end
    
    -- 3. Находим лучшую заспавненную рыбу / предмет в точке приземления
    local bestFishName = nil
    local bestRarity = nil
    local bestScore = -1
    local totalSpawned = 0
    
    if FishSchoolCtrl and FishSchoolCtrl.Fish and #FishSchoolCtrl.Fish > 0 then
        totalSpawned = #FishSchoolCtrl.Fish
        for _, f in ipairs(FishSchoolCtrl.Fish) do
            local score, info = getEntityScore(f, catchMode)
            if score > bestScore then
                bestScore = score
                bestFishName = info.name
                bestRarity = info.rarity
                if info.mutation then
                    bestFishName = "[" .. info.mutation .. "] " .. bestFishName
                end
            end
        end
    end
    
    -- 4. Создаем или позиционируем маркер цели
    if not target then
        target = Instance.new("Frame")
        target.Name = "PredictedTarget"
        target.AnchorPoint = Vector2.new(0.5, 0.5)
        target.Size = you.Size
        target.BackgroundColor3 = Color3.fromRGB(0, 25, 45)
        target.BackgroundTransparency = 0.25
        target.ZIndex = math.max(you.ZIndex - 1, 1)
        Instance.new("UICorner", target).CornerRadius = UDim.new(1, 0)
        
        local stroke = Instance.new("UIStroke", target)
        stroke.Color = Color3.fromRGB(0, 255, 255)
        stroke.Thickness = 2
        
        local icon = Instance.new("TextLabel", target)
        icon.Name = "Icon"
        icon.Size = UDim2.new(1, 0, 1, 0)
        icon.BackgroundTransparency = 1
        icon.Text = "🎯"
        icon.TextSize = 13
        icon.Font = Enum.Font.GothamBold
        
        local tag = Instance.new("TextLabel", target)
        tag.Name = "DistanceTag"
        tag.Size = UDim2.new(0, 130, 0, 16)
        tag.AnchorPoint = Vector2.new(0.5, 0)
        tag.Position = UDim2.new(0.5, 0, 1, 3)
        tag.BackgroundColor3 = Color3.fromRGB(5, 15, 25)
        tag.BackgroundTransparency = 0.25
        Instance.new("UICorner", tag).CornerRadius = UDim.new(0, 4)
        local tagStroke = Instance.new("UIStroke", tag)
        tagStroke.Color = Color3.fromRGB(0, 255, 255)
        tagStroke.Thickness = 1
        tag.TextColor3 = Color3.fromRGB(0, 255, 255)
        tag.Font = Enum.Font.GothamBold
        tag.TextSize = 10
        
        target.Parent = playersFrame
    end
    
    target.Position = UDim2.new(finalRatio, 0, you.Position.Y.Scale, 0)
    target.Visible = true
    
    local tag = target:FindFirstChild("DistanceTag")
    if tag then
        local distText = string.format("🎯 %dm", math.floor(calcDist + 0.5))
        if bestFishName and totalSpawned > 0 then
            tag.Size = UDim2.new(0, 150, 0, 16)
            tag.Text = string.format("%s | %s", distText, bestFishName)
            if bestRarity and rarityColors[bestRarity] then
                tag.TextColor3 = rarityColors[bestRarity]
            end
        else
            tag.Size = UDim2.new(0, 75, 0, 16)
            tag.Text = distText
            tag.TextColor3 = Color3.fromRGB(0, 255, 255)
        end
    end
end

-- Хуки на HUD и спавн рыбы для мгновенного отображения лендинга
pcall(function()
    local Displays = require(RS.Shared.UI.HUD.Fishing.Displays)
    if Displays then
        Displays._rawSetDist = Displays._rawSetDist or Displays.SetDistance
        local rawSetDist = Displays._rawSetDist
        Displays.SetDistance = function(self, currentDist, totalDist)
            rawSetDist(self, currentDist, totalDist)
            updateLandingHUD(self, totalDist)
        end
        
        Displays._rawHide = Displays._rawHide or Displays.HideThrowDisplays
        local rawHide = Displays._rawHide
        Displays.HideThrowDisplays = function(self)
            if self.DistanceContent and self.DistanceContent:FindFirstChild("Players") then
                local target = self.DistanceContent.Players:FindFirstChild("PredictedTarget")
                if target then target.Visible = false end
            end
            return rawHide(self)
        end
    end
end)

-- Мгновенный вызов при спавне рыбы
if FishSchoolCtrl then
    FishSchoolCtrl._rawSpawn = FishSchoolCtrl._rawSpawn or FishSchoolCtrl.Spawn
    local rawSpawn = FishSchoolCtrl._rawSpawn
    FishSchoolCtrl.Spawn = function(self, a2)
        rawSpawn(self, a2)
        task.defer(function()
            local d = RS.Shared.UI.HUD.Fishing:FindFirstChild("Displays") and require(RS.Shared.UI.HUD.Fishing.Displays)
            if d then
                updateLandingHUD(d, ThrowCinematicCtrl and ThrowCinematicCtrl.ThrowDistance)
            end
        end)
    end
end

-- Защита от сброса авто-рыбалки при телепорте на продажу
if FishingCtrl then
    FishingCtrl._rawInArea = FishingCtrl._rawInArea or FishingCtrl.InArea
    local rawInArea = FishingCtrl._rawInArea
    FishingCtrl.InArea = function(self)
        if isSelling then return true end
        return rawInArea(self)
    end
end

if AutoFishingCtrl then
    AutoFishingCtrl._rawSetOn = AutoFishingCtrl._rawSetOn or AutoFishingCtrl.SetOn
    local rawSetOn = AutoFishingCtrl._rawSetOn
    AutoFishingCtrl.SetOn = function(self, val)
        if isSelling and val == false then
            return -- блокируем отключение во время продажи
        end
        return rawSetOn(self, val)
    end
end

-- Хук на завершение вылова заброса: подсчет заработка, уведомление, авто-пруд и авто-продажа
if FishSchoolCtrl then
    FishSchoolCtrl._rawTakeCaught = FishSchoolCtrl._rawTakeCaught or FishSchoolCtrl.TakeCaught
    local rawTakeCaught = FishSchoolCtrl._rawTakeCaught
    FishSchoolCtrl.TakeCaught = function(self)
        local caught = rawTakeCaught(self)
        if caught and #caught > 0 then
            local totalValue = 0
            local count = #caught
            local bestName = nil
            local bestVal = -1
            
            for _, f in ipairs(caught) do
                local val = 0
                local itemData = {
                    Type = "Fish",
                    Name = f.name,
                    Data = {
                        Mutation = f.mutation,
                        Size = f.size or 1
                    }
                }
                pcall(function()
                    if NpcSellCtrl and NpcSellCtrl.Services and NpcSellCtrl.Services.Item then
                        val = NpcSellCtrl.Services.Item:GetSellValue(LocalPlayer, itemData) or 0
                    end
                end)
                if val <= 0 then
                    local cfg = FishConfig:Get(f.name, true)
                    val = (cfg and cfg.SellPrice) or 50
                    if f.mutation then val = val * 2.5 end
                end
                
                totalValue = totalValue + val
                if val > bestVal then
                    bestVal = val
                    bestName = (f.mutation and ("[" .. f.mutation .. "] ") or "") .. f.name
                end
            end
            
            sessionFishCaught = sessionFishCaught + count
            sessionMoneyEarned = sessionMoneyEarned + totalValue
            if updateStatsHud then updateStatsHud() end

            if notifyCatchValue then
                local bestTxt = bestName and (locText(" | Best: ", " | Топ: ") .. bestName) or ""
                showNotification(
                    locText("🎣 Cast Complete!", "🎣 Заброс завершён!"),
                    string.format(locText("Caught: %d fish | Revenue: %s%s", "Поймано: %d шт. | Выручка: %s%s"), count, formatMoney(totalValue), bestTxt)
                )
            end
            
            -- Ждем завершения анимаций сбора рыбы и синематика заброса
            task.spawn(function()
                local t0 = os.clock()
                while ThrowCinematicCtrl and ThrowCinematicCtrl.Active and (os.clock() - t0 < 0.8) do
                    task.wait(0.05)
                end
                
                -- Очищаем зависшие 3D-модели рыбы с пирса
                if ThrowCinematicCtrl and ThrowCinematicCtrl.Active then
                    pcall(function()
                        if ThrowCinematicCtrl.Cleanup then
                            ThrowCinematicCtrl:Cleanup()
                        end
                    end)
                    ThrowCinematicCtrl.Active = false
                end
                if FishSchoolCtrl and FishSchoolCtrl.Despawn then
                    pcall(function() FishSchoolCtrl:Despawn() end)
                end
                unfreezeCharacter()

                task.wait(0.2)
                if autoPondEnabled then
                    putBestFishInPond()
                end
                task.wait(0.4) -- Даем серверу время обработать EquipBest в пруд перед продажей!
                if autoSellEnabled then
                    sellFishNow()
                end
            end)
        end
        return caught
    end
end

-- ==================== ⚡ ZERO FLIGHT TIME & INSTANT PULL ANIMATION SKIP ====================
if ThrowCinematicCtrl then
    ThrowCinematicCtrl._rawOnServerStarted = ThrowCinematicCtrl._rawOnServerStarted or ThrowCinematicCtrl.OnServerStarted
    local rawOnServerStarted = ThrowCinematicCtrl._rawOnServerStarted
    ThrowCinematicCtrl.OnServerStarted = function(self, a2, ...)
        if fastArcEnabled and type(a2) == "table" then
            a2.arcDuration = 0.05
            if a2.bounces then
                for _, b in ipairs(a2.bounces) do
                    b.duration = 0.02
                    b.Duration = 0.02
                end
            end
        end
        return rawOnServerStarted(self, a2, ...)
    end

    ThrowCinematicCtrl._rawBeginFlight = ThrowCinematicCtrl._rawBeginFlight or ThrowCinematicCtrl.BeginFlight
    local rawBeginFlight = ThrowCinematicCtrl._rawBeginFlight
    ThrowCinematicCtrl.BeginFlight = function(self, ...)
        rawBeginFlight(self, ...)
        if fastArcEnabled then
            self.ArcDuration = 0.05
            if self.BounceList then
                for _, b in ipairs(self.BounceList) do
                    b.duration = 0.02
                    b.Duration = 0.02
                end
            end
        end
    end
end

-- 1. Hook Auto Perfect (100% Guaranteed Perfect Throw)
if FishingCtrl then
    FishingCtrl._rawStopHook = FishingCtrl._rawStopHook or FishingCtrl.StopHook
    local rawStopHook = FishingCtrl._rawStopHook
    FishingCtrl.StopHook = function(self)
        if autoPerfectEnabled and self.Charging then
            local hud = self:HUD()
            if hud and hud.GetHookSteps then
                local steps = hud:GetHookSteps()
                if steps and steps >= 2 then
                    self.HookT = 9.5 / (steps - 1)
                    self.ThrowTier = "Perfect"
                end
            end
        end
        return rawStopHook(self)
    end
end

-- 2. Hook AutoFishing & Turbo Cast
if AutoFishingCtrl then
    AutoFishingCtrl.OwnsAutoSell = function() return true end

    AutoFishingCtrl.DriveCast = function(self, fishing)
        if isSelling or (ThrowCinematicCtrl and ThrowCinematicCtrl.Active) then
            return
        end
        self.DrivingThrow = true
        equipRod()
        fishing:StartHook()
        if not fishing.Charging then
            self.DrivingThrow = false
            return
        end
        if turboCastEnabled then
            task.wait(0.06)
        else
            task.wait(0.8)
        end
        if autoPerfectEnabled then
            local steps = fishing:HUD():GetHookSteps()
            if steps and steps >= 2 then
                fishing.HookT = 9.5 / (steps - 1)
                fishing.ThrowTier = "Perfect"
            end
        end
        fishing:StopHook()
        self.DrivingThrow = false
    end

    -- Мгновенный турбо-заброс: убирает 2.5-секундную паузу между забросами
    task.spawn(function()
        while true do
            task.wait(0.05)
            if getgenv()._FishyHubToken ~= myHubToken then break end
            
            -- Авто-заброс работает ТОЛЬКО когда пользователь включил авто-рыбалку (и в игре, и в UI)
            local isAutoActive = autoFishEnabled and (AutoFishingCtrl and AutoFishingCtrl.On)
            if isAutoActive and not isSelling then
                if not (ThrowCinematicCtrl and ThrowCinematicCtrl.Active) then
                    equipRod()
                    if FishingCtrl and FishingCtrl:CanStartThrow() and not FishingCtrl.Charging then
                        AutoFishingCtrl:DriveCast(FishingCtrl)
                    end
                end
            end
        end
    end)

    AutoFishingCtrl.WarnFull = function(self)
        if autoSellEnabled then
            sellFishNow()
        end
    end

    AutoFishingCtrl.Boost = function(self)
        return true
    end

    AutoFishingCtrl.BoostedHookT = function(self, fishing, boost)
        if autoPerfectEnabled then
            local steps = fishing:HUD():GetHookSteps()
            if steps and steps >= 2 then
                return 9.5 / (steps - 1)
            end
        end
        return 0.5
    end
end

-- 3. Hook CatchMinigame (Instant Auto-Win Secret / Boss)
if CatchMinigameCtrl then
    CatchMinigameCtrl._rawBegin = CatchMinigameCtrl._rawBegin or CatchMinigameCtrl.Begin
    local rawBegin = CatchMinigameCtrl._rawBegin

    CatchMinigameCtrl.Begin = function(self, fish, boss)
        rawBegin(self, fish, boss)
        if autoFightEnabled and self.Fight then
            local fishName = (fish and (fish.name or fish.Name)) or "Boss / Secret Fish"
            showNotification("🌟 Auto-Win Boss!", "Ловим: " .. tostring(fishName))
            task.defer(function()
                task.wait(0.02)
                if self.Fight then
                    self.Fight.made = math.max(self.Fight.made or 0, self.Fight.required or 30)
                    self.Fight.progress = 1
                    pcall(function() self:Finish(true) end)
                end
            end)
        end
    end
end

-- 4. Heartbeat Loop: Full-Capacity Fast Reel, Entity Collector & Animation Skip
RunService.Heartbeat:Connect(function()
    -- Safety solver for active minigame (мгновенная победа из бекапа)
    if autoFightEnabled and CatchMinigameCtrl and CatchMinigameCtrl.Fight then
        local fight = CatchMinigameCtrl.Fight
        fight.made = math.max(fight.made or 0, fight.required or 30)
        fight.progress = 1
        pcall(function() CatchMinigameCtrl:Finish(true) end)
    end

    -- Активный сбор предметов и рыбы прямо в Heartbeat пока наживка в воде
    if instantCatchEnabled and ThrowCinematicCtrl and ThrowCinematicCtrl.Active and ThrowCinematicCtrl.Catchable and FishSchoolCtrl then
        grabAllEntities(FishSchoolCtrl)
    end

    -- 🌊 Быстрое погружение на дно (Fast Dive)
    if fastDiveEnabled and ThrowCinematicCtrl and ThrowCinematicCtrl.Active then
        ThrowCinematicCtrl.DiveDuration = 0.12
    end

    -- 🚶 Свободный ход во время и после заброса (Анти-заморозка)
    if freeWalkEnabled then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hrp and hrp.Anchored and not (waterPlatform and waterPlatform.Parent and math.abs(hrp.Position.Y - waterPlatform.Position.Y) < 4) then
            hrp.Anchored = false
        end
        if hum then
            if hum.WalkSpeed <= 0 then
                hum.WalkSpeed = (currentWalkSpeed and currentWalkSpeed > 0) and currentWalkSpeed or 16
            end
            if hum.PlatformStand then
                hum.PlatformStand = false
            end
        end
    end

    -- 🌊 Walk On Water (Хождение по воде без плавания)
    if waterWalkEnabled and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hrp and hum then
            if hum:GetState() == Enum.HumanoidStateType.Swimming then
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
            if not waterPlatform or not waterPlatform.Parent then
                waterPlatform = Instance.new("Part")
                waterPlatform.Name = "FishyWaterWalk"
                waterPlatform.Size = Vector3.new(12, 1, 12)
                waterPlatform.Transparency = 1
                waterPlatform.Anchored = true
                waterPlatform.CanCollide = true
                waterPlatform.Parent = workspace
            end
            local targetY = math.max(16.5, hrp.Position.Y - 3.1)
            waterPlatform.CFrame = CFrame.new(hrp.Position.X, targetY, hrp.Position.Z)
        end
    elseif not waterWalkEnabled and waterPlatform then
        pcall(function() waterPlatform:Destroy() end)
        waterPlatform = nil
    end

    -- 🚀 Fly Mode (Плавный полёт)
    if flyEnabled and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        local cam = workspace.CurrentCamera
        if hrp and hum and cam then
            if not flyBodyVelocity or not flyBodyVelocity.Parent then
                flyBodyGyro = Instance.new("BodyGyro")
                flyBodyGyro.P = 9e4
                flyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                flyBodyGyro.CFrame = cam.CFrame
                flyBodyGyro.Parent = hrp

                flyBodyVelocity = Instance.new("BodyVelocity")
                flyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                flyBodyVelocity.Velocity = Vector3.zero
                flyBodyVelocity.Parent = hrp
            end

            flyBodyGyro.CFrame = cam.CFrame
            local move = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, 1, 0) end

            if move.Magnitude > 0 then
                flyBodyVelocity.Velocity = move.Unit * flySpeed
            else
                flyBodyVelocity.Velocity = Vector3.zero
            end
        end
    elseif not flyEnabled then
        if flyBodyVelocity then pcall(function() flyBodyVelocity:Destroy() end) flyBodyVelocity = nil end
        if flyBodyGyro then pcall(function() flyBodyGyro:Destroy() end) flyBodyGyro = nil end
    end

    -- Fast Reel: подсекаем когда забиты слоты или вся рыба в косяке поймана (из бекапа)
    if instantReelEnabled and ThrowCinematicCtrl and ThrowCinematicCtrl.Active and not ThrowCinematicCtrl.ReelRequested then
        local cap = ThrowCinematicCtrl:GetBaitCapacity()
        local caught = ThrowCinematicCtrl:CaughtFishCount()
        local spawned = (FishSchoolCtrl and FishSchoolCtrl.Fish and #FishSchoolCtrl.Fish) or 0
        
        if caught >= cap or (caught > 0 and spawned <= caught) then
            pcall(function() ThrowCinematicCtrl:RequestReel() end)
        end
    end
end)

-- 5. Auto Sell & Auto Upgrade Background Loop
task.spawn(function()
    while true do
        task.wait(autoSellInterval)
        if getgenv()._FishyHubToken ~= myHubToken then break end
        if autoSellEnabled then
            sellFishNow()
        end
        if autoUpgradeCapacity or autoUpgradeAll then
            buyUpgrade("Capacity")
        end
        if autoUpgradeAll then
            buyUpgrade("Strength")
            buyUpgrade("Weight")
            buyUpgrade("Bounce")
        end
    end
end)

-- 6. Noclip Loop
RunService.Stepped:Connect(function()
    if noclipEnabled and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

-- 7. Fish & Items ESP 2.0 (BillboardGui + Highlights)
local function createEntityBillboard(model, info)
    local pp = model.PrimaryPart
    if not pp then return end
    
    local bg = model:FindFirstChild("FishInfoTag")
    if not bg then
        bg = Instance.new("BillboardGui")
        bg.Name = "FishInfoTag"
        bg.Adornee = pp
        bg.Size = UDim2.new(0, 140, 0, 45)
        bg.StudsOffset = Vector3.new(0, 2.5, 0)
        bg.AlwaysOnTop = true
        
        local frame = Instance.new("Frame", bg)
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundColor3 = Color3.fromRGB(10, 20, 30)
        frame.BackgroundTransparency = 0.35
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
        
        local nameLabel = Instance.new("TextLabel", frame)
        nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = rarityColors[info.rarity] or Color3.fromRGB(255, 255, 255)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 13
        nameLabel.Text = (info.mutation and ("[" .. info.mutation .. "] ") or "") .. info.name
        
        local priceLabel = Instance.new("TextLabel", frame)
        priceLabel.Size = UDim2.new(1, 0, 0.5, 0)
        priceLabel.Position = UDim2.new(0, 0, 0.5, 0)
        priceLabel.BackgroundTransparency = 1
        priceLabel.TextColor3 = info.isChest and Color3.fromRGB(255, 220, 0) or Color3.fromRGB(100, 255, 120)
        priceLabel.Font = Enum.Font.GothamMedium
        priceLabel.TextSize = 11
        priceLabel.Text = info.rarity .. " | $" .. tostring(info.price)
        
        bg.Parent = model
    end
end

RunService.RenderStepped:Connect(function()
    -- Watchdog камеры: если вне синематика и продажи камера застряла в Scriptable, возвращаем игроку в Custom
    if not isSelling and not (ThrowCinematicCtrl and ThrowCinematicCtrl.Active) and not (CatchMinigameCtrl and CatchMinigameCtrl.Fight) then
        local cam = workspace.CurrentCamera
        if cam then
            if cam.CameraType ~= Enum.CameraType.Custom then
                cam.CameraType = Enum.CameraType.Custom
            end
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and cam.CameraSubject ~= hum then
                cam.CameraSubject = hum
            end
        end
    end

    -- Отрисовка ESP ТОЛЬКО для активных (не пойманных) рыб в воде
    if FishSchoolCtrl and FishSchoolCtrl.Fish then
        for _, f in ipairs(FishSchoolCtrl.Fish) do
            if f.model and f.model.Parent then
                if f.caught or f.taken then
                    -- Рыба уже поймана: удаляем теги и подсветки чтобы не загромождать игрока
                    local tag = f.model:FindFirstChild("FishInfoTag")
                    if tag then tag:Destroy() end
                    local hl = f.model:FindFirstChild("FishESP")
                    if hl then hl:Destroy() end
                elseif fishEspEnabled and f.model.PrimaryPart then
                    local _, info = getEntityScore(f, "Rarest")
                    
                    local hl = f.model:FindFirstChild("FishESP")
                    if not hl then
                        hl = Instance.new("Highlight")
                        hl.Name = "FishESP"
                        hl.Adornee = f.model
                        hl.FillColor = rarityColors[info.rarity] or Color3.fromRGB(0, 240, 255)
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        hl.FillTransparency = 0.35
                        hl.OutlineTransparency = 0
                        hl.Parent = f.model
                    end
                    
                    if espLabelsEnabled then
                        createEntityBillboard(f.model, info)
                    end
                else
                    local tag = f.model:FindFirstChild("FishInfoTag")
                    if tag then tag:Destroy() end
                    local hl = f.model:FindFirstChild("FishESP")
                    if hl then hl:Destroy() end
                end
            end
        end
    end
end)

-- ==================== MODERN WINDUI GUI SETUP (9 TABS) ====================

-- 1. 🎣 TAB: FISHING
local TabFishing = Window:Tab({
    Title = "Fishing",
    Icon = "fish-symbol"
})

TabFishing:Section({ Title = "Live AFK Farm Statistics" })

statsParagraph = TabFishing:Paragraph({
    Title = "Session Performance",
    Desc = "Поймано: 0 шт. | Выручка: $0\nMoney / Min: $0/m | Money / Hour: $0/h\nВремя сессии: 00:00:00 | Темп: 0.0 рыб/мин"
})

TabFishing:Button({
    Title = "🔄 Refresh Session Statistics",
    Desc = "Recalculate fish count, revenue, and AFK farm rates",
    Icon = "activity",
    Callback = function()
        updateStatsHud()
        showNotification("Stats", string.format(locText("Caught: %d | Revenue: %s", "Выловлено: %d шт. | Доход: %s"), sessionFishCaught, formatMoney(sessionMoneyEarned)))
    end
})

TabFishing:Toggle({
    Title = "Show On-Screen AFK HUD",
    Desc = "Display floating session statistics HUD on screen",
    Value = hudEnabled,
    Callback = function(state)
        hudEnabled = state
        if statsHudGui then
            statsHudGui.Enabled = state
        end
        showNotification("HUD", state and locText("On-screen HUD enabled!", "Экранный виджет включен!") or locText("On-screen HUD hidden", "Экранный виджет скрыт"))
    end
})

TabFishing:Section({ Title = "Auto-Fishing & Speed Hacks" })

TabFishing:Toggle({
    Title = "Enable Auto Fish (AFK Farm)",
    Desc = "Автоматический заброс и вылов без остановок",
    Value = autoFishEnabled,
    Callback = function(state)
        autoFishEnabled = state
        if AutoFishingCtrl then
            if state then
                equipRod()
                AutoFishingCtrl:SetOn(true)
            else
                AutoFishingCtrl:SetOn(false)
            end
        end
    end
})

TabFishing:Toggle({
    Title = "Fast Arc Skip (Zero Flight Time)",
    Desc = "Мгновенный перелёт поплавка в воду (0.02с)",
    Value = fastArcEnabled,
    Callback = function(state) fastArcEnabled = state end
})

TabFishing:Toggle({
    Title = "Fast Dive / Sink (Zero Sinking Time)",
    Desc = "Мгновенное погружение крючка на глубину (0.05с)",
    Value = fastDiveEnabled,
    Callback = function(state) fastDiveEnabled = state end
})

TabFishing:Toggle({
    Title = "Instant Pull-Up & Return (No Anim)",
    Desc = "Пропуск 25-секундного всплытия со дна и возврата лески",
    Value = instantPullEnabled,
    Callback = function(state) instantPullEnabled = state end
})

TabFishing:Toggle({
    Title = "Turbo Cast (Instant Recast)",
    Desc = "Убирает 2.5-секундную паузу между забросами",
    Value = turboCastEnabled,
    Callback = function(state) turboCastEnabled = state end
})

TabFishing:Toggle({
    Title = "100% Guaranteed Perfect Throw",
    Desc = "Всегда идеальный заброс максимальной дальности",
    Value = autoPerfectEnabled,
    Callback = function(state) autoPerfectEnabled = state end
})

TabFishing:Toggle({
    Title = "Walk While Fishing (Free Walk)",
    Desc = "Разрешить ходить и прыгать во время и после заброса (Анти-фриз)",
    Value = freeWalkEnabled,
    Callback = function(state)
        freeWalkEnabled = state
        if state then unfreezeCharacter() end
    end
})

TabFishing:Section({ Title = "Targeting & Catching Logic" })

TabFishing:Dropdown({
    Title = "Target Mode",
    Desc = "Приоритет выбора рыбы в косяке",
    Values = {
        "Rarest (Highest Rarity)",
        "Secret & Boss (Secret/Boss Only)",
        "Money (Highest Sell Price)",
        "Biggest (Largest Size/Weight)",
        "Any (Fastest / Closest)"
    },
    Value = "Rarest (Highest Rarity)",
    Callback = function(selected)
        if selected:find("Secret") then catchMode = "Secret"
        elseif selected:find("Rarest") then catchMode = "Rarest"
        elseif selected:find("Money") then catchMode = "Money"
        elseif selected:find("Biggest") then catchMode = "Biggest"
        else catchMode = "Any" end
        showNotification("Target Updated", "Mode: " .. catchMode)
    end
})

TabFishing:Toggle({
    Title = "Full Capacity Catch",
    Desc = "Забивать все слоты крючка лучшей рыбой (7 из 7, 10 из 10)",
    Value = instantCatchEnabled,
    Callback = function(state) instantCatchEnabled = state end
})

TabFishing:Toggle({
    Title = "Fallback to Best if No Secret",
    Desc = "Ловить редкую рыбу если секретной нет в воде",
    Value = fallbackToBest,
    Callback = function(state) fallbackToBest = state end
})

TabFishing:Toggle({
    Title = "Auto-Win Boss Minigame",
    Desc = "Мгновенная победа в мини-игре при вылове босса/секретки",
    Value = autoFightEnabled,
    Callback = function(state) autoFightEnabled = state end
})

TabFishing:Toggle({
    Title = "Instant Reel (Full Hook Only)",
    Desc = "Подсекать только при полной загрузке слотов и отсутствии предметов",
    Value = instantReelEnabled,
    Callback = function(state) instantReelEnabled = state end
})


-- 2. 💎 TAB: ITEMS
local TabItems = Window:Tab({
    Title = "Items",
    Icon = "sparkles"
})

TabItems:Section({ Title = "100% Special Items Collector" })

TabItems:Toggle({
    Title = "Collect All Items (Fragments, Keys, Chests)",
    Desc = "100% сбор артефактов (Lava/Sand/Frozen фрагменты, ключи, сундуки)",
    Value = collectItemsEnabled,
    Callback = function(state) collectItemsEnabled = state end
})

TabItems:Toggle({
    Title = "Show Landing Spot on Distance Bar",
    Desc = "Отображение маркера цели и лучшей рыбы на шкале заброса",
    Value = landingPredictorEnabled,
    Callback = function(state) landingPredictorEnabled = state end
})

TabItems:Button({
    Title = "Grab All Water Items Now",
    Desc = "Принудительный мгновенный захват всех предметов в воде",
    Icon = "sparkles",
    Callback = function()
        if FishSchoolCtrl then
            grabAllEntities(FishSchoolCtrl)
            showNotification("Collector", "Попытка мгновенного захвата всех предметов в воде!")
        end
    end
})

TabItems:Button({
    Title = "Open All Caught Chests & Crates",
    Desc = "Автоматическое массовое открытие сундуков из инвентаря",
    Icon = "package",
    Callback = function()
        openAllChests()
    end
})

TabItems:Section({ Title = "Special Items Tracked (Priority: 100M)" })
TabItems:Button({ Title = "👑 Lava, Sand & Frozen Fragments", Desc = "Абсолютный наивысший приоритет (1 из 3000 в Emberdeep)", Icon = "check", Callback = function() end })
TabItems:Button({ Title = "🔑 Lava, Sand & Frozen Keys", Desc = "Редчайшие ключи (до 1 из 125,000)", Icon = "check", Callback = function() end })
TabItems:Button({ Title = "📦 Secret Lucky & Sunken Chests", Desc = "Секретные сундуки с ценными наградами", Icon = "check", Callback = function() end })
TabItems:Button({ Title = "📜 Summon Scrolls & Ancient Relics", Desc = "Свитки призыва, камни энчанта и реликвии", Icon = "check", Callback = function() end })


-- 3. 💰 TAB: ECONOMY
local TabEconomy = Window:Tab({
    Title = "Economy",
    Icon = "dollar-sign"
})

TabEconomy:Section({ Title = "Remote Auto-Sell" })

TabEconomy:Toggle({
    Title = "Remote Auto-Sell (Anywhere)",
    Desc = "Авто-продажа рыбы торговцу из любой точки карты",
    Value = autoSellEnabled,
    Callback = function(state) autoSellEnabled = state end
})

TabEconomy:Toggle({
    Title = "Notify Earnings per Cast",
    Desc = "Тост-уведомление с заработанной суммой после каждого вылова",
    Value = notifyCatchValue,
    Callback = function(state) notifyCatchValue = state end
})

TabEconomy:Slider({
    Title = "Sell Interval (seconds)",
    Desc = "Периодичность удаленной продажи рыбы",
    Value = { Min = 3, Max = 60, Default = 10 },
    Step = 1,
    Callback = function(val) autoSellInterval = val end
})

TabEconomy:Button({
    Title = "Sell Fish Now (Filtered)",
    Desc = "Продать рыбу выбранных редкостей торговцу прямо сейчас",
    Icon = "dollar-sign",
    Callback = function() sellFishNow() end
})

TabEconomy:Section({ Title = "Rarity Filter (Auto-Sell)" })

TabEconomy:Toggle({
    Title = "Sell Common",
    Desc = "Продавать обычную рыбу (Common)",
    Value = sellRarities.Common,
    Callback = function(state) sellRarities.Common = state end
})

TabEconomy:Toggle({
    Title = "Sell Uncommon",
    Desc = "Продавать необычную рыбу (Uncommon)",
    Value = sellRarities.Uncommon,
    Callback = function(state) sellRarities.Uncommon = state end
})

TabEconomy:Toggle({
    Title = "Sell Rare",
    Desc = "Продавать редкую рыбу (Rare)",
    Value = sellRarities.Rare,
    Callback = function(state) sellRarities.Rare = state end
})

TabEconomy:Toggle({
    Title = "Sell Epic",
    Desc = "Продавать эпическую рыбу (Epic)",
    Value = sellRarities.Epic,
    Callback = function(state) sellRarities.Epic = state end
})

TabEconomy:Toggle({
    Title = "Sell Legendary",
    Desc = "Продавать легендарную рыбу (Legendary) [по умолч. выкл]",
    Value = sellRarities.Legendary,
    Callback = function(state) sellRarities.Legendary = state end
})

TabEconomy:Toggle({
    Title = "Sell Mythic",
    Desc = "Продавать мифическую рыбу (Mythic) [защита ценностей]",
    Value = sellRarities.Mythic,
    Callback = function(state) sellRarities.Mythic = state end
})

TabEconomy:Toggle({
    Title = "Sell Secret",
    Desc = "Продавать секретную рыбу (Secret) [защита ценностей]",
    Value = sellRarities.Secret,
    Callback = function(state) sellRarities.Secret = state end
})

TabEconomy:Toggle({
    Title = "Sell Exotic",
    Desc = "Продавать экзотическую рыбу (Exotic) [защита ценностей]",
    Value = sellRarities.Exotic,
    Callback = function(state) sellRarities.Exotic = state end
})

TabEconomy:Button({
    Title = "Preset: Safe (Common - Epic Only)",
    Desc = "Выбрать только обычную-эпическую (легендарки и секретки в безопасности)",
    Icon = "shield-check",
    Callback = function()
        sellRarities.Common = true
        sellRarities.Uncommon = true
        sellRarities.Rare = true
        sellRarities.Epic = true
        sellRarities.Legendary = false
        sellRarities.Mythic = false
        sellRarities.Secret = false
        sellRarities.Exotic = false
        showNotification("Auto-Sell Filter", "Пресет: Безопасный (Common - Epic) активирован!")
    end
})

TabEconomy:Button({
    Title = "Preset: Sell All (Include High Tier)",
    Desc = "Включить продажу всех категорий рыб без исключений",
    Icon = "alert-triangle",
    Callback = function()
        for k in pairs(sellRarities) do sellRarities[k] = true end
        showNotification("Auto-Sell Filter", "Внимание: продажа всех редкостей включена!")
    end
})

TabEconomy:Section({ Title = "Passive Fish Pond" })

TabEconomy:Toggle({
    Title = "Auto Put Best Fish in Pond",
    Desc = "Авто-экипировка самых дорогих рыб в пруд перед продажей",
    Value = autoPondEnabled,
    Callback = function(state) autoPondEnabled = state end
})

TabEconomy:Button({
    Title = "Put Best Fish in Pond Now",
    Desc = "Собрать пассивный доход и экипировать лучших рыб",
    Icon = "fish",
    Callback = function()
        putBestFishInPond()
        showNotification("Pond", "EquipBest вызван: лучшие рыбы отправлены в пруд!")
    end
})

TabEconomy:Section({ Title = "Auto Upgrades" })

TabEconomy:Toggle({
    Title = "Auto-Buy Capacity (+Slots)",
    Desc = "Авто-покупка слотов вместимости удочки при наличии денег",
    Value = autoUpgradeCapacity,
    Callback = function(state) autoUpgradeCapacity = state end
})

TabEconomy:Toggle({
    Title = "Auto-Buy All Stats",
    Desc = "Авто-покупка всех характеристик (Strength, Weight, Bounce)",
    Value = autoUpgradeAll,
    Callback = function(state) autoUpgradeAll = state end
})

TabEconomy:Button({
    Title = "Buy Capacity Upgrade Now",
    Desc = "Купить +1 слот вместимости прямо сейчас",
    Icon = "plus-circle",
    Callback = function()
        buyUpgrade("Capacity")
        showNotification("Upgrade", "Запрос на покупку слота отправлен!")
    end
})


-- 4. 👁️ TAB: VISUALS
local TabVisuals = Window:Tab({
    Title = "Visuals",
    Icon = "eye"
})

TabVisuals:Section({ Title = "Fish & Items ESP" })

TabVisuals:Toggle({
    Title = "Fish & Item Highlights (Chams)",
    Desc = "Подсветка сущностей в воде цветом их редкости",
    Value = fishEspEnabled,
    Callback = function(state)
        fishEspEnabled = state
        if not state and FishSchoolCtrl and FishSchoolCtrl.Fish then
            for _, f in ipairs(FishSchoolCtrl.Fish) do
                if f.model then
                    local hl = f.model:FindFirstChild("FishESP")
                    if hl then hl:Destroy() end
                end
            end
        end
    end
})

TabVisuals:Toggle({
    Title = "Name, Rarity & Price Tags",
    Desc = "3D таблички над рыбой с названием, редкостью и ценой продажи",
    Value = espLabelsEnabled,
    Callback = function(state)
        espLabelsEnabled = state
        if not state and FishSchoolCtrl and FishSchoolCtrl.Fish then
            for _, f in ipairs(FishSchoolCtrl.Fish) do
                if f.model then
                    local bg = f.model:FindFirstChild("FishInfoTag")
                    if bg then bg:Destroy() end
                end
            end
        end
    end
})

TabVisuals:Toggle({
    Title = "Show Landing Spot Marker",
    Desc = "Показ точки приземления поплавка на полоске дальности",
    Value = landingPredictorEnabled,
    Callback = function(state) landingPredictorEnabled = state end
})


-- 5. ⚡ TAB: PERFORMANCE & BOOST
local TabBoost = Window:Tab({
    Title = "Boost",
    Icon = "zap"
})

TabBoost:Section({ Title = "Extreme FPS Booster & Optimization" })

TabBoost:Toggle({
    Title = "Ultra FPS Boost",
    Desc = "Disable water waves, grass, global shadows and post-effects",
    Value = fpsBoostEnabled,
    Callback = function(state)
        fpsBoostEnabled = state
        applyFpsBoost(state)
        showNotification("FPS Boost", state and locText("Optimization enabled: lags reduced!", "Оптимизация включена: лаги убраны!") or locText("Optimization disabled", "Оптимизация отключена"))
    end
})

TabBoost:Toggle({
    Title = "Potato PC (No Textures & Smooth Plastic)",
    Desc = "Convert parts to smooth plastic and remove textures for maximum FPS",
    Value = potatoGfxEnabled,
    Callback = function(state)
        potatoGfxEnabled = state
        applyPotatoGfx(state)
        showNotification("Potato PC", state and locText("Textures removed, FPS boosted!", "Включено: текстуры убраны, FPS увеличен!") or locText("Textures restored", "Текстуры возвращены"))
    end
})

TabBoost:Toggle({
    Title = "Remove Fog & Atmosphere (Clear Horizon)",
    Desc = "Remove lava haze and fog for crystal clear horizon",
    Value = clearFogEnabled,
    Callback = function(state)
        clearFogEnabled = state
        applyClearFog(state)
        showNotification("Clear View", state and locText("Fog and atmosphere removed!", "Включено: дымка и туман убраны!") or locText("Fog restored", "Туман возвращен"))
    end
})

TabBoost:Toggle({
    Title = "Unlock FPS Cap (Max 999 FPS)",
    Desc = "Remove Roblox 60 FPS cap",
    Value = unlockFpsEnabled,
    Callback = function(state)
        unlockFpsEnabled = state
        if state and setfpscap then setfpscap(999) end
    end
})

TabBoost:Toggle({
    Title = "GPU 0% Potato AFK (Disable 3D Rendering)",
    Desc = "Completely disable 3D rendering to save GPU temperature during AFK",
    Value = false,
    Callback = function(state)
        setGpuAfkMode(state)
        ensureGuiLayering()
        showNotification("GPU 0% AFK", state and locText("3D rendering disabled! GPU is cold.", "3D рендер выключен! GPU холодная.") or locText("3D rendering restored.", "3D рендер включен обратно."))
    end
})

TabBoost:Colorpicker({
    Title = "GPU AFK Screen Color (RGB Palette)",
    Desc = "Choose backdrop color when 3D rendering is disabled",
    Default = gpuScreenColor,
    Callback = function(color)
        gpuScreenColor = color
        if gpuScreenFrame then
            gpuScreenFrame.BackgroundColor3 = color
        end
        ensureGuiLayering()
    end
})

TabBoost:Button({
    Title = "Clean Up Dead Fish & ESP Tags",
    Desc = "Принудительно очистить временный мусор и остаточные теги",
    Icon = "trash-2",
    Callback = function()
        pcall(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj.Name == "FishInfoTag" or obj.Name == "FishESP" then
                    obj:Destroy()
                end
            end
        end)
        showNotification("Cleaner", "Теги и мусор очищены!")
    end
})


-- 6. 📍 TAB: TELEPORTS
local TabTeleports = Window:Tab({
    Title = "Teleports",
    Icon = "compass"
})

TabTeleports:Section({ Title = "🏛️ Maze & Dungeon Autocomplete" })

TabTeleports:Button({
    Title = "⚡ Autocomplete Sand Maze (Temple of the Sun)",
    Desc = "Мгновенное прохождение Песчаного Лабиринта и сбор награды у Алтаря Солнца",
    Icon = "sun",
    Callback = function() autocompleteSandMaze() end
})

TabTeleports:Button({
    Title = "❄️ Autocomplete Frost Maze (Frozen Caves)",
    Desc = "Мгновенное прохождение Ледяного Лабиринта и сбор награды у Ледяного Алтаря",
    Icon = "snowflake",
    Callback = function() autocompleteFrostMaze() end
})

TabTeleports:Button({
    Title = "🚪 Unlock Sand Maze Door (Use Sand Key)",
    Desc = "Телепорт к воротам Храма Солнца для открытия Sand Key",
    Icon = "key",
    Callback = function() unlockMazeDoor("Sand") end
})

TabTeleports:Button({
    Title = "🗝️ Unlock Frost Maze Door (Use Frozen Key)",
    Desc = "Телепорт к воротам Ледяной Пещеры для открытия Frozen Key",
    Icon = "key-round",
    Callback = function() unlockMazeDoor("Frost") end
})

TabTeleports:Section({ Title = "🌐 Dynamic World Detection & Quick TP" })

local currentWorldParagraph = TabTeleports:Paragraph({
    Title = "📍 Current World Detected",
    Desc = "Нажмите кнопку ниже для сканирования мира"
})

TabTeleports:Button({
    Title = "🔄 Scan / Update Current World",
    Desc = "Определить текущий мир и обновить информацию",
    Icon = "compass",
    Callback = function()
        local wName = getCurrentWorldName()
        if currentWorldParagraph and currentWorldParagraph.SetDesc then
            currentWorldParagraph:SetDesc("Вы находитесь в: " .. wName)
        end
        showNotification("World Scanner", "Текущий мир: " .. wName)
    end
})

TabTeleports:Button({
    Title = "🛒 Teleport to Current World Merchant",
    Desc = "Мгновенно телепортирует к торговцу того мира, в котором вы стоите",
    Icon = "store",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local npc = getActiveSellNPC()
        if hrp and npc then
            hrp.CFrame = CFrame.new(npc:GetPivot().Position + Vector3.new(0, 2, 3))
            showNotification("Teleport", "Телепортирован к торговцу мира " .. getCurrentWorldName() .. "!")
        elseif hrp then
            showNotification("Teleport", "Торговец в текущем мире не найден")
        end
    end
})

TabTeleports:Button({
    Title = "🎣 Teleport to Current World Fishing Pier",
    Desc = "Телепортирует на главный пирс/место рыбалки в текущем мире",
    Icon = "anchor",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local wName = getCurrentWorldName()
        if wName:find("2") or wName:lower():find("desert") then
            hrp.CFrame = CFrame.new(-1330, 20, 180)
        elseif wName:find("3") or wName:lower():find("frost") or wName:lower():find("tundra") then
            hrp.CFrame = CFrame.new(-1292.88, 28, 81.86)
        elseif wName:find("4") or wName:lower():find("volcano") then
            hrp.CFrame = CFrame.new(-1350, 22, 150)
        else
            hrp.CFrame = CFrame.new(-1218, 18, 185)
        end
        showNotification("Teleport", "Телепортирован на пирс " .. wName .. "!")
    end
})

TabTeleports:Section({ Title = "🌍 World 1: Starter Sea" })

TabTeleports:Button({
    Title = "World 1 Merchant",
    Desc = "Телепорт к торговцу World 1",
    Icon = "store",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(-1226.75, 22, 144.58)
            showNotification("Teleport", "Телепортирован к торговцу World 1!")
        end
    end
})

TabTeleports:Button({
    Title = "World 1 Fishing Pier",
    Desc = "Главный пирс для рыбалки в World 1",
    Icon = "anchor",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(-1218, 18, 185) end
    end
})

TabTeleports:Button({
    Title = "Deep Ocean Abyss Spot",
    Desc = "Глубоководная зона бездны в World 1",
    Icon = "waves",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(-1218, 18, 650) end
    end
})

TabTeleports:Button({
    Title = "World 1 Spawn Island",
    Desc = "Телепорт на стартовый остров",
    Icon = "home",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(-1260, 25, 80) end
    end
})

TabTeleports:Button({
    Title = "Stone Mage (Enchants)",
    Desc = "Телепорт к магу зачарований удочки",
    Icon = "sparkles",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(-1150, 20, 100) end
    end
})

TabTeleports:Section({ Title = "🏜️ World 2: Desert & Dunes" })

TabTeleports:Button({
    Title = "World 2 Desert Merchant",
    Desc = "Телепорт к торговцу во 2-м мире (Desert)",
    Icon = "store",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(-1335.45, 20.8, 141.23)
            showNotification("Teleport", "Телепортирован к торговцу World 2!")
        end
    end
})

TabTeleports:Button({
    Title = "World 2 Desert Pier",
    Desc = "Пирс и место заброса удочки в World 2",
    Icon = "anchor",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(-1330, 20, 180)
            showNotification("Teleport", "Телепортирован на пирс World 2!")
        end
    end
})

TabTeleports:Button({
    Title = "Sun Temple Entrance (Sand Door)",
    Desc = "Вход в Храм Солнца к закрытым дверям лабиринта",
    Icon = "door-closed",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(-1345, 22, 85)
            showNotification("Teleport", "Телепортирован к входу Храма Солнца!")
        end
    end
})

TabTeleports:Button({
    Title = "Desert Oasis & Dunes",
    Desc = "Оазис и глубокие песчаные барханы",
    Icon = "sun",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(-1360, 25, 220)
            showNotification("Teleport", "Телепортирован в пустынный оазис!")
        end
    end
})

TabTeleports:Section({ Title = "❄️ World 3: Frostmere & Tundra" })

TabTeleports:Button({
    Title = "World 3 Frost Merchant",
    Desc = "Телепорт к торговцу в 3-м мире (Tundra)",
    Icon = "store",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(-1325.44, 23.5, 157.35)
            showNotification("Teleport", "Телепортирован к торговцу World 3!")
        end
    end
})

TabTeleports:Button({
    Title = "World 3 Frozen Pier",
    Desc = "Замерзший пирс для рыбалки в World 3",
    Icon = "anchor",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(-1292.88, 28, 81.86)
            showNotification("Teleport", "Телепортирован на ледяной пирс World 3!")
        end
    end
})

TabTeleports:Button({
    Title = "Frozen Caves Entrance (Frost Door)",
    Desc = "Вход в Ледяные Пещеры к вратам лабиринта",
    Icon = "door-closed",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(-1310, 25, 120)
            showNotification("Teleport", "Телепортирован к ледяным вратам!")
        end
    end
})

TabTeleports:Button({
    Title = "Glacier Deep Frost Spot",
    Desc = "Глубокая ледяная расщелина для редкой арктической рыбы",
    Icon = "snowflake",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(-1280, 20, 250)
            showNotification("Teleport", "Телепортирован к леднику World 3!")
        end
    end
})

TabTeleports:Section({ Title = "🌋 World 4: Volcano & Magma Abyss" })

TabTeleports:Button({
    Title = "World 4 Volcano Merchant",
    Desc = "Телепорт к торговцу в лавовом мире (World 4)",
    Icon = "store",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(-1340.18, 20.5, 100.98)
            showNotification("Teleport", "Телепортирован к торговцу World 4!")
        end
    end
})

TabTeleports:Button({
    Title = "Lava Abyss Fishing Spot",
    Desc = "Пирс над лавовой бездной для огненных рыб",
    Icon = "flame",
    Callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(-1350, 22, 150)
            showNotification("Teleport", "Телепортирован в лавовую бездну!")
        end
    end
})


-- 7. 🏃 TAB: PLAYER
local TabPlayer = Window:Tab({
    Title = "Player",
    Icon = "user"
})

TabPlayer:Section({ Title = "Movement & Physics" })

TabPlayer:Button({
    Title = "Unfreeze Character (Fix Stuck Movement)",
    Desc = "Мгновенно разморозить персонажа и вернуть ходьбу (WASD)",
    Icon = "unlock",
    Callback = function()
        unfreezeCharacter()
        showNotification("Movement", locText("Character unfrozen! You can walk freely.", "Персонаж разморожен! Ходьба восстановлена."))
    end
})

TabPlayer:Slider({
    Title = "WalkSpeed",
    Desc = "Скорость перемещения персонажа",
    Value = { Min = 16, Max = 150, Default = 16 },
    Step = 2,
    Callback = function(val)
        currentWalkSpeed = val
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = val end
    end
})

TabPlayer:Slider({
    Title = "JumpPower",
    Desc = "Сила прыжка персонажа",
    Value = { Min = 50, Max = 250, Default = 50 },
    Step = 5,
    Callback = function(val)
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = val
        end
    end
})

TabPlayer:Toggle({
    Title = "Infinite Jump",
    Desc = "Прыжок в воздухе без земли",
    Value = infJumpEnabled,
    Callback = function(state) infJumpEnabled = state end
})

TabPlayer:Toggle({
    Title = "Walk On Water (Jesus Mode)",
    Desc = "Walk across ocean and water surfaces without swimming",
    Value = waterWalkEnabled,
    Callback = function(state)
        waterWalkEnabled = state
        showNotification("Water Walk", state and locText("Walk on water enabled!", "Хождение по воде включено!") or locText("Walk on water disabled", "Хождение по воде выключено"))
    end
})

TabPlayer:Toggle({
    Title = "Fly Mode (WASD Flight)",
    Desc = "Freely fly in air (WASD + Space to ascend, Shift to descend)",
    Value = flyEnabled,
    Callback = function(state)
        flyEnabled = state
        showNotification("Fly", state and locText("Flight mode activated!", "Полёт активирован!") or locText("Flight mode disabled", "Полёт отключен"))
    end
})

TabPlayer:Slider({
    Title = "Flight Speed",
    Desc = "Скорость полёта персонажа",
    Value = { Min = 20, Max = 200, Default = 50 },
    Step = 5,
    Callback = function(val)
        flySpeed = val
    end
})

TabPlayer:Toggle({
    Title = "Noclip (Walk Through Walls)",
    Desc = "Проход сквозь любые препятствия и стены",
    Value = noclipEnabled,
    Callback = function(state) noclipEnabled = state end
})

UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)


-- 8. ⚙️ TAB: SETTINGS & THEMES
local TabSettings = Window:Tab({
    Title = "Settings",
    Icon = "settings"
})

TabSettings:Section({ Title = "Language & Interface" })

local langDropdown = TabSettings:Dropdown({
    Title = "Interface Language",
    Desc = "Select script language (Default: English / Русский)",
    Values = { "English", "Русский" },
    Value = "English",
    Callback = function(choice)
        setScriptLanguage(choice == "Русский" and "ru" or "en")
    end
})
registerLoc(langDropdown, "Interface Language", "Язык интерфейса", "Select script language (Default: English / Русский)", "Выберите язык скрипта (По умолчанию: English / Русский)")

TabSettings:Section({ Title = "Interface Appearance & Themes" })

local AvailableThemes = {
    "Dark", "Midnight", "Sky", "Emerald", "Indigo",
    "Rose", "Violet", "CottonCandy", "MonokaiPro",
    "Crimson", "Amber", "Red", "Plant", "Mellowsi", "Light"
}

TabSettings:Dropdown({
    Title = "UI Theme Selection",
    Desc = "Выберите стильную цветовую тему (15 стилей)",
    Values = AvailableThemes,
    Value = "Dark",
    Callback = function(theme)
        Window:SetTheme(theme)
    end
})

TabSettings:Toggle({
    Title = "Acrylic Glass Blur",
    Desc = "Эффект матового стекла на фоне меню",
    Value = true,
    Callback = function(state)
        Window:ToggleAcrylic(state)
    end
})

TabSettings:Keybind({
    Title = "Toggle Menu Key",
    Desc = "Бинд меню: [Insert], [RightShift], [RightControl], [F4] или круг на экране",
    Value = Enum.KeyCode.Insert,
    Callback = function(key)
        if typeof(key) == "EnumItem" then
            toggleKeys[key] = true
            showNotification("Keybind", "Бинд изменен на " .. key.Name)
        else
            if Window then
                if Window.Toggle then
                    Window:Toggle()
                elseif Window.Closed ~= nil then
                    if Window.Closed then Window:Open() else Window:Close() end
                end
            end
        end
    end
})

TabSettings:Section({ Title = "Server & Network Utilities" })

TabSettings:Button({
    Title = "🔄 Rejoin Current Server",
    Desc = "Быстро переподключиться к текущему серверу",
    Icon = "rotate-ccw",
    Callback = function()
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
    end
})

TabSettings:Button({
    Title = "🌐 Server Hop (Change Server)",
    Desc = "Найти другой свободный сервер и подключиться",
    Icon = "globe",
    Callback = function()
        pcall(function()
            local HttpService = game:GetService("HttpService")
            local raw = game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
            local servers = HttpService:JSONDecode(raw)
            if servers and servers.data then
                for _, s in ipairs(servers.data) do
                    if s.playing < s.maxPlayers and s.id ~= game.JobId then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                        break
                    end
                end
            end
        end)
    end
})

TabSettings:Section({ Title = "🎁 Promo Codes & Freebies" })

TabSettings:Button({
    Title = "🎟️ Redeem All Working Promo Codes",
    Desc = "Автоматический ввод всех промокодов игры на бесплатные монеты и зелья",
    Icon = "gift",
    Callback = function()
        local codes = {
            "Release",
            "Fishing",
            "ThanksforPlaying",
            "Gifting",
            "Pond",
            "Skins",
            "Mutations",
            "BigFish",
            "Frostmere",
            "Kraken",
            "Keys",
            "Update9",
            "Volcano",
            "Boats",
            "SunkenCrown"
        }
        local redeemed = 0
        pcall(function()
            local ev = require(RS.Shared.Events).Client("Code")
            if ev then
                for _, c in ipairs(codes) do
                    ev:Fire(c)
                    task.wait(0.2)
                    redeemed = redeemed + 1
                end
            end
        end)
        showNotification("Codes", string.format(locText("Checked %d promo codes. Check balance!", "Проверено промокодов: %d шт. Проверьте баланс!"), redeemed))
    end
})

-- Anti-AFK
pcall(function()
    LocalPlayer.Idled:Connect(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end)
end)

showNotification("Fishy Hub Modern UI", locText("Ready! WindUI loaded with Acrylic & 15 themes.", "Готово! WindUI загружен с поддержкой акрила и 15 тем."))
