extends Node2D

signal wave_resolved
signal defeated
signal slot_changed
signal cue(name: String)

const Rules = preload("res://game/rules.gd")
const Artist = preload("res://game/arena_art.gd")
const SIZE := Vector2(1376, 768)
const ORIGIN := Vector2(688, 703)
const BOTTOM := 688.0
const AIM_SPEED := 520.0
const ABILITIES := ["Банка огірків", "РЕБ", "Термос"]

var mode := ""
var hero := "petro"
var score := 0
var lives := 5
var shields := 0
var scrap := 0
var free_upgrade := false
var wave := 0
var wave_count := 0
var playing := false
var planning := false
var paused := false
var cards: Array[String] = []
var aim := Vector2(688, 269)
var pointer_fire := false
var touch_index := -1
var heat := 0.0
var heat_cap := 100.0
var lock_time := 0.0
var boost := 0.0
var next_shot := 0.0
var cooldowns := [0.0, 0.0, 0.0]
var laser_clock := 0.0
var spawn_time := 0.0
var air_remaining := 0
var incoming: Array = []
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var rockets: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var boss: Dictionary = {}
var slots: Array[Dictionary] = []
var selected_slot := -1
var selected_tower := ""
var finish_time := 0.0
var clock := 0.0
var artwork := Artist.new()

func reset(stage: String, defender: String, total: int, balance: int, count: int, free: bool = false, health: int = 5) -> void:
	mode = stage
	hero = defender
	score = total
	scrap = balance
	free_upgrade = free
	lives = health
	shields = 0
	wave = 0
	wave_count = count
	playing = false
	planning = stage == "street"
	paused = false
	cards.clear()
	aim = Vector2(688, 269)
	heat = 0.0
	heat_cap = 130.0 if hero == "petro" else 100.0
	lock_time = 0.0
	boost = 0.0
	next_shot = 0.0
	cooldowns = [0.0, 0.0, 0.0]
	stop_input()
	clear_wave()
	slots.clear()
	for point in Rules.SLOTS:
		slots.append({"pos": point, "type": "", "level": 0, "cooldown": 0.0})
	selected_slot = -1
	selected_tower = ""
	if stage != "street":
		start_wave()
	queue_redraw()

func clear_wave() -> void:
	enemies.clear()
	shots.clear()
	rockets.clear()
	effects.clear()
	boss.clear()
	incoming.clear()
	air_remaining = 0
	finish_time = 0
	laser_clock = 0

func start_wave() -> void:
	if playing or wave >= wave_count or paused:
		return
	clear_wave()
	wave += 1
	planning = false
	playing = true
	shields = 1 if hero == "petro" else 0
	spawn_time = 0.5
	match mode:
		"air":
			air_remaining = Rules.AIR_COUNTS[wave - 1]
		"street":
			incoming = Rules.GROUND_WAVES[wave - 1].duplicate()
			for slot in slots:
				slot.cooldown = 0.0
		"boss":
			boss = {"pos": Vector2(688, 145), "hp": 95, "time": 0.0, "volley": 2.0}

func stop_input() -> void:
	pointer_fire = false
	touch_index = -1

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and touch_index == -1:
		pointer_fire = false
	if event is InputEventScreenTouch and not event.pressed and event.index == touch_index:
		stop_input()

func _unhandled_input(event: InputEvent) -> void:
	if paused or (not playing and not planning):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var number := int(event.physical_keycode) - KEY_1
		if mode == "street" and number in range(4):
			select_tower(Rules.TOWERS.keys()[number])
			get_viewport().set_input_as_handled()
		elif mode != "street" and number in range(3):
			use_ability(number)
			get_viewport().set_input_as_handled()
	if event is InputEventMouse and touch_index == -1:
		update_pointer(event.position - global_position)
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			press_field(event.position - global_position)
	elif event is InputEventScreenTouch and event.pressed and touch_index == -1:
		var point: Vector2 = event.position - global_position
		if Rect2(Vector2.ZERO, SIZE).has_point(point):
			touch_index = event.index
			press_field(point)
	elif event is InputEventScreenDrag and event.index == touch_index:
		update_pointer(event.position - global_position)

