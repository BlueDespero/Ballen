# Rules compile to cell bit masks

Rules stay data (ADR 0001), and the Parts interpreter still defines what a rule means. But `RuleChecker`
answers from a compiled form: when a `Rule` is built, `RuleCompiler` turns its tree into conditions over
36-bit cell masks (one bit per cell, kept by `Board` for the occupied cells, each colour and each owner). These
give the legal cells for every target of a placement check at once.

We chose this over keeping only the interpreter. The interpreter walks the tree once per empty cell and cost
0.2–1.6 ms per check, which ruled out Hard's tree search (thousands of checks per move). Hand-written GDScript
per rule was the other option, and it was rejected because it breaks ADR 0001.

Compiled checks cost about 17 µs on desktop and 33 µs in Chrome, against 370 µs and 590 µs interpreted.

## Consequences

- There is still one source of legality: the match, the UI and the AI all ask `RuleChecker`.
- A tree the compiler can't handle (a new part, or a part in a new shape) returns null, and `RuleChecker`
  interprets that rule. `test_rule_compiler.gd` checks that every built-in rule compiles.
- The compiled form must allow exactly the cells the interpreter allows. `test_rule_compiler.gd` checks this
  for every built-in rule and for test trees covering every part, on random positions and on positions from
  played matches. A new part needs its compiled case and a test tree.
- A rule is compiled when it is built and its compiled form never changes. Each check works in fresh
  objects, so a rule keeps no trace of how it has been used. Otherwise the views of two matches that differ
  only in a secret rule could differ (ADR 0002, `test_public_view.gd`).
