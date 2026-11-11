extends Node2D

const W := 1280.0
const H := 720.0
const TILE_W := 64.0
const TILE_H := 32.0
const SAVE_PATH := "user://save.cfg"
const FIELD_BACKGROUND: Texture2D = preload("res://assets/field_background.jpg")
const SPRITES := {
	"hero": preload("res://assets/hero.webp"),
	"ranger": preload("res://assets/ranger.webp"),
	"guardian": preload("res://assets/guardian.webp"),
	"stalker": preload("res://assets/stalker.webp"),
	"acolyte": preload("res://assets/acolyte.webp"),
	"warden": preload("res://assets/warden.webp")
}

var mode := "title"
var player := Vector2(-5.0, 4.0)
var camera := Vector2.ZERO
var player_hp := 100.0
var essence := 0
var enemies: Array[Dictionary] = []
var companions: Array[Dictionary] = []
var loot: Array[Dictionary] = []
var room_levels := [0, 0, 0]
var attack_timer := 0.0
var spell_timer := 0.0
var dodge_timer := 0.0
var invulnerable := 0.0
var message := ""
var message_timer := 0.0
var paused := false
var intro_seen := false
var animation_time := 0.0

const TREE_POSITIONS := [Vector2(-11,-8), Vector2(-9,-10), Vector2(-12,-4), Vector2(-11,1), Vector2(-10,7), Vector2(-8,10), Vector2(-4,-10), Vector2(1,-10), Vector2(9,-9), Vector2(12,-7), Vector2(11,-1), Vector2(12,3), Vector2(9,9), Vector2(5,10), Vector2(-2,10)]
const RUIN_POSITIONS := [Vector2(3,-8), Vector2(4,-8), Vector2(8,-8), Vector2(9,-8), Vector2(3,-7), Vector2(9,-7), Vector2(3,-6), Vector2(9,-6), Vector2(3,-5), Vector2(9,-5), Vector2(4,-4), Vector2(8,-4)]

func _ready() -> void:
	_load_game()
	_reset_encounter()
	queue_redraw()

