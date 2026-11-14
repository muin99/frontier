extends Node3D
## Surface dangers that keep an EVA tense: meteor showers and marsquakes.
## Mars does receive small impactors and InSight recorded marsquakes; the timing,
## frequency and damage here are compressed game models, not forecasts.
const Gfx = preload("res://scripts/gfx.gd")
const BLAST := 7.5
var game: Node
var enabled := true
var clock := 0.0
var next_event := 110.0
var events := 0
var shower_left := 0
var shower_timer := 0.0
var pending: Array[Dictionary] = []
var fragments: Array[Dictionary] = []
var quake := 0.0
var warning := ""
var rng := RandomNumberGenerator.new()
var survived := 0
var hits := 0
var siren: AudioStreamPlayer

func setup(game_node: Node) -> void:
	game = game_node
	siren = AudioStreamPlayer.new(); siren.volume_db = -16; add_child(siren)

func reset(seed_number: int) -> void:
	rng.seed = seed_number * 31 + 7
	clock = 0.0; next_event = rng.randf_range(95.0, 130.0); events = 0
	shower_left = 0; quake = 0.0; warning = ""; survived = 0; hits = 0
	for entry: Dictionary in pending:
		for key: String in ["marker", "rock"]:
			if is_instance_valid(entry[key]): entry[key].queue_free()
	pending.clear()
	for entry: Dictionary in fragments:
		if is_instance_valid(entry.node): entry.node.queue_free()
	fragments.clear()

func active() -> bool:
	return shower_left > 0 or not pending.is_empty() or quake > 0.0

