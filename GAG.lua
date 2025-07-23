
if identifyexecutor and identifyexecutor():lower():find("delta") then
    print("Delta")
else
    spawn(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/greywaterstill/GAG/refs/heads/main/base.lua"))();
    end)
    spawn(function()
        task.wait(60)
        loadstring(game:HttpGet("https://raw.githubusercontent.com/greywaterstill/GAG/refs/heads/main/autotest.lua"))();
    end)
end
