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

-- Kartu pop-up di tengah layar (hasil jawaban, finish, dll).
--   local card = UiKit.card(screenGui, "HasilJawaban")
--   local title = card.Line(1, { TextSize = 34 })   -- baris teks, urut menurut angka
--   card.Stroke.Color = ...; card.Show(4); card.Hide()
function UiKit.card(parent: Instance, name: string)
	local stroke = UiKit.stroke(Theme.Gold, 4)
	local frame = UiKit.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(0.5, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Cream,
		Visible = false,
		Parent = parent,
	}, {
		UiKit.corner(18),
		stroke,
		UiKit.padding(16),
		UiKit.new("UISizeConstraint", { MinSize = Vector2.new(300, 0), MaxSize = Vector2.new(560, math.huge) }),
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
		Token = 0,
	}
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
		card.Scale.Scale = 0.85
		UiKit.tween(card.Scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
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
