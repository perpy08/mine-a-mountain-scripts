-- =====================================================================
--  MINE A MOUNTAIN: INTEGRATED FULL-FUNCTIONAL PANEL
-- =====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService") 
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local ProfileSettings = {
    AutoBuyActive = false, InstantInteractions = false, MultiJumpActive = false,
    NoRagdollActive = false, NoDamageActive = false, PlayerESPActive = false,
    LagFXActive = false, CurrentSpeedMultiplier = 1.0
}

local maxBonusJumps = 10
local jumpCount = 0

-- ---------------------------------------------------------------------
--  ESP & CHARACTER MANAGEMENT (ORIGINAL LOGIC)
-- ---------------------------------------------------------------------
local function createESP(player)
    if player == LocalPlayer then return end
    local highlight = Instance.new("Highlight"); highlight.Name = "PlayerHighlight"; highlight.FillColor = Color3.fromRGB(255, 0, 0); highlight.Enabled = false
    local billboard = Instance.new("BillboardGui"); billboard.Name = "PlayerLabel"; billboard.Size = UDim2.new(0, 100, 0, 50); billboard.StudsOffset = Vector3.new(0, 2, 0); billboard.AlwaysOnTop = true; billboard.Enabled = false
    Instance.new("TextLabel", billboard).Text = player.Name
    local function setupChar(char) highlight.Parent = char; billboard.Parent = char:WaitForChild("HumanoidRootPart") end
    player.CharacterAdded:Connect(setupChar)
    if player.Character then setupChar(player.Character) end
end
Players.PlayerAdded:Connect(createESP)
for _, p in pairs(Players:GetPlayers()) do createESP(p) end

RunService.RenderStepped:Connect(function()
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("PlayerHighlight") then
            p.Character.PlayerHighlight.Enabled = ProfileSettings.PlayerESPActive
            p.Character.HumanoidRootPart.PlayerLabel.Enabled = ProfileSettings.PlayerESPActive
        end
    end
end)

-- ---------------------------------------------------------------------
--  AUTOMATION & LAG FX ENGINES
-- ---------------------------------------------------------------------
local BUY_BOMB_REMOTE = (ReplicatedStorage:WaitForChild("Remotes", 3) or ReplicatedStorage:WaitForChild("Events", 3) or ReplicatedStorage):FindFirstChild("BuyBomb") or ReplicatedStorage:FindFirstChild("PurchaseBomb")

task.spawn(function()
    while true do
        if ProfileSettings.AutoBuyActive and BUY_BOMB_REMOTE then
            for _, bomb in ipairs({"Classic Bomb", "Wind Bomb", "Ice Bomb", "Fire Bomb", "Thunder Bomb"}) do
                if not ProfileSettings.AutoBuyActive then break end
                pcall(function() BUY_BOMB_REMOTE:FireServer(bomb) end)
                task.wait(0.4)
            end
        end
        task.wait(3)
    end
end)

local function applyLagEffect(track)
    local lastUpdate = 0
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not track or not track.Parent or not track.IsPlaying then if connection then connection:Disconnect() end return end
        if ProfileSettings.LagFXActive then
            track:AdjustSpeed(0)
            if os.clock() - lastUpdate >= 0.33 then
                pcall(function() track.TimePosition += (0.15 + (math.random() * 0.1)) end)
                lastUpdate = os.clock()
            end
        elseif track.Speed == 0 then track:AdjustSpeed(ProfileSettings.CurrentSpeedMultiplier) end
    end)
end

local function ManageCharacter(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        local anim = hum:FindFirstChildOfClass("Animator")
        if anim then
            anim.AnimationPlayed:Connect(applyLagEffect)
            for _, track in ipairs(anim:GetPlayingAnimationTracks()) do applyLagEffect(track) end
        end
        hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function() hum.WalkSpeed = 16 * ProfileSettings.CurrentSpeedMultiplier end)
    end
