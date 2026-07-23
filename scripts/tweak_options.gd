@tool
extends Resource
class_name TweakOptions
## Shared option resource for editor-tweaks (ProjectSettings + runtime).
##
##[br][color=tomato]FIXME[/color]: [enum LogLevel] is sequential (0..6) while
## [member verbosity] is [code]@export_flags[/code] (bit values). [EneLog]
## uses yet another bitmask scheme. Colour lookup via [method get_colour]
## only matches sequential keys — flag verbosity will often miss.
##[br][color=goldenrod]TODO[/color]: Align exports with the single logger API
## once print_helper / EneLog are merged.


# FIXME: sequential; does not match @export_flags values on verbosity.
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

# NOTE: flag values ≠ LogLevel enum ordinals above (see class FIXME).
@export_flags(
	"CRITICAL:1", "ERROR:2", "WARNING:4", "DEFAULT:8",
	"NOTICE:16", "DEBUG:32", "TRACE:64")
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
var use_monospace_glyphs:bool = false

@export
var add_rich_paste:bool = false

@export
var enable_linespacing_tweaks:bool = false

@export
var adjust_linespacing_above:int = 0

@export
var adjust_linespacing_below:int = 0

## Add a function to the code editor to add a call to trace with all the function arguments in a dictionary.
@export
var make_method_trace_line:bool = false

#endregion Code Editor

#@export_tool_button("Dump Icons to EditorLog")
@export_custom( PROPERTY_HINT_TOOL_BUTTON, "Dump Editor Icons",
	PROPERTY_USAGE_EDITOR)
var icons_dump:Callable
