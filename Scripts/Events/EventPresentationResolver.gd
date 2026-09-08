class_name EventPresentationResolver
extends RefCounted


static func resolve_instance_content(instance: EventInstance) -> Dictionary:
	if instance == null or EventManager.registry == null:
		return {}

	return resolve_content(
		EventManager.registry.get_content(instance.event_id),
		instance.participants,
		instance.context
	)


static func resolve_content(
	content: Dictionary,
	participants: Dictionary,
	context: Dictionary
) -> Dictionary:
	var resolved := content.duplicate(true)
	var replacements := _build_replacements(participants, context)

	for field_name in ["title", "subtitle", "description"]:
		if typeof(resolved.get(field_name, null)) != TYPE_STRING:
			continue

		var text := String(resolved[field_name])
		for token in replacements:
			text = text.replace(
				"{%s}" % String(token),
				String(replacements[token])
			)
		resolved[field_name] = text

	return resolved


static func _build_replacements(
	participants: Dictionary,
	context: Dictionary
) -> Dictionary:
	var replacements: Dictionary = {}

	for participant_name_value in participants:
		var participant_name := String(participant_name_value)
		var participant_value = participants[participant_name]
		if typeof(participant_value) not in [TYPE_INT, TYPE_FLOAT]:
			continue
		var character := CharacterManager.get_character_by_id(
			int(participant_value)
		)
		var resolved_name := String(character.get("first_name", ""))
		if resolved_name.is_empty():
			continue
		replacements["%s_name" % participant_name] = resolved_name
		if participant_name == "primary":
			replacements["character_name"] = resolved_name

	if not replacements.has("character_name"):
		var context_character_id := int(context.get("character_id", 0))
		if context_character_id > 0:
			var context_character := CharacterManager.get_character_by_id(
				context_character_id
			)
			var context_character_name := String(
				context_character.get("first_name", "")
			)
			if not context_character_name.is_empty():
				replacements["character_name"] = context_character_name

	if context.has("job_id"):
		var job := CareerManager.get_job_by_id(int(context.get("job_id", 0)))
		var job_name := String(job.get("job_name", ""))
		if not job_name.is_empty():
			replacements["job"] = job_name

	if context.has("company_id"):
		var company := CareerManager.get_company_by_id(
			String(context.get("company_id", ""))
		)
		var company_name := String(company.get("company_name", ""))
		if not company_name.is_empty():
			replacements["company_name"] = company_name

	if context.has("salary"):
		replacements["salary"] = str(int(context.get("salary", 0)))

	return replacements
