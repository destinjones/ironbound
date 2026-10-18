extends CanvasLayer

# Decides when a match is won, lost or over and plays the ending. On victory or defeat the
# HUD goes away, the camera jumps to where the deciding blow landed and the match runs in
# slow motion for a moment under a VICTORY or DEFEAT banner; then the match pauses behind
# the results: the banner as the title, a table of each player's numbers (MatchStats), a
# score-over-time chart and buttons to play the same match again, keep watching or go back
# to the main menu. Keep watching lets the match run on; a small Results button brings the
# panel back. A match ended by the match limits (time, a dry map) shows the results at once.

signal hold_started(result)  # the slow-motion moment began: "victory" or "defeat"
signal results_shown(result)  # the results panel is up: "victory", "defeat" or "draw"

const Human = preload("res://source/match/players/human/Human.gd")
const MatchLimits = preload("res://source/match/MatchLimits.gd")
const MatchStats = preload("res://source/match/handlers/MatchStats.gd")
const ScoreChart = preload("res://source/match/handlers/ScoreChart.gd")
const Diplomacy = preload("res://source/match/diplomacy/Diplomacy.gd")
const IsometricCamera3D = preload("res://source/match/IsometricCamera3D.gd")
const MenuStyle = preload("res://source/options/MenuStyle.gd")
const HudStyle = preload("res://source/match/hud/HudStyle.gd")
const LoadingScene = preload("res://source/main-menu/Loading.tscn")
const TITLE_FONT = preload("res://assets/ui/fonts/ironbound_title.tres")
const BODY_FONT = preload("res://assets/ui/fonts/barlow-600.woff2")
const NUMBER_FONT = preload("res://assets/ui/fonts/ibm-plex-mono-500.woff2")

const HOLD_S = 2.5  # real seconds of slow motion before the results come up
const HOLD_TIME_SCALE = 0.25  # of the speed the match was running at
const HOLD_STEP_MAX_S = 0.1  # one frame moves the hold's clock by this much at most
const BANNER_FADE_S = 0.4
const RESULTS_FADE_S = 0.25
const DIM_ALPHA = 0.25  # the whole view darkens a little under the band
const BANNER_ANCHOR = 0.33  # the band sits at the top third of the screen
const BANNER_FONT_SIZE = 120  # on the band; it shrinks to the panel's title size afterwards
const TITLE_FONT_SIZE = 84
# a wheel notch (a zoom) or a modifier on its own does not cut the hold short
const WHEEL_BUTTONS = [
	MOUSE_BUTTON_WHEEL_UP,
	MOUSE_BUTTON_WHEEL_DOWN,
	MOUSE_BUTTON_WHEEL_LEFT,
	MOUSE_BUTTON_WHEEL_RIGHT,
]
const MODIFIER_KEYS = [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]

var stats = null
var result = null  # "victory", "defeat" or "draw" once the match is decided

var _human = null
var _limit_reason = null
var _decided = false
var _holding = false
var _hold_left_s = 0.0
var _results_up = false
var _time_scale_before = 1.0
var _band = null
var _band_tween = null
var _dim = null
var _blur = null
var _panel_root = null
var _panel_column = null
var _results_tween = null
var _results_button = null
var _victory_tile = null
var _defeat_tile = null
var _finish_tile = null
var _subtitle = null
var _table = null
var _chart = null


func _ready():
	if not FeatureFlags.handle_match_end:
		queue_free()
		return
	hide()
	stats = MatchStats.new()
	stats.name = "MatchStats"
	add_child(stats)
	_blur = get_node_or_null("BlurredBackground")
	_build()
	await find_parent("Match").ready
	MatchSignals.setup_and_spawn_unit.connect(_on_new_unit)
	MatchSignals.match_limit_reached.connect(_on_match_limit_reached)
	for unit in get_tree().get_nodes_in_group("units"):
		unit.tree_exited.connect(_on_unit_tree_exited.bind(unit))


func _process(delta):
	# the hold's clock runs in real time, capped per frame, so one slow frame (the first
	# after the camera jump on a cold renderer) cannot swallow the whole hold
	if not _holding:
		return
	_hold_left_s -= min(delta / max(Engine.time_scale, 0.001), HOLD_STEP_MAX_S)
	if _hold_left_s <= 0.0:
		_end_hold()


