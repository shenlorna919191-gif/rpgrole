extends Node

# 玩家战斗胜利后播放的对话文件路径。
const PLAYER_WIN = "res://dialogue/dialogue_data/player_won.json"
# 玩家战斗失败后播放的对话文件路径。
const PLAYER_LOSE = "res://dialogue/dialogue_data/player_lose.json"

# 战斗场景节点（通过编辑器导出赋值）。
@export var combat_screen: Node2D
# 探索场景节点（通过编辑器导出赋值）。
@export var exploration_screen: Node2D


func _ready() -> void:
	# 监听战斗结束信号，以便切回探索并播放结果对话。
	combat_screen.combat_finished.connect(_on_combat_finished)

	# 遍历探索地图中的所有子节点，给可对话的敌人绑定“对话结束”事件。
	for n in $Exploration/Grid.get_children():
		# 只处理“角色类型”的格子对象。
		if not n.type == n.CellType.ACTOR:
			continue
		# 没有 DialoguePlayer 的对象跳过。
		if not n.has_node(^"DialoguePlayer"):
			continue
		# 对话结束后触发战斗判定。
		n.get_node(^"DialoguePlayer").dialogue_finished.connect(_on_opponent_dialogue_finished.bind(n))

	# 游戏启动时先移除战斗界面，默认留在探索界面。
	remove_child(combat_screen)


func start_combat(combat_actors: Array[PackedScene]) -> void:
	# 先播放淡入黑屏动画，遮罩场景切换。
	$AnimationPlayer.play(&"fade_to_black")
	await $AnimationPlayer.animation_finished
	# 切到战斗场景并初始化双方战斗单位。
	remove_child($Exploration)
	add_child(combat_screen)
	combat_screen.show()
	combat_screen.initialize(combat_actors)
	# 倒放动画实现“从黑屏淡出”的过渡效果。
	$AnimationPlayer.play_backwards(&"fade_to_black")


func _on_opponent_dialogue_finished(opponent: Pawn) -> void:
	# 若该敌人已被击败，则不再重复开战。
	if opponent.lost:
		return
	# 组装战斗双方（玩家 + 当前对手）的战斗场景资源。
	var player: Node2D = $Exploration/Grid/Player
	var combatants: Array[PackedScene] = [player.combat_actor, opponent.combat_actor]
	# 发起战斗。
	start_combat(combatants)


func _on_combat_finished(winner: Combatant, _loser: Combatant) -> void:
	# 战斗结束后移除战斗场景并恢复探索场景。
	remove_child(combat_screen)
	$AnimationPlayer.play_backwards(&"fade_to_black")
	add_child(exploration_screen)
	# 动态创建一个对话播放器，用于展示胜负结果文本。
	var dialogue: Node = load("res://dialogue/dialogue_player/dialogue_player.tscn").instantiate()

	# 根据胜者决定读取“胜利”还是“失败”对话文本。
	if winner.name == "Player":
		dialogue.dialogue_file = PLAYER_WIN
	else:
		dialogue.dialogue_file = PLAYER_LOSE

	# 等过渡动画结束，再展示对话 UI。
	await $AnimationPlayer.animation_finished
	var player: Pawn = $Exploration/Grid/Player
	exploration_screen.get_node(^"DialogueCanvas/DialogueUI").show_dialogue(player, dialogue)
	# 清理战斗中的临时角色和血条 UI，为下次战斗做准备。
	combat_screen.clear_combat()
	# 等待对话结束后释放对话节点，避免资源泄漏。
	await dialogue.dialogue_finished
	dialogue.queue_free()
