## Base class all states extend. Override enter/exit/update/handle_input.
class_name State
extends Node

var sm: StateMachine


func enter() -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass
