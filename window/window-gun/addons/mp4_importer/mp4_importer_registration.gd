@tool
extends EditorPlugin

var importer

func _enter_tree():
	importer = preload("res://addons/mp4_importer/mp4_importer.gd").new()
	add_import_plugin(importer)

func _exit_tree():
	remove_import_plugin(importer)
	importer = null
