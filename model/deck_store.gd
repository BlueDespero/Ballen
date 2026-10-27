class_name DeckStore
extends RefCounted

## The player's named decks, saved in a JSON file as each deck's rule ids:
##     {"decks": [{"name": "Mixed", "rules": ["R02", "R04", "R06", "R07", "R09"]}]}
## The starter deck is built in: always offered first, never saved, renamed or
## deleted. Every change writes the file at once.

const DEFAULT_PATH: String = "user://decks.json"

const STARTER_DECK_NAME: String = "Starter"
const STARTER_DECK_IDS: Array[String] = ["R01", "R03", "R05", "R08", "R18"]

var _book: RuleBook
var _path: String
## Rule ids by saved deck name, in the order the decks were saved.
var _decks: Dictionary[String, Array] = {}


## Reads the decks saved at path, using book to turn rule ids into rules.
func _init(book: RuleBook, path: String = DEFAULT_PATH) -> void:
	_book = book
	_path = path
	_load()


## The starter deck's name, then the saved deck names in the order they were
## saved.
func names() -> Array[String]:
	var deck_names: Array[String] = [STARTER_DECK_NAME]
	deck_names.append_array(_decks.keys())
	return deck_names


## A new deck holding the book's rules for this name; null if there is none.
func deck(deck_name: String) -> Deck:
	var rule_ids: Array = STARTER_DECK_IDS if deck_name == STARTER_DECK_NAME else _decks.get(deck_name, [])
	if rule_ids.is_empty():
		return null
	var rules: Array[Rule] = []
	for rule_id: String in rule_ids:
		rules.append(_book.rule(rule_id))
	return Deck.new(rules)


## True for the built-in starter deck, which can only be copied.
func is_read_only(deck_name: String) -> bool:
	return deck_name == STARTER_DECK_NAME


## Saves the deck under this name, replacing a saved deck of the same name,
## and writes the file. Returns false (and reports an error, saving nothing)
## for a deck that wouldn't load (see _problem_with), the starter deck's name
## or a file that can't be written.
func save(deck_name: String, deck_to_save: Deck) -> bool:
	var rule_ids: Array[String] = []
	for rule: Rule in deck_to_save.rules:
		rule_ids.append(rule.id)
	var problem: String = _problem_with({"name": deck_name, "rules": rule_ids})
	if problem != "":
		push_error("DeckStore: did not save: %s" % problem)
		return false
	var decks: Dictionary[String, Array] = _decks.duplicate()
	decks[deck_name] = rule_ids
	return _replace_decks(decks)


## Writes these decks to the file and keeps them; false (keeping the old ones)
## if the file can't be written.
func _replace_decks(decks: Dictionary[String, Array]) -> bool:
	if not _write(decks):
		return false
	_decks = decks
	return true


func _load() -> void:
	if not FileAccess.file_exists(_path):
		return
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(_path)) != OK:
		push_error("DeckStore: could not read %s (%s)" % [_path, json.get_error_message()])
		return
	var parsed: Variant = json.data
	if not parsed is Dictionary or not parsed.get("decks") is Array:
		push_error("DeckStore: %s must be an object with a \"decks\" array" % _path)
		return
	var entries: Array = parsed.decks
	for entry: Variant in entries:
		var problem: String = _problem_with(entry)
		if problem == "" and _decks.has(entry.name):
			problem = "a deck is named %s twice" % entry.name
		if problem != "":
			push_error("DeckStore: skipped a deck in %s: %s" % [_path, problem])
			continue
		var rule_ids: Array[String] = []
		rule_ids.assign(entry.rules)
		_decks[entry.name] = rule_ids


## Why this file entry is not a deck the store can load; "" if it is.
func _problem_with(entry: Variant) -> String:
	if not entry is Dictionary:
		return "%s is not an object" % JSON.stringify(entry)
	var deck_name: Variant = entry.get("name")
	if not deck_name is String or deck_name == "":
		return "%s has no name" % JSON.stringify(entry)
	if is_read_only(deck_name):
		return "%s is the built-in deck" % deck_name
	var rule_ids: Variant = entry.get("rules")
	if not rule_ids is Array or not rule_ids.all(func(rule_id: Variant) -> bool: return rule_id is String):
		return "deck %s needs a list of rule ids" % deck_name
	if rule_ids.size() != Deck.SIZE:
		return "deck %s has %d rules, a deck needs %d rules" % [deck_name, rule_ids.size(), Deck.SIZE]
	for rule_id: String in rule_ids:
		if _book.rule(rule_id) == null:
			return "deck %s has an unknown rule %s" % [deck_name, rule_id]
		if rule_ids.count(rule_id) > 1:
			return "deck %s has %s twice" % [deck_name, rule_id]
	return ""


func _write(decks: Dictionary[String, Array]) -> bool:
	var entries: Array[Dictionary] = []
	for deck_name: String in decks:
		entries.append({"name": deck_name, "rules": decks[deck_name]})
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		push_error("DeckStore: could not write %s (%s)" % [_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify({"decks": entries}, "\t"))
	return true
