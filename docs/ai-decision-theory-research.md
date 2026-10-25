# A five-number belief powers Ballen's opponent

Ballen's AI can be built almost entirely from textbook Kochenderfer, and the reason is that the hidden variable is tiny. The opponent's secret rule takes only 5 values, so the AI's knowledge fits in a **5-entry belief vector updated exactly by the discrete state filter** (DMU §2.2.2 / §6.2.1). That needs no sampling, no particle filter and no offline solver, and it runs in well under a millisecond. The three decisions the AI makes each turn then map onto three chapters. Choosing your ball colour is a **value-of-information probe** (DMU §3.2.2). Deciding when to guess is a **maximum-expected-utility stopping rule**: guess when confidence p clears the threshold p* = (1 + V_wait)/2 (DMU §3.1.3, §6.5.1). Choosing its own placement is **multi-attribute utility over a simulated model of what you believe about the AI** (DMU §3.1.6, §3.3.3). Difficulty should change *what the AI believes about you* (level-k reasoning), *how carefully it chooses* (a softmax precision λ) and *how far it looks ahead* (0 / 1-step / Monte Carlo search). It should never change what the AI can see. A full equilibrium solve is out of reach and isn't needed; randomisation tuned by self-play does the anti-exploit work. Showing the theory to players works best as a post-match "AI's mind" replay, the pattern NYT WordleBot and Chess.com Game Review use. Live analysis belongs only in an opt-in, unranked Lab mode, which keeps the rule that a normal match never deduces for the player. One caveat on sources: the Stanford PDF is the 2015 book *Decision Making Under Uncertainty* (DMU), not the 2022 *Algorithms for Decision Making* (ADM). The Google Drive file could not be opened, and its identification as ADM is **unconfirmed**.

**Terminology.** This research says "bluffing" loosely. In Ballen every move is legal; it means choosing moves that give away as little as possible about your true rule.

**How to read this report.** Paragraphs that open with **Sourced** report what the cited sources say, with an inline link. Paragraphs that open with **Design inference** are proposals for Ballen built from those sources; nothing published covers Ballen itself. Formulas marked "standard form" are written in Kochenderfer's notation but were not copied verbatim from the book. Only the table of contents and Chapter 2 of DMU could be extracted. All timing figures are analytical estimates, not GDScript benchmarks.

## Two Kochenderfer books split the job, and the Drive file is probably the second

