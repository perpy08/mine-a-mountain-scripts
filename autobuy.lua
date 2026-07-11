-- =====================================================================
--  MINE A MOUNTAIN: FULL INTEGRATED HUB (V2)
-- =====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer and LocalPlayer:GetMouse()

local ProfileSettings = {
    AutoBuyActive = false,
    InstantInteractions = false,
    FastHitting = false,
    MultiJumpActive = false,
    MagnetActive = false,
    CurrentSpeedMultiplier = 1.0,
    CrystalBoostValue = 0,
    SelectedRarity = "All",
    PullCount = 50,
    PullRadius = 1000
}

local jumpCount = 0
local maxBonusJumps = 10

-- Remote Setup
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 3) or ReplicatedStorage:WaitForChild("Events", 3) or ReplicatedStorage
local BUY_BOMB_REMOTE = remotesFolder:FindFirstChild("BuyBomb") or remotesFolder:FindFirstChild("PurchaseBomb")
local MINE_REMOTE = remotesFolder:FindFirstChild("CrystalMining") or remotesFolder:FindFirstChild("CrystalMiningController")
local LUCK_REMOTE = remotesFolder:FindFirstChild("CrystalLuck") or remotesFolder:FindFirstChild("CrystalBoost")

-- ---------------------------------------------------------------------
--  AUTOMATION ENGINE
-- ---------------------------------------------------------------------
task.spawn(function()
    while true do
        if ProfileSettings.AutoBuyActive and BUY_BOMB_REMOTE then
            local cashBombs = {"Classic Bomb", "Wind Bomb", "Ice Bomb", "Fire Bomb", "Thunder Bomb"}
            for _, b in ipairs(cashBombs) do
                pcall(function() BUY_BOMB_REMOTE:FireServer(b) end)
                task.wait(0.4)
            end
        end
        task.wait(3)
    end
end)

task.spawn(function()
    while true do
        if ProfileSettings.MagnetActive then
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local pulled = 0
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if pulled >= ProfileSettings.PullCount then break end
                    if obj:IsA("BasePart") and (obj.Name:lower():find("crystal") or obj.Name:lower():find("lod")) then
                        if (obj.Position - root.Position).Magnitude <= ProfileSettings.PullRadius then
                            local target = ProfileSettings.SelectedRarity:lower()
                            if target == "all" or obj.Name:lower():find(target) or (obj.Parent and obj.Parent.Name:lower():find(target)) then
                                obj.CFrame = root.CFrame * CFrame.new(0, -2, -2)
                                pulled += 1
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)

-- ---------------------------------------------------------------------
--  CHARACTER LOGIC (Speed/Jump)
-- ---------------------------------------------------------------------
local function ManageCharacter(char)
    local hum = char:WaitForChild("Humanoid")
    hum.WalkSpeed = 16 * ProfileSettings.CurrentSpeedMultiplier
    hum.StateChanged:Connect(function(_, s) if s == Enum.HumanoidStateType.Landed then jumpCount = 0 end end)
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
--  UI (Shortened for brevity, use your existing button logic)
-- ---------------------------------------------------------------------
-- [Keep your original createToggle function here]
-- [Keep your Slider logic here, but remember to set the radius range to 1000]

print("Hub Loaded with Integrated Magnet & Features")
