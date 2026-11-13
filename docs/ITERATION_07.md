# Frontier 7 — build a chain of Mars outposts

Run `build/windows-v7/Mohashunnyo.exe` with its neighbouring `.pck`, or `Play.cmd`.
Version 6 and its saves remain available. Version 7 writes `expedition_v7.json`
and can import a version 6 checkpoint. Existing worlds begin with no deployed
version 7 structures; the main habitat workshop can fabricate basic equipment.

## The new loop

Purchase field kits in Mission Control → carry limited cargo → place and assemble
hardware → connect a power grid → recover materials → fabricate more modules →
build life support and scientific stations farther from base → earn exploration,
research and engineering-contract points. The original expedition and its twelve
activity families remain playable, alongside this longer construction progression.

The original 1,536 m survey is still surrounded by the version 6 streamed world.
There is no designed arena edge. Numerical precision, save size and hardware still
impose practical limits; this is a fictional procedural Mars extension.

## Procurement and first deployment

Use Mission Control / Field Systems on the title or planning screen. A physical
FIELD SYSTEMS PROCUREMENT terminal also sits in the Mission Control room, beside
the NASA archive. The Earth outfitter links to the same catalog. Purchases persist
in `outpost_procurement_v7.json` and transfer into the next launched expedition.
Editing this preflight draft does not alter active deployed hardware or cargo.

Field procurement has its own 600-credit budget and 260 kg payload limit, separate
from the older spacecraft architecture budget. The recommended 580-credit pack
contains two solar arrays, a battery, oxygen processor, shelter, fabricator,
communications relay, weather station and ice extractor. It weighs about 227 kg
with starter materials and consumables. Inspect each actual 3D model before buying.

After touchdown, build the two solar arrays, battery, oxygen processor, shelter and
fabricator within 20 m of one another. B opens packed kits; select one to position
a hologram seven metres ahead. Position snaps to one metre; Q rotates by 15°.
Left-click or Enter places it. Right-click or Escape cancels. Green/red previews
show valid/invalid footprints. Placement rejects excessive slope, overlapping
structures, blocked evidence/activity/resource access, and positions outside
3–10 m of the astronaut. A sector accepts up to 24 modules; expand into new sectors.

Approach a frame and hold E for each of three two-second steps: anchor, connect,
calibrate. Release and hold again between steps. Uncommissioned equipment remains
a translucent frame and cannot produce resources or power. E on commissioned
equipment shows state, integrity, stored resources and its power/data connection.
Repacking preserves the kit but discharges production reservoirs and stored energy.

## Equipment catalog

| Family | Equipment | Actual gameplay role |
|---|---|---|
| Power | HELIOS solar array | 8 power units, scaled by the weather's solar fraction |
| Power | VAULT battery | Stores up to 100 energy; supplies up to 5 power during deficits |
| Power | EMBER concept generator | Reliable 16-unit source; expensive tier 3 fabrication |
| Power | NEXUS coupler | Extends connection reach from 20 m to 38 m |
| Survival | AERIS oxygen processor | Consumes stored water; fills an oxygen reservoir |
| Survival | BOREAL ice extractor | Extracts beside an ice deposit or processes recovered raw ice |
| Survival | HAVEN shelter | Powered suit charging, exposure protection, oxygen service from a connected processor |
| Survival | VERDANT growth capsule | Converts water and power into rations |
| Industry | FORGE fabricator | Enables field crafting and tier 2 technology |
| Industry | CRUCIBLE refinery | Converts two regolith into one alloy under power |
| Industry | ATLAS cargo vault | Adds 100 kg team cargo capacity when assembled |
| Science | HORIZON relay | Links to base within 260 m, or another connected relay within 360 m |
| Science | TEMPEST weather array | One powered/downlinked research package per sector |
| Science | ECHO seismic anchor | Three powered/linked anchors, separated 20–150 m, form an array |
| Science | PRISM mineral laboratory | Linked research; unlocks tier 3 after three sectors have been explored |
| Science | ORION observatory | Research requires a data link and clear/high-cloud weather |
| Exploration | SCOUT drone dock | Visible 45-second mapping sorties reveal nearby resource markers |
| Exploration | WAYFINDER pylon | Lit, persistent navigation/map landmark |
| Construction | SPAN walkway | Six-metre collision deck for shallow gaps |
| Construction | ASCENT ramp | Inclined four-metre collision deck for access |

All hardware is original speculative game equipment. Capacities, production,
dimensions, prices, recipes, timings and compressed needs are gameplay balances.
No module is represented as flight-certified NASA hardware or a real mission design.

## Survival, industry and placement strategy

Assembled modules form connected components through short-range cables. Power is
allocated to oxygen and shelter before lower-priority industry. Batteries store
surplus and discharge under deficits; empty batteries cannot supply free energy.
They deploy empty, so repacking does not create charged batteries. Dust reduces
solar supply; a buffer or an additional source can preserve life support.

