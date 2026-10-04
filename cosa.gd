extends Node2D

@onready var animated_sprite = $AnimatedSprite2D

var ball_scene = preload("res://ball.tscn")
var ball = null

var is_dragging = false
var is_idling = false
var is_going_to_corner = false
var is_parked = false
var is_chasing = false
var is_headbutting = false
var is_playing = false
var is_jumping = false
var ball_kicked = false

var drag_offset = Vector2()
var speed = 300.0
var base_speed = 300.0
var direction = Vector2(1, 0)
var min_pos = Vector2()
var max_pos = Vector2()
var window_size = Vector2()
var window_position = Vector2()

var idle_timer = 0.0
var turn_timer = 5.0
var ball_timer = 10.0

var hit_distance = 40.0

var headbutt_timer = 0.0
var headbutt_duration = 0.5
var headbutt_lunge = 40.0
var headbutt_hop = 60.0
var headbutt_start = Vector2()

var play_speed = 450.0
var jump_height = 220.0
var jump_duration = 0.6
var jump_timer = 0.0
var hit_cooldown = 0.0
var hit_margin = 40.0


func _ready() -> void:
	get_viewport().gui_embed_subwindows = false

	var usable = DisplayServer.screen_get_usable_rect()
	window_size = Vector2(DisplayServer.window_get_size())
	min_pos = Vector2(usable.position)
	max_pos = Vector2(usable.end) - window_size
	window_position = Vector2(DisplayServer.window_get_position())
	turn_timer = randf_range(3.0, 8.0)
	ball_timer = randf_range(8.0, 15.0)
	animated_sprite.play("walk")

	spawn_ball()

	if not ("is_launching" in ball):
		print("OJO: la bola usa un ball.gd viejo: ", ball.get_script().resource_path)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not is_headbutting:
				is_dragging = true
				drag_offset = Vector2(DisplayServer.mouse_get_position()) - Vector2(DisplayServer.window_get_position())
		else:
			if is_dragging:
				is_dragging = false
				window_position = Vector2(DisplayServer.window_get_position())

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		is_chasing = false
		is_headbutting = false
		is_playing = false
		is_jumping = false
		if is_parked or is_going_to_corner:
			is_parked = false
			is_going_to_corner = false
			is_idling = false
			speed = base_speed
			animated_sprite.play("walk")
		else:
			is_going_to_corner = true
			is_idling = false
			speed = base_speed
			animated_sprite.play("walk")

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		start_chase()


func _physics_process(delta: float) -> void:
	if is_dragging:
		var mouse_pos = Vector2(DisplayServer.mouse_get_position())
		window_position = mouse_pos - drag_offset
		DisplayServer.window_set_position(Vector2i(window_position))
		return

	if is_headbutting:
		headbutt_timer += delta
		var t = clamp(headbutt_timer / headbutt_duration, 0.0, 1.0)
		var amount = sin(t * PI)   
		window_position.x = headbutt_start.x - amount * headbutt_lunge
		window_position.y = headbutt_start.y - amount * headbutt_hop
		DisplayServer.window_set_position(Vector2i(window_position))

		if t >= 0.5 and not ball_kicked:
			ball_kicked = true
			if ball != null and is_instance_valid(ball):
				ball.kick()

		if t >= 1.0:
			is_headbutting = false
			window_position = headbutt_start
			DisplayServer.window_set_position(Vector2i(window_position))
			animated_sprite.play("walk")
		return

	if is_parked:
		return

	if is_going_to_corner:
		var to_target = max_pos - window_position
		if to_target.length() <= speed * delta:
			window_position = max_pos
			DisplayServer.window_set_position(Vector2i(window_position))
			is_going_to_corner = false
			is_parked = true
			animated_sprite.flip_h = true
			return
		direction = to_target.normalized()
		animated_sprite.flip_h = direction.x < 0
		window_position += direction * speed * delta
		DisplayServer.window_set_position(Vector2i(window_position))
		return

	if ball != null and is_instance_valid(ball) and ball.is_flying:
		if not is_playing:
			start_play()
		process_play(delta)
		return
	elif is_playing:
		stop_play()

	if is_idling:
		idle_timer -= delta
		if idle_timer <= 0:
			is_idling = false
			animated_sprite.play("walk")
			speed = base_speed
		return

	if is_chasing:
		if ball == null or not is_instance_valid(ball) or not ball.is_home:
			is_chasing = false
			return
		var target = Vector2(ball.home.x + ball.window_size.x - hit_distance, max_pos.y)
		var to_target = target - window_position
		if to_target.length() <= speed * delta:
			window_position = target
			DisplayServer.window_set_position(Vector2i(window_position))
			start_headbutt()
			return
		direction = to_target.normalized()
		animated_sprite.flip_h = direction.x < 0
		window_position += direction * speed * delta
		DisplayServer.window_set_position(Vector2i(window_position))
		return

	ball_timer -= delta
	if ball_timer <= 0:
		ball_timer = randf_range(8.0, 15.0)
		if ball != null and is_instance_valid(ball) and ball.is_home:
			start_chase()
			return

	turn_timer -= delta
	if turn_timer <= 0:
		var side = 1 if randf() < 0.5 else -1
		direction = Vector2(side * randf_range(0.5, 1.0), randf_range(-0.3, 0.3)).normalized()
		animated_sprite.flip_h = direction.x < 0
		turn_timer = randf_range(3.0, 8.0)

	window_position += direction * speed * delta

	var hit_x = false
	var hit_y = false

	if window_position.x <= min_pos.x or window_position.x >= max_pos.x:
		window_position.x = clamp(window_position.x, min_pos.x, max_pos.x)
		direction.x *= -1
		animated_sprite.flip_h = direction.x < 0
		hit_x = true

	if direction.y != 0 and (window_position.y <= min_pos.y or window_position.y >= max_pos.y):
		window_position.y = clamp(window_position.y, min_pos.y, max_pos.y)
		direction.y *= -1
		hit_y = true

	DisplayServer.window_set_position(Vector2i(window_position))

	if hit_x or hit_y:
		maybe_idle()


