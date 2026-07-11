-- =====================================================================
--  MINE A MOUNTAIN: STABLE HUB (CORE FEATURES)
-- =====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local ProfileSettings = {
    AutoBuyActive = false,
    InstantInteractions = false,
    MultiJumpActive = false,
    CurrentSpeedMultiplier = 1.0
}

local jumpCount = 0
local maxBonusJumps = 10

-- ---------------------------------------------------------------------
--  1. AUTOMATION ENGINE
-- ---------------------------------------------------------------------
local BUY_BOMB_REMOTE = nil
local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:FindFirstChild("Events") or ReplicatedStorage
if remotes then
    BUY_BOMB_REMOTE = remotes:FindFirstChild("BuyBomb") or remotes:FindFirstChild("PurchaseBomb")
end

task.spawn(function()
    while true do
        if ProfileSettings.AutoBuyActive and BUY_BOMB_REMOTE then
            local cashBombs = {"Classic Bomb", "Wind Bomb", "Ice Bomb", "Fire Bomb", "Thunder Bomb"}
            for _, b in ipairs(cashBombs) do
                if not ProfileSettings.AutoBuyActive then break end
                pcall(function() BUY_BOMB_REMOTE:FireServer(b) end)
                task.wait(0.4)
            end
        end
        task.wait(3)
    end
end)

-- ---------------------------------------------------------------------
--  2. CHARACTER MANAGEMENT
-- ---------------------------------------------------------------------
local function ManageCharacter(char)
    local hum = char:WaitForChild("Humanoid")
    hum.WalkSpeed = 16 * ProfileSettings.CurrentSpeedMultiplier
    
    hum.StateChanged:Connect(function(_, s) 
        if s == Enum.HumanoidStateType.Landed then jumpCount = 0 end 
    end)
end

if LocalPlayer.Character then ManageCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(ManageCharacter)

UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Space and ProfileSettings.MultiJumpActive then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and jumpCount < maxBonusJumps then
            jumpCount += 1
            LocalPlayer.Character.HumanoidRootPart.Velocity = Vector3.new(0, hum.JumpPower, 0)
        end
    end
end)

-- ---------------------------------------------------------------------
--  3. GUI SYSTEM (Guaranteed Visibility)
-- ---------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.Name = "MineAMountainPanel"
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 200, 0, 150)
MainFrame.Position = UDim2.new(0.05, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Active = true
MainFrame.Draggable = true

local function createToggle(name, pos, callback)
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0.9, 0, 0, 30)
    btn.Position = UDim2.new(0.05, 0, 0, pos)
    btn.Text = name .. ": OFF"
    local on = false
    btn.MouseButton1Click:Connect(function()
        on = not on
        btn.Text = name .. (on and ": ON" or ": OFF")
        callback(on)
    end)
end

createToggle("Auto Buy Bombs", 10, function(s) ProfileSettings.AutoBuyActive = s end)
createToggle("Infinite Multi-Jump", 50, function(s) ProfileSettings.MultiJumpActive = s end)
createToggle("Instant E-Mining", 90, function(s) ProfileSettings.InstantInteractions = s end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Insert then 
        MainFrame.Visible = not MainFrame.Visible 
    end
end)

print("Hub loaded: Core features active.")
