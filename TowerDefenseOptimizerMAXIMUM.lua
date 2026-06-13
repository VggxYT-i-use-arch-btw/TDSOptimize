-- ═══════════════════════════════════════════════════════
--        TOWER DEFENSE OPTIMIZER — LocalScript
-- ═══════════════════════════════════════════════════════

local Lighting = game:GetService("Lighting")
local WS       = workspace

local PLACEHOLDER_COLOR = Color3.fromRGB(90, 60, 210) -- azul arroxeado sólido

-- ─── 1. GLOBAL GRAPHICS ─────────────────────────────────

local function applyGlobalSettings()
    -- Full bright de verdade
    Lighting.Brightness               = 2
    Lighting.ClockTime                = 14
    Lighting.GlobalShadows            = false
    Lighting.Ambient                  = Color3.fromRGB(255, 255, 255)
    Lighting.OutdoorAmbient           = Color3.fromRGB(255, 255, 255)
    Lighting.EnvironmentDiffuseScale  = 1
    Lighting.EnvironmentSpecularScale = 0

    -- No fog legado
    Lighting.FogStart = 0
    Lighting.FogEnd   = 9e8
    Lighting.FogColor = Color3.fromRGB(255, 255, 255)

    -- Remove Atmosphere (fog/haze moderno) e pós-processamento
    for _, fx in ipairs(Lighting:GetChildren()) do
        if  fx:IsA("Atmosphere")
        or  fx:IsA("BlurEffect")
        or  fx:IsA("ColorCorrectionEffect")
        or  fx:IsA("SunRaysEffect")
        or  fx:IsA("BloomEffect")
        or  fx:IsA("DepthOfFieldEffect") then
            fx:Destroy()
        end
    end

    pcall(function()
        local ugs = UserSettings():GetService("UserGameSettings")
        ugs.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel01
    end)
end

-- Remove partículas, texturas e força SmoothPlastic em chunks (sem travar no início)
local function globalCleanup()
    local descendants = WS:GetDescendants()
    local CHUNK = 80  -- processa 80 objetos por frame
    for i, d in ipairs(descendants) do
        pcall(function()
            if  d:IsA("ParticleEmitter") or d:IsA("Fire")
            or  d:IsA("Smoke") or d:IsA("Sparkles")
            or  d:IsA("Trail") then
                d.Enabled = false

            elseif d:IsA("Decal") or d:IsA("Texture") then
                d:Destroy()

            elseif d:IsA("SpecialMesh") then
                d.TextureId = ""

            elseif d:IsA("BasePart") then
                d.Material   = Enum.Material.SmoothPlastic
                d.CastShadow = false
            end
        end)
        if i % CHUNK == 0 then task.wait() end  -- respira a cada chunk
    end
end

-- Deleta attachments do Terrain deixando exatamente 1 (se deletar todos eles voltam)
local function cleanTerrainAttachments()
    local terrain = WS:FindFirstChildOfClass("Terrain")
    if not terrain then return end
    local attachments = terrain:GetChildren()
    local kept = false
    for _, obj in ipairs(attachments) do
        if obj:IsA("Attachment") then
            if not kept then
                kept = true   -- preserva o primeiro, deleta o resto
            else
                obj:Destroy()
            end
        end
    end
end

-- ─── 2. HELPERS ─────────────────────────────────────────

local function del(parent, name)
    local obj = parent:FindFirstChild(name)
    if obj then obj:Destroy() end
end

-- Cria placeholder azul arroxeado SmoothPlastic sem efeitos
-- anchorPart = BasePart para soldar (NPCs) ou nil para ancorado (torres)
local function makePlaceholder(parent, anchorPart, w, h, l)
    local stud          = Instance.new("Part")
    stud.Name           = "Placeholder"
    stud.Size           = Vector3.new(w, h, l)
    stud.Material       = Enum.Material.SmoothPlastic
    stud.Color          = PLACEHOLDER_COLOR
    stud.CastShadow     = false
    stud.CanCollide     = false
    stud.Anchored       = (anchorPart == nil)
    stud.CFrame         = anchorPart and anchorPart.CFrame or CFrame.new()
    stud.Parent         = parent

    if anchorPart then
        local weld  = Instance.new("WeldConstraint")
        weld.Part0  = anchorPart
        weld.Part1  = stud
        weld.Parent = stud
    end
end

-- ─── 3. TOWERS ──────────────────────────────────────────

local processedTowers = setmetatable({}, {__mode = "k"})
local pendingTowers   = setmetatable({}, {__mode = "k"})  -- tower → tick() de quando foi vista

