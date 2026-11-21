extends RefCounted

const PATH := "user://dronobiy_profile.cfg"
const Rules = preload("res://game/rules.gd")
var records := {"air": 0, "street": 0}
var checkpoint: Dictionary = {}
var postcard := false
var muted := false
var hero := "petro"

func load_profile() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	for mode in records:
		records[mode] = maxi(0, int(file.get_value("records", mode, 0)))
	postcard = bool(file.get_value("profile", "postcard", false))
	muted = bool(file.get_value("profile", "muted", false))
	var saved_hero := str(file.get_value("profile", "hero", "petro"))
	if Rules.HEROES.has(saved_hero):
		hero = saved_hero
	var data = file.get_value("campaign", "checkpoint", {})
	if data is Dictionary and not data.is_empty():
		var phase := str(data.get("phase", ""))
		var mission := int(data.get("mission", 0))
		var expected: Array = ["", "air", "street", "street"]
		if mission in [1, 2, 3] and (phase == expected[mission] or (mission == 3 and phase == "boss")):
			checkpoint = data

func save_profile() -> Error:
	var file := ConfigFile.new()
	for mode in records:
		file.set_value("records", mode, records[mode])
	file.set_value("profile", "postcard", postcard)
	file.set_value("profile", "muted", muted)
	file.set_value("profile", "hero", hero)
	file.set_value("campaign", "checkpoint", checkpoint)
	return file.save(PATH)
