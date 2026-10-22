extends Control

# Tells the player what they are looking at:
# - hovering any unit or building shows a small tip by the cursor with its name and one
#   line of state (for your resource buildings: yard and how many trucks are coming; for
#   your trucks: their current job),
# - selecting one unit or building shows its card in the middle of the bottom bar
#   (HUD/BottomBar/SelectionPanel/Single): on the left its icon, name, role, rank, health
#   bar and, for your factories, the production queue; on the right what it does, what it
#   costs and needs, what it makes, its live status and, for your extractors, storages,
#   depots and construction sites, the trucks working for it (scrolling when it is long).
#   Truck names on the card select that truck and centre the camera on it. A match scene
#   without the bar gets the same card floating next to the minimap,
# - the routes of those trucks are drawn on the ground (HaulerRouteLines.gd), for the
#   building under the cursor and the selected one, and the route of a selected truck.
# Texts come from data/units (role, info, cost, power...) via BuildingInfoText.gd.

const HudStyle = preload("res://source/match/hud/HudStyle.gd")
const Text = preload("res://source/match/hud/BuildingInfoText.gd")
const HaulerLinks = preload("res://source/match/economy/HaulerLinks.gd")
const HaulerRouteLines = preload("res://source/match/hud/HaulerRouteLines.gd")
const Hauler = preload("res://source/match/units/Hauler.gd")
const Structure = preload("res://source/match/units/Structure.gd")
const Veterancy = preload("res://source/match/veterancy/Veterancy.gd")
const ProductionQueueScene = preload("res://source/match/hud/ProductionQueue.tscn")

const REFRESH_INTERVAL_S = 0.25
const CARD_WIDTH = 380  # the floating card, without the bar
const SUMMARY_FULL_PX = 300  # the card's left column in the bar (80 px slots)
const SUMMARY_COMPACT_PX = 260  # the same with 64 px slots
const COLUMN_GAP = 16
const CHEVRON_PX = 22
# "180 / 180" (the command centre, the most hp in data) with room for a veteran's more,
# so the health bar beside it keeps one length from unit to unit
const HP_LABEL_PX = 96
const TIP_WIDTH = 300
const TIP_OFFSET = Vector2(18, 20)

var hovered = null  # unit under the cursor
var shown = null  # unit the card shows

var _since_refresh_s = 0.0
var _tip = null
var _tip_title = null
var _tip_body = null
var _card = null
var _card_icon = null
var _card_title = null
var _card_role = null
var _card_rank = null
var _card_tile = null  # the icon's slot, a disabled button that names the unit on hover
var _card_chevrons = null
var _card_health_row = null
var _card_health = null
var _card_health_fill = StyleBoxFlat.new()
var _card_hp = null
var _card_queue_row = null
var _card_queue = null
var _card_details = null
var _card_body = null
var _in_bar = false  # the card sits in the bottom bar, not floating
var _routes = null

@onready var _match = find_parent("Match")


func _ready():
	name = "BuildingInfo"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_tip()
	_build_card()
	_routes = HaulerRouteLines.new()
	_routes.name = "HaulerRouteLines"
	_match.add_child.call_deferred(_routes)
	var units = get_tree().get_nodes_in_group("units")
	units.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
	for unit in units:
		_track(unit)
	MatchSignals.unit_spawned.connect(_track)
	MatchSignals.unit_selected.connect(func(_unit): _on_selection_changed.call_deferred())
	MatchSignals.unit_deselected.connect(func(_unit): _on_selection_changed.call_deferred())
	MatchSignals.unit_died.connect(_on_unit_died)


func _process(delta):
	if _tip.visible:
		_place_tip()
	_since_refresh_s += delta
	if _since_refresh_s < REFRESH_INTERVAL_S:
		return
	_since_refresh_s = 0.0
	_refresh()


func _track(unit):
	"""numbers the unit among its owner's units of that type and follows the cursor on it"""
	if unit.player != null and (unit is Structure or unit is Hauler):
		HaulerLinks.number_of(unit)
	if not unit.mouse_entered.is_connected(_on_mouse_entered):
		unit.mouse_entered.connect(_on_mouse_entered.bind(unit))
		unit.mouse_exited.connect(_on_mouse_exited.bind(unit))


func _on_mouse_entered(unit):
	if not _valid(unit) or not unit.visible:
		return
	hovered = unit
	_refresh()


func _on_mouse_exited(unit):
	if hovered == unit:
		hovered = null
		_refresh()


func _on_unit_died(unit):
	if hovered == unit:
		hovered = null
	if shown == unit:
		shown = null
	# a death is not a selection change, so pick again: when it leaves one of two selected
	# units, that one's card shows (the dead unit is out of the group by the deferred call)
	if is_instance_valid(unit) and unit.is_in_group("selected_units"):
		_on_selection_changed.call_deferred()
	_refresh()