func _process(delta: float) -> void:
	animation_time += delta
	attack_timer = maxf(0.0, attack_timer - delta)
	spell_timer = maxf(0.0, spell_timer - delta)
	dodge_timer = maxf(0.0, dodge_timer - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	message_timer = maxf(0.0, message_timer - delta)
	if mode == "field" and not paused:
		_update_field(delta)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if mode == "title" and event.keycode in [KEY_ENTER, KEY_SPACE]:
			_start_game()
		elif event.keycode == KEY_ESCAPE:
			if mode == "title":
				return
			if mode == "field":
				paused = not paused
			elif mode == "home":
				mode = "field"
		elif event.keycode == KEY_B:
			if mode == "field":
				mode = "home"
				paused = false
				_save_game()
			elif mode == "home":
				mode = "field"
		elif mode == "home" and event.keycode == KEY_E:
			player_hp = 100.0
			_show_message("Du ruhst dich aus. Deine Kräfte sind wiederhergestellt.")
			_save_game()
		elif mode == "home" and event.keycode in [KEY_1, KEY_2, KEY_3]:
			_upgrade_room(event.keycode - KEY_1)
		elif mode == "field" and not paused:
			if event.keycode == KEY_Q:
				_cast_spell()
			elif event.keycode == KEY_SPACE:
				_start_dodge()
	if event is InputEventMouseButton and event.pressed:
		if mode == "title" and event.button_index == MOUSE_BUTTON_LEFT:
			_start_game()
		elif mode == "home" and event.button_index == MOUSE_BUTTON_LEFT:
			var card_x := (get_viewport().get_mouse_position().x - 340.0) / 230.0
			if get_viewport().get_mouse_position().y > 365.0 and card_x >= 0.0:
				_upgrade_room(clampi(floori(card_x), 0, 2))
		elif mode == "field" and not paused and event.button_index == MOUSE_BUTTON_LEFT:
			_melee_attack()

func _start_game() -> void:
	mode = "field"
	paused = false
	player = Vector2(-5.0, 4.0)
	player_hp = 100.0
	_reset_encounter()
	_show_message("Die Splitter der Finsternis warten am alten Tor.")

func _reset_encounter() -> void:
	enemies = [
		_make_enemy("stalker", Vector2(0,-2), 36.0),
		_make_enemy("stalker", Vector2(3,0), 36.0),
		_make_enemy("acolyte", Vector2(5,-1), 30.0),
		_make_enemy("stalker", Vector2(7,-3), 40.0),
		_make_enemy("warden", Vector2(8,-5), 180.0)
	]
	companions = [
		{"kind":"ranger", "pos":Vector2(-7,5), "cooldown":0.25, "hp":55.0},
		{"kind":"guardian", "pos":Vector2(-5,7), "cooldown":0.75, "hp":85.0}
	]
	loot.clear()

func _make_enemy(kind: String, pos: Vector2, hp: float) -> Dictionary:
	return {"kind":kind, "pos":pos, "hp":hp, "max_hp":hp, "cooldown":randf_range(0.1, 1.2), "hit":0.0}

func _update_field(delta: float) -> void:
	var axes := Vector2.ZERO
	if Input.is_action_pressed("move_right"): axes.x += 1.0
	if Input.is_action_pressed("move_left"): axes.x -= 1.0
	if Input.is_action_pressed("move_down"): axes.y += 1.0
	if Input.is_action_pressed("move_up"): axes.y -= 1.0
	var world_motion := axes.normalized()
	var speed := 4.4 if dodge_timer <= 0.0 else 10.0
	if world_motion.length_squared() > 0.0:
		player += world_motion * speed * delta
		player.x = clampf(player.x, -11.0, 13.0)
		player.y = clampf(player.y, -9.0, 4.0)
	camera = Vector2.ZERO
	for enemy in enemies:
		enemy.hit = maxf(0.0, enemy.hit - delta)
		enemy.cooldown -= delta
		var to_player: Vector2 = player - enemy.pos
		if to_player.length() > 1.3 and to_player.length() < 10.0:
			enemy.pos += to_player.normalized() * delta * (1.0 if enemy.kind != "warden" else 0.55)
		elif to_player.length() <= 1.3 and enemy.cooldown <= 0.0:
			if invulnerable <= 0.0:
				player_hp -= 7.0 if enemy.kind != "warden" else 14.0
				invulnerable = 0.55
				_show_message("Ein Treffer! Weiche mit der Leertaste aus.")
			enemy.cooldown = 1.25
	for companion in companions:
		companion.cooldown -= delta
		var target_index := _nearest_enemy(companion.pos, 8.0)
		if target_index >= 0:
			var target: Dictionary = enemies[target_index]
			var distance: float = companion.pos.distance_to(target.pos)
			if distance > 1.8:
				companion.pos += (target.pos - companion.pos).normalized() * delta * 3.1
			elif companion.cooldown <= 0.0:
				target.hp -= 8.0 if companion.kind == "ranger" else 10.0
				target.hit = 0.18
				companion.cooldown = 1.15 if companion.kind == "ranger" else 1.35
		else:
			var follow_point := player + (Vector2(-1.7, 0.8) if companion.kind == "ranger" else Vector2(1.0, 1.6))
			if companion.pos.distance_to(follow_point) > 1.2:
				companion.pos += (follow_point - companion.pos).normalized() * delta * 3.4
	_process_dead_enemies()
	for drop in loot:
		if player.distance_to(drop.pos) < 1.2:
			essence += 1
			_show_message("Schattersplitter aufgenommen. (%d)" % essence)
			drop.collected = true
	loot = loot.filter(func(drop): return not drop.get("collected", false))
	if player_hp <= 0.0:
		player_hp = 52.0
		player = Vector2(-5, 4)
		_show_message("Die Finsternis drängt dich zurück. Du erwachst am Waldrand.")
		for enemy in enemies:
			enemy.pos = enemy.pos.lerp(Vector2(4,-2), 0.55)
	if enemies.is_empty():
		if not intro_seen:
			intro_seen = true
			_show_message("Das alte Tor ist frei. Kehre mit B in den Unterschlupf zurück.")
		_save_game()

func _nearest_enemy(pos: Vector2, max_distance: float) -> int:
	var best := -1
	var best_distance := max_distance
	for i in range(enemies.size()):
		var distance: float = pos.distance_to(enemies[i].pos)
		if distance < best_distance:
			best = i
			best_distance = distance
	return best

func _process_dead_enemies() -> void:
	var remaining: Array[Dictionary] = []
	for enemy in enemies:
		if enemy.hp <= 0.0:
			loot.append({"pos":enemy.pos, "collected":false})
		else:
			remaining.append(enemy)
	enemies = remaining

func _melee_attack() -> void:
	if attack_timer > 0.0: return
	attack_timer = 0.42
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var facing := (mouse - _iso(player)).normalized()
	for enemy in enemies:
		var toward: Vector2 = enemy.pos - player
		if toward.length() < 2.25 and (facing.dot(Vector2(toward.x - toward.y, (toward.x + toward.y) * 0.5).normalized()) > -0.45):
			enemy.hp -= 24.0
			enemy.hit = 0.22
	_show_message("Hieb")

func _cast_spell() -> void:
	if spell_timer > 0.0: return
	spell_timer = 4.0
	var index := _nearest_enemy(player, 7.0)
	if index < 0:
		_show_message("Kein Feind in Reichweite.")
		return
	var enemy: Dictionary = enemies[index]
	enemy.hp -= 42.0
	enemy.hit = 0.5
	for other in enemies:
		if other != enemy and other.pos.distance_to(enemy.pos) < 2.0:
			other.hp -= 18.0
	_show_message("Schattenblitz! Noch %.0f s Abklingzeit." % spell_timer)

func _start_dodge() -> void:
	if dodge_timer > 0.0: return
	dodge_timer = 0.45
	invulnerable = 0.5
	_show_message("Ausweichschritt")

func _upgrade_room(index: int) -> void:
	if index < 0 or index >= room_levels.size(): return
	var cost: int = 2 + int(room_levels[index]) * 2
	if room_levels[index] >= 3:
		_show_message("Dieser Raum ist bereits vollständig ausgebaut.")
	elif essence < cost:
		_show_message("Dir fehlen Splitter: benötigt werden %d." % cost)
	else:
		essence -= cost
		room_levels[index] += 1
		_show_message("Raum verbessert: %s" % ["Heilkammer", "Waffenkammer", "Quartier"][index])
		_save_game()

func _load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK: return
	essence = int(cfg.get_value("save", "essence", 0))
	room_levels = cfg.get_value("save", "rooms", [0,0,0])
	room_levels.resize(3)
	intro_seen = bool(cfg.get_value("save", "intro_seen", false))

func _save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("save", "essence", essence)
	cfg.set_value("save", "rooms", room_levels)
	cfg.set_value("save", "intro_seen", intro_seen)
	cfg.save(SAVE_PATH)

func _show_message(text: String) -> void:
	message = text
	message_timer = 3.0

func _draw() -> void:
	if mode == "title":
		_draw_title()
	elif mode == "home":
		_draw_home()
	else:
		_draw_field()
		if paused: _draw_pause()
	if message_timer > 0.0:
		_draw_message()

func _iso(pos: Vector2) -> Vector2:
	return Vector2(W * 0.5 + (pos.x-camera.x) * 44.0, 385.0 + (pos.y-camera.y) * 28.0)

func _draw_field() -> void:
	draw_texture_rect(FIELD_BACKGROUND, Rect2(0,0,W,H), false)
	for drop in loot: _draw_shard(_iso(drop.pos))
	for enemy in enemies: _draw_enemy(enemy)
	for companion in companions: _draw_actor(companion.pos, companion.kind, 1.0)
	_draw_actor(player, "hero", 1.0)
	_draw_hud()

func _draw_forest() -> void:
	for pos in TREE_POSITIONS:
		var p := _iso(pos)
		_draw_ellipse(p+Vector2(8,17),Vector2(24,8),Color(0,0,0,0.22))
		draw_colored_polygon(PackedVector2Array([p+Vector2(-3,4),p+Vector2(8,3),p+Vector2(12,25),p+Vector2(-2,25)]),Color("544538"))
		for layer in range(3):
			var yy := -18.0 - float(layer)*15.0
			var rr := 18.0 - float(layer)*2.0
			draw_circle(p+Vector2(-4,yy),rr,Color("132622") if layer == 0 else Color("1c3028"))
			draw_circle(p+Vector2(-9,yy-3),rr*0.62,Color("29453a"))
	for pos in [Vector2(-7,-2),Vector2(-1,-8),Vector2(10,5),Vector2(7,8),Vector2(-8,9),Vector2(11,-4)]:
		var p := _iso(pos)
		draw_colored_polygon(PackedVector2Array([p+Vector2(-13,5),p+Vector2(0,-6),p+Vector2(12,5),p+Vector2(3,13)]),Color("3d4943"))
		draw_line(p+Vector2(-8,5),p+Vector2(0,0),Color("74776b",0.5),2.0)

func _draw_ruin() -> void:
	var center := _iso(Vector2(6,-6))
	for pos in RUIN_POSITIONS:
		var p := _iso(pos)
		draw_rect(Rect2(p+Vector2(-18,-32),Vector2(36,35)),Color("555449"))
		draw_rect(Rect2(p+Vector2(-14,-28),Vector2(28,5)),Color("777363"))
		draw_line(p+Vector2(-11,-18),p+Vector2(10,-18),Color("353832"),2.0)
	draw_rect(Rect2(center+Vector2(-89,-99),Vector2(178,76)),Color("48483f"))
	draw_rect(Rect2(center+Vector2(-80,-92),Vector2(160,7)),Color("726e5d"))
	draw_rect(Rect2(center+Vector2(-48,-81),Vector2(96,102)),Color("282a29"))
	draw_rect(Rect2(center+Vector2(-38,-73),Vector2(76,89)),Color("111718"))
	draw_colored_polygon(PackedVector2Array([center+Vector2(-45,16),center+Vector2(0,-2),center+Vector2(45,16),center+Vector2(0,40)]),Color("292c29"))
	for xx in [-67.0, 67.0]:
		draw_rect(Rect2(center+Vector2(xx-6,-47),Vector2(12,42)),Color("77705c"))
		draw_circle(center+Vector2(xx,-49),7,Color("ffbb68"))
		draw_circle(center+Vector2(xx,-49),3,Color("fff0bc"))
	draw_string(ThemeDB.fallback_font, center+Vector2(-36,61), "ALTES TOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c8bc96"))

