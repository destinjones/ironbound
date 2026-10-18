extends PanelContainer

# The under-attack banner: "Base under attack: Mine 2" or "Units under attack: Tank" in a
# red-edged strip above the minimap, with the key that goes there (the alert row of
# StarCraft II, in words as Generals says it). It hangs off the accepted attack ping
# (MatchSignals.attack_pinged from MinimapPings.gd), so the red ring, the blip and the words
# share one filter and one throttle; it plays no sound of its own.
# - A fight already on screen gets no banner.
# - A hit structure beats a hit unit: a unit's alert neither replaces nor prolongs a
#   structure's, a structure's replaces a unit's at once.
# - It holds 9 game seconds after the last alert it took, restarting at most every 2 s, then
#   fades. The hold outlasts the 6 s a cell stays quiet, so one fight is one banner, not a
#   blink every 6 s; an alert that comes while it fades takes it back without a new flash.
# - The last five places of the last minute are remembered, one per 12 m. Space
#   (jump_to_alert) or a click on the banner puts the camera on the place the banner names,
#   or on the newest place once it has faded; Space again within 2 s goes to the one before.
# - Once the named place is on screen (after Space, a click, or the player scrolling there),
#   the banner fades a second later: the player is looking at the fight.
# - It sits above the selection card while the card reaches into its row (until the card
#   moves into the bottom bar).

const HudStyle = preload("res://source/match/hud/HudStyle.gd")
const MinimapPings = preload("res://source/match/hud/MinimapPings.gd")
const HaulerLinks = preload("res://source/match/economy/HaulerLinks.gd")
const GameData = preload("res://source/data-model/GameData.gd")
const Keybinds = preload("res://source/match/Keybinds.gd")
const Hauler = preload("res://source/match/units/Hauler.gd")
const Structure = preload("res://source/match/units/Structure.gd")

const ACTION = "jump_to_alert"
# shown this long after the last alert it took: longer than a cell stays quiet, so the next
# ping of the same fight lands while it still shows
const HOLD_S = MinimapPings.ATTACK_QUIET_S + 3.0
const SEEN_S = 1.0  # it fades this long after the place it names comes on screen
const RESTART_GUARD_S = 2.0  # the hold restarts at most this often
const CYCLE_WINDOW_S = 2.0  # Space again within this long goes to the alert before
const MEMORY_SIZE = 5
const MEMORY_S = 60.0
const BG = Color("#3a1711", 0.94)  # red-tinted, so it does not read as a Guide tip
const FLASH_BG = Color(HudStyle.BAD, 0.94)  # each new text pulses red once
const FLASH_S = 0.35
const FADE_S = 0.4
const HEIGHT = 40
const MIN_WIDTH = 260
const LEFT = 8
const ROW_PX = HEIGHT + 8  # the row above the minimap kept free for the banner (Guide._layout)

var shows = 0  # how often the banner came up, for the harness (alert fatigue)
var visible_s = 0.0  # game seconds it has been up this match, for the same count
var alert_position = null  # the place the text names
var memory = []  # [{"position": Vector3, "s": game seconds}], oldest first

var _now_s = 0.0  # game seconds: the hold, the guard and the memory pause and speed up with play
var _structure = false  # the text names a structure
var _restarted_s = -100.0
var _hide_s = 0.0
var _fading = false
var _jump_order = []
var _jump_index = 0
var _last_jump_ms = -100000
var _label = Label.new()
var _key = Label.new()
var _style = StyleBoxFlat.new()
var _tween = null


func _ready():
	name = "AlertBanner"
	add_to_group("alert_banner")  # the harness reads it (HarnessApi.state)
	z_index = 2
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP  # the click is the jump, not an order below
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(MIN_WIDTH, HEIGHT)
	_build()
	MatchSignals.attack_pinged.connect(_on_attack_pinged)


func _build():
	_style.bg_color = BG  # the hint's box (Guide._build_hint) in red, ringed in red
	_style.border_color = HudStyle.BAD
	_style.set_border_width_all(1)
	_style.border_width_left = 4
	_style.set_corner_radius_all(4)
	_style.shadow_color = Color(0, 0, 0, 0.35)
	_style.shadow_size = 6
	add_theme_stylebox_override("panel", _style)
	var margin = HudStyle.margin(self, 12, 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var icon = HudStyle.icon_rect(HudStyle.icon("alert_attack"), 20)
	icon.modulate = HudStyle.BAD
	row.add_child(icon)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", HudStyle.FG)
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_label)
	var chip = PanelContainer.new()
	var chip_style = StyleBoxFlat.new()  # a keycap: lighter face, thicker lower edge
	chip_style.bg_color = HudStyle.LINE
	chip_style.border_color = HudStyle.MUTED
	chip_style.set_border_width_all(1)
	chip_style.border_width_bottom = 2
	chip_style.set_corner_radius_all(3)
	chip_style.content_margin_left = 6
	chip_style.content_margin_right = 6
	chip_style.content_margin_top = 1
	chip_style.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", chip_style)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chip)
	_key.theme_type_variation = "NumberLabel"
	_key.add_theme_font_size_override("font_size", 12)
	_key.add_theme_color_override("font_color", HudStyle.FG)
	chip.add_child(_key)
	var hint = HudStyle.small(Label.new(), 12, true)
	hint.text = tr("ALERT_JUMP_HINT")
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hint)


