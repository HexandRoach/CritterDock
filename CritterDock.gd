extends Node2D

enum Mode { IDLE, FOLLOW, PLAY, SLEEP, EAT }

const SAVE_PATH: String = "user://critterdock_six_pips_v2.json"
const OLD_SAVE_PATH: String = "user://critterdock_care_v1.json"
const NAMES: Array[String] = ["Moss", "Ember", "Moon", "Puddle", "Pebble", "Puff"]
const COLORS: Array[Color] = [Color("94bea2"), Color("d89c70"), Color("b0a1c9"), Color("92bacb"), Color("aaa99f"), Color("e4d2b6")]
const NEED_NAMES: Array[String] = ["Hunger", "Energy", "Hygiene", "Fun", "Social", "Health"]
const RECIPES: Array[String] = ["Garden porridge", "Pumpkin bean stew", "Berry oat cakes"]
const COOK_TIMES: Array[float] = [5.0, 9.0, 6.0]
const FULLNESS: Array[float] = [0.60, 0.80, 0.40]
const DECAY: Array[float] = [0.045, 0.025, 0.020, 0.035, 0.022]

var needs: Array[float] = [85.0, 85.0, 90.0, 80.0, 80.0, 100.0]
var hatched: bool = false
var dead: bool = false
var cozy: bool = true
var egg_clicks: int = 0
var mode: Mode = Mode.IDLE
var pet_x: float = 440.0
var destination: float = 440.0
var facing: float = 1.0
var meal: int = -1
var portions: float = 0.0
var freshness: float = 0.0
var cooking: int = -1
var cook_time: float = 0.0
var dirty_bowl: bool = false
var critical_time: float = 0.0
var ball_x: float = 685.0
var ball_velocity: float = 0.0
var dragging: bool = false
var clock: float = 0.0
var mode_time: float = 0.0
var decision_time: float = 0.0
var save_time: float = 0.0
var affection_time: float = 0.0
var active: int = 0
var records: Array[Dictionary] = []
var font: Font
var status: Label
var message: Label
var panel: PanelContainer
var kitchen: VBoxContainer
var difficulty: CheckButton
var restart: Button
var meters: Array[ProgressBar] = []
var actions: Array[Button] = []
var tabs: Array[Button] = []
var toast: String = "Choose a Pip, then tap its egg three times."
var toast_time: float = 8.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var egg_shake: float = 0.0
var egg_hatch_timer: float = -1.0
var egg_audio: AudioStreamPlayer
var egg_crack_sounds: Array[AudioStreamWAV] = []
var sound_toggle: CheckButton
var egg_sound_enabled: bool = true


func _ready() -> void:
	rng.randomize()
	font = ThemeDB.fallback_font
	setup_egg_audio()
	var window: Window = get_window()
	window.min_size = Vector2i(1100, 720)
	window.content_scale_size = Vector2i(1100, 720)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().auto_accept_quit = false
	for i in range(6):
		records.append(fresh_record())
	load_game()
	apply_record()
	build_ui()
	refresh_ui()


# Each Pip has an independent care record. Only the selected Pip simulates.
func fresh_record() -> Dictionary:
	return {
		"hatched": false, "dead": false, "egg_clicks": 0,
		"needs": [85.0, 85.0, 90.0, 80.0, 80.0, 100.0],
		"pet_x": 440.0, "meal": -1, "portions": 0.0,
		"freshness": 0.0, "cooking": -1, "cook_time": 0.0,
		"dirty_bowl": false, "critical_time": 0.0
	}


func store_record() -> void:
	if records.size() != 6:
		return
	records[active] = {
		"hatched": hatched, "dead": dead, "egg_clicks": egg_clicks,
		"needs": needs.duplicate(), "pet_x": pet_x, "meal": meal,
		"portions": portions, "freshness": freshness,
		"cooking": cooking, "cook_time": cook_time,
		"dirty_bowl": dirty_bowl, "critical_time": critical_time
	}


