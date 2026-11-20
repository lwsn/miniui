local _, ns = ...

-- Shared look for action-style buttons (action bars, bags): black plate,
-- cropped icon inset by 1px, Blizzard's empty bag slot art for empty slots,
-- flat state overlays, and outlined text on the icon. The plate's 1px edge is the
-- border; neighbouring buttons overlap it (ns.layout.buttonSpacing).
--
-- Sets button.icon, .cooldown, .HotKey, .Count and .Name. Works on Button
-- and CheckButton; the checked overlay is only used by CheckButtons.

local EMPTY = [[Interface\PaperDoll\UI-Backpack-EmptySlot]]

function ns.SkinButton(button)
	local px = ns.Pixels(button, 1)

	local plate = button:CreateTexture(nil, 'BACKGROUND', nil, -8)
	plate:SetAllPoints()
	plate:SetColorTexture(0, 0, 0, 1)
	button.plate = plate -- the 1px border; recoloured for states like autocast

	local empty = button:CreateTexture(nil, 'BACKGROUND', nil, -7)
	empty:SetPoint('TOPLEFT', px, -px)
	empty:SetPoint('BOTTOMRIGHT', -px, px)
	empty:SetTexture(EMPTY)
	empty:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- cropped like icons

	local icon = button:CreateTexture(nil, 'BORDER')
	icon:SetPoint('TOPLEFT', px, -px)
	icon:SetPoint('BOTTOMRIGHT', -px, px)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.icon = icon

	local cooldown = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
	cooldown:SetAllPoints(icon)
	cooldown:SetDrawEdge(false)
	button.cooldown = cooldown

	-- States, drawn over the icon.
	local function Overlay(r, g, b, a)
		local texture = button:CreateTexture()
		texture:SetTexture(ns.media.texture)
		texture:SetVertexColor(r, g, b, a)
		texture:SetAllPoints(icon)
		return texture
	end
	button:SetHighlightTexture(Overlay(1, 1, 1, 0.15))
	button:SetPushedTexture(Overlay(1, 1, 1, 0.25))
	if button.SetCheckedTexture then
		button:SetCheckedTexture(Overlay(1, 0.85, 0.4, 0.25))
	end

	-- Text above the cooldown spiral, outlined like aura text.
	local overlay = CreateFrame('Frame', nil, button)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(cooldown:GetFrameLevel() + 1)

	local hotkey = ns.CreateText(overlay, 11, 'semibold', 'OUTLINE')
	hotkey:SetPoint('TOPRIGHT', icon, 'TOPRIGHT', -1, -1)
	hotkey:SetJustifyH('RIGHT')
	button.HotKey = hotkey

	local count = ns.CreateText(overlay, 12, 'semibold', 'OUTLINE')
	count:SetPoint('BOTTOMRIGHT', icon, 'BOTTOMRIGHT', -1, 1)
	button.Count = count

	local name = ns.CreateText(overlay, 10, 'regular', 'OUTLINE')
	name:SetPoint('BOTTOMLEFT', icon, 'BOTTOMLEFT', 1, 1)
	name:SetPoint('BOTTOMRIGHT', icon, 'BOTTOMRIGHT', -1, 1)
	name:SetWordWrap(false)
	button.Name = name
end

-- Short keybind labels: 'SHIFT-MOUSEWHEELUP' -> 'SWU'.
local KEY_ABBREVIATIONS = {
	{ 'ALT%-', 'A' }, { 'CTRL%-', 'C' }, { 'SHIFT%-', 'S' }, { 'META%-', 'M' },
	{ 'MOUSEWHEELUP', 'WU' }, { 'MOUSEWHEELDOWN', 'WD' },
	{ 'MIDDLEMOUSE', 'M3' }, { 'BUTTON(%d+)', 'M%1' },
	{ 'NUMPAD', 'N' }, { 'SPACE', 'Sp' },
}

-- Sets the hotkey text from the first key bound to button.binding.
function ns.UpdateHotkey(button)
	local key = GetBindingKey(button.binding)
	if key then
		for _, rule in ipairs(KEY_ABBREVIATIONS) do
			key = key:gsub(rule[1], rule[2])
		end
	end
	button.HotKey:SetText(key or '')
end
