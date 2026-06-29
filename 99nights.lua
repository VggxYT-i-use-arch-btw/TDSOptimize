-- ═══════════════════════════════════════════════════════
--   OPTIMIZER — LocalScript
-- ═══════════════════════════════════════════════════════

local Lighting = game:GetService("Lighting")
local WS       = workspace

-- ─── 1. GLOBAL GRAPHICS ─────────────────────────────────

local function applyGlobalSettings()
    Lighting.Brightness               = 2
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
end

-- ─── 2. HELPERS ─────────────────────────────────────────

local function del(parent, name)
    local obj = parent:FindFirstChild(name)
    if obj then obj:Destroy() end
end

-- ─── 3. CHARACTERS ──────────────────────────────────────

local processedChars = setmetatable({}, {__mode = "k"})

local function processCharacter(char)
    if processedChars[char] then return end
    processedChars[char] = true

    -- Remove scripts e controllers de animação
    del(char, "Animate")
    del(char, "AnimationController")

    -- Remove Animator dentro do Humanoid
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        del(humanoid, "Animator")
    end

    -- Desativa efeitos visuais pesados (textura/material intactos)
    for _, d in ipairs(char:GetDescendants()) do
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
end

local function scanCharacters()
    local folder = WS:FindFirstChild("Characters")
    if not folder then return end
    for _, char in ipairs(folder:GetChildren()) do
        processCharacter(char)
    end
end

-- ─── 4. MAIN ─────────────────────────────────────────────

applyGlobalSettings()

task.spawn(function()
    task.wait(1)
    scanCharacters()
end)

while true do
    task.wait(1)
    scanCharacters()
end
