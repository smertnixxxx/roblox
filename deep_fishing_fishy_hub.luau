-- [[ Deep Fishing - Fishy Hub v6.3 (Full Capacity + Item Collector + Landing Predictor) ]] --
-- Совместимо с Real Executor
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Очистка старых потоков и GUI чтобы не двоились
if getgenv()._FishyHubCleanup then
    pcall(getgenv()._FishyHubCleanup)
end

local myHubToken = os.clock()
local fightThread = nil
getgenv()._FishyHubToken = myHubToken
getgenv()._FishyHubCleanup = function()
    getgenv()._FishyHubToken = nil
    if fightThread then pcall(task.cancel, fightThread) end
end

pcall(function()
    local targetParent = (gethui and gethui()) or game:GetService("CoreGui")
    for _, g in ipairs(targetParent:GetChildren()) do
        if g.Name:find("Fishy Hub") then
            pcall(function() g:Destroy() end)
        end
    end
end)

-- Загрузка UI библиотеки Venyx
local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/GhostDuckyy/UI-Libraries/3b0bcba89893baa65d36b12b33e70e93ebc8b122/Venyx/source.lua"))()
local venyx = library.new("Fishy Hub v6.5 | Deep Fishing", 5013109572)

-- Надежная система уведомлений: нативные тосты Roblox (исчезают сами ровно через 2 сек)
local StarterGui = game:GetService("StarterGui")
local function showNotification(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title),
            Text = tostring(text),
            Duration = 2
        })
    end)
end

-- Неоновая океаническая тема
local fishTheme = {
    Background    = Color3.fromRGB(8, 16, 26),
    Glow          = Color3.fromRGB(0, 240, 255),
    Accent        = Color3.fromRGB(12, 32, 48),
    LightContrast = Color3.fromRGB(16, 44, 64),
    DarkContrast  = Color3.fromRGB(5, 12, 20),
    TextColor     = Color3.fromRGB(230, 250, 255)
}

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
local CatchFight; pcall(function() CatchFight = require(RS.Shared.Modules.CatchFight) end)

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

-- Форматирование чисел в валюту ($1.25M, $45.2K)
local function formatMoney(val)
    if not val or val <= 0 then return "$0" end
    if val >= 1000000000 then
        return string.format("$%.2fB", val / 1000000000)
    elseif val >= 1000000 then
        return string.format("$%.2fM", val / 1000000)
    elseif val >= 1000 then
        return string.format("$%.1fK", val / 1000)
    else
        return string.format("$%d", math.floor(val))
    end
end

-- Поиск активного продавца в текущем мире (World 1, World 2, etc.)
local function getActiveSellNPC()
    local npcs = CollectionService:GetTagged("NPC_Sell")
    for _, npc in ipairs(npcs) do
        if npc:IsDescendantOf(workspace) then
            return npc
        end
    end
    return npcs[1]
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

-- Функция надежной удаленной продажи (со спуфом позиции к NPC для прохождения дистанс-чека)
local isSelling = false
local function sellFishNow()
    if isSelling then return end
    if ThrowCinematicCtrl and (ThrowCinematicCtrl.Active or (ThrowCinematicCtrl.Sub and ThrowCinematicCtrl.Sub.ThrowCamera and ThrowCinematicCtrl.Sub.ThrowCamera.OutroConn)) then
        return -- Не продаем прямо посреди полета поплавка или анимации камеры
    end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local npc = getActiveSellNPC()
    if not hrp or not npc then return end
    
    isSelling = true
    
    -- Сначала ставим лучших рыб в пруд и даем серверу время обработать
    if autoPondEnabled then
        putBestFishInPond()
        task.wait(0.35)
    end
    
    local oldCF = hrp.CFrame
    local npcPos = npc:GetPivot().Position
    
    -- Замораживаем камеру на месте, чтобы при телепорте персонажа экран не дергался и камера не сбивалась
    local cam = workspace.CurrentCamera
    local oldCamType = cam.CameraType
    local oldCamCFrame = cam.CFrame
    cam.CameraType = Enum.CameraType.Scriptable
    
    -- Смещаемся к NPC для серверной валидации
    hrp.CFrame = CFrame.new(npcPos + Vector3.new(0, 2, 2))
    task.wait(0.18)
    
    local ok, res = pcall(function()
        if NpcSellCtrl and NpcSellCtrl.Events and NpcSellCtrl.Events.Client then
            local ev = NpcSellCtrl.Events.Client("SellAll")
            if ev then
                return ev:Invoke(5, "Fish", nil)
            end
        end
    end)
    
    -- Возвращаемся обратно
    hrp.CFrame = oldCF
    task.wait(0.02)
    
    -- Гарантированно возвращаем камеру игроку в Custom
    cam.CameraType = Enum.CameraType.Custom
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        cam.CameraSubject = hum
    end
    
    isSelling = false
    
    if ok and res and res.Amount and res.Amount > 0 then
        showNotification("💰 Auto-Sell", string.format("Продано: %d рыб за %s", res.Amount, formatMoney(res.Value)))
        return res
    end
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

