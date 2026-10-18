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