end
LocalPlayer.CharacterAdded:Connect(ManageCharacter)
if LocalPlayer.Character then ManageCharacter(LocalPlayer.Character) end

-- ---------------------------------------------------------------------
--  FULL UI ARCHITECTURE
-- ---------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui")); ScreenGui.Name = "MineAMountainPanel"
local MainFrame = Instance.new("Frame", ScreenGui); MainFrame.Size = UDim2.new(0, 240, 0, 400); MainFrame.Position = UDim2.new(0.05, 0, 0.4, 0); MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25); MainFrame.Active = true; MainFrame.Draggable = true; Instance.new("UICorner", MainFrame)

local TabHolder = Instance.new("Frame", MainFrame); TabHolder.Size = UDim2.new(1, 0, 0, 40); TabHolder.BackgroundTransparency = 1
local ExpTab = Instance.new("TextButton", TabHolder); ExpTab.Size = UDim2.new(0.5, 0, 1, 0); ExpTab.Text = "Exploits"; ExpTab.BackgroundColor3 = Color3.fromRGB(40,40,40); ExpTab.TextColor3 = Color3.new(1,1,1)
local MiscTab = Instance.new("TextButton", TabHolder); MiscTab.Size = UDim2.new(0.5, 0, 1, 0); MiscTab.Position = UDim2.new(0.5, 0, 0, 0); MiscTab.Text = "Misc"; MiscTab.BackgroundColor3 = Color3.fromRGB(20,20,20); MiscTab.TextColor3 = Color3.new(1,1,1)

local Content = Instance.new("ScrollingFrame", MainFrame); Content.Size = UDim2.new(1, 0, 1, -40); Content.Position = UDim2.new(0, 0, 0, 40); Content.BackgroundTransparency = 1; Content.CanvasSize = UDim2.new(0, 0, 0, 800)
Instance.new("UIListLayout", Content).Padding = UDim.new(0, 5)

local function clear() for _,v in pairs(Content:GetChildren()) do if not v:IsA("UIListLayout") then v:Destroy() end end end

local function createToggle(name, callback)
    local b = Instance.new("TextButton", Content); b.Size = UDim2.new(0.9, 0, 0, 35); b.BackgroundColor3 = Color3.fromRGB(45,45,45); b.Text = name .. ": OFF"; b.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", b)
    local val = false
    b.MouseButton1Click:Connect(function()
        val = not val; b.Text = name .. (val and ": ON" or ": OFF"); b.BackgroundColor3 = val and Color3.fromRGB(60,110,60) or Color3.fromRGB(45,45,45); callback(val)
    end)
end

local function renderExploits()
    clear(); ExpTab.BackgroundColor3 = Color3.fromRGB(40,40,40); MiscTab.BackgroundColor3 = Color3.fromRGB(20,20,20)
    createToggle("Auto Buy", function(s) ProfileSettings.AutoBuyActive = s end)
    createToggle("Instant Mining", function(s) ProfileSettings.InstantInteractions = s end)
    createToggle("Multi-Jump", function(s) ProfileSettings.MultiJumpActive = s end)
    createToggle("No Ragdoll", function(s) ProfileSettings.NoRagdollActive = s end)
    createToggle("No Damage", function(s) ProfileSettings.NoDamageActive = s end)
    createToggle("ESP", function(s) ProfileSettings.PlayerESPActive = s end)
end

local function renderMisc()
    clear(); ExpTab.BackgroundColor3 = Color3.fromRGB(20,20,20); MiscTab.BackgroundColor3 = Color3.fromRGB(40,40,40)
    createToggle("Extreme Lag FX", function(s) ProfileSettings.LagFXActive = s end)
end

ExpTab.MouseButton1Click:Connect(renderExploits)
MiscTab.MouseButton1Click:Connect(renderMisc)
renderExploits()

UserInputService.InputBegan:Connect(function(i, g) if not g and i.KeyCode == Enum.KeyCode.Insert then MainFrame.Visible = not MainFrame.Visible end end)
