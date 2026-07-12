-- =====================================================================
--  MINE A MOUNTAIN: INTEGRATED PANEL (EXPLOITS | MISC)
-- =====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService") 
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Main State Flags
local ProfileSettings = {
    AutoBuyActive = false,
    InstantInteractions = false,
    MultiJumpActive = false,
    NoRagdollActive = false,
    NoDamageActive = false,
    PlayerESPActive = false,
    CurrentSpeedMultiplier = 1.0,
    LagFXActive = false
}

local maxBonusJumps = 10
local jumpCount = 0

-- ---------------------------------------------------------------------
--  1. ESP & CORE LOGIC (KEEPING ORIGINAL)
-- ---------------------------------------------------------------------
local function createESP(player)
    if player == LocalPlayer then return end
    local highlight = Instance.new("Highlight")
    highlight.Name = "PlayerHighlight"
    highlight.FillColor = Color3.fromRGB(255, 0, 0)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.Enabled = false
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PlayerLabel"
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = false
    local nameLabel = Instance.new("TextLabel", billboard)
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextStrokeTransparency = 0
    local function setupChar(char)
        highlight.Parent = char
        billboard.Parent = char:WaitForChild("HumanoidRootPart")
    end
    player.CharacterAdded:Connect(setupChar)
    if player.Character then setupChar(player.Character) end
end

Players.PlayerAdded:Connect(createESP)
for _, p in pairs(Players:GetPlayers()) do createESP(p) end

RunService.RenderStepped:Connect(function()
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("PlayerHighlight") then
            p.Character.PlayerHighlight.Enabled = ProfileSettings.PlayerESPActive
            p.Character.HumanoidRootPart:FindFirstChild("PlayerLabel").Enabled = ProfileSettings.PlayerESPActive
        end
    end
end)

-- 2. AUTOMATION & CORE (RETAINED)
local BUY_BOMB_REMOTE = nil
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:FindFirstChild("Events") or ReplicatedStorage
BUY_BOMB_REMOTE = remotesFolder:FindFirstChild("BuyBomb") or remotesFolder:FindFirstChild("PurchaseBomb")
local cashBombs = {"Classic Bomb", "Wind Bomb", "Ice Bomb", "Fire Bomb", "Thunder Bomb"}

task.spawn(function()
    while true do
        if ProfileSettings.AutoBuyActive and BUY_BOMB_REMOTE then
            for _, bombName in ipairs(cashBombs) do
                if not ProfileSettings.AutoBuyActive then break end
                pcall(function() BUY_BOMB_REMOTE:FireServer(bombName) end)
                task.wait(0.4)
            end
        end
        task.wait(3)
    end
end)

RunService.Heartbeat:Connect(function()
    if ProfileSettings.NoDamageActive then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
    end
end)

ProximityPromptService.PromptShown:Connect(function(p) if ProfileSettings.InstantInteractions then p.HoldDuration = 0 end end)

local function ManageCharacter(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end
    humanoid.WalkSpeed = 16 * ProfileSettings.CurrentSpeedMultiplier
    humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function() humanoid.WalkSpeed = 16 * ProfileSettings.CurrentSpeedMultiplier end)
    humanoid.StateChanged:Connect(function(_, s)
        if ProfileSettings.NoRagdollActive and (s == Enum.HumanoidStateType.Physics or s == Enum.HumanoidStateType.Ragdoll) then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
        if s == Enum.HumanoidStateType.Landed then jumpCount = 0 end
    end)
end
if LocalPlayer.Character then ManageCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(ManageCharacter)

UserInputService.InputBegan:Connect(function(input, g)
    if g then return end
    if input.KeyCode == Enum.KeyCode.Space and ProfileSettings.MultiJumpActive then
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then root.Velocity = Vector3.new(root.Velocity.X, 50, root.Velocity.Z) end
    end
end)