func update_pointer(point: Vector2) -> void:
	if mode != "street" and (pointer_fire or Rect2(Vector2.ZERO, SIZE).has_point(point)):
		aim = point.clamp(Vector2.ZERO, Vector2(SIZE.x, 678))

func press_field(point: Vector2) -> void:
	if not Rect2(Vector2.ZERO, SIZE).has_point(point):
		return
	if mode == "street":
		for i in range(slots.size()):
			if point.distance_to(slots[i].pos) <= 47:
				select_slot(i)
				break
	else:
		update_pointer(point)
		pointer_fire = true

func tower_price(kind: String, upgrade: bool = false) -> int:
	if upgrade and free_upgrade:
		return 0
	var value := int(Rules.TOWERS[kind][2 if upgrade else 1])
	return roundi(value * 0.75) if hero == "tolik" else value

func select_tower(kind: String) -> void:
	if paused or mode != "street" or (not planning and not playing) or not Rules.TOWERS.has(kind):
		return
	selected_tower = "" if selected_tower == kind else kind
	if selected_slot >= 0 and not selected_tower.is_empty():
		buy_tower(selected_slot, selected_tower)
	slot_changed.emit()

func select_slot(index: int) -> void:
	if paused or mode != "street" or (not planning and not playing) or index < 0 or index >= slots.size():
		return
	selected_slot = index
	if not selected_tower.is_empty():
		buy_tower(index, selected_tower)
	slot_changed.emit()

func buy_tower(index: int, kind: String) -> bool:
	var slot: Dictionary = slots[index]
	var price := tower_price(kind)
	if slot.level != 0 or scrap < price:
		return false
	scrap -= price
	slot.type = kind
	slot.level = 1
	slot.cooldown = 0.0
	selected_tower = ""
	cue.emit("confirm")
	return true

func upgrade_tower() -> void:
	if paused or selected_slot < 0 or (not planning and not playing):
		return
	var slot: Dictionary = slots[selected_slot]
	if slot.level != 1:
		return
	var price := tower_price(slot.type, true)
	if scrap < price:
		return
	scrap -= price
	free_upgrade = false
	slot.level = 2
	cue.emit("confirm")
	slot_changed.emit()

func sell_tower() -> void:
	if paused or selected_slot < 0 or (not planning and not playing):
		return
	var slot: Dictionary = slots[selected_slot]
	if slot.level == 0:
		return
	scrap += roundi(tower_price(slot.type) * 0.6 * slot.level)
	slot.type = ""
	slot.level = 0
	slot.cooldown = 0.0
	slot_changed.emit()

func draft_options() -> Array:
	var pool: Array = Rules.CARDS.keys().filter(func(key): return not cards.has(key))
	pool.shuffle()
	return pool.slice(0, 3)

func pick_card(key: String) -> void:
	if not Rules.CARDS.has(key) or cards.has(key):
		return
	cards.append(key)
	if key == "repair":
		lives = mini(5, lives + 1)

func use_ability(index: int) -> void:
	if paused or not playing or mode == "street" or index < 0 or index >= cooldowns.size() or cooldowns[index] > 0:
		return
	var charged := cards.has("charge")
	match index:
		0:
			cooldowns[0] = 6.0 if hero == "nadiia" else (8.0 if charged else 12.0)
			effects.append({"kind": "jar", "pos": aim, "time": 0.56, "radius": 170.0 if hero == "nadiia" else 90.0})
		1:
			cooldowns[1] = 11.0 if charged else 16.0
			for enemy in enemies:
				enemy.slow = 6.0
			effects.append({"kind": "pulse", "pos": SIZE / 2, "time": 0.7, "radius": 300.0})
		2:
			cooldowns[2] = 13.0 if charged else 18.0
			heat = 0
			lock_time = 0
			boost = 5
	cue.emit("confirm")

