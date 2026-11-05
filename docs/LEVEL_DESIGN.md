# Authored level design

100 explicit stage compositions across ten worlds, authored on 2026-11-03. The JSON files are
runtime content, not sample or procedurally renamed placeholders. The compact authoring source
was a hand-written list of every stage, altitude gap, speed, phase, offset, switch target and
checkpoint. Serialization expanded those choices without generating level permutations.

## Route model and solvability contract

The player starts on a safe perch and may wait for any gate phase. Each matched contact opens the
stage; chains need a second contact 54 units beyond the first. The matching portion cycles through
all four identities. Launch timing and repeated taps are the controls. Reverse fields mirror the
route and gravity; their exit arrow must be visible before entry. A switch changes color after its
matching crossing, so the following stage is read using the new color. Checkpoints every two or
three stages bound retry cost. Pulse duty decreases from 0.42 to 0.32 over the campaign; matching
and open time must overlap in the runtime sampler. A runtime search must verify actual crossing
windows for all 100 routes; structural validation alone is not a solvability claim.

Stage labels: ring = rotating quarter arcs; slide = lateral color band; pendulum = easing band;
pulse = timed opening plus matching color; switch = matching contact then color change;
reverse = descending gravity field; chain = two contacts with sustained lift.

## Progression and authored intent

| World | Intent |
|---|---|
| 1 First Light | Only rings and slides; introduce altitude and wait-before-tap. |
| 2 Tidal Circuit | Add pendulum easing and changing periods. |
| 3 Prism Orchard | Add post-contact color switching, including all four identities. |
| 4 Pulse Foundry | Add timed windows and visual rhythm independent of audio. |
| 5 Glass Relay | Introduce two-contact chains, then place them after switches/pulses. |
| 6 Inverse Sky | Introduce descending gravity fields with clear exit directions. |
| 7 Ember Archive | Reorder learned mechanics into four-to-seven-stage phrases. |
| 8 Ion Cathedral | Denser chains, longer phrases, contrasting short and long reaches. |
| 9 Velvet Paradox | Timing contrasts and switches inside gravity-led routes. |
| 10 White Horizon | Full synthesis, with level 98 visiting every mechanic once. |

Each row below records a distinct route, not a visual reskin. Numerical timing and gap choices
are authoritative in `data/worlds/*.json`. The chapter finale increases the length and combines
that chapter's mechanics; it does not simply multiply movement speed.

