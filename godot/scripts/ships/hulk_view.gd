class_name HulkView
extends Node3D
## Draws a live ship that can break apart: one node per piece, built
## from ShipView's parts, moved each frame by the piece's drift. Wrecked
## modules leave a hole; cut edges get their own rounded corners.

var pieces: ShipPieces
var outside := false: set = set_outside  # hull shells over the decks
var _nodes: Array[Node3D] = []
var _parts := {}  # module index -> its part node


func bind(p: ShipPieces) -> void:
	pieces = p
	p.changed.connect(rebuild)
	rebuild()


func rebuild() -> void:
	for n in _nodes:
		n.queue_free()
	_nodes.clear()
	_parts.clear()
	var d := pieces.design
	for mods in pieces.pieces:
		var filled := {}
		for i in mods:
			var r := d.rect(i)
			for x in range(r.position.x, r.end.x):
				for y in range(r.position.y, r.end.y):
					filled[Vector2i(x, y)] = i
		var node := Node3D.new()
		for i in mods:
			var part := ShipView.make_part(d.modules[i], d.rect(i), d.turns[i],
					d.theme(i), filled)
			node.add_child(part)
			_parts[i] = part
		var shell := MeshInstance3D.new()
		shell.name = &"Shell"
		shell.mesh = HullShell.build(d, ShipView.DECK * 0.5, mods)
		shell.material_override = ModelSkin.shell_material(d.theme(mods[0]))
		node.add_child(shell)
		add_child(node)
		_nodes.append(node)
	set_outside(outside)
	_process(0.0)


## Module i's part node, or null when it's been destroyed.
func part(i: int) -> Node3D:
	var n = _parts.get(i)  # untyped: may hold a freed node
	return n if is_instance_valid(n) and not n.is_queued_for_deletion() else null


func set_outside(v: bool) -> void:
	outside = v
	for n in _nodes:
		ModelSkin.set_outside(n, v)
		n.get_node(^"Shell").visible = v


func _process(_delta: float) -> void:
	for k in mini(_nodes.size(), pieces.pieces.size()):
		_nodes[k].transform = ShipPieces.to_3d(pieces.xf[pieces.pieces[k][0]])
