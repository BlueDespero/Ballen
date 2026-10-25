extends RefCounted

## Walks an object graph through script variables, arrays and dictionaries.
## Not a test script (no test_ prefix); preload it.


## The graph as plain data: objects become {"class": ..., <script vars>...}.
static func dump(value: Variant) -> Variant:
	if value is Object:
		var object: Object = value
		var data: Dictionary = {"class": _class_name(object)}
		for property: Dictionary in object.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				data[property.name] = dump(object.get(property.name))
		return data
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(dump(item))
		return items
	if value is Dictionary:
		var entries: Dictionary = {}
		for key: Variant in value:
			entries[key] = dump(value[key])
		return entries
	return value


## Every object reachable from value, value itself included.
static func objects(value: Variant) -> Array[Object]:
	var found: Array[Object] = []
	_collect(value, found)
	return found


static func _collect(value: Variant, found: Array[Object]) -> void:
	if value is Object:
		var object: Object = value
		if found.has(object):
			return
		found.append(object)
		for property: Dictionary in object.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				_collect(object.get(property.name), found)
	elif value is Array:
		for item: Variant in value:
			_collect(item, found)
	elif value is Dictionary:
		for key: Variant in value:
			_collect(key, found)
			_collect(value[key], found)


static func _class_name(object: Object) -> String:
	var script: Script = object.get_script()
	if script != null and not script.get_global_name().is_empty():
		return script.get_global_name()
	return object.get_class()