-- ==================== SMART ENTITY SCORING (FISH + ITEMS) ====================
local function getEntityScore(f, mode)
    local name = f.name or ""
    
    -- 1. Особые предметы, фрагменты (Sand/Frozen/Lava), ключи, свитки, сундуки, камни и реликвии
    local isSpecialItem = false
    local itemType = "Special"
    
    if KeyConfig and KeyConfig.Items and KeyConfig.Items[name] then
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
        local lower = name:lower()
        if lower:find("fragment") or lower:find("key") or lower:find("scroll") 
           or lower:find("stone") or lower:find("crown") or lower:find("chest") 
           or lower:find("bottle") or lower:find("relic") or lower:find("cage") 
           or lower:find("trap") or lower:find("heart") then
            isSpecialItem = true
            itemType = "Special"
        end
    end
    
    if isSpecialItem or f.bypassRoom then
        local info = {
            name = name,
            rarity = "Special",
            order = 10,
            price = 100000,
            isBoss = false,
            isSecret = true,
            isSpecial = true,
            isItem = true,
            itemType = itemType
        }
        -- Абсолютный наивысший приоритет (25M): фрагменты и предметы ловятся первыми всегда!
        return 25000000, info
    end
    
    -- 2. Мусор
    local isJunk = false
    if JunkConfig and JunkConfig.Items and JunkConfig.Items[name] then
        isJunk = true
    else
        local lower = name:lower()
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

