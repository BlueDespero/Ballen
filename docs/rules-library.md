# Ballen — Rules Library

The catalogue of placement rules. Each rule is a template plus the values in its blanks (see
[technical-design.md](technical-design.md#data-format)). Template ids are proposals until the rules
engine exists.

**Status:** Idea → Specced (template and blanks fixed) → Built → Tuned (strictness measured, playtested).
**Strictness** is the share of placements the rule forbids on random boards; target roughly 20–60%.
**Tier** ranks how much a rule restricts the player who holds it: Simple, Intermediate or Hardcore.
Tiers are assigned from AI-vs-AI tuning; the guided deck builder offers only Simple rules.
A dash means not measured yet.

| ID | Rule (player text) | Type | Template | Blanks | Status | Strictness | Tier |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R01 | Never next to the same colour | Colour & neighbours | `not_next_to` | target = same colour | Idea | – | – |
| R02 | Red only next to blue | Colour & neighbours | `colour_only_next_to` | colour = red, other = blue | Idea | – | – |
| R03 | Only on even rows | Position | `only_on_lines` | axis = row, parity = even | Idea | – | – |
| R04 | Never on the edge | Position | `not_on_zone` | zone = edge | Idea | – | – |
| R05 | At most 2 of a colour in any row | Counts | `max_in_line` | axis = row, target = same colour, n = 2 | Idea | – | – |
| R06 | Never more red than blue on the board | Counts | `never_more_than` | a = red, b = blue | Idea | – | – |
| R07 | Never next to an opponent ball | Ball owner | `not_next_to` | target = opponent ball | Idea | – | – |
| R08 | Not next to the ball you placed last | History | `not_next_to` | target = my last ball | Idea | – | – |
| R09 | Never in the same row as your previous ball | History | `not_same_line_as` | axis = row, target = my last ball | Idea | – | – |
| R10 | Never complete a line of 3 | Geometry | `no_line_of` | n = 3 | Idea | – | – |
| R11 | At least 2 cells from any red | Geometry | `min_distance_from` | target = red, n = 2 | Idea | – | – |
| R12 | Diagonal check (existing stub) | Geometry | `diagonal_check` | – | Stub in `rules/baserule.gd` | – | – |
| R13 | Must touch an existing ball | Connection | `must_touch` | target = any ball | Idea | – | – |
| R14 | Must join your own group | Connection | `must_touch` | target = my ball | Idea | – | – |
| R15 | Above your last ball | Relative position | `relative_to_last` | direction = above | Idea | – | – |
| R16 | Closer to the opponent's side than your last ball | Relative position | `relative_to_last` | direction = towards opponent | Idea | – | – |
| R17 | Must touch the next colour in yellow → blue → red → green | Colour order | `must_touch_next_colour` | cycle = Y→B→R→G | Idea | – | – |
| R18 | Only cells with 2+ empty neighbours | Space | `min_empty_neighbours` | n = 2 | Idea | – | – |
| R19 | Never fill a row completely | Space | `never_fill_line` | axis = row | Idea | – | – |
| R20 | On odd turns, edge only | Time | `if_then` | if = odd turn, then = on edge | Idea | – | – |
| R21 | For the first 5 turns, your own half only | Time | `if_then` | if = turn ≤ 5, then = own half | Idea | – | – |
| R22 | After any skip, must touch one of your own balls | Game state | `if_then` | if = any skip, then = touch my ball | Idea | – | – |
| R23 | Never next to the opponent's last ball | Opponent-aware | `not_next_to` | target = opponent's last ball | Idea | – | – |

## Open questions

- [ ] How many rules does the first release need?
- [ ] Can a deck hold two near-identical rules (e.g. R01 and R07)?
- [ ] Are some rules too strong as the true rule (too loose to deduce, or too strict to survive)?
- [ ] Tier thresholds: which strictness or AI-vs-AI win-rate ranges make a rule Simple, Intermediate or Hardcore?