func _on_selection_changed():
	# a deposit can be selected too (its Selection trait) and is not a unit: no card for it,
	# and it does not stop the card of the one unit selected with it
	var selected = get_tree().get_nodes_in_group("selected_units").filter(
		func(node): return node.is_in_group("units")
	)
	shown = selected[0] if selected.size() == 1 else null
	_refresh()


func _valid(unit):
	return unit != null and is_instance_valid(unit) and unit.is_inside_tree()


func _is_own(unit):
	return unit.is_in_group("controlled_units")


func _refresh():
	if not _valid(hovered) or not hovered.visible:
		hovered = null
	if not _valid(shown):
		shown = null
	_refresh_tip()
	_refresh_card()
	_refresh_routes()


func _refresh_tip():
	# no tip for the unit the card already shows
	_tip.visible = hovered != null and hovered != shown and hovered.player != null
	if not _tip.visible:
		return
	var own = _is_own(hovered)
	var title = (
		HaulerLinks.display_name(hovered)
		if own
		else Text.entry_of(hovered)["name"] if Text.entry_of(hovered) != null else ""
	)
	_tip_title.text = tr(title)
	var lines = []
	if not own:
		lines.append(_owner_text(hovered))
	var summary = Text.hover_summary(hovered, own)
	if summary != "":
		lines.append(summary)
	_tip_body.text = Text.plain("\n".join(lines))
	_tip_body.visible = not lines.is_empty()
	_tip.reset_size()
	_place_tip()


func _place_tip():
	var viewport = get_viewport().get_visible_rect().size
	var spot = get_viewport().get_mouse_position() + TIP_OFFSET
	spot.x = min(spot.x, viewport.x - _tip.size.x - 4)
	spot.y = min(spot.y, viewport.y - _tip.size.y - 4)
	_tip.position = spot


func _refresh_card():
	_card.visible = shown != null and shown.player != null and Text.entry_of(shown) != null
	if not _card.visible:
		return
	var own = _is_own(shown)
	var entry = Text.entry_of(shown)
	_card_icon.texture = HudStyle.unit_icon(entry)
	_card_icon.modulate = Color(entry.get("icon_tint", "#ffffff"))
	_card_title.text = HaulerLinks.display_name(shown) if own else tr(entry["name"])
	_card_tile.tooltip_text = _card_title.text
	_card_role.text = Text.role_text(shown) + ("" if own else "  ·  " + _owner_text(shown))
	_refresh_rank()
	_refresh_health()
	_refresh_queue_row()
	# the explanation in the muted tone, so the facts and the live lines read first
	var details = [_muted(Text.info_text(shown))]
	var classes = Text.classes_for(entry)
	if classes != "":
		details.append(classes)
	var needs = Text.needs_line(shown)
	if needs != "":
		details.append(_section("INFO_NEEDS") + needs)
	var makes = Text.makes_line(shown)
	if shown is Structure or makes != tr("INFO_NOTHING"):
		details.append(_section("INFO_MAKES") + makes)
	_card_details.text = "\n".join(details)
	var body = []
	var status = Text.status_lines(shown, own, false)  # the health bar shows hp
	if shown is Hauler and own:
		status.append(Text.cargo_line(shown))
	if not status.is_empty():
		body.append(_section("INFO_STATUS") + "\n" + "\n".join(status))
	if own and HaulerLinks.is_served_building(shown):
		body.append(_section("INFO_HAULERS") + "\n" + "\n".join(Text.truck_lines(shown)))
	_card_body.text = "\n".join(body)
	_card_body.visible = not body.is_empty()
	if not _in_bar:
		_card.reset_size()
		_place_card()


func _refresh_queue_row():
	"""the QUEUE caption only over something queued, not over an idle factory"""
	var elements = _card_queue.find_child("QueueElements", false, false)
	var queued = (
		elements.get_children().filter(func(node): return not node.is_queued_for_deletion())
		if elements != null
		else []
	)
	_card_queue_row.visible = _card_queue.visible and not queued.is_empty()


func _muted(text):
	return "[color={0}]{1}[/color]".format([HudStyle.MUTED.to_html(false), text])


func _refresh_rank():
	var rank = Veterancy.rank_of(shown)
	var veterancy = Veterancy.of(get_tree())
	var ranks = veterancy.config.get("ranks", []) if veterancy != null else []
	var ranked = rank > 0 and rank <= ranks.size()
	_card_rank.visible = ranked
	_card_chevrons.visible = ranked
	if not ranked:
		return
	var color = Color(ranks[rank - 1].get("color", "#ffffff"))
	_card_rank.text = veterancy.rank_name(rank)
	_card_rank.add_theme_color_override("font_color", color)
	_card_chevrons.texture = Veterancy.chevron_texture(rank)
	_card_chevrons.modulate = color


