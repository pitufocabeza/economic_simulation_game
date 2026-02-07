extends Control

func _ready():
	ViewTransition.register_nebula(self)

func _exit_tree():
	ViewTransition.clear_nebula(self)
