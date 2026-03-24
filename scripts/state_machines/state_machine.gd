## Base state machine. Owns the current_state reference, calls enter/exit on
## transitions, and delegates update() and handle_input() to the active state.
class_name StateMachine
extends Node

var current_state: State


func _ready() -> void:
	# Initialize to the first child State node if one exists
	if get_child_count() > 0:
		var first_child: Node = get_child(0)
		if first_child is State:
			current_state = first_child as State
			current_state.sm = self
			current_state.enter()


func change_state(new_state: State) -> void:
	if current_state:
		current_state.exit()
	current_state = new_state
	current_state.sm = self
	current_state.enter()


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)