func apply_record() -> void:
	var data: Dictionary = records[active]
	hatched = bool(data.get("hatched", false))
	dead = bool(data.get("dead", false))
	egg_clicks = clampi(int(data.get("egg_clicks", 0)), 0, 3)
	needs = [85.0, 85.0, 90.0, 80.0, 80.0, 100.0]
	var values: Variant = data.get("needs", [])
	if values is Array:
		var saved_values: Array = values
		if saved_values.size() == 6:
			for i in range(6):
				var value: Variant = saved_values[i]
				if value is float or value is int:
					needs[i] = clampf(float(value), 0.0, 100.0)
	pet_x = clampf(float(data.get("pet_x", 440.0)), 90.0, 735.0)
	destination = pet_x
	meal = clampi(int(data.get("meal", -1)), -1, 2)
	portions = clampf(float(data.get("portions", 0.0)), 0.0, 100.0)
	freshness = maxf(0.0, float(data.get("freshness", 0.0)))
	cooking = clampi(int(data.get("cooking", -1)), -1, 2)
	cook_time = maxf(0.0, float(data.get("cook_time", 0.0)))
	dirty_bowl = bool(data.get("dirty_bowl", false))
	critical_time = maxf(0.0, float(data.get("critical_time", 0.0)))
	mode = Mode.IDLE
	mode_time = 0.0
	decision_time = 0.0
	dragging = false
	ball_velocity = 0.0
	affection_time = 0.0
	egg_shake = 0.0
	egg_hatch_timer = -1.0
	if hatched:
		egg_clicks = 3
	else:
		egg_clicks = clampi(egg_clicks, 0, 2)
	if portions <= 0.0:
		meal = -1
	elif meal < 0:
		meal = 0
	if cozy and not dead:
		needs[5] = maxf(1.0, needs[5])
		critical_time = 0.0
	if egg_audio != null:
		egg_audio.stop()


func select_pip(index: int) -> void:
	if index < 0 or index >= 6 or index == active:
		return
	# Let the brief hatch animation finish before changing slots.
	if egg_hatch_timer >= 0.0:
		return
	store_record()
	active = index
	apply_record()
	kitchen.hide()
	notify(NAMES[active] + " Pip / inactive Pips rest with their needs paused.")
	save_pet()


# ---------------- UI ----------------
func box_style(color: Color, radius: int = 12) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box


