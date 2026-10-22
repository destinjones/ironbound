extends MarginContainer

# The middle cell of the bottom bar (BottomBar.gd): what is selected. One unit shows
# BuildingInfo's card, which BuildingInfo.gd moves into Single. Several units show Groups,
# which answers "how many of what, and which are dying" at a glance: one tile per unit
# type (Type_<data id>, the most numerous first) with its icon, its count, its name and a
# strip with one segment per unit coloured by its health, healthiest first, so the red
# ones gather at the right end; a type with a unit in the red gets a red frame and a red
# count of them in its top left corner. The tiles start at the top of the cell, level with
# the command card's first row and the card's icon tile, and a line under them says how
# many units, their hit points together and how many stand idle. A click on a tile keeps
# only that type selected and a Shift-click drops it. Nothing selected shows neither. Only
# units count: a deposit Shift-clicked into the selection gets no tile.
# The cell runs from the minimap's right edge to the command card's left edge, 8 px from
# each, so it narrows while the constructor's 6-column build menu shows. The card's text
# column (its ScrollContainer "Details") takes what the cell leaves after the card's left
# column, at most 640 px, so a line never runs across the whole bar at 1920. It has no
# floor: on a narrow screen (1024 wide, or a larger UI scale) the column narrows and
# scrolls rather than widen the card past the cell, which would widen the bar past both
# screen edges.

const GameData = preload("res://source/data-model/GameData.gd")
const HudStyle = preload("res://source/match/hud/HudStyle.gd")
const Stances = preload("res://source/match/units/actions/Stances.gd")
const Structure = preload("res://source/match/units/Structure.gd")
const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")

const DETAILS_MAX_PX = 640
const COLUMN_GAP = 16  # between the card's left column and its text (BuildingInfo.gd)
const REFRESH_S = 0.25  # health moves between selection changes: a cheap poll, as ControlGroupBar
# a strip is redrawn when a unit's health crosses a step; 1/30 puts the thirds (the colour
# changes, HudStyle.health_color) on step edges, so a step never hides a colour change
const HEALTH_STEPS = 30.0
# the strip under a tile's icon: 8 px tall in an 80 px tile, 7 in a 64 px one, 4 px in from
# the tile's sides
const STRIP_FULL_PX = 8
const STRIP_COMPACT_PX = 7
const STRIP_INSET = 4
const SEGMENT_PITCH = 3  # a segment and its gap; more units than fit become coloured runs
const RUN_MIN_PX = 4  # a run is never thinner than this, so one dying unit is a chip, not a hair
const HEADER_PX = 20

var _holder = null  # the minimap holder, HUD/MarginContainer
var _menus = null  # the command card, UnitMenus
var _hud = null
var _slot = HudStyle.SLOT_FULL_PX
var _units_label = null
var _hp_label = null
var _idle_label = null
var _tiles_box = null
var _tiles = {}  # group id -> its tile, kept while that type stays selected
var _drawn = []  # [[group id, count], ...] as the tiles show them
var _entries = {}  # scene path -> data entry ({} for none), so a refresh does not scan the data
var _dirty = false
var _resort = true  # the next refresh orders the tiles by count: the player changed the selection
var _since_refresh_s = 0.0
var _hinted = false
var _critical_boxes = {}  # "normal" and "hover": the tile's looks with a red frame

@onready var _single = $Single
@onready var _groups = $Groups


