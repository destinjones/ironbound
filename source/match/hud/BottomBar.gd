extends PanelContainer

# The HUD's bottom bar: one strip along the bottom of the screen with the minimap on the
# left, the selection in the middle (SelectionPanel) and the command card on the right, as
# Generals lays out its bar. It is the first child of the HUD, so it paints under the
# minimap holder (HUD/MarginContainer) and the command card holder (HUD/MarginContainer3),
# which keep their node paths because Match.tscn and the test scenes bind the minimap by
# path. The bar gives them their sizes. It keeps mouse_filter STOP: a click on the bar
# between its cells goes nowhere, so a right click there never orders a move. The two
# holders stop clicks too, since a container lets them through by default and their 8 px
# margins are part of the bar.
# Match.tscn holds the full preset (80 px slots, a 264 px bar); the compact one (64 px
# slots, a 216 px bar, below 900 px of height) is set here at _ready, read once like the
# command card's slots (HudStyle.slot_px).

const HudStyle = preload("res://source/match/hud/HudStyle.gd")


static func of(tree):
	return tree.get_first_node_in_group("bottom_bar")


func _ready():
	add_to_group("bottom_bar")
	mouse_filter = Control.MOUSE_FILTER_STOP
	var height = get_viewport_rect().size.y
	var bar = HudStyle.bar_height(height)
	offset_top = -bar
	var holder = get_parent().get_node_or_null("MarginContainer")  # the minimap's
	if holder != null:
		holder.offset_top = -bar
		holder.offset_right = bar
	for side in [holder, get_parent().get_node_or_null("MarginContainer3")]:
		if side != null:
			side.mouse_filter = Control.MOUSE_FILTER_STOP
	var menus = get_parent().find_child("UnitMenus", true, false)
	if menus != null:
		menus.custom_minimum_size = Vector2(
			HudStyle.card_width(height), bar - 2 * HudStyle.BAR_MARGIN
		)


func top():
	"""the y of the bar's top edge on screen: panels above the bar keep clear of it"""
	return global_position.y