func _refresh_health():
	var hp = shown.get("hp")
	var hp_max = shown.get("hp_max")
	_card_health_row.visible = hp != null and hp_max != null and hp_max > 0
	if not _card_health_row.visible:
		return
	var fraction = clamp(float(hp) / float(hp_max), 0.0, 1.0)
	_card_health.value = fraction
	_card_health_fill.bg_color = HudStyle.health_color(fraction)
	_card_hp.text = "{0} / {1}".format([int(ceil(hp)), int(hp_max)])


func _place_card():
	var viewport = get_viewport().get_visible_rect().size
	var left = 8.0
	var minimap = _match.find_child("Minimap", true, false) if _match != null else null
	if minimap != null and minimap.is_visible_in_tree():
		left = minimap.get_global_rect().end.x + 8.0
	_card.position = Vector2(left, viewport.y - _card.size.y - 8.0)


func _refresh_routes():
	if _routes == null or not _routes.is_inside_tree():
		return
	var buildings = []
	var trucks = []
	for unit in [hovered, shown]:
		if unit == null or not _is_own(unit):
			continue
		if unit is Hauler:
			trucks.append(unit)
		elif HaulerLinks.is_served_building(unit) and not unit in buildings:
			buildings.append(unit)
	_routes.show_routes(buildings, trucks)


func _owner_text(unit):
	var diplomacy_hud = _match.find_child("DiplomacyHud", true, false) if _match else null
	var owner = (
		diplomacy_hud.faction_name(unit.player)
		if diplomacy_hud != null
		else "#{0}".format([unit.player.get_index() + 1])
	)
	return tr("INFO_ENEMY").format([owner])


func _section(key):
	return "[color={0}][b]{1}[/b][/color]  ".format([HudStyle.MUTED.to_html(false), tr(key)])


func _on_link_clicked(meta):
	var id = int(str(meta))
	if not is_instance_id_valid(id):
		return
	var unit = instance_from_id(id)
	if not unit is Node or not unit.is_inside_tree():
		return
	MatchSignals.deselect_all_units.emit()
	var selection = unit.find_child("Selection")
	if selection != null:
		selection.select()
	var camera = get_viewport().get_camera_3d()
	if camera != null and camera.has_method("set_position_safely"):
		camera.set_position_safely(unit.global_position)


func _build_tip():
	_tip = PanelContainer.new()
	_tip.name = "HoverTip"
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.custom_minimum_size = Vector2(0, 0)
	add_child(_tip)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	HudStyle.margin(_tip, 8, 5).add_child(box)
	_tip_title = Label.new()
	_tip_title.theme_type_variation = "HeaderLabel"
	_tip_title.add_theme_font_size_override("font_size", 15)
	box.add_child(_tip_title)
	_tip_body = Label.new()
	HudStyle.small(_tip_body, 13, true)
	_tip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_body.custom_minimum_size = Vector2(TIP_WIDTH - 16, 0)
	box.add_child(_tip_body)
	_tip.hide()


func _build_card():
	"""in the bar: the icon tile, titles, health and queue on the left, the text scrolling on
	the right; floating (a match scene without the bar): the same stacked in one column"""
	var host = _match.get_node_or_null("HUD/BottomBar/SelectionPanel/Single") if _match else null
	_in_bar = host != null
	var height = get_viewport_rect().size.y
	var slot = HudStyle.slot_px(height)
	_card = PanelContainer.new()
	_card.name = "BuildingCard"
	if _in_bar:
		_card.theme_type_variation = "ClearPanel"  # the bar is the glass
		_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		host.add_child(_card)
	else:
		_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
		add_child(_card)
	var row = HBoxContainer.new() if _in_bar else VBoxContainer.new()
	row.add_theme_constant_override("separation", COLUMN_GAP if _in_bar else 6)
	HudStyle.margin(_card, 0 if _in_bar else 12, 0 if _in_bar else 10).add_child(row)
	var summary = VBoxContainer.new()
	summary.name = "Summary"
	summary.add_theme_constant_override("separation", 6)
	if _in_bar:
		summary.custom_minimum_size.x = (
			SUMMARY_FULL_PX if slot >= HudStyle.SLOT_FULL_PX else SUMMARY_COMPACT_PX
		)
	row.add_child(summary)
	summary.add_child(_build_header(slot if _in_bar else 48))
	# the slot's resting look, not the dimmed look of a disabled order
	_card_tile.add_theme_stylebox_override("disabled", _card_tile.get_theme_stylebox("normal"))
	summary.add_child(_build_health_row())
	summary.add_child(_build_queue_row())
	var text = VBoxContainer.new()
	text.add_theme_constant_override("separation", 6)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _in_bar:
		var scroll = ScrollContainer.new()
		scroll.name = "Details"  # SelectionPanel.gd sets its width from the cell
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		row.add_child(scroll)
		scroll.add_child(text)
	else:
		text.name = "Details"
		row.add_child(text)
	# the live state (status, cargo, trucks) first, so a long explanation never scrolls it
	# out of sight in the bar; then what the unit is, costs and makes
	_card_body = _rich_text()
	_card_body.meta_clicked.connect(_on_link_clicked)
	text.add_child(_card_body)
	_card_details = _rich_text()
	text.add_child(_card_details)
	_card.hide()