func make_label(text: String, font_size: int = 16) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("493f3b"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func make_button(parent: Node, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 34.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal: StyleBoxFlat = box_style(Color("eadbc7"))
	normal.content_margin_left = 9.0
	normal.content_margin_right = 9.0
	normal.content_margin_top = 7.0
	normal.content_margin_bottom = 7.0
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("f7ead8")
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("c2d6c3")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("493f3b"))
	button.add_theme_color_override("font_hover_color", Color("493f3b"))
	button.add_theme_color_override("font_pressed_color", Color("493f3b"))
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func build_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	var title: Label = make_label("CritterDock / The Pip Nursery", 27)
	title.position = Vector2(26.0, 15.0)
	canvas.add_child(title)
	status = make_label("")
	status.position = Vector2(28.0, 52.0)
	canvas.add_child(status)
	var tab_row: HBoxContainer = HBoxContainer.new()
	tab_row.position = Vector2(28.0, 85.0)
	tab_row.size.x = 730.0
	tab_row.add_theme_constant_override("separation", 8)
	canvas.add_child(tab_row)
	for i in range(6):
		tabs.append(make_button(tab_row, NAMES[i], select_pip.bind(i)))
	message = make_label("")
	message.position = Vector2(28.0, 665.0)
	message.size = Vector2(1040.0, 48.0)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(message)
	panel = PanelContainer.new()
	panel.position = Vector2(800.0, 100.0)
	panel.size = Vector2(275.0, 530.0)
	var background: StyleBoxFlat = box_style(Color("fff6e7"), 18)
	background.content_margin_left = 14.0
	background.content_margin_right = 14.0
	background.content_margin_top = 14.0
	background.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", background)
	canvas.add_child(panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 7)
	scroll.add_child(column)
	column.add_child(make_label("Care journal", 22))
	for i in range(6):
		column.add_child(make_label(NEED_NAMES[i], 14))
		var meter: ProgressBar = ProgressBar.new()
		meter.custom_minimum_size = Vector2(215.0, 12.0)
		meter.show_percentage = false
		meter.add_theme_stylebox_override("background", box_style(Color("e5d9cd"), 6))
		meter.add_theme_stylebox_override("fill", box_style(Color("8fb49a"), 6))
		column.add_child(meter)
		meters.append(meter)
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	actions.append(make_button(row, "Meals", toggle_kitchen))
	actions.append(make_button(row, "Sleep", change_mode.bind(Mode.SLEEP)))
	actions.append(make_button(row, "Play", change_mode.bind(Mode.PLAY)))
	var row_two: HBoxContainer = HBoxContainer.new()
	column.add_child(row_two)
	actions.append(make_button(row_two, "Clean", clean_home))
	actions.append(make_button(row_two, "Follow", change_mode.bind(Mode.FOLLOW)))
	actions.append(make_button(row_two, "Rest", change_mode.bind(Mode.IDLE)))
	difficulty = CheckButton.new()
	difficulty.text = "Cozy mode: no death"
	difficulty.button_pressed = cozy
	difficulty.add_theme_color_override("font_color", Color("493f3b"))
	difficulty.toggled.connect(set_cozy)
	column.add_child(difficulty)
	kitchen = VBoxContainer.new()
	column.add_child(kitchen)
	for i in range(3):
		actions.append(make_button(kitchen, RECIPES[i], start_cooking.bind(i)))
	kitchen.hide()
	restart = make_button(column, "New egg for this slot", reset_pet)
	restart.hide()
	# Audio control is accessible even while the care panel is hidden.
	sound_toggle = CheckButton.new()
	sound_toggle.position = Vector2(810.0, 55.0)
	sound_toggle.text = "Egg sounds"
	sound_toggle.button_pressed = egg_sound_enabled
	sound_toggle.add_theme_color_override("font_color", Color("493f3b"))
	sound_toggle.toggled.connect(set_egg_sound)
	canvas.add_child(sound_toggle)


func notify(text: String) -> void:
	toast = text
	toast_time = 7.0
	if text.contains("praise") or text.contains("hand"):
		affection_time = 2.0


func set_cozy(value: bool) -> void:
	cozy = value
	if cozy and not dead:
		needs[5] = maxf(1.0, needs[5])
		critical_time = 0.0
	save_pet()


func set_egg_sound(value: bool) -> void:
	egg_sound_enabled = value
	if not value and egg_audio != null:
		egg_audio.stop()
	save_pet()


func toggle_kitchen() -> void:
	if hatched and not dead:
		kitchen.visible = not kitchen.visible


func change_mode(next_mode: Mode) -> void:
	if not hatched or dead:
		return
	mode = next_mode
	mode_time = 0.0
	if mode != Mode.PLAY:
		dragging = false


func clean_home() -> void:
	if not hatched or dead:
		return
	needs[2] = minf(100.0, needs[2] + 40.0)
	if dirty_bowl or freshness <= 0.0:
		portions = 0.0
		meal = -1
		dirty_bowl = false
	notify("A tidy room, clean fur, and fresh bedding.")


func start_cooking(recipe: int) -> void:
	if not hatched or dead or recipe < 0 or recipe > 2:
		return
	if cooking >= 0:
		notify("A meal is already cooking.")
		return
	if portions > 0.0:
		notify("Finish the bowl first. Clean removes spoiled food.")
		return
	cooking = recipe
	cook_time = COOK_TIMES[recipe]
	kitchen.hide()
	notify("Preparing " + RECIPES[recipe].to_lower() + "...")


# ---------------- EGG AUDIO AND ANIMATION ----------------
func setup_egg_audio() -> void:
	egg_audio = AudioStreamPlayer.new()
	egg_audio.volume_db = -12.0
	add_child(egg_audio)
	for strength in range(3):
		egg_crack_sounds.append(create_egg_crack_sound(strength))


func create_egg_crack_sound(strength: int) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.18 + float(strength) * 0.07
	var sample_count: int = int(duration * float(sample_rate))
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(sample_count * 2)
	var sound_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	sound_rng.seed = 1037 + strength * 79
	var previous_noise: float = 0.0
	var tick_count: int = 3 + strength * 2
	for i in range(sample_count):
		var time: float = float(i) / float(sample_rate)
		var noise: float = sound_rng.randf_range(-1.0, 1.0)
		var bright_noise: float = noise - previous_noise * 0.75
		previous_noise = noise
		var envelope: float = 0.0
		for tick in range(tick_count):
			var local_time: float = time - float(tick) * 0.024
			if local_time >= 0.0:
				envelope += exp(-local_time * 160.0) / (1.0 + float(tick) * 0.35)
		var shell_ring: float = sin(TAU * (1700.0 + float(strength) * 220.0) * time)
		shell_ring *= exp(-time * 65.0) * 0.10
		var value: float = clampf(bright_noise * envelope * 0.36 + shell_ring, -0.9, 0.9)
		# Fade the tail to prevent an abrupt end to the generated sample.
		value *= minf(1.0, (duration - time) * 150.0)
		samples.encode_s16(i * 2, int(value * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = samples
	return stream


func play_egg_crack(strength: int) -> void:
	if not egg_sound_enabled or egg_audio == null or egg_crack_sounds.is_empty():
		return
	var index: int = clampi(strength, 0, egg_crack_sounds.size() - 1)
	egg_audio.stream = egg_crack_sounds[index]
	egg_audio.pitch_scale = rng.randf_range(0.94, 1.06)
	egg_audio.play()


func tap_egg() -> void:
	if hatched or egg_hatch_timer >= 0.0:
		return
	egg_clicks = mini(egg_clicks + 1, 3)
	egg_shake = 1.0
	play_egg_crack(egg_clicks - 1)
	if egg_clicks == 1:
		notify("Tap... tap... something inside tapped back!")
	elif egg_clicks == 2:
		notify("The shell is cracking! One more gentle tap.")
	else:
		egg_hatch_timer = 0.9
		notify("Someone is ready to come out!")


func update_egg_animation(delta: float) -> void:
	egg_shake = move_toward(egg_shake, 0.0, delta * 1.5)
	if egg_hatch_timer < 0.0:
		return
	egg_hatch_timer -= delta
	egg_shake = 1.0
	if egg_hatch_timer <= 0.0:
		egg_hatch_timer = -1.0
		egg_shake = 0.0
		hatched = true
		pet_x = 420.0
		destination = pet_x
		mode = Mode.IDLE
		mode_time = 0.0
		affection_time = 2.0
		play_egg_crack(2)
		notify("Welcome, " + NAMES[active] + " Pip!")
		save_pet()


# ---------------- INPUT ----------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			save_pet()
			get_tree().quit()
			return
	if not (event is InputEventMouseButton):
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	var mouse: Vector2 = click.position
	if not hatched:
		var offset: Vector2 = mouse - Vector2(420.0, 477.0)
		var hit: Vector2 = Vector2(offset.x / 58.0, offset.y / 74.0)
		if click.pressed and hit.length_squared() <= 1.0:
			tap_egg()
		return
	if dead:
		return
	if not click.pressed:
		release_ball()
		return
	if mouse.distance_to(Vector2(pet_x, 490.0)) < 49.0:
		needs[4] = minf(100.0, needs[4] + 14.0)
		affection_time = 2.0
		notify(NAMES[active] + " Pip leans into your hand.")
	elif mouse.distance_to(Vector2(ball_x, 527.0)) < 24.0:
		change_mode(Mode.PLAY)
		dragging = true
		ball_velocity = 0.0
	elif mouse.distance_to(Vector2(640.0, 533.0)) < 50.0:
		if portions > 0.0 and freshness > 0.0:
			change_mode(Mode.EAT)
		else:
			notify("Prepare a fresh meal first.")


func release_ball() -> void:
	if dragging:
		dragging = false
		ball_velocity = clampf((ball_x - pet_x) * 2.0, -320.0, 320.0)


# ---------------- SIMULATION ----------------
func _process(delta: float) -> void:
	clock += delta
	toast_time = maxf(0.0, toast_time - delta)
	affection_time = maxf(0.0, affection_time - delta)
	save_time += delta
	if not hatched:
		update_egg_animation(delta)
	elif not dead:
		update_life(delta)
	if save_time >= 15.0:
		save_time = 0.0
		save_pet()
	refresh_ui()
	queue_redraw()


func update_life(delta: float) -> void:
	mode_time += delta
	for i in range(5):
		needs[i] = maxf(0.0, needs[i] - DECAY[i] * delta)
	if cooking >= 0:
		cook_time -= delta
		if cook_time <= 0.0:
			meal = cooking
			cooking = -1
			cook_time = 0.0
			portions = 100.0
			freshness = 600.0
			dirty_bowl = false
			change_mode(Mode.EAT)
			notify("Dinner is ready!")
	if portions > 0.0:
		freshness = maxf(0.0, freshness - delta)
	if needs[0] < 35.0 and portions > 0.0 and freshness > 0.0:
		if mode != Mode.EAT and mode != Mode.SLEEP:
			change_mode(Mode.EAT)
	if needs[1] < 10.0 and mode != Mode.EAT and mode != Mode.SLEEP:
		change_mode(Mode.SLEEP)
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		release_ball()
	match mode:
		Mode.IDLE:
			decision_time -= delta
			if decision_time <= 0.0:
				destination = rng.randf_range(110.0, 730.0)
				decision_time = rng.randf_range(4.0, 9.0)
			walk(destination, 40.0, delta)
		Mode.FOLLOW:
			walk(clampf(get_global_mouse_position().x, 90.0, 735.0), 85.0, delta)
		Mode.PLAY:
			if dragging:
				ball_x = clampf(get_global_mouse_position().x, 65.0, 740.0)
			walk(ball_x, 110.0, delta)
			if not dragging and absf(pet_x - ball_x) < 35.0:
				ball_velocity = facing * 180.0
			needs[3] = minf(100.0, needs[3] + delta)
			if mode_time > 70.0:
				change_mode(Mode.IDLE)
		Mode.SLEEP:
			walk(180.0, 55.0, delta)
			if absf(pet_x - 180.0) < 5.0:
				needs[1] = minf(100.0, needs[1] + delta * 0.8)
				if needs[1] >= 99.0:
					change_mode(Mode.IDLE)
		Mode.EAT:
			walk(595.0, 65.0, delta)
			if absf(pet_x - 595.0) < 5.0:
				if portions > 0.0 and freshness > 0.0:
					var bite: float = minf(portions, delta * 7.0)
					portions = maxf(0.0, portions - bite)
					needs[0] = minf(100.0, needs[0] + bite * FULLNESS[clampi(meal, 0, 2)])
					if portions <= 0.0:
						meal = -1
						dirty_bowl = true
						change_mode(Mode.IDLE)
				else:
					change_mode(Mode.IDLE)
	if not dragging:
		ball_x += ball_velocity * delta
		ball_velocity = move_toward(ball_velocity, 0.0, delta * 65.0)
		if ball_x < 65.0 or ball_x > 740.0:
			ball_x = clampf(ball_x, 65.0, 740.0)
			ball_velocity *= -0.7
	if needs[0] <= 0.0 or needs[1] <= 0.0:
		needs[5] = maxf(1.0 if cozy else 0.0, needs[5] - delta * 0.15)
	elif needs[0] > 40.0 and needs[1] > 35.0 and needs[2] > 30.0:
		needs[5] = minf(100.0, needs[5] + delta * 0.06)
	if needs[5] <= 15.0 and not cozy:
		critical_time += delta
	else:
		critical_time = 0.0
	if not cozy and needs[5] <= 0.0 and critical_time > 60.0:
		dead = true
		dragging = false
		ball_velocity = 0.0
		kitchen.hide()
		notify("This Pip has passed away. You can begin again in this slot.")
		save_pet()


func walk(target: float, speed: float, delta: float) -> void:
	if absf(target - pet_x) < 4.0:
		return
	facing = signf(target - pet_x)
	var pace: float = 1.0
	if active == 1:
		pace = 1.15
	elif active == 2 or active == 4:
		pace = 0.8
	if needs[5] < 30.0:
		pace *= 0.5
	pet_x = move_toward(pet_x, target, speed * pace * delta)


func refresh_ui() -> void:
	if panel == null:
		return
	panel.visible = hatched
	for i in range(6):
		meters[i].value = needs[i]
		meters[i].tooltip_text = "%s: %d / 100" % [NEED_NAMES[i], int(needs[i])]
		tabs[i].text = ("> " if i == active else "") + NAMES[i]
		tabs[i].disabled = egg_hatch_timer >= 0.0
	for button in actions:
		button.disabled = dead
	restart.visible = dead
	difficulty.disabled = dead
	var description: String = "Tap the egg three times to hatch."
	if egg_hatch_timer >= 0.0:
		description = "Hatching..."
	elif dead:
		description = "In memory / a new egg is available in the journal."
	elif hatched:
		var mode_names: Array[String] = ["Exploring", "Following", "Playing", "Bedtime", "Eating"]
		description = mode_names[int(mode)]
		if needs[5] <= 15.0:
			description = "CRITICAL: fresh food and rest needed."
		elif needs[0] < 20.0:
			description = "Very hungry / prepare a meal."
		elif needs[1] < 20.0:
			description = "Very sleepy / help your Pip get to bed."
	status.text = NAMES[active] + " Pip / " + description
	if dead:
		message.text = "This Pip's story has ended. The other Pips are unchanged."
	elif cooking >= 0:
		message.text = "Cooking %s / %ds" % [RECIPES[cooking], ceili(cook_time)]
	elif toast_time > 0.0:
		message.text = toast
	elif not hatched:
		message.text = "Click the egg / each tap shakes and cracks the shell"
	elif portions > 0.0 and freshness <= 0.0:
		message.text = "The food has spoiled. Use Clean before cooking again."
	else:
		message.text = "Select a Pip above / click to pet / Meals to cook / inactive Pips are paused"


# ---------------- DRAWING HELPERS ----------------
func rect_soft(rect: Rect2, color: Color, radius: int = 12) -> void:
	draw_style_box(box_style(color, radius), rect)


func oval(center: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(48):
		var angle: float = TAU * float(i) / 48.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)


func _draw() -> void:
	if font == null:
		return
	draw_room()
	if not hatched:
		draw_egg()
		return
	draw_bowl()
	draw_circle(Vector2(ball_x, 527.0), 17.0, Color("cd956f"))
	draw_arc(Vector2(ball_x, 527.0), 12.0, -1.2, 1.2, 16, Color("fae4bd"), 3.0, true)
	if dead:
		rect_soft(Rect2(365.0, 475.0, 130.0, 65.0), Color("aab2a2"))
		draw_string(font, Vector2(375.0, 515.0), NAMES[active], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color("fff6e7"))
	else:
		draw_pet()


func draw_room() -> void:
	draw_rect(Rect2(0.0, 0.0, 1100.0, 720.0), Color("f1e5d5"))
	for x in range(0, 790, 38):
		draw_line(Vector2(x, 135), Vector2(x, 450), Color("e9dacb"), 2.0)
	draw_rect(Rect2(0.0, 450.0, 790.0, 200.0), Color("b89070"))
	for y in range(450, 650, 40):
		draw_line(Vector2(0, y), Vector2(790, y), Color("9f795e"), 2.0)
	draw_line(Vector2(0, 450), Vector2(790, 450), Color("fff0dc"), 8.0)
	rect_soft(Rect2(270, 155, 220, 175), Color("fff6e7"))
	rect_soft(Rect2(282, 167, 196, 151), Color("b9dce0"))
	draw_circle(Vector2(430, 201), 22.0, Color("fff0bb"))
	draw_line(Vector2(380, 167), Vector2(380, 318), Color("fff6e7"), 7.0)
	draw_line(Vector2(282, 242), Vector2(478, 242), Color("fff6e7"), 7.0)
	rect_soft(Rect2(251, 145, 31, 197), Color("d7b2a5"))
	rect_soft(Rect2(478, 145, 31, 197), Color("d7b2a5"))
	oval(Vector2(400, 568), Vector2(305, 52), Color("c7c9aa"))
	oval(Vector2(400, 568), Vector2(279, 40), Color("dce0c4"))
	rect_soft(Rect2(105, 501, 150, 52), Color("8e6b59"), 19)
	rect_soft(Rect2(113, 494, 134, 42), Color("d5b1a5"), 19)
	rect_soft(Rect2(123, 495, 53, 24), Color("faead8"))
	draw_line(Vector2(696, 407), Vector2(696, 348), Color("729778"), 5.0)
	oval(Vector2(679, 365), Vector2(23, 10), Color("8eac87"))
	oval(Vector2(711, 349), Vector2(23, 10), Color("a2bb93"))
	rect_soft(Rect2(670, 394, 52, 55), Color("c78f71"))


func draw_bowl() -> void:
	oval(Vector2(640, 550), Vector2(48, 10), Color(0, 0, 0, 0.12))
	rect_soft(Rect2(599, 519, 82, 31), Color("a5bfc0"), 15)
	oval(Vector2(640, 521), Vector2(41, 13), Color("e3eeea"))
	if portions > 0.0:
		var food: Color = Color("c9aa76")
		if meal == 1:
			food = Color("d89c59")
		elif meal == 2:
			food = Color("b27a80")
		if freshness <= 0.0:
			food = Color("889066")
		oval(Vector2(640, 521), Vector2(34.0 * minf(1.0, portions / 30.0), 9.0), food)
	elif dirty_bowl:
		draw_circle(Vector2(631, 521), 4.0, Color("ad957d"))


func draw_egg() -> void:
	var color: Color = COLORS[active]
	var hatching: bool = egg_hatch_timer >= 0.0
	var idle_pulse: float = pow(maxf(0.0, sin(clock * 1.6)), 12.0)
	var idle_wobble: float = sin(clock * 3.0) * 0.025
	idle_wobble += sin(clock * 15.0) * idle_pulse * 0.045
	var shake_rotation: float = sin(clock * 42.0) * egg_shake * 0.15
	var shake_x: float = sin(clock * 57.0) * egg_shake * 4.0
	var bounce: float = absf(sin(clock * 22.0)) * egg_shake * 6.0
	if hatching:
		shake_rotation *= 1.4
		bounce *= 1.5
	oval(Vector2(420, 544), Vector2(55.0 - bounce * 0.4, 10.0), Color(0, 0, 0, 0.13))
	draw_set_transform(Vector2(420.0 + shake_x, 477.0 - bounce), idle_wobble + shake_rotation, Vector2.ONE)
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(65):
		var angle: float = TAU * float(i) / 64.0
		points.append(Vector2(cos(angle) * 46.0 * (1.0 + 0.17 * sin(angle)), sin(angle) * 63.0))
	draw_colored_polygon(points, color.lightened(0.7))
	draw_polyline(points, color.darkened(0.15), 2.0, true)
	oval(Vector2(-14, -21), Vector2(15, 32), Color(1, 1, 1, 0.22))
	for i in range(6):
		var spot: Vector2 = Vector2(sin(float(i) * 2.3) * 29.0, -39.0 + float(i) * 15.0)
		if active == 4:
			draw_circle(spot, 4.0, color.darkened(0.2))
		elif active == 3:
			draw_arc(spot, 9.0, 0.0, TAU, 24, color, 2.0, true)
		elif active == 2:
			draw_line(spot - Vector2(5, 0), spot + Vector2(5, 0), color, 2.0)
			draw_line(spot - Vector2(0, 5), spot + Vector2(0, 5), color, 2.0)
		else:
			oval(spot, Vector2(7, 10), color)
	var crack: Color = Color("75635b")
	if egg_clicks >= 1:
		draw_polyline(PackedVector2Array([Vector2(0, -62), Vector2(-8, -40), Vector2(5, -22), Vector2(-5, -5)]), crack, 2.5, true)
	if egg_clicks >= 2:
		draw_polyline(PackedVector2Array([Vector2(-5, -5), Vector2(10, 10), Vector2(0, 30), Vector2(13, 48)]), crack, 2.5, true)
		draw_polyline(PackedVector2Array([Vector2(-5, -5), Vector2(-23, 3), Vector2(-37, -6)]), crack, 2.0, true)
	if hatching:
		draw_polyline(PackedVector2Array([Vector2(-44, 8), Vector2(-29, 15), Vector2(-15, 5), Vector2(0, 14), Vector2(15, 4), Vector2(30, 13), Vector2(45, 6)]), crack, 3.5, true)
	draw_set_transform(Vector2.ZERO)


func draw_pet() -> void:
	var sleeping: bool = mode == Mode.SLEEP and absf(pet_x - 180.0) < 6.0
	var bob: float = sin(clock * 2.5) * 1.5
	if mode == Mode.PLAY:
		bob -= absf(sin(clock * 8.0)) * 3.0
	var ground: float = 510.0 if sleeping else 529.0
	var fur: Color = COLORS[active]
	if needs[2] < 25.0:
		fur = fur.darkened(0.15)
	oval(Vector2(pet_x, ground + 7.0), Vector2(39, 9), Color(0, 0, 0, 0.13))
	draw_set_transform(Vector2(pet_x, ground + bob), 0.0, Vector2(1.0, 0.76 if sleeping else 1.0))
	if active == 3:
		oval(Vector2(37, -16), Vector2(21, 14), fur.darkened(0.12))
	elif active == 5:
		draw_circle(Vector2(38, -22), 18.0, fur.lightened(0.1))
	elif active == 1:
		draw_colored_polygon(PackedVector2Array([Vector2(25, -8), Vector2(53, -35), Vector2(45, -9)]), fur.darkened(0.1))
	var ear_y: float = -65.0
	var ear_size: Vector2 = Vector2(13, 18)
	if active == 2 or active == 3:
		ear_y = -48.0
		ear_size = Vector2(13, 26)
	elif active == 4:
		ear_size = Vector2(10, 10)
	elif active == 5:
		ear_size = Vector2(17, 25)
	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		oval(Vector2(side * 25.0, ear_y), ear_size, fur.darkened(0.09))
		oval(Vector2(side * 25.0, ear_y - 1.0), ear_size * 0.6, Color("d8aca6"))
	oval(Vector2(0, -33), Vector2(39, 39), fur.darkened(0.20))
	oval(Vector2(-2, -36), Vector2(36, 36), fur)
	oval(Vector2(-10, -46), Vector2(23, 23), fur.lightened(0.10))
	oval(Vector2(0, -23), Vector2(23, 23), fur.lightened(0.45))
	oval(Vector2(-18, -3), Vector2(13, 10), fur.darkened(0.08))
	oval(Vector2(18, -3), Vector2(13, 10), fur.darkened(0.08))
	if active != 3:
		for i in range(75):
			var angle: float = float(i) * 2.39996
			var radius: float = sqrt(float(i) / 75.0) * 32.0
			var point: Vector2 = Vector2(cos(angle) * radius, sin(angle) * radius - 36.0)
			var tint: Color = fur.lightened(0.22)
			tint.a = 0.28
			draw_line(point, point + Vector2(cos(angle) * 2.0, 3.0), tint, 1.0, true)
	else:
		oval(Vector2(-20, -47), Vector2(4, 11), Color(1, 1, 1, 0.24))
	if active == 0:
		draw_line(Vector2(0, -69), Vector2(2, -88), Color("6d9267"), 3.0)
		oval(Vector2(11, -85), Vector2(12, 5), Color("8dab75"))
	elif active == 1:
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -65), Vector2(-6, -84), Vector2(0, -76), Vector2(8, -90), Vector2(15, -66)]), fur.lightened(0.13))
	elif active == 2:
		draw_arc(Vector2(0, -56), 7.0, -0.4, 2.1, 18, Color("f5e8c6"), 3.0, true)
	elif active == 4:
		for i in range(3):
			draw_circle(Vector2(-12.0 + float(i) * 12.0, -68.0), 5.0, fur.darkened(0.16))
	elif active == 5:
		for side in sides:
			for i in range(3):
				draw_circle(Vector2(side * (29.0 + float(i) * 2.0), -33.0 + float(i) * 8.0), 9.0, fur.lightened(0.10))
	var blink: bool = fmod(clock + float(active) * 0.4, 4.7) < 0.14
	var eye_positions: Array[float] = [-13.0, 13.0]
	for x in eye_positions:
		if sleeping or blink or affection_time > 0.0:
			draw_arc(Vector2(x, -40), 5.0, 0.0, PI, 12, Color("49473f"), 2.0, true)
		else:
			oval(Vector2(x + facing, -40), Vector2(5, 6), Color("303c35"))
			draw_circle(Vector2(x + facing - 1.0, -42), 1.8, Color("fff8e8"))
		draw_circle(Vector2(signf(x) * 24.0, -29), 5.0, Color("dca9a0"))
	oval(Vector2(0, -32), Vector2(3.5, 2.5), Color("72605a"))
	draw_arc(Vector2(0, -28), 5.0, 0.0, PI, 12, Color("72605a"), 2.0, true)
	draw_set_transform(Vector2.ZERO)
	if sleeping:
		draw_string(font, Vector2(pet_x + 35.0, 440.0 + sin(clock) * 5.0), "z Z", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 23, Color("88719a"))
	if affection_time > 0.0:
		draw_string(font, Vector2(pet_x - 5.0, ground - 98.0), "<3", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color("bf7d8a"))


