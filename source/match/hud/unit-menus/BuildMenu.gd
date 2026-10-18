extends GridContainer

# Production or construction buttons generated from the unit definitions in res://data/
# (see GameData.producible_by). Structures are placed with the blueprint, units are queued
# in the selected producer. Buttons stay disabled until the city reaches the required tier.
# Each button shows its cost and, for the first slots, a hotkey (letters no other order
# or the camera uses), which works while the menu is on screen. The slots fill from the
# top left; the constructor's menu is 6 columns wide so all its structures show at once
# (never paged), the others are 4 like the command card. Slots are HudStyle.slot_px.
# Only the units of the player's faction are listed (see Factions.gd); the buttons are
# made again when the menu is shown for a player of another faction.

const GameData = preload("res://source/data-model/GameData.gd")
const HudStyle = preload("res://source/match/hud/HudStyle.gd")
const RichTooltipButton = preload("res://source/match/hud/RichTooltipButton.gd")
const Tooltips = preload("res://source/match/hud/Tooltips.gd")
const SLOTS = 18
const HOTKEYS = [KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_J, KEY_N, KEY_M, KEY_C]

@export var producer_id = ""

var unit = null

var _buttons = {}  # scene path -> button
var _hotkeys = {}  # keycode -> button
var _faction = null  # faction id the buttons were made for
var _slot = HudStyle.SLOT_FULL_PX


func _ready():
	columns = 6 if producer_id == "worker" else 4
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot = HudStyle.slot_px(get_viewport().get_visible_rect().size.y)
	_make_buttons(_faction_of(_player()))


func _make_buttons(faction_id):
	_faction = faction_id
	_buttons.clear()
	_hotkeys.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var entries = GameData.producible_by(producer_id, faction_id)
	# without a faction everything is allowed: the units the game had before factions
	# (no "factions" field, or not data-only) come first so they keep their slots
	entries.sort_custom(
		func(a, b):
			return (
				[_faction_only(a, faction_id), int(a.get("tier", 1)), a["id"]]
				< [_faction_only(b, faction_id), int(b.get("tier", 1)), b["id"]]
			)
	)
	entries = entries.slice(0, SLOTS)
	for index in range(entries.size()):
		var hotkey = HOTKEYS[index] if index < HOTKEYS.size() else KEY_NONE
		add_child(_make_button(entries[index], hotkey))


func _unhandled_key_input(event):
	if not event.pressed or event.echo or not is_visible_in_tree():
		return
	if event.ctrl_pressed or event.alt_pressed or event.shift_pressed or event.meta_pressed:
		return
	var button = _hotkeys.get(event.physical_keycode)
	if button == null or button.disabled or not button.is_visible_in_tree():
		return
	get_viewport().set_input_as_handled()
	button.pressed.emit()


static func _faction_only(entry, faction_id):
	return faction_id == "" and "factions" in entry and "base" in entry


static func _faction_of(player):
	var faction_id = player.get("faction") if player != null else null
	return faction_id if faction_id is String else ""


func _process(_delta):
	var player = _player()
	if player != null and _faction_of(player) != _faction:
		_make_buttons(_faction_of(player))
	for scene_path in _buttons:
		var button = _buttons[scene_path]
		var disabled = player == null or not player.can_produce(scene_path)
		if button.disabled != disabled:
			button.disabled = disabled
			button.modulate = Color(1, 1, 1, 0.45) if disabled else Color.WHITE


func _player():
	if unit != null and is_instance_valid(unit):
		return unit.player
	var selected = get_tree().get_nodes_in_group("selected_units").filter(
		func(a_unit): return a_unit.is_in_group("controlled_units")
	)
	return selected[0].player if not selected.is_empty() else null


func _make_button(entry, hotkey = KEY_NONE):
	var button = RichTooltipButton.new()  # the hover card: Tooltips.build_item
	button.tip_maker = func(): return Tooltips.build_item(entry, _player(), hotkey)
	button.theme_type_variation = "SlotButton"
	button.custom_minimum_size = Vector2(_slot, _slot)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = describe(entry)
	if hotkey != KEY_NONE:
		_hotkeys[hotkey] = button
		button.tooltip_text += "\n" + tr("HOTKEY").format([OS.get_keycode_string(hotkey)])
	# the anatomy scales with the slot: icon on top, cost row, name along the bottom
	var icon = TextureRect.new()
	icon.texture = HudStyle.unit_icon(entry)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = round(0.15 * _slot)
	icon.offset_top = 4
	icon.offset_right = -round(0.15 * _slot)
	icon.offset_bottom = -round(0.40 * _slot)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if "icon_tint" in entry:
		icon.modulate = Color(entry["icon_tint"])
	button.add_child(icon)
	button.add_child(_cost_row(entry.get("cost", {}), _slot))
	# the name under the icon, so buttons can be told apart without hovering
	button.add_child(HudStyle.caption(tr(entry["name"]), _slot))
	var tier_label = Label.new()
	tier_label.text = "T{0}".format([int(entry.get("tier", 1))]) if entry.get("tier", 1) > 1 else ""
	tier_label.theme_type_variation = "NumberLabel"
	tier_label.add_theme_font_size_override("font_size", 11)
	tier_label.add_theme_color_override("font_color", HudStyle.MUTED)
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tier_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	tier_label.offset_right = -4
	tier_label.offset_top = 1
	tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(tier_label)
	if hotkey != KEY_NONE:
		button.add_child(HudStyle.hotkey_tag(OS.get_keycode_string(hotkey)))
	button.pressed.connect(_on_button_pressed.bind(entry))
	_buttons[entry["scene"]] = button
	return button