func _build_header(tile_px):
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_card_tile = Button.new()
	_card_tile.name = "IconTile"
	_card_tile.theme_type_variation = "SlotButton"
	_card_tile.disabled = true  # a picture, not an order
	_card_tile.focus_mode = Control.FOCUS_NONE
	_card_tile.mouse_filter = Control.MOUSE_FILTER_PASS  # for the tooltip
	_card_tile.custom_minimum_size = Vector2(tile_px, tile_px)
	header.add_child(_card_tile)
	var inset = round(tile_px * 0.15)
	_card_icon = HudStyle.icon_rect(null, tile_px - 2 * inset)
	_card_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		_card_icon.set_offset(side, inset)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		_card_icon.set_offset(side, -inset)
	_card_tile.add_child(_card_icon)
	_card_chevrons = HudStyle.icon_rect(null, CHEVRON_PX)
	_card_chevrons.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_card_chevrons.offset_left = -4 - CHEVRON_PX
	_card_chevrons.offset_top = -4 - CHEVRON_PX
	_card_chevrons.offset_right = -4
	_card_chevrons.offset_bottom = -4
	_card_chevrons.hide()
	_card_tile.add_child(_card_chevrons)
	var titles = VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(titles)
	_card_title = Label.new()
	_card_title.theme_type_variation = "HeaderLabel"
	_card_title.add_theme_font_size_override("font_size", 18)
	_card_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(_card_title)
	_card_role = Label.new()
	HudStyle.small(_card_role, 12, true)
	_card_role.uppercase = true
	_card_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a rival's owner wraps
	titles.add_child(_card_role)
	_card_rank = HudStyle.small(Label.new(), 12)
	_card_rank.hide()
	titles.add_child(_card_rank)
	return header


func _build_health_row():
	_card_health_row = HBoxContainer.new()
	_card_health_row.add_theme_constant_override("separation", 8)
	_card_health = ProgressBar.new()
	_card_health.max_value = 1.0
	_card_health.show_percentage = false
	_card_health.custom_minimum_size = Vector2(0, 12)
	_card_health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_health.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_card_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_health_fill.set_corner_radius_all(3)
	_card_health_fill.bg_color = HudStyle.GOOD
	_card_health.add_theme_stylebox_override("fill", _card_health_fill)
	_card_health_row.add_child(_card_health)
	_card_hp = Label.new()
	_card_hp.theme_type_variation = "NumberLabel"
	_card_hp.add_theme_font_size_override("font_size", 15)
	_card_hp.custom_minimum_size = Vector2(HP_LABEL_PX, 0)
	_card_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_card_health_row.add_child(_card_hp)
	return _card_health_row


func _build_queue_row():
	_card_queue_row = VBoxContainer.new()
	_card_queue_row.add_theme_constant_override("separation", 2)
	var caption = HudStyle.small(Label.new(), 11, true)
	caption.text = tr("QUEUE_CAPTION")
	caption.uppercase = true
	_card_queue_row.add_child(caption)
	_card_queue = ProductionQueueScene.instantiate()
	_card_queue.name = "ProductionQueue"
	_card_queue_row.add_child(_card_queue)
	# shown or hidden as soon as a unit is queued or leaves the queue, not at the next refresh
	var elements = _card_queue.find_child("QueueElements", false, false)
	elements.child_entered_tree.connect(func(_node): _refresh_queue_row.call_deferred())
	elements.child_exiting_tree.connect(func(_node): _refresh_queue_row.call_deferred())
	_card_queue_row.hide()
	return _card_queue_row


func _rich_text():
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _in_bar:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		label.custom_minimum_size = Vector2(CARD_WIDTH - 24, 0)
	label.add_theme_font_size_override("normal_font_size", 13)
	label.add_theme_font_size_override("bold_font_size", 12)
	label.add_theme_color_override("default_color", HudStyle.FG)
	label.meta_underlined = true
	return label
