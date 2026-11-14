extends RefCounted
## Shared look for Earth and Mars: post-processing presets, turned (lathe) meshes,
## animated display shaders and soft-particle emitters. Everything is procedural.
const SETTINGS := "user://settings.cfg"
static var soft_sprite: GradientTexture2D
static var shader_cache: Dictionary = {}

static func release_cache() -> void:
	soft_sprite = null
	shader_cache.clear()

static func quality() -> int:
	var config := ConfigFile.new(); config.load(SETTINGS)
	return clampi(int(config.get_value("video","quality",1)),0,2)

static func store_quality(level: int) -> void:
	var config := ConfigFile.new(); config.load(SETTINGS)
	config.set_value("video","quality",clampi(level,0,2)); config.save(SETTINGS)

## Post-processing shared by every scene. Level 0 keeps only tonemap and glow.
static func grade(env: Environment,level: int,interior := false) -> void:
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.42; env.glow_strength = 0.9; env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.05; env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = level > 0
	env.ssao_radius = 1.4; env.ssao_intensity = 1.8; env.ssao_power = 1.4
	env.ssil_enabled = level > 1
	env.ssr_enabled = interior and level > 0
	env.ssr_max_steps = 40; env.ssr_fade_in = 0.2; env.ssr_fade_out = 2.5
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.07; env.adjustment_saturation = 1.1

static func viewport_quality(viewport: Viewport,level: int) -> void:
	viewport.msaa_3d = Viewport.MSAA_4X if level == 2 else (Viewport.MSAA_DISABLED if level == 0 else Viewport.MSAA_2X)
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if level == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	var target := 864.0 if level == 0 else 1440.0
	viewport.scaling_3d_scale = 1.0 if level == 2 else minf(1.0,target/maxf(1.0,viewport.get_visible_rect().size.y))

## Surface of revolution. Profile points are (radius, height), listed bottom to top.
static func lathe(profile: Array,segments := 32,smooth := true) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if not smooth: st.set_smooth_group(-1)
	for i: int in range(profile.size()-1):
		var a: Vector2 = profile[i]; var b: Vector2 = profile[i+1]
		for s: int in range(segments):
			var t0 := TAU*float(s)/segments; var t1 := TAU*float(s+1)/segments
			var p00 := Vector3(cos(t0)*a.x,a.y,sin(t0)*a.x); var p01 := Vector3(cos(t1)*a.x,a.y,sin(t1)*a.x)
			var p10 := Vector3(cos(t0)*b.x,b.y,sin(t0)*b.x); var p11 := Vector3(cos(t1)*b.x,b.y,sin(t1)*b.x)
			if a.x > 0.0001:
				st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p01)
			if b.x > 0.0001:
				st.add_vertex(p01); st.add_vertex(p10); st.add_vertex(p11)
	st.generate_normals()
	return st.commit()