func _physics_process(delta: float) -> void:
	clock += delta
	queue_redraw()
	if paused or not playing:
		return
	update_effects(delta)
	if mode == "street":
		update_street(delta)
	else:
		update_air(delta)
	if not playing:
		return
	var is_clear := bool(
		(mode == "air" and air_remaining == 0 and enemies.is_empty())
		or (mode == "street" and incoming.is_empty() and enemies.is_empty())
		or (mode == "boss" and boss.hp <= 0)
	)
	if is_clear:
		finish_time += delta
		if finish_time >= (1.8 if mode == "boss" else 1.2):
			playing = false
			stop_input()
			if mode == "street" and wave < wave_count:
				scrap += 40
				planning = true
			wave_resolved.emit()

func damage_city() -> void:
	if mode == "boss" and boss.hp <= 0:
		return
	if shields > 0:
		shields -= 1
	else:
		lives = maxi(0, lives - 1)
	cue.emit("damage")
	if lives <= 0 and playing:
		playing = false
		stop_input()
		defeated.emit()

func damage_enemy(enemy: Dictionary, amount: float, jar: bool = false) -> void:
	if enemy.hp <= 0:
		return
	enemy.hp -= amount
	if enemy.hp > 0:
		return
	effects.append({"kind": "spark", "pos": enemy.pos, "time": 0.26, "radius": 30.0})
	if mode == "street":
		scrap += enemy.reward
		score += int(enemy.reward) * 10
	else:
		score += 140 if jar else (120 if enemy.type == "moped" else 150)
	cue.emit("point")

func update_laser(delta: float) -> void:
	if hero != "stepan":
		return
	laser_clock = minf(4, laser_clock + delta)
	if laser_clock < 4:
		return
	for enemy in enemies:
		if enemy.hp > 0:
			laser_clock = 0
			damage_enemy(enemy, 2)
			effects.append({"kind": "laser", "pos": enemy.pos, "time": 0.24, "radius": 0})
			break

