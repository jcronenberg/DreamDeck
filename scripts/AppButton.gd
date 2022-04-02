extends Button

export var app: String
export var arguments: PoolStringArray
export var straight_shell: bool = false

func _ready():
	if !straight_shell:
		arguments.insert(0, app)
	#print(arguments)


func _on_AppButton_pressed():
	if straight_shell:
		OS.execute(app, arguments, false)
	else:
		OS.execute("nohup", arguments, false)
