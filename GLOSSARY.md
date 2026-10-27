# Ballen

A two-player hidden-information duel on a 6 × 6 board: each player hides one true rule among four fakes
and wins by naming the opponent's true rule.

## Board and balls

**Match**:
One play of Ballen between two players, from choosing true rules to the result.
_Avoid_: Game, duel (except in the mode name "Daily duel")

**Board**:
The shared 6 × 6 grid of cells that both players place on.
_Avoid_: Grid, field

**Cell**:
One square of the board, empty or holding one ball.
_Avoid_: Tile, square, slot

**Side**:
The board edge a player sits at: you at the bottom, the opponent at the top. A skipped ball dissolves
at its owner's side.

**First player**:
The player who takes the first turn of a match, decided by a coin toss.
_Avoid_: Starting player, player one

**Row**:
A horizontal line of 6 cells, numbered 1–6 from the first player's side. Both players use the same
numbering, so a row is odd or even for both.

**Column**:
A vertical line of 6 cells.

**Line**:
Balls of one colour in an unbroken straight row of cells: horizontal, vertical or diagonal, any owner.
"A line of 3" means 3 or more such balls in a row.
_Avoid_: Run, streak; and "line" as a word for "row or column" (say "row or column")

**Neighbour**:
One of the up to 8 cells touching a cell, diagonals included. "Next to" in rule text means
"on a neighbour".
_Avoid_: Adjacent, touching

**Distance**:
How many king moves apart two cells are: one step reaches any neighbour, diagonals included, so
neighbours are at distance 1 and "within 2 cells" is the 5 × 5 square around a cell.
_Avoid_: Manhattan or straight-line distance

**Ball**:
A piece with one colour and one owner, placed on a cell.
_Avoid_: Piece, token, stone

**Last ball**:
The ball a player placed most recently in this match. A skip doesn't change it; before a player's first
placement they have none.
_Avoid_: Previous ball

**Colour**:
One of yellow, blue, red or green; every ball has exactly one.

**Owner**:
The player who placed a ball.

## Rules and decks

**Rule**:
A placement constraint, written as a fill-in-the-blank sentence, that says which cells a ball may go on.

**Holder**:
The player whose deck contains a rule. "You" in rule text always means the holder, "opponent" the other
player.
_Avoid_: Owner (that word belongs to balls)

**Deck**:
The 5 rules a player brings to a match; both players see each other's whole deck.
_Avoid_: Hand, set, loadout

**True rule**:
The one rule in a deck that its owner secretly marks for this match; the game enforces it on every
placement.
_Avoid_: Real rule, secret rule, active rule

**Fake rule**:
Any of the 4 deck rules that are not the true rule; never enforced, they exist only as cover.
_Avoid_: Decoy, false rule, bluff

**Template**:
The fixed sentence shape of a rule, with blanks, such as "Ball can't be placed in the same ___ as ___".

**Blank**:
A slot in a template; a rule is a template plus a value for each blank.
_Avoid_: Parameter, field

**Part**:
A reusable building block that templates are made of: a selector, filter, condition or combiner.

**Strictness**:
The share of placements a rule forbids on random boards.

**Skip rate**:
For one rule: the share of its holders' turns that ended in a skip, counted over matches where it was
the true rule.

**Tier**:
How much a rule restricts its holder: Simple, Intermediate or Hardcore.
_Avoid_: Difficulty (that word belongs to the AI)

## Play

**Turn**:
One player's go: an optional guess, a placement or skip, another optional guess, then a colour pick.
Players alternate turns.
_Avoid_: Move, round, ply

**Legal cell**:
An empty cell where the current ball may be placed under the current player's true rule.
_Avoid_: Valid cell, allowed cell, glowing cell

**Placement**:
Putting the current ball on a legal cell.
_Avoid_: Move, drop

**Skip**:
What happens when a player has no legal cell for their ball: the ball is removed and their skip count
rises by one. The third skip in a match loses it at once, with no chance to guess.
_Avoid_: Pass, dissolve (that is the animation, not the event)

**Colour pick**:
The choice, at the end of a turn, of the colour the opponent must place next.
_Avoid_: Probe (that is the AI's reason for a pick, not the act)

**Guess**:
Naming one of the opponent's deck rules as their true rule; right wins, wrong loses.
_Avoid_: Accusation, pulling the trigger (that is flavour text only)

**Match setup**:
The screen before a match: pick a deck and the AI level, then choose the true rule.
_Avoid_: Pre-match, lobby

**Rematch**:
A new match straight after one ends, with the same decks and AI level. Both players choose their true
rule again, and the other player goes first.

**Full board**:
The state where every cell holds a ball; both players then make a forced guess.

**Forced guess**:
The guess each player must make when the board is full. Both are sealed and revealed together; exactly
one right wins, otherwise the match is a draw.

**Public view**:
Everything one player is allowed to know about a match: all of it except the opponent's true rule.

**Note mark**:
A private note a player keeps on one of the opponent's deck rules: ✗ ruled out or ? suspect. It records
the player's own belief, not proof; the game never checks it, and a rematch clears it.
_Avoid_: Tag, flag

## AI

**AI level**:
How well the AI plays: Easy, Normal or Hard, picked in match setup. Levels change how well it reads
moves and hides its own, never what it knows or which rules it gets.
_Avoid_: Difficulty setting, tier (that word belongs to rules)

**Confidence**:
The AI's probability that a given candidate is the opponent's true rule. The AI guesses when its top
candidate's confidence reaches its threshold.

**Candidate**:
An opponent deck rule that the AI has not yet ruled out as their true rule.

**Ruled out**:
Proven not to be the true rule, because a placement broke it or a skip happened although it would have
allowed a cell.
_Avoid_: Eliminated, crossed off
