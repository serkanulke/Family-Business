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

	var character_id := int(
		participants.get(
			"primary",
			context.get("character_id", 0)
		)
	)
	if character_id > 0:
		var character := CharacterManager.get_character_by_id(character_id)
		var character_name := String(character.get("first_name", ""))
		if not character_name.is_empty():
			replacements["character_name"] = character_name

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