class _Strip:
	extends Control

	var fractions = PackedFloat32Array()  # one per unit, healthiest first

	func bands():
		"""how many units are healthy, hurt and critical: [GOOD, WARN, BAD]"""
		var counts = [0, 0, 0]
		for fraction in fractions:
			if fraction >= HudStyle.HEALTH_WARN_BELOW:
				counts[0] += 1
			elif fraction >= HudStyle.HEALTH_BAD_BELOW:
				counts[1] += 1
			else:
				counts[2] += 1
		return counts

	func _draw():
		var count = fractions.size()
		if count == 0:
			return
		draw_rect(Rect2(Vector2.ZERO, size), HudStyle.SURFACE_2)
		var width = floor(size.x)
		if (width + 1) / SEGMENT_PITCH < count:
			_draw_runs(width)
			return
		for index in range(count):
			var left = floor(index * (width + 1) / count)
			var right = floor((index + 1) * (width + 1) / count) - 1
			draw_rect(Rect2(left, 0, right - left, size.y), HudStyle.health_color(fractions[index]))

	func _draw_runs(width):
		"""a big group: one run per colour, as wide as its share of the units, the critical
		ones at the right end and never thinner than RUN_MIN_PX, so a dying unit still shows"""
		var counts = bands()
		var widths = [0.0, 0.0, 0.0]
		for band in [2, 1]:
			if counts[band] > 0:
				widths[band] = max(RUN_MIN_PX, round(width * counts[band] / fractions.size()))
		# two rounded-up shares can add up to more than the strip: the hurt run gives way
		widths[1] = min(widths[1], width - widths[2])
		widths[0] = max(0.0, width - widths[1] - widths[2])
		var colors = [HudStyle.GOOD, HudStyle.WARN, HudStyle.BAD]
		var left = 0.0
		for band in range(3):
			if widths[band] > 0.0:
				draw_rect(Rect2(left, 0, widths[band], size.y), colors[band])
			left += widths[band]


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # the bar under it takes the clicks
	_hud = get_parent().get_parent()
	_holder = _hud.get_node_or_null("MarginContainer")
	_menus = _hud.find_child("UnitMenus", true, false)
	_slot = HudStyle.slot_px(get_viewport_rect().size.y)
	_build_groups()
	resized.connect(_layout)
	if _holder != null:
		_holder.resized.connect(_layout)  # BottomBar sets the compact preset after this _ready
	if _menus != null:
		_menus.resized.connect(_layout)
		_menus.visibility_changed.connect(_layout)
	_single.child_entered_tree.connect(func(_node): _layout.call_deferred())
	# a smaller window or a larger UI scale: the card's width holds the bar at the old
	# width, so this panel is never resized and has to be told
	get_viewport().size_changed.connect(func(): _layout.call_deferred())
	MatchSignals.unit_selected.connect(_mark_reorder)
	MatchSignals.unit_deselected.connect(_mark_reorder)
	MatchSignals.unit_died.connect(_on_unit_died)
	_layout()
	_mark_dirty()


func _process(delta):
	if not _groups.visible:
		return
	_since_refresh_s += delta
	if _since_refresh_s >= REFRESH_S:
		_refresh()


func _layout():
	var height = get_viewport_rect().size.y
	var left = HudStyle.BAR_MARGIN
	if _holder != null and _holder.visible:
		left = int(_holder.get_global_rect().end.x)  # the minimap panel and its 8 px margins
	var card = HudStyle.card_width(height)
	if _menus != null and _menus.is_visible_in_tree():
		card = max(card, int(_menus.size.x))
	var right = card + 2 * HudStyle.BAR_MARGIN
	var details = _single.find_child("Details", true, false)
	var summary = _single.find_child("Summary", true, false)
	if details == null or summary == null:
		_set_margins(left, right)
		return
	# from the screen's width, not this container's: a text column set too wide for the
	# cell would widen the bar, and the next pass would read the wider bar and keep it
	var cell = get_viewport_rect().size.x - left - right
	# floored, so at a fractional UI scale the card is never a fraction of a pixel too wide
	var wanted = floor(
		clamp(cell - summary.custom_minimum_size.x - COLUMN_GAP, 0.0, DETAILS_MAX_PX)
	)
	# a narrower cell takes the text column in first and a wider one moves the margins
	# first, so the card and the margins never add up to more than the screen, not even
	# for a moment: the bar would grow past the screen's edges and stay there
	if wanted < details.custom_minimum_size.x:
		details.custom_minimum_size.x = wanted
	_set_margins(left, right)
	if wanted > details.custom_minimum_size.x:
		details.custom_minimum_size.x = wanted


