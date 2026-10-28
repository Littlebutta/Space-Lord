class_name RockBumps
extends RefCounted
## Makes asteroids solid for the ship. Each intact module of the ship's
## own piece is a ball; one touching a rock pushes the ship back out and
## bounces it, and a hit faster than SAFE damages that module.

const SAFE := 1.0  # m/s into a rock that does no harm
const HURT := 12.0  # hp per m/s over SAFE
const BOUNCE := 0.3

var field: MiningField


func _init(f: MiningField) -> void:
	field = f


func tick() -> void:
	var ship := field.ship
	var st := ship.sim.state
	var p := st.pieces
	for rock in field.rocks:
		var c: Vector3 = rock.node.position
		var at := Vector2(c.x, c.z)
		for i in st.size():
			if st.hp[i] <= 0.0 or p.piece_of[i] != p.main:
				continue
			var sz := st.design.rect(i).size
			var rm := ShipView.CELL * maxf(sz.x, sz.y) * 0.5
			var off := ship.world(st.center(i)) - at
			var pen: float = rock.r + rm - off.length()
			if pen <= 0.0 or off.length() < 0.001:
				continue
			var n := off.normalized()
			ship.at.origin += n * pen
			var into := -ship.vel.dot(n)
			if into > 0.0:
				ship.vel += n * into * (1.0 + BOUNCE)
				if into > SAFE:
					st.damage(i, (into - SAFE) * HURT)
			break  # one push per rock per tick
