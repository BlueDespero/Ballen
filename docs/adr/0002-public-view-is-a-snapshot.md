# PublicView is an immutable snapshot

What a player (human UI or AI) may know about a match is handed over as a `PublicView`. It is a copy
built for one viewer and holds no reference to the match object. We chose this over a read-only wrapper
around the live match because a wrapper keeps a back-reference that code (or reflection, such as
`get()`) could follow to the opponent's true rule. With a snapshot, "the AI cannot reach hidden state"
is something a test can actually prove. Building a copy every turn costs very little on a 6 × 6 board.

## Consequences

- The snapshot never includes the opponent's legal cells, because those would reveal the true rule.
- The online server can later send the same snapshot to each client.