func _set_margins(left, right):
	_set_margin("margin_left", left)
	_set_margin("margin_right", right)


func _set_margin(side, value):
	if get_theme_constant(side) != value:
		add_theme_constant_override(side, value)


func _mark_dirty(_unit = null):
	"""a selection change: one refresh at the end of the frame, however many units changed"""
	if _dirty:
		return
	_dirty = true
	_refresh.call_deferred()


func _mark_reorder(_unit = null):
	"""the player changed the selection: the tiles are ordered again by count"""
	_resort = true
	_mark_dirty()


func _on_unit_died(unit):
	# unit_died comes for every unit on the map; only a selected one changes the panel (a
	# missed one is caught by the next poll); a death changes a count, never the order
	if is_instance_valid(unit) and unit.is_in_group("selected_units"):
		_mark_dirty()


func _refresh():
	_dirty = false
	_since_refresh_s = 0.0
	var units = _selected_units()
	_show(_single, units.size() == 1)
	_show(_groups, units.size() > 1)
	if units.size() < 2:
		return
	var groups = {}  # group id -> {"entry", "units"}
	for unit in units:
		var id = _group_id(unit)
		if not id in groups:
			groups[id] = {"entry": _entry_of(unit), "units": []}
		groups[id]["units"].append(unit)
	var order = _order(groups)
	var signature = order.map(func(id): return [id, groups[id]["units"].size()])
	if signature != _drawn:
		_place_tiles(order, groups)
		_drawn = signature
	for id in order:
		_refresh_tile(_tiles[id], groups[id])
	_refresh_header(units)
	if not _hinted and order.size() > 1:
		_hint()


func _order(groups):
	"""the most numerous type first, then by id, when the player changed the selection or a
	type is new to it; between those a death keeps every tile where it is, so the tile the
	eye is on in a fight never moves under the pointer"""
	var ids = groups.keys()
	if not _resort and ids.all(func(id): return id in _tiles):
		return _drawn.map(func(pair): return pair[0]).filter(func(id): return id in groups)
	_resort = false
	ids.sort_custom(
		func(a, b):
			var count_a = groups[a]["units"].size()
			var count_b = groups[b]["units"].size()
			return count_a > count_b or (count_a == count_b and a < b)
	)
	return ids


func _show(node, shown):
	if node.visible != shown:
		node.visible = shown


func _selected_units():
	"""the selected units that are still alive; a deposit in the selection is not a unit"""
	return get_tree().get_nodes_in_group("selected_units").filter(
		func(unit): return _alive(unit) and unit.is_in_group("units")
	)


func _alive(unit):
	return is_instance_valid(unit) and unit.is_inside_tree() and not unit.is_queued_for_deletion()


func _entry_of(unit):
	var path = unit._scene_path() if unit.has_method("_scene_path") else unit.scene_file_path
	if not path in _entries:
		var entry = GameData.unit_by_scene(path)
		_entries[path] = entry if entry != null else {}
	return _entries[path]


func _group_id(unit):
	"""the data entry's id (as ControlGroupBar groups), so battle_tank stays apart from tank"""
	var entry = _entry_of(unit)
	return str(entry["id"]) if entry.has("id") else str(unit.get("type"))


func _place_tiles(order, groups):
	"""the tiles in count order; a type that left the selection loses its tile, the others
	keep theirs, so a death only changes a number"""
	for id in _tiles.keys():
		if not id in groups:
			_tiles_box.remove_child(_tiles[id])
			_tiles[id].queue_free()
			_tiles.erase(id)
	for index in range(order.size()):
		var id = order[index]
		if not id in _tiles:
			_tiles[id] = _make_tile(id, groups[id]["entry"])
			_tiles_box.add_child(_tiles[id])
		_tiles_box.move_child(_tiles[id], index)
		_tiles[id].get_node("Count").text = str(groups[id]["units"].size())


