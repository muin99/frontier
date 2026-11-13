# NASA Space Apps 2026 — evidence and submission handoff

Update, 13 November 2026: the user supplied the full challenge brief in
`nasaguide.md`. The current implementation review and validation record are in
`RELEASE_REVIEW.md`; those supersede the historical feature limits below,
including the old score cap. Current rules and pre-event eligibility still
require an organizer decision. The retrieval history below records the earlier
build rather than the availability of the supplied brief.

Checked 4 November 2026, Asia/Dhaka. This is a development build made **before** the event. It is not a certified eligible submission. Do not conceal its development dates or present it as work created entirely during the hackathon.

## Verified from the official 2026 landing page

Source: https://www.spaceappschallenge.org/2026/

- Event dates: 14–15 November 2026; theme: The Next Frontier.
- Register individually, choose a Local Event or Universal Event, and join/form a team.
- Team size: no more than six participants.
- The official page lists submission opening 14 November at 09:00 and closing 15 November at 23:59 local time. Check your Local Lead's earlier presentation/judging deadlines.
- Submission is through the Project tab of the team's page. Registration and a submitted project are needed for Global Judging eligibility.

## Challenge alignment, with an explicit verification limit

Candidate official brief: https://www.spaceappschallenge.org/2026/challenges/space-mission-design-game/

The official challenge index lists 14 challenges. Direct retrieval of the full game challenge and current participant FAQ repeatedly failed (HTTP 502 from the browsing service; the direct Python attempt failed certificate validation). Certificate validation was not bypassed. Therefore this build does **not** claim that all detailed challenge requirements, resource mandates, AI disclosures, submission formats or judging criteria were verified.

The independent Space Data Atlas summary describes designing, managing and simulating a full mission with objectives, instruments, launch, budget, power, mass and communications. It is a useful cross-check, **not** an official requirements source: https://spacedata.swapniltamse.com/challenges/space-mission-design-game/

| Candidate requirement | Implemented evidence | Limit |
|---|---|---|
| Complete mission | Architecture → Earth departure → transit decision → Mars surface → ascent → return/debrief | Time/distance are compressed; no validated trajectory simulation |
| Engineering decisions | Three architectures with cost/mass margins, instruments, power, oxygen/battery capacities | Hardware and costs are gameplay assumptions |
| Limited resources | EVA oxygen/battery, integrity, scanning costs, recharge, one-use repair | Normalized resource units, not mission certification |
| Consequences | Instrument exclusions, dust/solar charging, transit integrity tradeoff, optional downlink | Weather and radiation event are authored scenarios |
| NASA data use | Real MOLA regional elevation crop drives terrain mesh/collision and site elevation readouts | Coarse regional grid; no local slope, mineral or life inference |
| Evaluate success | Safe return, science/integrity/reserve score, causal action log | Game scoring, capped at 200 |
| Explain evidence | Source ledger, observed/derived/fictional distinction, interpretation choices | Classroom learning efficacy still needs external evaluation |

## Pre-event work and eligibility

2026 event organizers explicitly say intended challenge solutions must begin during the event:

- Tel Aviv University Space Engineering Center: https://space.tau.ac.il/SpaceApps2026
- Cottbus event organizers: https://spacecottbus.com/

These are organizer sources, but they do not replace the current global rules or your own Local Lead's ruling. Before using this repository in a competition submission, disclose the prototype and its dates, ask which pre-existing assets/code are allowed, and obtain the organizer's decision. A newly dated branch does **not** erase pre-event development. If this work cannot be submitted, use it as a practice prototype and build the permitted event solution within the event rules.

## Team-owned actions still required

1. Read the complete official challenge and current global/local participation rules directly when accessible; reconcile every detail with this matrix.
2. Confirm eligibility of pre-event code, NASA data transformations, third-party assets and AI assistance; preserve the answer.
3. Register every member and select the correct shared event/team (maximum six).
4. Review final submission and judging guides when issued. Do not reuse a prior year's rubric as confirmed 2026 criteria.
5. Have students/teachers outside the development team test controls and explain two tradeoffs after playing; record observations and accessibility problems.
6. Prepare a concise project description, accurate NASA data references, playable download, source link and a short recorded demonstration in the formats actually requested by the official submission form.
7. Submit before the applicable deadline and verify that the team page shows the final project.

No award, eligibility result, external review or registration is guaranteed or completed by this build. No organizer was contacted and nothing was submitted or published.
