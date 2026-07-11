-- =====================================================================
--  MINE A MOUNTAIN: PRO COLLECTOR EDITION (1000 Stud Radius)
-- =====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local ProfileSettings = {
    LuckBoostPercent = 0,
    MagnetActive = false,
    SelectedRarity = "All", -- Default to All
    PullCount = 50,         -- Increased capacity
    PullRadius = 1000       -- Requested 1000 stud radius
}

-- Refined Remote Discovery
local PICKUP_REMOTE = ReplicatedStorage:FindFirstChild("CrystalPickupJuice") 
    or ReplicatedStorage:FindFirstChild("Events"):FindFirstChild("CrystalPickupJuice")
local LUCK_BOOST_REMOTE = ReplicatedStorage:FindFirstChild("LuckBoost")

-- ---------------------------------------------------------------------
--  ROBUST RARITY CHECKER
-- ---------------------------------------------------------------------
local function IsValidRarity(obj)
    if ProfileSettings.SelectedRarity == "All" then return true end
    
    local target = ProfileSettings.SelectedRarity:lower()
    local name = obj.Name:lower()
    local parentName = obj.Parent and obj.Parent.Name:lower() or ""
    
    -- Check both name and parent for the rarity keyword
    return name:find(target) or parentName:find(target)
end

-- ---------------------------------------------------------------------
--  SYNCED COLLECTION ENGINE
-- ---------------------------------------------------------------------
local function ExecuteCollection()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not PICKUP_REMOTE then return end

    local collected = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if collected >= ProfileSettings.PullCount then break end
        
        -- Filter for crystal-like objects
        local isCrystal = obj:IsA("BasePart") and (obj.Name:lower():find("crystal") or obj.Parent and obj.Parent.Name:lower():find("crystal"))
        
        if isCrystal and IsValidRarity(obj) then
            local dist = (obj.Position - root.Position).Magnitude
            if dist <= ProfileSettings.PullRadius then
                pcall(function()
                    -- Fire remote to register pickup on server
                    PICKUP_REMOTE:FireServer(obj)
                end)
                collected = collected + 1
                task.wait(0.05) -- Slightly faster execution
            end
        end
    end
end

-- ---------------------------------------------------------------------
--  UI UPDATES
-- ---------------------------------------------------------------------
-- (Ensure your existing UI calls this function)
-- When the Rarity Dropdown selection changes, update:
-- ProfileSettings.SelectedRarity = "Common" -- (example)

-- To update Luck:
-- if LUCK_BOOST_REMOTE then LUCK_BOOST_REMOTE:FireServer(ProfileSettings.LuckBoostPercent) end
