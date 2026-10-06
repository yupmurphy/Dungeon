extends CanvasLayer
## Health and stamina bars plus the death message. Binds to the node in group "player".

@onready var _health_bar: StatBar = $Root/HealthBar
@onready var _stamina_bar: StatBar = $Root/StaminaBar
@onready var _death_panel: Control = $Root/DeathPanel


func _ready() -> void:
	_death_panel.hide()
	_bind_player.call_deferred()


func _bind_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		push_warning("HUD: no node in group 'player' found")
		return
	player.health.health_changed.connect(_on_health_changed)
	player.stamina.stamina_changed.connect(_on_stamina_changed)
	player.died.connect(_death_panel.show)
	_on_health_changed(player.health.current_health, player.health.max_health)
	_on_stamina_changed(player.stamina.current_stamina, player.stamina.max_stamina)


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.set_ratio(current / maximum)


func _on_stamina_changed(current: float, maximum: float) -> void:
	_stamina_bar.set_ratio(current / maximum)
