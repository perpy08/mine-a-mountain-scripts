-- =====================================================================
--  MINE A MOUNTAIN: ULTIMATE SAFE-LOAD EDITION
-- =====================================================================

local function InitializeScript()
    -- Wait until the game is fully loaded
    if not game:IsLoaded() then game.Loaded:Wait() end
    
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local LocalPlayer = Players.LocalPlayer
    
    local ProfileSettings = {
        SelectedRarity = "All",
        PullCount = 50,
        PullRadius = 1000
    }

    -- LOCALIZED SCANNER: Inside the function, game is now guaranteed to exist
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

    -- -----------------------------------------------------------------
    --  CORE LOGIC
    -- -----------------------------------------------------------------
    local function ExecuteCollection()
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not root or not PICKUP_REMOTE then return end

        local collected = 0
        for _, obj in ipairs(workspace:GetDescendants()) do
            if collected >= ProfileSettings.PullCount then break end
            
            local isCrystal = obj:IsA("BasePart") and (obj.Name:lower():find("crystal") or (obj.Parent and obj.Parent.Name:lower():find("crystal")))
            
            if isCrystal then
                -- Rarity Filter
                local matches = (ProfileSettings.SelectedRarity == "All") or 
                                (obj.Name:lower():find(ProfileSettings.SelectedRarity:lower()) or 
                                (obj.Parent and obj.Parent.Name:lower():find(ProfileSettings.SelectedRarity:lower())))
                
                if matches and (obj.Position - root.Position).Magnitude <= ProfileSettings.PullRadius then
                    pcall(function() PICKUP_REMOTE:FireServer(obj) end)
                    collected = collected + 1
                    task.wait(0.05)
                end
            end
        end
    end

    -- -----------------------------------------------------------------
    --  GUI
    -- -----------------------------------------------------------------
    local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.Size = UDim2.new(0, 250, 0, 200)
    MainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
    MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    MainFrame.Draggable = true

    local PullBtn = Instance.new("TextButton", MainFrame)
    PullBtn.Size = UDim2.new(0.9, 0, 0, 50)
    PullBtn.Position = UDim2.new(0.05, 0, 0, 50)
    PullBtn.Text = "PULL CRYSTALS"
    PullBtn.MouseButton1Click:Connect(ExecuteCollection)
end

-- Wrap in pcall to prevent line 1 crashes
pcall(InitializeScript)
