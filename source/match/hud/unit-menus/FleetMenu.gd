extends GridContainer

# Menu of selected trucks and trains: recycle them at the closest depot for part of
# their cost back, and for a train its line: what it is doing, and a button to let it
# plan its own line again after the player edited it. It is drawn over the command card
# (GenericMenu), so its buttons start on the card's free third row, or on the second
# when nothing selected drives (trains run on rails, and the card then shows only Stop).

const Hauler = preload("res://source/match/units/Hauler.gd")
const HudStyle = preload("res://source/match/hud/HudStyle.gd")

const REFRESH_INTERVAL_S = 0.4

var units = []:
	set = _set_units

var _recycle_button = null
var _line_button = null
var _status = Label.new()
var _spacers = []
var _slot = HudStyle.SLOT_FULL_PX


func _ready():
	columns = 4
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot = HudStyle.slot_px(get_viewport().get_visible_rect().size.y)
	# the command card's two order rows show through these
	for _i in range(2 * columns):
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(_slot, _slot)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(spacer)
		_spacers.append(spacer)
	_recycle_button = _make_button(_on_recycle_pressed)
	_line_button = _make_button(_on_line_pressed)
	_line_button.text = tr("TRAIN_AUTO_LINE")
	_line_button.tooltip_text = tr("TRAIN_AUTO_LINE_TOOLTIP")
	# one slot in the grid, the text runs over the next one, so the columns stay slot wide
	var holder = Control.new()
	holder.custom_minimum_size = Vector2(_slot, _slot)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	# a long train line grows the text upwards, over the card, not below the screen's edge
	_status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_status.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_status.offset_top = -_slot
	_status.offset_right = 2 * _slot + HudStyle.SLOT_GAP
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 12)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_status)
	var timer = Timer.new()
	timer.timeout.connect(_refresh)
	add_child(timer)
	timer.start(REFRESH_INTERVAL_S)


static func applies_to(selection):
	return (
		not selection.is_empty()
		and selection.all(func(unit): return unit is Hauler or unit.get("is_train") == true)
	)


func _make_button(on_pressed):
	var button = Button.new()
	button.theme_type_variation = "SlotButton"
	button.custom_minimum_size = Vector2(_slot, _slot)
	button.focus_mode = Control.FOCUS_NONE
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(on_pressed)
	add_child(button)
	return button


func _set_units(selection):
	units = selection
	if is_node_ready():
		var drives = _valid_units().any(func(unit): return unit.movement_speed > 0.0)
		for spacer in _spacers.slice(columns):
			spacer.visible = drives
		_refresh()


func _valid_units():
	return units.filter(func(unit): return is_instance_valid(unit) and unit.is_inside_tree())


func _refresh():
	var selection = _valid_units()
	if not visible or selection.is_empty():
		return
	var logistics = selection[0].player.logistics
	var waiting = selection.filter(func(unit): return not unit.recycling)
	_recycle_button.text = tr("RECYCLE_BUTTON").format([waiting.size()])
	_recycle_button.disabled = waiting.is_empty() or logistics == null
	var refund = {}
	if logistics != null:
		for unit in waiting:
			var share = logistics.fleet.get_recycle_refund(unit)
			for resource in share:
				refund[resource] = refund.get(resource, 0.0) + share[resource]
	var parts = []
	for resource in refund:
		parts.append("{0} {1}".format([int(floor(refund[resource])), tr(resource.to_upper())]))
	_recycle_button.tooltip_text = tr("RECYCLE_TOOLTIP").format([", ".join(parts)])
	var trains = selection.filter(func(unit): return unit.get("is_train") == true)
	_line_button.visible = not trains.is_empty()
	_status.text = _status_text(selection, trains)


func _status_text(selection, trains):
	if trains.size() == 1:
		var train = trains[0]
		var stop_names = (
			train
			. stops
			. filter(func(stop): return is_instance_valid(stop))
			. map(func(stop): return train._name_of(stop))
		)
		return "{0}\n{1}".format(
			[
				train.get_status_text(),
				tr("TRAIN_LINE").format(
					[" > ".join(stop_names) if not stop_names.is_empty() else "-"]
				)
			]
		)
	var hauler = selection[0]
	if selection.size() == 1 and hauler is Hauler:
		return tr("HAULER_DOING_" + _doing_of(hauler))
	return tr("FLEET_SELECTED").format([selection.size()])


static func _doing_of(hauler):
	if hauler.recycling:
		return "RECYCLING"
	if not hauler.automated:
		return "MANUAL"
	if hauler.action == null:
		return "PARKED"
	var description = hauler.action.get("description")
	return (
		description if description in ["STANDBY", "PARKED", "COLLECTING", "SUPPLYING"] else "BUSY"
	)


func _on_recycle_pressed():
	for unit in _valid_units():
		if unit.player.logistics != null:
			unit.player.logistics.fleet.recycle(unit)
	_refresh()


func _on_line_pressed():
	for unit in _valid_units():
		if unit.get("is_train") == true:
			unit.use_automatic_line()
	_refresh()