func _input(event):
	# any key or mouse button skips the rest of the hold
	if not _holding:
		return
	var key_pressed = (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and not event.keycode in MODIFIER_KEYS
	)
	var clicked = (
		event is InputEventMouseButton and event.pressed and not event.button_index in WHEEL_BUTTONS
	)
	if key_pressed or clicked:
		get_viewport().set_input_as_handled()
		_end_hold()


func surrender():
	"""ends the match as a loss for the human player (pause menu); after Keep watching it
	brings the results back instead of deciding a second ending"""
	if _decided:
		if not _holding:
			_show_results()
		return
	_decide("defeat")


func is_holding():
	return _holding


func is_results_shown():
	return _results_up


# --- deciding ---------------------------------------------------------------------------


func _on_new_unit(unit, _transform, _player):
	unit.tree_exited.connect(_on_unit_tree_exited.bind(unit))


func _on_unit_tree_exited(unit):
	if _decided or not is_inside_tree():
		return
	var alive = {}  # player -> true, for every player that still has a unit
	for other in get_tree().get_nodes_in_group("units"):
		alive[other.player] = true
	var human = _find_human()
	# the deciding blow: a death, not a unit taken away without a fight (CityCentres)
	var fallen = unit if unit.hp <= 0 else null
	if human == null:
		if alive.size() == 1:
			_decide("draw", false)
	elif not human in alive:
		_decide("defeat", true, fallen)
	elif alive.keys().all(func(player): return not _hostile(player, human)):
		_decide("victory", true, fallen)


func _hostile(player, human):
	"""every other player that is not the human's ally: an enemy at war, a neutral and a
	pact partner all stand in the way of victory, only an alliance excuses a living player"""
	return player != human and not Diplomacy.allied(player, human)


func _on_match_limit_reached(reason, ranking):
	"""time ran out (or the map ran dry): the best score wins, see MatchLimits. The results
	come up at once: the camera has nothing to frame and the pause is expected right away"""
	if _decided or ranking.is_empty():
		return
	_limit_reason = reason
	var human = _find_human()
	var best = ranking[0]["score"]["total"]
	var leaders = ranking.filter(func(row): return row["score"]["total"] == best)
	if leaders.size() > 1:
		_finish_tile.text = tr("MATCH_END_DRAW").to_upper()
		_decide("draw", false)
	elif human == null:
		_decide("draw", false)
	elif leaders[0]["player"] == human:
		_decide("victory", false)
	else:
		_decide("defeat", false)


func _decide(outcome, hold = true, fallen = null):
	_decided = true
	result = outcome
	{"victory": _victory_tile, "defeat": _defeat_tile, "draw": _finish_tile}[outcome].show()
	if outcome == "victory":
		MatchSignals.match_finished_with_victory.emit()
	elif outcome == "defeat":
		MatchSignals.match_finished_with_defeat.emit()
	if hold and _find_human() != null:
		_hold(fallen)
	else:
		_show_results()


# --- the hold ---------------------------------------------------------------------------


func _hold(fallen):
	"""the HUD goes, the camera frames the deciding blow, the match runs in slow motion
	under the banner for HOLD_S real seconds (a key or a click cuts it short)"""
	_holding = true
	_hold_left_s = HOLD_S
	var a_match = find_parent("Match")
	MatchSignals.deselect_all_units.emit()
	_set_hud_visible(false)
	_frame_last_fall(a_match, fallen)
	get_tree().paused = false  # a surrender comes from the pause menu
	_time_scale_before = Engine.time_scale
	if is_equal_approx(_time_scale_before, IsometricCamera3D.HIT_STOP_TIME_SCALE):
		# the deciding blow's hit-stop is running (IsometricCamera3D); it would have put
		# the speed back to 1.0 itself, so that is the speed to come back to
		_time_scale_before = 1.0
	Engine.time_scale = _time_scale_before * HOLD_TIME_SCALE
	_set_blur_visible(false)
	_panel_root.hide()
	_results_button.hide()
	for node in [_dim, _band]:
		node.modulate.a = 0.0
		node.show()
	show()
	_band_tween = create_tween().set_parallel(true)
	_band_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_band_tween.set_ignore_time_scale(true)
	_band_tween.tween_property(_band, "modulate:a", 1.0, BANNER_FADE_S)
	_band_tween.tween_property(_dim, "modulate:a", 1.0, BANNER_FADE_S)
	hold_started.emit(result)


