@tool
extends EditorPlugin

var export_plugin: PlayCoreExportPlugin


func _enter_tree():
	export_plugin = PlayCoreExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree():
	remove_export_plugin(export_plugin)
	export_plugin = null


class PlayCoreExportPlugin extends EditorExportPlugin:
	var _plugin_name = "NineRiversPlayCore"

	func _supports_platform(platform):
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(platform, debug):
		if debug:
			return PackedStringArray([_plugin_name + "/bin/debug/" + _plugin_name + "-debug.aar"])
		return PackedStringArray([_plugin_name + "/bin/release/" + _plugin_name + "-release.aar"])

	# Same version as android_plugins/playcore/build.gradle.
	func _get_android_dependencies(platform, debug):
		return PackedStringArray([
			"com.google.android.play:app-update:2.1.0",
			"com.google.android.play:review:2.0.2",
		])

	func _get_name():
		return _plugin_name
