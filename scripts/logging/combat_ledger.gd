extends RefCounted

## Append-only attribution: later transfers never rewrite previously booked totals.
var _rows := {}

func ensure_actor(actor: Dictionary) -> void:
	if actor.is_empty() or int(actor.get("fighter_uid", -1)) < 0:
		return
	var key := _actor_key(actor)
	if _rows.has(key):
		return
	var row := actor.duplicate(true)
	row.merge({"damage_dealt": 0.0, "damage_taken": 0.0, "healing": 0.0,
		"healing_done": 0.0, "self_damage": 0.0, "unattributed_damage": 0.0})
	_rows[key] = row

func record_damage(source: Dictionary, target: Dictionary, amount: float) -> void:
	if amount <= 0.0:
		return
	_add(target, "damage_taken", amount)
	if source.is_empty():
		_add(target, "unattributed_damage", amount)
	elif _actor_key(source) == _actor_key(target):
		_add(target, "self_damage", amount)
	else:
		_add(source, "damage_dealt", amount)

func record_healing(source: Dictionary, target: Dictionary, amount: float) -> void:
	if amount <= 0.0:
		return
	_add(target, "healing", amount)
	_add(source, "healing_done", amount)

func rows_for(fighter_uid: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in _rows.values():
		if int(row["fighter_uid"]) == fighter_uid:
			result.append(row.duplicate(true))
	result.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		if first["category_id"] != second["category_id"]:
			if first["category_id"] == "body": return true
			if second["category_id"] == "body": return false
			return String(first["category_id"]) < String(second["category_id"])
		return int(first["origin_fighter_uid"]) < int(second["origin_fighter_uid"])
	)
	return result

func totals_for(fighter_uid: int) -> Dictionary:
	var totals := {"damage_dealt": 0.0, "damage_taken": 0.0, "healing": 0.0, "healing_done": 0.0}
	for row in rows_for(fighter_uid):
		for metric in totals:
			totals[metric] += float(row[metric])
	return totals

func _add(actor: Dictionary, metric: String, amount: float) -> void:
	ensure_actor(actor)
	var key := _actor_key(actor)
	if _rows.has(key):
		_rows[key][metric] = float(_rows[key][metric]) + amount

func _actor_key(actor: Dictionary) -> String:
	return "%d/%s/%d" % [int(actor.get("fighter_uid", -1)),
		String(actor.get("category_id", "body")), int(actor.get("origin_fighter_uid", -1))]
