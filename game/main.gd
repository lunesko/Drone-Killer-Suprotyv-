extends Node2D

const Rules = preload("res://game/rules.gd")
const Profile = preload("res://game/profile.gd")
const CITY = preload("res://assets/bg_city_night.webp")
const MARCH = preload("res://assets/bgm_dronobiy_march.mp3")
const SKYWATCH_PAGE := "res://web/skywatch_ua_2022_2026.html"
const GOLD := Color("#ffd783")
const INK := Color("#eff4fa")
const MUTED := Color("#a9b8ce")

@onready var arena = $Arena
var profile := Profile.new()
var campaign := false
var mission := 1
var bonus := ""
var screen := "menu"
var ui: Control
var overlay: Control
var hud: Label
var heat_meter: ProgressBar
var action_buttons: Array[Button] = []
var position_buttons: Array[Button] = []
var tower_buttons: Array[Button] = []
var build_info: Label
var start_button: Button
var upgrade_button: Button
var sell_button: Button
var audio := AudioStreamPlayer.new()
var sfx := AudioStreamPlayer.new()
var tones := {}
var portrait_cache := {}
var active_panel: String = ""

func _ready() -> void:
	profile.load_profile()
	arena.wave_resolved.connect(on_wave_resolved)
	arena.defeated.connect(on_defeated)
	arena.slot_changed.connect(refresh_game)
	arena.cue.connect(play_cue)
	add_child(audio)
	audio.stream = MARCH
	audio.volume_db = -15
	add_child(sfx)
	sfx.volume_db = -17
	tones = {"confirm": make_tone(660, 0.12), "point": make_tone(860, 0.07), "damage": make_tone(170, 0.2)}
	show_menu()