func _process(delta):
	_now_s += delta
	if not visible:
		return
	visible_s += delta
	_place()
	if not _fading and _on_screen(alert_position):
		_hide_s = min(_hide_s, _now_s + SEEN_S)  # the player is looking at it now
	if not _fading and _now_s >= _hide_s:
		_fading = true
		_style.bg_color = BG
		_restart_tween().tween_property(self, "modulate:a", 0.0, FADE_S)
		_tween.tween_callback(_on_faded)


func _unhandled_input(event):
	if not InputMap.has_action(ACTION) or not event.is_action_pressed(ACTION):
		return
	if not event.is_echo() and jump():
		get_viewport().set_input_as_handled()


func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			jump()
		accept_event()


func jump():
	"""puts the camera on the place the banner names (the newest alert once it has faded);
	again within CYCLE_WINDOW_S, on the one before, wrapping. False with nothing to go to."""
	var now = Time.get_ticks_msec()  # real time: two presses of the key
	if now - _last_jump_ms < CYCLE_WINDOW_S * 1000.0 and not _jump_order.is_empty():
		_jump_index = (_jump_index + 1) % _jump_order.size()
	else:
		_jump_order = _jump_targets()
		_jump_index = 0
	if _jump_order.is_empty():
		return false
	_last_jump_ms = now
	var camera = get_viewport().get_camera_3d()
	if camera != null and camera.has_method("set_position_safely"):
		camera.set_position_safely(_jump_order[_jump_index])
	return true


func _jump_targets():
	"""the remembered places, newest first, with the one on the banner leading"""
	var targets = []
	for entry in memory:
		if _now_s - entry["s"] < MEMORY_S:
			targets.push_front(entry["position"])
	if visible and alert_position != null:
		targets = targets.filter(func(at): return not _same_place(at, alert_position))
		targets.push_front(alert_position)
	return targets


func _on_screen(position):
	var camera = get_viewport().get_camera_3d()
	return position != null and camera != null and camera.is_position_in_frustum(position)


func _on_attack_pinged(position, unit):
	if _on_screen(position):
		return  # a fight on screen needs no words; the ping and the advisor still come
	_remember(position)
	var structure = unit is Structure
	var showing = visible and not _fading
	if showing and _structure and not structure:
		return
	var takes_over = structure and not _structure
	if showing and not takes_over and _now_s - _restarted_s < RESTART_GUARD_S:
		return
	_restarted_s = _now_s
	_hide_s = _now_s + HOLD_S
	_structure = structure
	alert_position = position
	var key = "ALERT_BASE_UNDER_ATTACK" if structure else "ALERT_UNITS_UNDER_ATTACK"
	_show(tr(key).format([_name_of(unit)]), not visible)


func _show(text, appearing):
	"""a new banner when `appearing`; else the same one goes on: a fade stops, and only new
	words flash"""
	if appearing:
		shows += 1
	if _fading:
		_fading = false
		_kill_tween()
		modulate = Color.WHITE
	if not appearing and text == _label.text:
		return  # the same words again: the hold restarted, no flash
	_label.text = text
	_key.text = Keybinds.key_label(ACTION)
	tooltip_text = tr("ALERT_JUMP_TOOLTIP").format([_key.text])
	reset_size()  # shrink back after a longer name
	_place()
	show()
	_style.bg_color = FLASH_BG
	_restart_tween().tween_property(_style, "bg_color", BG, FLASH_S)


func _place():
	"""on the row above the minimap, lined up with its left edge; above BuildingInfo's
	selection card instead while the card reaches into that row"""
	var holder = get_parent().get_node_or_null("MarginContainer")  # the minimap's
	var minimap = holder.get_node_or_null("Minimap") if holder != null else null
	var top = holder.global_position.y if holder != null else get_viewport_rect().size.y - 215.0
	var left = minimap.global_position.x if minimap != null else LEFT
	var card = get_parent().get_node_or_null("BuildingInfo/BuildingCard")
	if card != null and card.is_visible_in_tree():
		var row = Rect2(left, top - ROW_PX, size.x, HEIGHT)
		if card.get_global_rect().intersects(row):
			top = min(top, card.global_position.y)
	position = Vector2(left, top - ROW_PX)


func _restart_tween():
	_kill_tween()
	_tween = create_tween().set_ignore_time_scale(true)  # the hit-stop does not slow it
	return _tween


func _kill_tween():
	if _tween != null:
		_tween.kill()
		_tween = null


func _on_faded():
	hide()
	_fading = false
	modulate = Color.WHITE
	_style.bg_color = BG


func _remember(position):
	"""the newest place last; it replaces one within 12 m, and a minute old ones go"""
	var kept = []
	for entry in memory:
		if _now_s - entry["s"] < MEMORY_S and not _same_place(entry["position"], position):
			kept.append(entry)
	kept.append({"position": position, "s": _now_s})
	memory = kept.slice(max(0, kept.size() - MEMORY_SIZE))


static func _same_place(a, b):
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) <= MinimapPings.ATTACK_CELL_M


static func _name_of(unit):
	"""numbered for structures and trucks ("Mine 2", "Hauler 3"), the type for the rest"""
	if not is_instance_valid(unit):
		return ""
	if unit is Structure or unit is Hauler:
		return HaulerLinks.display_name(unit)
	var entry = GameData.unit_by_scene(unit._scene_path())
	return TranslationServer.translate(entry["name"]) if entry != null else str(unit.name)
