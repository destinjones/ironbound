# Decisions

Notable choices and the reason for each, newest last, so the next session knows why.

## 2026-10-11: art direction, feel spec and working agreement
docs/art-direction.md, docs/feel.md and CLAUDE.md are the source of truth for art and feel
work. Features are frozen until the feel layer of existing units is done. The feel work runs
as six tickets, one vertical slice per PR, in this order: turn-to-face with accel/brake,
death animations with persistent wrecks, weapon VFX, recoil and turret lead, screen shake
and hit feedback, then the textured pipeline starting with the tank. Why: "make it modern"
gave no target to measure against; the docs are the ruler and screenshots the measurement.

## 2026-10-11: HUD redesign and onboarding parked
A HUD declutter and first-five-minutes pass (intro camera, quick battle, delayed AI offers)
were started and then stopped. Why: they are new features, and features are frozen until
the feel layer is done.

## 2026-10-11: ticket 1 may change unit movement
Destin approved turn-to-face and acceleration/braking in the movement trait, which is core
simulation. Pathing, the navmesh and avoidance settings stay untouched, and
"turn_to_face": false in data/movement.json restores the old movement. Why: the instant facing
snap and constant speed were the main cause of the sliding feel, and a visual-only fix can't
remove them. Known cost: a tank ordered behind itself turns in place first and arrives about
1.3 s later (tracked turn rate 150°/s).

## 2026-10-11: onboarding cleared despite the feature freeze
Destin asked for the onboarding and first-run thread (guided first match, first-time
hints, tooltips, first-run defaults, searchable manual) explicitly, so it goes ahead while
features are otherwise frozen. It stays out of models, shaders, VFX, audio and the control
layer.

