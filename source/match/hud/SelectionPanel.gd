extends MarginContainer

# The middle cell of the bottom bar (BottomBar.gd): what is selected. One unit shows
# BuildingInfo's card, which BuildingInfo.gd moves into Single; several units will show
# type tiles in Groups (empty for now). The cell runs from the minimap's right edge to the
# command card's left edge, 8 px from each, so it narrows while the constructor's 6-column
# build menu shows. The card's text column (its ScrollContainer "Details") takes what the
# cell leaves after the card's left column, at most 640 px, so a line never runs across
# the whole bar at 1920. It has no floor: on a narrow screen (1024 wide, or a larger UI
# scale) the column narrows and scrolls rather than widen the card past the cell, which
# would widen the bar past both screen edges. Layout only: the card's contents are
# BuildingInfo's.

const HudStyle = preload("res://source/match/hud/HudStyle.gd")

const DETAILS_MAX_PX = 640
const COLUMN_GAP = 16  # between the card's left column and its text (BuildingInfo.gd)

var _holder = null  # the minimap holder, HUD/MarginContainer
var _menus = null  # the command card, UnitMenus


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # the bar under it takes the clicks
	var hud = get_parent().get_parent()
	_holder = hud.get_node_or_null("MarginContainer")
	_menus = hud.find_child("UnitMenus", true, false)
	resized.connect(_layout)
	if _holder != null:
		_holder.resized.connect(_layout)  # BottomBar sets the compact preset after this _ready
	if _menus != null:
		_menus.resized.connect(_layout)
		_menus.visibility_changed.connect(_layout)
	$Single.child_entered_tree.connect(func(_node): _layout.call_deferred())
	# a smaller window or a larger UI scale: the card's width holds the bar at the old
	# width, so this panel is never resized and has to be told
	get_viewport().size_changed.connect(func(): _layout.call_deferred())
	_layout()


func _layout():
	var height = get_viewport_rect().size.y
	var left = HudStyle.BAR_MARGIN
	if _holder != null and _holder.visible:
		left = int(_holder.get_global_rect().end.x)  # the minimap panel and its 8 px margins
	var card = HudStyle.card_width(height)
	if _menus != null and _menus.is_visible_in_tree():
		card = max(card, int(_menus.size.x))
	var right = card + 2 * HudStyle.BAR_MARGIN
	var details = $Single.find_child("Details", true, false)
	var summary = $Single.find_child("Summary", true, false)
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