func _draw_actor(pos: Vector2, kind: String, scale: float) -> void:
	var p := _iso(pos)
	var size := Vector2(100,132)
	if kind == "guardian": size = Vector2(114,126)
	var bob := sin(animation_time*3.1 + p.x*0.01) * 2.0
	_draw_ellipse(p+Vector2(0,3),Vector2(size.x*0.28,9),Color(0,0,0,0.42))
	draw_texture_rect(SPRITES[kind], Rect2(p.x-size.x*0.5,p.y-size.y+bob,size.x,size.y),false)
	if kind == "hero" and invulnerable > 0.0:
		draw_arc(p+Vector2(0,-size.y*0.45),size.x*0.52,0,TAU,32,Color(0.72,0.84,1.0,0.55),2.0)

func _draw_enemy(enemy: Dictionary) -> void:
	var p: Vector2 = _iso(enemy.pos)
	var boss: bool = enemy.kind == "warden"
	var s := 1.0
	var size := Vector2(94,84)
	if enemy.kind == "acolyte": size = Vector2(104,137)
	if boss: size = Vector2(170,184)
	_draw_ellipse(p+Vector2(0,3),Vector2(size.x*0.28,10),Color(0,0,0,0.48))
	var flash: bool = enemy.hit > 0.0
	if flash: draw_circle(p-Vector2(0,size.y*0.45),maxf(size.x,size.y)*0.48,Color(1.0,0.77,0.62,0.24))
	var bob := sin(animation_time*2.4 + p.x*0.02) * 2.5
	draw_texture_rect(SPRITES[enemy.kind],Rect2(p.x-size.x*0.5,p.y-size.y+bob,size.x,size.y),false)
	if boss:
		draw_rect(Rect2(p+Vector2(-43,-size.y-12),Vector2(86,7)),Color("251b21"))
		draw_rect(Rect2(p+Vector2(-41,-size.y-10),Vector2(82.0*maxf(enemy.hp,0.0)/enemy.max_hp,3)),Color("b23c46"))

