# Words Poker — Claude Code Project Kickoff

This document is the starting point for using Claude Code to build Words Poker v12.3. Place at repo root as `CLAUDE.md`. Reference the full design spec (`docs/spec-v12.3.md`) for design context.

-----

## How To Use This Document

1. Create a new repo: `mkdir words-poker && cd words-poker && git init`
1. Save this file as `CLAUDE.md` in the root
1. Save the v12.3 spec as `docs/spec-v12.3.md`
1. Open Claude Code in the repo: `claude` from the terminal
1. Start with the Sprint 0 setup tasks below
1. Use the prompt patterns at the bottom of this document

**Honest scope note for Claude Code:** This document scopes work that Claude Code can genuinely do alone — the LUT pipeline (Python), the Nakama backend (Go), the dictionary tooling, the test suite. **The Unity client (Section 9 of the spec) is a separate workstream that needs a Unity-experienced developer working in the Unity IDE.** Claude Code can help with C# logic but should not be the primary tool for client work.

-----

## Project Summary

Words Poker is a mobile word/poker hybrid. Players form words from hidden and shared letters while running standard poker betting rounds. Word scores translate to poker hand ranks via a precomputed lookup table, making showdowns instant and visual.

- **v12 (Heads-up):** ships first with Daily Ghost tutorial mode
- **v13 (Multiplayer 3-6 players):** ships post-soft-launch
- **MVP target:** 7-10 weeks of focused engineering

-----

## Tech Stack

