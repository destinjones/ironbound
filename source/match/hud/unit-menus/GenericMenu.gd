extends GridContainer

# The command card of the selected units: 4 x 3 slots, each an icon with its caption under
# it and its key in the top left corner (Keybinds, so a controls.cfg rebind shows).
#   row 1: Fight F, Patrol P, Guard V, Stop X
#   row 2: Patrol base B, Retreat Z, Fire stance L, Hold position K
#   row 3: free, for the fleet menu's buttons drawn over it (FleetMenu)
# A single constructor's build menu takes the place of the card.

const Structure = preload("res://source/match/units/Structure.gd")
const Worker = preload("res://source/match/units/Worker.gd")
const HudStyle = preload("res://source/match/hud/HudStyle.gd")
const Keybinds = preload("res://source/match/Keybinds.gd")
const Stances = preload("res://source/match/units/actions/Stances.gd")
const UnitCommandHandler = preload("res://source/match/handlers/UnitCommandHandler.gd")

# unit orders (see UnitCommandHandler) and the placeholder slot of the scene each one takes
const COMMANDS = [
	["fight", "Padding"],
	["patrol", "Padding2"],
	["guard", "Padding3"],
	["patrol_base", "Padding5"],
	["retreat", "Padding6"],
	["fire_stance", "Padding7"],
	["hold_position", "Padding8"],
]
const SPACERS = ["Padding9", "Padding10", "Padding11", "Padding12"]
const FIRE_STANCES = ["AT_WILL", "RETURN", "HOLD"]  # Stances.Fire order
const FIRE_STANCE_ICONS = ["cmd_fire_at_will", "cmd_return_fire", "cmd_hold_fire"]
const DISABLED = Color(1, 1, 1, 0.45)

var units = []

var _command_buttons = {}  # command -> button
var _cancel_button = null
var _spacers = []
var _slot = HudStyle.SLOT_FULL_PX
var _looks = {}  # button -> [icon name, caption, key] it shows


func _ready():
	_slot = HudStyle.slot_px(get_viewport().get_visible_rect().size.y)
	for entry in COMMANDS:
		var button = Button.new()
		button.name = "Command_" + entry[0]
		button.toggle_mode = entry[0] in UnitCommandHandler.MODES or entry[0] == "hold_position"
		button.pressed.connect(_on_command_pressed.bind(entry[0]))
		_command_buttons[entry[0]] = _replace_padding(entry[1], button)
	_cancel_button = find_child("CancelActionButton")
	_dress(_cancel_button)
	for spacer_name in SPACERS:
		var spacer = get_node(spacer_name)
		spacer.custom_minimum_size = Vector2(_slot, _slot)
		_spacers.append(spacer)


func _replace_padding(padding_name, button):
	"""the button takes the slot of the scene's placeholder, keeping its place in the grid"""
	var padding = get_node(padding_name)
	_dress(button)
	add_child(button)
	move_child(button, padding.get_index())
	padding.queue_free()
	remove_child(padding)
	return button


func _dress(button):
	"""an empty slot button with an icon, a caption and a hotkey tag (see _show)"""
	button.text = ""
	button.theme_type_variation = "SlotButton"
	button.custom_minimum_size = Vector2(_slot, _slot)
	button.focus_mode = Control.FOCUS_NONE
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_CENTER_TOP)
	var side = _slot / 2.0
	var top = round(_slot * 0.1)
	icon.offset_left = -side / 2.0
	icon.offset_right = side / 2.0
	icon.offset_top = top
	icon.offset_bottom = top + side
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	button.add_child(HudStyle.caption("", _slot))
	button.add_child(HudStyle.hotkey_tag(""))
	_looks[button] = []


func _show(button, icon_name, caption, action, tooltip):
	"""sets what a slot shows, touching the nodes only when something changed"""
	var key = Keybinds.key_label(action)
	var look = [icon_name, caption, key]
	if _looks[button] == look:
		return
	_looks[button] = look
	button.get_node("Icon").texture = HudStyle.icon(icon_name)
	button.get_node("Caption").text = caption
	button.get_node("Hotkey").text = key
	button.tooltip_text = tr(tooltip) if key == "" else "{0} ({1})".format([tr(tooltip), key])


func _process(_delta):
	if not is_visible_in_tree():
		return
	var handler = UnitCommandHandler.of(get_tree())
	var movable = units.filter(
		func(unit):
			return is_instance_valid(unit) and not unit is Structure and unit.movement_speed > 0.0
	)
	var armed = movable.filter(func(unit): return unit.attack_range != null)
	# a single constructor shows its build menu in the same slots
	var single_constructor = (
		units.size() == 1 and is_instance_valid(units[0]) and units[0] is Worker
	)
	var show = not movable.is_empty() and not single_constructor
	# under a single constructor's build menu the stop button would peek between the
	# build buttons without being clickable; X (stop) still cancels
	_cancel_button.visible = not single_constructor
	for spacer in _spacers:
		spacer.visible = show
	_show_stop()
	for command in _command_buttons:
		var button = _command_buttons[command]
		button.visible = show
		var disabled = command in ["fire_stance", "hold_position"] and armed.is_empty()
		if button.disabled != disabled:
			button.disabled = disabled
			button.modulate = DISABLED if disabled else Color.WHITE
		var icon_name = FIRE_STANCE_ICONS[0] if command == "fire_stance" else "cmd_" + command
		var caption = "COMMAND_" + command.to_upper()
		if command == "fire_stance" and not armed.is_empty():
			var stance = Stances.fire_stance(armed[0])
			icon_name = FIRE_STANCE_ICONS[stance]
			caption = "COMMAND_FIRE_STANCE_SHORT_" + FIRE_STANCES[stance]
		elif command == "hold_position" and not armed.is_empty():
			# a toggle names its action and lights up while on, as SC2 and Generals do
			if Stances.holds_position(armed[0]):
				caption = "COMMAND_HOLD_SHORT_ON"
		_show(
			button,
			icon_name,
			tr(caption),
			"command_" + command,
			"COMMAND_{0}_TOOLTIP".format([command.to_upper()])
		)
		var pressed = handler != null and handler.mode == command
		if command == "hold_position":
			pressed = not armed.is_empty() and Stances.holds_position(armed[0])
		if button.toggle_mode and button.button_pressed != pressed:
			button.set_pressed_no_signal(pressed)


func _show_stop():
	"""Stop, or Cancel build while the one selected unit is a construction site; the stop
	key skips structures (UnitCommands.stop), so Cancel build shows no key and takes a click"""
	if _is_construction_site():
		_show(
			_cancel_button,
			"cmd_cancel_build",
			tr("COMMAND_CANCEL_BUILD"),
			"",
			"COMMAND_CANCEL_BUILD"
		)
	else:
		_show(
			_cancel_button, "cmd_stop", tr("COMMAND_STOP"), "command_stop", "CANCEL_CURRENT_ACTION"
		)


func _is_construction_site():
	return (
		len(units) == 1
		and is_instance_valid(units[0])
		and units[0] is Structure
		and units[0].is_under_construction()
	)


func _on_command_pressed(command):
	var handler = UnitCommandHandler.of(get_tree())
	if handler != null:
		handler.begin(command)


func _on_cancel_action_button_pressed():
	if _is_construction_site():
		units[0].cancel_construction()
		return
	for unit in units:
		unit.action = null
