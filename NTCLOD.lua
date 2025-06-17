local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local function applyCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end


if playerGui:FindFirstChild("NoticeUI") then
	playerGui:FindFirstChild("NoticeUI"):Destroy()
end

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NoticeUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Container frame
local container = Instance.new("Frame")
container.Size = UDim2.new(0, 400, 0, 220)
container.Position = UDim2.new(0.5, -200, 0.5, -110)
container.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
container.BorderSizePixel = 0
applyCorner(container, 12)
container.Parent = screenGui

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "⚠️ Notice"
title.Font = Enum.Font.GothamBold
title.TextSize = 26
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Parent = container

-- Message label 1
local message1 = Instance.new("TextLabel")
message1.Size = UDim2.new(1, -40, 0, 30)
message1.Position = UDim2.new(0, 20, 0, 50)
message1.BackgroundTransparency = 1
message1.Text = "Duplication only works in public servers."
message1.TextWrapped = true
message1.Font = Enum.Font.Gotham
message1.TextSize = 18
message1.TextColor3 = Color3.fromRGB(200, 200, 200)
message1.TextXAlignment = Enum.TextXAlignment.Center
message1.Parent = container

-- Message label 2
local message2 = message1:Clone()
message2.Text = "Please switch to a public server"
message2.Position = UDim2.new(0, 20, 0, 100)
message2.Parent = container

-- Message label 3
local message3 = message1:Clone()
message3.Text = "for the dupe tab to show."
message3.Position = UDim2.new(0, 20, 0, 135)
message3.Parent = container

-- Okay Button
local okayBtn = Instance.new("TextButton")
okayBtn.Size = UDim2.new(0, 100, 0, 35)
okayBtn.Position = UDim2.new(0.5, -50, 1, -50)
okayBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
okayBtn.Text = "Okay"
okayBtn.Font = Enum.Font.GothamBold
okayBtn.TextSize = 18
okayBtn.TextColor3 = Color3.new(1, 1, 1)
applyCorner(okayBtn, 6)
okayBtn.Parent = container

local function showLoadingBar()
	container:Destroy()

	local loadingFrame = Instance.new("Frame")
	loadingFrame.Size = UDim2.new(0, 400, 0, 100)
	loadingFrame.Position = UDim2.new(0.5, -200, 0.5, -50)
	loadingFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	loadingFrame.BorderSizePixel = 0
	applyCorner(loadingFrame, 12)
	loadingFrame.Parent = screenGui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 30)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Text = "Loading... 0%"
	label.Parent = loadingFrame

	local progressBarBG = Instance.new("Frame")
	progressBarBG.Size = UDim2.new(0.9, 0, 0, 20)
	progressBarBG.Position = UDim2.new(0.05, 0, 0, 50)
	progressBarBG.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	progressBarBG.BorderSizePixel = 0
	applyCorner(progressBarBG, 8)
	progressBarBG.Parent = loadingFrame

	local progressBar = Instance.new("Frame")
	progressBar.Size = UDim2.new(0, 0, 1, 0)
	progressBar.Position = UDim2.new(0, 0, 0, 0)
	progressBar.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
	progressBar.BorderSizePixel = 0
	applyCorner(progressBar, 8)
	progressBar.Parent = progressBarBG


	task.spawn(function()
		local duration = 15 -- total time in seconds
		local steps = 60 -- number of steps/updates
		local timePerStep = duration / steps

		local currentProgress = 0
		local goal = 1 -- 100%

		for i = 1, steps do
			-- Distribute progress randomly across steps
			local remainingSteps = steps - i + 1
			local remainingProgress = goal - currentProgress
			local maxStep = remainingProgress / remainingSteps * 2
			local stepProgress = math.clamp(math.random() * maxStep, 0, remainingProgress)

			currentProgress += stepProgress

			-- Tween the progress bar
			TweenService:Create(progressBar, TweenInfo.new(timePerStep, Enum.EasingStyle.Linear), {
				Size = UDim2.new(currentProgress, 0, 1, 0)
			}):Play()

			local percent = math.floor(currentProgress * 100)
			label.Text = "Loading... " .. tostring(percent) .. "%"

			task.wait(timePerStep)
		end

		label.Text = "Complete!"
		task.wait(0.5)
		screenGui:Destroy()

		getgenv().uiSize = UDim2.fromOffset(580, 400)

		loadstring(game:HttpGet("https://raw.githubusercontent.com/ArdyBotzz/NatHub/refs/heads/master/NatHub.lua"))();
	end)
end

-- Connect button
okayBtn.MouseButton1Click:Connect(showLoadingBar)