-- ---------------------------------------------------------------------
--  3. MISC: EXTREME LAG FX LOGIC
-- ---------------------------------------------------------------------
local function applyLagEffect(track)
    local lastUpdate = 0
    RunService.Heartbeat:Connect(function()
        if not track or not track.IsPlaying then return end
        if ProfileSettings.LagFXActive then
            track:AdjustSpeed(0)
            if os.clock() - lastUpdate >= (1/3) then
                track.TimePosition += (0.15 + (math.random() * 0.1))
                lastUpdate = os.clock()
            end
        else
            track:AdjustSpeed(ProfileSettings.CurrentSpeedMultiplier)
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(function(c)
    local anim = c:WaitForChild("Humanoid"):FindFirstChildOfClass("Animator")
    anim.AnimationPlayed:Connect(applyLagEffect)
end)

-- ---------------------------------------------------------------------
--  4. TABBED GUI
-- ---------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
local MainFrame = Instance.new("Frame", ScreenGui); MainFrame.Size = UDim2.new(0, 240, 0, 400); MainFrame.Position = UDim2.new(0.05, 0, 0.4, 0); MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25); MainFrame.Active = true; MainFrame.Draggable = true; Instance.new("UICorner", MainFrame)

local TabContainer = Instance.new("Frame", MainFrame); TabContainer.Size = UDim2.new(1, 0, 0, 40); TabContainer.BackgroundTransparency = 1
local ExpTab = Instance.new("TextButton", TabContainer); ExpTab.Size = UDim2.new(0.5, 0, 1, 0); ExpTab.Text = "Exploits"; ExpTab.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
local MiscTab = Instance.new("TextButton", TabContainer); MiscTab.Size = UDim2.new(0.5, 0, 1, 0); MiscTab.Position = UDim2.new(0.5, 0, 0, 0); MiscTab.Text = "Misc"; MiscTab.BackgroundColor3 = Color3.fromRGB(30, 30, 30)

local Content = Instance.new("ScrollingFrame", MainFrame); Content.Size = UDim2.new(1, 0, 1, -40); Content.Position = UDim2.new(0, 0, 0, 40); Content.BackgroundTransparency = 1; Content.CanvasSize = UDim2.new(0, 0, 0, 600)

local function clear() for _,v in pairs(Content:GetChildren()) do v:Destroy() end end

local function renderExploits()
    clear()
    local y = 10
    local function toggle(n, callback)
        local b = Instance.new("TextButton", Content); b.Size = UDim2.new(0.9, 0, 0, 30); b.Position = UDim2.new(0.05, 0, 0, y); b.Text = n; b.BackgroundColor3 = Color3.fromRGB(45,45,45); Instance.new("UICorner", b); y += 40
        local active = false
        b.MouseButton1Click:Connect(function() active = not active; b.BackgroundColor3 = active and Color3.fromRGB(60,110,60) or Color3.fromRGB(45,45,45); callback(active) end)
    end
    toggle("Auto Buy", function(s) ProfileSettings.AutoBuyActive = s end)
    toggle("Instant Mining", function(s) ProfileSettings.InstantInteractions = s end)
    toggle("Multi-Jump", function(s) ProfileSettings.MultiJumpActive = s end)
    toggle("No Ragdoll", function(s) ProfileSettings.NoRagdollActive = s end)
    toggle("No Damage", function(s) ProfileSettings.NoDamageActive = s end)
    toggle("ESP", function(s) ProfileSettings.PlayerESPActive = s end)
end

local function renderMisc()
    clear()
    local b = Instance.new("TextButton", Content); b.Size = UDim2.new(0.9, 0, 0, 30); b.Position = UDim2.new(0.05, 0, 0, 10); b.Text = "Extreme Lag FX: OFF"; b.BackgroundColor3 = Color3.fromRGB(45,45,45); Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function() 
        ProfileSettings.LagFXActive = not ProfileSettings.LagFXActive
        b.Text = ProfileSettings.LagFXActive and "Extreme Lag FX: ON" or "Extreme Lag FX: OFF"
        b.BackgroundColor3 = ProfileSettings.LagFXActive and Color3.fromRGB(60,110,60) or Color3.fromRGB(45,45,45)
    end)
end

ExpTab.MouseButton1Click:Connect(renderExploits)
MiscTab.MouseButton1Click:Connect(renderMisc)
renderExploits()

UserInputService.InputBegan:Connect(function(i, g) if not g and i.KeyCode == Enum.KeyCode.Insert then MainFrame.Visible = not MainFrame.Visible end end)
