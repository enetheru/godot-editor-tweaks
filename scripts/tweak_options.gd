@tool
extends Resource
class_name TweakOptions

enum LogLevel {
	SILENT = 0,
	CRITICAL = 1,
	ERROR = 2,
	WARNING = 3,
	NOTICE = 4,
	DEBUG = 5,
	TRACE = 6,
}

@export
## A variable to help me turn on and off debug features and tests.
var debug:bool = false

@export
## Turn on and off experimental and development features.
var experimental:bool = false

@export_flags( "CRITICAL:1","ERROR:2","WARNING:4","DEFAULT:8","NOTICE:16","DEBUG:32","TRACE:64")
var verbosity:int = 0


func                        __Output_Log_____________              ()->void:pass
#region Output Log
#MARK: Output Log
##                                                    [br]
## │  ___       _             _     _                 [br]
## │ / _ \ _  _| |_ _ __ _  _| |_  | |   ___  __ _    [br]
## │| (_) | || |  _| '_ \ || |  _| | |__/ _ \/ _` |   [br]
## │ \___/ \_,_|\__| .__/\_,_|\__| |____\___/\__, |   [br]
## ╰───────────────|_|───────────────────────|___/─── [br]
## Output Log By-Line
##
## Output Log Description
@export_category("OutputLog")

@export
var enable_ligatures:bool = false

@export
var add_rotate_bbcode_effect:bool = false

@export
var enable_output_search_bar:bool = false

@export
var enable_clickable_url_links:bool = false

# log Colours
@export_group("Colours", "color_")
@export
var color_notice_critical:Color

@export
var color_notice_error:Color

@export
var color_notice_warning:Color

@export
var color_notice_notice:Color

@export
var color_notice_debug:Color

@export
var color_notice_trace:Color

#endregion Output Log
func get_colour( lvl:int ) -> Color:
	match lvl:
		LogLevel.CRITICAL: return color_notice_critical
		LogLevel.ERROR: return color_notice_error
		LogLevel.WARNING: return color_notice_warning
		LogLevel.NOTICE: return color_notice_notice
		LogLevel.DEBUG: return color_notice_debug
		LogLevel.TRACE: return color_notice_trace

	return Color.WHITE


func                        __Code_Editor____________              ()->void:pass
#region Code Editor
#MARK: Code Editor
## │  ___         _       ___    _ _ _              [br]
## │ / __|___  __| |___  | __|__| (_) |_ ___ _ _    [br]
## │| (__/ _ \/ _` / -_) | _|/ _` | |  _/ _ \ '_|   [br]
## │ \___\___/\__,_\___| |___\__,_|_|\__\___/_|     [br]
## ╰─────────────────────────────────────────────── [br]
## Code Editor By-Line
##
## Code Editor Description
@export_category("CodeEditor")

@export
var use_monospace_glyphs : bool = false

@export
var add_rich_paste:bool = false

@export
var enable_linespacing_tweaks:bool = false

@export
var adjust_linespacing_above : int = 0

@export
var adjust_linespacing_below : int = 0

#endregion Code Editor


func _init() -> void:
	if Engine.is_editor_hint():
		var _es := EditorInterface.get_editor_settings()
		if color_notice_critical == Color.BLACK:
			color_notice_critical = _es.get_setting("text_editor/theme/highlighting/comment_markers/critical_color")
		if color_notice_error == Color.BLACK:
			color_notice_error = _es.get_setting("text_editor/theme/highlighting/comment_markers/critical_color")
		if color_notice_warning == Color.BLACK:
			color_notice_warning = _es.get_setting("text_editor/theme/highlighting/comment_markers/warning_color")
		if color_notice_notice == Color.BLACK:
			color_notice_notice = _es.get_setting("text_editor/theme/highlighting/comment_markers/notice_color")
		if color_notice_debug == Color.BLACK:
			color_notice_debug = _es.get_setting("text_editor/theme/highlighting/doc_comment_color")
		if color_notice_trace == Color.BLACK:
			color_notice_trace = _es.get_setting("text_editor/theme/highlighting/comment_color")