local TOWER_DELETE = {
    "Animations", "Display", "Queues", "Units",
    "Upgrades",   "Owner",   "Rig",    "Weapon",
    "AnimationController",
}

local BODY_PARTS = {
    -- R6
    "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
    -- R15
    "UpperTorso", "LowerTorso",
    "LeftUpperArm",  "LeftLowerArm",  "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg",  "LeftLowerLeg",  "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

local function processTower(tower)
    if processedTowers[tower] then return end
    processedTowers[tower] = true

    for _, name in ipairs(TOWER_DELETE) do del(tower, name) end
    for _, name in ipairs(BODY_PARTS)   do del(tower, name) end

    local hrp = tower:FindFirstChild("HumanoidRootPart")
    if hrp then
        del(hrp, "SellSound")
        del(hrp, "Hit")  -- destrói Hit e tudo dentro (Sound, Wave, flash1, sparks)

        hrp.Transparency = 1
        hrp.CastShadow   = false

        -- Torres são estáticas: placeholder ancorado na posição do HRP
        local p = makePlaceholder(tower, nil, 1.25, 2, 1.25)
        local ph = tower:FindFirstChild("Placeholder")
        if ph then ph.CFrame = hrp.CFrame end
    end
end

local function scanTowers()
    local folder = WS:FindFirstChild("Towers")
    if not folder then return end
    local now = tick()
    for _, tower in ipairs(folder:GetChildren()) do
        if not processedTowers[tower] then
            if not pendingTowers[tower] then
                pendingTowers[tower] = now          -- primeira vez que viu: registra
            elseif now - pendingTowers[tower] >= 2 then
                pendingTowers[tower] = nil
                processTower(tower)                 -- só processa após 2s de carregamento
            end
        end
    end
end

-- ─── 4. CLIENT UNITS (torres que andam) ────────────────

local processedUnits = setmetatable({}, {__mode = "k"})

local UNIT_DELETE = {
    "Animations", "AnimationController", "Display",
    "Queues", "Weapon",
}

local UNIT_BODY_PARTS = {
    "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
    "UpperTorso", "LowerTorso",
    "LeftUpperArm",  "LeftLowerArm",  "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg",  "LeftLowerLeg",  "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

local function processUnit(unit)
    if processedUnits[unit] then return end
    processedUnits[unit] = true

    for _, name in ipairs(UNIT_DELETE)      do del(unit, name) end
    for _, name in ipairs(UNIT_BODY_PARTS)  do del(unit, name) end

    -- Invisibiliza tudo que sobrou
    for _, part in ipairs(unit:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = 1
            part.CastShadow   = false
        end
    end

    -- Solda placeholder no HRP igual aos NPCs (anda junto)
    local hrp = unit:FindFirstChild("HumanoidRootPart", true)
    if hrp then
        hrp.Transparency = 1
        makePlaceholder(unit, hrp, 1.25, 2, 1.25)
    end
end

local function scanUnits()
    local folder = WS:FindFirstChild("ClientUnits")
    if not folder then return end
    for _, unit in ipairs(folder:GetChildren()) do
        processUnit(unit)
    end
end

-- ─── 5. NPCS ────────────────────────────────────────────

local processedNPCs = setmetatable({}, {__mode = "k"})

local function processNPC(npc)
    if processedNPCs[npc] then return end
    processedNPCs[npc] = true

    del(npc, "Animations")
    del(npc, "AnimationController")
    del(npc, "Hotbox")

    -- Invisibiliza todos os BaseParts mantendo física intacta
    for _, part in ipairs(npc:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = 1
            part.CastShadow   = false
        end
    end

    -- Solda placeholder no HRP: ele segue o NPC enquanto anda
    local hrp = npc:FindFirstChild("HumanoidRootPart", true)
    if hrp then
        makePlaceholder(npc, hrp, 1.1, 2, 1.1)
    end
end

local function scanNPCs()
    local folder = WS:FindFirstChild("NPCs")
    if not folder then return end
    for _, npc in ipairs(folder:GetChildren()) do
        processNPC(npc)
    end
end

-- ─── 6. MAIN ─────────────────────────────────────────────

applyGlobalSettings()

-- Startup distribuído: espalha o trabalho pesado em ~3s para não travar
task.spawn(function()
    task.wait(0.5)  cleanTerrainAttachments()
    task.wait(0.5)  globalCleanup()   -- chunked internamente
    task.wait(0.5)  scanTowers()
    task.wait(0.5)  scanNPCs()
    task.wait(0.5)  scanUnits()
end)

while true do
    task.wait(1)
    scanTowers()
    scanNPCs()
    scanUnits()
end
