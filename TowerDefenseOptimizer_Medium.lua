-- ═══════════════════════════════════════════════════════
--   TOWER DEFENSE OPTIMIZER [MEDIUM] — LocalScript
-- ═══════════════════════════════════════════════════════

local Lighting = game:GetService("Lighting")
local WS       = workspace

-- ─── 1. GLOBAL GRAPHICS ─────────────────────────────────

local function applyGlobalSettings()
    Lighting.Brightness               = 2
    Lighting.ClockTime                = 14
    Lighting.GlobalShadows            = false
    Lighting.Ambient                  = Color3.fromRGB(255, 255, 255)
    Lighting.OutdoorAmbient           = Color3.fromRGB(255, 255, 255)
    Lighting.EnvironmentDiffuseScale  = 1
    Lighting.EnvironmentSpecularScale = 0
    Lighting.FogStart                 = 0
    Lighting.FogEnd                   = 9e8
    Lighting.FogColor                 = Color3.fromRGB(255, 255, 255)

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

-- Limpeza global: desativa efeitos visuais pesados e força material liso
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
                d.TextureId = ""          -- remove textura, mantém shape do mesh

            elseif d:IsA("BasePart") then
                d.Material   = Enum.Material.SmoothPlastic  -- low poly visual
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

-- ─── 3. TOWERS ──────────────────────────────────────────

local processedTowers = setmetatable({}, {__mode = "k"})

-- Só remove o que é ligado a animação/lógica pesada
-- Mantém corpo, HRP, partes visuais
local TOWER_DELETE = {
    "Animations",
    "AnimationController",
    "Display",      -- UI flutuante acima da torre, geralmente pesada
    "Queues",
}

local function processTower(tower)
    if processedTowers[tower] then return end
    processedTowers[tower] = true

    for _, name in ipairs(TOWER_DELETE) do del(tower, name) end

    -- Remove partículas e sons dentro da torre
    for _, d in ipairs(tower:GetDescendants()) do
        pcall(function()
            if  d:IsA("ParticleEmitter") or d:IsA("Fire")
            or  d:IsA("Smoke") or d:IsA("Sparkles")
            or  d:IsA("Trail") then
                d.Enabled = false
            elseif d:IsA("Sound") then
                d:Destroy()
            end
        end)
    end

    local hrp = tower:FindFirstChild("HumanoidRootPart")
    if hrp then
        del(hrp, "SellSound")
        del(hrp, "Hit")
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

-- Remove animações e lógica dispensável
-- Mantém BodyMotor6D, corpo, física
local NPC_DELETE = {
    "Animations",
    "AnimationController",
    "Hotbox",
}

local function processNPC(npc)
    if processedNPCs[npc] then return end
    processedNPCs[npc] = true

    for _, name in ipairs(NPC_DELETE) do del(npc, name) end

    -- Remove texturas/decais/partículas do corpo do NPC
    for _, d in ipairs(npc:GetDescendants()) do
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

local function scanNPCs()
    local folder = WS:FindFirstChild("NPCs")
    if not folder then return end
    for _, npc in ipairs(folder:GetChildren()) do
        processNPC(npc)
    end
end

-- ─── 5. MAIN ─────────────────────────────────────────────

applyGlobalSettings()
task.spawn(globalCleanup)

while true do
    scanTowers()
    scanNPCs()
    task.wait(1)
end
