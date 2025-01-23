extends Area3D

signal show_interaction_text(text: String)
signal hide_interaction_text

func _on_body_entered(body) -> void:
    if body.is_in_group("player"):
        show_interaction_text.emit("A Powerful magic seems to block the way")

func _on_body_exited(body) -> void:
    if body.is_in_group("player"):
        hide_interaction_text.emit()