func _draw_shard(p: Vector2) -> void:
	draw_circle(p+Vector2(0,4),11,Color(0.59,0.31,0.83,0.22))
	draw_colored_polygon(PackedVector2Array([p+Vector2(0,-10),p+Vector2(7,0),p+Vector2(2,8),p+Vector2(-5,3)]),Color("c382eb"))
	draw_line(p+Vector2(0,-7),p+Vector2(1,2),Color("f0d7ff"),1.2)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(20):
		var angle := TAU * float(i) / 20.0
		points.append(center + Vector2(cos(angle)*radii.x, sin(angle)*radii.y))
	draw_colored_polygon(points, color)

func _draw_hud() -> void:
	draw_rect(Rect2(0,0,W,53),Color(0.055,0.073,0.071,0.88))
	draw_line(Vector2(0,53),Vector2(W,53),Color("98835e",0.6),1.0)
	draw_string(ThemeDB.fallback_font,Vector2(29,32),"SCHATTENBUND",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e8d7b3"))
	draw_string(ThemeDB.fallback_font,Vector2(262,32),"DAS ALTE TOR",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("c4b58c"))
	draw_string(ThemeDB.fallback_font,Vector2(454,31),"%d / 5 Feinde" % (5-enemies.size()),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("c3c5b9"))
	draw_string(ThemeDB.fallback_font,Vector2(1083,32),"✦ %d" % essence,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("d8a7ef"))
	draw_rect(Rect2(23,632,1234,72),Color(0.045,0.052,0.056,0.94))
	draw_rect(Rect2(23,632,1234,2),Color("8e7a57",0.85))
	draw_circle(Vector2(99,670),31,Color("452d2b")); draw_circle(Vector2(99,670),25,Color("a63e3d"))
	draw_arc(Vector2(99,670),29,-PI/2,-PI/2+TAU*clampf(player_hp/100.0,0,1),48,Color("f08068"),3.0)
	draw_string(ThemeDB.fallback_font,Vector2(78,675),"%d%%" % int(player_hp),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("fff0d8"))
	for i in range(2):
		var x := 160.0 + i*51.0
		draw_rect(Rect2(x,648,43,43),Color("343c37"),true)
		draw_rect(Rect2(x+3,651,37,37),Color("1c2724"),true)
		draw_string(ThemeDB.fallback_font,Vector2(x+15,678),"R" if i == 0 else "G",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("d3bd8e"))
	draw_string(ThemeDB.fallback_font,Vector2(273,661),"Q",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("d2bf94"))
	draw_rect(Rect2(292,642,50,50),Color("4a394f"),true); draw_circle(Vector2(317,667),13,Color("9e63bd")); draw_line(Vector2(307,676),Vector2(324,655),Color("e0bbf5"),3)
	draw_string(ThemeDB.fallback_font,Vector2(354,661),"SPACE",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("d2bf94"))
	draw_rect(Rect2(396,642,50,50),Color("3a4141"),true); draw_colored_polygon(PackedVector2Array([Vector2(421,651),Vector2(432,667),Vector2(421,684),Vector2(410,667)]),Color("a9c1c2"))
	draw_string(ThemeDB.fallback_font,Vector2(474,662),"B  Unterschlupf",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("aab1a6"))
	draw_string(ThemeDB.fallback_font,Vector2(1043,663),"WASD bewegen  ·  Klick: Hieb",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("9da79f"))
	if enemies.is_empty():
		draw_string(ThemeDB.fallback_font,Vector2(865,31),"TOR GESICHERT",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("a3d099"))

func _draw_title() -> void:
	draw_texture_rect(FIELD_BACKGROUND,Rect2(0,0,W,H),false)
	draw_rect(Rect2(0,0,W,H),Color(0.025,0.04,0.045,0.57))
	draw_circle(Vector2(1040,95),44,Color("d1d0bd")); draw_circle(Vector2(1055,79),43,Color("111b1d"))
	draw_string(ThemeDB.fallback_font,Vector2(120,191),"SCHATTENBUND",HORIZONTAL_ALIGNMENT_LEFT,-1,54,Color("e1d0ab"))
	draw_string(ThemeDB.fallback_font,Vector2(124,229),"Ein altes Tor. Eine erwachende Finsternis.",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("abb0a1"))
	draw_rect(Rect2(122,314,288,59),Color("4d4537"),true)
	draw_rect(Rect2(126,318,280,51),Color("98805b"),true)
	draw_string(ThemeDB.fallback_font,Vector2(159,351),"SPIEL BEGINNEN",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("fff1ce"))
	draw_string(ThemeDB.fallback_font,Vector2(123,414),"Isometrisches Fantasy-Abenteuer",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("a9ad9d"))
	draw_string(ThemeDB.fallback_font,Vector2(123,444),"Kämpfe · Begleiter · ein Unterschlupf, der wächst",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("858e83"))
	draw_string(ThemeDB.fallback_font,Vector2(123,667),"WASD bewegen   ·   Linke Maustaste angreifen   ·   Q Schattenblitz   ·   B Unterschlupf",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("aab0a5"))

func _draw_home() -> void:
	draw_rect(Rect2(0,0,W,H),Color("171e1c"))
	for x in range(0,1280,96):
		draw_line(Vector2(x,130),Vector2(x,610),Color("30372f"),1.0)
	for y in range(130,620,64):
		draw_line(Vector2(0,y),Vector2(W,y),Color("30372f"),1.0)
	draw_rect(Rect2(0,0,W,92),Color(0.05,0.07,0.065,0.94))
	draw_string(ThemeDB.fallback_font,Vector2(54,49),"DER UNTERSCHLUPF",HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color("e1d0ab"))
	draw_string(ThemeDB.fallback_font,Vector2(1060,48),"✦ %d Splitter" % essence,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("d8a7ef"))
	draw_string(ThemeDB.fallback_font,Vector2(57,139),"Ein sicherer Ort zwischen den Ausflügen. Ruhe dich aus oder verbessere deine Räume.",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("b6b7a7"))
	var names := ["Heilkammer","Waffenkammer","Quartier"]
	var desc := ["Stärkende Kräuter und Verbände.","Klingen, Schilde und altes Wissen.","Ein warmer Platz für deine Begleiter."]
	for i in range(3):
		var r := Rect2(52.0+i*404.0,226,370,299)
		draw_rect(r,Color("202a26"),true)
		draw_rect(Rect2(r.position.x,r.position.y,r.size.x,4),Color("927d59"))
		var cx := r.position.x+185
		if i == 0:
			draw_circle(Vector2(cx,307),35,Color("384839")); draw_arc(Vector2(cx,307),22,0,TAU,24,Color("93b27c"),5)
			draw_line(Vector2(cx-14,316),Vector2(cx+12,296),Color("d6d19e"),4)
		elif i == 1:
			draw_colored_polygon(PackedVector2Array([Vector2(cx-27,330),Vector2(cx,267),Vector2(cx+27,330)]),Color("9da6a2"))
			draw_line(Vector2(cx,317),Vector2(cx,341),Color("916942"),8)
		else:
			draw_rect(Rect2(cx-37,281,74,54),Color("674f3c"),true)
			draw_rect(Rect2(cx-29,291,58,36),Color("aa8863"),true)
		draw_string(ThemeDB.fallback_font,Vector2(r.position.x+27,384),names[i],HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("e2d4b4"))
		draw_string(ThemeDB.fallback_font,Vector2(r.position.x+27,415),"Ausbaustufe %d / 3" % room_levels[i],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("c2b68f"))
		draw_string(ThemeDB.fallback_font,Vector2(r.position.x+27,444),desc[i],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("a2aa9e"))
		var cost: int = 2+int(room_levels[i])*2
		var label := "VOLL AUSGEBAUT" if room_levels[i]>=3 else "VERBESSERN  ·  %d SPLITTER" % cost
		draw_rect(Rect2(r.position.x+22,466,326,42),Color("55503e") if room_levels[i]>=3 else Color("806a49"),true)
		draw_string(ThemeDB.fallback_font,Vector2(r.position.x+41,493),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f2e6c8"))
	draw_string(ThemeDB.fallback_font,Vector2(54,582),"E  Ausruhen und heilen",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("b2bea8"))
	draw_string(ThemeDB.fallback_font,Vector2(54,615),"1–3  Raum verbessern       B / Esc  Zurück zum Abenteuer",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("8d988e"))

func _draw_pause() -> void:
	draw_rect(Rect2(0,0,W,H),Color(0.025,0.035,0.034,0.62))
	draw_rect(Rect2(420,224,440,248),Color("202a26"),true)
	draw_string(ThemeDB.fallback_font,Vector2(550,294),"PAUSE",HORIZONTAL_ALIGNMENT_LEFT,-1,35,Color("eadbb9"))
	draw_string(ThemeDB.fallback_font,Vector2(492,349),"Esc drücken, um weiterzuspielen",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("b7bdaf"))
	draw_string(ThemeDB.fallback_font,Vector2(479,386),"B bringt dich in den Unterschlupf",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("929d91"))

func _draw_message() -> void:
	var width := minf(840.0, 80.0 + message.length()*9.0)
	var x := (W-width)*0.5
	draw_rect(Rect2(x,75,width,42),Color(0.08,0.09,0.08,0.9),true)
	draw_string(ThemeDB.fallback_font,Vector2(x+18,102),message,HORIZONTAL_ALIGNMENT_LEFT,width-36,16,Color("eee0bd"))
