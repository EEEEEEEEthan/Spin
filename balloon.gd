extends RigidBody3D


func _ready() -> void:
	add_to_group("balloon")


func explode() -> void:
	queue_free()