func _exit_tree():
	# a scene change in the middle of the hold must not leave the game in slow motion
	if _holding:
		_holding = false
		Engine.time_scale = _time_scale_before


func _end_hold():
	if not _holding:
		return
	_holding = false
	if _band_tween != null and _band_tween.is_valid():
		_band_tween.kill()
	_band.modulate.a = 1.0
	_dim.hide()
	Engine.time_scale = _time_scale_before
	_show_results()


func _frame_last_fall(a_match, fallen):
	"""the camera jumps to where the deciding blow landed: the unit or structure whose
	death decided the match, else the last fall of the human (defeat) or of the hostile
	players (victory), else a lost city site, else the human's remaining units"""
	var camera = a_match.get_node_or_null("IsometricCamera3D") if a_match != null else null
	var human = _find_human()
	if camera == null or human == null:
		return
	var spot = stats.spot_of(fallen) if fallen != null else null
	if spot == null:
		var owners = [human]
		if result == "victory":
			owners = get_tree().get_nodes_in_group("players").filter(
				func(player): return _hostile(player, human)
			)
		spot = stats.last_fall(owners)
	if spot == null:
		var centres = a_match.get_node_or_null("CityCentres")
		var sites = (
			centres.lost_sites(human) if centres and centres.has_method("lost_sites") else []
		)
		if not sites.is_empty():
			spot = sites[0]
	if spot == null:
		var mine = get_tree().get_nodes_in_group("units").filter(
			func(unit): return unit.player == human
		)
		if not mine.is_empty():
			spot = Utils.Match.Unit.Movement.calculate_aabb_crowd_pivot_yless(mine)
	if spot == null:
		return
	camera.set_position_safely(spot)
	camera.set_size_safely(camera.size - 1.0)  # one wheel step closer


func _set_blur_visible(shown):
	if _blur != null:
		_blur.visible = shown


func _set_hud_visible(shown, with_centres = true):
	"""the HUD layer and, with_centres, the city centres' rings, site labels and rebuild
	countdown (a Node3D with a CanvasLayer), which have nothing left to say once the match
	is lost"""
	var a_match = find_parent("Match")
	if a_match == null:
		return
	var hud = a_match.get_node_or_null("HUD")
	if hud != null:
		hud.visible = shown
	var centres = a_match.get_node_or_null("CityCentres")
	if centres == null or not with_centres:
		return
	centres.visible = shown
	for child in centres.get_children():
		if child is CanvasLayer:
			child.visible = shown


# --- the results ------------------------------------------------------------------------


func _show_results():
	stats.finish()
	_fill()
	var tile = _shown_tile()
	if tile != null and tile.get_parent() != _panel_column:
		tile.reparent(_panel_column, false)  # the banner becomes the panel's title
		_panel_column.move_child(tile, 0)
		tile.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_band.hide()
	_dim.hide()
	_results_button.hide()
	_set_blur_visible(true)
	_panel_root.show()
	show()
	_results_up = true
	get_tree().paused = true
	_fade_in_results()
	results_shown.emit(result)


func _fade_in_results():
	"""the blur and the panel come in over RESULTS_FADE_S real seconds, the tree is paused"""
	if _results_tween != null and _results_tween.is_valid():
		_results_tween.kill()
	_results_tween = create_tween().set_parallel(true)
	_results_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_results_tween.set_ignore_time_scale(true)
	for node in [_panel_root, _blur]:
		if node != null:
			node.modulate.a = 0.0
			_results_tween.tween_property(node, "modulate:a", 1.0, RESULTS_FADE_S)


func _shown_tile():
	for tile in [_victory_tile, _defeat_tile, _finish_tile]:
		if tile.visible:
			return tile
	return null


func _on_keep_watching_button_pressed():
	"""the match runs on; the Results button at the bottom brings the panel back. After a
	defeat the city centre rings, labels and countdown stay away: there is no city to keep"""
	_results_up = false
	_panel_root.hide()
	_set_blur_visible(false)
	_results_button.show()
	_set_hud_visible(true, result != "defeat")
	get_tree().paused = false


