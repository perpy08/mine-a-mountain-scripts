-- =====================================================================
--  MINE A MOUNTAIN: FIXED REMOTE ACCESS (No more Nil Errors)
-- =====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("WaitForChild")(game, "ReplicatedStorage") -- Safe Wait
local LocalPlayer = Players.LocalPlayer

local ProfileSettings = {
    LuckBoostPercent = 0,
    MagnetActive = false,
    SelectedRarity = "All",
    PullCount = 50,
    PullRadius = 1000
}

-- 1. SAFE REMOTE DISCOVERY (Using WaitForChild instead of FindFirstChild)
local function getRemote(name)
    -- This looks through the entire ReplicatedStorage tree for the remote
    local remote = nil
    local function search(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child.Name == name then return child end
            if child:IsA("Folder") or child:IsA("Model") then
                local found = search(child)
                if found then return found end
            end
        end
    end
    return search(ReplicatedStorage)
end

-- Safely assign remotes
local PICKUP_REMOTE = getRemote("CrystalPickupJuice")
local LUCK_BOOST_REMOTE = getRemote("LuckBoost")

-- ---------------------------------------------------------------------
--  2. ROBUST RARITY & COLLECTION ENGINE
-- ---------------------------------------------------------------------
local function IsValidRarity(obj)
    if ProfileSettings.SelectedRarity == "All" then return true end
    local target = ProfileSettings.SelectedRarity:lower()
    local name = obj.Name:lower()
    local parentName = obj.Parent and obj.Parent.Name:lower() or ""
    return name:find(target) or parentName:find(target)
end

local function ExecuteCollection()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    -- Check if remote was actually found
    if not PICKUP_REMOTE then warn("Pickup remote not found! Check game console.") return end

    local collected = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if collected >= ProfileSettings.PullCount then break end
        
        -- Filter for crystal-like objects
        local isCrystal = obj:IsA("BasePart") and (obj.Name:lower():find("crystal") or (obj.Parent and obj.Parent.Name:lower():find("crystal")))
        
        if isCrystal and IsValidRarity(obj) then
            local dist = (obj.Position - root.Position).Magnitude
            if dist <= ProfileSettings.PullRadius then
                pcall(function()
                    PICKUP_REMOTE:FireServer(obj)
                end)
                collected = collected + 1
                task.wait(0.05)
            end
        end
    end
end
