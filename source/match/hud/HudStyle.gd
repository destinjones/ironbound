extends RefCounted

# Shared look of the in-match HUD: the brand palette (see assets/ui/theme/ironbound.tres,
# built by tools/ui/BuildTheme.gd), resource icons and colours, and small builders for
# the folding panel headers, the stat cells used by several panels and the command card's
# slots (their size, hotkey tag and caption), and the sizes of the bottom bar.

const ICONS = "res://assets/ui/icons/hud/"
const BG = Color("#14110d")
const SURFACE = Color("#1f1a14")
const SURFACE_2 = Color("#2a231b")
const LINE = Color("#3d3326")
const FG = Color("#efe4cf")
const MUTED = Color("#b5a68c")
const ACCENT = Color("#f2a93b")
const RUST = Color("#d0643a")
const OASIS = Color("#4cc1b0")
const GOOD = Color("#8fbf5a")
const WARN = Color("#f2a93b")
const BAD = Color("#e0603f")
# health reads in thirds (StarCraft II's steps): GOOD at or above 2/3, WARN down to 1/3, BAD below
const HEALTH_WARN_BELOW = 2.0 / 3.0
const HEALTH_BAD_BELOW = 1.0 / 3.0
# the command card: square slots, 80 px on a HUD 900 px tall or more, 64 below, 4 px apart
const SLOT_FULL_PX = 80
const SLOT_COMPACT_PX = 64
const COMPACT_BELOW_PX = 900
const SLOT_GAP = 4
const BAR_MARGIN = 8
const CARD_ROWS = 3
const CARD_COLUMNS = 4
# a unit waiting in a factory's queue, on the selection card in the bottom bar
const QUEUE_FULL_PX = 56
const QUEUE_COMPACT_PX = 44
# brand colours of the commodities; data/resources.json colours paint the 3D deposits
# (oil there is almost black, unreadable on a dark bar)
const RESOURCE_COLORS = {
	"timber": Color("#8fbf5a"),
	"iron": Color("#a9b3bf"),
	"copper": Color("#e08a4f"),
	"oil": Color("#8b7bd8"),
}


static func icon(name):
	var path = ICONS + name + ".svg"
	return load(path) if ResourceLoader.exists(path) else null


static func resource_icon(resource):
	return icon(resource)


static func resource_color(resource):
	if resource in RESOURCE_COLORS:
		return RESOURCE_COLORS[resource]
	return Constants.Match.Resources.COLORS.get(resource, FG)


static func health_color(fraction):
	"""the colour of a health bar, strip or number at `fraction` of full health"""
	if fraction < HEALTH_BAD_BELOW:
		return BAD
	if fraction < HEALTH_WARN_BELOW:
		return WARN
	return GOOD


static func slot_px(viewport_height):
	"""the side of a command card slot for a HUD this tall (after ui_scale), read at _ready"""
	return SLOT_FULL_PX if viewport_height >= COMPACT_BELOW_PX else SLOT_COMPACT_PX


static func bar_height(viewport_height):
	"""the bottom bar: three slot rows, the gaps between them and a margin above and below"""
	return CARD_ROWS * slot_px(viewport_height) + (CARD_ROWS - 1) * SLOT_GAP + 2 * BAR_MARGIN


static func card_width(viewport_height, columns = CARD_COLUMNS):
	"""the command card's width: `columns` slots and the gaps between them"""
	return columns * slot_px(viewport_height) + (columns - 1) * SLOT_GAP


static func queue_px(viewport_height):
	"""the side of a production queue element for a HUD this tall, read as each element is added"""
	return QUEUE_FULL_PX if viewport_height >= COMPACT_BELOW_PX else QUEUE_COMPACT_PX


static func unit_icon(entry):
	"""a unit's picture from its data entry: its own icon, else the generic vehicle or block"""
	var path = entry.get("icon", "")
	if path is String and path != "" and ResourceLoader.exists(path):
		return load(path)
	return icon("structure_generic" if entry.get("category") == "structure" else "unit_generic")


static func hotkey_tag(text):
	"""the key of a slot, small and amber in its top left corner"""
	var label = Label.new()
	label.name = "Hotkey"
	label.text = text
	label.theme_type_variation = "NumberLabel"
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", ACCENT)
	# the outline keeps the amber letter readable on a lit (amber) slot
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 5
	label.offset_top = 1
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func caption(text, slot = SLOT_FULL_PX):
	"""the name along the bottom of a slot, outlined so it reads over any icon; a point
	smaller in a 64 px slot, where "Hold position" fits at 10 px and not at 11"""
	var label = Label.new()
	label.name = "Caption"
	label.text = text
	label.add_theme_font_size_override("font_size", 11 if slot >= SLOT_FULL_PX else 10)
	label.add_theme_color_override("font_color", FG)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 1
	label.offset_right = -1
	label.offset_bottom = -1
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func icon_rect(texture, size = 20):
	var rect = TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func margin(node, horizontal = 10, vertical = 8):
	"""wraps the panel's content in even padding and returns the margin container"""
	var container = MarginContainer.new()
	container.add_theme_constant_override("margin_left", horizontal)
	container.add_theme_constant_override("margin_right", horizontal)
	container.add_theme_constant_override("margin_top", vertical)
	container.add_theme_constant_override("margin_bottom", vertical)
	node.add_child(container)
	return container


static func header(icon_name, title_label, fold_button):
	"""a panel header: icon, title (stencil face) and a chevron that folds the panel"""
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var texture = icon(icon_name)
	if texture != null:
		row.add_child(icon_rect(texture, 20))
	title_label.theme_type_variation = "HeaderLabel"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text = true
	row.add_child(title_label)
	if fold_button != null:
		style_fold_button(fold_button)
		row.add_child(fold_button)
	return row


static func style_fold_button(button):
	button.flat = false
	button.theme_type_variation = "HeaderButton"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(26, 26)
	button.expand_icon = false
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER


static func set_folded_icon(button, folded):
	button.text = ""
	button.icon = icon("chevron_right" if folded else "chevron_down")
	button.tooltip_text = TranslationServer.translate("HUD_EXPAND" if folded else "HUD_COLLAPSE")


static func stat_cell(caption_text, value_label, tooltip = ""):
	"""a small caption over a number, for the stat grids"""
	var cell = VBoxContainer.new()
	cell.add_theme_constant_override("separation", -2)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.tooltip_text = tooltip
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	var caption_label = Label.new()
	caption_label.text = caption_text
	caption_label.theme_type_variation = "MutedLabel"
	caption_label.add_theme_font_size_override("font_size", 11)
	caption_label.uppercase = true
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(caption_label)
	value_label.theme_type_variation = "NumberLabel"
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(value_label)
	return cell


static func small(label, size = 13, muted = false):
	label.add_theme_font_size_override("font_size", size)
	if muted:
		label.theme_type_variation = "MutedLabel"
	return label
