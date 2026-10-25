extends Node

const PORT: int = 42425
const APP_ID: String = "critterdock_voice_v1"

# These match the Mode enum in your current CritterDock.gd.
const MODE_IDLE: int = 0
const MODE_FOLLOW: int = 1
const MODE_PLAY: int = 2
const MODE_SLEEP: int = 3
const MODE_EAT: int = 4

var receiver: PacketPeerUDP = PacketPeerUDP.new()
var game: Node
var voice_label: Label

var connected: bool = false
var heartbeat_age: float = 999.0
var last_heard: String = ""
var heard_age: float = 999.0
var command_cooldown: float = 0.0


func _ready() -> void:
	game = get_parent()

	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)

	voice_label = Label.new()
	voice_label.position = Vector2(30.0, 625.0)
	voice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	voice_label.add_theme_font_size_override("font_size", 15)
	voice_label.add_theme_color_override(
		"font_color",
		Color("493e39")
	)
	canvas.add_child(voice_label)

	if not game.has_method("change_mode"):
		voice_label.text = "Voice: attach VoiceListener under the CritterDock root."
		set_process(false)
		return

	# Listen only on this computer, not on the network.
	var result: Error = receiver.bind(PORT, "127.0.0.1")

	if result != OK:
		voice_label.text = "Voice: could not open local port %d." % PORT
		push_error(
			"CritterDock voice port failed: %s"
			% error_string(result)
		)
		set_process(false)
		return

	voice_label.text = "Voice: waiting for the microphone helper..."


func _process(delta: float) -> void:
	heartbeat_age += delta
	heard_age += delta
	command_cooldown = maxf(0.0, command_cooldown - delta)

	# Limit work per frame.
	var processed: int = 0

	while receiver.get_available_packet_count() > 0 and processed < 32:
		processed += 1

		var packet: PackedByteArray = receiver.get_packet()

		if receiver.get_packet_ip() != "127.0.0.1":
			continue

		if packet.size() > 4096:
			continue

		var parsed: Variant = JSON.parse_string(
			packet.get_string_from_utf8()
		)

		if not (parsed is Dictionary):
			continue

		var data: Dictionary = parsed

		if str(data.get("app", "")) != APP_ID:
			continue

		var kind: String = str(data.get("kind", ""))

		if kind == "stopped":
			connected = false
			heartbeat_age = 999.0
			continue

		if kind != "heartbeat" and kind != "heard" and kind != "command":
			continue

		connected = true
		heartbeat_age = 0.0

		if kind == "heard":
			last_heard = str(data.get("text", "")).left(80)
			heard_age = 0.0

		elif kind == "command":
			last_heard = str(data.get("text", "")).left(80)
			heard_age = 0.0
			handle_command(str(data.get("action", "")))

	if heartbeat_age > 3.0:
		connected = false

	if not connected:
		voice_label.text = "Voice: helper disconnected / start critter_voice.py"
	elif heard_age < 6.0:
		voice_label.text = "Voice heard: " + last_heard
	else:
		voice_label.text = "Voice: listening / say a command, then pause"


func handle_command(action: String) -> void:
	if command_cooldown > 0.0:
		return

	if not bool(game.get("hatched")):
		game.call("notify", "Hatch your egg before giving voice commands.")
		return

	if bool(game.get("dead")):
		return

	match action:
		"follow":
			game.call("change_mode", MODE_FOLLOW)
			game.call("notify", "Pip heard you: come here!")

		"sleep":
			game.call("change_mode", MODE_SLEEP)

		"play":
			game.call("change_mode", MODE_PLAY)
			game.call("notify", "Pip heard you: play time!")

		"eat":
			var food_amount: float = float(game.get("portions"))
			var food_freshness: float = float(game.get("freshness"))

			if food_amount > 0.0 and food_freshness > 0.0:
				game.call("change_mode", MODE_EAT)
				game.call("notify", "Pip heard you: dinner time!")
			else:
				game.call("notify", "Prepare a fresh meal for Pip first.")

		"praise":
			# Update the existing typed needs array in place.
			game.needs[4] = minf(
				100.0,
				float(game.needs[4]) + 12.0
			)
			game.call("notify", "Pip seems pleased to hear your praise.")

		"rest":
			game.call("change_mode", MODE_IDLE)
			game.call("notify", "Pip goes back to exploring.")

		_:
			return

	command_cooldown = 1.5


func _exit_tree() -> void:
	receiver.close()
