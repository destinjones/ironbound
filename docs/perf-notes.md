# Perf notes: 60 fps at 20 against 20

What the "15,000 buildings at 200 fps" Generals-style demo does that we can use, how
Ironbound draws today, and three changes ranked by payoff. Measured 18 October on main
(9c9d369) in the cloud box with the software renderer, so milliseconds here are the CPU
side only; draw calls, primitives, surfaces and the ratios carry over to a real PC. Nothing
in this note is a change: it is the plan for item 10 of docs/direction.md.

## Where the frame goes today

| What | Measured | Where |
| --- | --- | --- |
| GPU, 4-player match, 1080p High, RTX 3060 | 4.5 to 5.7 ms | docs/decisions.md, 2026-10-17 |
| CPU, 20 v 20 on Big Arena, 3D off | frame p50 66 ms, p95 91 ms; process p95 103 ms | `./play.sh stress 20`, harness-out stress-20v20 |
| Draw calls at contact, 59 units, 3D on | 1,396 draw calls, 415k primitives a frame | same run with `--view=window --minutes=1` |
| Draw calls after the fight, 28 units | 480 draw calls, 70k primitives | same |
| Per fighting unit | about 30 draw calls and 11k primitives (shadow pass included) | the difference of the two rows |

So the GPU has room (5 ms of a 16 ms frame) and the CPU does not: at 20 v 20 the process
time alone is six times the frame budget on this CPU, and the 60 to 90 ms hitches seen on
the RTX 3060 PC on 17 October were CPU too (extractor planning, since fixed). 60 fps at
20 v 20 is a CPU problem first and a draw-call problem second.

The harness records no render counters. The two draw-call rows came from adding
`Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` and `RENDER_TOTAL_PRIMITIVES_IN_FRAME` to
`tools/harness/Recorder.gd:_sample` for the run and reverting; keeping those two columns is
a two-line change to test tooling and needs Destin's OK.

## How Ironbound draws units and structures

- Every unit and structure is its own scene; `GameData.apply_model`
  (source/data-model/GameData.gd:330) instantiates the GLB under its Geometry node. There
  is no instancing of units or structures and none is needed: the cap is 150 units and a
  base has a few dozen structures, against the demo's 15,000.
- Team colour is one shared `StandardMaterial3D` per player
  (source/match/players/Player.gd:140) set as a surface override on the matching surfaces
  (source/match/MatchUtils.gd:11). That is already the cheap way to do it.
- Surfaces are the draw calls. Models that went through the textured pipeline have 2 to 4
  surfaces and one or two textures (tank 4, heavy_tank 4, militia rifleman_squad 2, every
  `buildings/generated/*` 2). The legacy procedural models have one material per part and
  no texture: hauler 13, trade_truck 11, constructor 9, aircraft_factory 21,
  vehicle_factory 22, command_center 21, artillery 14 (primitive counts read from each
  GLB's JSON header at this commit). Each surface is a draw call in the colour pass and
  again in the shadow pass.
- Triangles: units 1.1k to 7.7k, generated buildings 8.4k to 9k, inside the
  docs/art-direction.md budgets. Godot's importer already generates LODs and shadow
  meshes for every GLB (`meshes/generate_lods=true`, `meshes/create_shadow_meshes=true`
  in the .import files), so distance LOD is in place and costs nothing more.
- The one directional light casts shadows from everything except effects, rings and
  decals (the `cast_shadow = OFF` lines in source/match/effects and hud). The shadow pass
  is why primitives per unit are about twice the model's triangle count.
- MultiMesh is used where it pays: desert scatter (source/match/maps/DesertScatter.gd),
  wildlife, wind props, rail, townsfolk and chimney smoke, each one draw call per kind.
- The Grounded look adds SSAO and SSIL (data/looks/grounded.json); GraphicsQuality.gd
  turns them off below High.

## What the demo does that we can use

15,000 buildings at 200 fps means one draw call per building type (MultiMesh or GPU
instancing), one texture atlas so one material, LOD or impostors far out, and no node per
building. Ironbound's counts are two orders of magnitude smaller, so instancing structures
would save a few dozen draw calls out of 480 and is not worth its code. What carries over
is the discipline per asset: one material, one atlas, few surfaces, and nothing drawn or
simulated for a unit that the frame does not need.

## Three changes, ranked by payoff

1. **CPU time per unit in a fight.** The only item that decides 16 ms. Evidence: process
   p95 103 ms at 20 v 20 with 3D off, and 1,696 frames over 50 ms in two minutes. What it
   takes: one stress run on a PC under the Godot profiler to name the top three functions
   (likely candidates are the per-frame target searches in
   source/match/units/actions/AutoAttacking.gd and the adherence checks in
   source/match/utils/UnitMovementUtils.gd, both scanning the `units` group), then run
   those on a timer or through a spatial bucket instead of every frame. Proof:
   `./play.sh stress 20 --budget-process-ms=12 --view=window` passing on a mid-range PC.
   Simulation code, so each step is its own small PR with the harness numbers.
2. **One material and one atlas per model.** Cuts the colour and shadow draw calls of the
   legacy models three to ten times (hauler 13 to 2, vehicle_factory 22 to 2). Evidence:
   the surface counts above and the 30 draw calls per fighting unit. What it takes:
   nothing new, this is what the textured pipeline already produces; the "bake, do not
   decimate" pass in direction item 10 delivers it as each unit goes through, worst first
   (hauler, trade_truck, constructor, the three factories). Proof per unit: the ArtGallery
   and UnitModelCompare shots, tri count and UnitModelBench, as docs/art-direction.md
   already asks.
3. **Shadow pass budget.** The shadow pass doubles primitives. What it takes: a shadow
   distance on the sun (`directional_shadow_max_distance`, set only in the map editor
   today, source/map-editor/MapEditor.gd:498) matched to the far zoom, and
   `cast_shadow = OFF` on the small scatter kinds (grass tufts, reeds, bushes) that draw
   through MultiMesh. Data and scene settings, one PR. Proof: primitives per frame in
   the stress run at the same camera, before and after, and a LookShots pair to show the
   shadows still read.

Not on the list: instancing structures (dozens, not thousands), outlines or toon passes
(a fourth style), and texture size cuts (the GPU is not the bottleneck; the web build is
the only place texture size matters, docs/decisions.md 2026-10-17).