AERIS needs water. BOREAL requires a nearby finite ice deposit in a generated cold
district, or raw ice recovered with G. CRUCIBLE consumes regolith, and VERDANT
consumes water. Production pauses if prerequisites or cargo space are unavailable.
An unpowered shelter does not provide sustained suit support. Powered shelters
draw oxygen from a processor in the same grid. Multiple crew members share those
reservoirs. Modules suffer gradual severe-dust wear and can be repaired with alloy.

Food and hydration decline gradually during active play; reaching zero causes
integrity attrition. C opens cargo to eat/drink. Life-support rates are compressed
balances, not real astronaut metabolic requirements. The main base and six starter
refuges retain their original safe support. Outer generated pods now contain one
finite emergency reserve per sector rather than unlimited free recharging.

Each sector has deterministic recoverable resource sites. Basalt analogs provide
hard-rock alloy; other ground supplies regolith. Fictional salvage caches provide
circuits and polymer, and cold districts have raw ice. Deposits deplete persistently;
exploring new sectors supplies new material. G recovers a small batch with a tool
cooldown. Hard-rock recovery needs a drill architecture. These are simulated
resource distributions, not NASA mineral detections or discovered infrastructure.

C also opens recipes. Inputs and capacity are validated before anything is consumed.
The base workshop can fabricate basic equipment; field crafting needs an online
FORGE within 7 m. Commissioning FORGE unlocks tier 2. A successful PRISM package
after three explored sectors unlocks tier 3. Research and contracts return additional
fabrication material, supporting a repeatable expansion loop. Shared cargo is a
logistics abstraction; physical crate transport and voxel excavation are not modeled.

## Research, missions and scoring

Each newly explored sector awards 8 science once. A powered, connected instrument
records for 45 seconds and awards 36 science once per instrument family/sector.
Moving a station into a new sector enables new research; repacking and replacing
it in the same sector cannot farm its reward. Remote stations need local power
and a functioning relay chain. Observatory work depends on sky conditions.

Eight engineering contracts cover power commissioning, life support, industry,
water production, three-sector weather research, a seismic array, a distant shelter
and observatory work. Each pays 65 science plus alloy/circuits once. J links to
the contract board. Existing evidence, interpretations, traversal activities and
safe-return bonuses remain. The previous 1,000-point report cap is removed.

NASA MOLA and MEDA data remain the regional/scenario context described in MARS_DATA
and WEATHER_DATA. New station placement, resources, outputs and research rewards
are invented gameplay. Archived MEDA profiles are not new measurements made by
the placed instruments, and this economy is not a closed physical/chemical model.

## Multiplayer and persistence

LAN co-op remains a four-player listen server on UDP 24642. Protocol version 7
requires matching builds. The host owns shared kits, materials, installations,
production and exploration/research awards. Clients request placements/crafting;
the host validates position, inventory, capacity, recipes and assembly time.
Instant assembly requests are rejected. Late joining/reconnecting restores deployed
hardware and completed assembly. Food/hydration and suit reserves remain personal.
Client oxygen service and finite-pod claims are allocated by the host.

Production and the shared weather clock continue while the host uses a console.
Each player streams their surroundings independently. Far installation visuals
unload beyond 900 m; records and simulation persist. Structures reappear when
returning, at positions corrected for origin shifts. Save data stores kits,
resources, stages, integrity, battery/oxygen reservoirs, research, depletion,
explored sectors, contracts and needs. A canceled/in-progress hand interaction
must be resumed after loading. No external server or account service was added.

## Verification and limits

The source regression suite checks the original expedition, five Earth terminals,
launch handoff, nine-seed terrain/weather generation, controller routes through
the six starter districts, streamed collision/far travel and the platform course.
The outpost check covers all 20 authored models, procurement budget/mass, disk
ledger roundtrip, atomic failed purchases/recipes, placement rejection, assembly,
connected/disconnected life support, battery exhaustion, technology gates,
research deduplication, finite material recovery, deposit-dependent and recovered
ice processing, malformed save records, uncapped exploration scoring and menus.

Independent host/client processes check shared placement, rejection of instant
assembly, three timed assembly stages, reconnect restoration and the retained
evidence/activity validation. Source and exported release checks use the same
in-game test entry points. Physical two-PC router/firewall behavior remains untested.

GPU captures inspect the solar/oxygen/fabricator/observatory purchasing previews
and a deployed outpost on Mars. Short 1280×720 captures on the RTX 3050 laptop
generally measured around 130–140 FPS. These are not long-session or four-player
performance guarantees. This is modular infrastructure building, with a fixed
authored equipment family and reusable missions; arbitrary voxel excavation,
freeform hull design, terrain deformation and real industrial chemistry are outside
the implemented simulation.
