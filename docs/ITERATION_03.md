# Iteration 3 — Mission flow and liftoff

This iteration connects the spaceport systems into a complete playable pre-launch story.

## Player flow

1. Accept the four-crew, 500-day Mars surface mission briefing.
2. Procure components manually or use the recommended baseline loadout.
3. Wait for visible ground-crew deliveries and inspect the integrated manifest.
4. Complete three contextual engineering calculations in the NASA Flight Lab.
5. Clear the combined hardware, calculation, briefing, and logistics authorization gate.
6. Start terminal count and watch Frontier 01 ignite and clear the tower.

The HUD shows the current phase throughout the flow. Wrong calculation answers produce unit or method hints without consuming money. Every calculation includes an in-game link and clearly distinguishes a NASA-published value from a fictional scenario input.

## Equations and evidence

- **Propulsion:** `MR = exp(Δv / (Isp × g₀))`, based on NASA Glenn's ideal rocket equation. The 3,600 m/s burn is a gameplay scenario; 350 s is NASA Glenn's liquid hydrogen/liquid oxygen example value.
- **Human systems:** `energy = crew × days × 3,035 kcal`, using NASA-STD-3001's average per-crewmember daily provision and the DRA-inspired 500-day surface stay.
- **Operations:** `one-way = round-trip / 2`, using NASA communication-delay research's maximum-distance example of up to 44 minutes round trip. Actual latency varies with geometry.

## Camera and launch presentation

`V` switches instantly between collision-aware third-person view and eye-height first-person view. The terminal count provides milestone callouts at T−10, T−5, T−3, T−2 and T−1. At zero, emissive engine plumes and pad light appear and the launch stack accelerates vertically.

## Verification

The automated smoke test rejects a wrong equation answer, accepts all three correct values, verifies an incomplete mission cannot launch, clears simulated deliveries, completes authorization, advances the countdown to physical liftoff, toggles both camera modes, and repeats navigation and collision checks.
