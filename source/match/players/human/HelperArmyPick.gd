extends RefCounted

# What the helper's army builds, and its save for it (Helper._manage_army decides when to
# order). At each factory the first choice is the faction's main battle unit (the main_t3,
# main_t2 and main_t1 roles in data/factions, the ones the AI builds) of the highest tier
# unlocked, then the lower tiers' main units, then every other combat unit by cost, file
# order on a tie. Units with no room under the unit cap are left out, so a smaller one
# still fills the last slots.
# The helper saves for the first choice for up to SAVE_FOR_S, and nothing cheaper is bought
# at any factory meanwhile. When that window runs out it saves for the next tier's main unit
# instead, still taking a higher one whenever the bank covers it, and goes back to the top
# one when it buys it or a new tier is unlocked. After the lowest main unit's window it buys
# the first unit the bank covers. Kept apart from Helper.gd, near gdlint's 1000-line limit.

const GameData = preload("res://source/data-model/GameData.gd")
const Factions = preload("res://source/data-model/Factions.gd")

const SAVE_FOR_S = 60.0  # the army waits this long for a main unit, then looks lower
const MAIN_ROLES = ["main_t3", "main_t2", "main_t1"]  # highest tier first (Factions.gd roles)
const SCOUT_UNIT_ID = "scout_buggy"  # the helper's scout, never part of its army

var saving_since_s = -1.0  # when the current save began; -1: not saving
var _step = 0  # main units passed over because their window ran out, highest tier first
var _top = null  # the first choice _step belongs to; a new one (a new tier) starts over


static func plans(player, factories, limits):
	"""[factory, ranked scenes, how many of them lead as main units] for every factory with
	room in its queue and something to make, the main unit's factory first"""
	var mains = main_role_scenes(player)
	# slots left under the unit cap, counted once: MatchLimits.has_room_for counts every unit
	var free = limits.slots_cap() - limits.slots_used(player) if limits != null else 1 << 30
	var found = []
	for factory in factories:
		if factory.production_queue.size() >= 2:
			continue
		var ranked = ranked_units_for(player, factory, mains, limits, free)
		if not ranked.is_empty():
			var leading = ranked.filter(func(scene): return scene in mains).size()
			found.append([factory, ranked, leading])
	# the factory that makes the main unit decides first, so another one cannot spend its iron
	found.sort_custom(func(a, b): return a[2] > 0 and b[2] == 0)
	return found


static func main_role_scenes(player):
	"""the faction's main battle units (data/factions roles), highest tier first"""
	var scenes = []
	for role in MAIN_ROLES:
		var scene = Factions.role_scene(Factions.of(player), role)
		if scene != null and not scene in scenes:
			scenes.append(scene)
	return scenes


static func ranked_units_for(player, factory, mains, limits, free):
	"""combat units this factory can make now, first choice first ('mains' from
	main_role_scenes, 'free' the slots left under the unit cap)"""
	var producer = GameData.unit_by_scene(factory._scene_path())
	if producer == null:
		return []
	var allowed = []  # [cost sum, file index, scene]
	var index = 0
	for entry in GameData.producible_by(producer["id"], player.faction):
		index += 1
		if not is_combat_entry(entry) or entry["id"] == SCOUT_UNIT_ID:
			continue
		if not player.can_produce(entry["scene"]):
			continue
		if limits != null and limits.slots_of(entry["scene"]) > max(free, 0):
			continue  # as MatchLimits.has_room_for
		var cost = Constants.Match.Units.PRODUCTION_COSTS.get(entry["scene"], {})
		allowed.append([Utils.Dict.sum(cost), index, entry["scene"]])
	var scenes = allowed.map(func(item): return item[2])
	var ranked = mains.filter(func(scene): return scene in scenes)
	allowed.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	for item in allowed:
		if not item[2] in ranked:
			ranked.append(item[2])
	return ranked


static func first_affordable(ranked, can_spare):
	"""the first of 'ranked' whose cost 'can_spare' (Helper.spare) lets through, or null"""
	for scene in ranked:
		if can_spare.call(Constants.Match.Units.PRODUCTION_COSTS.get(scene, {})):
			return scene
	return null


func choose(plan, clock_s, can_spare):
	"""[unit to order or null, unit saved for or null] at the main unit's factory"""
	var ranked = plan[1]
	if ranked[0] != _top:
		_top = ranked[0]
		_step = 0
		saving_since_s = -1.0
	for step in range(mini(_step, plan[2] - 1), plan[2]):
		_step = step
		var choice = first_affordable(ranked.slice(0, step + 1), can_spare)  # it, or a higher one
		if choice != null:
			return [choice, null]
		if saving_since_s < 0.0:
			saving_since_s = clock_s
		if clock_s - saving_since_s < SAVE_FOR_S:
			return [null, ranked[step]]
		if step + 1 < plan[2]:
			saving_since_s = clock_s  # its window ran out: the next tier's main unit gets one
	var fallback = first_affordable(ranked, can_spare)
	return [fallback, ranked[plan[2] - 1] if fallback == null else null]


func bought(scene, plan):
	"""an order went in at the main unit's factory"""
	saving_since_s = -1.0
	if scene == plan[1][0]:
		_step = 0  # the top one was within reach: save for it again


func reset():
	"""not saving: the army is off or full, has no factory, the cap is reached, the main unit's
	factory is busy, or the helper was switched off"""
	saving_since_s = -1.0


static func is_combat_entry(entry):
	return (
		entry != null
		and entry.get("category", "unit") == "unit"
		and entry.get("properties", {}).get("attack_damage") != null
		and entry["id"] != "hauler"
		and entry["id"] != "caravan"
	)


static func unit_name(scene_path):
	var entry = GameData.unit_by_scene(scene_path)
	if entry == null:
		return scene_path.get_file().get_basename()
	return TranslationServer.translate(entry["name"])