func make_tone(hz: float, duration: float) -> AudioStreamWAV:
	var tone := AudioStreamWAV.new()
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	tone.mix_rate = 22050
	var length := int(duration * tone.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(length * 2)
	for i in range(length):
		var fade := minf(1.0, i / 40.0) * (1.0 - float(i) / length)
		bytes.encode_s16(i * 2, int(sin(TAU * hz * i / tone.mix_rate) * fade * 20000))
	tone.data = bytes
	return tone

func play_cue(kind: String) -> void:
	if profile.muted or not tones.has(kind):
		return
	sfx.stream = tones[kind]
	sfx.play()

func _process(_delta: float) -> void:
	if screen == "game":
		refresh_game()
		if arena.playing and not arena.paused and not profile.muted and not audio.playing:
			audio.play()
	if screen != "game" or arena.paused or profile.muted:
		if audio.playing:
			audio.stop()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if screen == "game" and active_panel == "pause":
			close_overlay()
		elif screen == "game" and active_panel.is_empty():
			show_pause()
		elif screen == "menu" and active_panel in ["guide", "skywatch_error"]:
			close_overlay()
		get_viewport().set_input_as_handled()

func save_profile() -> void:
	if profile.save_profile() != OK:
		push_warning("Не вдалося записати профіль у user://.")

func style(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	box.content_margin_left = 12
	box.content_margin_right = 12
	return box

func layer() -> Control:
	var root := Control.new()
	root.size = Vector2(1376, 920)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	return root

func panel(parent: Control, rect: Rect2, fill := Color("#132236"), border := Color("#3c5068")) -> Panel:
	var frame := Panel.new()
	frame.position = rect.position
	frame.size = rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", style(fill, border))
	parent.add_child(frame)
	return frame

func text(parent: Control, value: String, rect: Rect2, font_size: int = 20, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func button(parent: Control, value: String, rect: Rect2, action: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = value
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", 18)
	node.add_theme_stylebox_override("normal", style(Color("#ddb45e") if primary else Color("#253953"), GOLD if primary else Color("#4f6783")))
	node.add_theme_stylebox_override("hover", style(GOLD if primary else Color("#365170"), GOLD))
	node.add_theme_stylebox_override("pressed", style(Color("#ba9047") if primary else Color("#1c3047"), GOLD))
	node.add_theme_stylebox_override("disabled", style(Color("#152238"), Color("#293a4c")))
	node.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, GOLD))
	if primary:
		for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			node.add_theme_color_override(state, Color("#13171d"))
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func picture(parent: Control, image: Texture2D, rect: Rect2, stretch_mode: int = TextureRect.STRETCH_KEEP_ASPECT_CENTERED) -> TextureRect:
	var frame := TextureRect.new()
	frame.texture = image
	frame.position = rect.position
	frame.size = rect.size
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = stretch_mode
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	return frame

func portrait(hero_id: String) -> AtlasTexture:
	if portrait_cache.has(hero_id):
		return portrait_cache[hero_id]
	var source := load("res://assets/" + str(Rules.HEROES[hero_id][2])) as Texture2D
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(0, 0, 512, 512)
	portrait_cache[hero_id] = atlas
	return atlas

func switch_screen(next: String) -> void:
	close_overlay()
	if is_instance_valid(ui):
		remove_child(ui)
		ui.queue_free()
	screen = next
	ui = layer()
	action_buttons.clear()
	position_buttons.clear()
	tower_buttons.clear()

func choose_hero(id: String) -> void:
	profile.hero = id
	save_profile()
	show_menu(id)

func show_menu(focus_hero: String = "") -> void:
	arena.visible = false
	arena.playing = false
	arena.stop_input()
	switch_screen("menu")
	panel(ui, Rect2(0, 0, 1376, 920), Color("#0b1422"))
	picture(ui, CITY, Rect2(44, 65, 805, 791), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.44, 1.0])
	gradient.colors = PackedColorArray([Color(0.02, 0.04, 0.09, 0.76), Color(0.02, 0.04, 0.09, 0.14), Color(0.02, 0.04, 0.09, 0.90)])
	var shade := GradientTexture2D.new()
	shade.gradient = gradient
	shade.fill_from = Vector2(0.5, 0.0)
	shade.fill_to = Vector2(0.5, 1.0)
	picture(ui, shade, Rect2(44, 65, 805, 791), TextureRect.STRETCH_SCALE)
	panel(ui, Rect2(863, 65, 469, 791))
	text(ui, "ДРОНОБІЙ", Rect2(85, 115, 615, 80), 79)
	text(ui, "ЗАХИСТ", Rect2(85, 207, 615, 86), 79, GOLD)
	text(ui, "ОБОРОНА НЕБА ТА ВУЛИЦЬ УКРАЇНИ", Rect2(91, 321, 650, 35), 18)
	picture(ui, portrait(profile.hero), Rect2(427, 306, 411, 425))
	panel(ui, Rect2(70, 600, 520, 213), Color(0.02, 0.04, 0.09, 0.88))
	text(ui, "КАМПАНІЯ · РОЗДІЛ 1", Rect2(92, 621, 465, 25), 18, GOLD)
	text(ui, "Харків — Холодна Гора", Rect2(91, 658, 478, 50), 32)
	var title := "Почати кампанію" if profile.checkpoint.is_empty() else "Продовжити"
	var primary := button(ui, title, Rect2(92, 734, 227, 55), main_campaign_action, true)
	primary.grab_focus()
	if not profile.checkpoint.is_empty():
		button(ui, "Почати спочатку", Rect2(329, 734, 229, 55), confirm_restart)
	text(ui, "Оберіть захисника", Rect2(890, 92, 410, 43), 28)
	var index := 0
	for id in Rules.HEROES:
		var x := 887 + (index % 2) * 210
		var y := 147 + floori(index / 2.0) * 127
		var area := Rect2(x, y, 202, 117)
		var card := button(ui, "", area, choose_hero.bind(id), id == profile.hero)
		card.tooltip_text = str(Rules.HEROES[id][1])
		if id == focus_hero:
			card.grab_focus()
		picture(ui, portrait(id), Rect2(x + 64, y + 4, 74, 74))
		var label := text(ui, str(Rules.HEROES[id][0]), Rect2(x + 5, y + 80, 192, 29), 17, Color("#141a22") if id == profile.hero else INK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		index += 1
	text(ui, str(Rules.HEROES[profile.hero][1]), Rect2(890, 406, 405, 81), 17, MUTED)
	text(ui, "Швидка гра", Rect2(890, 500, 404, 32), 24)
	button(ui, "Небесна варта   %s" % profile.records.air, Rect2(889, 545, 416, 51), start_quick.bind("air"))
	button(ui, "Варта вулиць   %s" % profile.records.street, Rect2(889, 605, 416, 51), start_quick.bind("street"))
	if OS.has_feature("pc"):
		var skywatch := button(ui, "SKYWATCH: UA · у браузері", Rect2(889, 665, 416, 48), open_skywatch)
		skywatch.tooltip_text = "Окрема браузерна кампанія з вісьмома главами"
	button(ui, "Довідник і керування", Rect2(889, 725, 416, 48), show_guide)
	if profile.postcard:
		button(ui, "Листівка · Харків", Rect2(889, 783, 416, 45), show_postcard)
	text(ui, "Клавіші  •  миша  •  дотик", Rect2(890, 830, 414, 24), 16, MUTED)

func open_skywatch() -> void:
	var source := FileAccess.open(SKYWATCH_PAGE, FileAccess.READ)
	if source == null:
		show_skywatch_error("Файл кампанії не знайдено.")
		return

	var browser_path := ProjectSettings.globalize_path(SKYWATCH_PAGE)
	if not OS.has_feature("editor"):
		var browser_copy := "user://skywatch_ua_2022_2026.html"
		var destination := FileAccess.open(browser_copy, FileAccess.WRITE)
		if destination == null:
			show_skywatch_error("Не вдалося підготувати файл кампанії для браузера.")
			return
		var page := source.get_buffer(source.get_length())
		destination.store_buffer(page)
		var write_error := destination.get_error()
		destination.close()
		if write_error != OK:
			show_skywatch_error("Не вдалося записати файл кампанії.")
			return
		browser_path = ProjectSettings.globalize_path(browser_copy)

	if OS.shell_open(browser_path) != OK:
		show_skywatch_error("Не вдалося відкрити кампанію в системному браузері.")

func show_skywatch_error(message: String) -> void:
	begin_overlay("skywatch_error", "SKYWATCH: UA", message)
	button(overlay, "Закрити", Rect2(350, 500, 676, 51), close_overlay, true).grab_focus()

func main_campaign_action() -> void:
	if profile.checkpoint.is_empty():
		start_campaign()
	else:
		resume_campaign()

func active_checkpoint(stage: String, points: int, health: int = 5) -> void:
	profile.checkpoint = {"mission": mission, "phase": stage, "score": points, "hero": arena.hero, "bonus": bonus, "health": health}
	save_profile()

func start_campaign() -> void:
	profile.checkpoint = {"mission": 1, "phase": "air", "score": 0, "hero": profile.hero, "bonus": "", "health": 5}
	save_profile()
	resume_campaign()

func resume_campaign() -> void:
	if profile.checkpoint.is_empty():
		start_campaign()
		return
	var saved: Dictionary = profile.checkpoint
	campaign = true
	mission = int(saved.mission)
	bonus = str(saved.get("bonus", ""))
	var defender := str(saved.get("hero", "petro"))
	if not Rules.HEROES.has(defender):
		defender = "petro"
	var points := maxi(0, int(saved.get("score", 0)))
	enter_phase(str(saved.phase), defender, points, clampi(int(saved.get("health", 5)), 3, 5))

func start_quick(stage: String) -> void:
	campaign = false
	mission = 1
	bonus = ""
	enter_phase(stage, profile.hero, 0)

func enter_phase(stage: String, defender: String, points: int, health: int = 5) -> void:
	switch_screen("game")
	arena.visible = true
	var balance := (160 if campaign and mission == 3 else 140) + (120 if bonus == "extra_scrap" else 0)
	var count := (3 if campaign else 5) if stage == "air" else (1 if stage == "boss" else 3)
	arena.reset(stage, defender, points, balance if stage == "street" else 0, count, bonus == "free_upgrade", health)
	build_game_ui()
	refresh_game()

func build_game_ui() -> void:
	panel(ui, Rect2(0, 0, 1376, 68), Color("#111f31"))
	hud = text(ui, "", Rect2(20, 17, 1170, 38), 20)
	button(ui, "Пауза", Rect2(1222, 12, 130, 43), show_pause)
	panel(ui, Rect2(0, 842, 1376, 78), Color("#111f31"))
	if arena.mode == "street":
		for i in range(Rules.TOWERS.size()):
			var kind: String = Rules.TOWERS.keys()[i]
			tower_buttons.append(button(ui, "", Rect2(14 + i * 153, 852, 145, 44), arena.select_tower.bind(kind)))
		for i in range(Rules.SLOTS.size()):
			var control := button(ui, str(i + 1), Rect2(629 + i * 44, 852, 40, 44), arena.select_slot.bind(i))
			control.tooltip_text = Rules.SLOT_NAMES[i]
			position_buttons.append(control)
		upgrade_button = button(ui, "Рівень 2", Rect2(902, 852, 111, 44), arena.upgrade_tower)
		sell_button = button(ui, "Продати", Rect2(1021, 852, 100, 44), arena.sell_tower)
		start_button = button(ui, "Почати хвилю", Rect2(1130, 852, 226, 44), arena.start_wave, true)
		build_info = text(ui, "", Rect2(14, 897, 1120, 21), 14, MUTED)
	else:
		for i in range(arena.ABILITIES.size()):
			action_buttons.append(button(ui, "", Rect2(20 + i * 215, 856, 205, 48), arena.use_ability.bind(i)))
		heat_meter = ProgressBar.new()
		heat_meter.position = Vector2(694, 861)
		heat_meter.size = Vector2(325, 38)
		heat_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heat_meter.add_theme_stylebox_override("background", style(Color("#1d2b3f"), Color("#59718c")))
		heat_meter.add_theme_stylebox_override("fill", style(Color("#c08a37"), GOLD))
		ui.add_child(heat_meter)
		build_info = text(ui, "", Rect2(1045, 860, 306, 54), 17, GOLD)

func refresh_game() -> void:
	if screen != "game" or not is_instance_valid(hud):
		return
	var stage_name := "Варта вулиць" if arena.mode == "street" else ("Фінальна дуель" if arena.mode == "boss" else "Небесна варта")
	var phase := "Місія %s · " % mission if campaign else ""
	var current_wave: int = mini(arena.wave_count, arena.wave + int(arena.planning))
	var defense := "Серця %s" % arena.lives
	if arena.shields > 0:
		defense += " + щит"
	var budget := "    Брухт %s" % arena.scrap if arena.mode == "street" else ""
	hud.text = "%s%s    Хвиля %s/%s    %s    Очки %s%s" % [phase, stage_name, current_wave, arena.wave_count, defense, arena.score, budget]
	if arena.mode == "street":
		for i in range(tower_buttons.size()):
			var kind: String = Rules.TOWERS.keys()[i]
			var price: int = arena.tower_price(kind)
			tower_buttons[i].text = "%s %s · %s" % [i + 1, Rules.TOWERS[kind][0], price]
			tower_buttons[i].disabled = arena.paused or arena.scrap < price
			tower_buttons[i].modulate = GOLD if arena.selected_tower == kind else Color.WHITE
		for i in range(position_buttons.size()):
			position_buttons[i].disabled = arena.paused
			position_buttons[i].modulate = GOLD if i == arena.selected_slot else Color.WHITE
		var slot: Dictionary = {} if arena.selected_slot < 0 else arena.slots[arena.selected_slot]
		var has_tower: bool = not slot.is_empty() and slot.level > 0
		upgrade_button.disabled = not has_tower or slot.level != 1 or arena.scrap < arena.tower_price(slot.type, true) or arena.paused
		upgrade_button.text = str(arena.tower_price(slot.type, true)) + " · Рів. 2" if has_tower and slot.level == 1 else "Рівень 2"
		sell_button.disabled = not has_tower or arena.paused
		start_button.disabled = not arena.planning or arena.paused
		build_info.text = "Позиція %s · %s" % [arena.selected_slot + 1, Rules.SLOT_NAMES[arena.selected_slot]] if arena.selected_slot >= 0 else "Оберіть позицію на мапі або натисніть її номер"
	else:
		for i in range(action_buttons.size()):
			action_buttons[i].disabled = arena.paused or not arena.playing or arena.cooldowns[i] > 0
			action_buttons[i].text = "%s %s%s" % [i + 1, arena.ABILITIES[i], (" · %s с" % ceili(arena.cooldowns[i])) if arena.cooldowns[i] > 0 else ""]
		heat_meter.value = 100.0 * arena.heat / arena.heat_cap
		build_info.text = "Охолодження · %.1f с" % arena.lock_time if arena.lock_time > 0 else "Приціл · миша / дотик / WASD\nДія · ЛКМ / пробіл"

func on_wave_resolved() -> void:
	if arena.mode == "air" and arena.wave < arena.wave_count:
		show_draft()
	elif arena.mode == "street" and arena.wave < arena.wave_count:
		refresh_game()
	elif not campaign:
		save_record()
		show_result(true)
	elif mission == 1:
		show_bonus()
	elif mission == 2:
		mission = 3
		active_checkpoint("street", arena.score)
		resume_campaign()
	elif arena.mode == "street":
		active_checkpoint("boss", arena.score, maxi(3, arena.lives))
		resume_campaign()
	else:
		profile.postcard = true
		profile.checkpoint.clear()
		save_profile()
		show_result(true)

func save_record() -> void:
	if not campaign:
		profile.records[arena.mode] = maxi(profile.records[arena.mode], arena.score)
		save_profile()

func on_defeated() -> void:
	save_record()
	show_result(false)

func begin_overlay(id: String, title: String, body: String) -> void:
	close_overlay()
	active_panel = id
	arena.paused = true
	arena.stop_input()
	overlay = layer()
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.025, 0.05, 0.78)
	shade.size = Vector2(1376, 920)
	overlay.add_child(shade)
	panel(overlay, Rect2(306, 207, 764, 501), Color("#15243a"), Color("#5e7895"))
	text(overlay, title, Rect2(348, 247, 680, 72), 33, GOLD)
	text(overlay, body, Rect2(350, 328, 672, 228), 21)

func close_overlay() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
		overlay = null
	active_panel = ""
	arena.paused = false
	arena.stop_input()

func show_pause() -> void:
	begin_overlay("pause", "Пауза", "На клавіатурі натисніть Esc, щоб продовжити.")
	button(overlay, "Продовжити", Rect2(350, 440, 676, 51), close_overlay, true)
	button(overlay, "Звук: " + ("вимкнено" if profile.muted else "увімкнено"), Rect2(350, 505, 676, 51), toggle_mute)
	button(overlay, "Головне меню", Rect2(350, 592, 676, 53), show_menu)

func toggle_mute() -> void:
	profile.muted = not profile.muted
	save_profile()
	show_pause()

func show_draft() -> void:
	begin_overlay("draft", "Оберіть картку", "Ефект діє до завершення повітряного етапу.")
	var index := 0
	for id in arena.draft_options():
		var entry: Array = Rules.CARDS[id]
		button(overlay, entry[0], Rect2(347, 397 + 84 * index, 276, 60), pick_card.bind(id), index == 0)
		text(overlay, entry[1], Rect2(649, 404 + 84 * index, 367, 65), 17, MUTED)
		index += 1

func pick_card(id: String) -> void:
	arena.pick_card(id)
	close_overlay()
	arena.start_wave()

func show_bonus() -> void:
	begin_overlay("bonus", "Нічне небо захищено", "Оберіть підтримку для наступного етапу.")
	button(overlay, "+120 брухту", Rect2(350, 506, 676, 56), pick_bonus.bind("extra_scrap"), true)
	button(overlay, "Безкоштовне покращення", Rect2(350, 577, 676, 56), pick_bonus.bind("free_upgrade"))

func pick_bonus(choice: String) -> void:
	mission = 2
	bonus = choice
	active_checkpoint("street", arena.score)
	resume_campaign()

func show_result(won: bool) -> void:
	var title := "Місто захищено!" if won else "Місто зазнало втрат"
	var body := "Підсумковий рахунок: %s" % arena.score
	if won and campaign:
		body += "\nВідкрито листівку «Харків — Холодна Гора»."
	begin_overlay("result", title, body)
	if not campaign or not won:
		button(overlay, "Грати знову" if won else "Спробувати знову", Rect2(350, 505, 676, 58), repeat_attempt, true)
	button(overlay, "Головне меню", Rect2(350, 588, 676, 58), show_menu)

func repeat_attempt() -> void:
	if campaign:
		resume_campaign()
	else:
		start_quick(arena.mode)

func confirm_restart() -> void:
	begin_overlay("restart", "Почати кампанію спочатку?", "Поточну контрольну точку буде замінено.")
	button(overlay, "Почати нову кампанію", Rect2(350, 534, 330, 55), start_campaign, true)
	button(overlay, "Скасувати", Rect2(696, 534, 330, 55), close_overlay)

func show_guide() -> void:
	begin_overlay("guide", "Довідник і керування", "Небесна варта\nМиша, дотик, стрілки або WASD — приціл. Ліва кнопка миші, дотик або пробіл — дія. Клавіші 1–3 — здібності.\n\nВарта вулиць\nКлавіші 1–4 — тип позиції. Миша або дотик на мапі чи кнопки з номерами — вибір місця. Esc — пауза.")
	button(overlay, "Довідник техніки", Rect2(350, 603, 331, 52), show_catalog)
	button(overlay, "Закрити", Rect2(692, 603, 334, 52), close_overlay)

func show_catalog() -> void:
	begin_overlay("guide", "Довідник техніки", "Гра «Небесна варта»
«Герань-2» — 3 одиниці міцності. «Орлан-10» — 2 та зигзаги.

Гра «Варта вулиць»
БТР-82А, БМП-2 і Т-72Б3 мають 4, 10 і 26 одиниць міцності.

Фінальний флагман — 95 одиниць міцності.")
	button(overlay, "До керування", Rect2(350, 603, 331, 52), show_guide)
	button(overlay, "Закрити", Rect2(692, 603, 334, 52), close_overlay)

func show_postcard() -> void:
	begin_overlay("postcard", "Харків — Холодна Гора", "Пам’ятна листівка за проходження першого розділу.")
	picture(overlay, CITY, Rect2(488, 374, 400, 202))
	button(overlay, "Закрити", Rect2(350, 603, 676, 52), close_overlay)
