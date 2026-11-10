# The theory behind Ballen's AI, explained

This document explains the ideas and equations the AI uses, for a reader with little background in probability.
`docs/ai-internals.md` describes the code as built (classes, parameters, measurements); this document explains *why*
it works. Each section follows the same pattern:

1. the idea in plain words;
2. a small worked example from Ballen, with real numbers;
3. the equation, with every symbol explained;
4. where it lives in the code;
5. where to read more in the textbook.

**The textbook.** Mykel J. Kochenderfer, *Decision Making Under Uncertainty: Theory and Application* (MIT Press,
2015), free as a PDF from Stanford: <https://web.stanford.edu/group/sisl/public/dmu.pdf>. It is cited as "DMU" with
a section number (and a page where known). The PDF has no links to sections, so open it and use its table of
contents. The section numbers are those of `docs/ai-decision-theory-research.md`, which checked them against the
book's table of contents; it could read the text of Chapter 2 only. So the claim "this section explains this idea" is
confirmed for Chapter 2 and is otherwise based on the section titles.

The running example throughout: the board is 6 × 6 (36 cells, 20 on the edge, 16 inside). The opponent's deck holds
**R04 "Never on the edge"** and four rules that allow every cell. The AI doesn't know which of the five is the
opponent's secret rule.

## Contents