func _find_human():
	if _human != null and is_instance_valid(_human):
		return _human
	for player in get_tree().get_nodes_in_group("players"):
		if player is Human:
			_human = player
			return player
	return null


func _player_name(player):
	if player == _find_human():
		return tr("MATCH_END_YOU")
	var a_match = find_parent("Match")
	var diplomacy_hud = a_match.find_child("DiplomacyHud", true, false) if a_match else null
	if diplomacy_hud != null:
		return diplomacy_hud.faction_name(player)
	return "#{0}".format([player.get_index() + 1])


func _build():
	_build_band()
	_panel_root = CenterContainer.new()
	_panel_root.name = "Results"
	_panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_root.hide()
	add_child(_panel_root)
	var panel = PanelContainer.new()
	var style = MenuStyle.panel_style(0.96)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	_panel_root.add_child(panel)
	_panel_column = VBoxContainer.new()
	_panel_column.custom_minimum_size = Vector2(980, 0)
	_panel_column.add_theme_constant_override("separation", 14)
	panel.add_child(_panel_column)

	_subtitle = _label("", BODY_FONT, 20, MenuStyle.MUTED)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_column.add_child(_subtitle)

	_table = GridContainer.new()
	_table.name = "StatsTable"
	_table.columns = 9
	_table.add_theme_constant_override("h_separation", 26)
	_table.add_theme_constant_override("v_separation", 6)
	_table.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel_column.add_child(_table)

	var chart_title = _label(tr("MATCH_END_SCORE_OVER_TIME"), BODY_FONT, 18, MenuStyle.MUTED)
	_panel_column.add_child(chart_title)
	_chart = ScoreChart.new()
	_chart.name = "ScoreChart"
	_chart.custom_minimum_size = Vector2(980, 220)
	_panel_column.add_child(_chart)

	var buttons = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	_panel_column.add_child(buttons)
	var rematch = _button(tr("MATCH_END_REMATCH"), _on_rematch_button_pressed)
	rematch.name = "RematchButton"
	buttons.add_child(rematch)
	var keep_watching = _button(tr("MATCH_END_KEEP_WATCHING"), _on_keep_watching_button_pressed)
	keep_watching.name = "KeepWatchingButton"
	buttons.add_child(keep_watching)
	var exit = _button(tr("MATCH_END_MAIN_MENU"), _on_exit_button_pressed)
	exit.name = "ExitButton"
	buttons.add_child(exit)

	# shown while watching on: bottom centre, just above the screen edge, where neither the
	# HUD (minimap left, unit menus right) nor the diplomacy panel (top) draws
	_results_button = _button(tr("MATCH_END_RESULTS"), _show_results)
	_results_button.name = "ResultsButton"
	_results_button.custom_minimum_size = Vector2(140, 36)
	_results_button.add_theme_font_size_override("font_size", 16)
	_results_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_results_button.offset_left = -70
	_results_button.offset_right = 70
	_results_button.offset_top = -44
	_results_button.offset_bottom = -8
	_results_button.hide()
	add_child(_results_button)


