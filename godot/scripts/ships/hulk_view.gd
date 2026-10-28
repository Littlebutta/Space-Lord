class_name HulkView
extends Node3D
## Draws a live ship that can break apart: one node per piece, built
## from ShipView's parts, moved each frame by the piece's drift. Wrecked
## modules leave a hole; cut edges get their own rounded corners.

var pieces: ShipPieces
var _nodes: Array[Node3D] = []


func bind(p: ShipPieces) -> void:
	pieces = p
	p.changed.connect(rebuild)
	rebuild()


func rebuild() -> void:
	for n in _nodes:
		n.queue_free()
	_nodes.clear()
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
			node.add_child(ShipView.make_part(d.modules[i], d.rect(i), d.turns[i],
					d.theme(i), filled))
		add_child(node)
		_nodes.append(node)
	_process(0.0)


func _process(_delta: float) -> void:
	for k in mini(_nodes.size(), pieces.pieces.size()):
		_nodes[k].transform = ShipPieces.to_3d(pieces.xf[pieces.pieces[k][0]])
