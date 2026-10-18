# Game direction

Read this before docs/art-direction.md and docs/feel.md. It says what Ironbound is, how
we judge a change, what stays, what goes, and in which order the work happens. It is the
ruler; docs/decisions.md is the log of what was measured and why.

## The one sentence

Ironbound is a 20 to 25 minute skirmish against an AI that escalates and finishes: build a
base in the first five minutes, hold and answer growing attack waves in the middle, then
break their base or be broken. The yardstick is Command & Conquer Generals: Zero Hour.

## What a match is

- **0:00 to 5:00, the opening.** Extractors, power, a factory, the first tanks. First
  contact (a raid on the trucks) around 4:30, the first attack wave around 6:00.
- **5:00 to 15:00, the middle.** A wave every three minutes, each bigger than the last.
  The player keeps an army at home, chooses what to build against what is coming, and
  pushes out to outposts and a second base.
- **15:00 to 25:00, the end.** The player breaks the AI's base, or the waves break the
  player's. The ending holds for a moment and shows what happened.
- The player makes one decision every 30 to 60 seconds that they can see pay off.

## The ruler

A change is worth making when it does at least one of these, and nothing else is cheaper:

1. It makes the arc above happen, sooner or more clearly.
2. It creates a decision the player can see and feel.
3. A new player reads it on screen without the manual.
4. It holds at 20 against 20 units at 60 fps on a mid-range PC.

A change that does none of the four is cut, however clever it is.

## Where we were on 18 October (measured, not guessed)

Probe matches, all headless on Desert Expanse, reports in the project folder under
game/direction/probes/:

- Nobody won. A helper-run player with a 24-unit army against a Normal balanced AI: no
  end in 30 minutes. A passive new player: no end in 25 minutes. The AI formed its two
  battlegroups once, lost most of them around minute 6, never built another battle unit,
  and sat on 1,700 iron. Fixed by PR #100: a beaten group dissolves, the next forms at
  once, waves grow.
- The player's army did nothing. Fifteen idle tanks stood at the rally point while raids
  took the mines 20 m away; idle units only answer what walks into their 10 m sight.
- The economy stalled at the start. Iron stuck at 10 all match, copper at 8: the only
  copper on Desert Expanse is 24 m out and never seen, the home deposits sit outside the
  command centre's power grid and run at half rate, and the helper keeps 10 of everything.
- Combat has no roles. Damage is flat, three tanks are the same tank at three prices,
  artillery cannot see what it can shoot, a bunker loses to three tanks and kills none.
- The Play screen logged 138 errors every time it opened and the crash prompt blamed the
  player on the next launch. Fixed by PR #99.

## Keep, and finish

- The hauling economy with trucks as the visible lever, tiers, the city centre as the win
  condition, outposts and crates as reasons to leave the base.
- The helper (it is how a new player survives their first match), the tutorial, the play
  harness and the data-first pipeline (data/*.json plus tools/validate_data.gd).
- The textured model pipeline at the tank's quality, the Grounded look, weather and the day
  cycle as a backdrop.

## Cut or mute until the loop is proven

Each cut is its own small PR with the reason in docs/decisions.md; nothing is deleted on
a hunch.

- Trade offer popups to the human, treaties in a two-player match, the ultimatum.
- The 45-minute score ending as the default and the depletion ending.
- Truck oil upkeep, surplus-truck recycling, storage yards and conveyors, the rail road
  level, trade hoarding and margin knobs per personality.
- The classic-model option with its 16 GLBs, the classic and stylised looks.
- F1 opening the diagnostic overlay together with the manual.

## Order of work

One concern per PR, main stays releasable, every PR carries its evidence.

1. Done, #99: the Play menu error storm.
2. Done, #100: the AI refills and grows its waves, so matches end.
3. Done, #103 and #105: the idle army defends the base: units within reach answer a hit
   on our structures or units, instead of standing at the rally point.
4. Partly done, #102: Economy pace: copper reachable from the start and home extractors
   inside the grid (done), helper reserves that build an army (open). Target: a tank every
   20 to 30 s by minute 5. Found while proving 3: in three of four helper-run matches the
   helper never got a vehicle factory up and had no army when the raider came; the helper
   must build one early, every time.
5. Done, #111: armour and weapon classes (one multiply in Unit.take_damage plus data),
   structures that hold a few tanks, artillery that sees what it shoots. Units get roles:
   the class line on every card is the first half; the one-word role label on the card is
   the follow-up.
6. Difficulty retune in data once 3 to 5 are in: Easy for the first match, Normal for the
   20-minute skirmish above, Hard and Brutal that hit harder, not just fatter.
7. Done, #109: the ending: a hold with the camera on the last structure, kills and losses,
   Continue.
8. In progress, slice 1 of 5 done (#110, health bars by thirds with Alt and an option). The HUD: one bottom bar (minimap, selection with counts and health, icon command card),
   an under-attack banner with a jump key, health bars that can stay on.
9. Done (PR #108): CI runs the smoke harness and the validator, not only the formatter.
10. Art: every unit through the one textured pipeline at the tank's quality (bake, do not
    decimate), one explosion look, wrecks that keep their texture, recorded sound.
11. Dead branches, dead scenes and the second explosion system go.

## Numbers we aim at

Normal difficulty, 1v1 on Desert Expanse, measured with the probe scenarios:

| What | Target |
| --- | --- |
| First contact | 4:00 to 5:00 |
| First attack wave | about 6:00, then every 3 minutes, growing |
| Player tank cadence by minute 5 | one every 20 to 30 s |
| Player army by minute 8 | 12 or more |
| Passive player eliminated | 8 to 10 minutes |
| Competent player wins or loses | 15 to 25 minutes by conquest |
| Frame time at 20 vs 20 | 16 ms on a mid-range GPU |

## What we do not touch without Destin

Pathing and the navmesh, the save format, the exports, the test suite. Simulation and AI
numbers are in scope: on 18 October Destin asked for control of the game and its direction,
and the economy and combat numbers are the game.