static func _cost_row(cost, slot):
	"""the price as small commodity icons and amounts, above the name; smaller in a 64 px
	slot so three amounts still fit"""
	var compact = slot < HudStyle.SLOT_FULL_PX
	var row = HBoxContainer.new()
	row.name = "Cost"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 1)
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -round(0.39 * slot)
	row.offset_bottom = -round(0.21 * slot)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for resource in Constants.Match.Resources.ALL:
		var amount = int(cost.get(resource, 0))
		if amount <= 0:
			continue
		row.add_child(HudStyle.icon_rect(HudStyle.resource_icon(resource), 9 if compact else 11))
		var label = Label.new()
		label.text = str(amount)
		label.theme_type_variation = "NumberLabel"
		label.add_theme_font_size_override("font_size", 9 if compact else 10)
		label.add_theme_color_override("font_color", HudStyle.resource_color(resource))
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		var gap = Control.new()
		gap.custom_minimum_size = Vector2(1 if compact else 2, 0)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(gap)
	return row


static func describe(entry):
	var lines = [
		"{0} - {1}".format(
			[
				TranslationServer.translate(entry["name"]),
				TranslationServer.translate(entry["description"])
			]
		)
	]
	var properties = entry.get("properties", {})
	var stats = []
	if "hp_max" in properties:
		stats.append("{0} HP".format([int(properties["hp_max"])]))
	if "attack_damage" in properties:
		(
			stats
			. append(
				(
					"{0} DPS, {1} m"
					. format(
						[
							"%.1f" % (properties["attack_damage"] / properties["attack_interval"]),
							properties["attack_range"],
						]
					)
				)
			)
		)
	if "cargo_capacity" in properties:
		stats.append(
			TranslationServer.translate("CARGO_CAPACITY").format(
				[int(properties["cargo_capacity"])]
			)
		)
	var power = entry.get("power", {})
	if power.get("output_mw", 0) > 0:
		stats.append("+{0} MW".format([power["output_mw"]]))
	if power.get("demand_mw", 0) > 0:
		stats.append("-{0} MW".format([power["demand_mw"]]))
	if power.get("grid_radius_m", 0) > 0:
		stats.append(TranslationServer.translate("GRID_RADIUS").format([power["grid_radius_m"]]))
	if not stats.is_empty():
		lines.append(", ".join(stats))
	if "extracts" in entry:
		lines.append(
			TranslationServer.translate("EXTRACTS").format(
				[
					", ".join(
						entry["extracts"].map(
							func(kind): return TranslationServer.translate(kind.to_upper())
						)
					)
				]
			)
		)
	if "extracts" in entry:
		lines.append(TranslationServer.translate("EXTRACTOR_PLACEMENT_HINT"))
	if entry.get("category") == "structure":
		lines.append(TranslationServer.translate("STRUCTURE_BUILD_HINT"))
	var cost_parts = []
	for resource in Constants.Match.Resources.ALL:
		if entry.get("cost", {}).get(resource, 0) > 0:
			cost_parts.append(
				"{0} {1}".format(
					[int(entry["cost"][resource]), TranslationServer.translate(resource.to_upper())]
				)
			)
	lines.append(TranslationServer.translate("COST").format([", ".join(cost_parts)]))
	if "flight_endurance_s" in entry:
		lines.append(
			TranslationServer.translate("NEEDS_AIRPORT").format([int(entry["flight_endurance_s"])])
		)
	if int(entry.get("tier", 1)) > 1:
		lines.append(
			TranslationServer.translate("REQUIRES_TIER").format(
				[
					TranslationServer.translate(
						Constants.Match.Tech.TIERS[int(entry["tier"]) - 1]["name"]
					)
				]
			)
		)
	return "\n".join(lines)


func _on_button_pressed(entry):
	var scene = load(entry["scene"])
	if entry.get("category") == "structure":
		MatchSignals.place_structure.emit(scene)
	elif unit != null and is_instance_valid(unit):
		unit.production_queue.produce(scene)
