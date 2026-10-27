# Ballen — Rules Library

The catalogue of placement rules. Each rule is a template plus the values in its blanks (see
[technical-design.md](technical-design.md#data-format)). Built rules live in `rules/data/rules.json` and
their templates in `rules/data/templates.json`; the template ids of other rules are proposals.
Blank names follow the built templates: `axis` is a row or column (never "line", which means only a line
of one colour), and `ball` names which balls count (built values are filter parts: `same_colour`,
`opponent_ball`, `my_last_ball`, `opponent_last_ball`).
Rule text reads the same for both players: it names rows by number (1–6 from the first player's side),
never by perspective words such as "above", "own half" or "towards the opponent".

**Turn counts** in rule text ("your odd turns", "your first 5 turns") count only the holder's own turns,
skipped ones included: your first turn is turn 1, whoever went first.

**Status:** Idea → Specced (template and blanks fixed) → Built → Tuned (strictness measured, playtested).
**Strictness** is the share of placements the rule forbids on random boards; target roughly 20–60%.
**Tier** ranks how much a rule restricts the player who holds it: Simple, Intermediate or Hardcore.
Tiers are assigned from AI-vs-AI tuning; the guided deck builder offers only Simple rules.
A dash means not measured yet.

| ID | Rule (player text) | Type | Template | Blanks | Status | Strictness | Tier |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R01 | Never next to the same colour | Colour & neighbours | `not_next_to` | ball = same_colour | Built | – | – |
| R02 | Red only next to blue | Colour & neighbours | `colour_only_next_to` | colour = red, other = blue | Built | – | – |
| R03 | Only on even rows | Position | `only_on_axis` | axis = row, parity = even | Built | – | – |
| R04 | Never on the edge | Position | `not_on_zone` | zone = edge | Built | – | – |
| R05 | At most 2 of a colour in any row | Counts | `max_in_axis` | axis = row, ball = same_colour, n = 2 | Built | – | – |
| R06 | Never more red than blue on the board | Counts | `never_more_than` | a = red, b = blue | Built | – | – |
| R07 | Never next to an opponent ball | Ball owner | `not_next_to` | ball = opponent_ball | Built | – | – |
| R08 | Not next to the ball you placed last | History | `not_next_to` | ball = my_last_ball | Built | – | – |
| R09 | Never in the same row as your last ball | History | `not_same_axis_as` | axis = row, ball = my_last_ball | Built | – | – |
| R10 | Never complete a line of 3 | Geometry | `no_line_of` | n = 3 | Built | – | – |
| R11 | At least 2 cells from any red | Geometry | `min_distance_from` | ball = red, n = 2 | Idea | – | – |
| R12 | Diagonal check | Geometry | `diagonal_check` | – | Idea | – | – |
| R13 | Must touch an existing ball | Connection | `must_touch` | ball = any ball | Idea | – | – |
| R14 | Must join your own group | Connection | `must_touch` | ball = my ball | Idea | – | – |
| R15 | Only in a row numbered higher than your last ball's row | Relative position | `relative_to_last` | direction = higher | Built | – | – |
| R16 | Only in a row numbered lower than your last ball's row | Relative position | `relative_to_last` | direction = lower | Built | – | – |
| R17 | Must touch the next colour in yellow → blue → red → green | Colour order | `must_touch_next_colour` | cycle = Y→B→R→G | Idea | – | – |
| R18 | Only cells with 2+ empty neighbours | Space | `min_empty_neighbours` | n = 2 | Built | – | – |
| R19 | Never fill a row completely | Space | `never_fill_axis` | axis = row | Built | – | – |
| R20 | On your odd turns, edge only | Time | `zone_on_turn_parity` | parity = odd, zone = edge | Built | – | – |
| R21 | For your first 5 turns, only rows 3 and 4 | Time | `rows_for_first_turns` | turns = 5, from = 3, to = 4 | Built | – | – |
| R22 | After any skip, must touch one of your own balls | Game state | `touch_mine_after_skips` | skips = 1 | Built | – | – |
| R23 | Never next to the opponent's last ball | Opponent-aware | `not_next_to` | ball = opponent_last_ball | Built | – | – |

## Open questions

- [ ] How many rules does the first release need?
- [ ] Can a deck hold two near-identical rules (e.g. R01 and R07)?
- [ ] Are some rules too strong as the true rule (too loose to deduce, or too strict to survive)?
- [ ] Tier thresholds: which strictness or AI-vs-AI win-rate ranges make a rule Simple, Intermediate or Hardcore?