func update_effects(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		var fx := effects[i]
		fx.time -= delta
		if fx.time > 0:
			continue
		effects.remove_at(i)
		if fx.kind == "jar":
			effects.append({"kind": "spark", "pos": fx.pos, "time": 0.4, "radius": fx.radius})
			for enemy in enemies:
				if enemy.pos.distance_to(fx.pos) <= fx.radius:
					damage_enemy(enemy, 4, true)

func update_air(delta: float) -> void:
	var horizontal := int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var vertical := int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	aim = (aim + Vector2(horizontal, vertical).normalized() * AIM_SPEED * delta).clamp(Vector2.ZERO, Vector2(SIZE.x, 678))
	var focus := get_viewport().gui_get_focus_owner()
	var firing := pointer_fire or (Input.is_physical_key_pressed(KEY_SPACE) and not focus is BaseButton)
	for i in range(cooldowns.size()):
		cooldowns[i] = maxf(0, cooldowns[i] - delta)
	boost = maxf(0, boost - delta)
	if lock_time > 0:
		lock_time = maxf(0, lock_time - delta)
		heat = heat_cap * lock_time / 3.0
	elif not firing:
		var rate := 32.0 * (1.4 if hero == "tolik" else 1.0) * (1.5 if cards.has("cool") else 1.0) * (3.0 if boost > 0 else 1.0)
		heat = maxf(0, heat - rate * delta)
	next_shot -= delta
	if firing and lock_time == 0 and next_shot <= 0:
		var speed := 1430.0 if cards.has("speed") else 1100.0
		var amount := 3 if hero == "stepan" and randf() < 0.25 else 1
		shots.append({"pos": ORIGIN, "velocity": ORIGIN.direction_to(aim) * speed, "damage": amount, "time": 1.2})
		next_shot = 0.08 if boost > 0 else 0.14
		if boost == 0:
			heat = minf(heat_cap, heat + 6)
			if heat >= heat_cap:
				lock_time = 3.0
				cue.emit("damage")

	if mode == "boss":
		update_boss(delta)
	else:
		spawn_time -= delta
		if air_remaining > 0 and spawn_time <= 0:
			spawn_air()
			air_remaining -= 1
			spawn_time = 1.3
		for i in range(enemies.size() - 1, -1, -1):
			var enemy := enemies[i]
			if enemy.hp <= 0:
				enemies.remove_at(i)
				continue
			enemy.age += delta
			enemy.slow = maxf(0, enemy.slow - delta)
			if enemy.age < enemy.dive:
				enemy.pos = enemy.pos.lerp(enemy.formation, minf(1, delta * 2.1))
			else:
				var speed := float(enemy.speed) * (0.45 if enemy.slow > 0 else 1.0)
				enemy.pos.y += speed * delta
				if enemy.type == "recon":
					enemy.pos.x = clampf(enemy.pos.x + cos(enemy.age * 6) * 96 * delta, 28, SIZE.x - 28)
			if enemy.pos.y >= BOTTOM:
				enemies.remove_at(i)
				damage_city()
				if not playing:
					return
		update_laser(delta)
	update_shots(delta)

func spawn_air() -> void:
	var moped := randf() < 0.65
	var from_left := randf() < 0.5
	var index: int = Rules.AIR_COUNTS[wave - 1] - air_remaining
	enemies.append({
		"type": "moped" if moped else "recon",
		"pos": Vector2(-30 if from_left else SIZE.x + 30, randf_range(40, 125)),
		"formation": Vector2(260 + (index % 5) * 215, 110 + (index % 4) * 43),
		"age": 0.0, "dive": randf_range(3.0, 7.0), "slow": 0.0,
		"hp": 3 if moped else 2, "max_hp": 3 if moped else 2,
		"speed": 110 if moped else 155,
	})

func update_boss(delta: float) -> void:
	if boss.hp > 0:
		boss.time += delta
		boss.pos = Vector2(688 + sin(boss.time * 1.1) * 458, 140 + cos(boss.time * 1.6) * 48)
		boss.volley -= delta
		if boss.volley <= 0:
			boss.volley = 2.4
			for offset in [-64, 64]:
				var start: Vector2 = boss.pos + Vector2(offset, 28)
				rockets.append({"pos": start, "velocity": start.direction_to(Vector2(688 + offset * 3, BOTTOM)) * 210.0})
	for i in range(rockets.size() - 1, -1, -1):
		var rocket := rockets[i]
		rocket.pos += rocket.velocity * delta
		if rocket.pos.y >= BOTTOM:
			rockets.remove_at(i)
			damage_city()
			if not playing:
				return

func update_shots(delta: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var shot := shots[i]
		var previous: Vector2 = shot.pos
		shot.pos += shot.velocity * delta
		shot.time -= delta
		var hit := false
		for j in range(rockets.size() - 1, -1, -1):
			if hit_near(previous, shot.pos, rockets[j].pos, 18.0):
				rockets.remove_at(j)
				hit = true
				break
		if not hit and not boss.is_empty() and boss.hp > 0 and hit_near(previous, shot.pos, boss.pos, 64):
			hit = true
			boss.hp -= shot.damage
			if boss.hp <= 0:
				score += 1500
				rockets.clear()
				effects.append({"kind": "spark", "pos": boss.pos, "time": 1.0, "radius": 125})
				cue.emit("confirm")
		if not hit:
			for enemy in enemies:
				if enemy.hp > 0 and hit_near(previous, shot.pos, enemy.pos, 27.0):
					damage_enemy(enemy, shot.damage)
					hit = true
					break
		if hit or shot.time <= 0 or not Rect2(Vector2.ZERO, SIZE).grow(20).has_point(shot.pos):
			shots.remove_at(i)

func hit_near(from: Vector2, to: Vector2, target: Vector2, radius: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(target, from, to).distance_to(target) <= radius

func update_street(delta: float) -> void:
	spawn_time -= delta
	if not incoming.is_empty() and spawn_time <= 0:
		var entry: Array = incoming.pop_front()
		spawn_ground(entry[0], entry[1])
		spawn_time = 2.0
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		if enemy.hp <= 0:
			enemies.remove_at(i)
			continue
		var path: Array = Rules.ROUTES[enemy.route]
		var target: Vector2 = path[enemy.next]
		var slow := 1.0
		for slot in slots:
			if slot.type == "obstacle":
				var stats: Array = Rules.TOWERS.obstacle
				if enemy.pos.distance_to(slot.pos) <= stats[3 if slot.level == 1 else 4]:
					slow = minf(slow, 0.5 if slot.level == 1 else 0.4)
					damage_enemy(enemy, float(stats[5 if slot.level == 1 else 6]) * delta)
		if enemy.hp <= 0:
			continue
		enemy.facing = enemy.pos.direction_to(target)
		enemy.pos = enemy.pos.move_toward(target, float(enemy.speed) * slow * delta)
		if enemy.pos == target:
			enemy.next += 1
			if enemy.next >= path.size():
				enemies.remove_at(i)
				damage_city()
				if not playing:
					return
	for slot in slots:
		if slot.level > 0 and slot.type != "obstacle":
			slot.cooldown -= delta
			if slot.cooldown <= 0:
				fire_tower(slot)
	for i in range(shots.size() - 1, -1, -1):
		var shot := shots[i]
		shot.time -= delta
		if shot.target.hp > 0:
			shot.dest = shot.target.pos
		shot.pos = shot.start.lerp(shot.dest, 1.0 - maxf(0, shot.time) / shot.duration)
		if shot.time > 0:
			continue
		shots.remove_at(i)
		for enemy in enemies:
			var distance: float = enemy.pos.distance_to(shot.dest)
			if enemy.hp > 0 and distance <= shot.radius:
				var falloff: float = 1.0 - 0.4 * distance / shot.radius if shot.kind == "artillery" else 1.0
				damage_enemy(enemy, shot.damage * falloff)
		effects.append({"kind": "spark", "pos": shot.dest, "time": 0.25, "radius": float(shot.radius)})
	update_laser(delta)

func spawn_ground(kind: String, route: int) -> void:
	var data: Array = Rules.UNITS[kind]
	var reward: int = roundi(data[2] * 1.35) if hero == "nadiia" else data[2]
	enemies.append({"type": kind, "route": route, "next": 1, "pos": Rules.ROUTES[route][0], "hp": data[0], "max_hp": data[0], "speed": data[1], "reward": reward, "facing": Vector2.RIGHT})

func fire_tower(slot: Dictionary) -> void:
	var stats: Array = Rules.TOWERS[slot.type]
	var level_offset := int(slot.level) - 1
	var nearest := float(stats[3 + level_offset])
	var target: Dictionary = {}
	for enemy in enemies:
		var distance: float = enemy.pos.distance_to(slot.pos)
		if enemy.hp > 0 and distance <= nearest:
			nearest = distance
			target = enemy
	if target.is_empty():
		return
	slot.cooldown = stats[7 + level_offset]
	var travel := maxf(0.1, nearest / (370.0 if slot.type == "artillery" else 770.0))
	shots.append({"kind": slot.type, "start": slot.pos, "pos": slot.pos, "dest": target.pos, "target": target, "time": travel, "duration": travel, "damage": stats[5 + level_offset], "radius": stats[9 + level_offset]})

func _draw() -> void:
	if not mode.is_empty():
		artwork.render(self)
