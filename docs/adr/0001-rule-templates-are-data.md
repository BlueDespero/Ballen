# Rule templates are data, not code

A rule is a template plus blank values, and the template itself is also data: a JSON tree of parts
(selectors, filters, conditions, combiners) with placeholders for its blanks. We chose this over one
GDScript builder function per template because adding a template, not only a rule, should need no
code. That serves player-made rules later and keeps every rule checkable by the same evaluator.

## Consequences

- Some rules need richer parts than a flat "select, filter, count" chain. R10 ("never complete a line
  of 3") needs a selector that yields groups (the lines through the target cell) and a condition over
  groups.
- A rule the parts can't express gets a GDScript fallback with the same `(context) -> bool`
  signature. That is the exception, and every fallback is a hint that a part is missing.
