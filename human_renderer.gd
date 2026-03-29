class_name HumanRenderer
extends Node3D

const _EMOJI_DEFAULT := preload("res://Emoji0.png")
const _EMOJI_DEAD := preload("res://Emoji_dead.png")
const _EMOJI_RANDOM: Array[Texture2D] = [
	preload("res://Emoji1.png"),
	preload("res://Emoji2.png"),
	preload("res://Emoji3.png"),
	preload("res://Emoji4.png"),
]

@onready var _body_mesh: MeshInstance3D = $Skeleton3D/身体

var _body_material: StandardMaterial3D


func _ready() -> void:
	var base_material: StandardMaterial3D = _body_mesh.get_surface_override_material(0) as StandardMaterial3D
	if base_material == null:
		base_material = _body_mesh.mesh.surface_get_material(0) as StandardMaterial3D
	_body_material = base_material.duplicate(true) as StandardMaterial3D
	_body_material.albedo_texture = _EMOJI_DEFAULT
	_body_mesh.set_surface_override_material(0, _body_material)


func apply_random_emoji_one_to_four() -> void:
	_body_material.albedo_texture = _EMOJI_RANDOM[randi() % _EMOJI_RANDOM.size()]


func apply_emoji_dead() -> void:
	_body_material.albedo_texture = _EMOJI_DEAD