# ---------------- SAVING ----------------
func save_pet() -> void:
	if records.size() != 6:
		return
	store_record()
	var data: Dictionary = {
		"version": 2, "active": active, "cozy": cozy,
		"egg_sound_enabled": egg_sound_enabled, "pips": records
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
	else:
		push_warning("Could not write CritterDock save.")


func load_game() -> void:
	var path: String = SAVE_PATH
	if not FileAccess.file_exists(path):
		path = OLD_SAVE_PATH
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("CritterDock save is not a valid dictionary.")
		return
	var data: Dictionary = parsed
	cozy = bool(data.get("cozy", true))
	egg_sound_enabled = bool(data.get("egg_sound_enabled", true))
	if path == OLD_SAVE_PATH:
		records[0] = data
		toast = "Your original Pip has joined the nursery as Moss."
		return
	active = clampi(int(data.get("active", 0)), 0, 5)
	var saved: Variant = data.get("pips", [])
	if saved is Array:
		var saved_records: Array = saved
		for i in range(mini(6, saved_records.size())):
			if saved_records[i] is Dictionary:
				records[i] = saved_records[i]


func reset_pet() -> void:
	if not dead:
		return
	records[active] = fresh_record()
	apply_record()
	kitchen.hide()
	notify("A new " + NAMES[active] + " egg. The other Pips are unchanged.")
	save_pet()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_pet()
		get_tree().quit()
