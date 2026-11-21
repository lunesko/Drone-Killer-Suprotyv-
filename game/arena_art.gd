extends RefCounted

const Rules = preload("res://game/rules.gd")
const CITY = preload("res://assets/bg_city_night.webp")
const MOPED = preload("res://assets/enemy_moped.webp")
const RECON = preload("res://assets/enemy_recon.webp")
const FLAGSHIP = preload("res://assets/enemy_boss_rocket.webp")
const JAR = preload("res://assets/item_pickle_jar.webp")
const STREET = preload("res://assets/street_atlas.png")
const BOLLARD = preload("res://assets/street_bollard.png")
const BOLLARD_REGION := Rect2(62, 44, 132, 198)
const BOLLARD_SIZE := Vector2(18, 27)
const BOLLARD_BASES := [
	Vector2(98, 279), Vector2(127, 279),
	Vector2(789, 329), Vector2(811, 346),
	Vector2(1267, 681), Vector2(1296, 681),
]
const StreetAtlas = preload("res://game/street_atlas.gd")
const VEHICLE_SPRITES := {"btr": "btr82a_base", "bmp": "bmp2_base", "tank": "t72b3_base"}
const SIZE := Vector2(1376, 768)
const INK := Color("#e9f1f5")
const GOLD := Color("#ffce75")
const CYAN := Color("#74d9ff")

func render(field: Node2D) -> void:
	if field.mode == "street":
		draw_street(field)
	else:
		draw_sky(field)
	for shot in field.shots:
		var color := GOLD if field.mode == "street" else CYAN
		field.draw_circle(shot.pos, 4, color, true, -1.0, true)
	for fx in field.effects:
		match fx.kind:
			"laser":
				field.draw_line(Vector2(688, 703), fx.pos, Color("#a7f3d0"), 5, true)
			"jar":
				var pos: Vector2 = Vector2(688, 703).lerp(fx.pos, 1 - fx.time / 0.56)
				field.draw_texture_rect(JAR, Rect2(pos - Vector2(11, 18), Vector2(22, 36)), false)
			"pulse":
				field.draw_arc(fx.pos, fx.radius * (1.0 - fx.time / 0.7) + 1, 0, TAU, 48, Color("#72c4db"), 4, true)
			"spark":
				field.draw_arc(fx.pos, maxf(1.0, fx.radius * (1.0 - minf(fx.time, 0.25))), 0, TAU, 24, GOLD, 3, true)

func draw_sky(field: Node2D) -> void:
	field.draw_texture_rect(CITY, Rect2(Vector2.ZERO, SIZE), false)
	field.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.02, 0.04, 0.10, 0.28))
	var radius := 140.0 if field.cards.has("beam") else 95.0
	field.draw_circle(field.aim, radius, Color(0.95, 0.81, 0.42, 0.09))
	field.draw_arc(field.aim, 15, 0, TAU, 24, GOLD, 2, true)
	field.draw_line(field.aim + Vector2(-25, 0), field.aim + Vector2(25, 0), GOLD, 2, true)
	field.draw_line(field.aim + Vector2(0, -25), field.aim + Vector2(0, 25), GOLD, 2, true)
	var origin := Vector2(688, 703)
	field.draw_circle(origin, 24, Color("#182334"))
	field.draw_line(origin, origin + origin.direction_to(field.aim) * 45, CYAN, 7, true)
	for enemy in field.enemies:
		if enemy.hp <= 0:
			continue
		var image: Texture2D = MOPED if enemy.type == "moped" else RECON
		var tint := Color("#80deff") if enemy.slow > 0 else Color.WHITE
		field.draw_texture_rect(image, Rect2(enemy.pos - Vector2(43, 25), Vector2(86, 50)), false, tint)
		health(field, enemy.pos + Vector2(-22, -29), 44, float(enemy.hp) / enemy.max_hp)
	if not field.boss.is_empty() and field.boss.hp > 0:
		var position: Vector2 = field.boss.pos
		field.draw_texture_rect(FLAGSHIP, Rect2(position - Vector2(117, 57), Vector2(234, 114)), false)
		health(field, position + Vector2(-78, -69), 156, float(field.boss.hp) / 95.0)
	for rocket in field.rockets:
		field.draw_line(rocket.pos - rocket.velocity.normalized() * 20, rocket.pos, Color("#ffab72"), 6, true)
		field.draw_circle(rocket.pos, 8, Color("#fbe4a6"), true, -1.0, true)

