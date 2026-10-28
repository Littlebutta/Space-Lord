extends SceneTree
## Saves a screenshot of a scene, for checking art without clicking.
##   godot --path godot -s res://tools/screenshot.gd -- <scene> <out.png>
##       [distance] [pitch] [yaw] [outside|fire|wreck|thrust|-] [module id]
## Needs a real window (not --headless) so something renders. Modes act
## on a crew sandbox scene ($Ship); the module id centres the camera.


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var scene: Node = load(a[0]).instantiate()
	root.add_child(scene)
	var cam := scene.get_node_or_null("Camera")
	if cam and a.size() > 2:
		cam.distance = float(a[2])
	if cam and a.size() > 3:
		cam.pitch_deg = float(a[3])
	if cam and a.size() > 4:
		cam.yaw_deg = float(a[4])
	var mode: String = a[5] if a.size() > 5 else ""
	var ship: ShipBody = scene.get_node_or_null("Ship")
	await process_frame  # let the scene's _ready build the ship
	if mode in ["outside", "thrust"]:
		(ship.hulk if ship else scene.get_node("ShipView")).outside = true
	if cam and ship and a.size() > 6:
		var d := ship.sim.state.design
		for i in d.modules.size():
			if d.modules[i].id == StringName(a[6]):
				var c := ship.world(Vector2(ShipView.center(d.rect(i)).x, ShipView.center(d.rect(i)).z))
				cam.focus = Vector3(c.x, 0.0, c.y)
				break
	for k in 90:
		_act(ship, mode, k)
		await process_frame
	root.get_texture().get_image().save_png(a[1])
	quit()


func _act(ship: ShipBody, mode: String, k: int) -> void:
	if ship == null:
		return
	var s := ship.sim.state
	if k == 2 and mode == "thrust":
		ship.fx.thrust_all = true
	if k == 40 and mode == "wreck":  # knock out a few parts mid-ship
		for i in [3, 5, 8]:
			s.damage(i, INF)
	if k == 84 and mode == "fire":  # every gun, crewed or not
		for i in s.size():
			if s.module(i).firepower > 0.0:
				ship.fx.fire(i)
