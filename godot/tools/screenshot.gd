extends SceneTree
## Saves a screenshot of a scene, for checking art without clicking.
##   godot --path godot -s res://tools/screenshot.gd -- <scene> <out.png>
##       [distance] [pitch] [yaw] [outside|fire|wreck|-] [module id to focus]
## Needs a real window (not --headless) so something renders.


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
	if a.size() > 5 and a[5] == "outside":
		v_out(scene)
	var mode: String = a[5] if a.size() > 5 else ""
	await process_frame  # let the scene's _ready build the ship
	if cam and a.size() > 6:
		var d: ShipDesign = scene._ship.sim.state.design
		for i in d.modules.size():
			if d.modules[i].id == StringName(a[6]):
				cam.focus = ShipView.center(d.rect(i))
				break
	for k in 90:
		if k == 40 and mode == "wreck":  # knock out a few parts mid-ship
			for i in [3, 5, 8]:
				scene._ship.sim.state.damage(i, INF)
		if k == 2 and mode == "thrust":
			scene._fx.thrust_all = true
			v_out(scene)
		if k == 85 and mode == "fire":  # every gun, crewed or not
			var s: ShipState = scene._ship.sim.state
			for i in s.size():
				if s.module(i).firepower > 0.0:
					scene._fx.fire(i)
		await process_frame
	root.get_texture().get_image().save_png(a[1])
	quit()


func v_out(scene: Node) -> void:
	var v := scene.get_node_or_null("Ship")
	(v.hulk if v else scene.get_node("ShipView")).outside = true
