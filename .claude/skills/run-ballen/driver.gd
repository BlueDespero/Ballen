extends SceneTree
## Drives Ballen from the command line: loads the main scene, then runs the
## commands given after `--`, one per argument, in order.
##
##   godot --path . -s .claude/skills/run-ballen/driver.gd -- wait:30 ss:menu click:640,305 ss:game quit
##
## Commands (coordinates are viewport pixels, 1280x720 at the default window size):
##   wait:N               let N frames pass
##   until:PATH:PROP=VAL  wait until str(property) == VAL (at most 600 frames)
##   click:X,Y            left press + release at X,Y
##   drag:X1,Y1,X2,Y2     press at X1,Y1, move to X2,Y2 in steps, release
##   touch:X1,Y1,X2,Y2    the same drag with a finger (screen touch + drag events)
##   ss:NAME              save a screenshot to .claude/skills/run-ballen/out/NAME.png
##   tree                 print the scene tree under the current scene
##   get:PATH:PROP        print a property of a node, PATH relative to the current scene
##   scene:RES_PATH       switch to another scene (e.g. res://main_game.tscn)
##   quit                 exit (always appended if missing)

const OUT_DIR: String = "res://.claude/skills/run-ballen/out"
const UNTIL_MAX_FRAMES: int = 600

var _commands: PackedStringArray = []
var _mouse: Vector2 = Vector2.ZERO


func _initialize() -> void:
	_commands = OS.get_cmdline_user_args()
	if _commands.is_empty() or _commands[_commands.size() - 1] != "quit":
		_commands.append("quit")
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	change_scene_to_file(main_scene)
	_run.call_deferred()


func _run() -> void:
	await _frames(2)
	for command: String in _commands:
		print("[driver] ", command)
		var parts: PackedStringArray = command.split(":", true, 2)
		var args: PackedStringArray = parts[1].split(",") if parts.size() > 1 else PackedStringArray()
		match parts[0]:
			"wait":
				await _frames(int(args[0]))
			"click":
				var at: Vector2 = Vector2(float(args[0]), float(args[1]))
				await _move(at)
				await _button(at, true)
				await _button(at, false)
			"drag":
				var from: Vector2 = Vector2(float(args[0]), float(args[1]))
				var to: Vector2 = Vector2(float(args[2]), float(args[3]))
				await _move(from)
				await _button(from, true)
				for i: int in range(1, 11):
					await _move(from.lerp(to, i / 10.0))
				await _button(to, false)
			"touch":
				var from: Vector2 = Vector2(float(args[0]), float(args[1]))
				var to: Vector2 = Vector2(float(args[2]), float(args[3]))
				await _touch(from, true)
				var last: Vector2 = from
				for i: int in range(1, 11):
					var at: Vector2 = from.lerp(to, i / 10.0)
					await _touch_drag(at, at - last)
					last = at
				await _touch(to, false)
			"until":
				var target: PackedStringArray = parts[2].split("=", true, 1) if parts.size() > 2 else PackedStringArray(["", ""])
				var waited: int = 0
				while waited < UNTIL_MAX_FRAMES:
					var watched: Node = current_scene.get_node_or_null(parts[1])
					if watched and str(watched.get(target[0])) == target[1]:
						break
					await process_frame
					waited += 1
				print("[driver] until ", "met" if waited < UNTIL_MAX_FRAMES else "TIMED OUT", " after ", waited, " frames")
			"ss":
				await _screenshot(args[0])
			"tree":
				if current_scene:
					current_scene.print_tree_pretty()
			"get":
				var node: Node = current_scene.get_node_or_null(parts[1])
				var prop: String = parts[2] if parts.size() > 2 else ""
				print("[driver] ", parts[1], ".", prop, " = ", node.get(prop) if node else "<no node>")
			"scene":
				change_scene_to_file(parts[1] + (":" + parts[2] if parts.size() > 2 else ""))
				await _frames(2)
			"quit":
				quit()
				return
			_:
				push_error("[driver] unknown command: " + command)
				quit(1)
				return


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


# Physics picking (CollisionObject2D.input_event) runs on physics frames, so
# every injected event is followed by a physics frame and a process frame.
func _settle() -> void:
	await physics_frame
	await process_frame


func _move(at: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = at - _mouse
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0
	_mouse = at
	# Viewport.get_mouse_position() reads the OS cursor, not injected events,
	# so the real cursor has to move too (gui/ball_view.gd follows the pointer while dragging).
	Input.warp_mouse(at)
	Input.parse_input_event(event)
	await _settle()


func _button(at: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	await _settle()


# With emulate_mouse_from_touch on (the default), Godot turns these into mouse
# events too, which is how the game sees touch.
func _touch(at: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = pressed
	Input.parse_input_event(event)
	await _settle()


func _touch_drag(at: Vector2, relative: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = 0
	event.position = at
	event.relative = relative
	Input.parse_input_event(event)
	await _settle()


func _screenshot(name: String) -> void:
	# --headless never draws, so frame_post_draw would wait forever.
	if DisplayServer.get_name() == "headless":
		push_error("[driver] ss needs a window: run without --headless")
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var path: String = ProjectSettings.globalize_path(OUT_DIR.path_join(name + ".png"))
	var error: Error = root.get_texture().get_image().save_png(path)
	if error == OK:
		print("[driver] saved ", path)
	else:
		push_error("[driver] screenshot failed: " + error_string(error))
