# Portable Navigation

Click-to-move for Roblox, with a settings window that treats a hundred and ninety
seven knobs as something to organise rather than something to dump on you.

Click the ground and the character walks there: over gaps, up ramps, around
things, across ledges that Roblox's own pathfinder refuses to join up.

## Load it

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/lowkeymyself/portable-navigation/main/PortableNavigationV2.lua"))()
```

Or drop `PortableNavigationV2.lua` into `StarterPlayer/StarterPlayerScripts` as a
LocalScript.

| Key | Does |
| --- | --- |
| `RightShift` | open the window |
| `RightAlt` | toggle navigation |
| `X` | cancel the current route |
| Click | walk there |
| Double click | walk there, sprinting |

## What is in it

**Trajectory emulation.** Rather than asking "is there ground somewhere ahead",
it runs a stand-in for the character forward under the game's own gravity, walk
speed and jump power, stepping at a fixed tick and sweeping for walls. It answers
the questions ground probes cannot: does walking off this edge land somewhere or
fall forever, would a jump from here clear the gap, and is jumping still optional
for another step. A jump is committed at the last tick from which it still lands,
not the first tick a gap becomes visible.

**Its own planner for when Roblox refuses.** PathfindingService reports NoPath
for plenty of geometry a player walks across without thinking. When it refuses,
the planner fans out from the current position using the same walkability test
the follower uses, and where there is no ground to probe at all it asks the
emulator where the body lands.

**Six movement drivers.** `Humanoid:Move` is the right default and plenty of
games break it, so there are also MoveTo, WalkToPoint, WASD emulation,
LinearVelocity, AssemblyVelocity and direct CFrame. Auto starts with the first
and escalates when the character is being commanded but not moving. Every one of
them follows the game's own WalkSpeed unless you tell it otherwise.

**Kill brick awareness** (off by default). Names and tags only catch what a
developer chose to label. Turned on, every character part reports what it
touches, and when health drops the parts touched a moment earlier are blamed,
generalised by shape so one death teaches the whole set, and remembered for next
session.

**A settings window with a Basic mode.** Everything is tunable and almost none of
it is in your face: Basic shows the forty odd controls anyone actually reaches
for, search always reaches past the filter, and descriptions are one toggle away.

## Configuration

Settings save per place, so a game you have tuned comes back tuned. Profiles live
in the executor's filesystem when there is one and in session memory when there
is not.

## Where it runs

A LocalScript in StarterPlayerScripts, or injected through an executor. WASD
emulation is the one feature that needs an executor: a plain LocalScript cannot
synthesise keyboard input at all.
