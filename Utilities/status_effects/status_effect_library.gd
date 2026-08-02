extends Object
class_name StatusEffectLibrary

## Factory for built-in status effects. Shared fields merge from [member STATUS_EFFECT_DATA] / [code]Data/status_effects.csv[/code]; effect-specific numbers are [annotation @export] on each def script.


static func damage_vulnerability() -> DamageVulnerabilityDef:
	return DamageVulnerabilityDef.new()


static func attack_speed_aura() -> AttackSpeedAuraDef:
	return AttackSpeedAuraDef.new()


static func ground_slow() -> GroundSlowDef:
	return GroundSlowDef.new()


static func dot_damage_ramp() -> DotDamageRampDef:
	return DotDamageRampDef.new()


static func stunned() -> StunnedDef:
	return StunnedDef.new()


static func beacon_following() -> BeaconFollowingDef:
	return BeaconFollowingDef.new()


static func aegis() -> AegisDef:
	return AegisDef.new()


static func ablative_armor() -> AblativeArmorDef:
	return AblativeArmorDef.new()


static func infested() -> InfestedDef:
	return InfestedDef.new()


static func spell_immune() -> SpellImmuneDef:
	return SpellImmuneDef.new()


static func fire() -> FireDef:
	return FireDef.new()