## Ground point below a local position, found on whatever terrain collision is loaded.
func ground(at: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 60, at - Vector3.UP * 80)
	if is_instance_valid(game.player): query.exclude = [game.player.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	return hit.position if not hit.is_empty() else at

func tick(delta: float, sheltered: bool) -> void:
	if not enabled: return
	clock += delta
	if clock >= next_event and not active():
		events += 1
		next_event = clock + rng.randf_range(85.0, 150.0)
		if events % 2 == 1: start_shower(rng.randi_range(6, 9))
		else: start_quake()
	if shower_left > 0:
		shower_timer -= delta
		if shower_timer <= 0:
			shower_timer = rng.randf_range(0.7, 1.5)
			# Later rocks walk in toward the crew; every one is telegraphed on the ground first.
			var spread := lerpf(9.0, 30.0, float(shower_left) / 9.0)
			var angle := rng.randf() * TAU
			var offset := Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(spread * 0.35, spread)
			var lead: Vector3 = game.player.velocity * 1.6
			lead.y = 0
			schedule(game.player.position + offset + lead, 2.7)
			shower_left -= 1
	for i: int in range(pending.size() - 1, -1, -1):
		var entry: Dictionary = pending[i]
		entry.t -= delta
		var progress := clampf(1.0 - float(entry.t) / float(entry.total), 0, 1)
		var rock: Node3D = entry.rock
		var marker: Node3D = entry.marker
		rock.position = entry.from.lerp(entry.p, progress)
		marker.scale = Vector3.ONE * lerpf(1.25, 0.55, progress)
		marker.rotation.y += delta * 3.0
		if float(entry.t) <= 0:
			pending.remove_at(i)
			impact(entry, sheltered)
	if quake > 0:
		quake -= delta
		game.player.shake(delta * 2.2)
		if quake <= 0: game.toast("MARSQUAKE OVER  /  +4 science\nYour suit accelerometers logged the event for the seismology team.")
	if shower_left <= 0 and pending.is_empty() and warning.begins_with("METEOR"):
		warning = ""
		survived += 1
		game.toast("SHOWER PASSED\nGlowing fragments mark fresh impacts. Walk over one to collect it for science.")
	elif quake <= 0 and warning.begins_with("MARSQUAKE"): warning = ""
	for i: int in range(fragments.size() - 1, -1, -1):
		var piece: Dictionary = fragments[i]
		var node: Node3D = piece.node
		piece.life -= delta
		node.rotation.y += delta * 1.4
		if node.global_position.distance_to(game.player.global_position) < 2.4:
			game.model.science += 6
			if is_instance_valid(game.stream): game.stream.salvage += 1
			game.toast("METEORITE FRAGMENT RECOVERED  /  +6 science, +1 spare\nA fresh fall has not been weathered: valuable context for the sample team.")
			game.tone(990, 0.18)
			node.queue_free(); fragments.remove_at(i)
		elif float(piece.life) <= 0:
			node.queue_free(); fragments.remove_at(i)

func start_shower(count: int) -> void:
	shower_left = count; shower_timer = 1.6
	warning = "METEOR SHOWER  /  watch the red rings, keep moving or reach shelter"
	game.toast("METEOR SHOWER INBOUND\nRed rings mark impact points. Move clear or shelter at a habitat.")
	alarm()

func start_quake() -> void:
	quake = 6.5
	warning = "MARSQUAKE  /  hold your footing"
	game.model.science += 4
	game.toast("MARSQUAKE\nThe ground is moving. Loose slopes are dangerous: stay on level terrain.")
	alarm()

func alarm() -> void:
	if DisplayServer.get_name() == "headless": return
	siren.stream = Gfx.tone_stream(330, 0.9, 0.3); siren.play()

func schedule(target: Vector3, delay: float) -> void:
	var at := ground(target)
	var marker := Node3D.new(); add_child(marker); marker.position = at + Vector3.UP * 0.15
	var ring := MeshInstance3D.new(); var torus := TorusMesh.new(); torus.inner_radius = BLAST - 0.3; torus.outer_radius = BLAST; torus.rings = 48
	ring.mesh = torus; ring.material_override = Gfx.emissive(Color("ff4a3a"), 2.2); ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; marker.add_child(ring)
	var inner := MeshInstance3D.new(); var core := TorusMesh.new(); core.inner_radius = 0.7; core.outer_radius = 0.95
	inner.mesh = core; inner.material_override = Gfx.emissive(Color("ffb347"), 2.6); inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; marker.add_child(inner)
	var rock := Node3D.new(); add_child(rock)
	var body := MeshInstance3D.new(); var ball := SphereMesh.new(); ball.radius = 0.55; ball.height = 1.1; ball.radial_segments = 10; ball.rings = 5
	body.mesh = ball; body.material_override = Gfx.emissive(Color("ffa24a"), 3.5); rock.add_child(body)
	var trail: CPUParticles3D = Gfx.emitter({"amount": 60, "life": 0.9, "speed": Vector2(0.2, 1.0), "size": Vector2(0.9, 1.8), "spread": 180.0, "colors": [Color(1, 0.9, 0.6, 0.9), Color(1, 0.45, 0.12, 0.6), Color(0.3, 0.25, 0.25, 0.0)], "additive": true, "grow": Vector2(1.0, 0.2)})
	rock.add_child(trail)
	var glow := OmniLight3D.new(); glow.light_color = Color("ff9a4a"); glow.omni_range = 26; glow.light_energy = 4.0; glow.shadow_enabled = false; rock.add_child(glow)
	var from := at + Vector3(rng.randf_range(-60, 60), 150, rng.randf_range(-60, 60))
	rock.position = from
	pending.append({"p": at, "from": from, "t": delay, "total": delay, "marker": marker, "rock": rock})

## Damage a body at `distance` metres from the strike takes before shelter is considered.
static func damage_at(distance: float) -> float:
	return 0.0 if distance >= BLAST else lerpf(20.0, 5.0, distance / BLAST)

func impact(entry: Dictionary, sheltered: bool) -> void:
	var at: Vector3 = entry.p
	if is_instance_valid(entry.marker): entry.marker.queue_free()
	if is_instance_valid(entry.rock): entry.rock.queue_free()
	var distance: float = game.player.position.distance_to(at)
	var burst: CPUParticles3D = Gfx.emitter({"amount": 70, "life": 2.2, "speed": Vector2(5, 17), "size": Vector2(1.2, 3.4), "dir": Vector3(0, 1, 0), "spread": 75.0, "gravity": Vector3(0, -3.71, 0), "damping": 2.0, "colors": [Color(1, 0.8, 0.45, 0.95), Color(0.75, 0.5, 0.36, 0.7), Color(0.55, 0.4, 0.32, 0.0)], "grow": Vector2(0.5, 2.4), "one_shot": true, "explosive": 0.92})
	add_child(burst); burst.position = at + Vector3.UP * 0.4
	var flash := OmniLight3D.new(); flash.light_color = Color("ffb060"); flash.omni_range = 40; flash.light_energy = 12; flash.shadow_enabled = false
	add_child(flash); flash.position = at + Vector3.UP * 2
	var fade := create_tween(); fade.tween_property(flash, "light_energy", 0.0, 0.7); fade.tween_callback(flash.queue_free)
	get_tree().create_timer(3.0).timeout.connect(burst.queue_free)
	game.player.shake(clampf(1.1 - distance / 45.0, 0.12, 1.0))
	game.tone(90, 0.45)
	var harm := damage_at(distance)
	if harm > 0 and not sheltered:
		if game.driving: harm *= 0.5
		hits += 1
		game.model.integrity = maxf(0, game.model.integrity - harm)
		game.model.log.append("Meteor strike %.0f m away: −%.0f%% suit integrity" % [distance, harm])
		game.toast("IMPACT  /  −%d%% suit integrity\nDebris struck your suit. Get clear of the red rings." % int(harm))
	# The fall leaves a collectable fragment in a scorched crater.
	var piece := Node3D.new(); add_child(piece); piece.position = at + Vector3.UP * 0.35
	var stone := MeshInstance3D.new(); var shard := SphereMesh.new(); shard.radius = 0.32; shard.height = 0.5; shard.radial_segments = 7; shard.rings = 4
	stone.mesh = shard; stone.material_override = Gfx.emissive(Color("ff8a3a"), 1.6); piece.add_child(stone)
	var scorch := MeshInstance3D.new(); var disc := CylinderMesh.new(); disc.top_radius = 2.6; disc.bottom_radius = 3.0; disc.height = 0.08
	scorch.mesh = disc; scorch.material_override = Gfx.surface(Color("2b1d18"), 0.0, 1.0); scorch.position.y = -0.3; scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; piece.add_child(scorch)
	var beam := MeshInstance3D.new(); var column := CylinderMesh.new(); column.top_radius = 0.12; column.bottom_radius = 0.12; column.height = 9
	beam.mesh = column; beam.material_override = Gfx.hologram(Color("ffb347"), 0.35); beam.position.y = 4.5; beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; piece.add_child(beam)
	fragments.append({"node": piece, "life": 75.0})

## Shifts every live effect when the streamed world re-centres on the player.
func shift(offset: Vector3) -> void:
	for entry: Dictionary in pending:
		entry.p += offset; entry.from += offset
		entry.marker.position += offset; entry.rock.position += offset
	for piece: Dictionary in fragments: piece.node.position += offset

func snapshot() -> Dictionary:
	return {"clock":clock,"next":maxf(clock+15,next_event),"events":events,"survived":survived,"hits":hits,"rng_state":str(rng.state)}

func restore(data: Dictionary) -> void:
	clock = maxf(0,float(data.get("clock",0))); next_event = maxf(clock+15,float(data.get("next",110)))
	events = maxi(0,int(data.get("events",0))); survived = maxi(0,int(data.get("survived",0))); hits = maxi(0,int(data.get("hits",0)))
	var state_text := str(data.get("rng_state",""))
	if state_text.is_valid_int(): rng.state = state_text.to_int()
