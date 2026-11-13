# Field hardware art direction

Original authored procedural meshes in `field_hardware.gd`, batched by material.
No generated bitmap or unverified downloaded model is used for the new equipment.

Godot 4.7, 3D, metre scale, third/first-person camera, Windows GL Compatibility.
Pivot at ground contact; initial model dimensions roughly 0.5–6 m. Collision uses
simple instrument bodies and actual walkway/ramp meshes. Main unit meshes have
roughly eight possible material surfaces; unused surfaces are omitted and identical
unit meshes share the cache. Resource prop visibility is limited to 150 m.

Silhouette families: twin winged solar sails, segmented battery stacks, radiator
generator cores, paired oxygen vessels, auger towers, arched pressure-shell cabins,
ribbed growth capsules, open gantry fabricators, parabolic antennas and split-fan
survey drones. Do not replace them with a primitive blockout.

Manufactured edge treatment uses four bevel bands and octagonal housing corners.
Curved vessels and dish profiles use sampled lathe meshes. Telescoping braces,
hinge collars, vents, segmented solar cells, protected displays, seams and cable
connections provide detail at gameplay distance. Palette: ceramic silver,
graphite, brushed blue-grey metal, restrained teal indicators and amber safety
strips. Material roughness and metalness separate housings from solar/glazed faces.

Assembly state is translucent; commissioned state is solid. World readouts expose
power/recipe/link failures. Procurement shows the actual shared 3D asset, not a
concept illustration. Review through the `hardware-*` and `outpost` capture modes.
