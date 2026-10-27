# Ballen

Ballen is a two-player hidden-information duel on a 6 × 6 board. Each player hides one true rule
among four fakes, places balls that give away as little as possible, and wins by naming which of the
opponent's rules is real. Built with Godot 4.7 and GDScript, for the browser first and mobile later.

- **Game design:** [docs/game-design-document.md](docs/game-design-document.md)
- **Technical design:** [docs/technical-design.md](docs/technical-design.md)
- **Rules library:** [docs/rules-library.md](docs/rules-library.md)
- **AI research notes:** [docs/ai-decision-theory-research.md](docs/ai-decision-theory-research.md)

## Running the project

Open `project.godot` in Godot 4.7 and press **Play**. The main scene is `main.tscn`; **Single Player**
starts a match against the AI.

From the repo root, with Godot 4.7 on the path as `godot` (PowerShell):

```powershell
# Once per fresh checkout, and after adding a class_name
godot --headless --path . --import
# Run the GUT test suite headless; exit code 0 means every test passed
godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
# Play 100 AI-vs-AI matches and print balance numbers; exit code 1 if any match didn't finish
godot --headless --path . -s harness/run_harness.gd -- --matches 100 --seed 1
# Measure each rule's strictness on 2000 seeded random boards
godot --headless --path . -s harness/run_strictness.gd -- --boards 2000 --seed 1
```

`CLAUDE.md` has the details.

## Project layout

| Path | What it holds |
| --- | --- |
| `main.tscn`, `main_game.tscn` | Entry scenes: main menu and match |
| `model/` | The match as plain GDScript: board, turns, commands, history, public views, controllers |
| `rules/` | Rules engine; rules and templates as data in `rules/data/` |
| `ai/` | The AI opponent: deduction, guessing, colour picks, placement, levels |
| `harness/` | Headless AI-vs-AI harness and strictness check for balance numbers |
| `gui/` | Board, ball, colour picker, guess button, rules panel, match setup, match-end and menu scenes |
| `event_bus.gd`, `constants.gd` | Autoloads: global signals, ball colours |
| `assets/` | Kenney art assets |
| `test/`, `addons/gut/` | GUT tests and the vendored GUT addon |
| `docs/` | Design documents, rules library, research notes, milestone briefs, ADRs |

## How the AI thinks

The AI opponent is built on decision making under uncertainty, following Mykel Kochenderfer's
[*Decision Making Under Uncertainty: Theory and Application*](https://web.stanford.edu/group/sisl/public/dmu.pdf)
(MIT Press, 2015). Section numbers below refer to that book. The AI sees only what a human
opponent would see: it never peeks at your true rule.

This is the design the AI grows into. The prototype builds one level on hard evidence only: it rules
out your rules, gives you the colour expected to rule out the most, guesses once one rule is left, and
places where most of its own rules allow. Soft evidence, difficulty levels and scaled thinking time
come later ([technical design](docs/technical-design.md#ai-opponent)).

### A belief over your rules

Your secret is small: one of your 5 public rules is true. The AI keeps a **belief**, five
probabilities that sum to 1, and updates it with Bayes' rule after each of your turns (§2.2.2
Inference in Temporal Models, §6.2.1 Discrete State Filter):

```
belief(r) ∝ P(what you did | rule r is true) × previous belief(r)
```

The evidence comes in two strengths:

- **Hard evidence.** The game enforces your true rule, so a placement that breaks rule *r* proves
  *r* is fake, and a skip rules out every rule that would have allowed a cell. This evidence can
  never mislead.
- **Soft evidence.** *Which* legal cell you picked hints at your rule, and this is where hiding
  works: a cell that satisfies all 5 of your rules reveals nothing. The AI weighs it with a model of
  how you play (careless or careful), so it can be misled.

The entropy of the belief, between 0 and log₂5 ≈ 2.32 bits, measures how hidden you still are.

### Three decisions each turn

| Decision | Idea | Book |
| --- | --- | --- |
| Which colour to give you | Treat the colour as a probe: pick the one expected to shrink the belief most, or to force a revealing skip (value of information) | §3.2.2 |
| When to guess | Guessing now is worth 2p − 1 (p = top belief). Guess when that beats the value of waiting, which drops as you get close to guessing the AI's rule | §3.1.3, §6.5.1 |
| Where to place its own ball | Score each legal cell on staying hidden, keeping enough legal cells to avoid skips, and pressuring you; never break a fake rule needlessly | §3.1.6 |

To stay hidden, the AI also tracks what *you* can deduce about *its* rules, since every move is
public.

### Staying unpredictable

A predictable hider is easy to read. The AI randomises which rule it makes true and, when it must
break a fake rule, which one it breaks (mixed strategies, §3.3 Games).

### Difficulty levels

The levels differ in how the AI models you and how far it thinks ahead, never in what it can see.

| Level | Models you as | Thinks ahead |
| --- | --- | --- |
| Easy | Placing at random; makes believable mistakes | No lookahead; guesses only when very sure |
| Normal | A careless player, plus hard evidence | One step |
| Hard | A player who deliberately hides (level-k reasoning, §3.3.3) | Monte Carlo tree search over sampled futures (§4.6.4, §6.5.4), also during your turn |

Thinking time is up to 5 seconds and grows with how hard the choice is. On Easy and Normal a long
pause honestly means the AI is unsure; Hard adds random variation so its pauses can't be read.

All of this stays inside the AI; the game never shows these numbers to the player during a match.
The full research behind it, with sources, is in
[docs/ai-decision-theory-research.md](docs/ai-decision-theory-research.md).

## Credits

Art by [Kenney](https://kenney.nl) (see `License.txt`).
