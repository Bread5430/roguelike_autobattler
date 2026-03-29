extends Object
class_name StatusEffectTune

## Merges shared CSV fields ([code]effect_id[/code], [code]display_name[/code], [code]icon_path[/code], [code]default_duration[/code], [code]max_stacks[/code]) into a scripted [StatusEffectDef].
## Effect-specific numbers live as [annotation @export] on each subclass. Call at end of [_init] after setting script fallbacks.


static func apply_csv(def: StatusEffectDef, effect_id: StringName) -> void:
	if def == null:
		return
	if not STATUS_EFFECT_DATA.has_entry(str(effect_id)):
		return
	var row := STATUS_EFFECT_DATA.get_entry(str(effect_id))
	var s: String

	s = str(row.get("display_name", "")).strip_edges()
	if s != "":
		def.display_name = s

	s = str(row.get("default_duration", "")).strip_edges()
	if s != "" and s.is_valid_float():
		def.default_duration = float(s)

	s = str(row.get("max_stacks", "")).strip_edges()
	if s != "" and s.is_valid_int():
		def.max_stacks = int(s)

	s = str(row.get("icon_path", "")).strip_edges()
	if s != "" and ResourceLoader.exists(s):
		var res := load(s)
		if res is Texture2D:
			def.icon = res