1. [Probability and odds](#1-probability-and-odds)
2. [Bayes' rule: updating a belief](#2-bayes-rule-updating-a-belief)
3. [Hard and soft evidence](#3-hard-and-soft-evidence)
4. [Models of the player](#4-models-of-the-player)
5. [Logarithms: adding instead of multiplying](#5-logarithms-adding-instead-of-multiplying)
6. [Lapse, temper and calibration](#6-lapse-temper-and-calibration)
7. [Entropy and information gain: choosing a colour](#7-entropy-and-information-gain-choosing-a-colour)
8. [Expected value: when to guess](#8-expected-value-when-to-guess)
9. [Exposure: the AI reading itself](#9-exposure-the-ai-reading-itself)
10. [Softmax: choosing with some randomness](#10-softmax-choosing-with-some-randomness)
11. [Playouts and tree search (Hard)](#11-playouts-and-tree-search-hard)
12. [Symbols at a glance](#symbols-at-a-glance)

## 1. Probability and odds

**Idea.** A probability is a number from 0 to 1 saying how sure the AI is: 0 means "impossible", 1 means "certain",
0.2 means "one chance in five". The AI keeps one probability for each of the opponent's 5 rules, and they always add
up to 1, because exactly one of them is the secret rule. That list of five numbers is called the **belief**.

At the start the AI knows nothing, so each rule gets 1/5 = 0.2.

**Odds** say the same thing as a comparison: "how many times likelier is it than not". A probability p has odds
p / (1 − p). A rule held at 0.8 has odds 0.8 / 0.2 = 4, "4 to 1". Odds are handy because evidence *multiplies* them
(section 2), and turning odds o back into a probability is p = o / (1 + o).

**Example.** Two rules at 0.36 and 0.16 have a ratio of 0.36 / 0.16 = 2.25: the first is 2.25 times as likely as
the second.

**Code.** `Belief.probability(rule_id)`, `Belief.probabilities()` (`ai/belief.gd`).

**Read more.** DMU §2.1 (Representation), §2.1.1 Degrees of belief and probability.

## 2. Bayes' rule: updating a belief

**Idea.** When the opponent places a ball, the AI asks, for each rule: *if this were the secret rule, how likely
was that move?* Rules that make the move likely gain weight; rules that make it unlikely lose weight. The new belief
is the old one multiplied, rule by rule, by that likelihood, then rescaled so that the five numbers add up to 1 again.

**Example.** The opponent places on an inner cell of the empty board, and the AI assumes they pick at random among
the cells their rule allows (the uniform model, section 4).

| Rule | Cells it allows | Chance of this cell, if it is the secret rule | Old belief | Old × chance | New belief |
| --- | --- | --- | --- | --- | --- |
| R04 | 16 inner | 1/16 = 0.0625 | 0.2 | 0.0125 | 0.0125 / 0.0347 = **0.36** |
| Each of the other 4 | all 36 | 1/36 ≈ 0.0278 | 0.2 | 0.0056 | **0.16** each |
| Sum | | | 1 | 0.0347 | 1 |

R04 is now 2.25 times as likely as each other rule (0.0625 / 0.0278 = 36 / 16). Why? A player holding R04 *had* to
place inside, while a player with an "anywhere" rule only lands inside 16 times in 36. The inner placement is weak
evidence for R04.

Had the ball gone on the edge, R04's chance would be 0: it is ruled out, and the four others share the belief at 1/4.

**Equation.** For each rule r, after an observed move o (a placement on a cell, or a skip):

```
b'(r) = P(o | r) · b(r) / Σ_s P(o | s) · b(s)
```

- b(r): the belief in rule r before the move; b'(r): after it.
- P(o | r): the **likelihood**, "the chance of seeing move o if r is the secret rule".
- The sum Σ over all five rules s rescales the result so it adds up to 1 (**normalising**).

In odds form: new odds of r against s = old odds × P(o | r) / P(o | s). The ratio P(o | r) / P(o | s) is how strong
the evidence is; 2.25 in the example.

Ballen's secret rule never changes during a match, so this is the simplest kind of "filter": the textbook's
transition step (the hidden thing moving between observations) is not needed.

**Code.** `Belief.update` (`ai/belief.gd`) reads each new opponent event, judged on the board *just before* it
(`MatchPosition.before(i)`).

**Read more.** DMU §2.2.2 Inference in Temporal Models (p. 29; Equation 2.33 and Algorithm 2.1 are this update);
§6.2.1 Discrete State Filter (p. 136); §2.2.1 (naive Bayes, p. 26) for treating each move as one more piece of
independent evidence.

## 3. Hard and soft evidence

**Idea.** Some evidence is certain. If the opponent places on the edge, R04 *cannot* be their rule; if they skip,
every rule that allowed some cell for that colour is impossible. This is **hard evidence**, and the AI keeps it
separately as a yes/no list called the **mask** (`alive`). A rule ruled out stays ruled out for the rest of the
match; nothing can bring it back.

Everything else is **soft evidence**: "this move is a bit likelier under R04", as in section 2. Soft evidence depends
on a guess about how the player behaves (section 4), so it can be wrong, and the AI trusts it only partly
(section 6).

**Why keep them apart?** Because the hard part never makes a mistake: the opponent's real secret rule always stays
alive. That gives two promises the tests check: the AI never names a rule that the moves have ruled out, and its
belief never drops the true rule. If the soft part used likelihood 0 for "possible but unexpected" moves, one odd
move would rule out the true rule forever.

**Example.** After an edge placement, R04's mask is false and its probability is exactly 0, whatever its soft score
was. The four others share the belief in proportion to their soft scores.

**Equation.**

```
b(r) = 0                                          if r is ruled out
b(r) = e^score(r) / Σ_{alive s} e^score(s)        otherwise
```

(scores in section 5).

**Code.** `Deduction.rules_out` (`ai/deduction.gd`) decides hard elimination; `Belief` keeps `alive` and applies it.

**Read more.** DMU §2.2.2: a state with likelihood 0 keeps probability 0 after every later update.

## 4. Models of the player

**Idea.** To know how likely a move is under a rule, the AI needs a picture of *how the player chooses* among the
cells their rule allows. That picture is the **model of the player**. Levels differ in their model, never in what
they can see.

**The uniform model** (Easy): the player picks any allowed cell at random. Then a rule allowing fewer cells makes
each of its cells likelier: the chance is 1 / (number of allowed cells). This is the **size principle**: a strict
rule that "fits" a move gets more credit than a loose rule that would have allowed nearly anything. Section 2's
example used it: 1/16 against 1/36.

**The hider model** (Normal and Hard): real players hide. A cell that many of their five rules allow gives nothing
away, so they prefer such cells. The model gives each cell a weight e^(β·k), where k is how many of the player's 5
deck rules allow it and β ("beta") is how strongly they prefer such cells. e ≈ 2.718, so with β = 1 a cell one more
rule allows is weighted 2.718 times as much.

**Example.** The same inner placement. Inner cells are allowed by all 5 rules (k = 5), edge cells by the 4
"anywhere" rules only (k = 4). With β = 1:

- Under R04 (16 inner cells, all weighted e⁵), the chance of this cell is 1/16 = 0.0625, as before.
- Under an "anywhere" rule (16 cells weighted e⁵ and 20 weighted e⁴), it is e⁵ / (16·e⁵ + 20·e⁴) ≈ 0.043, up from
  0.028: a hider with an "anywhere" rule likes inner cells too.

With the lapse of section 6 the ratio is 0.0625 / 0.0398 ≈ **1.57**, not 2.25. The hider model learns less from an
inner placement, because it expects even an innocent player to go there. That is the point: a player who hides
can't fool it as easily.

**Equation.**

```
P(x | r) = (1 − ε) · e^(β·k(x)) / Σ_{y ∈ A_r} e^(β·k(y))  +  ε / |A_r|
```

- x: the cell played; A_r: the cells rule r allows; |A_r|: how many there are.
- k(x): how many of the player's 5 deck rules allow x.
- β: how strongly the player prefers shared cells (0 is the uniform model).
- ε ("epsilon"): the lapse, section 6.

**Code.** `OpponentModel` (`ai/opponent_model.gd`: uniform), `HiderModel` (`ai/hider_model.gd`), Normal's settings in
`AIController.normal_model()`: β = 1, ε = 0.2, temper 0.4.

**Read more.** DMU §3.3.3 Behavioral Game Theory (p. 71) on modelling how other people actually choose, and §3.1.7
Irrationality; the research doc's section on level-k and cognitive hierarchy models (Camerer, Ho and Chong 2004).

## 5. Logarithms: adding instead of multiplying

**Idea.** Bayes' rule multiplies small numbers again and again: after 15 placements a rule's weight might be
(1/20)¹⁵, about 3 × 10⁻²⁰. Computers lose precision on such numbers. The **logarithm** turns multiplying into
adding: log(a × b) = log a + log b. So the AI keeps, for each rule, a **score** that is the sum of the logs of its
likelihoods. Adding 15 numbers like −3 is easy and exact.

To turn scores back into probabilities, the AI uses **log-sum-exp**: subtract the largest score from every score
first, then exponentiate. The largest becomes e⁰ = 1 and the rest are between 0 and 1, so nothing overflows, and the
result is the same, because the subtraction scales every rule by the same factor, and normalising removes it.

**Example.** Scores −50.0 and −51.1: e^−50 is tiny, but after subtracting −50 they are e⁰ = 1 and e^−1.1 ≈ 0.333,
which normalise to 0.75 and 0.25.

**Equation.**

```
score(r) = Σ over the opponent's placements of  temper · log P(x | r)
b(r)     = e^(score(r) − m) / Σ_s e^(score(s) − m),   m = the largest score
```

**Code.** `Belief._log_scores` and `Belief.probabilities()` (`ai/belief.gd`).

**Read more.** A general numerical trick rather than a DMU topic; DMU §2.2.1 works with products of likelihoods,
which is what the scores add up in log form.

## 6. Lapse, temper and calibration

**Idea.** A model of the player is only a guess, and a confident guess that is wrong does damage. Two settings keep
the AI humble:

- **Lapse (ε).** "Now and then the player does something my model didn't expect." A share ε of each likelihood is
  spread evenly over the allowed cells. So no allowed cell is ever nearly impossible under a rule, and the soft
  evidence can never all but rule out a rule the hard evidence keeps.
- **Temper.** Each placement's evidence counts only partly: its log-likelihood is multiplied by the temper (0 to 1)
  before it is added. Temper 1 believes the model fully; 0.4 raises each likelihood ratio to the power 0.4, so a
  2.25× piece of evidence counts as 2.25^0.4 ≈ 1.38×.

**Calibration** is the test of whether the AI's confidence is honest: of all the times it held a rule at about 70%,
was that rule right about 70% of the time? An overconfident AI says 90% and is right 60% of the time, and guesses
too early. The temper was set by measuring exactly this over seeded AI-vs-AI matches (right / times seen):

| Model | 0.5–0.6 | 0.6–0.7 | 0.7–0.8 | 0.8–0.9 |
| --- | --- | --- | --- | --- |
| Hider, temper 1 (untempered) | 38% | 50% | 45% | 64% |
| Hider, temper 0.4 (Normal) | 44% | 57% | 73% | 75% |

Untempered, the AI was much surer than it should have been; at 0.4 its confidence roughly matches how often it is
right.

Calibration depends on who you play. Those numbers were measured against an earlier Normal that didn't hide. Against
today's Normal, which hides, a rule held at 0.7 is right only about 40% of the time: a good hider makes soft
evidence weak. Yet an honest Normal (lower temper) loses more, because it waits and gets named first (section 8:
waiting is worth little once the opponent is close). Details in `docs/ai-internals.md`, "Calibration".

**Example.** Section 2's inner placement, as each level sees it (R04 was 0.2 before):

| Level | Model, temper | R04 after one inner placement |
| --- | --- | --- |
| Untempered uniform | uniform, 1 | 0.36 |
| Normal | hider (β 1, ε 0.2), 0.4 | 0.23 |
| Easy | uniform, 0.15 | 0.22 |

Easy learns slowly on purpose (temper 0.15): it is meant to be beatable.

**Equation.** In section 5's score: score(r) += temper · log P(x | r). Equivalently each likelihood is raised to the
power temper.

**Code.** `OpponentModel.lapse`, `OpponentModel.temper`; Normal's values in `AIController.normal_model()`, Easy's in
`AIController.easy_model()`. Full calibration table and method in `docs/ai-internals.md` ("Measurements").

**Read more.** DMU §2.3 (Parameter Learning) on fitting a model's numbers to data; calibration itself is not a named
DMU section.

## 7. Entropy and information gain: choosing a colour

**Idea.** The AI picks the colour of the opponent's next ball. A good colour is one where the opponent's answer
(where they place, or whether they must skip) tells the AI the most. To measure "tells the most", it needs a measure
of how unsure it is. That measure is **entropy**, counted in **bits**.

- 5 rules equally likely: entropy log₂5 ≈ 2.32 bits.
- 1 rule certain: 0 bits.
- A handy reading: 2^entropy is the "effective number of rules still in play". After section 2's placement the
  belief (0.36, 0.16, 0.16, 0.16, 0.16) has entropy 2.22 bits, about 4.7 effective rules: a little was learned.

**Information gain** of a colour is how much entropy it is expected to remove: today's entropy minus the average
entropy after the opponent's reply, each possible reply weighted by how likely it is.

**Example.** All 5 rules equally likely (2.32 bits). For some colour, 2 of the rules allow no cell (the opponent
would have to skip) and 3 allow the same cells.

- With chance 2/5 the opponent skips: the 3 rules that allowed a cell are ruled out, 2 rules remain, 1 bit left.
- With chance 3/5 they place: the 2 skip rules are ruled out, 3 remain, log₂3 ≈ 1.58 bits left.
- Expected entropy after: 0.4 × 1 + 0.6 × 1.58 = 1.35 bits. **Information gain: 2.32 − 1.35 = 0.97 bits.**

A colour every rule treats alike gains 0 bits: whatever the reply, the AI learns nothing. Normal also adds a **skip
bonus**: a skip costs the opponent one of their 3 skips, and a third skip loses them the match, so a colour likely to
force a skip is worth extra (0.5, 1 or 20 bits for an opponent with 0, 1 or 2 skips). In the example, at 0 skips:
0.97 + 0.4 × 0.5 = 1.17.

**Equation.**

```
H(b)     = − Σ_r b(r) · log₂ b(r)                                    entropy, in bits
value(c) = H(b) − Σ_o P(o | c) · H(b'_o)  +  P(skip | c) · SKIP_BITS[opponent's skips]
P(o | c) = Σ_r b(r) · P(o | r)                                       chance of reply o
```

- c: a colour; o: one possible reply (a cell, or a skip); b'_o: the belief after reply o (section 2's update,
  tempered as the real belief would be).
- 0 · log 0 counts as 0.

This is **value of information**: an action worth taking only for what it tells you. Choosing the most informative
colour one step ahead is "greedy" probing; for games of deduction it comes close to the best possible (the research
doc cites Wordle: 7,944 total guesses greedy against 7,920 optimal).

**Code.** `InformationColourPick.value` (`ai/information_colour_pick.gd`); `Belief.entropy()`.

**Read more.** DMU §3.2.2 Value of Information (p. 66); §5.1 Exploration and Exploitation.

## 8. Expected value: when to guess

**Idea.** A guess ends the match: right wins, wrong loses. Count a win as +1, a loss as −1 and a draw as 0. The
**expected value** of an action is its average outcome, each outcome weighted by its probability. The best action is
the one with the highest expected value (the **maximum expected utility** principle).

Guessing the top rule, held at probability p, is worth:

```
EV(guess) = p · (+1) + (1 − p) · (−1) = 2p − 1
```

At p = 0.8 that is +0.6; at p = 0.5 it is 0 (a coin flip); below 0.5 it is negative.

Waiting is worth something too: call it V_wait. Guess when 2p − 1 ≥ V_wait, that is when

```
p ≥ (1 + V_wait) / 2
```

If waiting is worthless (V_wait = 0) the AI should guess at any p above 0.5. If waiting is nearly as good as a sure
win (V_wait ≈ 1), only near-certainty is worth guessing on. The whole question is how much waiting is worth, and
that depends on the danger: **if the opponent is about to name the AI's rule, waiting is worth little.**

**Normal's shortcut** (`DangerGuessPolicy`). It slides its threshold from 0.95 (safe) down to 0.35 (desperate) as
its own rule gets exposed:

```
threshold = 0.95 − (0.95 − 0.35) · danger
danger    = clamp((p_exposed − 0.2) / (0.95 − 0.2), 0, 1),  or 1 one skip from losing
```

p_exposed is how likely the opponent could think the AI's own rule is (section 9). Example: the AI's own edge
placement has shown it isn't R04, so p_exposed = 1/4 and danger = 0.05 / 0.75 ≈ 0.067: the threshold is about 0.91.

**Hard's version** (`ValueGuessPolicy`) works V_wait out, one opponent turn ahead:

```
V_wait = −g·m + g·(1 − m) + (1 − g) · max(0, 2p' − 1)
```

- g: the chance the opponent guesses on their next turn. It grows from 0 when their best probability is 0.35 to 1
  when it is 0.95 (Normal's range); 1 if the AI is one skip from losing (the opponent can finish it by handing over
  a colour it can't place).
- m: the chance their guess names the AI's real rule (the exposure, section 9). They then win: −1 with chance g·m.
  They name a wrong rule with chance g·(1 − m), and the AI wins: +1.
- Otherwise the match goes on, and next turn the AI will be surer: its top rule's odds (section 1) are multiplied by
  1.6, giving p'. Guessing then would be worth 2p' − 1 (or it keeps waiting: never below 0).

**Example (from the code's numbers).**

| Situation | p | V_wait | Guess when p ≥ | Decision |
| --- | --- | --- | --- | --- |
| Hidden: the opponent knows nothing (their best 0.35, so g = 0) | 0.6 | 0.41 | 0.71 | Wait |
| Exposed: the opponent holds the AI's rule at 0.8 (g = 0.75, m = 0.8) | 0.6 | −0.35 | 0.33 | Guess |

The same p = 0.6 is a bad guess when safe and a good one when the opponent is closing in. While fully hidden,
this formula never lets Hard guess before it is certain: waiting always looks better.

**Forced guess.** On a full board each player must name a rule; only a right guess wins. Then waiting is not an
option, and the best pick is simply the most likely rule.

**Code.** `GuessPolicy`, `DangerGuessPolicy`, `ValueGuessPolicy` (`ai/`).

**Read more.** DMU §3.1.3 Maximum Expected Utility Principle; §6.5.1 Lookahead with Approximate Value Functions (the
one-turn look ahead, with "how good is the future" estimated rather than searched); the research doc's "Guess when
confidence beats the value of waiting".

## 9. Exposure: the AI reading itself

**Idea.** The AI applies sections 2–6 to *its own* moves, as if it were the opponent: "from what I've played, how
likely could they think each of my rules is?" That belief about itself is the **exposure**. Its probability for the
AI's real secret rule says how exposed the AI is. Guessing uses it (danger, m above) and so does placement: the AI
places where it gives the least away.

**Example.** The AI's secret rule allows every cell, and one of its fake rules is R04 "Never on the edge" (the
mirror of the running example). Under Normal's model:

- An inner placement fits all 5 of its rules: its exposure for its secret rule goes from 0.20 to about 0.19.
- An edge placement breaks R04: the opponent can rule R04 out, so only 4 rules remain and the secret rule goes to
  0.25.

So it places inside, keeping R04 believable as a decoy. Hard's `ExposurePlacement` computes this "exposure after"
for every allowed cell and keeps the lowest.

**When a fake is broken.** Once the AI has placed on the edge, the exposure rules R04 out, assuming the opponent
noticed. From then on R04 is dead to the AI's hiding too: breaking it again costs nothing, so the edge is free again,
and the AI protects the fakes still alive instead (tests `test_once_r04_is_ruled_out_the_edge_is_free_again` and
`test_after_breaking_a_fake_it_protects_the_others`). Choosing *which* fake to give up when a break can't be avoided,
with later turns in mind, needs looking ahead: section 11.

**Equation.** The same as sections 2–6, with the AI's own placements as the observations and its own deck as the
rules. Hard's placement picks

```
x* = the allowed cell x with the lowest b'_x(own secret rule),
```

where b'_x is the exposure updated as if the AI had placed on x.

**Code.** `Belief.new(model, true)` (the `about_viewer` flag) in `ai/belief.gd`; `HidingPlacement` (Normal) and
`ExposurePlacement` (Hard).

**Read more.** DMU §3.1.6 Multiple Variable Utility Functions (weighing hiding against keeping room for the next
ball); the research doc's placement section on bluffing; and, for reasoning about what the other player believes,
DMU §3.3 Games.

## 10. Softmax: choosing with some randomness

**Idea.** An AI that always makes the best-looking move is predictable, and a predictable AI can be read: if Hard
always handed over the colour that best splits your rules, the colour itself would tell you what it suspects. A
**softmax** choice picks every option with some chance, the better options much more often. A **precision**
setting says how much more: very high is "always the best", 0 is "any at random".

**Example.** Hard's colour pick, precision 6, with four colours valued 1.0, 0.5, 0.2 and 0 (scaled so the best is
1):

| Colour value | Weight e^(6 · (v − 1)) | Chance |
| --- | --- | --- |
| 1.0 | 1 | 94.3% |
| 0.5 | e^−3 ≈ 0.050 | 4.7% |
| 0.2 | e^−4.8 ≈ 0.008 | 0.8% |
| 0 | e^−6 ≈ 0.002 | 0.2% |

**Equation.**

```
P(choose c) = e^(λ · u(c)) / Σ_d e^(λ · u(d))
```

- u(c): how good option c looks (Hard: its value ÷ the best value, so the scale doesn't depend on the position).
- λ ("lambda"): the precision.

Behavioural game theory uses the same formula as a model of how people actually choose: they mostly pick the best
option but not always ("quantal response").

**Code.** `SoftmaxColourPick` (`ai/softmax_colour_pick.gd`). Easy's `LooseColourPick` is a simpler cousin: the
considered pick 40% of the time, any colour otherwise.

**Read more.** DMU §3.3.3 Behavioral Game Theory (p. 71), §3.3.1–3.3.2 on why mixing your choices matters against
an opponent (Nash equilibrium); McKelvey and Palfrey (1995) on quantal response, cited in the research doc.

## 11. Playouts and tree search (Hard)

Hard uses playouts for its two biggest choices, when to guess (`RolloutGuessPolicy`) and where to place
(`RolloutPlacement`). A full tree search over every choice is not built (issue #22).

**Idea: playouts.** Section 8's formula *estimates* how much waiting is worth. A **playout** measures it instead:
imagine the rest of the match, played out to the end, and see who wins. Do that many times and average the results.
Each imagined match starts from the real position. Because the AI doesn't know the opponent's secret rule, each
playout first draws one from the belief: a rule held at 0.4 is drawn in about 40% of the playouts. This is the
**Monte Carlo** idea: estimate an average by sampling.

**Example.** At some decision, the AI's top rule is held at p = 0.6, so guessing is worth 2(0.6) − 1 = 0.2. It plays
16 matches on without guessing now. Say they end 9 wins, 6 losses and 1 draw: waiting is worth
(9 − 6) / 16 ≈ 0.19. Guessing (0.2) is slightly better, so it guesses. Had the playouts ended 11–5, waiting would be
worth 0.375, and it would hold back.

**Equation.**

```
V_wait ≈ (1/N) · Σ_{i=1..N} result_i,     result = +1 win, −1 loss, 0 draw
guess  if  2p − 1 ≥ V_wait
```

**What the measurements taught** (`docs/ai-internals.md`, "Playouts for guessing"):

- **A playout is only as good as the players imagined in it.** When the AI imagined its own future moves as Normal's
  (a worse hider than it really is), the imagined opponent named it too often. Waiting looked bad, the AI guessed
  too early, and it won *less* (51%).
- **Draw from an honest belief.** Drawing the opponent's rule from an overconfident belief also makes guessing look
  safer than it is (section 6); a lower temper helped.
- Guessing by playouts won 57.4% against Normal, up from 55%. Placing by playouts too (each of the 4 best hiding
  cells played out 8 times, on the same imagined matches so they are compared fairly) brought Hard to 61.4% over
  1000 matches, past its 60% target. That is Hard as built.

**Idea: tree search (next).** Playouts judge one decision: guess or wait. **Monte Carlo tree search** (MCTS) uses
the same playouts for every decision (colours and cells too). It grows a tree of the most promising lines, spending
more of its time on moves that look good but are not yet well tested. It sees what one step can't: that breaking
this fake now keeps a better one for later, or that a colour sets up a forced skip two turns on.

**Read more.** DMU §4.6 (online planning; §4.6.3 Sparse Sampling, §4.6.4 Monte Carlo Tree Search), §6.5.4 (Monte
Carlo tree search for partially observable problems); Silver and Veness (2010), "Monte-Carlo Planning in Large
POMDPs", cited in the research doc.

## Symbols at a glance

| Symbol | Meaning | Section |
| --- | --- | --- |
| r, s | One of the opponent's 5 rules | 2 |
| b(r), b'(r) | The belief in rule r, before and after a move | 1, 2 |
| P(o \| r) | The likelihood: the chance of move o if r is the secret rule | 2 |
| A_r | The cells rule r allows for the colour being placed | 4 |
| k(x) | How many of the player's 5 deck rules allow cell x | 4 |
| β | How strongly the hider model expects shared cells | 4 |
| ε | Lapse: the share of each likelihood spread evenly | 6 |
| temper | How much each placement's evidence counts | 6 |
| H(b) | Entropy, in bits | 7 |
| p | The top rule's probability | 8 |
| V_wait | The expected value of not guessing now | 8 |
| g, m | The chance the opponent guesses next turn; the chance they name the AI's rule | 8 |
| λ | Softmax precision | 10 |
