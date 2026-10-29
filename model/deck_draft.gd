class_name DeckDraft
extends RefCounted

## The deck editor's work in progress: a name and up to Deck.SIZE distinct
## rule ids, picked in order. It says what stops it from being saved and saves
## itself as a new deck, or over the saved deck it edits (renaming that deck if
## the name changed).

## The name typed so far; saved without leading or trailing spaces.
var name: String
var _rule_ids: Array[String] = []
## The saved deck this draft edits; "" for a new deck.
var _own_name: String


func _init(deck_name: String = "", rule_ids: Array[String] = [], own_name: String = "") -> void:
	name = deck_name
	_rule_ids = rule_ids.duplicate()
	_own_name = own_name


## A draft that edits the saved deck by this name.
static func editing(store: DeckStore, deck_name: String) -> DeckDraft:
	return DeckDraft.new(deck_name, _ids_of(store.deck(deck_name)), deck_name)


## A new deck with the rules of the deck by this name, named "<name> copy"
## (or "<name> copy 2", 3, ... if that is taken).
static func copy_of(store: DeckStore, deck_name: String) -> DeckDraft:
	var copy_name: String = "%s copy" % deck_name
	var number: int = 2
	while store.names().has(copy_name):
		copy_name = "%s copy %d" % [deck_name, number]
		number += 1
	return DeckDraft.new(copy_name, _ids_of(store.deck(deck_name)))


## The picked rule ids, in the order they were picked.
func rule_ids() -> Array[String]:
	return _rule_ids.duplicate()


func has(rule_id: String) -> bool:
	return _rule_ids.has(rule_id)


func count() -> int:
	return _rule_ids.size()


func is_full() -> bool:
	return count() >= Deck.SIZE


## Picks the rule, or drops it if it is picked. Returns false (changing
## nothing) for a new pick when the draft is already full.
func toggle(rule_id: String) -> bool:
	if has(rule_id):
		_rule_ids.erase(rule_id)
		return true
	if is_full():
		return false
	_rule_ids.append(rule_id)
	return true


## What the player must fix before saving, as a hint ("" when it can be saved):
## the rule count first, then the name.
func problem(store: DeckStore) -> String:
	if count() != Deck.SIZE:
		return tr("Pick %d rules (%d picked)") % [Deck.SIZE, count()]
	return store.name_problem(name, _own_name)


## A deck of the book's rules, in pick order.
func to_deck(book: RuleBook) -> Deck:
	var rules: Array[Rule] = []
	for rule_id: String in _rule_ids:
		rules.append(book.rule(rule_id))
	return Deck.new(rules)


## Saves the draft to the store (see the class description). False if it has
## a problem or the store refuses it.
func save_to(store: DeckStore, book: RuleBook) -> bool:
	if problem(store) != "":
		return false
	var deck_name: String = name.strip_edges()
	var saved: bool
	if _own_name != "":
		saved = store.replace(_own_name, deck_name, to_deck(book))
	else:
		saved = store.save(deck_name, to_deck(book))
	if not saved:
		return false
	_own_name = deck_name
	return true


static func _ids_of(deck: Deck) -> Array[String]:
	var ids: Array[String] = []
	for rule: Rule in deck.rules:
		ids.append(rule.id)
	return ids
