-- StarterPlayer/StarterPlayerScripts/Controllers/SurveyController.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local SubmitSurveyEvent = ReplicatedStorage:WaitForChild("SubmitSurvey")

local SurveyController = {}

-- UI 参照
local surveyGui
local openButton
local formFrame
local overlay

-- 回答状態
local currentAnswers = {
	fun = 0,
	difficulty = "",
	replay = "",
	comment = ""
}

-- UIコンポーネント作成のユーティリティ
local function createRoundedFrame(name, parent, size, pos, color, radius)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size or UDim2.new(1, 0, 1, 0)
	frame.Position = pos or UDim2.new(0, 0, 0, 0)
	frame.BackgroundColor3 = color or Color3.new(1, 1, 1)
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UDim.new(0, 12)
	corner.Parent = frame

	return frame
end

local function createStyledText(text, parent, size, pos, fontSize, alignment)
	local label = Instance.new("TextLabel")
	label.Size = size or UDim2.new(1, 0, 0, 30)
	label.Position = pos or UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(40, 40, 40)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = fontSize or 18
	label.TextXAlignment = alignment or Enum.TextXAlignment.Center
	label.Parent = parent
	return label
end

----------------------------------------------------------------
-- UIセットアップ
----------------------------------------------------------------
function SurveyController.Init()
	print("[SurveyController] Init")

	-- すでに存在すれば削除
	if playerGui:FindFirstChild("SurveyGui") then
		playerGui.SurveyGui:Destroy()
	end

	surveyGui = Instance.new("ScreenGui")
	surveyGui.Name = "SurveyGui"
	surveyGui.ResetOnSpawn = false
	surveyGui.Enabled = true
	surveyGui.DisplayOrder = 100 -- 高い優先度
	surveyGui.Parent = playerGui

	-- 1. オープンボタン (右上)
	-- スマホでも押しやすいよう、最低サイズ（Pixel）を保ちつつScaleで配置
	openButton = Instance.new("TextButton")
	openButton.Name = "OpenButton"
	openButton.Size = UDim2.new(0, 50, 0, 50) -- 固定ピクセルで押しやすさを確保
	openButton.Position = UDim2.new(1, -20, 0, 60)
	openButton.AnchorPoint = Vector2.new(1, 0)
	openButton.BackgroundColor3 = Color3.fromRGB(241, 196, 15) -- Gold
	openButton.Text = "💬"
	openButton.TextSize = 25
	openButton.Parent = surveyGui

	-- 小さい画面（スマホ等）ではボタンを少し大きく、大きい画面では適切なサイズに
	local btnConstraint = Instance.new("UISizeConstraint")
	btnConstraint.MinSize = Vector2.new(45, 45)
	btnConstraint.MaxSize = Vector2.new(60, 60)
	btnConstraint.Parent = openButton

	Instance.new("UICorner", openButton).CornerRadius = UDim.new(0.5, 0)
	local bStroke = Instance.new("UIStroke", openButton)
	bStroke.Thickness = 2
	bStroke.Color = Color3.new(1, 1, 1)

	-- 2. オーバーレイ
	overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1 -- 最初は非表示
	overlay.Active = true
	overlay.Visible = false
	overlay.Parent = surveyGui

	-- 3. メインフォーム (Scaleベースに変更)
	-- 幅80%、高さ70%を目指しつつ、UISizeConstraintで制限
	formFrame = createRoundedFrame("FormFrame", overlay, UDim2.new(0.8, 0, 0.7, 0), UDim2.new(0.5, 0, 0.5, 0), Color3.fromRGB(250, 250, 250), UDim.new(0, 20))
	formFrame.AnchorPoint = Vector2.new(0.5, 0.5)

	-- サイズ制限 (PCだと大きすぎず、スマホだと小さすぎないように)
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(300, 400)
	sizeConstraint.MaxSize = Vector2.new(500, 650)
	sizeConstraint.Parent = formFrame

	local title = createStyledText("アンケート", formFrame, UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0, 10), 24)

	-- コンテンツコンテナ
	local content = Instance.new("ScrollingFrame")
	content.Size = UDim2.new(1, -40, 1, -120)
	content.Position = UDim2.new(0, 20, 0, 60)
	content.BackgroundTransparency = 1
	content.ScrollBarThickness = 8
	content.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
	content.CanvasSize = UDim2.new(0, 0, 0, 520)
	content.Parent = formFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 15)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content

	-- Q1: Fun (1-5 Buttons)
	local funGroup = Instance.new("Frame")
	funGroup.Size = UDim2.new(1, 0, 0, 70)
	funGroup.BackgroundTransparency = 1
	funGroup.Parent = content

	createStyledText("楽しさは？ (1-5)", funGroup, UDim2.new(1, 0, 0, 25), UDim2.new(0, 0, 0, 0), 18, Enum.TextXAlignment.Left)

	local funButtons = Instance.new("Frame")
	funButtons.Size = UDim2.new(1, 0, 0, 40)
	funButtons.Position = UDim2.new(0, 0, 0, 30)
	funButtons.BackgroundTransparency = 1
	funButtons.Parent = funGroup

	local funLayout = Instance.new("UIListLayout")
	funLayout.FillDirection = Enum.FillDirection.Horizontal
	funLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	funLayout.Padding = UDim.new(0, 10)
	funLayout.Parent = funButtons

	local starButtons = {}
	for i = 1, 5 do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 40, 0, 40)
		btn.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
		btn.Text = tostring(i)
		btn.Font = Enum.Font.FredokaOne
		btn.TextSize = 18
		btn.Parent = funButtons
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

		btn.Activated:Connect(function()
			currentAnswers.fun = i
			for j, b in ipairs(starButtons) do
				b.BackgroundColor3 = (j <= i) and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(220, 220, 220)
			end
		end)
		table.insert(starButtons, btn)
	end

	-- Q2: Difficulty (Easy / Normal / Hard)
	local function createRadioGroup(titleText, options, key)
		local group = Instance.new("Frame")
		group.Size = UDim2.new(1, 0, 0, 70)
		group.BackgroundTransparency = 1
		group.Parent = content

		createStyledText(titleText, group, UDim2.new(1, 0, 0, 25), UDim2.new(0, 0, 0, 0), 18, Enum.TextXAlignment.Left)

		local optsFrame = Instance.new("Frame")
		optsFrame.Size = UDim2.new(1, 0, 0, 35)
		optsFrame.Position = UDim2.new(0, 0, 0, 30)
		optsFrame.BackgroundTransparency = 1
		optsFrame.Parent = group

		local hLayout = Instance.new("UIListLayout")
		hLayout.FillDirection = Enum.FillDirection.Horizontal
		hLayout.Padding = UDim.new(0, 5)
		hLayout.Parent = optsFrame

		local buttons = {}
		local numOptions = #options
		for _, opt in ipairs(options) do
			local btn = Instance.new("TextButton")
			-- 選択肢の数に応じて幅を自動調整 (Scaleを使用)
			btn.Size = UDim2.new(1/numOptions, -5, 1, 0)
			btn.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
			btn.Text = opt.label
			btn.TextSize = 14
			btn.Parent = optsFrame
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

			-- テキストがはみ出さないように調整
			local textConstraint = Instance.new("UITextSizeConstraint")
			textConstraint.MaxTextSize = 14
			textConstraint.MinTextSize = 8
			textConstraint.Parent = btn

			btn.Activated:Connect(function()
				currentAnswers[key] = opt.value
				for _, b in ipairs(buttons) do
					b.BackgroundColor3 = (b.Name == opt.value) and Color3.fromRGB(52, 152, 219) or Color3.fromRGB(220, 220, 220)
					b.TextColor3 = (b.Name == opt.value) and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
				end
			end)
			btn.Name = opt.value
			table.insert(buttons, btn)
		end
	end

	createRadioGroup("難易度は？", {
		{label = "かんたん", value = "Easy"},
		{label = "ちょうどいい", value = "JustRight"},
		{label = "むずかしい", value = "Hard"}
	}, "difficulty")

	createRadioGroup("またやりたい？", {
		{label = "はい", value = "Yes"},
		{label = "いいえ", value = "No"}
	}, "replay")

	-- Q4: Comment
	local commentGroup = Instance.new("Frame")
	commentGroup.Size = UDim2.new(1, 0, 0, 100)
	commentGroup.BackgroundTransparency = 1
	commentGroup.Parent = content

	createStyledText("コメント (任意)", commentGroup, UDim2.new(1, 0, 0, 25), UDim2.new(0, 0, 0, 0), 18, Enum.TextXAlignment.Left)

	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(1, 0, 0, 70)
	textBox.Position = UDim2.new(0, 0, 0, 30)
	textBox.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
	textBox.Text = ""
	textBox.PlaceholderText = "ここに入力してください..."
	textBox.TextSize = 14 -- 読みやすいサイズに設定
	textBox.TextWrapped = true
	textBox.TextYAlignment = Enum.TextYAlignment.Top
	textBox.TextXAlignment = Enum.TextXAlignment.Left -- 左寄せで読みやすく
	textBox.ClearTextOnFocus = false
	textBox.Parent = commentGroup
	Instance.new("UICorner", textBox).CornerRadius = UDim.new(0, 8)

	textBox:GetPropertyChangedSignal("Text"):Connect(function()
		currentAnswers.comment = textBox.Text
	end)

	-- 下部ボタン (スクロール内へ移動)
	local submitBtn = createRoundedFrame("SubmitButton", content, UDim2.new(1, 0, 0, 45), nil, Color3.fromRGB(46, 204, 113))
	local submitLabel = createStyledText("送信する", submitBtn, UDim2.new(1, 0, 1, 0))
	submitLabel.TextColor3 = Color3.new(1, 1, 1)

	local submitTrigger = Instance.new("TextButton")
	submitTrigger.Size = UDim2.new(1, 0, 1, 0)
	submitTrigger.BackgroundTransparency = 1
	submitTrigger.Text = ""
	submitTrigger.Parent = submitBtn

	-- 閉じるボタン
	local closeIcon = Instance.new("TextButton")
	closeIcon.Name = "CloseIcon"
	closeIcon.Size = UDim2.new(0, 40, 0, 40)
	closeIcon.Position = UDim2.new(1, -5, 0, 5)
	closeIcon.AnchorPoint = Vector2.new(1, 0)
	closeIcon.BackgroundTransparency = 1
	closeIcon.Text = "✕"
	closeIcon.TextSize = 24
	closeIcon.TextColor3 = Color3.fromRGB(150, 150, 150)
	closeIcon.Parent = formFrame

	-- CanvasSize の調整 (コンテンツが増えたため)
	content.CanvasSize = UDim2.new(0, 0, 0, 520)

	----------------------------------------------------------------
	-- イベント管理
	----------------------------------------------------------------
	local function toggleForm(show)
		if show then
			overlay.Visible = true
			TweenService:Create(overlay, TweenInfo.new(0.3), {BackgroundTransparency = 0.5}):Play()
		else
			local tween = TweenService:Create(overlay, TweenInfo.new(0.3), {BackgroundTransparency = 1})
			tween:Play()
			tween.Completed:Wait()
			overlay.Visible = false
		end
	end

	openButton.Activated:Connect(function()
		toggleForm(true)
	end)

	closeIcon.Activated:Connect(function()
		toggleForm(false)
	end)

	submitTrigger.Activated:Connect(function()
		-- バリデーション
		if currentAnswers.fun == 0 or currentAnswers.difficulty == "" or currentAnswers.replay == "" then
			submitLabel.Text = "未回答の項目があります"
			submitBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
			task.wait(1.5)
			submitLabel.Text = "送信する"
			submitBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
			return
		end

		submitLabel.Text = "送信中..."
		submitTrigger.Active = false

		SubmitSurveyEvent:FireServer(currentAnswers)

		task.wait(1)
		submitLabel.Text = "送信完了！"
		task.wait(1)
		toggleForm(false)

		-- リセット
		currentAnswers = {fun = 0, difficulty = "", replay = "", comment = ""}
		textBox.Text = ""
		submitLabel.Text = "送信する"
		submitTrigger.Active = true
		for _, b in ipairs(starButtons) do b.BackgroundColor3 = Color3.fromRGB(220, 220, 220) end
		-- ラジオボタンのリセットは省略
	end)
end

return SurveyController