## 2026-10-11: tutorials are data, run through the play harness
The tutorial steps moved from a constant in Guide.gd to data/tutorial/*.json: standard.json
keeps the old ten steps for every Guided match, first_match.json is the guided first match
on the main menu. A step waits for one of a fixed list of conditions (Guide.CONDITIONS) and
may run play-harness orders when it starts (give, spawn, declare_war, camera), so new
tutorials need no code. The same script is played end to end by
tools/harness/scenarios/tutorial-first-match.json. Why: Destin asked for data, not
hard-coded cutscenes, and reusing the harness keeps one order format. Known gap: a save
made mid-tutorial resumes with the standard steps, because carrying the script name would
change the save format, which needs asking first.

## 2026-10-11: first-time hints are remembered in the options
A hint (HINT_*) now shows once ever, not once per match. The keys it has shown are kept
in Options (`seen_hints`, saved in options.tres), with a "Show first-time tips" switch and
a "Show all tips again" button on Options > Interface. Only a real game, one started from
source/Main.gd, writes them (FeatureFlags.remember_first_run), so tests and the play
harness never use up a player's hints. Alerts (unit cap, city full, raids) are not hints
and still repeat. Why: hints that come back every match read as nagging.

## 2026-10-11: build-menu tooltips are cards made from the building-card data
Build and production buttons open a rich hover card (RichTooltipButton + Tooltips.gd)
built from BuildingInfoText, the same source as the selection card: role, what it does,
needs, makes, health, the cost with what the player is short of, and why it is locked.
The plain tooltip_text (BuildMenu.describe) stays as the fallback. The controls thread
owns hud/ layout; this only swaps the button class and fills the tooltip. Why: one source
of truth for what a building does, and a locked or unaffordable button says why.

## 2026-10-11: first-run defaults and the intro card
On the very first launch the main menu shows a "What is Ironbound?" card (IntroCard.gd):
four lines on the game loop, then Play the tutorial or Go to the menu. Either answer sets
Options.intro_seen, so it shows once. The Play menu starts a new player on Plain & Simple
(small, open, 50x50) against an Easy AI, then remembers the last map and AI difficulty
(Options.last_map, last_ai_difficulty). Like the hints, only a real game writes these
(FeatureFlags.remember_first_run, renamed from remember_seen_hints). Why: the old default
was whichever two-player map sorted first, often a large or asymmetric one, against a
Normal AI; AoE4 and Northgard both point a new player at a guided match first.

## 2026-10-11: the manual is searchable and hints link into it
The F1 manual has a search box (Ctrl+F): it keeps the topics whose title or text holds
every word typed, title matches first, and marks the words. Each hint names its manual
topic (Guide.HINT_TOPICS) and shows a "Read more" button that opens it; alerts have none.
The "(F1: ...)" pointers in two hint texts went, the button replaces them. Known gap:
the camera polls W A S D, so typing in the search box also pans the map; the fix belongs
to the camera (control layer), passed to the controls thread.

## 2026-10-11: control and UX layer cleared despite the feature freeze
Destin asked for a second thread to bring the controls up to the StarCraft II standard
(docs/feel.md, "Control"), so it runs alongside the feel work instead of waiting for it. It
owns source/match/hud/ layout, input and camera handling; the art thread owns models,
shaders, VFX and the model fields in data/units/; the audio thread owns all sound, and the
onboarding thread owns translations, tooltips and the manual. Four PRs, one per area:
selection, orders, camera, feedback. Most of the list already existed (box select,
double-click, groups, attack-move, queued orders, rally points), so each PR only fills gaps.

## 2026-10-11: selection works like StarCraft II
A box over units and buildings takes only the units, so sweeping across the base grabs the
army; a box with only buildings still takes them. Ctrl + click selects all of a type on
screen, like a double-click. Shift + number adds to a group, and pressing a group's number
twice within 0.4 s centres the camera on it. The group bar sits top centre under the
diplomacy bar, because the bottom centre is taken by the unit card next to the minimap.

## 2026-10-11: audio and reactive soundscape cleared despite the feature freeze
Destin asked for the audio thread explicitly, so it ran alongside the feel work. It owns
data/sounds/, assets/audio/ and the playback code; Thread A owns voices.json entries for new
units. Five PRs (#57, #58, #60, #61, #64): an ambient bed, unit presence, combat density,
economy feedback, then spatialization and the mix. The full reasoning is in
docs/audio-soundscape.md ("Decisions"); the ones that shape later work:
- The ambient bed reads MusicPlayer's heat state instead of detecting threat itself, so the
  music and the world escalate together and there is one place to tune.
- Unit presence is one mixed loop per layer (engines, footsteps, rotors), not one per unit.
- Combat, economy and mix levels are data (data/sounds/*.json) keyed by unit id.
- Ducking is sidechain compressors on the buses, so the Options sliders stay in charge, and
  a crowd of sounds drops the quiet low-priority ones rather than whichever came last.
- Sounds are synthesized with numpy (tools/audio/), so they are original and regenerable.

## 2026-10-11: the tank is the first unit on the textured pipeline
The Foundry tank was remade from a GPT Image 2.5 concept through Tripo H3.1 and
tools/blender/clean_generated.py (Destin picked "modern light MBT", concept B). It keeps
one 1024 px base colour plus one normal map, team colour on upward faces only, and a
separate Turret node for TurretAim. It is decimated to 3,600 triangles, the old tank's
count, because 4,762 cost about 15% more frame time in UnitModelBench (llvmpipe) for no
visible gain at play zoom. Why: the art direction makes the tank the reference every other
unit is matched against, so it goes first. Known cost: still slower than the old
vertex-coloured tank on a software renderer (64 vs 50 ms for 30 copies); a real-GPU bench
is owed.

## 2026-10-11: rally points show where they send units
A selected factory now shows a dashed teal line from its edge to its rally point, and the
marker stays visible when the rally point follows a unit (it used to vanish). Dashed so it
does not read as an order the building carries out; teal so it is not confused with the
green move lines. Attack-move stays on F: A scrolls the camera (WASD), and controls.cfg
can rebind it for anyone who wants StarCraft II's A.

## 2026-10-11: the cursor says what a click will do
With units selected, the cursor turns into a red crosshair over an enemy they can attack and
a yellow build mark over an unfinished building a selected constructor can build; while
fight, patrol or guard waits for its click it shows that order's crosshair in the colour of
its ground line. An order nobody can carry out flashes a red "no" cursor and leaves a red
cross on the spot. The sound for it belongs to the audio thread: it can bind to
MatchSignals.units_ordered(units, "cannot"), which this layer only reacts to visually.
Cursors are tinted Kenney crosshairs (already in assets/ui), so no new art. The selection
box now reads the harness's virtual mouse too, and is green like the move lines.

## 2026-10-11: the camera follows the cursor, like StarCraft II
The mouse wheel zooms towards the cursor: the ground under it stays under it, and the zoom
glides over a fraction of a second instead of jumping a step. Edge scrolling eases in over
0.12 s and out over 0.08 s rather than starting and stopping dead. The minimap pings: a hit
on one of your units or buildings rings it red (one ping per 12 m spot every 6 s, so a fight
reads as one ping), and Alt + click marks a spot in yellow without moving the camera. A plain
click or drag on the minimap still jumps the camera. All the timings are exported on
IsometricCamera3D and constants in hud/MinimapPings.gd. Why: zoom-to-centre made you re-aim
after every wheel notch, and an attack off screen gave no sign at all. Pings have no sound
here; the audio thread can bind to MatchSignals.unit_damaged. Map keys (W, A, S, D, Q, E) are
ignored while a text field has focus, so typing into a search box no longer pans the map.

## 2026-10-13: the remade tank's cost is fine on a real GPU
The GPU bench owed by the tank remake (#56) ran on an RTX 3060 (Vulkan, Forward+, Godot
4.7.2) with UnitModelBench, 5 rounds of 300 frames. 30 copies cost 0.33 ms per frame with
the new tank against 0.31 ms with the pre-#56 tank (classic control 0.26 to 0.28 ms between
runs), so the gap is inside run-to-run noise. At 150 copies it is 0.78 against 0.60 ms, about
2.7 against 2.3 ms per frame in total, still several hundred fps. Why it matters: the 64 vs
50 ms gap on llvmpipe was texture and normal-map sampling that a software renderer
exaggerates, so the textured pipeline (one base colour plus one normal map per unit) stays
the plan for the other units and no decimation or texture cut is needed for the tank.

## 2026-10-17: late-game hitches came from extractor planning, not the GPU
On an RTX 3060 at 1080p High the GPU needs 4.5 to 5.7 ms a frame in a 4-player match, so
rendering is not what lags. What players feel is a 60 to 90 ms frame every few seconds from
minute 2 on. The helper's auto-build (AutoExpand._think) and the AI's economy
(EconomyController._refresh) re-plan extractors every 1.5 s and spent up to 70 and 30 ms
doing it: every deposit re-scanned every unit (and every deposit again, through a deep
find_child per radius read), the AI instantiated a building just to read its radius on each
try and searched every spot twice, and placement checks rebuilt the obstacle list per try.
They now scan once per plan, cache radii, and rank a deposit by its cheap score before the
unit scans and path queries. The plans they make are the same. The fix is in the planning
code rather than a longer think interval, because a slower helper would build later.
tools/harness/scenarios/bench-late-game.json is the benchmark for this; see
docs/testing/play-harness.md.

## 2026-10-17: fights last long enough to watch and steer
Every unit and structure has 3x the HP it had, and direct-fire weapons reach about 40%
further (tank 5 -> 7 m, heavy tank 5.5 -> 7.5 m, militia 4.5 -> 6 m, artillery 11 -> 15 m;
defences keep their ranges; sight grows with range so units still spot an enemy
3 m before it is in range). Damage, fire rates and costs are unchanged. Measured in open
ground on Big Arena with the play harness: a 1 v 1 tank fight went from about 4 s to about
13 s, and in 5 v 5 tanks the time from the first loss to the last went from 5 s to 16 s.
Why: the values were the Open RTS template's, so armies met hull to hull and were gone
before the turret aim, recoil, wrecks or control groups could matter. Scaling HP for
buildings too keeps a raid on a factory or a supply line at the same pace relative to a
fight. Known effect: a save made before this loads its units at a third of their health,
since saved hp is kept and hp_max triples.

## 2026-10-17: the resource bar shows whole numbers
Stock is fractional because upkeep drains it bit by bit, so the bar read "46.0". It now
shows whole units, rounded down so it never shows more than you can spend.

## 2026-10-17: building sites no longer stall
Two stalls in a 10-minute match on Oil and Iron, traced with a probe that logged every site,
truck and constructor every 15 s. First, a site whose constructor was given another order
stayed at 0% for the rest of the match while the other constructors stood idle; the AI
already sends idle workers to unfinished sites (ConstructionWorksController), the player
only did with auto-expand. Now Human has IdleConstructors: a constructor with no order for
3 s goes to the nearest site nobody is building, skipping sites with an enemy within 14 m.
Second, trucks carry 10 and the oil derrick costs 11, so its last unit of copper was a
1-unit supply job; the job board values a trip by its load, so it lost to every pickup and
the derrick stood at 91% for 8 minutes. Supply trips are now valued as a full truck. After
both, the derrick finishes at about 90 s and the player ends the match with 179 oil instead
of 9. Not fixed, because it is pathing: once, a truck carrying materials for a derrick 1 m
from where it is usually placed never arrived (MovingToUnit retries the same spot forever).
Copper staying at 5 on Oil and Iron is by design: that map gives this side oil, and copper
comes from trade or the contested deposits.

## 2026-10-17: matches have a clock: dawn, day, dusk and night
data/time_of_day.json drives one light through 24 hours (TimeOfDay.gd, owned by
Atmosphere). The look still sets the noon sun; the clock scales its height, swings its
azimuth, and multiplies energy, colour, ambient, exposure and haze tint on top of weather and
look. The moon is the same DirectionalLight: it swaps in during twilight while the light is
dim, so there is no second shadow-casting light and no extra frame cost. A day is 16 minutes
and night hours pass 2.5 times faster, so a match starts at 10:00, gets dusk at about minute 8
and has about 3 minutes of night per day. Why: one fixed noon light made every minute of
every match look the same. Night lowers sight to 0.85 through the same WeatherEffects
multiplier weather already uses (sandstorms go to 0.55), so it is felt but mild. Night must
stay readable: exposure drops to about half and the light turns blue rather than going dark.
The sun turns in 0.25 degree steps so shadow edges do not crawl. The hour is not saved
(the save format is untouched), so a loaded game restarts at 10:00, as weather already
restarts. tests/screenshots/WeatherShots renders any weather at any hour.

## 2026-10-17: text over units shows only when it needs you
Labels floating over buildings and units ("Iron 6/16", "Constructor on the way", "Hauler 2")
now show only while that thing is hovered or selected, or while a constructor is selected
for site labels. Three states stay visible all the time because nothing happens until the
player acts: a site nobody is building, a full extractor that has stopped, and an aircraft
with no airport to return to. All of them use the HUD's Barlow font as a signed distance
field (WorldLabel.gd), so they stay sharp at any zoom instead of the tiny pixel font, and
the shouting capitals ("NO AIRPORT - WILL CRASH") became sentence case. Why: the playtest
of 17 Oct found debug-looking text all over the base; the tests that check a waiting site
and a full mine still see their labels.

## 2026-10-17: rain soaks the ground, and lightning is a bolt you can see
Rain used to be thin streaks over a sunny, dry desert. Now the terrain shader has a
`wetness` uniform that Atmosphere raises over about 30 s of rain and lets fall over about
2 minutes after it (faster in sandstorm wind): soaked sand darkens and turns glossy, and
small puddles collect in low noise spots on flat ground. Rings splash on the ground under
the rain (one more GPUParticles3D, 900 flat quads, following the camera like the rain and
thinned when zoomed out). Heavy rain's lightning now draws a branching bolt somewhere in
view, built once per strike as an ImmediateMesh, with a short unshadowed OmniLight3D where
it lands, so nothing runs between strikes. Atmosphere emits `lightning_struck(position)` so
the sound side can add thunder with a delay; this PR adds no audio because the sound thread
owns the mix. Wetness is visual only: ground speed and sight still come from the weather.

## 2026-10-17: birds and vultures, the first piece of a living world
Destin asked for a game that feels alive rather than dull, and lifted the feature freeze for
it. The first piece is wildlife (source/match/environment/Wildlife.gd, data/wildlife.json):
small flocks of birds wander over the map, settle on dry open ground to feed, and burst into
the air when a unit walks up or something is hit nearby; vultures turn up over some fresh
wrecks and circle for about 45 s. Choices that shape later world-life work:
- Purely visual: its own random numbers, nothing saved, no effect on the simulation or on
  replays. Wildlife reacts to the war (MatchSignals.unit_damaged, camera_shake, new wrecks)
  and never the other way round.
- One MultiMesh per kind, wings beaten in the vertex shader (bird.gdshader), so all birds
  cost two draw calls plus shadows. The script moves only the flocks on screen; a flock off
  screen moves as a point and its birds take their places when it comes back into view, and
  nothing is drawn zoomed out past camera size 45, where a bird is a speck.
- Cost, measured headless on the cloud CPU (slow GDScript): about 0.15 ms a frame in a
  normal view on a 110 m map with 100 units, about 0.3 ms with every flock in view.
- Birds and vultures are simple shapes, not textured models: at play zoom they are 20 to
  50 px across and read by their motion and silhouette, so the unit pipeline does not apply.

## 2026-10-17: no trade or treaty offers during the guided first match
Rival trade offers and treaty offers to the player are dropped while a scripted tutorial
(the guided first match) runs, until it reaches a trade step if it has one. The AI keeps
offering, so the first offer after the tutorial still arrives, and skipping the tutorial
lifts the hold. The standard tutorial of a normal match still lets offers through: it
teaches trading itself, and PlaytestChecks expects an offer box there. Why: in the first
match a deal box opened inside the city card within two minutes, before the player had
built a mine.

## 2026-10-17: the interface has sounds
Every button in the menus and the HUD now clicks, toggles latch, cancel and close tick lower,
and hover ticks in the menus (not in a match, where the HUD is always under the pointer).
An order nobody can carry out knocks, and minimap pings blip (two urgent blips for a hit,
one soft blip for a mark), taking up the two hooks the control threads left for audio
(units_ordered "cannot" and the minimap pings). One autoload (audio/InterfaceSounds.gd)
wires buttons as they enter the tree, so no scene was edited and new UI is covered for free.
Why: the game had no interface sound at all, which is a large part of why it felt dead
under the hand. Levels in data/sounds/interface.json; sounds synthesized by
tools/audio/make_interface_sounds.py like the rest.

## 2026-10-17: new players start on Desert Expanse
The main menu's first map and the guided first match moved from Plain & Simple to Desert
Expanse. Plain & Simple is the template's 50 m test plane: flat beige ground with the base
7 m from the edge, so about 40% of a new player's first screen was black void. Desert Expanse
is generated (cracked ground, scrub, palms, a lake) with even resources on every side, unlike
Oil and Iron, which gives one side no copper. Plain & Simple stays in the map list and stays
the harness's default map, so no test fixture moved. The tutorial ran to its end on the new map.
The tutorial's last step now sends one rival scout instead of two: with fights lasting longer
(see above), the second scout escaped across the bigger map and the step never ended.

## 2026-10-17: units earn ranks from kills (veterancy)
Destin asked for more features to make matches less dull, lifting the feature freeze for
this. Mobile units now earn experience from kills, worth the victim's cost (half for a
structure), and rank up to Veteran (12), Elite (32) and Heroic (64): +15/30/50% damage,
+10/20/35% hp, and from Elite on faster fire and self-repair after 6 s out of the fight.
Gold chevrons sit over the health bar, with a star for Heroic. Why: it gives players a
reason to keep a unit alive and pull it back, and a fight leaves a mark beyond losses. All
numbers are in data/veterancy.json. Kill credit reads Unit.take_damage's "last_hit_by" meta,
so no unit or combat code changed. Turrets and militia posts do not rank, because
CivilDefense drives their fire rate. Known gap: ranks are not in save files yet (save format
needs Destin's OK), so a loaded match starts everyone green. MatchSignals.unit_promoted is
there for the sound and UI threads to bind a promotion sting and a card line.

## 2026-10-17: the wind moves the land
Second piece of the living world (source/match/environment/Wind.gd, data/wind.json): trees,
palms, reeds, bushes and grass of the desert scatter bend with Atmosphere's wind, gusts
rolling across the map as a slow wave; a few tumbleweeds roll over open ground, around rocks
and tree clumps, and fade out at water or after a while; on clear or hazy days a dust devil
spins up every half minute or so and drifts off. Choices:
- Purely visual, its own random numbers, nothing saved.
- The plants keep their flat colours: Wind.gd copies each swaying prop's mesh and swaps its
  StandardMaterial3D for foliage_sway.gdshader with the same albedo, roughness and specular,
  so they look as before when the air is still. Only the props named in data/wind.json sway;
  rocks, cacti and dead trees stay put.
- The plants and dust devils move in vertex shaders, so they cost no script time; the script
  sets the wind on the plant materials four times a second and moves only the tumbleweeds
  (one MultiMesh). Headless on the cloud CPU that is about 0.05 ms a frame for 7 tumbleweeds.
- Dust devils stay away in rain and sandstorms (the sandstorm is its own dust).

## 2026-10-17: cities smoke and their people walk the streets
Cities were the dullest thing on the map: rings of houses that never change. CityLife.gd
(data/city_life.json) gives them two signs of life, both visual only and invisible until the
player has seen the building:
- Chimney smoke: workshops pour dark smoke most of the time, houses send up thin pale smoke
  now and then, leaning with Atmosphere's wind and damped by rain. The models have no chimney
  nodes, so the chimney tops are points per model in the data file (workshop stack, roof vents
  of the houses); a model with no entry does not smoke. Each chimney is one instance of a
  32-puff column in one MultiMesh, moved in chimney_smoke.gdshader, so smoke costs no script
  time beyond writing one strength per chimney four times a second.
- Townsfolk: people step out of a building, walk to a neighbour, the city centre or down the
  street, chat on the doorstep and go in. They come out of and go into the buildings (they
  start and end inside the walls), so no one pops into view. Paths are straight lines checked
  against the city's buildings and nearby units, with one detour point if blocked; they do
  not use the navigation map, because they are decoration and should never touch pathing.
  When a unit is hit or something explodes within 10 m they run for the nearest door and
  nobody comes out there for 15 to 30 s, so a fight in town empties the streets.
- Limbs swing in townsfolk.gdshader; the script only moves and turns each person. Up to 22
  per city and 70 in all, hidden when zoomed out past camera size 40. Headless on the cloud
  CPU: about 0.05 ms a frame for a 21-person city, 0.17 ms with 69 people.
- No traffic: the supply trucks on the roads (Logistics) already are the traffic.

## 2026-10-17: neutral outposts to capture between the cities
Part of Destin's ask for more to do and more ways to expand. Each match places one outpost
in the centre and one between each pair of neighbouring spawn points (5 on a 4-player map),
moved off water, forests, deposits and start zones. Standing combat ground units in the
ring with no enemy inside captures it in 14 s, faster with more units up to 2x. A rival's
outpost is pulled down to neutral first, so taking one from someone takes twice as long.
Each outpost pays 2 iron, 1 copper and 2 oil every 10 s with no trucks, which is about half
an extractor, and reveals the fog around it. Why: the maps had nothing worth fighting over
between the bases, so armies only met at someone's city. The AI sends a squad of its raider
unit to the nearest outpost it doesn't hold (OutpostController.gd), and only goes after an
enemy's outpost when it would attack that player anyway. A map entry can list its own spots
("outposts": [[x, z], ...]) or turn them off ("outposts": 0). Known gap: outposts are not in
save files yet (save format needs Destin's OK), so a loaded match starts them neutral.

## 2026-10-17: supply drops give the middle of the map something to fight over
From about two minutes in, a crate parachutes down every 80 to 120 s somewhere between the
cities (at most two waiting at once), with a beacon and a yellow minimap ping. The first
ground unit to reach it takes it: goods (iron, copper, oil, timber), a repair of that
player's units around it, or experience for them when veterancy is on (goods otherwise).
Unclaimed crates vanish after 150 s. The AI sends its nearest free combat unit for a crate
within 40 m of it and keeps that unit out of its army meanwhile. Why: matches had long quiet
stretches with nothing to do outside the base; a crate is a small, visible reason to move out
and skirmish, and it rewards fast scouts. All numbers live in data/supply_drops.json; crates
are not saved (a loaded match just drops new ones), so the save format is untouched.


## 2026-10-17: the website lives at destinjones.github.io/ironbound/
The repo was renamed from godot-open-rts to ironbound. GitHub redirects the repo's own
URLs after a rename, but a GitHub Pages project site moves to the new name with no
redirect, so every link to destinjones.github.io/godot-open-rts/ (README, canonical tags,
sitemap, robots.txt) pointed at a dead path. BASE in tools/site/build.py now uses
/ironbound/ and site/ was regenerated. github.com/destinjones/godot-open-rts links were
left alone because those still redirect. The README now opens with the hook ("You never
place a house. The city builds itself.") and names the engine second, because players
decide from the mechanic, not the tech.

## 2026-10-17: a unit that stopped next to a building counts as there
A truck could stand next to a site or extractor for the rest of the match. Units sent to
a building stop anywhere within their target_desired_distance (0.5 m for vehicles) of their
spot, but "touching" was measured with a 0.3 m margin, so a truck that stopped 1 cm too far
out headed for the building's centre, was blocked, and did it again forever. Now adherence
adds the mover's own arrival tolerance (UnitMovementUtils.units_adhere), and MovingToUnit
heads for the target itself only once before handing back to its caller. In the movement
bench, more units end next to their target building (squeezed mine 3 -> 6) and settle sooner;
in a 10-minute Oil and Iron match that had a truck stuck 1 cm out, none get stuck.

## 2026-10-17: v0.10.0 desktop builds, and docs screenshots kept out of the game
The release workflow already exported Windows, Linux and macOS zips; v0.9.0 was published
on 6 October but was 190 commits behind main, and the README never linked to it. Bumped
the version to 0.10.0 (project.godot and the export presets, which still said Open RTS's
0.9.0) and added a Download section that links releases/latest/download/<zip>, so the
links follow every new release. Added docs/.gdignore: the export filter is all_resources,
so Godot was importing the 40 README screenshots in docs/images and packing them into
every build. Nothing in the game loads them; the Linux zip drops from 140 MB to 94 MB.

## 2026-10-17: a browser build at <site>/web/
Step 2 of Destin's path to players: a link that opens the game with no download. The
"Web" export preset is single-threaded (no SharedArrayBuffer), so it runs on GitHub Pages,
which cannot send the COOP/COEP headers a threaded build needs, and on itch.io without
their SharedArrayBuffer switch. The browser uses the Compatibility renderer; the game's
shaders and the match render correctly there with no changes. The Website workflow exports
it into site/web/ on every merge that touches the game or the site. It lives at /web/, not
/play/, because play.html is already the manual and Pages would serve /play as that page.
Web-only changes: Quit is hidden (it would freeze the page), the stored fullscreen option
is not applied at start (a browser refuses fullscreen without a click; the Options screen
still switches it), and the crash reporter is off (a closed tab looks exactly like a crash
to it, it cannot open its folder, and its hang watchdog needs threads). The preset leaves
out docs/, tests/, media/ and site/. Download is 73 MB of game data plus a 38 MB engine;
on a 50 Mbps line the menu is up in about 23 s, locally in 3 s. Shrinking the textures for
the web is the next lever if that proves too slow.

## 2026-10-18: units stand off the sand (look, team colours, infantry size)
Destin linked a Generals-style RTS demo whose models "read better than ours". The demo
could not be fetched, but our own frames showed the cause was not model detail: tan units on
pale sand under exposure 1.4, pastel team colours (#66b1ff blue, #ff5c73 red) and infantry
about 35 px tall at play zoom. Data only: the Grounded look drops exposure 1.4 -> 1.15, the
sand and hardpan colours about 10% darker, shadow blur 0.8 -> 0.45, lift 0 and contrast
1.16; the twelve player colours are now saturated mid-value (blue #2d7ff0, red #e3313f,
green #39b54a, ...); militia model_scale 0.7 -> 1.0, so a rifleman stands 1.8 m (about
55 px at camera size 15, close to the 60 px rule). Why: the eye reads value contrast and
saturation first, and the pastel colours were brightened again by the exposure; the tank
pipeline work is wasted if the ground outshines the unit. A first pass with saturation 1.08
came out orange and went back to 1.0. Before/after shots in the project folder under
game/art/readability/. Tri counts unchanged (militia 3,366); UnitModelBench militia 30
copies 72 ms on llvmpipe, the same model as before. The textured pipeline for the other
units (bake, don't decimate) is the next step and is owned by the direction thread.

## 2026-10-18: the AI refills and grows its attack waves, so matches end
Five probe matches on main (project folder game/direction/probes/) showed why a match never
ends: the balanced Normal AI formed its two battlegroups once, lost most of each on the first
attack around minute 6, and then never built another battle unit, because a group with one
survivor kept its slot for the rest of the match and the production count subtracted whole
groups. The AI then sat on 1,700 iron while a helper-run player's 15 idle tanks stood at the
rally point; nobody won in 30 minutes. Now a group that has lost two thirds of its planned
size sends the survivors home and dissolves, the next group forms at once, the factory keeps
producing a wave for every empty slot, and each wave is bigger: "waves" in data/ai/*.json
(balanced +1 unit every 180 s up to 12; raider +1 per 150 s up to 8; turtle +1 per 300 s up
to 12; trader +1 per 300 s up to 6), scaled by the difficulty's wave_growth_scale (very easy
0, easy 0.5, normal 1, hard 1.5, brutal 2). The same probes on this branch: the passive
player's command centre falls at 5:41 and the match ends at 7:35 (was: never); the helper-run
player with a 24-unit army falls at 10:08 and the match is over at 11:44 (was: never, the AI
stuck at 15 units). Normal is now too strong for a player whose army does not defend its base
and whose iron never passes 10; the next two changes (the idle army defends the base, then
the economy pace) are where the difficulty gets re-tuned, not here. The first wave keeps the
personality's size, so the setup check's battlegroup assertion still holds.

## 2026-10-18: the direction, written down (docs/direction.md)
Destin asked for the game to be taken from "vibe coded slop" to something that looks, feels
and behaves like a complete game, and handed over the direction. Five probe matches and a
read of every subsystem (AI, economy, match arc, combat, HUD, presentation) gave the same
answer: the pieces exist, the arc does not. Nobody won in 30 minutes, the army ignored the
base, the economy stalled at the start, combat had no roles. The direction is one sentence,
"a 20 to 25 minute skirmish against an AI that escalates and finishes", with a four-point
ruler for every change (makes the arc happen, creates a decision, readable without the
manual, holds at 20 vs 20), a keep list, a cut list, and the order of work. Why this order:
the AI finishing (done), the army defending and the economy pacing come first because they
make a match playable at all; counters and difficulty make it interesting; the ending and
the HUD make it readable; art and sound last because they are worthless on a game that is
not fun, and the pipeline for them already exists. Measured targets are in the document so
the next session can tell whether a change worked.

## 2026-10-18: the home deposits are inside the base (economy pace)
The opening crawled: on Desert Expanse the home deposits sit 13 to 15 m from the command
centre (start zone 6 m plus 7 to 9 m), the command centre's grid reached 10 m and its yard
9 m, so every opening extractor ran at half rate until a power plant stood next to it and
each one waited for a truck, and copper was not a home deposit at all, the nearest copper
24 m out and invisible to a new player. Now the command centre's grid and yard both reach
16 m (data/units/command_center.json, MatchConstants.Logistics.YARD_RADIUS_M) and Desert
Expanse's home deposits are iron, oil and copper. Home deposits were always the "safe start
economy" by design; making them pay from the first minute removes busywork, not a decision,
because the richer contested and middle deposits still need power, trucks and an escort.
Measured with the opening probe (tutorial opening, then only tanks, eight minutes, seed 3):
copper in stock at 5:00 went from 16 to 42, tanks by 8:00 from 14 to 18, units at the end
from 22 to 26. The AI plays by the same rules and gained a little too (12 to 14 structures).
The helper's army target and the truck numbers were left alone; they belong with the
difficulty re-tune once counters exist.

## 2026-10-18: the idle army answers a hit nearby (HomeGuard)
In every probe the player's army stood at the rally point while raiders took the mines 20 m
away, because an idle unit only answers what walks into its own sight (10 m for a tank). The
human player now has a HomeGuard node next to IdleConstructors: when one of the player's
units or structures is hit by an enemy, the idle fighting units whose post is within 30 m
attack-move to the attacker (closest eight first, one call-up per 12 m cell every 8 s, a
cell nobody was free for is looked at again after 2 s so a battle's hits do not scan every
unit of the match). Idle means waiting for targets with nothing to shoot, not holding
position, fire at will. Once a responder has got where it was sent and has nothing left to
shoot, it attack-moves back to where it stood, so the army stays together between raids
instead of being drawn out piece by piece; the 30 m is measured from that post, not from
wherever the last fight ended, so one raid cannot pull the army across the map a hop at a
time. The player's word wins: a responder that is stopped, redirected or told to hold or
hold fire is theirs again and stays where it is (a stopped unit is one standing idle away
from where it was sent). Land units are not sent at boats nor boats at tanks inland.
Attack-move rather than a direct attack order, so responders fight whatever they meet on
the way. Only the human gets it: the AI's army positioning already reacts to intruders. It
runs in every match, rules or not, because it is unit behaviour like firing back, not the
helper. Evidence: harness scenario base-defence (six idle tanks 22 m from a pylon an enemy
bunker shoots) fails on main and passes here: the tanks arrive by 10 s, the bunker is gone
by 22 s, all six are back at their post by 30 s; base-defence-stop stops them on the way
and they stay put with the bunker alive. The 1v1 probe against Normal balanced, run with
the first version (no return to post), went from the command centre falling at 10:08 to
12:31 on the same seed, army peak 29 units. The helper-never-attacks scenario was no judge
of this change: in four runs across main and this branch the helper built a vehicle
factory once and was wiped out by the Normal raider three times, with HomeGuard never
called up in one of the losses; the helper's opening is a problem of its own, noted in
docs/direction.md.

## 2026-10-18: Normal's first attack at 4:00, and waves that leave one at a time
Normal and Hard had first_attack_after_s 0, so the AI attacked whenever its first group
happened to fill, which depends on its economy: unit production is the AI's lowest resource
priority, and on the same seed the Normal balanced AI's first tank came at 2:00 in one run
and 4:54 in the next. A new player could be raided at 2:54 without owning a factory. Now
Normal holds its first attack until 4:00 and Hard until 2:00 (Easy 8:00, Very Easy 12:00
and Brutal 0:00 are unchanged), and wave growth counts from the first attack time, so a
difficulty that waits longer does not open with a bigger wave. Holding alone made things
worse: every group that filled during the hold left in the same second, and on a run where
the AI had eight tanks and three raiders by 4:00 the helper-run player's command centre
fell at 5:50 instead of 10:07. So full groups now leave at least waves.launch_gap_s apart
(balanced 90 s, raider 60 s, turtle and trader 120 s, data/ai/*.json; OffenseController
keeps the clock, AutoAttackingBattlegroup asks it before setting off). A battlegroup that
sets off emits MatchSignals.attack_wave_launched and the harness writes "pX sent a wave of
N" into every timeline, so the AI's waves can be read off any report from now on.
Evidence: new scenario ai-waves-stagger (eight tanks spawned for a Normal balanced AI fill
both groups at once): nothing leaves before 3:50, one wave of four leaves at 4:00, the
second waits and leaves at 5:30, the checks at 3:50, 4:10, 5:20 and 5:45 all pass. The
helper-never-attacks scenario passes on this branch (31 structures standing at 10:00, the
raider's first wave at 4:00 sharp). The 1v1 probe against Normal balanced: war at 5:55,
command centre falls at 11:49; that match is still lost by the helper-run player and the
run-to-run spread of the AI's economy is wider than any of these changes, so the probe is
a shape check, not a number to tune on. Normal is re-tuned once counters exist (item 6 of
the order of work), not here.

## 2026-10-18: any player order releases a home guard responder
The review of #103 ran the harness by hand and found one case the "stopped far from where
it was sent" rule misses: a Stop pressed on responders standing idle at the fight itself,
inside the one second before they are walked back, left them in the same state as "fight
over" and they walked off anyway. HomeGuard now also listens to
MatchSignals.unit_command_issued, which UnitCommandHandler emits for every player command,
instant ones (Stop, Hold Position, fire stance) included, and drops the selected units from
its list of responders. The distance rule stays as a second net for orders that bypass the
handler. base-defence and base-defence-stop pass unchanged.

## 2026-10-18: a unit dies once, however many shells land in the killing frame

Shells are hitscan: CannonShell deals its damage in _ready, so every tank whose fire timer
goes off in the same frame lands in that frame, and tanks that start shooting together stay
in step volley after volley. Unit._set_hp ran _handle_unit_death every time it was called
with hp at 0, so each shell after the killing one handed out the loot again and emitted
unit_died again; that is why probe reports listed one command centre as lost three or four
times, and the loss counters, the loot and anything else listening to unit_died were off by
the same number. A unit now marks itself dying on its first death and later hits in that
frame do nothing more. Evidence: new scenario die-once (twenty tanks standing in range of an
enemy vehicle factory on all four sides): on main the factory is reported lost three times
at 0:01.9, with the fix exactly once, all checks pass, no script errors. The target is a
factory and not a command centre because a command centre with no defenders near surrenders
and is captured, not destroyed, so it never dies at all.

## 2026-10-18: CI plays a match (the validator and the smoke scenario in the checks)

The checks caught formatting and nothing else: a data file with a field the game cannot
read, or a scene that errors on load, landed on main green. The checks workflow now has a
second job. It downloads Godot 4.7.2 (cached between runs), imports the project (about
twenty seconds headless, no cache needed), runs tools/validate_data.gd, which exits non-zero
on any error, and plays the smoke scenario with ./play.sh under a virtual screen, then keeps
harness-out as a build artifact for a week. These are the same two commands a contributor
runs before pushing. One scenario and not the quick batch, because the batch takes several
minutes a run and the smoke match covers the loop that must never break: extractors, a
second constructor, a factory, three tanks, a fight, the AI building a base, no script
errors (it passes on main in 72 s here). The job is not a required check yet; that is a
repository setting for Destin once it has been green for a few days.

## 2026-10-18: the ending holds on the last structure, counts kills and lets you keep watching

Until now the match froze in the frame it was decided: MatchEndHandler paused the tree and
put the results over whatever the camera happened to show. Item 7 of docs/direction.md asks
for an ending that holds for a moment and shows what happened. What changed:

- The hold. On victory or defeat (surrender too) the HUD, the city centres' rings, site
  labels and rebuild countdown go away, the selection is cleared, the camera jumps to where
  the deciding blow landed and zooms in one wheel step. Engine.time_scale drops to a quarter
  of what it was for 2.5 real seconds while the view dims a little and VICTORY or DEFEAT
  (the TitleLabel stencil face, amber or rust from MenuStyle and HudStyle) fades in over
  0.4 s on a thin dark band at the top third of the screen, with "Press any key or click to
  continue" at the bottom in the city build-up's hint style. Any key or mouse button cuts
  the hold short, except the wheel (a zoom) and a modifier on its own. Then the time scale
  is put back exactly, the tree pauses and the blur and the results fade in over 0.25 s
  with the banner as their title. A surrender comes from the pause menu with the tree
  paused, so the hold unpauses it; the results pause it again.
- Where the camera goes. MatchStats remembers where every unit and structure of each player
  fell (structures by the spot they stood on, since unit_died comes after the node has left
  the tree). The handler frames the unit whose death decided the match first (its
  tree_exited is what decides, so it is not in the stats yet), else the last fall of the
  human (defeat) or of the hostile players (victory), else a lost city site from
  CityCentres.lost_sites, else the human's remaining units, else the camera stays. A first
  version framed the last fallen structure, which in the proof scenario was a defence post
  that fell two minutes before the end: an empty patch of sand at the map edge.
- The hold's clock is counted in _process in real time with at most 0.1 s per frame, not a
  SceneTreeTimer: the first 3D frame after the camera jump on a cold software renderer
  took up to 3.4 s and swallowed the whole hold, so the harness's hold screenshot showed
  the results panel. A hitch at the jump now costs the hold 0.1 s.
- The hit-stop. IsometricCamera3D's hit-stop sets Engine.time_scale to 0.05 for 60 ms and
  restores 1.0 only if it still reads 0.05. A structure's death shake runs in the frame the
  match is decided (hp_changed comes before tree_exited), so the hold read 0.05 as the
  speed to come back to and the whole session was left at one twentieth speed after the
  ending. The hold now treats a time scale equal to HIT_STOP_TIME_SCALE as 1.0, the
  hit-stop's own restore target, without touching the camera.
- No hold for a match ended by the match limits (time up, dry map) or a match without a
  human player: there is nothing to frame, and tests/caps/CapsChecks.gd expects the pause
  within twenty frames of the limit signal.
- Kills: on unit_died the dying unit's last_attacker_player gets one, units and structures
  alike, never for friendly fire. Units taken away by CityCentres._remove_unit emit no
  unit_died and count for nobody. A fuel crash or a god-mode delete still credits the last
  attacker; accepted. The results table has a Kills column next to Units lost.
- Keep watching, a third button between Play again and Main menu: unpauses, hides the panel
  and the blur, shows the HUD again and lets the match run on. After a defeat the city
  centre rings, labels and countdown stay hidden: there is no city left to keep, and the
  countdown would tick toward a second defeat. The handler never decides a second ending
  (one _decided guard) and the match limits cannot re-open it. A small Results button sits
  bottom centre just above the screen edge, where neither the HUD nor the diplomacy panel
  draws (a first version put it top centre, inside the diplomacy offer), and brings the
  panel back; Surrender after Keep watching does the same instead of starting a new ending.
- Allies: victory comes when no hostile player has units left, and only an alliance excuses
  a living player. A pact partner, a neutral and an enemy at war all block victory: a first
  version used Diplomacy.can_attack, under which buying a non-aggression pact from the
  only enemy would have won the match at the next death of anything. Defeat stays "the
  human has no units"; a match without a human still finishes when one player is left.
- Harness: HarnessApi.state() carries "match_end" {shown, result, hold} and "stats" (the
  MatchStats counters by player index), expr checks can call api as well as read state,
  the Recorder writes a "hold" event when the hold begins and an "ending" event (with the
  speed the match is back at) when the results come up, and with match_end true a run goes
  on past the match_end event until the ending event and its screenshots are in: a 10 s
  real-time grace, extended while a screenshot is still on its way, capped at 30 s. One
  shot is taken 0.5 s into the hold and one 0.3 s after the results come up; the end shot
  waits for any shot in flight and skips the jump to a command centre the human no longer
  has ("no such unit" from the camera order). Scenarios with match_end false end as before.
- New strings MATCH_END_KEEP_WATCHING, MATCH_END_RESULTS, MATCH_END_KILLS and
  MATCH_END_SKIP_HINT in assets/translations/match.csv. MatchEndHandler lost its private
  copy of the palette.

Evidence, scenario tools/harness/scenarios/ending.json (twenty-four enemy tanks next to the
player's command centre on Big Arena, match_end true, speed 4), run twice in a row: the
command centre falls at 0:27 and two defence posts by 0:47, "the human player lost" and
"the hold began: Defeat" at 2:29, "the results screen is up: Defeat, speed back at 4.0" at
2:33; HARNESS PASS ending: 6/6 checks ok both times (the match was lost, the hold ran
before the results, the results screen came up with Defeat, match_end shown and result ==
"defeat", stats[1]["kills"] >= 1 with 10 kills for the AI, no_errors), 153 game seconds in
46 real seconds. Both 00-hold.png files show the DEFEAT band, the dim and the hint over
the scorch of the last unit, the HUD gone; 01-results.png the panel with the Kills column
and Keep watching. tools/harness/scenarios/ending-victory.json (the player's tanks at the
enemy command centre): HARNESS PASS ending-victory: 6/6 checks ok, "the human player won"
at 2:29, "the results screen is up: Victory, speed back at 4.0" at 2:34, 20 kills for the
player, 00-hold.png the VICTORY band over the enemy base with the tanks and a wreck. A
speed-1 reproduction of the hit-stop (camera_shake 1.0 and every unit killed in one frame)
reads 0.05 in that frame, then inside the hold _time_scale_before 1.0 and speed 0.25, and
1.0 after the skip. A copy of the ending scenario that presses Keep watching as an end
check ends unpaused with the HUD back, CityCentres and its banner layer hidden, and the
Results button at the bottom centre in its end shot. smoke (10/10) and die-once (3/3)
still pass; the data validator reports 0 errors. The four tests that look at the end
screen pass unchanged: CityCentreChecks 0 failures ("PASS the match ends in defeat", its
6-defeat.png is the DEFEAT band over the old city), CapsChecks 0 failures ("the match is
over (paused behind the end screen)", "the end screen shows Defeat"), OptionsShots
failures=0 ("surrender shows Defeat"), Playthrough exit 0 (time limit after 406 s, no
script errors; the bot reached no ending in six minutes).

## 2026-10-18: health bars colour by thirds, on a dark backing, held on with Alt or an option
Health bars colour by thirds (HudStyle.health_color: green at or above 2/3, amber down to 1/3,
red below, the StarCraft II steps that Generals also uses) and sit on a black backing, and every
bar shows while Alt (the show_health_bars action, rebindable in controls.cfg) is held or
Options > Interface > "Always show health bars" is on. One node, HUD/HealthBarsControl, polls
the option and the key and tells the bars through MatchSignals.health_bars_forced; no bar polls
Input. Hover shows a bar too, enemies included, through the unit's own mouse_entered and
mouse_exited (Unit is an Area3D). pixel_size 0.0125 in HealthBar.tscn instead of 23 scene
edits: the tank's 160 x 10 bar is now 2.0 x 0.125 m, and the node does not move, so the
veterancy chevrons and the surrender flag that read its position stay put. Why: a 7 px green
hairline on sand was unreadable at 1080p and invisible at 720p, and a bar that only ever shows
green says nothing about who is dying. The lost-hp chunk keeps its pale colour; the empty part
is SURFACE_2, the dark panel tone. A site under construction draws its bar in MUTED until it is
built: its hp is build progress, and a red sliver by the command centre would read as an attack.

The backing is black at 0.85 alpha and three texture pixels larger each side, not the spec's
0.55 and two: after the Look's haze, tonemap and contrast, 0.55 came out mid-tan on sand
((171, 134, 98) against (250, 226, 196) at 1080p), and at 720p, where two texture pixels are
1.2 screen pixels, the bottom row went missing. The backing and the bar share render_priority 1,
both sort by the node's origin (sorting_use_aabb_center off), and the bar sorts 0.01 m nearer
(sorting_offset), so each unit's edge is drawn right before its own bar. The spec's split
(backing 0 under the bar's 1) drew every backing before every bar, so bars that overlap in a
fight fused into one long strip with no line between them; with the default AABB sort the
bigger backing sorted nearer than its own bar unless the offset was half a metre. This was seen
under the Compatibility renderer the cloud box runs; Forward+ on a GPU is still to be looked
at. The Look also shifts the fills (GOOD #8fbf5a renders about (164, 188, 107)), so the 2D
strips of a later PR will not match the 3D bars exactly; accepted.

Evidence: the new scenario hud-health-bars (eight raiders charging six tanks in Big Arena; Alt
held at 6 s, released at 7.5 s, the option on at 8 s) passes 4/4 at 1920x1080 and at a true
1280x720: every bar visible while the key is held, no bar visible without a reason (selected,
hovered or hit in the last 2 s) once the key is released with the option off, every bar
visible with the option on, and no script errors. The fight differs from run to run, but in
each run looked at the 7 s and 9 s shots between them show green, amber and red bars across the
tanks and raiders, with the dark edge clear on sand. The tank bar measures about 144 x 9 px at
1080p with a 2 px edge of about (55, 30, 8), and 96 x 6 px at 720p with a one-pixel dark edge
and a blended row. In the 40 v 40 window view with the option on, overlapping bars each keep
their own frame. stress-40v40 (fast view, so the CPU side only) gave frame p95 164.36 ms and
p50 74.82 ms with the bars off, and p95 108.42 ms and p50 72.99 ms with the option on; both
fail the 50 ms budget, which this box already failed before the PR (p95 141.04 ms, p50
95.77 ms in the quick batch at 07:05), so the pair is noise from a shared software-rendering
box and needs a PC with a GPU before either number means anything. The spec's four raiders
standing 8 m away were tried first: all four died by 6 s having dealt about 28 damage spread
over six 33 hp tanks, so every bar stayed green; the raiders now start out of the tanks' range
at [54, 40] and charge on a fight order, which keeps the fight alive to 12 s. The harness
gained the two verbs this needed, a held key ({"do": "key", "action": ..., "hold": true} and
"release": true) and {"do": "option", "set": ..., "value": ...}, plus a "health_bars" field in
state() with the counts the checks read; docs/testing/play-harness.md lists them and says that
under xvfb --resolution, not --window, sets the viewport size.

## 2026-10-18: armour and weapon classes: tanks beat light vehicles, rockets beat tanks, light vehicles beat rocket trucks

Combat had no roles (docs/direction.md, the measured problems): damage was flat, three tanks
were the same tank at three prices, artillery could not see what it could shoot, and a
bunker lost to three tanks and killed none. Two data keys fix that and one line of code
reads them. Every unit now has properties.armour, one of light, heavy, truck, structure or
air, and every armed unit a properties.damage_vs map from armour class to multiplier;
Unit.take_damage multiplies the incoming damage by the attacker's cell for the target's
class (1.0 when the key is absent, when the attacker is null as in the tests, or when it
has no map as the armed caravan). The sentence a player can repeat after three factory
cards: tanks beat light vehicles, rocket trucks beat tanks, light vehicles beat rocket
trucks. Cells are x2.0 (strong) and x0.5 (weak) with two exceptions: the heavy tank's x0.75
against structures (the T2 tank half-loses the T1 penalty, the T3 tank loses it) and militia
x1.5 against aircraft (the city screen ends the pillow fight with helicopters). The hero
stays the hero: the tank's cannon is x2 against raiders, has no heavy key so tank on tank is
exactly 1.0 (VeterancyChecks and CommandChecks keep killing), and its one weakness is
structures, which makes a siege a decision. Shells are the structure answer (artillery x2),
flak the air answer (every anti-air weapon x2), and the emplacement cannon of ag_turret and
bunker stays x1 against structures so base-defence's 8 s pylon check keeps its 4.8 s kill;
the two cannon rules were kept on purpose rather than re-timing that check. Each card and
production button gets one generated line from the same two keys
(BuildingInfoText.classes_for, buildings.csv rows), so "weak against structures" on the
tank and "Structure" on the bunker give the decision without the manual. The class word on
a card is the word the other cards use for that class: Tank armour (tanks), Light armour
(light vehicles and infantry), Unarmoured truck (trucks), Structure (structures), Aircraft
(aircraft). The design said "Heavy armour" and "Building"; review found that a player could
not link "strong against tanks" on the technical to the APC or the patrol boat, which read
"Heavy armour", so those two words changed in buildings.csv and nothing else did.

Hp and sight moved where armour alone was not enough: command_center 90 -> 180 (four T1
tanks need 33 s instead of 8; an undefended centre still surrenders on the first hit, so
the passive-player time is set by capture), vehicle_factory and aircraft_factory 48 -> 72
(one size for both factories), ag_turret 30 -> 36 (one turret beats one tank with margin,
14 hp left, where 30 lost to an Elite tank), bunker 54 -> 66 (holds two tanks with 15 hp
left instead of 3, so a Veteran tank no longer flips it), gun_nest 24 -> 36 (a tank pays 29
hp for it without losing, "thin walls" stays true), flak_tower 42 -> 48 (beats one gunship
by 2.35 s instead of 0.75 s), artillery sight_range 7 -> 15 (idle acquisition and
attack-move search only sight_range, so at 7 m it never fired its 15 m on its own). The
missile truck takes the fallback: attack_domains stays ["air"], its map is {"air": 2.0},
armour truck, and MISSILE_TRUCK_DESCRIPTION is untouched; making its rockets hit ground
would change a shared unit's role inside a counters PR and is a separate decision. Its card
reads "Unarmoured truck, strong against aircraft". The cost of the fallback: until the
ground-rockets PR the Foundry has no unit strong against tanks, so a Foundry player learns
"rockets beat tanks" only from an enemy technical, and Foundry against Foundry is a tank
mirror decided by bunkers and artillery. rocket_technical overrides the light armour it
would inherit from raider with truck, or the tank's x2 would break "rockets beat tanks".
The amphibious APC's "strong against trucks" holds for haulers, workers and artillery, but
it loses to the rocket technical, the truck the sentence names (6.5 s against 7.0 s, and
8.5 m of range against its 6.0 m), because the technical's x2 on heavy armour outweighs the
APC's x2 on trucks; its armour (open question 11) was not ruled here. The seconds in this
entry leave out veterancy: a promotion heals a quarter of hp_max, and kills come twice as
fast against light units, so a tank ranks up sooner against raiders (in fight A below the
tank healed from 19.0 to 28.9 hp at its second kill and ended on 26.4 hp, where the design
predicted 12.5).

Evidence: new scenario counters-triangle, six isolated fights on big_arena against a Very
Easy turtle pinned to the far corner, its mobile units on fight orders so army positioning
does not walk them home. On main 10 of its 12 named checks fail (the two that pass are the
companion checks "the technical is alive" and the artillery "without moving", which main
meets by accident); on the branch 13 of 13 pass. Seconds from a half-second probe of the
same scenario, before -> after: three raiders killed the tank at 7.0 s taking one loss ->
the tank kills them by 3.5, 8.0 and 11.0 s and stands (predicted 3.0, 6.75, 10.5); the tank
killed the rocket technical at 14 s -> the technical kills the tank by 7.5 s (predicted
6.5); the technical killed the raider at 7.5 s -> the raider kills the technical by 9.0 s
(predicted 7.4); the tank killed the turret at 11.5 s -> the turret kills the tank by 17.5
s (predicted 16); two tanks killed the bunker at 12.0 s -> the bunker kills them by 14.5
and 28.0 s (predicted 12.0 and 25.2); the gun nest stood all match -> artillery 13 m away
kills it at 8.4 s without moving (predicted 8). The scenario runs at speed 1: at speed 4
the fights drift late under the virtual screen (the second bunker tank died between 35 and
40 s instead of 28 s) and the 32 s check misses it. base-defence, base-defence-stop,
die-once, ai-waves-stagger, tutorial-first-match and smoke pass with no check re-timed
(die-once's 20 tanks still flatten the 72 hp factory in 4 volleys). base-defence passes
with less margin than on main, and its file stays as it is (the lead's ruling: the two
cannon rules exist so that it is not re-timed): the 66 hp bunker now falls to six tanks at
17 to 19 s (12 to 13 s on main) against the 22 s check, so the tanks start the walk back
about 6 s later and "the tanks went back to their post" counted 4, 4, 5, 4, 5, 6 and 5 of 6
at 30 s in seven branch runs (5 to 6 on main, want 4; all six are back by 32 s). A
base-defence failure on a loaded box is re-run before anyone reads it as a regression. Of
the rest of the quick batch, place-extractors, line-orders, factions-foundry,
factions-syndicate and counters-triangle pass; stress-40v40 misses its frame budget on this
software renderer (frame_ms_p95 141 and 162 ms on the branch, 161 and 93 on main, want 50),
and helper-never-attacks and save-load fail some runs on main and on the branch alike: the
helper built no extractors in one run on each side and passed in a third, on the branch,
and save-load failed one to four checks in all 4 runs on main and in 5 of 6 on the branch
(raiders out of the loaded factory, the loaded power plant site, and script errors such as
"bake() should be called exactly once" that main has too). The validator requires armour on
every unit (structures must be structure, units must not be), damage_vs on every armed unit
and on no unarmed one, keys from the five classes, values from 0.25 to 2.0, and warns when
a map has no cell for a domain the weapon shoots at; validate_data: 0 error(s), 0
warning(s) on main and on the branch. VeterancyChecks, CommandChecks, DiplomacyChecks,
CityCentreChecks, CameraChecks, PlaytestChecks, and the two that read the card text,
TooltipsCheck and BuildingInfoCheck, run green without edits.

Deferred, on purpose, each its own PR: hauler hp 24 -> 30 (the raid now kills a hauler in
1.5 s with three raiders; economy retune), Easy's unit roster (Easy and Very Easy keep the
Syndicate on raiders, which two tanks now shrug off; item 6), the helper's cost-first pick
(Helper buys missile trucks over tanks at T2), AI target preference (nearest-first, class
blind), caravan guns (CaravanGuns passes the caravan, factor 1.0), CivilDefense._strength_of
and CityCentres._firepower_of staying class blind, hp_max of old saves (a saved command
centre loads at 90/180), shipyard hp (42 while the land factories are 72), helicopter ground
cells (aircraft are 1.0 against everything), a unit "role" key with a one-word label on the
card, ShotEffects for x0.5 hits, the missile truck's ground rockets or its description, and
the Normal retune, which must be re-measured now that the arc has moved.

## 2026-10-18: the under-attack banner hangs off the accepted ping, and Space goes there
The under-attack banner hangs off MinimapPings' accepted ping (MatchSignals.attack_pinged); one
filter and one throttle for the ring, the blip and the words. Why: two throttles drift and
CLAUDE.md prefers deleting duplicates. HUD/AlertBanner shows "Base under attack: Storage 1" for
a structure and "Units under attack: Tank" otherwise, above the minimap, with the key that goes
there. No banner for a fight already on screen; a structure's alert beats a unit's; it holds
9 s after the last alert it took, restarts at most every 2 s, then fades, and it fades a second
after the place it names comes on screen. It keeps the last five places of the last minute, one
per 12 m. Space (jump_to_alert, rebindable in controls.cfg) or a click on the banner moves the
camera there, and Space again within 2 s goes to the place before. It plays no sound: the ping
already blips and the advisor already speaks.

Where it differs from the spec, and why. The hold is MinimapPings.ATTACK_QUIET_S + 3 s (9 s),
not 6 s, and an alert that arrives while the banner fades takes it back without counting a new
show or flashing the same words. With a 6 s hold and a 6 s cell quiet time that both start at
the same ping, the next ping of a fight in one cell came just as the hold ran out, so the
banner blinked off and on every 6 s and state.alert.shows counted each blink. The banner fades
a second after the place it names comes on screen, by Space, a click or the player scrolling
there: with the longer hold, "Space go there" otherwise stayed up over a fight the player was
already watching, and this is the frustum gate's rule applied to a banner that is already up.
The look is the spec's box in red: a red-tinted fill (#3a1711 at 0.94) with a 1 px red ring
around the 4 px red left edge, the key on a keycap (LINE face, MUTED border, a 2 px lower edge,
FG text), and a new text pulses the fill from BAD back to its resting red over 0.35 s instead
of the modulate flash. The spec's box was Guide's hint box with a red edge where the hint's is
amber, and at 4 px both read as orange, so the alert looked like a tip; the chip's fill was 5
levels off the panel's and its 1 px LINE border vanished, so "Space" read as part of the
sentence; and the modulate flash took the near-black panel from (37, 31, 25) to (52, 37, 25)
for 0.35 s, which nobody sees. While BuildingInfo's selection card reaches into the banner's
row, the banner sits 8 px above the card: the card floats right of the minimap and anchors to
the bottom, so any card taller than about 215 px (the command centre's is 343) ran under the
banner, which printed "Space go there" over its text and took its clicks. The lift looks up
HUD/BuildingInfo/BuildingCard, so it stops by itself once PR 4 moves the card into the bar.
While the banner shows, the first press goes to the place it names, not to the newest place:
the chip says "Space go there", and a unit hit elsewhere does not change a structure's text, so
"newest" could be a place the words never mentioned. The hold, the 2 s guard and the minute of
memory run in game seconds (the 2 s between key presses is real time): this box plays a 1080p
window at 0.15x to 0.26x, where a real-time hold showed the banner for about one game second,
and game seconds also keep the banner up while the game is paused. The banner lines up with the
minimap's left edge (x 5 today, x 8 once the bar lands) instead of a fixed x 8. The burst icon
has four long and four short points with a wide core: the thin spikes of the first try vanished
under the outline at 20 px.

Evidence: tools/harness/scenarios/hud-alert.json passes 3/3 at a true 1920x1080 (10 game
seconds in 39 real seconds) and at a true 1280x720: "Base under attack: Storage 1" at 6 s, and
after the jump_to_alert action at 7 s the camera is on the alert's place (18, 7) at 8 s. The
banner sits at y 817..857 at 1080p and 457..497 at 720p, 8 px above the minimap; after Space
the burning storage and the tanks are in the middle of the screen and the banner is off them in
the bottom left corner, about to fade. The scenario differs from the spec in three ways, all
written in its description: the tanks shoot the closest thing, which is a truck or a
constructor at a corner of the command centre from any side, so a storage stands 8 m east of it
for them to hit; the war starts at 2 s, after the camera has moved away; the camera looks at
[32, 36] because [90, 90] clamps to the corner of a 50 m map, where two thirds of the shot is
black void. With the command centre selected, the banner moves to y 681..721 above the card's
729 at 1080p and to 321..361 above 369 at 720p. A scratch copy with a second fight at (40, 25)
showed a structure's alert replacing a unit's at once, a later unit alert not replacing it, a
click on the banner going to the storage while the tank fight was the newest place, and three
presses within 2 s going (40, 25), the storage, (40, 25). With the helper and auto-expand
panels open at 720p the auto-expand panel ends at y 440, above the banner's row.

Alert fatigue (risk 3). state.alert now also has visible_s, the game seconds the banner has
been up, because shows alone counted blinks and missed how long it stayed. base-defence.json at
speed 1, with the camera moving onto the fight at 3 s: 1 to 2 shows in 90 s, 0.7 to 1.3 a
minute. The first is the pylon in the first second, before the camera got there (up 4.5 s);
the second, in two of three runs, is a real hit on a hauler at the home base about 56 s in,
off screen, so the banner did its job. A harder review scenario, three
waves of 4, 4 and 5 tanks hitting the Big Arena base from three sides at 5, 65 and 125 s with
the camera parked far away for all 200 s: 11 shows before this change, 6 of them blinks of a
banner that was already up; after it, 5 shows (one per wave plus one after an 8 s lull and one
after a 20 s lull) and no blinks, with the banner up 95 of the 200 s. That is 1.5 shows a
minute, about 2.3 a minute over the 130 s of fighting, for a player who never looks at a base
under siege. Every one of those shows is a new episode the player is not looking at, which is what the
banner is for, and Generals also says "unit under attack" for units, so the quiet time and the
unit alerts stay. If play shows the siege case nags, the first lever is structure alerts only
while a structure alert is up, not a longer quiet time.

CameraChecks reports 0 failures (one ping per spot, Alt + click still marks),
InterfaceSoundsCheck reports ok (one blip per hit), smoke 10/10, hud-health-bars 4/4
and base-defence 5/5 still pass, and the data validator reports 0 errors. state() gained
"camera" and "alert", listed in docs/testing/play-harness.md.

Known and left for later. At 720p, with the helper and auto-expand panels both open, Guide's
tutorial and hint panels continue the left column into the banner's row and the banner covers
them while it shows; the auto-expand panel itself stays above the row. Clamping them up would
lay them over the auto-expand panel the tutorial points at, so the left column has no room at
720p either way, and PR 4's layout is the place to settle it. The 12 m cell's 6 s quiet time
does not look at the victim, so a hit on a structure within 6 s of a truck or constructor ping
in the same cell does not reach the banner, which keeps "Units under attack" until the cell
reopens; letting a structure through once would change the one filter, which is a spec call.
Space goes to where the victim was at the accepted ping, not where it is now, which can be a
few metres behind a moving truck. The frustum gate counts ground under the HUD panels as on
screen. A production queue button left focused by a press dragged off it took Space as
ui_accept and cancelled that unit before the jump saw the key, so the queue buttons are now
FOCUS_NONE like every other HUD button.

## 2026-10-18: the Militia uses a generated squad

The Militia's procedural squad looked like toys next to the remade tank, so it was replaced
with a Higgsfield rifleman (concept, then Tripo) placed three times by
`clean_generated.py --squad`, at the tank's 3,600 triangles. Team colour goes on the helmet
and shoulder patches, including their sides (`--team-up -0.2`), against the "top surfaces
only" rule: on a 15-pixel soldier the tops alone did not tell blue from red. The classic
model option is unchanged. Details in tools/blender/generated_models.md.

## 2026-10-18: the constructor uses a generated engineer vehicle

The worker's built bulldozer was flat-colour programmer art next to the remade tank. It is
now a generated combat engineer vehicle (dozer blade, yellow crane arm) at the tank's 3,600
triangles; the old bulldozer stays as the classic model. The yellow crane keeps it easy to
tell apart from combat vehicles. It costs less to draw than the tank in the software-renderer
bench (107 ms vs 132 ms for 30). Details in tools/blender/generated_models.md.

## 2026-10-18: the hauler uses a generated truck

Haulers are always on screen, and the built truck was flat-colour
programmer art next to the remade tank. It is now a generated 6x6 cargo truck at the tank's
3,600 triangles; the old truck stays as the classic model. It costs about as much to draw as
the tank in the software-renderer bench (128 ms vs 129 ms for 30) and a sixth of the draw
calls of the old one. Details in tools/blender/generated_models.md.

## 2026-10-18: CI prints the smoke report when the smoke match fails

The "Play the smoke match" step ran `./play.sh smoke` and then `cat report.md`, but the step
runs under `bash -e`, so a failing match ended the step before the report was printed. Two
failures today (#114's run 239 and #116's run 248, both on changes that cannot touch the
match) said only `HARNESS FAIL smoke: 9/10 checks ok`: the failed item was one of the six
`expect_ok` orders, which the log does not print, and the uploaded report cannot be read from
the cloud session. The step now keeps play.sh's exit status, prints the report either way and
exits with that status, so the next failure names the order and its error in the log.

## 2026-10-18: the missile truck fires at the ground: the Foundry's rocket corner

The armour entry above left the missile truck on its fallback (attack_domains ["air"],
damage_vs {"air": 2.0}), so the Foundry, the default human faction, had no unit strong
against tanks while the truck's own card said "long-range rockets against ground and air".
The lead took the role change: data/units/missile_truck.json now has attack_domains
["terrain", "air"] and damage_vs {"heavy": 2.0, "light": 0.5, "air": 2.0}, the map the
armour design gave it, and MISSILE_TRUCK_DESCRIPTION stays as it is because the data now
matches it. Review changed two more numbers in the same file, attack_range 9.5 -> 8.5 and
attack_interval 1.0 -> 1.2, so that against the ground the truck equals the rocket technical
instead of beating it. No code changed. The card's class line reads "Unarmoured truck ·
strong against tanks and aircraft · weak against light vehicles and infantry"
(BuildingInfoText.classes_for with the buildings.csv words) and its attack line "ground/air:
3 damage every 1.2 s, 8.5 m range". "Long-range" still holds against what it is strong
against: the tank shoots from 7.0 m, the heavy tank and the gunship from 7.5 and the
helicopter from 6.5 (the battle tank's 8.5 is equal).

Why 8.5 m: at 9.5 m the truck outranged every structure that shoots at the ground (gun nest
8.5 m, turret 8.0, bunker 7.0; the flak tower, SAM site and AA turret shoot only at
aircraft). On a fight order it stopped 9.0 m from a gun nest and killed it in 15 s without
taking a hit, although the gun nest is the Syndicate's answer to rocket trucks: its card
says "strong against trucks", and in the armour design it beats the technical at an equal
8.5 m. At 8.5 m the truck stops 8.05 m from the nest, as the technical does (8.06 m), and
the nest wins: the truck was dead by 10 s with the nest on 21 of its 36 hp, and a technical
sent the same way at another nest was dead by 10 s with that nest on 18. The bunker's 7.0 m
is still outranged, as it is by the technical (matchup 60 of the armour design, accepted
there).

Why 1.2 s: the missile truck is a shared unit. It has no "factions" key and the Syndicate
hides only ag_turret and aa_turret, so a Syndicate player and the Syndicate helper build it
too (VoiceCheck already gives it a Syndicate crew voice). At 9.5 m and 1.0 s it out-ranged
and out-damaged the Syndicate's own main_t2 and main_t3 unit, the rocket technical, against
tanks (6.0 against 5.0 damage per second, at the same cost of 11) and shot aircraft as well.
At 8.5 m and 1.2 s their ground weapons are the same; the truck keeps its anti-air, the
technical keeps its speed (3.8 against 2.8 m/s), its hp (30 against 27) and a build 1 s
shorter, and in the fight model six technicals beat six trucks. Hiding the truck from the
Syndicate was the other option and was not taken: the Syndicate would lose its only
ground-based mobile anti-air (militia is city-only). The technical's niche can be looked at
again in the item 6 retune.

The scene was read before the data was trusted: MissileTruck.gd extends Tank.gd (waiting for
targets by default), and WaitingForTargets, AutoAttacking, AttackingWhileInRange and Stances
pick targets only by attack_domains. Its rocket (Rocket.gd, "projectile": "rocket") moves
its end point to the target every physics frame and damages the unit it was fired at, lobbed
at ground targets 5 m away or more and flat at aircraft, so a rocket at a tank cannot climb
to an aircraft's height and miss.

Evidence: counters-triangle gains fight G, one missile truck holding position 9.5 m from one
tank that is told to fight through it, and fight H, a raider told to attack a missile truck.
In a half-second probe of the scenario on the branch, the tank came within the holding
truck's 8.5 m between 0.5 and 1.0 s, the first rocket landed by 1.5 s, and the tank went 33,
27, 21, 15, 9, 3 hp and died between 7.5 and 8.0 s with the truck on 11 hp. The check names
carry the prediction counted from simultaneous first shots, 6.5 s and 9 hp, and G's checks
run at 11 s. In H the raider killed the truck between 8.0 and 8.5 s and kept 9 of its 18 hp
(predicted 9). On main the truck never fired at the tank, and the tank killed it between
11.5 and 12.0 s on full hp; in H the raider killed the truck between 11.0 and 11.5 s
untouched. G's check "a missile truck beats a tank" fails on main (one tank left at 11 s)
and passes on the branch, where all 16 named checks pass and A to F are unchanged; "and the
truck stands" and both H checks pass on main too and only guard the branch result. The first
branch run showed why G's truck holds position and H's raider is on return fire with an
attack order: once their own fight was over, the human's home guard (HomeGuard.gd, idle
fighters within 30 m of an attacker) sent the idle truck at D's turret 20 m away, which then
fell and failed D, and the idle raider at E's bunker 29.5 m away, where it died.

Other engine probes on the final numbers: two holding trucks killed a gunship between 7.0
and 7.5 s (the first hit landed by 2.5 s) and lost neither truck; one truck killed a
helicopter between 6.5 and 7.0 s and lost 5 hp; two trucks killed a heavy tank between 7.5
and 8.0 s and lost neither, though one was down to 3 hp; one truck lost to a heavy tank (the
truck dead by 9 s, the heavy tank on 24 of 60); a hover skimmer killed a truck and kept 4.5
of its 15 hp. The skimmer is the Foundry's own light unit and wins this fight more narrowly
than the raider (at 9.5 m and 1.0 s it kept 1.5 hp). smoke, base-defence, die-once,
factions-foundry, ai-waves-stagger and tutorial-first-match pass; TooltipsCheck and
BuildingInfoCheck pass unchanged; validate_data: 0 error(s), 0 warning(s); gdformat and
gdlint are clean.

The AI builds no missile trucks: no role in data/factions or Factions.DEFAULT_ROLES names
it, and its anti-air roles are the flak tower and the SAM site, both structures, so its
compositions and its air defence do not change. A truck the AI owns (a spawned one) now
fires at ground units in its sight. The human's home guard now also sends idle missile
trucks at ground attackers within 30 m, where before it sent them only at aircraft. That
includes raider raids, where the truck deals x0.5 and at 2.8 m/s cannot catch a 4.4 m/s
raider; a follow-up could skip responders whose damage_vs against the attacker's armour is
below 1.0. Targeting stays nearest-first and class blind
(WaitingForTargets._pick_closest_unit), so in a mixed fight a truck spends its rockets at
x0.5 on the light units in front before the tanks behind, and "strong against tanks" needs
the player's attack orders until the deferred target preference lands. The helper's
cost-first pick (Helper._best_unit_for) already bought missile trucks at T2 when the bank
covered them but not the heavy tank (17), the artillery (14) or, on the tie at 11, the
amphibious APC that comes first in file order; those trucks now fight tanks instead of
standing idle in front of a ground army. The Syndicate helper's tie at 11 goes, in file
order, to the APC, then the truck, then the technical. A role-aware pick stays deferred, as
in the armour entry.

Input to item 6: past T1 neither AI's main waves hold a light unit. The Foundry AI fields
the tank, the heavy tank and the battle tank with artillery and helicopters, and its raider
role is the tank; the Syndicate's main_t2 and main_t3 are the rocket technical. A pure
missile-truck stack therefore beats the Foundry AI's tank and heavy-tank waves cost for
cost, and the light units that punish it hard (raiders, skimmers, city militia) are missing
from those waves. In the fight model at about 66 cost, six trucks beat seven tanks keeping
two and four heavy tanks keeping three, and take no damage from two bunkers; they lose to
three battle tanks, six technicals, eleven raiders, eleven skimmers or thirteen militia. A
follow-up data PR can give the Foundry AI a light unit (roles.raider "hover_skimmer" in
data/factions/foundry.json) and keep some main_t1 light units in the later waves. One feel
item stays open: ShotEffects.rocket_impact shakes the camera for rockets of 3 damage or
more, so a truck stack in a ground fight now shakes the camera on its hits, as the technical
and artillery do; nobody has watched six trucks in a window yet.

## 2026-10-18: the command card is 4 x 3 with icons and captions, the constructor's menu 6 columns and never paged
The command card is 4 x 3 with icons and captions; the worker's menu is 6 columns, never paged.
Why: PlaytestChecks.gd:64 and TooltipsCheck.gd:80-89 pin the width and the visible vehicle
factory, and page 2 would hide the defences at 6:00. Row 1 is Fight F, Patrol P, Guard V and
Stop X, row 2 Patrol base B, Retreat Z, Fire stance L and Hold position K, and row 3 is free:
the truck buttons (recycle, line and the fleet status) sit there, where on main the status ran
over the top row next to the X. Every slot is an icon with its caption under it and its key in
the top left corner, read from Keybinds so a controls.cfg rebind shows. The fire stance slot
changes icon and caption with the stance. Hold position is a toggle: its caption names the order
("Hold position") and the slot lights up and says "Holding" while the units hold, as SC2 and
Generals name a toggle's action and let the lit frame show that it is on; "Free to chase" under
a pin said the opposite of the icon, so COMMAND_HOLD_SHORT_OFF is gone. With one construction
site selected the stop slot becomes Cancel build, with no key: the stop key goes through
UnitCommands.stop, which skips structures, so an X tag promised a key that did nothing (making X
cancel a site would change UnitCommandHandler, which this PR leaves alone). HudStyle.slot_px
gives 80 px slots on a HUD 900 px tall or more and 64 below, read once at _ready; the command
card is 332 x 248 or 268 x 200 and the constructor's 500 x 248 or 404 x 200 (346 x 262, 282 x
214, 514 x 262 and 418 x 214 with the panel). A faction's constructor has 15 structures, which
fill rows of 6, 6 and 3 from the top left, where main had four rows of four in the bottom right
corner (a 342 x 342 panel, 47 % of a 720 px screen). With no faction there are 20: main's 16
slots cut Trading post, Flak tower, Foundry and SAM site, and the 18 slots now cut Foundry and
SAM site, the last two in the menu's order. No faction means the harness, the tests and the
first-match tutorial (data/tutorial/first_match.json names none, and TutorialScript.gd:88 passes
""). The slot builders (hotkey tag, caption, unit icon) moved to HudStyle, so the build menus
and the card share them; the hotkey tag has a 3 px black outline, because the amber letter faded
into a lit (amber) slot. UnitMenus' BackgroundGrid and the card's four dead placeholders are
gone; the fleet and extractor menus take their slot size from HudStyle.

Where it differs from the spec, and why. The icons were redrawn after shots at 32 px. Fire at
will is three upright cartridges fanned from below (fanning from one corner read as crumbs);
the cartridges are two-tone (the casing in MUTED, the head in FG), the spec's fallback. Return
fire is an incoming arrow over the stances' own cartridge going back out, not a shield with a
shell: the shield read as a spade, was mostly MUTED so the slot looked half disabled, and
repeated Guard's shield two slots away. Hold fire is the cartridge in a MUTED no-entry ring and
slash: in FG it was the same cream ring with a mark as Stop, diagonally next to it. Fight is a
whole ring with three ticks outside it and the arrow coming in level from the left to its
centre: ticks across the ring cut it into dashes, and an arrow at 45 degrees at the lower left
made a magnifier ("search"). Patrol's arrowheads sit at the ends of its two arcs, next to the
posts: in the middle of the loop they broke it into beads that looked like Patrol base's ring.
Retreat's pennant is FG and half again as big, because at 32 px the flag vanished and left an
undo arrow. Cancel build is a crate (frame, planks, brace) with the X in its corner: an X over
hatching did not say crate. The 13 SVGs import at svg/scale 2.0 (64 px textures): at 1.0 the 32
px raster was stretched to 40 px in a full slot and went soft next to the text. In a 64 px slot
the captions are 10 px, not 11: "Hold position" is wider than the 62 px a caption has at 11 px,
and the build menu's cost row uses 9 px icons and numbers, because three amounts ran out of the
slot and the command centre's copper price was cut off. The 6-column card is 500 px wide, not
492 (6 x 80 + 5 x 4). COMMAND_STOP and COMMAND_CANCEL_BUILD are in guide.csv in English only:
guide.csv has no Polish column, like every other COMMAND_ string. The key on each slot and in
its tooltip is read every frame and set when it changes: Match applies controls.cfg after the
HUD's _ready, so a tag set at _ready showed the default key (the tooltips on main had that bug).
With nothing movable selected, a structure, the card is the stop slot alone; showing the third
row's spacers there would put Stop in the top left of a two-row card. A train is not movable to
the card either (it runs on rails), so with only trains selected the fleet menu hides its second
row of spacers and its buttons sit on row 2 under Stop, not on row 3 under two empty rows. The
fleet status is one slot wide in the grid and its text runs over the next slot (a 160 px cell
would have made its column 160 px), and it grows upwards from its slot: a train's line of four
lines or more ran below the card and off a 720 px screen. unit_generic and structure_generic
draw nothing in today's data: a unit with a "base" inherits the base's icon, so every entry has
a PNG, and they are the fallback for a unit with none.

One change outside the menus. At 1280 x 720 the constructor's wider menu left the auto-expand
switch (Guide.gd) no room beside the unit card, and it was laid over the card's text. When the
switch would reach into the BuildingInfo card it now sits above the menu at the right edge
instead; at 1920 x 1080 it stays left of the menu as before.

Evidence: tools/harness/scenarios/hud-card.json passes 22/22 (8 orders, 14 checks) at a true
1920 x 1080 (12.1 game seconds in 53.5 real seconds) and at a true 1280 x 720 (27.4 real
seconds), with six shots: card-orders, card-return-fire, card-hold-fire (Hold fire, Holding
lit), card-build (18 slots in three rows of 6, nothing over the unit card), card-fleet (orders
on rows 1 and 2, Recycle and "4 vehicles selected" on row 3) and card-cancel-build (one slot,
crate and X, Cancel build, no key). Its checks read the card, not only the selection: Patrol
base is the fifth slot with B, the captions say Fire at will, Hold position, Return fire, Hold
fire and Holding in turn, Hold position is lit only while held and its caption fits its slot,
the build menu has 6 columns and 18 slots, the fleet buttons sit below the order rows, and the
site's slot says Cancel build with no key. The same json run on main from /home/claude/ironbound
passes 13/22: the 8 card checks fail there (main's slots have no caption or key nodes, its
build menu is 4 wide), and so does no_errors, with 69 errors from that checkout's import cache
(alert_attack.svg and the new hauler, constructor and militia models missing from
.godot/imported), not from code. Main's shots show the text card with an empty top row and the
X alone in its corner, the 4 x 4 build menu without Trading post and Flak tower, and for the
site a wide empty card with an X squeezed to a sliver at its right edge. A probe at 1280 x 720
with a train selected: the fleet card is 268 x 132, Stop on row 1 and Recycle, Auto line and
the status on row 2; a five-line status grows up to 621..708 inside the card (ends at 715).
CommandChecks at 1280 x 720: 38 PASS and "command checks: 0 failure(s)", including "the Patrol
base button is in the unit menu", "clicking it sends the units on the base loop" and "X stops
them". PlaytestChecks: 20 PASS, 0 failure(s), "worker menu is 4 x 80 px wide or more (is
500)". TooltipsCheck: 76 PASS, all checks passed, "every visible HUD button has a tooltip" in
both shots and 21 menu cards complete. BuildingInfoCheck: 23 PASS, 0 failure(s), the site card
beside the Cancel build slot. smoke 10/10 and hud-alert 3/3 still pass, the data validator
reports 0 errors and 0 warnings, and gdformat and gdlint are clean.

Known and left for later. In a 64 px slot the long structure names end in an ellipsis
(Anti-ground..., Command c..., Vehicle fact..., Aircraft fac...) and the 9 px commodity marks
are mostly told apart by the colour of their numbers; the hover card has the full name and
cost. The first-match tutorial's constructor does not list Foundry or SAM site; giving
first_match.json a faction is a data change for its own PR. With orders only, the card's third
row is an empty dark strip, as the first row was on main; PR 4's bar gives the card its frame.
The icons are 40 / 32 px as section 1 of the spec sets, which leaves about 16 px between icon
and caption in a full slot; 44 / 35 would fill it if play says the icons are small. The fleet
menu's Recycle and line buttons are still words, not icons.

## 2026-10-18: god mode stays out of release builds

Debug god mode shipped switched on: FeatureFlags.tscn sets god_mode = true, so in every
build F2 showed the GodModeHUD (fog toggle, visible player, time scale) and Delete set hp
to 0 on every selected unit. A player can select an enemy unit with a click, so in the
downloads and the public web build Delete killed enemy units. Globals._toggle_god_mode now
also needs OS.is_debug_build(), which Godot documents as false on a release export
template, and the makefile, tools/release/export.sh and the web build all use
--export-release. Release and web players no longer get the debug panel or
Delete-to-kill, and F2 and Delete are bound to nothing else by default, so both keys
simply do nothing there. Running from the editor or the editor binary (the play harness,
the tests) and a debug export keep F2 as before, which is why the flag stays true.
Evidence: a scratch harness scenario in a debug run turned god mode on with the
toggle_god_mode action, showed the HUD, killed a click-selected enemy tank with Delete
(Delete did nothing before F2), and turned it off again with the real F2 key.

## 2026-10-18: a cannon shot draws one muzzle effect, ShotEffects'

CannonShell.tscn still carried the upstream OriginParticles, a GPUParticles3D of 32 particles
under a DetachTransform node, which every shot emitted at the muzzle next to ShotEffects'
flash, smoke and recoil, and a Timer kept the shell node alive for the particles' one second
lifetime. The spray was a cost, not a second visible effect: each particle was a 0.05 m quad
scaled by 0.05, 2.5 mm across, 0.18 px at the default zoom. With the game paused on a tank
shot and the particles hidden for one frame, no pixel changed at the default zoom, 1 at a 6 m
view and 17 faint specks at a 2 m view. The particles, their scene-local materials and the
Timer are gone. The shell still deals its damage in _ready, still calls ShotEffects.cannon_shot
a physics frame later with the same transform, and then frees itself; nothing ShotEffects draws
is parented to it.

Evidence: a scratch probe in a fight of one tank against three raiders counted, per shot, one
GPUParticles3D plus ShotEffects' 2 flash quads, 1 smoke and 1 tracer before (46 of 50 shots,
the shell living 60 to 65 physics frames) and no GPUParticles3D with the same quads after (45
of 48, the shell living 1 frame). In counters-triangle, two runs each side, every fight takes
the same number of shots with the same damage per hit, and the kill times differ between two
runs of the same code as much as between before and after. smoke 10/10, counters-triangle
33/33, hud-health-bars 4/4 and die-once 3/3 pass, the validator reports 0 errors and 0
warnings, gdformat and gdlint are clean. Screenshots: game/direction/feel/muzzle-flash.

Known and left for later. The killing shot draws no muzzle effect, before as after: the target
is freed in the frame the damage lands, so a physics frame later the shell finds it gone and
skips cannon_shot (3 of 50 shots in the probe; before, only the invisible particles fired).
And the tank's flash and smoke are drawn inside its hull, at the unit's own origin: the shell
looks the marker up with find_child("ProjectileOrigin"), whose default owned = true skips
nodes added at run time (the data model, UnitMotion's pivot), and UnitMotion and TurretAim have
moved the marker under them, onto the barrel tip (1.35 m ahead, 0.79 m up). The lookup finds
nothing, so the shot leaves from the unit's 0, 0, 0 and only the tracer shows, coming out of
the lower hull. Rocket.gd makes the same lookup.

## 2026-10-18: upstream files nothing uses are deleted

The repo and the exported game carried upstream leftovers that no scene, script, data
file, test or tool loads. 237 files (1.58 MB) are gone: 114 of the 153 Kenney Space Kit
models in assets/models/kenney-spacekit/ with their .import files, the unused
source/match/players/Player.tscn and source/utils/IconOverview.tscn, the icon render booth
(source/utils/IconRenderBooth.tscn and IconRenderBooth.gd, a dev scene that wrote PNGs into
assets/ui/icons/) and the three files only the booth used: resource_a.material.tres and
resource_b.material.tres in source/match/resources/materials/ and
assets/ui/icons/texture_01.png. The 39 Kenney models that unit, structure and deposit scenes
still use stay, and so does their line in ASSET_CREDITS.md. The Ironbound models nothing
uses yet (research_lab, tanker_truck, ore_coal, rifleman, timber_stack) stay for the art
work. Method: for each candidate, every tracked text file was searched for its res:// path,
its file name and its uid (from its .uid file, its .import file or its scene header), and
the search was repeated with the deleted files left out until nothing new fell out. The
string-built paths (StartPicker, GameData, DepositLook, MatchConstants) and the folder scans
in source/ and tests/ were read by hand; none reach these files. Evidence: a clean
re-import, the validator at 0 errors and 0 warnings, every scene, resource, model and
texture in the project loading headless (563 loaded, 0 failed), and smoke,
factions-foundry, tutorial-first-match, ending, UnitModelCompare, ArtGallery and
PlacementSurvey (every map) passing with no missing-file errors.

## 2026-10-19: one bottom bar: the minimap, the selected unit's card and the command card in one strip
One bottom bar is painted under the kept minimap and UnitMenus containers. Why: Match.tscn binds
a ViewportTexture to HUD/MarginContainer/Minimap/MarginContainer/MinimapViewport and five
read-only tests/manual scenes override that subtree by path and child index, so the bar cannot
own the minimap node. HUD/BottomBar is the HUD's first child (it paints under everything) and
spans the screen's width, 264 px tall at 900 px of height and above and 216 below: three slot
rows of HudStyle.slot_px, the gaps between them and an 8 px margin above and below, so its top
is at 816 at 1080p, 636 at 900p and 504 at 720p. BottomBar.gd applies the compact preset at
_ready (Match.tscn holds the full one), sizes the minimap holder to bar x bar with 8 px margins
and gives UnitMenus a fixed 332 x 248 or 268 x 200 (the constructor's 6-column menu widens it to
500 or 404), and answers BottomBar.of(tree) and top() for the panels that keep above it: CityHud
clamps its bottom to the bar's top minus 6 (and to the auto-expand switch's top minus 6 while
the switch shows under it) and drops its lookups of UnitMenus and the HUD ProductionQueue, and
Guide keeps the auto-expand panel above the alert row over the bar and puts the auto-expand
switch above the bar at the right edge. The bar keeps mouse_filter STOP, so a click on it goes
nowhere and a right click there never orders a move. BottomBar.gd sets STOP on the minimap
holder and the command card holder too: a container lets clicks through by default, their 8 px
margins lie on the bar, and a review probe at 720p found a left click there deselecting and a
right click ordering a move. The look is two new theme variations from tools/ui/BuildTheme.gd:
BottomBar (BG at 0.88 so the terrain reads through, square, a 1 px LINE along the top and an
upward shadow, like the top strip) and MinimapFrame (SURFACE_2 with a 1 px LINE border, radius
4); UnitMenus is a ClearPanel with no inner margins.

The middle cell, HUD/BottomBar/SelectionPanel, runs from the minimap holder's right edge to 8 px
left of the command card, so the constructor's wider menu narrows it (risk 2b of the spec: the
cell's right edge moves 168 px at 1080p and 136 px at 720p when a constructor is selected). It
holds Single (BuildingInfo's card) and Groups (empty until the next slice). BuildingInfo moves
its BuildingCard into Single when that path exists and keeps today's floating card otherwise.
Every match scene today, the tests' and tests/manual's included, inherits Match.tscn and has the
bar, so the floating card, Guide's placement for no bar and AlertBanner's look-up of
BuildingInfo/BuildingCard (which PR 2's entry expected to stop by itself) do not run; they are
kept because the spec asks for the fallback, for a scene without the bar. In the bar the card
has two columns. The left one (300 px, 260 compact) is the unit's icon on a slot-sized tile that
names it on hover, the name, the role, the rank in its colour with the chevrons on the tile's
corner for a veteran, a health bar coloured by thirds with "hp / max" in a 96 px label (the
spec's 72 px is narrower than the command centre's "180 / 180", so the bar changed length from
unit to unit), and for a producer the QUEUE caption over the ProductionQueue, which moved here
from above the command card. The right one scrolls and takes what the cell leaves, up to 640 px,
so a line never runs across the whole bar at 1080p. It has no floor: the spec's 200 px floor
made the constructor's card wider than its cell at 1024 x 768 (a 388 px cell, a 476 px card), so
the bar grew past both screen edges and the card slid under the minimap and the build menu.
SelectionPanel also lays the cell out again when the window or the UI scale changes, floors the
column's width, and changes the column before the margins when the cell narrows and after them
when it widens. A probe at 1366 x 768 with the scale raised to 1.25 mid-match found the bar
still 1366 px wide in a 1093 px view, because the card's width held the bar, so the panel was
never resized and never told; and on reselecting, the new margins and the old column added up to
more than the screen for a moment, after which the bar stayed too wide. Health left the status
lines (BuildingInfoText.status_lines takes with_hp, false for the card) because the bar shows
it. The fold button is gone: folding shrank a floating card, and in a fixed bar it did nothing.
ProductionQueue.tscn lost its five placeholder ColorRects; its elements are HudStyle.queue_px
(56 or 44 px), so five fit in the left column.

Where it differs from the spec, and why. The self-critique pass changed three things. The live
state (status, cargo, the trucks working for a building) comes before the explanation, not
after: at 720p the command centre's explanation alone is seven lines and pushed its status and
haulers below the scroll fold. The explanation is in the muted tone, so the facts (armour,
needs, makes) and the live lines read first. The QUEUE caption and the queue show only while
something is queued, not over an idle producer, and they appear as soon as a unit is queued (the
queue's element list signals it), not at the card's next 0.25 s refresh. So
tests/hud/BuildingInfoCheck's 5-factory-card, which queues nothing, has no queue row; hud-bar's
e-factory-queue shows it. Other differences: the queue lists the unit in production first, on
the left (main put each new element at the front of a right-aligned row, so the newest sat on
the left and the one in production at the right end, which reads backwards in a left-aligned
row); its elements are 4 px apart, the spacing the spec's 296 px sum assumes. MinimapTextureRect
gets expand_mode IGNORE_SIZE: the minimap viewport is 2 px per metre (200 px on the 100 m maps,
400 on Four Oases), and a texture rect that keeps its texture's size would hold the compact
panel at 210 px or more and push the minimap out of the 216 px bar. It is a property of an
existing node, so the subtree's paths and child order do not change. SelectionPanel reads the
cell's width from the screen, not from its own size: read from its own size, a text column set
for a wide cell (the command centre's at 720p) would widen the bar when a constructor's narrower
cell came next, and every later pass would read the wider bar and keep it. BottomBar sets
UnitMenus' minimum width as well as its height, from a new HudStyle.card_width. The icon tile's
disabled look is its normal slot look, not the dimmed look of an order you cannot give. A
rival's role line wraps instead of widening the column. The card's text column is a
ScrollContainer named Details and its left column Summary, the names SelectionPanel looks for.
The spec's line numbers are from main b8f10e8; since then PR 3 made the 6-column card 500 px
wide (so the cell is 264..1404 at 1920, not 264..1412), the 4-column card 332 x 248 and 268 x
200, removed BackgroundGrid and the GenericMenu paddings and had Guide._layout move the switch
above the menu at 720p, which this PR replaces with the spec's rule at every size.
ironbound.tres differs from main by the two variations only, but the generator numbers its
sub-resources in order, so inserting two renumbers the ids after them (200 lines in, 168 out;
the same resources with the ids resolved).

Evidence: tools/harness/scenarios/hud-bar.json passes 24/24 (7 orders, 17 checks) at a true 1920
x 1080 (10.5 game seconds in 51.5 real seconds), at a true 1280 x 720 (27.7 real seconds) and at
1024 x 768 (25.7 real seconds), with five shots: a-nothing-selected, b-constructor,
c-three-tanks, d-command-centre and e-factory-queue. Its checks read the layout: the bar's top
(816, 504, 552), the bar and both holders stopping clicks, the minimap inside the bar's left
cell, the card in SelectionPanel/Single for the constructor and the command centre, the build
menu and the order card inside the bar right of the middle cell, the bar from screen edge to
screen edge beside the constructor's menu, the auto-expand switch above the bar and clear of the
city panel, the card clear of the minimap and the command card, no queue row while the command
centre has nothing queued, and the factory's two queued tanks inside the card. The json as first
written (20 entries, before the queue-row check) run on main from /home/claude/ironbound passes
11/20 at both sizes: the 8 layout checks fail (main has no bar), and so does no_errors, with 78
errors from that checkout's import cache, not from code. The critique's first pass passed its 20
checks too; its d-command-centre at 720p shows the status and the haulers below the scroll fold
and a QUEUE caption over an empty row. Two scratch probes from the review (not committed) cover
the review's fixes. The click probe selects the three tanks and sends a right click and then a
left click to nine points of the bar (its empty middle, the minimap holder's top, right, left
and bottom margins, the command card's empty third row, that holder's right and bottom margins,
and the gap between two of its slots), then cancels a queued tank from the card and releases a
box drag deep in the bar: 28/28 checks ok at 1280 x 720 and at 1920 x 1080, no click there
orders a move or drops the selection, and the box still selects. The layout probe at 1366 x 768
passes 34/34: the bar spans the screen exactly for a constructor, a rival command centre and a
factory with five queued, every hp label is 96 px and every health bar 156 px; with the trade
panel open and a constructor selected the city panel ends at y 443 and the auto-expand switch
starts at 449; and after the scale goes to 1.25 mid-match the bar is 1092.8 px wide in a 1092.8
px view, for the constructor (a 180 px text column) and the factory. SelectionChecks at 1280 x
720, the gate of risk 2a: 15 PASS and "selection checks: 0 failure(s)", before and after the
critique fixes and again after the review fixes; the box over the tanks and the base ends at
about y 492, above the bar's top at 504, and its release lands on the battlefield, so the
RectangularSelection3D fallback was not needed. BuildingInfoCheck at 1280 x 720: 23 PASS, 0
failure(s). UiShots --only=hud: 0 problem(s) at 1280 x 720 and at 1920 x 1080. PlaytestChecks:
20 PASS, 0 failure(s), "worker menu is 4 x 80 px wide or more (is 500)". CameraChecks: 12 PASS,
0 failure(s). TooltipsCheck: 76 PASS, all checks passed. Playthrough (plain_and_simple, balanced
and raider, 8 minutes, at 1920 x 1080): time limit after 494 s, exit 0, 0 errors, and no "sticks
out" or "overlaps" finding; its notes are two missed clicks at 27 s on a constructor above the
bar (the run before the review had one too) and no free copper deposit for the menu-placed mine
at 39 s, a search in the world that does not involve the HUD. smoke 10/10, hud-alert 3/3 and
hud-card 22/22 still pass, the data validator reports 0 errors and 0 warnings, and gdformat and
gdlint are clean on source/. A scratch run at 1280 x 720 (not committed) with a tank promoted to
Elite and hurt to 30 % passes 7/7: the card shows ELITE in the rank's colour, the chevrons on
the tile's corner and a red health bar at 13 / 39.

CommandChecks at 1280 x 720 fails 2 of 38 checks (36 PASS, "command checks: 2 failure(s)", the
same two after the review fixes), where PR 3 had 38 PASS: "F + left-drag gives each unit a fight
order to its spot on the line" and "they form the fighting line". CommandChecks._check_fight
keeps the camera at size 28 on a point 10 m short of the fight goal and draws the line 4 m past
the goal: at 720p the click lands at y 489 and both ends of the line at y 540, inside the bar
(top 504). The bar takes that press, as it should for a click on it. A scratch scenario at 1280
x 720 (not committed) passes 17/17: after F, a left-drag across the bar at y 600 gives no order
and the fight mode still waits, and the same drag at y 430 gives every tank a fight order. Tests
are read-only without Destin's approval. Framing the camera on the goal before
the line (camera_on(goal, 28.0) and ten frames before the F press in _check_fight) puts both
ends at y 411: a scratch subclass of CommandChecks with that change and only the fight check
(not committed) passes 8 PASS, 0 failure(s), with the line's ends at (485.7, 411.4) and (794.3,
411.4). Destin approved that two-line change to the test, and this PR carries it.

Known and left for later. With nothing selected everything right of the minimap is empty bar
(about 1650 x 248 px at 1080p, 1050 x 200 at 720p), and with several units selected the middle
stays empty until the Groups slice; these are the shots a-nothing-selected and c-three-tanks for
Destin to judge (risk 1); BG 0.88 is kept and no frame art is added. The auto-expand switch now
sits above the bar at the right edge at every size, over the battlefield (at 1080p main had it
in the bottom band beside the menu). With orders only the command card's third row is empty bar.
At 720p the command centre's card scrolls: its needs and makes lines are below the fold. CityHud
now always stops above the bar, where on main it reached the screen's bottom while nothing was
selected, so at 720p the open trade panel scrolls to reach Propose trade (UiShots
hud-city-trade). A construction site's health bar starts red, because a site's hp grows as it is
built; its status line says how far along it is. With all the left panels open at 720p the
tutorial runs down over the minimap, as it did on main. Below about 920 px of width after the UI
scale (1024 x 768 at 1.15 or more, 1280 x 720 at 1.4 or more, 1366 x 768 at 1.5), the minimap's
216 px cell, the card's 260 px column with its gap and the constructor's 420 px menu cell do not
fit side by side, so the bar grows past both screen edges: the review's layout probe at 1024 x
768 with the scale at 1.25 (an 819 px view) has the bar at x -50 and 919 px wide, and the
constructor's card, its text column down to 7 px, runs 42 px under the minimap and 42 px under
the build menu. The 4-column card fits down to about 783 px. A narrower left column at that
size, or a card that clips, is for Destin to choose.

## 2026-10-19: the helper saves for its faction's main battle unit

The helper's army bought the costliest unit the bank covered above the keep
(Helper._best_unit_for). Iron is the scarce commodity on Desert Expanse and arrives a few
units at a time, so each climb crossed the hover skimmer's floor (iron 13) before the tank's
(15), and "costliest affordable" in practice meant "cheapest in iron": on main the helper
made 0 to 1 tanks and 15 to 21 skimmers by 5:00 in the runs below, and the AI's tanks deal
double damage to the skimmer's light armour. With a full bank the rule was wrong too: the
Foundry's costliest T1 unit is the amphibious APC, not the tank. Now each factory's first
choice is the faction's main battle unit from data/factions (main_t3, then main_t2, then
main_t1, the roles the AI builds from), and the helper saves for it for up to 60 s
(HelperArmyPick.SAVE_FOR_S). While it saves nothing cheaper is bought at any factory, and
the helper panel adds "Saving for a Tank." to the army line. When the window runs out the
helper saves for the next tier's main unit instead, still buying the higher one whenever the
bank covers it, and goes back to the top unit when it buys it or a new tier changes it.
After the lowest main unit's window it buys the first unit the bank covers: the other combat
units by cost, file order on a tie. The role table rather than a fight model, because it is
data the AI already reads, so a retune of roles in item 6 moves both sides, and "the helper
builds your faction's main unit" reads on screen. The lead kept the role table at tier 2:
the Foundry helper and a helper without a faction save for the heavy tank there, as the AI
builds it, and the heavy tank's value is fixed in the item 6 difficulty retune. The in-game
help (HELP_HELPER_BODY, item 2) now says what the army builds.

Why the step-down: saving is not a reservation. Auto-expand's own floors (pylon 12, mine 14)
keep the bank's iron at 10 to 17, under the heavy tank's floor (iron 20 with the keep). With
one window and then a fallback, every unit after tier 2 waited out the full window first: in
review, the first version of this change made 9 army units (41 iron) in the five minutes
after tier 2 of the 1v1 probe, where main made 21 (84 iron). With the step-down the heavy
tank gets a window, and once it has run out the tank keeps its tier 1 pace and a heavy tank
is bought whenever the bank covers one (each heavy tank bought starts a new window for it).
Pinning the helper to main_t1 until item 6 (MAIN_ROLES = ["main_t1"]) was the other option;
it was not taken because the lead kept the role table at tier 2.

Why 60 s and not the design's 30 s: the design raises SAVE_FOR_S to 60 s if the skimmer
check fails. At 30 s it failed in two of six helper-army-pace runs of this change and in one
of two of its first version, all seed 5 with 3 skimmers by 5:00, each bought by the fallback
after a window ran out (at tier 1 the tank ranks first, so the fallback is the only way to a
skimmer). At 60 s it passes on every run: 0, 0 and 1 skimmers by 5:00 on seeds 3, 5 and 7,
and 0 in two more runs of seed 5.

The save clock restarts when an order goes in at the main unit's factory, when the first
choice changes (a new tier, or the unit cap dropping it), when the main unit's factory drops
out of the plans (its queue full, the factory gone, or the main unit not fitting under the
cap), on every early return (army off or full, no factory, unit cap) and when the helper is
switched off. Units with no room under the cap drop out of the ranking, so a smaller one
still fills the last slots. The free slots are counted once per think, because
MatchLimits.has_room_for walks every unit in the match and the saving helper reaches the
pick on more thinks than before; has_room_for is asked once more right before each order, so
a second factory cannot order a unit that the first factory's order in the same think left
no room for. The pick lives in HelperArmyPick.gd because Helper.gd was at 999 of gdlint's
1000 lines (994 now).

The scout: the save held iron at 12 to 14, above the scout buggy's floor (iron 12 with the
keep) and below the tank's, so in review the first version rebuilt its scout within half a
minute of each loss and built 13 in the probe where main built 3. While the army saves, the
helper now waits 90 s (Helper.SCOUT_REPLACE_S) after losing a scout before it orders another,
and the panel counts the wait down ("Scouting: the next scout buggy in 42 s, after the army's
save"). With the army full or not saving it replaces the scout at once, as on main: in
review a hold that always applied left HelperChecks, whose army is full, without a scout for
its hold-fire check whenever the scout died in the last 90 s before it. Main's check for a
lost scout never fired: in Godot 4.7 a freed object compares equal to null, so
`_scout != null and not is_instance_valid(_scout)` is false once the scout is freed. It now
tests `typeof(_scout) == TYPE_OBJECT`. A Foundry helper still never scouts: the Foundry's scout
role is the drone, which needs an aircraft factory the helper never asks for, and the panel
says it waits for a scout buggy and a vehicle factory that already stands. That predates
this change and is a follow-up ticket; helper-army-pace's scouting flag does nothing for its
Foundry player, and its description says so.

Evidence: new scenario helper-army-pace (a Foundry player with the helper, army 24, against
a very easy Foundry turtle on Desert Expanse whose first attack comes at 12:00), seeds 3, 5
and 7 on main 1a3a96e and on the branch, read with the helper-design probe_numbers.py. Main
passes 5, 3 and 5 of 8 checks; the branch passes 8 of 8 on all three. By 4:00 main made 0, 0
and 1 tanks, the branch 10, 8 and 8; by 5:00 main 0, 0 and 1, the branch 15, 12 and 15.
Skimmers by 5:00: main 21, 20 and 15, the branch 0, 0 and 1. The longest stretch from 1:00
to 5:00 with no tank: main 240 s on all three, the branch 43, 55 and 82 s. Structures by
5:00: main 10, 6 and 12, the branch 15, 16 and 15; the first power plant came at 8:31, 9:41
and 7:52 on main and at 6:50, 4:34 and 6:04 on the branch, so main's seed 5 fails both
auto-expand guards. Made by 8:00: main 21 skimmers and an APC twice, then 19 skimmers and 2
tanks; the branch 21 tanks, 21 tanks, and 20 tanks and a skimmer. A fourth main run of seed
5 made 0 tanks and 21 skimmers by 5:00 and failed 4 checks.

Think time: the helper's think time per think (think_usec_total / thinks) was 1447, 1531 and
1479 us on the branch against 1356, 1292 and 1412 on main, 7%, 18% and 5% above, but it
moves with the box's load from hour to hour (main alone read 1259 to 1494). Run back to back
on seed 5, main, the first version of this change and this one read 1437, 1604 and 1549 us,
then 1494, 1705 and 1678: this version 8% and 12% above main and 3% and 2% below the first
version. Both versions save, so the step-down, the room check and the scout hold add nothing
that shows; what costs is common to both, and HelperChecks' bound of 2 ms per half-second
tick passes.

The checks differ from the design's numbers where the runs said so. The design asked for 4
tanks by 2:00, but main made 2 or 3 by 2:00 in three of thirteen runs, so the first check
asks for 6 by 4:00: over twenty-two runs of either version of this change the branch made 6
to 10 by 4:00, and main made 0 to 4. The design's 10 by 5:00 became 8 (a tank every 30 s
from 1:00): the branch made 9 to 16, main at most 4. The power plant guard moved from 3:00
to 9:00: the design's 2:26 came from the Normal AI probe, but here auto-expand builds its
first plant when the grid runs short, from 6:38 to 9:41 over twelve main runs and from 4:06
to 8:31 over twenty branch runs. It guards against the branch starving the plant and does
not pass on every main run. The design's target of no stretch over 30 s without a tank is
not met (43 to 82 s, while auto-expand spends the iron on its first mines and pylons).

Shape check: the direction probe probe-1v1-normal as it is (no faction, a Normal balanced
AI, seed 3) on main (the review's run) and on the branch. Tanks by 5:00 went from 6 to 11,
skimmers by 5:00 from 12 to 1, skimmers lost by 8:00 from 11 to 1, missile trucks by 8:00
from 4 to 0, and the helper-made army alive at 8:00 from 18 to 16. The longest stretch from
1:00 to 5:00 with no tank went from 102.5 s to 36.0 s. Tier 2 came at 6:49 on main and 7:13
on the branch. In the three minutes after tier 2 main made 14 army units (8 skimmers, 5
missile trucks and an artillery, 57 iron) and the branch 10 tanks (50 iron); in five minutes
21 (84 iron) against 15 tanks (75 iron). The branch's first minute after tier 2 is the heavy
tank's window, with iron at 10 to 17, then a tank came every 9 to 39 s. It built no heavy
tank all match (35 tanks and 2 skimmers) and lost at 17:39, main at 16:46. It built 4 scouts
(at 0:27, then 94 to 102 s after each loss), main 3 (from 3:15).

A tier 2 diagnostic, a scratch copy of the pace scenario that forces tier 2 at 4:00 with
army 40 (seed 3): in the three and four minutes after tier 2 main made 14 units (12 skimmers
and 2 missile trucks) and 16, the first version of this change 7 and 9, and the branch 9 and
15 (13 tanks and 2 heavy tanks). Each heavy tank bought starts a new heavy tank window: one
bought at 4:52 was followed by 67 s with no unit. The Syndicate, the same diagnostic with a
Syndicate player: 18 raiders by 4:00, then 14 rocket technicals and 2 raiders in the three
minutes after tier 2, a scout buggy at 0:16 and no script errors.

Unchanged on the branch: helper-never-attacks passes 5 of 5 and smoke 10 of 10; CapsChecks
has 0 failures (the helper fills the army to the cap, 10 of 10 slots, and the panel says the
cap stops it); validate_data reports 0 errors and 0 warnings; gdformat and gdlint are clean.
HelperChecks passes its army checks on every run on both sides (4 of 4 units and a scout, it
stops at the army size, no attack orders, under 2 ms a tick) but fails its constructor guard
scenarios on main too. Run alone (--only=detour,hold,retreat), main failed 2 checks in both
runs ("and reached the site behind the squad", "and gets away from where it was"); the
branch failed the same 2, then 1 ("gets away") in a run where the test stopped the detour
scenario on a freed constructor (the script error at HelperChecks.gd:191 that a full main
run also hit). In full runs, where the peace scenario's army is still on the map, main
failed 3 and 2 checks, the first version of this change 3 (cut short), 1 and 2, and this
version 4 and 4. Both 4s add "it never came within 12 m of the squad" and "it went around
the squad": the test's constructor was held back instead of rerouted, with the same guard
log line ("no detour around ..., first leg 30, second leg 6", then a hold) as in main's
first full run, which passed "it went around the squad" only because another constructor
took a detour.

Missile trucks no longer come by accident: the tank, which ranks first, needs the same iron
and oil as the truck and less copper, so whenever the bank covers a truck it covers the
tank, and the helper fields no mobile anti-air until PR 4 (the counters PR) brings the truck
back on purpose. PR 1 and PR 4 ship back to back, with no release between them. A Syndicate
helper now fields raiders, which tanks shred, until the PR that vetoes units the enemy hits
at double damage.

Re-run after the scout change, merged with main ef2c11a: helper-army-pace passes 8 of 8 on
seeds 3 and 5 (9 and 10 tanks by 5:00, 1 and 0 skimmers, the longest stretch with no tank
103.7 and 41.0 s; the Foundry helper never scouts, so the scout change does not touch this
scenario and the spread is run to run), smoke 10 of 10, helper-never-attacks 5 of 5,
CapsChecks 41 PASS and 0 failures, the validator 0 errors and 0 warnings. HelperChecks, two
full runs: 20 PASS and 2 failures, then 23 PASS and 4; "the scout never attacks an enemy tank
next to it at war" passes in both, and every failure is a constructor guard check that fails
on main too.

## 2026-10-19: shots leave from the muzzle marker, and the killing shot is drawn

The shells and rockets looked their marker up with find_child("ProjectileOrigin"), whose
default owned = true skips nodes added at run time (UnitMotion's MotionPivot, the data model)
and everything under them, which is where UnitMotion and TurretAim keep the marker. So every
flash, smoke puff, tracer and rocket started at the unit's own origin, on the ground; only the
bunker, gun_nest, flak_tower and sam_site, whose marker stays in their scene, found theirs.
ShotEffects.muzzle() now looks it up with owned = false for both projectiles and keeps it in
the shooter's "_muzzle" meta.

The killing shot drew nothing: the shell draws a physics frame after its damage, and by then
the target is freed. A killing shot is now drawn at once, in the frame its damage lands, while
the dying target is still in the tree. Its tracer takes the shortest flight, 0.08 s, to land as
close to the death explosion as it can, and ends without sparks, which the explosion stands in
for. Other shots still draw a physics frame later, into the aim point taken before the damage.
The damage still lands in _ready, in the same frame, for the same amount.

TurretAim put the marker at the middle of the turret's front face, above the barrel: 0.19 m on
the heavy tank, 0.085 m on the tank. When the frontmost 5 % of the turret mesh is under half
its width and height, TurretAim now takes it for a barrel, or a pair, and puts the marker at
its middle, 1.5 barrel heights ahead of its end; a launcher keeps the middle of its face. This
is a heuristic tuned on the current models, and a muzzle field in data/units would replace it.
The militia used the tank's marker, scaled down, between its front riflemen; Militia.tscn now
puts it on the front right rifleman's muzzle.

Still wrong, each for want of a per-unit muzzle in data/units, as one marker in a shared base
scene serves several models. The AG and AA turrets this change fixes are hidden in both
factions: the defenses players build are the bunker and flak_tower (Foundry) and the gun_nest
and sam_site (Syndicate). Their marker sits on the hidden kenney turret of
AntiGroundTurret.tscn or AntiAirTurret.tscn, about 0.4 m from the centre on the side facing the
target and 0.5 m up, while their gun is part of one mesh that does not turn. The bunker's and
flak_tower's flash is inside the model and only the tracer shows. The gun_nest's flash shows
over its sandbags, and is on its barrel only when the target is in front of the model. The
sam_site's flash and rocket start beside its rack, at half its height. The marker also turns
with the idle scan, so the first shot after idling can leave 0.8 m from where the next ones do.
The rocket_technical, the Syndicate's main tier 2 and tier 3 unit, launches from its hood, not
the rack on its bed, and the patrol_boat fires from its bow waterline. A rocket already in
flight when its target dies still vanishes with it (Rocket.gd frees itself on the target's
tree_exited), so the killing-shot fix covers shells only.

Evidence: a scratch probe of 20 armed units over 25 s counted on HEAD 1382 flash quads, 372
tracers and 319 rockets starting at the unit's origin, and 0 of 359 killing shots drawn; with
this change, in two runs, none at the origin and every killing shot drawn (382 and 364), each
with its flash at the marker. In counters-triangle, every unit that died took the same hits for
the same damage per hit in two runs on HEAD and three with this change. smoke, die-once and
hud-health-bars pass, the validator reports 0 errors and 0 warnings, gdformat and gdlint are
clean, and the stress-40v40 frame time is the same within the noise between runs.

## 2026-10-19: several units selected show one tile per unit type with its count and each unit's health
With two or more units selected, the bar's middle cell (HUD/BottomBar/SelectionPanel) shows
Groups and hides Single; one unit keeps BuildingInfo's card in Single, unchanged, and nothing
selected hides both, as the spec has it (PR 4 left Single shown and empty). SelectionPanel.gd
builds Groups in code: the tiles and a totals line under them. Each tile is a Button named
Type_<data id> (Type_tank, Type_artillery, Type_worker) with the SlotButton look, slot x slot
(80 px at 900 px of height and above, 64 below), in an HFlowContainer named Tiles, the most
numerous type first and then by id. It holds the unit's icon, the count in the accent colour at
the top right, a health strip under the icon and the name along the bottom (HudStyle.caption,
as on the command card). The strip has one segment per unit coloured by thirds, healthiest
first, so the red ones gather at the right end. A type with a unit in the red gets a red frame
(SlotButton's resting and hover looks with the BAD border) and a red count of those units in
its top left corner, where a command slot carries its key (HudStyle.hotkey_tag), so "how many
are dying" is a number the eye finds before it reads the strip. The totals line (the HBox named
Header) says how many units ("14 units"), their hit points together in the muted tone ("370 /
408 HP") and how many of yours stand idle, in amber and in the same face and size as the unit
count ("12 idle", hidden at 0). The group key is the data entry's id (GameData.unit_by_scene,
as ControlGroupBar finds a group's icon), falling back to unit.type, so battle_tank stays apart
from tank. Only units count: a deposit Shift-clicked into the selection (deposits carry the
Selection trait) gets no tile and is not in the totals; BuildingInfo shows no card for a
deposit and keeps the card of the one unit selected with it, and Guide's army-orders hint skips
it (both read unit.player and threw an error per selection, on main as well, BuildingInfo's
every 0.25 s while a deposit stayed selected). A click on a tile keeps only that type
selected (Utils.Match.select_units); a Shift-click drops it (Selection.deselect on each unit).
The tooltip names the type and the count, says how many are healthy, hurt and critical, and
says what a click and a Shift-click do. Why: the measured problem is fifteen idle tanks nobody
noticed (docs/direction.md); a line that counts the idle ones and a strip that shows which are
dying answer "how many of what, and which are dying" in one row, where a portrait per unit
(SC2) is twenty identical squares for twenty tanks and overflows the cell at 720p with forty.

The tiles are kept. A refresh groups the selection and compares its [id, count] list with the
one last drawn; only when it differs does it add the tile of a new type, free the tile of a type
that left and reorder, so a death changes a number and frees nothing. The order is by count only
when the player changed the selection (unit_selected or unit_deselected) or a type is new to it;
between those a death keeps every tile where it is, as Generals and SC2 never reorder a live
selection, so the tile the eye is on in a fight never moves under the pointer. A strip is
redrawn only when one of its units crosses a step of 1/30 of its health. Refreshes come every
0.25 s while Groups shows and once at the end of the frame after unit_selected, unit_deselected
or the death of a selected unit, however many units changed. When a death leaves one of two
selected units, BuildingInfo picks that unit again (one line in BuildingInfo._on_unit_died,
deferred so the dead unit is out of the group by then): its card shows in Single instead of an
empty middle; BuildingInfo's rule for one unit does not change. The first time two types or more
show, Guide.show_hint("HINT_SELECTION_TILES") says what a click and a Shift-click do; its manual
topic is Basics, which gains one sentence on the tiles. Five strings: SELECTION_UNITS,
SELECTION_HP, SELECTION_IDLE and SELECTION_TILE_TOOLTIP in match.csv (English and Polish) and
HINT_SELECTION_TILES in guide.csv (English only: guide.csv has no Polish column). The command
card does not change, as the spec asks: with several of your units selected UnitMenus shows
GenericMenu, the 4 x 3 orders, for all of them (and FleetMenu with it when every selected unit
is a truck or a train); the constructor's build menu and a producer's menu need exactly one
unit, so a second one hides them; with only rival units selected the card hides. The harness's
click order takes control (a node's name; it clicks the centre of the node's rect), which the
spec put in PR 1 and PR 1 did not add.

Where it differs from the spec, and why. The self-critique pass (the first shots against
Generals' and SC2's multi-selection) and the review changed these. The tiles come first and the
totals line sits under them, where the spec puts the header row first: with the header on top
the tiles started 26 px below the command card's first row and the one-unit card's icon tile,
so the bar read as two rhythms and a slot-sized tile hopped 26 px when the selection went from
one unit to two; now the tiles start at the cell's top (y 512 at 720, 824 at 1080), level with
the card's rows, and the line ends level with the card's last row. The idle count is a
NumberLabel at 15 px in WARN, not a MutedLabel at 13: it was the smallest item of the line in a
different face from the two numbers beside it, and it is the number the line exists for. The
strip is 8 px tall in an 80 px tile and 7 in a 64 px one (the spec's 6) and spans the tile less
4 px a side (the spec's 8): at 6 px a segment was a chip the eye had to hunt for. Past the
segments the strip has room for (more than 24 units at 80 px, 19 at 64) it shows one run per
colour, as wide as its share of the units, red at the right end and never thinner than 4 px,
where the spec drew one bar at the mean: in a 28-tank group with one tank dying the mean is
green and hides it, and at 1 px the run was a hair; two rounded shares can add up to more than
the strip, so the hurt run gives way and the green one is never negative. The red frame and the
red count in the corner are additions: in a mixed fight half the tiles carry the frame, so the
frame alone no longer points, and the count says how many. A count in a 64 px tile is 13 px and
3 px from the right edge (15 px and 5 px in an 80 px tile): at 15 px two digits ran over the
icon's corner. Idle is no action, or a WaitingForTargets that is_idle(), and never a unit
holding position: a tank's resting action is WaitingForTargets and never null, so the spec's
rule would count no tank as idle; a unit holding position (K) was posted there by the player,
where a fire stance (L) only says how it fights, so a tank holding fire with no order still
counts, as HomeGuard sends neither; only your own units count, never a structure. Health is
floored to steps of 1/30, not snapped to 0.05, so the thirds where the colour changes fall on
step edges. The name is HudStyle.caption (11 px in an 80 px tile, 10 in a 64 px one, PR 3's
rule), not 11 px at both sizes. The tiles sit in a ScrollContainer named TileScroll, so more
types than two rows hold scroll instead of growing the bar. The hint fires the first time two
types or more show, not the first time Groups shows: with one type a click on its tile changes
nothing. The hit point sum rounds each unit's hp up, so a unit with 0.4 hp left still counts.
The spec groups a mixed selection whole; a rival unit still groups, a deposit does not, because
a deposit has no type and no hit points and the first version threw an error every 0.25 s with
one selected and kept a broken tile list for the rest of the match. BuildingInfo.gd is outside
the spec's file list for this PR; its two changes are the death re-pick above and the pick
among units only. hud-selection.json
differs from the spec's: with the enemy at [60, 40] the fight changed the counts under the
checks, so three enemy tanks start at [50, 40], the player's tanks and artillery hold fire, the
enemy drives off at 5.3 s and the constructors walk away so they are not idle; the selections
take the units near the fight (own:* also holds the command centre); the Shift-click holds
shift_selecting around the click (the virtual mouse's shift flag does not press the action, a
player's Shift key does); "select own:nothing" clears the selection (the harness has no deselect
order, so the report lists that order as failed, and it carries no expect_ok); a fourth shot
selects 28 tanks for the runs; and the review's cases follow: a Shift-click on the timber stand
at [4, 42] with the 28 tanks selected, the two constructors selected after it, two tanks and the
two constructors with one tank killed by a check that sets its hp to 0, and two tanks with one
killed.

Evidence. hud-selection.json at a true 1920 x 1080 (80 px tiles) and a true 1280 x 720 (64 px
tiles): 47 of 47 orders and checks at both sizes, 0 script errors, the two deaths the checks cause
and no other loss. a-three-types shows 14 units, 370 / 408 HP, 12 idle under three tiles, the tank
tile first with a red frame, a red 1 in its corner and a strip of six green, one amber and one red
segment, then artillery 4 and constructor 2, the tiles level with the Fight slot; b-tanks-only one
tile after a click, the red frame still on it under the pointer (8 selected); c-artillery-dropped
two tiles after a Shift-click (10 selected); d-twenty-eight-tanks one tile counting 28 with a red
1, a long green run with the amber and red runs, 4 px each, at its right end (886 / 924 HP);
e-deposit-in-selection the same tile and "28 units" with the timber stand's circle lit and 29
nodes selected; f-one-left-by-death the survivor's card. The checks also read the layout: Groups
shown and Single hidden with several selected, Single with its card and Groups hidden with one,
both hidden with none, the tiles slot-sized, inside the selection panel, level with the command
card's first row and clear of the minimap and the command card, the totals line under the tiles
inside the panel; and the review's cases: no tile and no count for the deposit, the constructors'
tile after it, the tank tile first with 1 after the death that made it the smaller group, and the
card after the death that left one. The same json on the PR 4 base fails its Groups checks at both
sizes: the middle of the bar is empty with fourteen selected (hud5-before-1080 and
hud5-before-720, shot with the version before the review's cases). The review's own deposit
scenario (deposit-sticky-2, a Shift-click on the timber stand between two selections) now passes
15 of 15 with 0 script errors, where the first version threw 43, and its edges scenario (a death
that leaves one of two, a rival in the selection, 24 types at 720, a deposit Shift-clicked in and
a deposit clicked alone) 22 of 22 with 0 errors. TooltipsCheck 76 PASS, all checks passed. UiShots
--only=hud 0 problem(s) at 1280 x 720 and at 1920 x 1080. BuildingInfoCheck at 1280 x 720 23 PASS,
0 failure(s). SelectionChecks at 1280 x 720 (box drags and control groups) 15 PASS, 0 failure(s).
PlaytestChecks 20 PASS, 0 failure(s). CommandChecks at 1280 x 720 38 PASS, "command checks: 0
failure(s)" (with main's camera fix for the fight line). smoke 10/10, hud-alert 3/3, hud-card
22/22 and hud-bar 24/24 still pass. stress-40v40 with select p0:* at 2.1 s (the player's whole
side selected while the armies fight; a scratch copy, the repo's file unchanged): frame_ms_p95
125.39, 126.07 and 113.06 ms on this branch, 129.36, 119.23, 116.97 and 118.94 on the PR 4 base,
so no measurable cost (this container renders in software, so both miss the 50 ms budget, as every
run here does; p50 was 80 to 87 ms in every run; a fourth run on the branch, 188.57, overlapped
another worker's Godot on the shared box and is not counted; before the review the pairs were
125.61 and 129.57 against 125.57 and 133.41). The spec compares with PR 1's baseline; main has
moved since, so the comparison is with the PR 4 base on the same day and box, at 2.1 s so the
selection comes after the fight orders at 2 s. The data validator reports 0 errors and 0 warnings;
gdformat and gdlint are clean on source/.

Playthrough (plain_and_simple, balanced and raider, 8 minutes, at the project's 1920 x 1080):
three runs on this branch and one of a scratch copy of the bot with logging added, 0 script errors
and no "sticks out" or "overlaps" finding in any. The third (time limit after 499 s, exit 0) and
the copy found nothing; the first two reported one bug each, a different one, and neither is the
HUD's. "clicking Hauler.tscn did not queue it" (152 s): the click reached the command centre's
Hauler button (its pressed signal fired), and the bot counts that queue before its click and three
frames after it, while the constructor it put on auto-expand orders a Hauler there whenever the
queue is empty (AutoExpand._order_hauler_if_short). The logging run measured 4.8 to 5.2 s of the
bot's clock from the count to the check, and six Haulers the bot never clicked; one started at
236.8 s was built by 240.8 s. An auto-expand Hauler that finishes inside that window cancels out
the one the click queued. "OilDerrick (menu OilDerrick.tscn) could not be placed:
COLLIDES_WITH_OBJECT" (199 s): the shot shows the blueprint in the middle of the screen, red over
the player's own finished Oil derrick 2, a deposit the bot took for free. Both are the bot's races
and guesses in the world, in code older than PR 4 that this PR does not touch, and tests/ is
read-only. Two runs on main in the same session (the PR 4 head, the same tree): one found nothing,
exit 0; the other reported two bugs of the same kind, "VehicleFactory (menu VehicleFactory.tscn)
was valid but clicking did not lay out a site" (125 s) and "Worker of P0 sits still for 45s while
Constructing" (210 s), exit 1. The bot's world findings come and go without this PR as well. One
run after the review's fixes: time limit after 509 s, exit 0, 0 script errors, no bug, two missed
clicks noted (a constructor at 59 s, an aircraft factory at 424 s).

Known and left for later. The tiles do not mark an active subgroup (SC2's Tab): the command card
gives every order to every selected unit. The idle count is for the whole selection, not per
type. The artillery's icon is the anti-ground turret's (data/units/artillery.json), dark at 32
px, and tank, heavy_tank, battle_tank and militia share Tank.png with different tints, so at 32
px the captions tell them apart, not the icons: one icon per type is an art pass. Names longer
than a tile clip with an ellipsis ("Trade carav...", "Rocket tech..."); shorter display names
are a data pass. With few types the cell is mostly empty glass, as PR 4's risk 1 says, and with
nothing selected the middle of the bar stays empty (the spec's open question 5, the whole army
as tiles, would be PR 6). More than two rows of tiles (23 types or more at 720, 31 at 1080,
reached only by Shift-adding structures to a big army) scroll inside TileScroll, the third row
cut at the bar's edge with only the scroll bar to say so. The tiles' hint waits behind the army
orders hint, which fires on the same first selection, so it shows up to 12 s later. No native
speaker has checked the Polish strings.
