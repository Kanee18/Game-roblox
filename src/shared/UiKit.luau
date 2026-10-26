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