func _refresh_tile(tile, group):
	"""the strip and the tooltip, only when a unit's health crossed a step"""
	var fractions = []
	for unit in group["units"]:
		fractions.append(_health_step(unit))
	fractions.sort()
	fractions.reverse()
	var packed = PackedFloat32Array(fractions)
	var strip = tile.get_node("Strip")
	if strip.fractions == packed:
		return
	strip.fractions = packed
	strip.queue_redraw()
	var bands = strip.bands()
	var counts = [tile.get_node("Caption").text, packed.size(), bands[0], bands[1], bands[2]]
	tile.tooltip_text = tr("SELECTION_TILE_TOOLTIP").format(counts)
	# a type with a unit in the red gets a red frame, resting and under the pointer, so the
	# eye finds it before the strip, and a red count of them in the top left corner, so
	# "how many are dying" is a number even when the strip is runs
	for state in _critical_boxes:
		if bands[2] > 0:
			tile.add_theme_stylebox_override(state, _critical_boxes[state])
		else:
			tile.remove_theme_stylebox_override(state)
	var critical = tile.get_node("Critical")
	critical.text = str(bands[2])
	_show(critical, bands[2] > 0)


func _health_step(unit):
	var hp = unit.get("hp")
	var hp_max = unit.get("hp_max")
	if hp == null or hp_max == null or hp_max <= 0:
		return 1.0
	return floor(clamp(float(hp) / float(hp_max), 0.0, 1.0) * HEALTH_STEPS) / HEALTH_STEPS


func _refresh_header(units):
	var hp = 0
	var hp_max = 0
	var idle = 0
	for unit in units:
		if unit.hp != null and unit.hp_max != null:
			hp += int(ceil(unit.hp))
			hp_max += int(unit.hp_max)
		if _is_idle(unit):
			idle += 1
	_units_label.text = tr("SELECTION_UNITS").format([units.size()])
	_hp_label.text = tr("SELECTION_HP").format([hp, hp_max])
	_idle_label.text = tr("SELECTION_IDLE").format([idle])
	_show(_idle_label, idle > 0)


static func _is_idle(unit):
	"""one of ours with no order: nothing to do (a constructor), or an armed unit waiting
	for something to walk into its sight (a tank's resting action, never null); a unit
	holding position was posted there (K), so it is not idle, where a fire stance only says
	how it fights"""
	if unit is Structure or not unit.is_in_group("controlled_units"):
		return false
	if Stances.holds_position(unit):
		return false
	var action = unit.action
	if action == null or not is_instance_valid(action):
		return true
	return action is WaitingForTargets and action.is_idle()


func _hint():
	"""the first time two types or more show, through Guide's first-time hints"""
	_hinted = true
	var guide = _hud.get_node_or_null("Guide") if _hud != null else null
	if guide != null and guide.has_method("show_hint"):
		guide.show_hint("HINT_SELECTION_TILES")


func _on_tile_pressed(id):
	var units = _selected_units().filter(func(unit): return _group_id(unit) == id)
	if units.is_empty():
		return
	if Input.is_action_pressed("shift_selecting"):
		for unit in units:
			var selection = unit.find_child("Selection")
			if selection != null:
				selection.deselect()
		return
	Utils.Match.select_units(Utils.Set.from_array(units))


