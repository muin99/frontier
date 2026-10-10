# Science Model and Equation Guide

## Modeling principle

This is an educational simulation, not flight software. Each model must declare assumptions, range of validity, units, and whether it is observed, derived, referenced, or invented for gameplay.

## Calculation moments for the MVP

### 1. Propellant and payload trade-off

Use the ideal rocket equation as a teaching relationship:

`delta_v = Isp * g0 * ln(m0 / mf)`

The player rearranges it to estimate required mass ratio:

`m0 / mf = exp(delta_v / (Isp * g0))`

Where delta-v is in m/s, specific impulse is in seconds, standard gravity is 9.80665 m/s², and masses share the same unit. The game must explain that real mission design also includes staging, gravity/drag losses, reserves, finite burns, trajectory, and vehicle constraints.

Gameplay consequence: adding an instrument increases delivered science capability but reduces margin or forces a more capable launch/propulsion option.

### 2. Surface power balance

For each time step:

`net_energy = generated_energy - habitat_load - instrument_load - mobility_load`

`battery_next = clamp(battery_now + net_energy * efficiencies, 0, capacity)`

Solar generation is modified by local time, panel area/efficiency, incidence approximation, and an explicit dust factor. The MVP should use a designed scenario informed by NASA references rather than pretend one station's weather is a global forecast.

Gameplay consequence: run the drill now, defer science, clean panels, shed habitat loads, or preserve reserve for night.

### 3. Consumables and recycling

For resource `r` over a step:

`stock_next = stock_now - crew * demand_rate * dt + recovered_fraction - losses`

Recovered water/oxygen should never exceed physically available input, and efficiencies stay between zero and one. Rates require a cited human-systems reference before finalization.

Gameplay consequence: high-closure hardware costs mass, money, power, and maintenance but reduces resupply/initial consumables.

## Additional models after MVP

- **Terrain:** slope from neighboring elevation cells; traversal cost from slope, roughness, load, and mode.
- **Communications:** free-space path loss, antenna gain, transmitter power, data rate, and Earth–Mars light time.
- **Thermal:** simplified heat capacity and habitat heat-loss/load model.
- **Radiation:** scenario dose rate × exposure time with shielding response and explicit uncertainty.
- **Launch window:** SPICE-derived geometry and transfer opportunity scoring rather than a fixed calendar fact.
- **EDL:** risk proxy from elevation, slope, landing ellipse, atmosphere scenario, vehicle limits, and mass.

## Equation interaction design

- Put equations inside real decisions, never as disconnected school tests.
- Let the player inspect definitions, units, and a worked example in the mission handbook.
- Accept dimensionally equivalent units and show conversions.
- Give a reasoned hint after an error and allow recovery.
- Offer **guided**, **standard**, and **expert** modes. Guided fills some terms; expert exposes margins and assumptions.
- Score reasoning and mission consequences, not typing speed.

## Validation plan

- Unit tests for nominal, zero, boundary, impossible, and unit-conversion cases.
- Golden scenarios calculated independently in a spreadsheet or notebook during the event.
- Dimensional-analysis review by the science/engineering teammate.
- Sensitivity tests: increasing mass cannot mysteriously improve propellant margin; increasing load cannot improve battery reserve.
- Expert review, if available, with every disputed value logged rather than silently changed.

