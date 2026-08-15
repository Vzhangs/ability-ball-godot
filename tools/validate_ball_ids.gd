extends SceneTree

func _init() -> void:
	BallRegistry.reload()
	if not BallRegistry.is_valid():
		printerr("球模块注册失败：%s" % ", ".join(BallRegistry.validation_errors()))
		quit(2)
		return
	var requested := {}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--left="):
			requested["left"] = argument.trim_prefix("--left=")
		elif argument.begins_with("--right="):
			requested["right"] = argument.trim_prefix("--right=")
	for side in ["left", "right"]:
		if not requested.has(side) or not BallRegistry.has_id(String(requested[side])):
			printerr("未知或缺失的%s球 ID。可用：%s" % [side, " ".join(BallRegistry.ids())])
			quit(2)
			return
	print("球 ID 校验通过：%s VS %s" % [requested["left"], requested["right"]])
	quit(0)
