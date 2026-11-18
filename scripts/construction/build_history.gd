class_name BuildHistory
extends RefCounted
## Pila de operaciones para deshacer y rehacer.
## Cada operación es un diccionario de datos (colocar, quitar, mover, variante,
## pintar) que el mundo sabe aplicar y revertir. Es el mismo formato que usará
## la sincronización por cambios de la Fase 4.

signal changed

const LIMIT := 150

var world: Node
var _undo: Array = []
var _redo: Array = []


func _init(w: Node) -> void:
	world = w


## Aplica una operación nueva y la apila.
func run(op: Dictionary) -> void:
	world.apply_op(op)
	_undo.push_back(op)
	if _undo.size() > LIMIT:
		_undo.pop_front()
	_redo.clear()
	changed.emit()


func undo() -> Dictionary:
	if _undo.is_empty():
		return {}
	var op: Dictionary = _undo.pop_back()
	world.revert_op(op)
	_redo.push_back(op)
	changed.emit()
	return op


func redo() -> Dictionary:
	if _redo.is_empty():
		return {}
	var op: Dictionary = _redo.pop_back()
	world.apply_op(op)
	_undo.push_back(op)
	changed.emit()
	return op


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func size() -> int:
	return _undo.size()
