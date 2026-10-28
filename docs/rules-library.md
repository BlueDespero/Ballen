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
Each built rule's `tier` in `rules/data/rules.json` mirrors this table's Tier column (lowercase); a test
checks they match, so change both together.
A dash means not measured yet.

**Strictness and Tier are provisional** (#17): strictness from the strictness check on 2000 random
boards (seed 1), tiers from 2000 AI-vs-AI matches (seed 1) with the thresholds in
[technical-design.md](technical-design.md#rule-tiers) (Simple: win rate as the true rule ≥ 55% and skip
rate < 5%; Hardcore: win rate < 33% or skip rate ≥ 10%; Intermediate: the rest). Re-measure when the AI
or a rule changes; playtests confirm them before a rule is Tuned.
Outside the 20–60% strictness band: below it R02, R05, R06, R08, R09, R10, R13, R19, R21, R22 and R23
(mostly rules that bite only at some moments: one colour, one turn range, after a skip, near the last
ball); above it R07 and R11.

| ID | Rule (player text) | Type | Template | Blanks | Status | Strictness | Tier |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R01 | Never next to the same colour | Colour & neighbours | `not_next_to` | ball = same_colour | Built | 50% | Hardcore |
| R02 | Red only next to blue | Colour & neighbours | `colour_only_next_to` | colour = red, other = blue | Built | 11% | Intermediate |
| R03 | Only on even rows | Position | `only_on_axis` | axis = row, parity = even | Built | 50% | Intermediate |
| R04 | Never on the edge | Position | `not_on_zone` | zone = edge | Built | 56% | Intermediate |
| R05 | At most 2 of a colour in any row | Counts | `max_in_axis` | axis = row, ball = same_colour, n = 2 | Built | 14% | Intermediate |
| R06 | Never more red than blue on the board | Counts | `never_more_than` | a = red, b = blue | Built | 16% | Hardcore |
| R07 | Never next to an opponent ball | Ball owner | `not_next_to` | ball = opponent_ball | Built | 73% | Intermediate |
| R08 | Not next to the ball you placed last | History | `not_next_to` | ball = my_last_ball | Built | 16% | Simple |
| R09 | Never in the same row as your last ball | History | `not_same_axis_as` | axis = row, ball = my_last_ball | Built | 14% | Simple |
| R10 | Never complete a line of 3 | Geometry | `no_line_of` | n = 3 | Built | 12% | Intermediate |
| R11 | At least 2 cells from any red | Geometry | `min_distance_from` | colour = red, n = 2 | Built | 74% | Hardcore |
| R12 | Diagonal check | Geometry | `diagonal_check` | – | Idea | – | – |
| R13 | Must touch an existing ball | Connection | `must_touch` | ball = any_ball | Built | 12% | Simple |
| R14 | Must join your own group | Connection | `must_touch` | ball = my_ball | Built | 24% | Simple |
| R15 | Only in a row numbered higher than your last ball's row | Relative position | `relative_to_last` | direction = higher | Built | 54% | Hardcore |
| R16 | Only in a row numbered lower than your last ball's row | Relative position | `relative_to_last` | direction = lower | Built | 54% | Hardcore |
| R17 | Must touch the next colour in yellow → blue → red → green | Colour order | `must_touch` | ball = next_colour (cycle Y→B→R→G) | Built | 39% | Hardcore |
| R18 | Only cells with 2+ empty neighbours | Space | `min_empty_neighbours` | n = 2 | Built | 31% | Simple |
| R19 | Never fill a row completely | Space | `never_fill_axis` | axis = row | Built | 17% | Simple |
| R20 | On your odd turns, edge only | Time | `zone_on_turn_parity` | parity = odd, zone = edge | Built | 24% | Simple |
| R21 | For your first 5 turns, only rows 3 and 4 | Time | `rows_for_first_turns` | turns = 5, from = 3, to = 4 | Built | 18% | Simple |
| R22 | After any skip, must touch one of your own balls | Game state | `touch_mine_after_skips` | skips = 1 | Built | 9% | Simple |
| R23 | Never next to the opponent's last ball | Opponent-aware | `not_next_to` | ball = opponent_last_ball | Built | 17% | Simple |

## Open questions

- [ ] How many rules does the first release need?
- [ ] Can a deck hold two near-identical rules (e.g. R01 and R07)?
- [ ] Are some rules too strong as the true rule (too loose to deduce, or too strict to survive)?
- [ ] Tier thresholds: which strictness or AI-vs-AI win-rate ranges make a rule Simple, Intermediate or Hardcore?
  Provisional answer above (#17); confirm in playtests.
- [ ] Is the 20–60% strictness band right for built rules? 11 of 22 fall below it, yet R06 is the harshest
  rule in play (71% skip rate), because an average share hides rules that forbid everything at some moments.