func _build_band():
	"""the hold's dressing: the whole view darkens a little, a hint at the bottom says how
	to skip, and the full-width banner carries VICTORY or DEFEAT in the stencil face on a
	thin dark band, so it reads on any terrain"""
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(MenuStyle.BACKGROUND, DIM_ALPHA)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.hide()
	add_child(_dim)
	var hint = Label.new()  # the same hint as the city build-up's skippable moment
	hint.name = "SkipHint"
	hint.text = tr("MATCH_END_SKIP_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 6)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -56
	hint.offset_bottom = -24
	hint.offset_left = -300
	hint.offset_right = 300
	_dim.add_child(hint)
	_band = PanelContainer.new()
	_band.name = "Banner"
	_band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_band.anchor_top = BANNER_ANCHOR
	_band.anchor_bottom = BANNER_ANCHOR
	_band.offset_top = -84
	_band.offset_bottom = 84
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(MenuStyle.BACKGROUND, 0.82)
	style.border_color = MenuStyle.LINE
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.set_content_margin_all(10)
	_band.add_theme_stylebox_override("panel", style)
	_band.hide()
	add_child(_band)
	_victory_tile = _banner("Victory", tr("MATCH_END_VICTORY").to_upper(), MenuStyle.ACCENT)
	_defeat_tile = _banner("Defeat", tr("MATCH_END_DEFEAT").to_upper(), HudStyle.RUST)
	_finish_tile = _banner("Finish", tr("MATCH_END_FINISHED").to_upper(), MenuStyle.TEXT)


func _fill():
	var human = _find_human()
	var minutes = int(stats.elapsed_s) / 60
	var seconds = int(stats.elapsed_s) % 60
	var reason = ""
	if _limit_reason != null:
		reason = tr(
			(
				"MATCH_END_DEPLETION"
				if _limit_reason == MatchLimits.EndReason.DEPLETION
				else "MATCH_END_TIME"
			)
		)
	var time_text = tr("MATCH_END_DURATION").format(["%d:%02d" % [minutes, seconds]])
	_subtitle.text = time_text if reason == "" else "{0}  ·  {1}".format([reason, time_text])

	var players = get_tree().get_nodes_in_group("players")
	players.sort_custom(func(a, b): return stats.score_of(a) > stats.score_of(b))
	for child in _table.get_children():
		child.queue_free()
	for header in [
		"",
		"MATCH_END_COL_SCORE",
		"MATCH_END_COL_TIER",
		"MATCH_END_COL_BUILT",
		"MATCH_END_COL_LOST",
		"MATCH_END_KILLS",
		"MATCH_END_COL_STRUCTURES",
		"MATCH_END_COL_DELIVERED",
		"MATCH_END_COL_TRADES",
	]:
		var cell = _label(tr(header) if header != "" else "", BODY_FONT, 17, MenuStyle.MUTED)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_table.add_child(cell)
	for player in players:
		var row = stats.counters_of(player)
		var name_cell = _label("■ " + _player_name(player), BODY_FONT, 20, MenuStyle.TEXT)
		name_cell.add_theme_color_override("font_color", player.color.lightened(0.2))
		if player == human:
			name_cell.add_theme_font_override("font", TITLE_FONT)
		_table.add_child(name_cell)
		for value in [
			stats.score_of(player),
			row["tier"],
			row["built"],
			row["lost"],
			row["kills"],
			row["structures"],
			int(round(row["delivered"])),
			row["trades"],
		]:
			var cell = _label(str(value), NUMBER_FONT, 20, MenuStyle.TEXT)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_table.add_child(cell)

	# kept for tests and for anyone reading the old summary text
	var summary = _panel_column.get_node_or_null("ScoreSummary")
	if summary == null:
		summary = Label.new()
		summary.name = "ScoreSummary"
		summary.visible = true
		summary.modulate.a = 0.0
		summary.custom_minimum_size = Vector2(0, 1)
		summary.clip_text = true
		_panel_column.add_child(summary)
	summary.text = _subtitle.text

	var series = []
	for player in players:
		var points = []
		for sample in stats.samples:
			points.append(Vector2(sample["t"], sample["scores"].get(player.get_instance_id(), 0)))
		series.append({"color": player.color, "points": points, "label": _player_name(player)})
	_chart.set_series(series)


func _banner(node_name, text, color):
	var label = Label.new()
	label.name = node_name
	label.text = text
	label.theme_type_variation = "TitleLabel"  # the stencil face
	label.add_theme_font_size_override("font_size", BANNER_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.hide()
	_band.add_child(label)
	return label


func _label(text, font, font_size, color):
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text, callback):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 52)
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(callback)
	return button


func _on_rematch_button_pressed():
	var a_match = find_parent("Match")
	var map_path = a_match.map.scene_file_path if a_match != null and a_match.map else ""
	if a_match == null or a_match.settings == null or map_path == "":
		_on_exit_button_pressed()
		return
	if a_match.scene_file_path != "res://source/match/Match.tscn":
		get_tree().paused = false
		get_tree().reload_current_scene()  # a test scene with its own players and map
		return
	var loading = LoadingScene.instantiate()
	loading.match_settings = a_match.settings.duplicate(true)
	loading.map_path = map_path
	get_tree().paused = false
	get_tree().root.add_child(loading)
	get_tree().current_scene = loading
	a_match.queue_free()


func _on_exit_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
