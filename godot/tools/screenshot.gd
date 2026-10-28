extends SceneTree
## Saves a screenshot of a scene, for checking art without clicking.
##   godot --path godot -s res://tools/screenshot.gd -- <scene> <out.png>
##       [distance] [pitch] [yaw] [outside]
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
		var v := scene.get_node_or_null("Ship")
		(v.hulk if v else scene.get_node("ShipView")).outside = true
	for k in 90:
		await process_frame
	root.get_texture().get_image().save_png(a[1])
	quit()