| Level | Name | Stage sequence | Route intent |
|---|---|---|---|
| 001 | A Small Beginning | ring ? ring ? ring | Find your color before the first lift. |
| 002 | Sideways Signal | slide ? ring ? slide | Sliding bands teach a different rhythm. |
| 003 | Three Quiet Orbits | ring ? ring ? ring | Three rotations, three deliberate launches. |
| 004 | The Long Step | ring ? slide ? ring | A higher reach rewards a second tap. |
| 005 | Counterweight | ring ? slide ? ring ? slide | Read a slide between two calm rings. |
| 006 | Signal Ladder | slide ? slide ? ring ? ring | Keep your pace while the distances change. |
| 007 | Twilight Crossing | ring ? slide ? ring ? slide | Alternate observation with quick lifts. |
| 008 | Slow Before Fast | slide ? ring ? slide ? ring | A slow opening makes a quick finish readable. |
| 009 | Aperture Study | ring ? slide ? ring ? slide ? ring | Five contacts form a measured ascent. |
| 010 | First Light Finale | slide ? ring ? slide ? ring ? slide | Combine long reaches and shifting bands. |
| 011 | The First Sway | pendulum ? ring ? pendulum | Wait for the pendulum to return to center. |
| 012 | Ebb And Lift | pendulum ? slide ? pendulum | Short and long reaches follow opposite swings. |
| 013 | Harbor Bell | pendulum ? pendulum ? ring ? slide | Two sways set up a calm ring landing. |
| 014 | Undertow | slide ? pendulum ? slide ? pendulum | Sliding bands interrupt the swinging cadence. |
| 015 | Tidal Steps | pendulum ? ring ? pendulum ? ring | Build height between measured pendulum beats. |
| 016 | Twin Moons | ring ? pendulum ? pendulum ? slide | Back-to-back swings use different periods. |
| 017 | Slack Water | slide ? pendulum ? ring ? pendulum | The lowest speed marks a useful waiting point. |
| 018 | Deep Current | pendulum ? slide ? pendulum ? ring ? pendulum | Five different reaches resist automatic tapping. |
| 019 | Circuit Break | slide ? pendulum ? pendulum ? slide ? ring | Fast bands frame a slower double sway. |
| 020 | Tidal Circuit Finale | pendulum ? ring ? slide ? pendulum ? slide ? pendulum | Finish a six-contact harbor route. |
| 021 | A New Hue | switch ? ring ? slide | Match first; the switch changes your next color. |
| 022 | Petal Exchange | ring ? switch ? switch ? pendulum | Two switches teach consecutive color changes. |
| 023 | Lantern Walk | slide ? switch ? slide ? ring | A higher switch connects two moving bands. |
| 024 | Split Blossom | switch ? pendulum ? ring ? switch | Learn a new hue before a slow pendulum. |
| 025 | Violet Footbridge | pendulum ? switch ? slide ? ring | Long reach, color change, then compact gates. |
| 026 | Afterimage | switch ? slide ? switch ? pendulum ? ring | Remember the changed number, not the old hue. |
| 027 | Orchard Loop | switch ? pendulum ? pendulum ? slide ? switch | Switches bookend a swinging center section. |
| 028 | Lantern Rain | slide ? ring ? switch ? slide ? pendulum | A slow middle switch gives time to plan. |
| 029 | Fourfold Bloom | switch ? switch ? pendulum ? switch ? ring | Visit all four orb identities in order. |
| 030 | Prism Orchard Finale | pendulum ? switch ? slide ? switch ? ring ? switch | Six stages test reading after every switch. |
| 031 | Open On The Beat | pulse ? ring ? pulse | The pulse must be open and your color must match. |
| 032 | Brass Interval | pulse ? pendulum ? pulse ? slide | A pendulum separates two pulse periods. |
| 033 | Four Count | switch ? pulse ? ring ? pulse | A switch changes the target before a pulse. |
| 034 | Foundry Floor | pulse ? slide ? pulse ? pendulum | Close spacing asks you to stop and observe. |
| 035 | Hot Metal | ring ? pulse ? switch ? pulse | A long reach lands into a new color identity. |
| 036 | Clockwork Petals | pulse ? switch ? pulse ? switch ? pulse | Alternate pulses and color switches. |
| 037 | Silent Strike | pendulum ? pulse ? slide ? pulse ? ring | Watch the pulse rather than relying on sound. |
| 038 | Golden Measure | pulse ? ring ? pulse ? pendulum ? switch | Two long lifts share a slow pulse pattern. |
| 039 | Pressure Valve | slide ? pulse ? pendulum ? pulse ? switch | Quick movement between patient pulse waits. |
| 040 | Pulse Foundry Finale | pulse ? switch ? pendulum ? pulse ? slide ? pulse | Six mechanisms share one readable rhythm. |
| 041 | Two Clear Notes | chain ? ring ? slide | Keep lifting through both contacts of a chain. |
| 042 | Relay Baton | switch ? chain ? pendulum ? ring | A single chain follows a gentle color switch. |
| 043 | Glass Stair | chain ? slide ? chain ? ring | Short chain entries ask for a sustained lift. |
| 044 | Passing Light | pulse ? chain ? switch ? pendulum | Observe a pulse before the relay contact. |
| 045 | Double Refraction | chain ? ring ? chain ? slide | Two chains use different rotation periods. |
| 046 | Handoff Garden | switch ? chain ? pulse ? switch ? chain | The next chain reads your changed color. |
| 047 | Fragile Rhythm | chain ? pulse ? pendulum ? chain ? pulse | Pulse and chain windows reward waiting. |
| 048 | Relay Fork | chain ? slide ? chain ? ring ? chain | Three chain distances break a repeated cadence. |
| 049 | Clear Span | pendulum ? chain ? switch ? chain ? pulse | A long opening leads to compact relay work. |
| 050 | Glass Relay Finale | chain ? switch ? pulse ? chain ? pendulum ? chain | Six contacts combine color changes and chains. |
| 051 | Down Is Forward | reverse ? ring ? reverse | In the field, tap toward the lower exit. |
| 052 | A Sky Below | reverse ? slide ? pendulum ? ring | The field ends before the next rising band. |
| 053 | Inverted Bloom | switch ? reverse ? switch ? slide | A switch announces a new descending color. |
| 054 | Low Orbit | reverse ? ring ? reverse ? pendulum | Two descending fields bracket an upward ring. |
| 055 | Polarity Relay | reverse ? chain ? pulse ? reverse | Descending timing leads into a two-contact lift. |
| 056 | Turn The Compass | pendulum ? reverse ? switch ? chain ? reverse | Change color at the center of the route. |
| 057 | Falling Lantern | reverse ? pulse ? reverse ? switch ? pendulum | Long inverted reaches need renewed impulses. |
| 058 | North Of Nowhere | reverse ? chain ? reverse ? pulse ? slide | A chain marks the turning point between fields. |
| 059 | False Horizon | ring ? reverse ? switch ? reverse ? chain | Read the exit arrow after every checkpoint. |
| 060 | Inverse Sky Finale | reverse ? pulse ? chain ? switch ? reverse ? pendulum | Six stages test polarity without hidden input. |
| 061 | Cinder Index | switch ? pulse ? reverse ? pendulum | Switch into a pulse, then reverse the exit. |
| 062 | Borrowed Flame | chain ? pendulum ? chain ? switch | Two relays frame a compact pendulum. |
| 063 | Emberline | slide ? reverse ? slide ? pulse | A wide-reaching inverse stage separates quick bands. |
| 064 | Copper Page | switch ? reverse ? pendulum ? reverse ? ring | The changed identity persists through two fields. |
| 065 | Ash Pendulum | pendulum ? chain ? pendulum ? chain ? pulse | Long swinging lifts alternate with short relays. |
| 066 | Archive Key | pulse ? switch ? chain ? switch ? reverse | Two switches separate the route into color phrases. |
| 067 | Smoldering Shelf | pulse ? reverse ? chain ? pendulum ? pulse | Pulse, reverse and relay with patient landings. |
| 068 | A Note In Fire | pendulum ? ring ? reverse ? switch ? chain | The final color change precedes a longer relay. |
| 069 | Last Reading | chain ? pulse ? switch ? pendulum ? reverse ? slide | Six distinct heights resist a memorized tap loop. |
| 070 | Ember Archive Finale | switch ? chain ? reverse ? pulse ? pendulum ? switch ? chain | Seven mechanisms form the archive's full lesson. |
| 071 | Antechamber | chain ? slide ? pulse ? reverse | A slow relay opens into a faster upper section. |
| 072 | Ion Choir | pulse ? pulse ? switch ? pendulum ? chain | Pulse periods alternate without relying on audio. |
| 073 | Vaulted Ascent | pendulum ? chain ? reverse ? ring ? pulse | High swing, low relay, inverted middle. |
| 074 | Luminous Nave | pendulum ? switch ? chain ? switch ? reverse | Two switches reshape a pendulum-led route. |
| 075 | Crossing Wires | slide ? chain ? slide ? pulse ? chain | Moving bands interrupt both halves of a chain route. |
| 076 | Quiet Voltage | reverse ? pendulum ? pulse ? switch ? chain | A generous middle pulse offers a planning pause. |
| 077 | Cathedral Steps | chain ? switch ? chain ? reverse ? chain | Three relay spans use deliberately different heights. |
| 078 | Glass Canticle | pulse ? reverse ? pendulum ? pulse ? switch ? chain | Gravity flips between two pulse measurements. |
| 079 | Signal Spire | ring ? chain ? switch ? pulse ? pendulum ? reverse | Six measured lifts culminate in a reversed exit. |
| 080 | Ion Cathedral Finale | pulse ? chain ? reverse ? switch ? slide ? pendulum ? chain | A seven-stage phrase across all learned mechanics. |
| 081 | Soft Contradiction | reverse ? pulse ? switch ? chain ? pendulum | A gentle inverse opening leads to quick pulses. |
| 082 | Second Thought | switch ? switch ? chain ? reverse ? pulse | Switch twice before committing to the relay. |
| 083 | Velvet Descent | reverse ? chain ? pendulum ? reverse ? slide | Two inverted fields divide the long route. |
| 084 | The Other Beat | pulse ? chain ? pulse ? switch ? chain | Offset pulses alternate with broader relay windows. |
| 085 | Folded Distance | chain ? reverse ? pendulum ? slide ? pulse ? ring | Close and distant contacts require fresh lift timing. |
| 086 | Color Of Silence | switch ? pulse ? pendulum ? chain ? switch ? reverse | A switch at each end surrounds a timing study. |
| 087 | Paradox Pocket | reverse ? chain ? reverse ? pulse ? chain ? pendulum | Short reversed gates punctuate longer relay spans. |
| 088 | Twice Reflected | chain ? pulse ? chain ? pulse ? reverse ? switch | Repeat the mechanic, never the period or reach. |
| 089 | Unwritten Horizon | switch ? pendulum ? pulse ? chain ? switch ? reverse ? slide | Three color identities span seven different contacts. |
| 090 | Velvet Paradox Finale | reverse ? switch ? chain ? pulse ? pendulum ? reverse ? chain | Keep reading through the longest alternating phrase. |
| 091 | Beyond The Spectrum | chain ? switch ? reverse ? pulse ? pendulum ? slide | A measured chain opens the final world. |
| 092 | White Noise | pulse ? pendulum ? chain ? switch ? pulse ? reverse | Read visual pulse cues through a varied climb. |
| 093 | Spectrum Memory | switch ? reverse ? chain ? switch ? reverse ? pulse | Two switches and two fields demand fresh observations. |
| 094 | Horizon Relay | chain ? pendulum ? chain ? switch ? pulse ? chain | Three chain heights close a long color phrase. |
| 095 | Clearer Than Light | slide ? pulse ? reverse ? pendulum ? switch ? chain | The fastest bands bracket a deliberate inverted lift. |
| 096 | The Last Switch | pendulum ? chain ? pulse ? reverse ? switch ? slide ? ring | Seven stages make the final identity change matter. |
| 097 | No Fixed Rhythm | reverse ? pulse ? chain ? pendulum ? switch ? chain ? reverse | Each adjacent stage changes timing and distance. |
| 098 | A Hundred Dawns | ring ? slide ? pendulum ? switch ? pulse ? reverse ? chain | Seven lifts revisit every mechanic exactly once. |
| 099 | The Open Horizon | pulse ? chain ? switch ? reverse ? chain ? pulse ? pendulum | Patient pulse waits connect the hardest relay spans. |
| 100 | Chromatic Rush | switch ? chain ? reverse ? pulse ? pendulum ? switch ? chain | The final route asks for clarity, not a blind sprint. |

## Structural audit performed

Python 3.13 parsed all ten files and checked IDs exactly 1?100, ten levels per world, unique stage
signatures, three to seven stages, gap/speed/phase/color ranges, pulse width ranges and checkpoint
presence. Result: 100 distinct levels, 486 stages, seven mechanic kinds. Engine-level route search
and manual representative-world playtests are separate release gates recorded in [release verification](RELEASE.md#tests-and-runtime-verification).
