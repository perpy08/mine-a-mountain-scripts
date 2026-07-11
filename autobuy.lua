-- =====================================================================
--  MINE A MOUNTAIN: GLOBAL SCAN EDITION (Anti-Nil-Error)
-- =====================================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local ProfileSettings = {
    LuckBoostPercent = 0,
    SelectedRarity = "All",
    PullCount = 50,
    PullRadius = 1000
}

-- GLOBAL REMOTE SCANNER: Finds the remote regardless of path
local function FindRemote(name)
    for _, obj in ipairs(game:GetDescendants()) do
        if obj.Name == name and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
            return obj
        end
    end
    return nil
end

local PICKUP_REMOTE = FindRemote("CrystalPickupJuice")
local LUCK_BOOST_REMOTE = FindRemote("LuckBoost")

-- ---------------------------------------------------------------------
--  COLLECTION LOGIC
-- ---------------------------------------------------------------------
local function IsValidRarity(obj)
    if ProfileSettings.SelectedRarity == "All" then return true end
    local target = ProfileSettings.SelectedRarity:lower()
    return obj.Name:lower():find(target) or (obj.Parent and obj.Parent.Name:lower():find(target))
end

local function ExecuteCollection()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root or not PICKUP_REMOTE then return end

    local collected = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if collected >= ProfileSettings.PullCount then break end
        
        local isCrystal = obj:IsA("BasePart") and (obj.Name:lower():find("crystal") or (obj.Parent and obj.Parent.Name:lower():find("crystal")))
        
        if isCrystal and IsValidRarity(obj) then
            if (obj.Position - root.Position).Magnitude <= ProfileSettings.PullRadius then
                pcall(function() PICKUP_REMOTE:FireServer(obj) end)
                collected = collected + 1
                task.wait(0.05)
            end
        end
    end
end

-- ---------------------------------------------------------------------
--  GUI SETUP
-- ---------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 250, 0, 300)
MainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Draggable = true

-- Rarity Dropdown
local RarityButton = Instance.new("TextButton", MainFrame)
RarityButton.Size = UDim2.new(0.9, 0, 0, 40)
RarityButton.Position = UDim2.new(0.05, 0, 0, 20)
RarityButton.Text = "Rarity: All"
RarityButton.MouseButton1Click:Connect(function()
    local rarities = {"All", "Common", "Rare", "Epic", "Legendary", "Mythic"}
    local current = table.find(rarities, ProfileSettings.SelectedRarity)
    local nextR = rarities[(current % #rarities) + 1]
    ProfileSettings.SelectedRarity = nextR
    RarityButton.Text = "Rarity: " .. nextR
end)

-- Luck Boost Input
local BoostBox = Instance.new("TextBox", MainFrame)
BoostBox.Size = UDim2.new(0.9, 0, 0, 40)
BoostBox.Position = UDim2.new(0.05, 0, 0, 80)
BoostBox.PlaceholderText = "Luck Boost %"
BoostBox.FocusLost:Connect(function()
    local val = tonumber(BoostBox.Text)
    if val and LUCK_BOOST_REMOTE then
        pcall(function() LUCK_BOOST_REMOTE:FireServer(val) end)
    end
end)

-- Pull Button
local PullBtn = Instance.new("TextButton", MainFrame)
PullBtn.Size = UDim2.new(0.9, 0, 0, 40)
PullBtn.Position = UDim2.new(0.05, 0, 0, 140)
PullBtn.Text = "PULL CRYSTALS"
PullBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 120)
PullBtn.MouseButton1Click:Connect(ExecuteCollection)

-- Toggle Visibility
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Insert then
        MainFrame.Visible = not MainFrame.Visible
    end
end)
