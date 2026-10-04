extends Window

@onready var sprite = $Sprite2D

var window_size = Vector2()
var ball_position = Vector2()
var velocity = Vector2()
var throw_velocity = Vector2()
var drag_offset = Vector2()
var gravity = 1500.0
var return_speed = 500.0
var min_pos = Vector2()
var max_pos = Vector2()
var home = Vector2()

var is_home = true
var is_dragging = false
var is_flying = false
var is_returning = false
var is_launching = false


var near_distance = 450.0

var launch_time = 1.0
var launch_timer = 0.0
var launch_start = Vector2()
var launch_velocity = Vector2()

var rest_time = 2.0
var rest_timer = 0.0


func _init() -> void:
	borderless = true
	transparent = true
	transparent_bg = true
	always_on_top = true


func _ready() -> void:
	var usable = DisplayServer.screen_get_usable_rect()
	window_size = Vector2(size)
	min_pos = Vector2(usable.position)
	max_pos = Vector2(usable.end) - window_size
	home = Vector2(min_pos.x, max_pos.y)
	ball_position = home
	position = Vector2i(home)
	sprite.position = window_size / 2


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			is_home = false
			is_flying = false
			is_returning = false
			is_launching = false
			velocity = Vector2.ZERO
			throw_velocity = Vector2.ZERO
			drag_offset = Vector2(DisplayServer.mouse_get_position()) - ball_position
		elif is_dragging:
			is_dragging = false
			is_flying = true
			rest_timer = 0.0
			velocity = throw_velocity.limit_length(2500.0)


func kick() -> void:
	is_home = false
	is_flying = true
	is_returning = false
	is_launching = false
	rest_timer = 0.0
	velocity = Vector2(randf_range(500, 800), -randf_range(900, 1100))


func hit() -> void:
	is_flying = true
	is_returning = false
	rest_timer = 0.0

	var distance = ball_position.x - home.x
	if distance < near_distance:
		launch_to_corner()
	else:
		var step = randf_range(250, 450)
		var target_x = max(home.x + 100.0, ball_position.x - step)
		velocity.y = -randf_range(900, 1100)
		var flight_time = 2.0 * abs(velocity.y) / gravity
		velocity.x = (target_x - ball_position.x) / flight_time


func launch_to_corner() -> void:
	is_launching = true
	launch_timer = 0.0
	launch_start = ball_position
	launch_velocity.x = (home.x - ball_position.x) / launch_time
	launch_velocity.y = (home.y - ball_position.y - 0.5 * gravity * launch_time * launch_time) / launch_time


func _physics_process(delta: float) -> void:
	if is_dragging:
		var new_pos = Vector2(DisplayServer.mouse_get_position()) - drag_offset
		new_pos.x = clamp(new_pos.x, min_pos.x, max_pos.x)
		new_pos.y = clamp(new_pos.y, min_pos.y, max_pos.y)
		throw_velocity = throw_velocity.lerp((new_pos - ball_position) / delta, 0.3)
		ball_position = new_pos
		position = Vector2i(ball_position)
		return

	if is_launching:
		launch_timer += delta
		var t = min(launch_timer, launch_time)
		var previous_x = ball_position.x
		ball_position.x = launch_start.x + launch_velocity.x * t
		ball_position.y = launch_start.y + launch_velocity.y * t + 0.5 * gravity * t * t
		sprite.rotation += (ball_position.x - previous_x) / (window_size.x / 2)

		if launch_timer >= launch_time:
			ball_position = home
			is_launching = false
			is_flying = false
			is_home = true
			velocity = Vector2.ZERO
			sprite.rotation = 0
		position = Vector2i(ball_position)
		return

	if is_flying:
		velocity.y += gravity * delta
		ball_position += velocity * delta
		var on_floor = false

		if ball_position.x <= min_pos.x:
			ball_position.x = min_pos.x
			velocity.x *= -0.7
		if ball_position.x >= max_pos.x:
			ball_position.x = max_pos.x
			velocity.x *= -0.7

		if ball_position.y <= min_pos.y:
			ball_position.y = min_pos.y
			velocity.y = abs(velocity.y) * 0.5

		if ball_position.y >= max_pos.y:
			ball_position.y = max_pos.y
			on_floor = true
			if abs(velocity.y) < 150:
				velocity.y = 0
				velocity.x = move_toward(velocity.x, 0, 600 * delta)
			else:
				velocity.y *= -0.6

		sprite.rotation += velocity.x * delta / (window_size.x / 2)

		if on_floor and velocity.length() < 20:
			rest_timer += delta
		else:
			rest_timer = 0.0
		if rest_timer > rest_time:
			is_flying = false
			is_returning = true

		position = Vector2i(ball_position)
		return

	if is_returning:
		var previous_x = ball_position.x
		ball_position = ball_position.move_toward(home, return_speed * delta)
		sprite.rotation += (ball_position.x - previous_x) / (window_size.x / 2)
		position = Vector2i(ball_position)

		if ball_position == home:
			is_returning = false
			is_home = true
			sprite.rotation = 0