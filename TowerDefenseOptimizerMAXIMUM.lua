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

-- Remove partículas, destrói decais/texturas e força SmoothPlastic em tudo (roda uma vez)
local function globalCleanup()
    for _, d in ipairs(WS:GetDescendants()) do
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
    for _, tower in ipairs(folder:GetChildren()) do
        processTower(tower)
    end
end

-- ─── 4. NPCS ────────────────────────────────────────────

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

-- ─── 5. MAIN ─────────────────────────────────────────────

applyGlobalSettings()
task.spawn(globalCleanup)  -- roda em paralelo sem travar o loop

while true do
    scanTowers()
    scanNPCs()
    task.wait(1)
end