**Sourced.** The Stanford PDF is *Decision Making Under Uncertainty: Theory and Application* by Mykel J. Kochenderfer, with contributors including Christopher Amato and Jonathan P. How (MIT Press, MIT Lincoln Laboratory Series, **2015**) ([DMU PDF](https://web.stanford.edu/group/sisl/public/dmu.pdf)). Its Part I (Theory) runs from Ch. 2 Probabilistic Models through Ch. 7 Cooperative Decision Making. Its only adversarial game theory is **§3.3 Games** (§3.3.1 Dominant Strategy Equilibrium, §3.3.2 Nash Equilibrium, §3.3.3 Behavioral Game Theory, p. 71), and its multiagent planning (Ch. 7, Dec-POMDPs) is cooperative only ([DMU PDF](https://web.stanford.edu/group/sisl/public/dmu.pdf)).

**Sourced.** The successor is *Algorithms for Decision Making* by Kochenderfer, Wheeler and Wray (MIT Press, published 16 Aug 2022, 700 pp., examples in Julia) ([Penguin Random House](https://penguinrandomhouse.com/books/isbn/9780262047012)). It adds a whole Part V, Multiagent Systems: Ch. 24 Multiagent Reasoning, 25 Sequential Problems, 26 State Uncertainty, 27 Collaborative Agents ([GitHub mirror](https://github.com/standardgalactic/algorithmsbook)). Free per-chapter PDFs exist for chapters 1–16, 19 and several appendices, but not for Part V ([GitHub mirror](https://github.com/standardgalactic/algorithmsbook)).

**Sourced.** The user's Drive file loads only a viewer page titled **"dm.pdf"**. No author, contents or page count are visible without signing in, and the download endpoint was blocked ([Drive viewer](https://drive.google.com/file/d/1drcYW3iJz4wnnCqjuVwQyc5a6eC7i6cu/view?usp=sharing)). Two facts point to ADM. First, ADM's official free PDF has the same filename, `algorithmsbook.com/files/dm.pdf` ([algorithmsbook.com](https://algorithmsbook.com/)). Second, an Aalto University "decisions" course link to `dm.pdf` returns a 302 redirect to **this exact Drive file ID** ([Aalto redirect](https://users.aalto.fi/~ltuuri/apu/decisions/files/dm.pdf)). Neither fact proves the identification, so the developer should confirm it by opening the file. The ADM column below assumes the identification holds.

The practical upshot is that DMU covers single-agent belief, value of information and planning in depth, while ADM is the better book for the adversarial side of Ballen. The table maps each Ballen technique to both books so the developer can study alongside the build. DMU sections and page numbers are verified from its table of contents. ADM chapter titles are verified. ADM sections in Ch. 3, 4 and 19 are verified from a TOC scan ([obalkyknih TOC scan](https://obalkyknih.cz/file/toc/773406/pdf)); ADM Part V section names come from recollection and are marked "unverified".

| Ballen technique | DMU 2015 (Stanford PDF) | ADM 2022 (likely the Drive file) |
|---|---|---|
| Belief over opponent's true rule | §2.2.2 Inference in Temporal Models, Eq. 2.33 / Alg. 2.1 (p. 29); §6.2.1 Discrete State Filter (p. 136); §2.2.1 naive Bayes (p. 26) | §19.2 Discrete State Filter; §3.2 Inference in Naive Bayes Models |
| Opponent-type node, learning β across games | §2.1.4 Bayesian Networks (p. 17); §2.3.2 Bayesian Parameter Learning (p. 42) | Ch. 2 Representation; §4.2 Bayesian Parameter Learning |
| Colour pick as information probe | §3.2.2 Value of Information (p. 66); §5.1 Exploration and Exploitation | Ch. 6 Simple Decisions (VOI section, number unverified); Ch. 15 |
| When to guess | §3.1.3 Maximum Expected Utility; §4.2.7 Closed/Open-Loop Planning; §6.5.1 Lookahead with Approximate Value Function | Ch. 6; Ch. 22 Online Belief State Planning |
| Own placement / bluffing | §3.1.6 Multiple Variable Utility Functions; §3.3.3 Behavioral Game Theory | Ch. 24 (response models, softmax; unverified sections); Ch. 26 |
| Mixed strategies, Nash | §3.3.1–3.3.2 | Ch. 24 (Nash, fictitious play; unverified sections) |
| Level-k / softmax difficulty | §3.3.3 (p. 71); §3.1.7 Irrationality | Ch. 24 (hierarchical softmax; unverified section) |
| Ballen as a formal model | §6.1.2 POMDPs; §6.1.4 Belief-State MDPs | Ch. 26 State Uncertainty (partially observable Markov games) |
| Run-time search for Hard | §4.6.3 Sparse Sampling; §4.6.4 and §6.5.4 Monte Carlo Tree Search | Ch. 9 Online Planning; Ch. 22 |
| Not needed at Ballen's scale | §2.2.5 Approximate Inference; §6.2.3 Particle Filter; §6.3–6.4 exact/offline POMDP | §19.6 Particle Filter; Ch. 20–21 |
| Explaining the AI to players | §12.2.1 Trust and Value of Decision Logic Transparency; §12.2.2 Designing for Different Levels of Certainty | — |

## Belief updating collapses to Bayes' rule with a hard mask

**Sourced.** DMU gives recursive Bayesian estimation as Eq. 2.33, P(s_t | o_{0:t}) ∝ P(o_t | s_t) Σ P(s_t | s_{t−1}) P(s_{t−1} | o_{0:t−1}). Algorithm 2.1 implements it as b_t(s) ← P(o_t | s) Σ_{s'} P(s | s') b_{t−1}(s') ([DMU PDF §2.2.2](https://web.stanford.edu/group/sisl/public/dmu.pdf)). Any state given zero likelihood keeps zero posterior mass, and the posterior must be renormalised each step ([CTU lecture notes](https://zimmerk.pages.fel.cvut.cz/beyond-normal-distributions-lecture-notes/bayes_filter/Bayes_filter.html)).

**Design inference.** In Ballen the hidden state is the opponent's true rule R ∈ {r1..r5}, and it never changes, so the transition is the identity. The board, the colour the AI chose and the move history are all public and can be conditioned on for free. The filter therefore reduces to **b_t(r) ∝ P(o_t | r, board, colour, history) · b_{t−1}(r)**. This is mathematically the naive-Bayes classifier of DMU §2.2.1: the "class" is the true rule, and each opponent turn is a feature. Because R is static, the AI can also recompute the posterior from the full move log every turn. That lets the opponent model change mid-game without inconsistency.

The likelihood should have two layers. The **hard layer** is exact, because the engine enforces the true rule. A placement at x is possible under r only if x is in r's legal set A_r for that colour. A skip is possible only if A_r is empty. Hard evidence therefore **can never mislead**. When a player deliberately breaks fake rule q, the only thing they reveal is that q is fake, which is true. Skips are forced rather than chosen, which makes them the most informative event in the game: every candidate rule that would have allowed some cell is eliminated. The **soft layer** models *which* legal cell the opponent picked, and that layer is where bluffing operates. The AI should anchor its guess on the hard-consistent set and use soft evidence only to break ties.

**Sourced.** The standard template for a soft layer is Boltzmann-rational action selection, P(a) ∝ exp(−β·cost), where β "controls the degree of optimality". This is the inverse-planning approach to inferring goals from actions, credited to Baker et al. (2009) ([arXiv 2407.16770](https://arxiv.org/html/2407.16770v1)).

**Design inference.** Three soft models make a natural ladder.

- **Uniform opponent:** P(x | r) = 1/|A_r|. This produces a *size principle*. If x is legal under r1 with 4 legal cells and under r2 with 20, the move favours r1 by **5:1**. Over a game this strongly rewards narrow rules, and a bluffer can exploit it.
- **Hider opponent:** P(x | r) ∝ exp(β·k(x)) over A_r, where k(x) counts how many of the opponent's 5 listed rules cell x satisfies. A cell with k = 5 carries almost no information beyond the hard mask, which is correct, because a smart human plays exactly those cells.
- **Mixture:** keep a joint 5 × K belief over (rule, opponent type). In DMU §2.1.4 terms this is a Bayesian network in which R and a type node τ are both parents of every observation. The AI then learns during the match whether it faces an honest or a bluffing human. A lapse term, (1−ε)·policy + ε·uniform-over-A_r, stops the soft layer from ever zeroing out a rule that is still hard-consistent.

The core update is short enough to show in full:

```
# logb[r] starts at log(1/5); alive[r] starts true
for r in 5:
    if not alive[r]: continue
    var A = legal_cells(rule[r], board, colour, owner, history)  # same code the engine uses
    if obs.is_skip:
        if A.size() > 0: alive[r] = false
        continue
    if not A.has(obs.cell): alive[r] = false; continue
    logb[r] += log(soft_likelihood(obs.cell, A))
normalize_log(logb, alive)   # log-sum-exp over alive rules
```

**Sourced.** Log-sum-exp shifts every term by the maximum before exponentiating, so nothing overflows and the sum cannot collapse to zero ([Gundersen](https://www.gregorygundersen.com/blog/2020/02/09/log-sum-exp/)).

**Design inference.** Store hard zeros as a boolean `alive` mask, not as log(0). Have the AI call the **same rule predicates the engine uses**. If every rule ever ends up dead, the AI's rule code disagrees with the engine's; assert on that and fall back to the last valid belief.

The belief also gives a measure of hiddenness: Shannon entropy H(b) = −Σ b(r) log₂ b(r). It runs from 0 bits (the AI knows the rule) to log₂5 ≈ **2.32 bits** (fully hidden). Perplexity 2^H(b) reads as "how many of your rules still look plausible", from 1 to 5, which makes it a natural number to show players later. The same machinery runs in reverse. Every placement is public, so the AI can compute **exactly what a consistency-filtering opponent believes about the AI's own rules**. That simulated belief, b_opp, drives both hiding and danger estimation.

## Colour, guess and placement are three textbook decisions

### Your ball colour is a value-of-information probe

**Sourced.** Value of information is DMU §3.2.2 (p. 66), and exploration versus exploitation is §5.1 ([DMU PDF](https://web.stanford.edu/group/sisl/public/dmu.pdf)). In the standard form, VOI = Σ_{o'} P(o')·EU*(after o') − EU*(now). It is never negative for a single decision-maker, and it ignores the cost of acquiring the observation. For deduction games, one-step greedy probing comes very close to optimal. On Wordle, the best greedy combined valuation scored **7,944 total guesses against a proven optimum of 7,920** over 2,315 secrets, about 0.01 extra guesses per word. Pure worst-case splitting (Knuth-style MaxSizeSplit) scored 8,510, and widening the search closed the gap entirely ([Cunanan & Thielscher, IJCAI 2023](https://arxiv.org/pdf/2305.09111)). Entropy, partition-count and worst-case criteria pick different "best" probes and need tie-breaks ([Cunanan & Thielscher](https://arxiv.org/pdf/2305.09111); [Kooi 2005](https://content.iospress.com/articles/icga-journal/icg28105)).

**Design inference.** Ballen has one twist that Wordle lacks: **the responder is an adversary who picks the observation**. Score each of the 4 colours on three things.

1. **Expected information gain:** EIG(c) = H(b) − Σ_o P(o | c)·H(b'_o), where o ranges over at most 36 cells plus a skip. Report this under two opponent models. Under the uniform model, the opponent picks any legal cell at random. Under the adversarial "hider" model, the opponent picks the cell that keeps the most of its rules consistent, which gives the information the AI gains even when the opponent hides as well as it can. A blend such as 0.7 adversarial + 0.3 uniform is a reasonable starting point.
2. **Skip pressure:** add a separate utility for P(skip | c). It is worth more as the opponent's skip count rises, and at 2 skips a forced skip is an outright win. This is additive multi-attribute utility (DMU §3.1.6).
3. **Self-harm:** subtract the expected damage the opponent's likely placement does to the AI's own legal cells next turn.

There is a game-theoretic catch here too. If the AI always gives the most informative colour, an attentive player can read what the AI suspects from the colours it chooses. Hard should therefore sample colours through a softmax rather than take the argmax.

### Guess when confidence beats the value of waiting

**Sourced.** DMU covers the maximum expected utility principle (§3.1.3) and lookahead with an approximate value function (§6.5.1), but its table of contents has **no dedicated optimal-stopping section** ([DMU PDF](https://web.stanford.edu/group/sisl/public/dmu.pdf)). A competitive-deduction result supports risk-taking when behind. In *Guess Who?*, bisection minimises the expected number of questions but **is not the optimal strategy**, and a trailing player should make a bold, lower-probability bid ([Nica, arXiv 1509.03327](https://arxiv.org/html/1509.03327v3)).

**Design inference.** Set U(win) = +1, U(loss) = −1 and U(draw) = 0. Guessing now then has expected utility **2p − 1**, where p = max_r b(r). Waiting is worth V_wait, which combines four things:

- the chance the opponent guesses the AI's rule correctly first, read from the simulated b_opp;
- the chance the opponent guesses wrong;
- the AI's own skip-out risk, which is non-zero only at 2 skips, when the opponent can choose a colour with no legal cell;
- the expected confidence after one more observation, computed with the colour machinery above.

The rule is to **guess when p ≥ p* = (1 + V_wait)/2**. The sanity checks behave correctly. If the opponent is about to guess the AI correctly, V_wait → −1 and p* → 0, so any guess beats a certain loss. If the AI is safely hidden and the next colour is informative, waiting dominates. Below p = 0.5 a guess has negative expected utility and is justified only by danger. Two cheaper variants serve the lower difficulties: a danger-interpolated threshold, lerp(0.95, 0.35, danger), with a zero threshold forced when the AI is at 2 skips and exposed, or a fixed high threshold for Easy. For the forced guess at a full board, the GDD already sets the utilities: exactly one right guess wins, and both right or both wrong is a draw (U = 0). So the forced guess should simply name the top-belief rule.

### Own placement means managing what the opponent believes about you

**Sourced.** DMU covers multiple-variable utility (§3.1.6) and behavioural game theory (§3.3.3) ([DMU PDF](https://web.stanford.edu/group/sisl/public/dmu.pdf)). Information-Set MCTS searches trees of information sets rather than states so that it can handle hidden information ([Cowling, Powley & Whitehouse 2012](https://eprints.whiterose.ac.uk/75048)).

**Design inference.** The AI's true rule restricts which cells it may play. Among those cells, score each one on three terms:

- **hide:** the entropy of b_opp after the move. A cell legal under all 5 of the AI's displayed rules reveals nothing, while a cell that breaks fake j proves j fake to the opponent.
- **mobility:** the worst-case number of legal cells for the AI's true rule across the 4 colours the opponent might give next.
- **pressure:** how much the move shrinks the opponent's candidate rules' legal sets, which raises the opponent's skip risk.

The weights should move with the situation. Weight hide when b_opp is sharp, mobility when the AI has 2 skips, and pressure when the opponent has 2 skips. Two rules follow directly:

- **Never break a fake when a cell satisfying all of your live rules exists.** Breaking one then gives information away for nothing.
- When a break is forced, **sample which fake to break** with a softmax over the information each break would leak, instead of always choosing the least costly break. A fixed tie-break is a tell.

Using the same hider model for reading the opponent and for hiding the AI keeps the whole system self-consistent.

## Randomisation and level-k reasoning build an honest difficulty ladder

**Sourced.** Every strong hidden-information agent randomises. DeepNash (Stratego) "randomises between seemingly equivalent actions to prevent exploitable tendencies" and varies its initial deployments so that opponents cannot spot patterns across games. Its play converges toward a Nash equilibrium, and it reached an **84% win rate against top experts**. It also bluffed, sending a weak Scout to pose as a strong piece ([DeepMind](https://deepmind.google/discover/blog/mastering-stratego-the-classic-game-of-imperfect-information/)). A pro said of Pluribus (poker), "Its major strength is its ability to use mixed strategies" ([CMU](https://www.cmu.edu/news/stories/archives/2019/july/cmu-facebook-ai-beats-poker-pros.html)). DeepRole (Avalon) combines counterfactual regret minimisation with deductive reasoning over joint role beliefs, and it beat humans as both cooperator and competitor ([arXiv 1906.02330](https://arxiv.org/abs/1906.02330v1)).

**Design inference.** Any deterministic pattern is exploitable in Ballen. Two examples: an AI that always makes its broadest rule true loses to a turn-1 guess once players learn the habit, and an AI that always breaks the least plausible fake teaches players that the surviving plausible fake is never true. Setup should therefore **sample the true rule**:

1. For each of the 5 rules, estimate the AI's win rate S(r) if that rule were true, using 50–200 quick self-play games.
2. Sample with p(r) ∝ exp(λ_setup·S(r)).
3. Apply a floor of about 10% per rule, so no rule is ever "never true".

The composition of the 5 public rules drawn from the deck should be randomised as well. Mixing rates have no published solution for a game shaped like Ballen. Tune them empirically: run headless AI-vs-AI matches against a pattern-detecting seeker and raise randomisation until the seeker's edge disappears. This is a hand-built version of fictitious play / best-response checking (ADM Ch. 24).

**Sourced.** The cognitive hierarchy model treats level-0 players as uniform randomisers and has each level-k player best-respond to a Poisson-weighted mix of the lower levels. Its single parameter τ had a **median estimate of 1.61 across 24 datasets**, and τ ≈ 1.5 is offered as a general default ([Camerer, Ho & Chong 2004](https://www.csc2.ncsu.edu/faculty/mpsingh/local/Social/f24/wrap/readings/Camerer+Ho+Chong-cognitive-hierarchy-of-games-2004.pdf)). The authors argue that plain level-k, in which each level assumes everyone else is exactly one level below, produces "increasingly irrational expectations" as k grows ([Camerer, Ho & Chong](https://www.csc2.ncsu.edu/faculty/mpsingh/local/Social/f24/wrap/readings/Camerer+Ho+Chong-cognitive-hierarchy-of-games-2004.pdf)). Logit quantal response with a precision parameter λ comes from McKelvey & Palfrey (1995) ([Caltech](https://resolver.caltech.edu/CaltechAUTHORS:20171128-164515991)). The open-source Gambit package computes logit QRE for small games ([Gambit docs](https://gambitproject.readthedocs.io/en/stable/tutorials/advanced_tutorials/quantal_response.html)). The text of DMU §3.3.3 could not be retrieved, so it is not confirmed whether that section presents level-k models specifically.

**Sourced.** Mick West's advice on weakening an AI is to make "intelligent mistakes": "figuring out what you should do, and then not doing it", and only where the miss won't look foolish. Players are "keenly aware" of deliberate throws, and those undermine their sense of accomplishment ([Game Developer](https://www.gamedeveloper.com/game-platforms/bonus-feature-intelligent-mistakes-key-to-believable-ai)).

**Design inference.** That gives an explainable ladder whose levels differ in **what the AI believes about you, not in what it can see**.

| Knob | Easy | Normal | Hard | Study |
|---|---|---|---|---|
| Model of you (level) | Level-0: you place at random among legal cells | Level-0 likelihood + hard elimination | Cognitive-hierarchy mix of honest and bluffing hider, τ ≈ 1.5, adapted during the match | DMU §3.3.3; ADM Ch. 24 |
| Belief update | Tempered (likelihood^β, β < 1), slight drift toward uniform | Exact filter | Exact filter, joint (rule, type) belief | DMU §6.2.1, §2.3.2 |
| Own hiding | Near-honest: uniform among legal cells | Keeps fakes alive (max-k cells) | Full hide/mobility/pressure utility plus softmax over which fake to break | DMU §3.1.6 |
| Colour pick | Random or low-λ softmax | 1-step expected information gain + skip pressure | Blended adversarial/uniform EIG, softmax-mixed so it doesn't tell | DMU §3.2.2 |
| Guess rule | Fixed high threshold (~0.95) plus occasional nervous guesses | Danger-interpolated threshold | p ≥ (1 + V_wait)/2, with V_wait from rollouts | DMU §3.1.3, §6.5.1 |
| Choice precision λ | Low | Medium | High but finite (mixing is what makes Hard hard to exploit) | QRE; ADM Ch. 24 |
| Lookahead | None | 1-step | Root-sampled MCTS, ~100–500 simulations, depth 6–10 | DMU §4.6.4, §6.5.4; ADM Ch. 22 |

Easy's mistakes should look human: over-weighting the latest move, falling for a fake that has been "confirmed" several times, or breaking one of its own fakes when the better cell wasn't obvious. It should never guess a rule you have already provably eliminated. Hard should never guess on thin evidence. A lucky early correct guess is the thing players most readily read as cheating. That makes the fairness architecture a feature to build deliberately: pass the AI a `PublicView` object that lacks your `true_rule` field and unit-test it. DMU §12.2.1, on the value of decision-logic transparency, is the chapter to study for this.

## Exact belief is sub-millisecond; only Hard needs a search budget

**Sourced.** Exact inference in general Bayesian networks is NP-hard, which is why DMU introduces sampling methods (§2.2.4–2.2.5) and particle filters (§6.2.3) ([DMU PDF](https://web.stanford.edu/group/sisl/public/dmu.pdf)). POMCP runs UCT over action–observation histories and needs only a black-box simulator. On RockSample(11,11) it **matched SARSOP with about 4 s of online computation versus SARSOP's 1,000 s offline**, and it played Battleship (~10^18 states) and PocMan (~10^56 states) ([Silver & Veness 2010](https://Www.Gwern.net/doc/reinforcement-learning/model/2010-silver.pdf)). Its default rollout policy is uniform but can be restricted to "preferred actions", and compiled implementations run hundreds of thousands of simulations per second ([Silver & Veness](https://Www.Gwern.net/doc/reinforcement-learning/model/2010-silver.pdf)). Pluribus showed that a limited-lookahead search budget is the lever separating strength levels: it was trained in about 12,400 core hours, against Libratus's roughly 15 million ([CMU](https://www.cmu.edu/news/stories/archives/2019/july/cmu-facebook-ai-beats-poker-pros.html)).

**Design inference.** Formally, Ballen is a two-player zero-sum partially observable Markov game (ADM Ch. 26). The board alone has about 5^36 ≈ 1.5×10^25 configurations, so exact and offline POMDP or equilibrium solving (DMU §6.3–6.4) is hopeless. But Ballen's network is a single 5-valued parent with observed children, so **exact inference is linear** and the NP-hardness and particle-filter material can be skipped. Estimated costs per decision:

- **Belief update:** 5 rules × ≤36 cells of predicate calls, about 6,500 checks if rules scan history.
- **Colour scoring:** about 720 legality checks plus about 740 multiplications.
- **Placement scoring:** about 1,000 checks.
- **Two-ply colour lookahead:** about 22,000 outcome evaluations, likely under 50 ms.

Underflow is a non-issue with per-step normalisation. Even an unnormalised 40-move product of 1/36 likelihoods is about 10^−62, well inside double range.

For Hard, use root-sampled MCTS. Sample the opponent's rule from the exact belief, simulate with the cheap heuristics as rollout policy, and value the "guess" action analytically as 2b(k) − 1 instead of searching it. Restrict candidate cells to the heuristic's top 4–6 to keep branching low. Key tree nodes by **public history only**, as POMCP and ISMCTS do. Otherwise the search "knows" the sampled rule deeper in the tree and the AI effectively cheats against itself (strategy fusion).

To make this affordable in GDScript, encode the board as 64-bit integer bitmasks (36 cells fit), one per colour plus occupancy, and write each rule as a mask function of shifts and ANDs. Popcount needs a 16-bit lookup table. The estimated throughput is **50–200 simulations per 300 ms on a mid-range phone**. Spread the search across frames with `await get_tree().process_frame`, or move it to a thread. Thread support on web exports depends on cross-origin isolation and must be checked per target. A C# or GDExtension port would plausibly gain 10–100×. Two Godot details are unverified and should be checked against the documentation: that GDScript `float` is 64-bit, and the popcount situation. Every timing here is an analytical estimate that needs in-engine measurement.

## Show the AI's mind after the match, never during it

**Sourced.** The closest precedent is NYT WordleBot. It analyses a puzzle **only after you finish**, replays the game turn by turn with "Words Left" and "Info Gained", and scores **Skill and Luck from 0 to 99**. Opening it does not affect your streak ([Beebom](https://beebom.com/puzzle/wordle-bot-explained/)). Critics call it snarky, saying it would "skin you alive" if you like playful guesses ([PC Gamer](https://pcgamer.com/nyt-wordlebot-wordle-companion)). One devoted player enjoyed the feedback but disliked its "subtle smugness", the pressure toward one optimal style, and a luck metric that credits wins to chance ([Substack essay](https://thefriscalatingdusklight.substack.com/p/a-complicated-love-hate-relationship)). Chess.com Game Review v2 frames missed tactics as review material to treat "like puzzles from your own games", and its coach text highlights squares on the board ([Chess.com](https://www.chess.com/news/view/chesscom-launches-game-review-v2)). On live evaluation bars, Luke McShane notes that "the swings heighten the excitement", but explaining every fluctuation "can distract from the flow", and a bar "may present equality even when both sides are walking a tightrope" ([Spectator](https://spectator.com/article/chess-on-the-telly/)). Poker draws a hard line: solver-style real-time assistance during play can bring permanent bans, and **31 GGPoker accounts** were reported banned for it in one period after the GGPoker / GTO Wizard partnership ([VIP-Grinders](https://www.vip-grinders.com/poker-tools/gto-wizard/)). F.E.A.R.'s developers had the AI "constantly communicate what it was thinking", and they concluded that "it didn't matter how smart the AI was as long as the player didn't notice" ([Digitec](https://www.digitec.ch/en/page/why-the-ai-in-fear-is-considered-a-reference-and-which-game-could-change-that-8751)).

**Design inference.** Ballen should treat any live display of beliefs, its own or the player's, as the equivalent of poker's real-time assistance. Even showing players how hidden *they* are mid-match would deduce for them, because it is public information they are meant to work out themselves. The theory belongs in four places, each tied to a chapter.

| Feature | When | Concept it teaches | Study |
|---|---|---|---|
| **"AI's mind" replay:** turn slider, 5 belief bars over your rules, tap a bar to highlight the moves that shifted it ("your skip on turn 7 made Rule C 3× likelier"), a "decision point" flag ("P(top rule) 0.81 > threshold 0.75") | Post-match | Discrete filter, MEU stopping | DMU §6.2.1, §3.1.3 |
| **Hiddenness meter and colour explainer:** your entropy in bits or "effective rules left", plus "I gave you red because it split your rules 3/2" | Post-match | Entropy, value of information | DMU §3.2.2 |
| **Opponent personality cards:** e.g. *Scout* (VOI seeker), *Gambler* (low guess threshold), *Sphinx* (maximises your uncertainty); difficulty described as reasoning depth ("Hard assumes you might be bluffing") | Pre-match | Level-k, softmax precision | DMU §3.3.3; ADM Ch. 24 |
| **Lab / Analyst mode:** live posterior over the AI's rules for the player, spectated AI-vs-AI games with all beliefs visible, lessons ordered like the book | Separate opt-in mode, unranked | The whole stack | DMU Ch. 2–6 |

In-match flavour can follow the F.E.A.R. pattern only for the AI's *own* state, such as "I'm torn between two of your rules…". Even that leaks the AI's progress, so tune barks as a deliberate part of the bluffing game, or put them behind a toggle. On Hard, barks could even be randomised so they bluff too. Achievements turn the theory into goals:

- **Ghost:** finish with the AI's belief about you above X bits.
- **Perfect bluff:** the AI guessed wrong at ≥ 80% confidence.
- **Information miser:** win while leaking little information per turn.

The WordleBot backlash sets the tone rules. Make the AI playful rather than smug, present its play as one style rather than "the answer", explain luck plainly ("the colour you were given was unlucky"), and keep a basic replay free. Ballen also has an answer to the "solved game" complaint that Wordle lacks. Because Ballen is adversarial, the replay can show *where the AI's model of you was wrong*, which turns a bluff that beat the AI into something to be proud of.

**Gaps.** No published hidden-role or deduction game was found that shows AI belief bars to players. An auto-explanation study of a board-game AI claims explanations raise satisfaction, but only its abstract was seen ([Chiou & Wong 2010](https://dl.ifip.org/IFIP-AICT-333/hal-01056333)). The reception of these showcase ideas is therefore a playtesting question.

## Conclusion

Ballen's rules make the textbook unusually literal. Because the engine enforces the true rule, the hard part of the likelihood is a fact rather than a model. The only room for deception, and so the only place game theory is needed, is the soft layer: which legal cell a player chose, and which colour the AI gives. That boundary is both the AI's design principle (anchor guesses on hard evidence, randomise everything soft) and the player's skill ceiling, and it is what the post-match replay should teach. The difficulty ladder carries the same idea. Easy, Normal and Hard are not handicaps but three successively better theories of the human. That makes difficulty honest and easy to explain, and it gives players a reason to climb: beating Hard means out-bluffing an AI that expects you to bluff.

For a developer learning this material, the build order matches the book's order:

1. Ch. 2 / §6.2.1 gives a belief that already plays a respectable Normal.
2. §3.1 and §3.2.2 add the colour and guess decisions.
3. §3.3 and ADM Ch. 24 add the mixing that keeps the AI from being exploited.
4. §4.6 / §6.5 and ADM Ch. 22 add search, needed only for Hard.

Two open items should be settled before relying on chapter citations. First, open the Drive `dm.pdf` to confirm it is ADM. Second, check the unverified ADM Part V section numbers against that PDF. One build item also gates tuning: a self-play harness to measure exploitability, which no published source can supply for a game shaped like Ballen.