func street_sprite(field: Node2D, sprite: String, point: Vector2, dimensions: Vector2) -> void:
	field.draw_texture_rect_region(STREET, Rect2(point - dimensions / 2, dimensions), StreetAtlas.REGIONS[sprite])

func draw_street(field: Node2D) -> void:
	field.draw_rect(Rect2(Vector2.ZERO, SIZE), Color("#101a29"))
	for ix in range(0, 15):
		for iy in range(0, 8):
			var point := Vector2(ix * 96 + 18, iy * 96 + 16)
			var height := 40 + (ix * 13 + iy * 17) % 24
			var building := Rect2(point, Vector2(64, height))
			field.draw_rect(building.grow(3), Color("#0b1421"))
			field.draw_rect(building, Color("#1b2b3e"))
			if (ix + iy) % 3 == 0:
				field.draw_rect(Rect2(point + Vector2(8, 8), Vector2(16, 4)), Color("#786747"))
	for route in Rules.ROUTES:
		var line := PackedVector2Array(route)
		field.draw_polyline(line, Color("#4a5161"), 62, true)
		field.draw_polyline(line, Color("#283344"), 55, true)
		field.draw_polyline(line, Color("#586278"), 2, true)
	for point in [Vector2(45, 140), Vector2(910, 120), Vector2(1140, 285), Vector2(656, 532), Vector2(100, 636), Vector2(1150, 716)]:
		street_sprite(field, "tree_canopy", point, Vector2(79, 79))
	for point in [Vector2(340, 275), Vector2(820, 409), Vector2(1110, 402)]:
		street_sprite(field, "street_lamp", point, Vector2(120, 120))
	for base: Vector2 in BOLLARD_BASES:
		var top_left := base - Vector2(BOLLARD_SIZE.x / 2, BOLLARD_SIZE.y)
		field.draw_texture_rect_region(BOLLARD, Rect2(top_left, BOLLARD_SIZE), BOLLARD_REGION)
	street_sprite(field, "city_gate", Vector2(1325, 620), Vector2(98, 136))
	for i in range(field.slots.size()):
		var slot: Dictionary = field.slots[i]
		var active: bool = i == field.selected_slot
		if active and slot.level > 0:
			var range_px: float = Rules.TOWERS[slot.type][3 if slot.level == 1 else 4]
			field.draw_circle(slot.pos, range_px, Color(0.33, 0.6, 0.9, 0.12))
			field.draw_arc(slot.pos, range_px, 0, TAU, 64, CYAN, 2, true)
		var pos: Vector2 = slot.pos
		var color := GOLD if active else Color("#59758f")
		if slot.level == 0:
			street_sprite(field, "build_slot_empty", pos, Vector2(78, 78))
		else:
			if slot.type != "obstacle":
				street_sprite(field, "tower_base_platform", pos, Vector2(79, 79))
			street_sprite(field, "tower_%s_lv%s" % [slot.type, slot.level], pos, Vector2(86, 86))
		if active:
			field.draw_arc(pos, 40, 0, TAU, 32, color, 3, true)
		field.draw_string(ThemeDB.fallback_font, pos + Vector2(-6, 49), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
		if slot.level == 2:
			field.draw_circle(pos + Vector2(29, -27), 7, GOLD)
	for enemy in field.enemies:
		if enemy.hp <= 0:
			continue
		var p: Vector2 = enemy.pos
		field.draw_set_transform(p, enemy.facing.angle())
		var size := 85.0 if enemy.type == "tank" else 77.0
		street_sprite(field, VEHICLE_SPRITES[enemy.type], Vector2.ZERO, Vector2(size, size))
		field.draw_set_transform(Vector2.ZERO, 0)
		health(field, p + Vector2(-20, -24), 40, float(enemy.hp) / enemy.max_hp)

func health(field: Node2D, point: Vector2, width: float, ratio: float) -> void:
	field.draw_rect(Rect2(point, Vector2(width, 5)), Color("#202230"))
	field.draw_rect(Rect2(point, Vector2(width * clampf(ratio, 0, 1), 5)), GOLD)