static func surface(color: Color,metallic := 0.0,roughness := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.metallic = metallic; m.roughness = roughness
	return m

static func emissive(color: Color,energy := 2.0) -> StandardMaterial3D:
	var m := surface(color,0.0,0.4); m.emission_enabled = true; m.emission = color; m.emission_energy_multiplier = energy
	return m

static func glass(color := Color(0.62,0.86,0.95,0.16)) -> StandardMaterial3D:
	var m := surface(color,0.25,0.06); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.metallic_specular = 0.9
	return m

static func soft() -> Texture2D:
	if soft_sprite == null:
		var g := Gradient.new(); g.offsets = PackedFloat32Array([0.0,0.45,1.0])
		g.colors = PackedColorArray([Color(1,1,1,1),Color(1,1,1,0.55),Color(1,1,1,0)])
		soft_sprite = GradientTexture2D.new(); soft_sprite.gradient = g; soft_sprite.fill = GradientTexture2D.FILL_RADIAL
		soft_sprite.fill_from = Vector2(0.5,0.5); soft_sprite.fill_to = Vector2(1.0,0.5); soft_sprite.width = 64; soft_sprite.height = 64
	return soft_sprite

## Soft billboard particles. Keys: amount, life, speed(Vector2), size(Vector2), dir, spread,
## gravity, colors(Array[Color]), grow(Vector2 start/end scale), additive, box, radius,
## one_shot, explosive, local, damping, emitting.
static func emitter(c: Dictionary) -> CPUParticles3D:
	var e := CPUParticles3D.new()
	e.amount = int(c.get("amount",40)); e.lifetime = float(c.get("life",1.5))
	e.one_shot = bool(c.get("one_shot",false)); e.explosiveness = float(c.get("explosive",0.0))
	e.local_coords = bool(c.get("local",false)); e.randomness = 0.4
	e.direction = c.get("dir",Vector3.UP); e.spread = float(c.get("spread",20.0))
	e.gravity = c.get("gravity",Vector3.ZERO)
	var speed: Vector2 = c.get("speed",Vector2(1,2)); e.initial_velocity_min = speed.x; e.initial_velocity_max = speed.y
	var size: Vector2 = c.get("size",Vector2(0.3,0.6)); e.scale_amount_min = size.x; e.scale_amount_max = size.y
	e.damping_min = float(c.get("damping",0.0)); e.damping_max = e.damping_min
	if c.has("box"):
		e.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; e.emission_box_extents = c.box
	elif c.has("radius"):
		e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; e.emission_sphere_radius = float(c.radius)
	var colors: Array = c.get("colors",[Color(1,1,1,0.8),Color(1,1,1,0)])
	var ramp := Gradient.new(); var offsets := PackedFloat32Array(); var values := PackedColorArray()
	for i: int in range(colors.size()):
		offsets.append(float(i)/maxf(1.0,colors.size()-1.0)); values.append(colors[i])
	ramp.offsets = offsets; ramp.colors = values; e.color_ramp = ramp
	var grow: Vector2 = c.get("grow",Vector2(0.6,1.4))
	var curve := Curve.new(); curve.add_point(Vector2(0,grow.x)); curve.add_point(Vector2(1,grow.y)); e.scale_amount_curve = curve
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft(); m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if bool(c.get("additive",false)): m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var quad := QuadMesh.new(); quad.material = m; e.mesh = quad
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.emitting = bool(c.get("emitting",true))
	return e

## Looping low rumble (filtered noise) for engines and storms.
static func rumble_stream(seed_value := 5) -> AudioStreamWAV:
	var wave := AudioStreamWAV.new(); wave.format = AudioStreamWAV.FORMAT_16_BITS; wave.mix_rate = 11025
	var bytes := PackedByteArray(); bytes.resize(11025*2*2)
	var level := 0.0; var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	for i: int in range(11025*2):
		level = clampf(level*0.965+rng.randf_range(-1,1)*0.15,-1,1)
		bytes.encode_s16(i*2,int(level*15000))
	wave.data = bytes; wave.loop_mode = AudioStreamWAV.LOOP_FORWARD; wave.loop_end = 11025*2
	return wave

## Short sine blip with a soft envelope for interface and alarm cues.
static func tone_stream(frequency: float,duration: float,volume := 0.2) -> AudioStreamWAV:
	var wave := AudioStreamWAV.new(); wave.format = AudioStreamWAV.FORMAT_16_BITS; wave.mix_rate = 22050
	var count := int(duration*22050); var bytes := PackedByteArray(); bytes.resize(count*2)
	for i: int in range(count):
		bytes.encode_s16(i*2,int(sin(float(i)*frequency*TAU/22050)*32000*volume*sin(PI*float(i)/count)))
	wave.data = bytes
	return wave

static func shader(key: String,code: String) -> Shader:
	if not shader_cache.has(key):
		var s := Shader.new(); s.code = code; shader_cache[key] = s
	return shader_cache[key]

## Animated control-room display. mode: 0 traces, 1 bars, 2 radar, 3 transfer orbit, 4 data rows.
static func screen(tint: Color,mode: int,seed_value := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("screen","""shader_type spatial;
render_mode unshaded;
uniform vec3 tint : source_color = vec3(0.35,0.9,0.88);
uniform int mode = 0;
uniform float seed = 0.0;
uniform float gain = 1.5;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float stroke(float d,float w){return smoothstep(w,0.0,abs(d));}
void fragment(){
	vec2 uv = vec2(UV.x,1.0-UV.y);
	float t = TIME*0.6+seed*7.0;
	float v = 0.0;
	vec2 g = abs(fract(uv*vec2(16.0,9.0))-0.5);
	v += smoothstep(0.46,0.5,max(g.x,g.y))*0.07;
	if(mode==0){
		for(int i=0;i<3;i++){
			float fi=float(i);
			float y=0.5+0.2*sin(uv.x*(5.0+fi*3.0)+t*(1.0+fi*0.4)+seed*fi)+0.07*sin(uv.x*23.0-t*2.0+fi);
			v+=stroke(uv.y-y,0.014)*(1.0-fi*0.25);
		}
	}else if(mode==1){
		float col=floor(uv.x*14.0);
		float h=0.2+0.62*hash(vec2(col,floor(t*0.8)+seed));
		float f=fract(uv.x*14.0);
		v+=step(uv.y,h)*step(0.18,f)*step(f,0.86)*step(0.08,uv.y)*(0.4+0.6*uv.y/h);
	}else if(mode==2){
		vec2 c=(uv-0.5)*vec2(1.7,1.0); float r=length(c); float a=atan(c.y,c.x);
		v+=stroke(r-0.15,0.005)+stroke(r-0.3,0.005)+stroke(r-0.45,0.005);
		v+=step(r,0.45)*pow(fract((a+t)/6.2832),6.0)*0.9;
		for(int i=0;i<5;i++){
			vec2 b=vec2(hash(vec2(float(i),seed))-0.5,hash(vec2(seed,float(i)))-0.5)*0.7;
			v+=smoothstep(0.025,0.0,length(c-b))*(0.5+0.5*sin(t*3.0+float(i)));
		}
	}else if(mode==3){
		vec2 c=(uv-0.5)*vec2(1.7,1.0); float r=length(c);
		v+=stroke(r-0.17,0.004)*0.7+stroke(r-0.38,0.004)*0.7+smoothstep(0.035,0.0,r)*1.4;
		vec2 e=(c-vec2(-0.105,0.0))/vec2(0.275,0.24);
		v+=stroke(length(e)-1.0,0.03)*step(0.0,c.y);
		vec2 earth=0.17*vec2(cos(t*0.5),sin(t*0.5)); vec2 mars=0.38*vec2(cos(t*0.27+2.0),sin(t*0.27+2.0));
		v+=smoothstep(0.024,0.0,length(c-earth))+smoothstep(0.02,0.0,length(c-mars));
	}else{
		float row=floor(uv.y*14.0); float fr=fract(uv.y*14.0);
		float w=0.25+0.6*hash(vec2(row,seed+floor(t*0.3+row*0.13)));
		v+=step(0.07,uv.x)*step(uv.x,0.07+w*0.8)*step(0.3,fr)*step(fr,0.7)*(0.45+0.55*hash(vec2(floor(uv.x*40.0),row+seed)));
	}
	float scan=0.9+0.1*sin(uv.y*380.0);
	ALBEDO=(vec3(0.012,0.03,0.05)+tint*v*gain)*scan;
}""")
	m.set_shader_parameter("tint",tint); m.set_shader_parameter("mode",mode); m.set_shader_parameter("seed",seed_value)
	return m

## Additive holographic shell: fresnel rim and travelling scan lines.
static func hologram(tint: Color,alpha := 0.6) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("hologram","""shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never;
uniform vec3 tint : source_color = vec3(0.3,0.9,0.9);
uniform float alpha = 0.6;
varying vec3 lp;
void vertex(){lp=VERTEX;}
void fragment(){
	float f=pow(1.0-abs(dot(NORMAL,VIEW)),2.0);
	float scan=0.65+0.35*sin(lp.y*42.0-TIME*2.6);
	ALBEDO=tint*(0.3+f*1.8)*scan;
	ALPHA=alpha*(0.25+f);
}""")
	m.set_shader_parameter("tint",tint); m.set_shader_parameter("alpha",alpha)
	return m

const NOISE := """float h3(vec3 q){return fract(sin(dot(q,vec3(127.1,311.7,74.7)))*43758.5453);}
float n3(vec3 q){vec3 i=floor(q);vec3 f=fract(q);f=f*f*(3.0-2.0*f);
	return mix(mix(mix(h3(i),h3(i+vec3(1,0,0)),f.x),mix(h3(i+vec3(0,1,0)),h3(i+vec3(1,1,0)),f.x),f.y),
		mix(mix(h3(i+vec3(0,0,1)),h3(i+vec3(1,0,1)),f.x),mix(h3(i+vec3(0,1,1)),h3(i+vec3(1,1,1)),f.x),f.y),f.z);}
float fbm(vec3 q){float a=0.5;float s=0.0;for(int i=0;i<5;i++){s+=a*n3(q);q*=2.03;a*=0.5;}return s;}
"""

## Stylised Mars. Colours are illustrative; this is not an image mosaic.
static func mars(glow := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("mars","shader_type spatial;\nuniform float glow = 0.0;\nvarying vec3 p;\n"+NOISE+"""void vertex(){p=normalize(VERTEX);}
void fragment(){
	float f=fbm(p*2.6); float d=fbm(p*7.0+3.0);
	vec3 c=mix(vec3(0.27,0.12,0.08),vec3(0.74,0.34,0.16),smoothstep(0.34,0.62,f));
	c=mix(c,vec3(0.88,0.58,0.37),smoothstep(0.52,0.8,d)*0.55);
	float canyon=smoothstep(0.03,0.0,abs(p.y+0.12+0.08*sin(p.x*5.0)))*smoothstep(0.2,0.7,f);
	c=mix(c,vec3(0.2,0.08,0.06),canyon*0.6);
	float cap=smoothstep(0.86,0.95,abs(p.y)+(f-0.5)*0.1);
	c=mix(c,vec3(0.94,0.93,0.9),cap);
	float rim=pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),3.0);
	ALBEDO=c; ROUGHNESS=0.95; SPECULAR=0.1;
	EMISSION=c*glow+vec3(0.9,0.45,0.25)*rim*(0.25+glow);
}""")
	m.set_shader_parameter("glow",glow)
	return m

## Stylised Earth with drifting cloud bands and an atmospheric rim.
static func earth() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("earth","shader_type spatial;\nvarying vec3 p;\n"+NOISE+"""void vertex(){p=normalize(VERTEX);}
void fragment(){
	float f=fbm(p*2.2+1.7); float d=fbm(p*6.0);
	float land=smoothstep(0.5,0.56,f+d*0.12);
	vec3 ocean=mix(vec3(0.02,0.1,0.28),vec3(0.04,0.24,0.42),d);
	vec3 ground=mix(vec3(0.13,0.3,0.12),vec3(0.52,0.45,0.28),smoothstep(0.45,0.75,d));
	vec3 c=mix(ocean,ground,land);
	c=mix(c,vec3(0.92,0.95,0.97),smoothstep(0.8,0.92,abs(p.y)+(f-0.5)*0.12));
	float cloud=smoothstep(0.52,0.72,fbm(p*4.0+vec3(TIME*0.01,0.0,TIME*0.006)));
	c=mix(c,vec3(0.95),cloud*0.75);
	float rim=pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),2.5);
	ALBEDO=c; ROUGHNESS=mix(0.35,0.9,max(land,cloud)); SPECULAR=0.4;
	EMISSION=vec3(0.25,0.55,1.0)*rim*0.9;
}""")
	return m

## Engine exhaust: a bright core that flickers and fades along its length.
static func plume(core: Color,edge: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("plume","""shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never;
uniform vec3 core : source_color = vec3(1.0,0.9,0.7);
uniform vec3 edge : source_color = vec3(1.0,0.4,0.1);
uniform float power = 1.0;
uniform float reach = 4.0;
varying float along;
varying float around;
float hash(vec2 p){return fract(sin(dot(p,vec2(41.3,289.1)))*43758.5453);}
void vertex(){along=clamp(-VERTEX.y/reach,0.0,1.0);around=atan(VERTEX.z,VERTEX.x);}
void fragment(){
	float flick=0.75+0.25*sin(TIME*38.0+around*5.0)+0.15*hash(vec2(floor(TIME*30.0),floor(around*2.0)));
	float f=pow(1.0-abs(dot(NORMAL,VIEW)),0.6);
	vec3 c=mix(core,edge,clamp(along*1.4+f*0.4,0.0,1.0));
	ALBEDO=c*(1.5-along*0.8)*flick*power;
	ALPHA=clamp((1.0-along)*(1.0-f*0.8)*flick*power*0.8,0.0,1.0);
}""")
	m.set_shader_parameter("core",core); m.set_shader_parameter("edge",edge)
	return m

## Exhaust mesh for plume(): nozzle at the origin, extending down -Y by `reach`.
static func plume_mesh(radius: float,reach: float) -> ArrayMesh:
	return lathe([Vector2(0.0,-reach),Vector2(radius*0.45,-reach*0.7),Vector2(radius*0.9,-reach*0.3),Vector2(radius,-reach*0.06),Vector2(radius*0.8,0.0)],16)