|Layer             |Tech                |Why                                                 |
|------------------|--------------------|----------------------------------------------------|
|Backend           |Nakama (Go)         |Authoritative game server, proven mobile multiplayer|
|Client            |Unity (C#)          |Cross-platform mobile, **not in Claude Code scope** |
|LUT pipeline      |Python 3.11+        |Offline batch processing of dictionary              |
|Persistent storage|PostgreSQL          |Nakama default                                      |
|Session state     |Redis               |Nakama default                                      |
|Dictionary        |Trie (Go)           |O(L) validation                                     |
|Test frameworks   |`go test` + `pytest`|Standard                                            |

-----

## Repository Structure

```
words-poker/
├── CLAUDE.md                      # this file (project context for Claude Code)
├── README.md                      # human-facing onboarding
├── docs/
│   ├── spec-v12.3.md             # full design spec
│   ├── architecture.md           # generated; high-level system diagram
│   └── api-contracts.md          # generated; client/server message schemas
├── backend/                       # Nakama Go module
│   ├── go.mod
│   ├── main.go                   # Nakama plugin entry point
│   ├── match/
│   │   ├── handler.go            # MatchHandler implementation
│   │   ├── state.go              # match state machine
│   │   ├── phases.go             # phase transitions
│   │   └── handler_test.go
│   ├── dictionary/
│   │   ├── trie.go               # Trie implementation
│   │   ├── loader.go             # load 50k word list + obscurity scores
│   │   └── trie_test.go
│   ├── scoring/
│   │   ├── scrabble.go           # letter values
│   │   ├── bonuses.go            # bingo, modifier triggers
│   │   ├── score.go              # main score function
│   │   └── scoring_test.go
│   ├── modifiers/
│   │   ├── deck.go               # 10-card modifier deck v2
│   │   ├── triggers.go           # trigger evaluation
│   │   └── triggers_test.go
│   ├── lut/
│   │   ├── loader.go             # load binary LUT into memory
│   │   ├── rank.go               # percentile → poker rank
│   │   └── lut_test.go
│   └── anticheat/
│       ├── obscurity.go          # Layer 1
│       ├── cadence.go            # Layer 2
│       ├── shadow.go             # Layer 3 routing
│       └── anticheat_test.go
├── lut-pipeline/                  # Python offline pipeline
│   ├── pyproject.toml
│   ├── src/
│   │   └── lut_pipeline/
│   │       ├── __init__.py
│   │       ├── dictionary_curator.py    # filter 50k from source corpora
│   │       ├── obscurity_tagger.py      # Google Books N-gram → 1-10
│   │       ├── lut_generator.py         # enumerate boards, compute distributions
│   │       ├── serializer.py            # write binary LUT
│   │       └── cli.py
│   ├── data/
│   │   ├── raw/                          # source dictionaries (gitignored)
│   │   ├── intermediate/                 # tagged dictionary
│   │   └── generated/
│   │       ├── dictionary.bin            # Trie-serialized
│   │       └── lut.bin                   # percentile cutoffs per board
│   └── tests/
│       ├── test_curator.py
│       ├── test_obscurity.py
│       ├── test_lut_generator.py
│       └── fixtures/
└── scripts/
    ├── setup.sh                          # install deps
    ├── build_backend.sh                  # compile Nakama plugin
    ├── generate_lut.sh                   # run full LUT pipeline
    └── run_local.sh                      # start local Nakama + Postgres + Redis
```

-----

## Sprint 0 — Foundation (Day 1-2)

Initialize everything before feature work begins.

### Task 0.1: Repository scaffold

- Create directory tree above
- `git init`, `.gitignore` for Go, Python, Unity, data files
- `pyproject.toml` with dependencies: `pytest`, `tqdm`, `numpy`, `nltk` (for corpus)
- `go.mod` with Nakama runtime dependency

### Task 0.2: README.md

- Project description, setup instructions, how to run tests
- Link to spec

### Task 0.3: Local dev environment

- `scripts/setup.sh`: installs Go 1.22+, Python 3.11+, Docker
- `scripts/run_local.sh`: docker-compose for Nakama + Postgres + Redis
- Verify all services start cleanly

**Acceptance:** `bash scripts/run_local.sh` brings up Nakama dashboard at localhost:7351.

-----

## Sprint 1 — LUT Pipeline (Week 1)

**Why first:** the backend can’t assign poker ranks without the LUT. Pipeline is also pure Python, fully testable, no networking complexity. Good first build.

### Task 1.1: Dictionary curator

Filter the 50k curated word list per spec Section 3.1.

**Input:** any open-source English word list (e.g., SCOWL, dwyl/english-words)
**Filters:**

- Exclude proper nouns, abbreviations, hyphens, apostrophes
- Exclude Scrabble-only obscure words (need a stop-list — start small, iterate)
- Length 2-12 characters
- Lowercase only

**Output:** `data/intermediate/dictionary_curated.txt` with ~50k lines.

**Acceptance:** Output contains TRAIN, STRAIN, QUARTZ, BICYCLE; does not contain ZA, QI, AALII, CRWTH.

### Task 1.2: Obscurity tagger

Tag each word with obscurity score 1-10 per spec Section 10 Layer 1.

**Corpus:** Google Books N-gram English (2010-2024)
**Method:** log-frequency bucketing into deciles
**Output:** `data/intermediate/dictionary_tagged.csv` with columns `word,obscurity`

**Note:** Google Books N-gram is ~24GB compressed. For the prototype, use the `nltk` Brown corpus or Wikipedia 1M-sentence sample as a stand-in. Document the substitution in code comments.

**Acceptance:** TRAIN scores 1-2, QUARTZ scores 4-5, CRWTH scores 9-10.

### Task 1.3: LUT generator

The core compute. For each possible 4-letter community board, enumerate all valid words using community + variable hole letters, compute score distribution, store percentile cutoffs.

**Pseudocode:**

```python
def generate_lut(dictionary, scrabble_values):
    lut = {}
    for board in all_community_combinations():  # ~15k effective boards
        scores = []
        for hole_combo in random_sample_hole_combinations(board, n=1000):
            for word in find_valid_words(board + hole_combo, dictionary):
                scores.append(compute_score(word, scrabble_values))
        if not scores:
            continue
        lut[board_key(board)] = {
            'p10': percentile(scores, 10),
            'p30': percentile(scores, 30),
            'p50': percentile(scores, 50),
            'p65': percentile(scores, 65),
            'p75': percentile(scores, 75),
            'p83': percentile(scores, 83),
            'p90': percentile(scores, 90),
            'p95': percentile(scores, 95),
            'p98': percentile(scores, 98),
            'p99_5': percentile(scores, 99.5),
        }
    return lut
```

**Acceptance:** LUT covers all reachable 4-letter community boards. Total binary size ≤ 10MB. Sample query for board [‘A’,‘R’,‘I’,‘N’] returns sensible percentile distribution.

### Task 1.4: Serializer

Write LUT to compact binary format. Use protobuf or custom binary; document the schema.

**Acceptance:** `python -m lut_pipeline.cli generate --output data/generated/lut.bin` produces a file ≤ 10MB readable by Go backend.

-----

## Sprint 2 — Backend Foundation (Week 2-3)

### Task 2.1: Trie dictionary

Standard Trie in Go with insert, lookup, prefix-search operations.

**Acceptance:** Loads 50k words in <100ms. Lookup is O(L) where L = word length. Unit tests cover empty input, prefix vs full match, case insensitivity.

### Task 2.2: Scrabble scoring

Implement letter values + bingo bonus + modifier trigger evaluation.

**Modifier deck v2 (spec Section 3.7):**

1. Ending Match (-ING/-ED/-LY): +15
1. Letter Hit (Q/X/Z): +20
1. Length Lock (exactly 5 letters): +10
1. Double Up (doubled letter): +25
1. Suffix Master (-TION/-NESS/-MENT): +20
1. Consonant Storm (4+ consonants): +15
1. All Hole (uses all 3 hole letters): +30
1. Bingo Boost (REPLACES base bingo, total +30 not stacked): +30
1. Palindrome: +30
1. Triple Threat (3+ of same letter): +25

**Acceptance:** Unit tests verify each modifier trigger correctly identifies matching/non-matching words. Bingo Boost replacement (not stacking) explicitly tested.

### Task 2.3: LUT loader

Read binary LUT into in-memory hash map keyed by board state.

**Acceptance:** Loads in <500ms on cold start. Lookup is O(1).

### Task 2.4: Rank assigner

Given word score + board state, return poker rank string per spec Section 3.3.

**Acceptance:** Round-trip test — generate score distribution, verify percentile assignments match spec table.

### Task 2.5: Match handler skeleton

Nakama `MatchHandler` interface implementation. Phase state machine. No game logic yet — just transitions.

**Phases (spec Section 4):** Setup → ModifierDraft → BuildPart1 → River → BuildPart2 → Betting1 → Squeeze → FinalBet → Showdown

**Acceptance:** A test client can join a match, observe phase transitions on schedule, leave cleanly.

-----

## Sprint 3 — Core Loop (Week 3-5)

### Task 3.1: Wire scoring into match handler

Players submit words during Build phases. Server validates, scores, assigns provisional rank, broadcasts.

### Task 3.2: Read mechanic

Player submits rank prediction. Lock at end of Build. Resolve at showdown.

### Task 3.3: Modifier draft

Simultaneous blind draft from 2-card pool (heads-up). 5-second window. Auto-pick first card on timeout.

### Task 3.4: Betting logic

Standard check/bet/raise/fold with pot management. 15s time bank, triggerable once per match. Chip stack tracking.

### Task 3.5: Squeeze phase

Each player selects one hole letter to reveal. Simultaneous reveal at phase end.

### Task 3.6: Modifier Wager

Reveal vs Hide decision at Final Bet. Hide doubles points only if pot won.

### Task 3.7: Showdown resolution

Compare ranks, apply modifier triggers, resolve Read predictions, award pot.

**Acceptance for Sprint 3:** A full heads-up hand can be played end-to-end via test clients. All edge cases from spec Section 12 handled.

-----

## Sprint 4 — MVP Polish (Week 5-7)

### Task 4.1: Edge case handlers

All twelve edge cases from spec Section 12 with unit tests.

### Task 4.2: Disconnect/reconnect

30s reconnect window before auto-fold. State persistence in Redis.

### Task 4.3: Hand timeout handling

If player times out during Build, auto-lock highest-scoring valid word from current arrangement.

### Task 4.4: Logging & telemetry

Structured logging per spec Section 10.5. Per-hand event log to PostgreSQL.

### Task 4.5: Integration tests

End-to-end hand simulation via Nakama test client. Cover: normal hand, all-folds, disconnect+reconnect, time-out, both players bust.

**Acceptance for Sprint 4:** 100 simulated hands complete without crashes. All edge cases pass tests.

-----

## Coding Conventions

### Go

- `gofmt` on every save
- Errors: wrap with `fmt.Errorf("context: %w", err)`, never panic in match handler
- All match state lives in `match.State`, no globals
- One file per concept; if a file exceeds 400 lines, split

### Python

- `black` formatter, `ruff` linter
- Type hints on all public functions
- Docstrings on modules and public functions, not on obvious code
- One concept per module

### Testing

- Every public function has a test
- Test names: `TestThing_Condition_ExpectedResult` (Go), `test_thing_condition_expected_result` (Python)
- Coverage target: 80%+ on logic packages (dictionary, scoring, lut, modifiers)
- Integration tests live in `match/integration_test.go`

### Git

- Feature branches: `feature/task-X.Y-short-description`
- Commits: imperative mood, “Add Trie dictionary loader” not “Added”
- PRs reference the task number from this doc

-----

## Useful Claude Code Prompts

### Starting a new task

```
Read CLAUDE.md and docs/spec-v12.3.md sections relevant to Task 2.2 
(Scrabble scoring). Implement backend/scoring/scrabble.go and 
backend/scoring/score.go with full test coverage in scoring_test.go. 
Reference spec Section 3.7 for the modifier deck v2.
```

### Adding a feature

```
Implement Task 3.6 (Modifier Wager). Reveal vs Hide decision at Final 
Bet phase. Hide doubles modifier bonus only if player wins the pot. 
Update match/handler.go, add wager state to match/state.go, write 
unit tests covering: win-with-hidden, loss-with-hidden, win-with-revealed, 
loss-with-revealed.
```

### Debugging

```
The integration test TestFullHand_WithModifierHide is failing — the 
hidden modifier bonus is being applied even when the player loses 
the pot. Trace the issue and fix it. Don't change test expectations 
without explaining why.
```

### Reviewing

```
Review backend/match/handler.go for issues a senior Go engineer would 
flag: error handling, goroutine safety, state mutation patterns. List 
the top 5 concerns ranked by severity.
```

### Specification questions

```
docs/spec-v12.3.md says modifier #8 Bingo Boost "REPLACES base bingo 
bonus, does not stack" for total +30. Verify that scoring/bonuses.go 
implements this correctly with a unit test that would catch a stacking 
regression.
```

-----

## What’s NOT In This Document

Deliberately scoped out of Claude Code work, with the right tool for each:

|Workstream                                       |Right Tool                        |Why                              |
|-------------------------------------------------|----------------------------------|---------------------------------|
|Unity client                                     |Unity-experienced dev in Unity IDE|Visual workflows, IDE-specific   |
|LUT corpus integration (real Google Books N-gram)|Data engineer with corpus access  |License + 24GB infrastructure    |
|Monetization model validation                    |F2P economist consultant          |Requires market data, not code   |
|Tutorial UX flows                                |UX designer                       |Visual prototyping, user research|
|Anti-cheat threshold calibration                 |Live with real player data        |Telemetry-driven, not spec-driven|
|Daily Ghost AI fidelity validation               |Engineering experiment in Phase 2 |Test 250-byte payload empirically|

-----

## Definition of Done for MVP (End of Sprint 4)

The MVP is complete when:

1. Two test clients can play a full heads-up hand end-to-end
1. All spec edge cases (Section 12) have passing tests
1. LUT pipeline generates a valid lut.bin from the dictionary
1. Backend loads dictionary + LUT and serves matches
1. Scoring, modifiers, Read, Wager, Showdown all functional
1. Disconnect/reconnect handled cleanly
1. 100 simulated hands run without crashes
1. Code coverage ≥80% on logic packages

What MVP does NOT include (per spec Section 13):

- Matchmaking, accounts, persistence beyond active match
- Daily Ghost mode
- Tutorial
- Anti-cheat (test cohort only)
- Animations, sound, polish
- Multiplayer (heads-up only)
- Word Book, progression
- Sharing artifacts

-----

## When You Get Stuck

1. **Re-read the relevant spec section first.** Most ambiguities are answered there.
1. **Check Section 12 (Edge Cases) in the spec** before inventing new rules.
1. **If the spec contradicts itself,** the v12.3 update notes (top of spec) win over v12.2 text.
1. **If something feels wrong about the design,** stop and ask before changing it. The spec is the output of 14 design rounds; don’t re-litigate decisions during implementation.
1. **If Claude Code suggests adding a feature not in the spec,** decline. Add a `TODO(post-MVP)` comment instead.

-----

## Next Steps After MVP

In order:

1. **Internal playtest with the 5-10 trusted testers.** Collect the metrics in spec Section 14.
1. **Compare playtest data against thresholds.** Where do we fail? Where do we succeed?
1. **Phase 2 planning meeting.** Adopt findings, scope tutorial + Daily Ghost + accounts.
1. **Hire the Unity engineer if not already on team.**
1. **Begin economist consultation for Section 18.1 monetization decision.**

These are sequencing decisions, not engineering tasks. Don’t ask Claude Code to plan these — schedule a human meeting.

-----

**Start here:** open Claude Code, run `claude`, and say:

> Read CLAUDE.md and docs/spec-v12.3.md. Execute Sprint 0 Task 0.1 (repository scaffold). Confirm directory tree matches the spec before moving on.
