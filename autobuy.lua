-- =====================================================================
--  MINE A MOUNTAIN: UNIVERSAL SAFE AUTOMATION PANEL
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
    CrystalESPActive = false,
    SelectedRarity = "None",
    CurrentSpeedMultiplier = 1.0
}

local maxBonusJumps = 10
local jumpCount = 0

-- ---------------------------------------------------------------------
--  1. ESP LOGIC
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

    if ProfileSettings.CrystalESPActive then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:GetAttribute("Rarity") == ProfileSettings.SelectedRarity then
                if not obj:FindFirstChild("CrystalHighlight") then
                    local h = Instance.new("Highlight", obj)
                    h.Name = "CrystalHighlight"
                    h.FillColor = Color3.fromRGB(0, 255, 255)
                end
                obj.CrystalHighlight.Enabled = true
            elseif obj:IsA("Model") and obj:FindFirstChild("CrystalHighlight") then
                obj.CrystalHighlight.Enabled = false
            end
        end
    end
end)

-- ---------------------------------------------------------------------
--  2. AUTOMATION & CORE LOGIC
-- ---------------------------------------------------------------------

local BUY_BOMB_REMOTE = nil
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 3) or ReplicatedStorage:WaitForChild("Events", 3) or ReplicatedStorage
if remotesFolder then BUY_BOMB_REMOTE = remotesFolder:FindFirstChild("BuyBomb") or remotesFolder:FindFirstChild("PurchaseBomb") end
local cashBombs = {"Classic Bomb", "Wind Bomb", "Ice Bomb", "Fire Bomb", "Thunder Bomb"}

task.spawn(function()
    while true do
        if ProfileSettings.AutoBuyActive and BUY_BOMB_REMOTE then
            for _, bombName in ipairs(cashBombs) do
                if not ProfileSettings.AutoBuyActive then break end
                pcall(function() if BUY_BOMB_REMOTE:IsA("RemoteFunction") then BUY_BOMB_REMOTE:InvokeServer(bombName) else BUY_BOMB_REMOTE:FireServer(bombName) end end)
                task.wait(0.4)
            end
        end
        task.wait(3)
    end
end)

RunService.Heartbeat:Connect(function()
    if ProfileSettings.NoDamageActive then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
    end
end)

ProximityPromptService.PromptShown:Connect(function(prompt) if ProfileSettings.InstantInteractions then prompt.HoldDuration = 0 end end)

local function ManageCharacter(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end
    humanoid.WalkSpeed = 16 * ProfileSettings.CurrentSpeedMultiplier
    humanoid.StateChanged:Connect(function(_, s) if ProfileSettings.NoRagdollActive and s == Enum.HumanoidStateType.Ragdoll then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end end)
end
if LocalPlayer.Character then ManageCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(ManageCharacter)

UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Space and ProfileSettings.MultiJumpActive then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hum and root and (hum:GetState() == Enum.HumanoidStateType.Freefall or hum:GetState() == Enum.HumanoidStateType.Jumping) and jumpCount < maxBonusJumps then
            jumpCount += 1; root.Velocity = Vector3.new(root.Velocity.X, hum.JumpPower, root.Velocity.Z)
        end
    end
end)

-- ---------------------------------------------------------------------
--  3. GRAPHICAL USER INTERFACE (ScrollingFrame)
-- ---------------------------------------------------------------------

local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui")); ScreenGui.Name = "MineAMountainPanel"
local MainFrame = Instance.new("Frame", ScreenGui); MainFrame.Size = UDim2.new(0, 240, 0, 400); MainFrame.Position = UDim2.new(0.05, 0, 0.4, 0); MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25); MainFrame.Active = true; MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local Scroll = Instance.new("ScrollingFrame", MainFrame); Scroll.Size = UDim2.new(1, 0, 1, -40); Scroll.Position = UDim2.new(0, 0, 0, 40); Scroll.BackgroundTransparency = 1; Scroll.CanvasSize = UDim2.new(0, 0, 2, 0); Scroll.ScrollBarThickness = 6

local function createToggle(name, y, callback)
    local b = Instance.new("TextButton", Scroll); b.Size = UDim2.new(0.9, 0, 0, 35); b.Position = UDim2.new(0.05, 0, 0, y); b.BackgroundColor3 = Color3.fromRGB(45, 45, 45); b.Text = name .. ": OFF"; b.TextColor3 = Color3.fromRGB(220, 80, 80)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    local on = false
    b.MouseButton1Click:Connect(function() on = not on; b.BackgroundColor3 = on and Color3.fromRGB(60, 110, 60) or Color3.fromRGB(45, 45, 45); b.Text = name .. (on and ": ON" or ": OFF"); callback(on) end)
end

-- Dropdown
local RarityFrame = Instance.new("Frame", Scroll); RarityFrame.Size = UDim2.new(0.9, 0, 0, 35); RarityFrame.Position = UDim2.new(0.05, 0, 0, 355); RarityFrame.BackgroundTransparency = 1
local RarityBtn = Instance.new("TextButton", RarityFrame); RarityBtn.Size = UDim2.new(1, 0, 1, 0); RarityBtn.Text = "Select Rarity"; RarityBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45); RarityBtn.Parent = RarityFrame
RarityBtn.MouseButton1Click:Connect(function() for _, c in pairs(RarityFrame:GetChildren()) do if c:IsA("TextButton") and c ~= RarityBtn then c.Visible = not c.Visible end end end)
for _, r in ipairs({"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"}) do
    local opt = Instance.new("TextButton", RarityFrame); opt.Size = UDim2.new(1, 0, 0, 30); opt.Position = UDim2.new(0, 0, 1, (#RarityFrame:GetChildren()-2)*30); opt.Text = r; opt.Visible = false; opt.BackgroundColor3 = Color3.fromRGB(60, 60, 60); opt.Parent = RarityFrame
    opt.MouseButton1Click:Connect(function() ProfileSettings.SelectedRarity = r; RarityBtn.Text = "Rarity: " .. r; for _, c in pairs(RarityFrame:GetChildren()) do if c ~= RarityBtn then c.Visible = false end end end)
end

-- Toggles
createToggle("Auto Buy Bombs", 55, function(s) ProfileSettings.AutoBuyActive = s end)
createToggle("Instant E-Mining", 105, function(s) ProfileSettings.InstantInteractions = s end)
createToggle("Infinite Multi-Jump", 155, function(s) ProfileSettings.MultiJumpActive = s end)
createToggle("No Ragdoll", 205, function(s) ProfileSettings.NoRagdollActive = s end)
createToggle("No Damage", 255, function(s) ProfileSettings.NoDamageActive = s end)
createToggle("Player ESP", 305, function(s) ProfileSettings.PlayerESPActive = s end)
createToggle("Crystal ESP", 400, function(s) ProfileSettings.CrystalESPActive = s end)

UserInputService.InputBegan:Connect(function(i, g) if not g and i.KeyCode == Enum.KeyCode.Insert then MainFrame.Visible = not MainFrame.Visible end end)