-- ==================== FULL CAPACITY MULTI-GRAB HOOK ====================
-- Забивает ВСЕ слоты вместимости крючка (7 из 7, 10 из 10) лучшими рыбами, фрагментами и предметами!
if FishSchoolCtrl then
    FishSchoolCtrl._rawTryGrab = FishSchoolCtrl._rawTryGrab or FishSchoolCtrl.TryGrab
    local rawTryGrab = FishSchoolCtrl._rawTryGrab
    
    FishSchoolCtrl.TryGrab = function(self, point)
        if instantCatchEnabled and self.Fish and #self.Fish > 0 and self.Cinematic and self.Cinematic.Catchable and self.Cinematic.PullStart then
            local maxCap = self.Cinematic:GetBaitCapacity()
            local currentCaught = self.Cinematic:CaughtFishCount()
            local slotsFree = maxCap - currentCaught
            
            if slotsFree > 0 or collectItemsEnabled then
                local candidates = {}
                for _, f in ipairs(self.Fish) do
                    if not f.caught and not f.escaped and not f.fighting and f.model and f.model.Parent then
                        local score, info = getEntityScore(f, catchMode)
                        table.insert(candidates, {
                            fish = f,
                            score = score,
                            info = info
                        })
                    end
                end
                
                table.sort(candidates, function(a, b)
                    return a.score > b.score
                end)
                
                if #candidates > 0 then
                    for _, cand in ipairs(candidates) do
                        local target = cand.fish
                        local isSpecial = cand.info and cand.info.isSpecial
                        local isBypass = target.bypassRoom == true or isSpecial
                        
                        if catchMode == "Secret" and cand.score <= 0 then
                            if not fallbackToBest then
                                break
                            end
                        end
                        
                        local isFighting = target.boss == true or (CatchFight and CatchFight.Required and CatchFight.Required(FishConfig:Get(target.name, true)))
                        
                        if isFighting then
                            -- Босс / Секретная рыба: начинаем бой в одиночку, не смешивая с другими рыбами
                            self.Cinematic.Sub.CatchMinigame:Offer(target)
                            return
                        end
                        
                        if slotsFree > 0 or isBypass then
                            if not isBypass then
                                slotsFree = slotsFree - 1
                            end
                            if not self.Cinematic.Sub.CatchMinigame:Offer(target) then
                                self:CompleteGrab(target)
                            end
                        end
                    end
                    return
                end
            end
        end
        
        return rawTryGrab(self, point)
    end
    
    -- Автоудаление застрявших / дохлых моделей рыб (включая v.taken == true)
    FishSchoolCtrl._rawDespawn = FishSchoolCtrl._rawDespawn or FishSchoolCtrl.Despawn
    local rawDespawn = FishSchoolCtrl._rawDespawn
    FishSchoolCtrl.Despawn = function(self)
        if self.Fish then
            for _, f in ipairs(self.Fish) do
                if f.model and f.model.Parent then
                    pcall(function() f.model:Destroy() end)
                end
            end
        end
        return rawDespawn(self)
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
        
        -- Сразу удаляем все не пойманные оставшиеся модели в воде
        if self.Fish then
            for _, f in ipairs(self.Fish) do
                if f.model and f.model.Parent and not f.caught then
                    pcall(function() f.model:Destroy() end)
                end
            end
        end
        
        -- Гарантированный возврат контроля персонажу
        pcall(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.WalkSpeed < 16 then hum.WalkSpeed = 16 end
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Anchored then hrp.Anchored = false end
        end)
        
        if caught and #caught > 0 then
            -- Удаляем пойманные модели после завершения анимации притяжения
            task.delay(0.6, function()
                for _, f in ipairs(caught) do
                    if f.model and f.model.Parent then
                        pcall(function() f.model:Destroy() end)
                    end
                end
            end)
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
            
            if notifyCatchValue then
                local bestTxt = bestName and (" | Топ: " .. bestName) or ""
                showNotification("🎣 Заброс завершён!", string.format("Поймано: %d шт. | Выручка: %s%s", count, formatMoney(totalValue), bestTxt))
            end
            
            -- Ждем полного завершения анимаций сбора рыбы и синематика заброса
            task.spawn(function()
                local t0 = os.clock()
                while ThrowCinematicCtrl and ThrowCinematicCtrl.Active and (os.clock() - t0 < 3.0) do
                    task.wait(0.05)
                end
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

-- ==================== ⚡ ZERO FLIGHT TIME (FAST ARC SKIP) ====================
-- Устраняет 3-6 секундный полёт поплавка в воздухе, оставляя только минимальный серверный кд
if ThrowCinematicCtrl then
    ThrowCinematicCtrl._rawOnServerStarted = ThrowCinematicCtrl._rawOnServerStarted or ThrowCinematicCtrl.OnServerStarted
    local rawOnServerStarted = ThrowCinematicCtrl._rawOnServerStarted
    ThrowCinematicCtrl.OnServerStarted = function(self, a2, ...)
        if fastArcEnabled and type(a2) == "table" then
            a2.arcDuration = 0.28
            if a2.bounces then
                for _, b in ipairs(a2.bounces) do
                    b.duration = 0.06
                    b.Duration = 0.06
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
            self.ArcDuration = 0.28
            self.ArcStart = os.clock() - 0.05
            if self.BounceList then
                for _, b in ipairs(self.BounceList) do
                    b.duration = 0.06
                    b.Duration = 0.06
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
            task.wait(0.35)
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

-- 3. Hook CatchMinigame (Auto-Clicker with Server Rate Limit Respect)
if CatchMinigameCtrl then
    CatchMinigameCtrl._rawBegin = CatchMinigameCtrl._rawBegin or CatchMinigameCtrl.Begin
    local rawBegin = CatchMinigameCtrl._rawBegin

    CatchMinigameCtrl.Begin = function(self, fish, boss)
        rawBegin(self, fish, boss)
        if autoFightEnabled and self.Fight then
            local fishName = (fish and fish.name) or "Boss / Secret Fish"
            showNotification("🌟 Босс на крючке!", "Ловим: " .. tostring(fishName))
            if fightThread then pcall(task.cancel, fightThread) end
            local currentFight = self.Fight
            fightThread = task.spawn(function()
                task.wait(0.05)
                while self.Fight and self.Fight == currentFight do
                    pcall(function() self:Click() end)
                    task.wait(0.088) -- ~11.36 кликов/сек, строго под серверным лимитом 12/сек
                end
            end)
        end
    end
end

-- 4. Heartbeat Loop: Full-Capacity Fast Reel & Fight Autoclicker Fallback
RunService.Heartbeat:Connect(function()
    -- Если идёт бой с боссом: НЕ ПОДСЕКАЕМ, даем автокликеру дожать мини-игру
    if CatchMinigameCtrl and CatchMinigameCtrl.Fight then
        local currentFight = CatchMinigameCtrl.Fight
        if autoFightEnabled and (not fightThread or coroutine.status(fightThread) == "dead") then
            fightThread = task.spawn(function()
                task.wait(0.05)
                while CatchMinigameCtrl.Fight and CatchMinigameCtrl.Fight == currentFight do
                    pcall(function() CatchMinigameCtrl:Click() end)
                    task.wait(0.088)
                end
            end)
        end
        return
    end

    -- Fast Reel: подсекаем ТОЛЬКО КОГДА ВСЕ СЛОТЫ ЗАБИТЫ (caught >= maxCap)
    if instantReelEnabled and ThrowCinematicCtrl and ThrowCinematicCtrl.Active and not ThrowCinematicCtrl.ReelRequested then
        local cap = ThrowCinematicCtrl:GetBaitCapacity()
        local caught = ThrowCinematicCtrl:CaughtFishCount()
        local spawned = (FishSchoolCtrl and FishSchoolCtrl.Fish and #FishSchoolCtrl.Fish) or 0
        
        -- Подсекаем, когда забиты абсолютно все слоты (например 7 из 7) ИЛИ в воде больше нет рыбы
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

-- ==================== VENYX GUI SETUP ====================

local mainPage = venyx:addPage("Fishing", 5012544693)
local filterSection = mainPage:addSection("🎯 Target & Capacity")

filterSection:addDropdown("Target Mode", {
    "Rarest (Highest Rarity)",
    "Secret & Boss (Secret/Boss Only)",
    "Money (Highest Sell Price)",
    "Biggest (Largest Size/Weight)",
    "Any (Fastest / Closest)"
}, function(selected)
    if selected:find("Secret") then
        catchMode = "Secret"
    elseif selected:find("Rarest") then
        catchMode = "Rarest"
    elseif selected:find("Money") then
        catchMode = "Money"
    elseif selected:find("Biggest") then
        catchMode = "Biggest"
    else
        catchMode = "Any"
    end
    showNotification("Target Updated", "Mode: " .. catchMode)
end)

filterSection:addToggle("Full Capacity Catch (Fill All Slots)", true, function(state)
    instantCatchEnabled = state
end)

filterSection:addToggle("Collect All Items (Fragments, Keys, Chests)", true, function(state)
    collectItemsEnabled = state
end)

filterSection:addToggle("Show Landing Spot on Bar", true, function(state)
    landingPredictorEnabled = state
end)

filterSection:addToggle("Auto Put Best Fish in Pond", true, function(state)
    autoPondEnabled = state
end)

filterSection:addToggle("Notify Earnings per Cast", true, function(state)
    notifyCatchValue = state
end)

filterSection:addToggle("Fallback to Best if No Secret", true, function(state)
    fallbackToBest = state
end)

filterSection:addToggle("Auto-Win Boss Minigame", true, function(state)
    autoFightEnabled = state
end)

filterSection:addToggle("Instant Reel (Full Hook Only)", true, function(state)
    instantReelEnabled = state
end)

local farmSection = mainPage:addSection("⚡ Auto Cast & Automation")

farmSection:addToggle("Enable Auto Fish (AFK Farm)", (AutoFishingCtrl and AutoFishingCtrl.On == true) or false, function(state)
    autoFishEnabled = state
    if AutoFishingCtrl then
        if state then
            equipRod()
            AutoFishingCtrl:SetOn(true)
        else
            AutoFishingCtrl:SetOn(false)
        end
    end
end)

farmSection:addToggle("⚡ Fast Arc Skip (Zero Flight Time)", true, function(state)
    fastArcEnabled = state
end)

farmSection:addToggle("100% Perfect Throw Every Time", true, function(state)
    autoPerfectEnabled = state
end)

farmSection:addToggle("Turbo Cast (Instant Fast Cast)", true, function(state)
    turboCastEnabled = state
end)

-- Economy & Upgrades Page
local ecoPage = venyx:addPage("Upgrades", 5012544693)
local upgradeSection = ecoPage:addSection("Auto-Buy Upgrades")

upgradeSection:addToggle("Auto-Buy Capacity (+Slots)", false, function(state)
    autoUpgradeCapacity = state
    if state then
        venyx:Notify("Auto-Upgrade", "Auto-buying Capacity when cash is available!")
    end
end)

upgradeSection:addToggle("Auto-Buy All Stats (Capacity, Strength, etc)", false, function(state)
    autoUpgradeAll = state
end)

upgradeSection:addButton("Buy Capacity Upgrade Now", function()
    buyUpgrade("Capacity")
    venyx:Notify("Upgrade Sent", "Requested Capacity upgrade!")
end)

local sellSection = ecoPage:addSection("Remote Auto-Sell & Pond")

sellSection:addToggle("Remote Auto-Sell (Anywhere)", true, function(state)
    autoSellEnabled = state
end)

sellSection:addToggle("Auto Put Best Fish in Pond", true, function(state)
    autoPondEnabled = state
end)

sellSection:addToggle("Notify Earnings per Cast", true, function(state)
    notifyCatchValue = state
end)

sellSection:addSlider("Sell Interval (seconds)", 10, 3, 60, function(val)
    autoSellInterval = val
end)

sellSection:addButton("Put Best Fish in Pond Now", function()
    putBestFishInPond()
    venyx:Notify("🐟 Pond", "EquipBest вызван: лучшие рыбы отправлены в пруд!")
end)

sellSection:addButton("Sell All Fish Now", function()
    sellFishNow()
end)

-- Visuals Page
local visualPage = venyx:addPage("Visuals", 5012544693)
local visualSection = visualPage:addSection("ESP & Chams")

visualSection:addToggle("Fish & Item Highlights", true, function(state)
    fishEspEnabled = state
    if not state and FishSchoolCtrl and FishSchoolCtrl.Fish then
        for _, f in ipairs(FishSchoolCtrl.Fish) do
            if f.model then
                local hl = f.model:FindFirstChild("FishESP")
                if hl then hl:Destroy() end
            end
        end
    end
end)

visualSection:addToggle("Name, Rarity & Price Tags", true, function(state)
    espLabelsEnabled = state
    if not state and FishSchoolCtrl and FishSchoolCtrl.Fish then
        for _, f in ipairs(FishSchoolCtrl.Fish) do
            if f.model then
                local bg = f.model:FindFirstChild("FishInfoTag")
                if bg then bg:Destroy() end
            end
        end
    end
end)

-- Teleports Page
local tpPage = venyx:addPage("Teleports", 5012544693)
local tpSection = tpPage:addSection("Locations & Spots")

tpSection:addButton("Merchant (Sell NPC)", function()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = CFrame.new(-1226.75, 22, 144.58) end
end)

tpSection:addButton("Fishing Pier (Deep Water)", function()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = CFrame.new(-1218, 18, 185) end
end)

tpSection:addButton("Deep Ocean Abyss Spot", function()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = CFrame.new(-1218, 18, 650) end
end)

tpSection:addButton("Island Spawn (World 1)", function()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = CFrame.new(-1260, 25, 80) end
end)

tpSection:addButton("Stone Mage (Enchants)", function()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = CFrame.new(-1150, 20, 100) end
end)

-- Player Page
local playerPage = venyx:addPage("Player", 5012544693)
local movementSection = playerPage:addSection("Movement & Physics")

movementSection:addSlider("WalkSpeed", 16, 16, 150, function(val)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = val end
end)

movementSection:addSlider("JumpPower", 50, 50, 250, function(val)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.UseJumpPower = true
        hum.JumpPower = val
    end
end)

local infJump = false
movementSection:addToggle("Infinite Jump", false, function(state)
    infJump = state
end)

movementSection:addToggle("Noclip (Walk Through Walls)", false, function(state)
    noclipEnabled = state
end)

UserInputService.JumpRequest:Connect(function()
    if infJump then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- UI Theme Page
local themePage = venyx:addPage("Settings", 5012544693)
local themeSection = themePage:addSection("UI Theme & Colors")

for theme, color in pairs(fishTheme) do
    themeSection:addColorPicker(theme, color, function(color3)
        pcall(function() venyx:setTheme(theme, color3) end)
    end)
    pcall(function() venyx:setTheme(theme, color) end)
end

themeSection:addKeybind("Toggle Menu Keybind", Enum.KeyCode.RightShift, function()
    pcall(function() venyx:toggle() end)
end)

-- Anti-AFK
pcall(function()
    LocalPlayer.Idled:Connect(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end)
end)

-- Select first page
venyx:SelectPage(venyx.pages[1], true)
showNotification("Fishy Hub v6.5", "Готово! Venyx UI, авто-босс и очистка активны.")