func _build_groups():
	for state in ["normal", "hover"]:
		var box = get_theme_stylebox(state, "SlotButton")
		if box is StyleBoxFlat:
			_critical_boxes[state] = box.duplicate()
			_critical_boxes[state].border_color = HudStyle.BAD
	# the tiles first, so they start at the cell's top, level with the command card's first
	# row and the one-unit card's icon tile, and the totals line sits under them, level with
	# the card's last row; a scroll container keeps the bar's height when more types are
	# selected than two rows hold (about 30 at 1920, 18 at 1280)
	var scroll = ScrollContainer.new()
	scroll.name = "TileScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_groups.add_child(scroll)
	_tiles_box = HFlowContainer.new()
	_tiles_box.name = "Tiles"
	_tiles_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tiles_box.add_theme_constant_override("h_separation", HudStyle.SLOT_GAP)
	_tiles_box.add_theme_constant_override("v_separation", HudStyle.SLOT_GAP)
	_tiles_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_tiles_box)
	var header = HBoxContainer.new()
	header.name = "Header"  # the totals line (the spec's header row), under the tiles
	header.custom_minimum_size = Vector2(0, HEADER_PX)
	header.add_theme_constant_override("separation", 16)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_groups.add_child(header)
	_units_label = _header_label("UnitsLabel", "NumberLabel", 15, HudStyle.FG)
	header.add_child(_units_label)
	_hp_label = _header_label("HpLabel", "NumberLabel", 13, HudStyle.MUTED)
	header.add_child(_hp_label)
	# the idle count in the same face and size as the unit count: it is the number the
	# line exists for (docs/direction.md, the fifteen idle tanks)
	_idle_label = _header_label("IdleLabel", "NumberLabel", 15, HudStyle.WARN)
	header.add_child(_idle_label)


func _header_label(label_name, variation, font_size, color):
	var label = Label.new()
	label.name = label_name
	label.theme_type_variation = variation
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_tile(id, entry):
	"""a slot-sized button: the icon, the count in the top right corner, the count of units
	in the red in the top left (hidden at 0), the health strip under the icon and the name
	along the bottom"""
	var compact = _slot < HudStyle.SLOT_FULL_PX
	var tile = Button.new()
	tile.name = "Type_" + id
	tile.theme_type_variation = "SlotButton"
	tile.custom_minimum_size = Vector2(_slot, _slot)
	tile.focus_mode = Control.FOCUS_NONE
	tile.pressed.connect(_on_tile_pressed.bind(id))
	var icon_px = round(_slot / 2.0)
	var top = 6 if compact else 8
	var icon = HudStyle.icon_rect(HudStyle.unit_icon(entry), icon_px)
	icon.name = "Icon"
	icon.set_anchors_preset(Control.PRESET_CENTER_TOP)
	icon.offset_left = -icon_px / 2.0
	icon.offset_right = icon_px / 2.0
	icon.offset_top = top
	icon.offset_bottom = top + icon_px
	icon.modulate = Color(entry.get("icon_tint", "#ffffff"))
	tile.add_child(icon)
	var count = Label.new()
	count.name = "Count"
	count.theme_type_variation = "NumberLabel"
	# a point smaller in a 64 px tile, where two digits at 15 px ran over the icon's corner
	count.add_theme_font_size_override("font_size", 13 if compact else 15)
	count.add_theme_color_override("font_color", HudStyle.ACCENT)
	count.add_theme_constant_override("outline_size", 4)
	count.add_theme_color_override("font_outline_color", Color.BLACK)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.set_anchors_preset(Control.PRESET_FULL_RECT)
	count.offset_right = -3 if compact else -5
	count.offset_top = 1
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(count)
	# the red count where the command card puts a slot's key: small, outlined, top left
	var critical = HudStyle.hotkey_tag("")
	critical.name = "Critical"
	critical.add_theme_color_override("font_color", HudStyle.BAD)
	critical.hide()
	tile.add_child(critical)
	var strip = _Strip.new()
	strip.name = "Strip"
	strip.position = Vector2(STRIP_INSET, top + icon_px + (2 if compact else 3))
	strip.size = Vector2(_slot - 2 * STRIP_INSET, STRIP_COMPACT_PX if compact else STRIP_FULL_PX)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(strip)
	tile.add_child(HudStyle.caption(tr(entry.get("name", id)), _slot))
	return tile
