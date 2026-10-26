--[[
	UiKit (ModuleScript)
	Lokasi: ReplicatedStorage > Shared > UiKit

	Pembantu kecil untuk membuat UI lewat script. Dipakai oleh HUD, Panel Guru,
	Videotron, papan nama portal, dan nanti UI soal di Tahap 1-4.

	Contoh:
		local frame = UiKit.new("Frame", { Size = UDim2.fromScale(1, 1), Parent = gui }, {
			UiKit.corner(12),
			UiKit.stroke(),
		})
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(script.Parent.GameConfig)

local Theme = GameConfig.Theme

local UiKit = {}
UiKit.Theme = Theme

local function merge(defaults: { [string]: any }, overrides: { [string]: any }?): { [string]: any }
	local result = table.clone(defaults)
	if overrides then
		for key, value in overrides do
			result[key] = value
		end
	end
	return result
end

-- Membuat Instance dengan properti dan anak sekaligus. Parent diatur paling akhir.
function UiKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local target: any = instance
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				target[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

-- radius: angka (piksel) atau UDim (mis. UDim.new(1, 0) untuk lingkaran)
function UiKit.corner(radius: (number | UDim)?): UICorner
	local cornerRadius = if typeof(radius) == "UDim" then radius else UDim.new(0, (radius :: number?) or 12)
	return UiKit.new("UICorner", { CornerRadius = cornerRadius })
end

function UiKit.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UiKit.new("UIStroke", {
		Color = color or Theme.Gold,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Garis tepi pada huruf (bukan pada kotak).
function UiKit.textStroke(color: Color3?, thickness: number?): UIStroke
	return UiKit.new("UIStroke", {
		Color = color or Theme.Night,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function UiKit.padding(pixels: number): UIPadding
	local size = UDim.new(0, pixels)
	return UiKit.new("UIPadding", {
		PaddingTop = size,
		PaddingBottom = size,
		PaddingLeft = size,
		PaddingRight = size,
	})
end

function UiKit.gradient(first: Color3, second: Color3, rotation: number?): UIGradient
	return UiKit.new("UIGradient", {
		Color = ColorSequence.new(first, second),
		Rotation = rotation or 90,
	})
end

local LABEL_DEFAULTS = {
	BackgroundTransparency = 1,
	Font = Theme.Font,
	TextColor3 = Theme.White,
	TextSize = 20,
	TextWrapped = true,
}

function UiKit.label(props: { [string]: any }?, children: { Instance }?): TextLabel
	return UiKit.new("TextLabel", merge(LABEL_DEFAULTS, props), children)
end

local BUTTON_DEFAULTS = {
	AutoButtonColor = true,
	BackgroundColor3 = Theme.Gold,
	Font = Theme.Font,
	TextColor3 = Theme.Ink,
	TextSize = 18,
	Text = "",
}

function UiKit.button(props: { [string]: any }?, children: { Instance }?): TextButton
	local button = UiKit.new("TextButton", merge(BUTTON_DEFAULTS, props), children)
	if not button:FindFirstChildOfClass("UICorner") then
		local corner = UiKit.corner(10)
		corner.Parent = button
	end
	return button
end

function UiKit.tween(
	instance: Instance,
	duration: number,
	goals: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local tween = TweenService:Create(instance, info, goals)
	tween:Play()
	return tween
end

--------------------------------------------------------------------------------
-- Tata letak responsif (HP vs PC)
--------------------------------------------------------------------------------
-- Perangkat sentuh (HP/tablet) tanpa keyboard.
function UiKit.IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Layar "ringkas": HP, atau jendela yang pendek (tinggi < 500 piksel).
function UiKit.IsCompact(): boolean
	if UiKit.IsTouch() then
		return true
	end
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 0
	return height > 50 and height < 500
end

-- Jalankan callback(compact) sekarang dan setiap kali mode tata letak berubah
-- (layar diputar, jendela diubah ukurannya, keyboard dicolok, dll).
function UiKit.OnLayout(callback: (boolean) -> ())
	local last: boolean? = nil
	local function update()
		local compact = UiKit.IsCompact()
		if compact ~= last then
			last = compact
			callback(compact)
		end
	end
	local viewportConnection: RBXScriptConnection? = nil
	local function watchCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		local camera = workspace.CurrentCamera
		if camera then
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(update)
	watchCamera()
end

-- Panel info tahap (soal, status). Di PC berada di bawah-tengah. Di HP pindah ke
-- kanan-atas supaya tidak menutupi karakter, joystick, dan tombol lompat, sedikit
-- diperkecil, dan bisa diciutkan dengan mengetuk judulnya.
--   local hud = UiKit.hudPanel(screenGui, warnaTahap)
--   hud.Header.Text = "..."; local soal = hud.Line(1, { Font = ..., TextSize = 18 })
--   hud.Expand()  -- buka lagi saat ada soal baru
-- Isi tambahan (mis. baris tombol) diletakkan di hud.Body.
function UiKit.hudPanel(parent: Instance, accent: Color3)
	local constraint = UiKit.new("UISizeConstraint", {})
	local frame = UiKit.new("Frame", {
		Name = "PanelTahap",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Night,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = parent,
	}, {
		UiKit.corner(16),
		UiKit.stroke(accent, 2),
		UiKit.padding(10),
		constraint,
		UiKit.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local scale = UiKit.new("UIScale", { Parent = frame })
	local header = UiKit.new("TextButton", {
		Name = "Judul",
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Font = Theme.Font,
		TextSize = 18,
		TextColor3 = accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		LayoutOrder = 1,
		Parent = frame,
	})
	local arrow = UiKit.label({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 28, 0.5, 0),
		Size = UDim2.fromOffset(26, 22),
		Text = "▾",
		TextSize = 18,
		TextColor3 = Theme.Cream,
		Visible = false,
		Parent = header,
	})
	UiKit.new("UIPadding", { PaddingRight = UDim.new(0, 28), Parent = header })
	local body = UiKit.new("Frame", {
		Name = "Isi",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = frame,
	}, {
		UiKit.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local panel = { Frame = frame, Header = header, Body = body, Collapsed = false, Compact = false }

	function panel.Line(order: number, props: { [string]: any }): TextLabel
		return UiKit.label(merge({
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
			Parent = body,
		}, props))
	end

	local function setCollapsed(collapsed: boolean)
		panel.Collapsed = collapsed
		body.Visible = not collapsed
		arrow.Text = if collapsed then "▸" else "▾"
	end

	function panel.Expand()
		if panel.Collapsed then
			setCollapsed(false)
		end
	end

	header.Activated:Connect(function()
		if panel.Compact then
			setCollapsed(not panel.Collapsed)
		end
	end)

	UiKit.OnLayout(function(compact)
		panel.Compact = compact
		arrow.Visible = compact
		if compact then
			frame.AnchorPoint = Vector2.new(1, 0)
			frame.Position = UDim2.new(1, -8, 0, 4)
			frame.Size = UDim2.new(0.46, 0, 0, 0)
			constraint.MinSize = Vector2.new(250, 0)
			constraint.MaxSize = Vector2.new(430, math.huge)
			scale.Scale = 0.9
		else
			frame.AnchorPoint = Vector2.new(0.5, 1)
			frame.Position = UDim2.new(0.5, 0, 1, -12)
			frame.Size = UDim2.new(0.55, 0, 0, 0)
			constraint.MinSize = Vector2.new(320, 0)
			constraint.MaxSize = Vector2.new(680, math.huge)
			scale.Scale = 1
			setCollapsed(false)
		end
	end)

	return panel
end

-- Kartu pop-up di tengah layar (hasil jawaban, finish, dll). Ketuk/klik untuk menutup.
--   local card = UiKit.card(screenGui, "HasilJawaban")
--   local title = card.Line(1, { TextSize = 34 })   -- baris teks, urut menurut angka
--   card.Stroke.Color = ...; card.Show(4); card.Hide()
function UiKit.card(parent: Instance, name: string)
	local stroke = UiKit.stroke(Theme.Gold, 4)
	local constraint = UiKit.new("UISizeConstraint", {})
	local frame = UiKit.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(0.5, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Cream,
		Active = true, -- ketukan pada kartu tidak tembus ke dunia (mis. tidak ikut menembak)
		Visible = false,
		Parent = parent,
	}, {
		UiKit.corner(18),
		stroke,
		UiKit.padding(16),
		constraint,
		UiKit.new("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})
	local card = {
		Frame = frame,
		Stroke = stroke,
		Scale = UiKit.new("UIScale", { Parent = frame }),
		BaseScale = 1,
		Token = 0,
	}
	local closeHint = UiKit.label({
		Size = UDim2.new(1, 0, 0, 16),
		Font = Theme.FontBody,
		TextSize = 13,
		TextColor3 = Theme.InkSoft,
		Text = "Ketuk untuk menutup",
		LayoutOrder = 999,
		Parent = frame,
	})

	function card.Line(order: number, props: { [string]: any }): TextLabel
		return UiKit.label(merge({
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextColor3 = Theme.Ink,
			LayoutOrder = order,
			Parent = frame,
		}, props))
	end
	function card.Show(duration: number)
		card.Token += 1
		local token = card.Token
		frame.Visible = true
		card.Scale.Scale = card.BaseScale * 0.85
		UiKit.tween(card.Scale, 0.35, { Scale = card.BaseScale }, Enum.EasingStyle.Back)
		task.delay(duration, function()
			if card.Token == token then
				frame.Visible = false
			end
		end)
	end
	function card.Hide()
		card.Token += 1
		frame.Visible = false
	end

	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			card.Hide()
		end
	end)

	UiKit.OnLayout(function(compact)
		-- Di HP: lebih kecil dan lebih lebar relatif terhadap layar.
		card.BaseScale = if compact then 0.8 else 1
		card.Scale.Scale = card.BaseScale
		frame.Size = UDim2.new(if compact then 0.62 else 0.5, 0, 0, 0)
		constraint.MinSize = Vector2.new(if compact then 260 else 300, 0)
		constraint.MaxSize = Vector2.new(if compact then 520 else 560, math.huge)
		closeHint.Visible = compact
	end)

	return card
end

-- Percikan partikel sekali jadi di sebuah posisi (efek tembakan, ledakan kecil).
function UiKit.burst(position: Vector3, color: Color3, amount: number?)
	local anchor = UiKit.new("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one,
		CFrame = CFrame.new(position),
		Parent = workspace,
	})
	local emitter = UiKit.new("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(color),
		LightEmission = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.2),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 0,
		Parent = anchor,
	})
	if RunService:IsClient() then
		emitter:Emit(amount or 50)
	else
		-- Di server: nyalakan sebentar (perubahan properti pasti terlihat di semua client).
		emitter.Rate = (amount or 50) * 5
		task.delay(0.2, function()
			emitter.Enabled = false
		end)
	end
	game:GetService("Debris"):AddItem(anchor, 2)
end

-- 12500 -> "12.500" (format angka Indonesia)
function UiKit.formatNumber(value: number): string
	local digits = tostring(math.floor(math.abs(value)))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if grouped:sub(1, 1) == "." then
		grouped = grouped:sub(2)
	end
	return if value < 0 then "-" .. grouped else grouped
end

return UiKit