func maybe_idle():
	if randf() < 0.3:
		is_idling = true
		idle_timer = randf_range(1.0, 3.0)
		animated_sprite.play("idle")
		speed = 0


func spawn_ball():
	ball = ball_scene.instantiate()
	add_child(ball)


func start_chase():
	if ball == null or not is_instance_valid(ball) or not ball.is_home:
		return
	is_parked = false
	is_going_to_corner = false
	is_idling = false
	is_headbutting = false
	is_chasing = true
	speed = base_speed
	animated_sprite.play("walk")


func start_headbutt():
	is_chasing = false
	is_headbutting = true
	ball_kicked = false
	headbutt_timer = 0.0
	headbutt_start = window_position
	animated_sprite.flip_h = true   
	animated_sprite.play("idle")


func start_play():
	is_playing = true
	is_chasing = false
	is_idling = false
	is_jumping = false
	hit_cooldown = 0.0
	speed = base_speed
	animated_sprite.play("walk")


func stop_play():
	is_playing = false
	is_jumping = false
	window_position.y = clamp(window_position.y, min_pos.y, max_pos.y)
	speed = base_speed
	animated_sprite.play("walk")


func process_play(delta: float):
	hit_cooldown -= delta

	var ball_center = ball.ball_position + ball.window_size / 2
	var cat_center_x = window_position.x + window_size.x / 2
	var dx = ball_center.x - cat_center_x

	animated_sprite.flip_h = dx < 0

	var launching = ball.is_launching

	if not launching:
		var target_x = clamp(ball_center.x - window_size.x / 2, min_pos.x, max_pos.x)
		window_position.x = move_toward(window_position.x, target_x, play_speed * delta)

	if is_jumping:
		jump_timer += delta
		var t = clamp(jump_timer / jump_duration, 0.0, 1.0)
		window_position.y = max_pos.y - sin(t * PI) * jump_height
		if t >= 1.0:
			is_jumping = false
			window_position.y = max_pos.y
			animated_sprite.play("walk")
	else:
		window_position.y = move_toward(window_position.y, max_pos.y, play_speed * delta)

		var ball_bottom = ball.ball_position.y + ball.window_size.y
		var gap = window_position.y - ball_bottom
		if not launching and ball.velocity.y > 0 and gap > 0 and gap < 300 and abs(dx) < 100 and window_position.y >= max_pos.y - 5:
			is_jumping = true
			jump_timer = 0.0
			if animated_sprite.sprite_frames.has_animation("jump"):
				animated_sprite.play("jump")
			else:
				animated_sprite.play("idle")

	var cat_rect = Rect2(window_position + Vector2(hit_margin, 0), window_size - Vector2(hit_margin * 2, 0))
	var ball_rect = Rect2(ball.ball_position, ball.window_size)
	if hit_cooldown <= 0 and not launching and cat_rect.intersects(ball_rect):
		ball.hit()
		hit_cooldown = 0.4

	DisplayServer.window_set_position(Vector2i(window_position))