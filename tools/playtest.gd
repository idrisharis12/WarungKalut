extends SceneTree

var fails := 0

func check(c: bool, msg: String) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1


func _initialize() -> void:
	var k: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(k)
	await process_frame
	await process_frame
	var chef: Chef
	for c in k.get_children():
		if c is Chef:
			chef = c
	check(chef != null, "chef spawned")
	check(chef.stations.size() == 38, "stations = %d (want 38)" % chef.stations.size())
	var game: Game = k.game
	game._card_open = false
	game.card.hide()
	paused = false

	var by := {}
	for s in chef.stations:
		var key: String = s.crate_id if s.kind == Station.Kind.CRATE else str(s.kind)
		if not by.has(key):
			by[key] = s

	# batter -> mixer -> mixed
	var batter: Ingredient = by["batter"].take_from_crate()
	chef.add_child(batter)
	await process_frame
	var mixer: Station = by[str(Station.Kind.MIXER)]
	batter.mix_seconds = 0.3
	check(mixer.accepts(batter), "mixer accepts raw batter")
	mixer.put(batter)
	mixer.work_hold(true)
	for i in 400:
		await process_frame
	check(batter.state == "mixed", "batter mixed (state=%s)" % batter.state)
	mixer.work_hold(false)

	# chicken -> fry -> cooked
	var ch: Ingredient = by["chicken"].take_from_crate()
	chef.add_child(ch)
	await process_frame
	var fry: Station = by[str(Station.Kind.FRY)]
	ch.cook_seconds = 0.5
	fry.put(ch)
	for i in 300:
		await process_frame
	check(ch.state == "cooked", "chicken cooked (state=%s)" % ch.state)

	# plate it
	var plate: Vessel = by[str(Station.Kind.PLATES)].take_from_crate()
	chef.add_child(plate)
	await process_frame
	var b2: Ingredient = fry.take() as Ingredient
	check(plate.can_add(b2), "plate accepts cooked chicken")
	plate.add(b2)
	var mx: Ingredient = mixer.take() as Ingredient
	check(plate.can_add(mx), "plate accepts mixed batter")
	plate.add(mx)
	check(plate.contents.size() == 2, "plate has 2 items: %s" % plate.summary())

	# order + serve
	game.orders.clear()
	game.orders.append({"dish": "roti_jala", "left": 60.0, "total": 80.0})
	var before := game.point
	game.serve(plate.contents)
	check(game.point > before, "roti jala scored (%.1f -> %.1f)" % [before, game.point])
	game.serve(["rice:cooked"])
	check(game.combo == 0, "wrong dish resets combo")

	# teh tarik
	var glass: Vessel = by["glass"].take_from_crate()
	chef.add_child(glass)
	await process_frame
	var tarik: Station = by[str(Station.Kind.TARIK)]
	check(tarik.accepts(glass), "tarik accepts empty glass")
	tarik.put(glass)
	for i in 8:
		tarik.work_press()
	check(glass.contents == ["teh:tarik"], "tea pulled: %s" % str(glass.contents))
	check(by[str(Station.Kind.HATCH)].accepts(glass), "hatch accepts teh tarik")

	# dirty plate loop: hatch -> return -> wash -> clean stack
	var ret: Station = by[str(Station.Kind.RETURN)]
	var wash: Station = by[str(Station.Kind.WASH)]
	var pl: Station = by[str(Station.Kind.PLATES)]
	var stock0 := pl.stock
	check(stock0 == 3, "clean stack after taking one plate: %d" % stock0)
	k._vessel_gone(true, 0.05)
	await create_timer(0.3).timeout
	check(ret.stock == 1, "dirty plate returned (%d)" % ret.stock)
	var dp: Vessel = ret.take_from_crate() as Vessel
	chef.add_child(dp)
	await process_frame
	check(dp.dirty and not dp.can_add(ingredient_for_test()), "dirty plate refuses food")
	check(wash.accepts(dp) and not by[str(Station.Kind.HATCH)].accepts(dp), "sink takes dirty plate, hatch refuses it")
	wash.put(dp)
	wash.wash_seconds = 0.2
	wash.wash_left = 0.2
	wash.work_hold(true)
	for i in 120:
		await process_frame
	check(pl.stock == stock0 + 1, "washed plate back in clean stack (%d)" % pl.stock)

	# cooking rules
	var wok: Station
	var pot: Station
	for st in chef.stations:
		if st.kind == Station.Kind.FRY and wok == null:
			wok = st
		if st.kind == Station.Kind.BOIL and pot == null:
			pot = st
	var chk := ingredient_for_test()
	var ri := Ingredient.new()
	ri.ingredient_id = "rice"
	var an := Ingredient.new()
	an.ingredient_id = "anchovy"
	check(wok.accepts(chk) and not pot.accepts(chk), "chicken fries, never boils")
	check(pot.accepts(ri) and not wok.accepts(ri), "rice boils, never fries")
	check(wok.accepts(an) and not pot.accepts(an), "anchovy fries, never boils")

	# police thresholds
	game.point = 60.0
	game._change(0.0)
	check(game.police_armed and not game.police_active, "armed above 50, no cop yet")
	game._change(-35.0)
	check(game.warned and not game.police_active, "warning siren at 25, no cop yet")
	game._change(-15.0)
	check(game.police_active, "cop called below 15")
	game._change(30.0)
	check(not game.police_active, "cop leaves at 30")
	game._change(-30.0)
	game._change(-40.0)
	check(game.point == 0.0 and game.police_active, "cop at 0")
	game.point = 50.0
	game.police_active = false

	# cop catches chef
	var kc: Kitchen = k
	kc._police_call()
	kc._cop.position = chef.global_position + Vector3(0.3, 0, 0)
	kc._process(0.1)
	check(game.over and game.end_panel.visible, "cop catches the chef: busted screen")
	game.over = false
	game.end_panel.hide()
	if is_instance_valid(kc._cop):
		kc._cop.queue_free()
		kc._cop = null
	kc._cop_chase = false
	game.police_active = false
	game.point = 20.0

	# fire
	var stove: Station
	for st in chef.stations:
		if st.kind == Station.Kind.FRY:
			stove = st
			break
	var p0: float = game.point
	stove._ignite()
	check(stove.on_fire and game.point < p0, "burning starts a fire and costs meter")
	check(not stove.accepts(ingredient_for_test()), "burning stove accepts nothing")
	stove.work_hold(true)
	await create_timer(2.0).timeout
	check(not stove.on_fire, "holding Q puts the fire out")

	# levels + hazards
	check(game.level["name"] == "Morning Stall", "level 0 loaded")
	k._on_stage(3)
	check(k.puddle_on and k._cart != null, "boss level has puddle and cart")
	check(Recipes.LEVELS[3]["dishes"].size() == 4 and Recipes.LEVELS[3]["boss"], "boss level has every dish")
	game.point = 100.0
	game.police_armed = true
	game.level = game.level.duplicate()
	game.level["hold"] = 0.1
	game.hold_100 = 0.0
	game._process(0.2)
	check(game.over and Recipes.unlocked >= 2, "level won, next unlocked (%d)" % Recipes.unlocked)
	check(game.end_panel.visible, "end panel shown")
	game.card.hide()
	for id in Recipes.DISHES:
		check(RecipeView.page(id) != null, "recipe page builds: " + id)

	print("FAILS: ", fails)
	quit(fails)


func ingredient_for_test() -> Ingredient:
	var i := Ingredient.new()
	i.ingredient_id = "chicken"
	return i
