# Words Poker — Build-Ready Specification (v12.3 Final)

**Document Status:** Integration of 15 LLM Council rounds + 3 peer AI review cycles + engineering corrections + surface-specific calibration rounds + production architecture resolutions (Daily Ghost AI, monetization hypothesis). Section 20 reduced to one remaining open question requiring economist validation.

**Update history from v12.2:**

- Section 6.2 (Daily Ghost): RESOLVED via Seed Hybrid (telemetry-seeded AI, ~250-byte payload)
- Section 8.2 (Economy): WORKING HYPOTHESIS adopted — Ticket Economy quarantined to v13 tournaments
- Section 17 (Red Flags): added 17.7 (Daily Ghost storage cost resolution)
- Section 20 (Open Questions): reduced from 2 items to 1 (ARPDAU validation only)

**Update history from v12.1:**

- Section 3.7 (Modifier System): rebalanced deck v2, fixes double-dipping bug and undefined card
- Section 10 (Anti-Cheat): full threshold calibration with corpus specified
- Section 11 (NEW): Onboarding tutorial — 75-second scaffolded play flow

**Final design score:** 9.25 / 10 on main 7-axis metric. Surface-specific scores: tutorial 8.6, modifier quality 8.4, anti-cheat quality 8.8.

-----

## 1. Product Summary

Mobile word/poker hybrid. 2 players (v12, ships first) or 3–6 players (v13, ships as mode). Players form words from hidden and shared letters, run standard poker betting rounds, resolve outcomes via Score-to-Rank Translation. Target: ~75-second hands, broad mobile appeal, real bluffing dynamics.

**Two products, one codebase:**

- **v12 Heads-Up (1v1):** polished default, ships first with Daily Ghost
- **v13 Multiplayer (3–6 players):** tournament mode, ships post-soft-launch

-----

## 2. Design Diagnosis (What We Solved)

Existing word-poker games fail because:

1. **Bluffing is fake** — community letters dominate, hole letters don’t matter
1. **Vocabulary gatekeeping** — skill ceiling is “memorize the Scrabble dictionary”
1. **Showdown sludge** — arithmetic at hand end kills pacing
1. **The Nut Problem** — players can’t see the theoretical best word, so they never bet boldly

v12 fixes via curated dictionary, score-to-rank, modifier system, Read mechanic.

-----

## 3. Core Mechanics

### 3.1 Dictionary

- 50,000 curated English words
- Sourced from modern usage corpus, NOT full Scrabble TWL
- Excludes: obscure Scrabble entries (ZA, QI, AALII, CRWTH), proper nouns, abbreviations, hyphens, apostrophes
- Each entry tagged with **Obscurity Score (1–10)** based on Google Books N-gram English (2010–2024) log-frequency deciles — feeds anti-cheat
- Excluded rare words live in a separate **Bonus Dictionary**, unlockable as cosmetic Word Book entries (don’t count for scoring)
- Stored as a **Trie** server-side for O(L) validation
- Updated quarterly via curated additions

### 3.2 Letter Distribution

English frequency-weighted bag, 98 tiles per deck. No blanks/wildcards in v1.

|Letter|Count|Letter|Count|Letter|Count|
|------|-----|------|-----|------|-----|
|A     |9    |J     |1    |S     |4    |
|B     |2    |K     |1    |T     |6    |
|C     |2    |L     |4    |U     |4    |
|D     |4    |M     |2    |V     |2    |
|E     |12   |N     |6    |W     |2    |
|F     |2    |O     |8    |X     |1    |
|G     |3    |P     |2    |Y     |2    |
|H     |2    |Q     |1    |Z     |1    |
|I     |9    |R     |6    |      |     |

Scrabble letter values used unchanged.

### 3.3 Score-to-Rank Translation (The Breakthrough)

Word score = Scrabble letter values + bingo bonus (+15 for using all 7 letters, replaced by Bingo Boost modifier if drafted) + modifier card bonuses + aesthetic bonuses.

Rank assigned by **percentile of achievable scores on the specific board**, computed via LUT:

|Percentile of possible scores|Poker Rank     |
|-----------------------------|---------------|
|Bottom 30%                   |High Card      |
|30–50%                       |Pair           |
|50–65%                       |Two Pair       |
|65–75%                       |Three of a Kind|
|75–83%                       |Straight       |
|83–90%                       |Flush          |
|90–95%                       |Full House     |
|95–98%                       |Four of a Kind |
|98–99.5%                     |Straight Flush |
|Top 0.5%                     |Royal Flush    |

5th community letter (River) recomputes thresholds; rank can shift up or down.

**At showdown:** ranks compared visually. Flush beats Straight, etc. No arithmetic shown to players.

### 3.4 LUT (Lookup Table)

- Pre-computed offline via Python pipeline
- Effective board states: ~15k combinations of 4 community letters
- For each: enumerate all valid words using community + variable hole letters, compute full score distribution
- LUT stores per-board: [10th, 30th, 50th, 65th, 75th, 83rd, 90th, 95th, 98th, 99.5th] percentile cutoffs
- Server holds canonical LUT (~5MB binary blob)
- **Client receives lightweight heuristic approximation** for in-Build UI projection (NEVER the full LUT — exposes thresholds to dataminers)
- Showdown rank determined by server LUT; projected rank in client UI is approximate
- Re-computed quarterly on dictionary updates

### 3.5 RNG Smoothing

- Every hand: hole letters guaranteed ≥1 vowel AND ≥2 consonants
- Y counts as vowel only if no other vowel present
- Community letters: pure random
- Re-deal if community has 0 vowels (<1% of cases)
- **Cut from prototype, restored before public launch**

### 3.6 Salvage Floor

- Words 1–3 letters: raw Scrabble values only, no bonuses, no modifier triggers
- Words 4+ letters: full bonus eligibility
- 3-letter word always scores ≥3 points
- **Cut from prototype, restored before public launch**

### 3.7 Modifier System — 10-Card Deck v2

**Calibration Round 13 outputs.** Replaced Vowel Heavy with Suffix Master, replaced Alliterative with Triple Threat, fixed Bingo Boost double-dipping bug.

|# |Card                     |Trigger                                                                |Bonus                 |Implementation           |
|--|-------------------------|-----------------------------------------------------------------------|----------------------|-------------------------|
|1 |Ending Match             |Word ends in -ING / -ED / -LY (one chosen at deal)                     |+15                   |Suffix regex             |
|2 |Letter Hit               |Word uses Q, X, or Z                                                   |+20                   |Character set check      |
|3 |Length Lock              |Word is exactly 5 letters                                              |+10                   |Length check             |
|4 |Double Up                |Word contains a doubled letter (LL, EE, etc.)                          |+25                   |Pattern match            |
|5 |**Suffix Master**        |Word ends in -TION / -NESS / -MENT                                     |+20                   |Suffix regex             |
|6 |Consonant Storm          |Word has 4+ consonants                                                 |+15                   |Character count          |
|7 |All Hole                 |Word uses all 3 hole letters                                           |+30                   |Hole letter usage tracker|
|8 |**Bingo Boost (REVISED)**|Word uses all 7 letters — **REPLACES base bingo bonus, does not stack**|+30 total             |Length + usage check     |
|9 |Palindrome               |Word reads same forward/backward                                       |+30 (reduced from +40)|String reverse compare   |
|10|**Triple Threat**        |Word has 3+ of the same letter                                         |+25                   |Character count          |

**Draft mechanics:**

- v12 heads-up: **simultaneous blind draft** from independent 2-card pool per player (5s)
- v13 multiplayer: shared pool of 3 visible cards, players pick in turn order (5s × player count)

**Prototype:** hardcode same 3 modifiers every match for controlled variable testing. Use **Cards 1 (Ending Match), 2 (Letter Hit), and 7 (All Hole)** — covers easy/medium/hard trigger spectrum for balanced telemetry.

**Modifier Wager (at Final Bet):**

- **REVEAL:** apply modifier for guaranteed points if trigger met
- **HIDE:** modifier triggers at **2× points** but only if you win the pot (loses worth entirely on fold or loss)

### 3.8 Read Mechanic

- During Build phase: predict opponent’s final rank from 10-option list
- **Skip Read** option with 0 penalty
- Prediction **locked at end of Build** (no information leak into betting phases)
- Revealed at showdown alongside word reveal
- Correct: +5 chips from opponent
- Incorrect: -3 chips to predictor
- Skip: 0 effect
- v13 multiplayer: pick ONE target opponent at start of Build (creates target-selection meta)

-----

## 4. Hand Flow — Heads-Up (v12)

**Total: ~75 seconds**

|#|Phase              |Duration|Actions                                                                                                                    |
|-|-------------------|--------|---------------------------------------------------------------------------------------------------------------------------|
|1|Setup              |5s      |4 community letters revealed; 3 hole letters dealt (RNG-smoothed); blinds posted                                           |
|2|Modifier Draft     |5s      |Simultaneous blind: each player picks 1 of 2 visible modifiers from independent pool                                       |
|3|Build Part 1       |25s     |Construct word from 4 community + 3 hole letters. Submit Read prediction. UI shows current score + heuristic projected rank|
|4|River              |instant |5th community letter drops; hard phase boundary                                                                            |
|5|Build Part 2 (Flex)|15s     |Optional word adjustment incorporating new letter. Read locks at phase end                                                 |
|6|Betting Round 1    |10s     |Standard check/bet/raise/fold. 15s time bank available once per match                                                      |
|7|Squeeze            |5s      |Each player flips one hole letter face-up (simultaneous reveal)                                                            |
|8|Final Bet          |10s     |Final betting action + Modifier Wager decision (REVEAL or HIDE)                                                            |
|9|Showdown           |instant |Ranks compared visually. Modifier triggers resolve. Read predictions resolve. Pot awarded                                  |

**Note on Build phase:** Spec calls for continuous 40-second Build with River dropping at 25s mark. **Prototype uses hard-phase boundary** (Build1 → River → Build2) per engineering recommendation to avoid mid-phase netcode complexity. Continuous version evaluated for v1.1 based on playtest data.

-----

## 5. Hand Flow — Multiplayer (v13)

Same phase structure with adaptations:

- 2–6 players
- **Dealer button rotates each hand** (poker grammar)
- **Modifier Draft:** 3-card shared pool, players pick in turn order (5s per player)
- **Read targets one opponent**, declared at Build start
- **Betting:** standard turn order from button forward
- **Squeeze:** all players simultaneous reveal
- **Word collisions resolve by raw Scrabble value** (highest wins; further tiebreak by submission timestamp)
- **Tournament structure:** bust at 0 chips, last player standing wins
- **Hand timer scales:** ~75s heads-up, ~120s at 6 players

-----

## 6. Modes

### 6.1 Ranked

- Heads-up or 3–6 player tables
- Real chip wagering, Elo ladder, seasonal resets
- Anti-cheat active (all 3 layers)
- **Unlocks after 5 Daily Ghost plays** for new accounts

### 6.2 Daily Ghost (Casual Funnel)

- Async match vs AI ghost of player who previously played the exact same hand
- Same letter sequence for all daily participants
- Functions as stress-free tutorial substitute
- One play per day, replay-after-win unlock
- **Default mode for new players** — never ship Ranked alone

**Implementation: Seed Hybrid Telemetry Ghost** (resolves former Open Question #5)

Pure replay storage at 100k DAU is cost-prohibitive (millions of JSON files in PostgreSQL). Pure synthesized AI fails as a tutorial because it plays mathematically, not psychologically — it doesn’t bluff, doesn’t make human modifier-draft mistakes, doesn’t pause on a hard Build.

The middle path: store *only the decisions*, synthesize the *animations* client-side.

**Server-side seed payload (~250 bytes per match):**

```json
{
  "draft_id": 7,
  "locked_word": "STRAIN",
  "build_part2_word": "STRAINS",
  "revealed_hole_index": 2,
  "read_prediction": "PAIR",
  "wager_mode": "HIDE",
  "bet_actions": ["check", "raise_20", "call"],
  "modifier_triggered": true,
  "final_rank": "FULL_HOUSE"
}
```

**Pipeline:**

1. Backend samples a random winning Ranked match from the previous 24 hours (PII stripped)
1. Extracts the seed payload to a `daily_ghosts` table keyed by hand seed (community letters + RNG seed)
1. When a player queues for Daily Ghost, their client downloads the seed payload (~250 bytes)
1. Client `GhostController` script interpolates the dragging animations on a believable timing curve, but strictly executes the human’s historical decisions

**Storage cost at 100k DAU:** ~25MB total per day for the entire ghost pool (vs ~50GB for full replay). 1000× reduction.

**Fidelity caveat:** 250 bytes preserves *decision outcomes* but loses *micro-behavior* (hesitation patterns, near-misses, abandoned word attempts). Phase 2 engineering must validate empirically whether this fidelity is enough for the tutorial to feel like playing a human. If not, expand payload to ~1KB with timing markers. Do not exceed 1KB.

### 6.3 Weekly Puzzle

- One hand sequence persistent for 7 days
- Global leaderboard
- Optional no-dictionary toggle for ranked submissions
- Top scorer gets cosmetic reward

-----

## 7. Share Artifacts (Virality)

### 7.1 Bluff Grid (Heads-Up)

- Wordle-style emoji grid
- Color coding: green = used in final word, yellow = revealed in Squeeze but unused, gray = stayed hidden
- Tells the bluffing story, not just the score
- One-tap share

### 7.2 Table View (Multiplayer)

- Horizontal ranking of all players’ final words
- Your position highlighted
- Final rank icon per player
- One-tap share as image

-----

## 8. Retention Layer

### 8.1 Word Book (Pokédex)

Every unique valid word the player has used is permanently logged. Tagged by length, rare-word status, date first played.

**Threshold unlocks:**

- 25 unique words → avatar slot 1
- 50 unique 6-letter words → card back
- 100 unique words → table theme
- 500 unique words → rare avatar
- All 50k discovered → legendary cosmetic
- Bonus Dictionary entries unlockable separately for collectors

Cosmetic only. No competitive advantage.

### 8.2 Economy — Ticket Economy (Working Hypothesis)

**Status:** Working hypothesis adopted in v12.3 pending economist ARPDAU validation. Council resolved structure; revenue modeling under alternatives (cosmetic-only, battle pass, hybrid) still required pre-launch.

**The Dual-Currency Model:**

|Currency             |Earned How                             |Spent On                                        |Purchasable?                       |
|---------------------|---------------------------------------|------------------------------------------------|-----------------------------------|
|**Chips** (soft)     |v12 Heads-Up play                      |Ladder progression, Ranked stakes               |No                                 |
|**Tickets** (premium)|1 free per daily login (does not stack)|v13 Tournament entry only                       |Yes ($0.99 each, bundles available)|
|**Ink** (premium)    |Purchase only                          |Cosmetic Word Book unlocks (card backs, avatars)|Yes                                |

**Why this structure:**

- **v12 Heads-Up stays free and pure.** No paywalls in the core 1v1 loop. New players never encounter monetization until they choose to enter tournaments.
- **Monetization is quarantined to v13.** Tournament entry is the natural gating mechanism poker players already understand — buy-ins, not pay-to-win.
- **Free Ticket prevents pure-paywall feel.** Every daily-active player gets one shot at tournaments. Engaged players who want more pay for it.
- **Cosmetics are optional accelerator, not gate.** Word Book unlocks via play remain primary path; Ink only buys instant access.

**Tournament Ticket pricing (initial hypothesis, requires validation):**

- Single Ticket: $0.99
- 5-pack: $3.99 (20% discount)
- 20-pack: $13.99 (30% discount)
- Monthly Tournament Pass: $9.99 (unlimited entries for 30 days)

**Anti-pay-to-win guardrails:**

- Tournament prize pools are chips and cosmetics only — no real money payouts
- Same modifier deck, same dictionary, same scoring across paid and free entries
- No “premium tables” with different rules

**Required pre-launch:**

- ARPDAU modeling under Ticket Economy vs cosmetic-only vs hybrid (economist work)
- Free Ticket frequency tuning (1/day baseline; may need adjustment for retention curves)
- Tournament prize pool sizing (chip economy balance)

**Council cannot resolve these.** They require live revenue assumptions, comparable game data, and market-specific tuning that no AI council has access to.

-----

## 9. Technical Architecture

### 9.1 Stack

- **Client:** Unity (iOS + Android single codebase)
- **Backend:** Nakama (Go-based authoritative match handlers)
- **Hosting:** managed Nakama (Heroic Labs cloud) or self-hosted Kubernetes
- **Persistent storage:** PostgreSQL (Nakama default)
- **Session state:** Redis
- **CDN:** standard mobile asset CDN

### 9.2 Server-Authoritative Responsibilities

Server owns:

- RNG (letter dealing)
- Trie dictionary word validation
- Score calculation
- LUT-based rank assignment
- Bet validation and pot management
- Modifier trigger evaluation
- Read prediction resolution
- All anti-cheat telemetry

Client owns:

- Input capture
- UI display with heuristic rank approximation
- Animations and sound
- Local state for UX snappiness ONLY (never authoritative)

### 9.3 LUT Generation Pipeline

- Python script run offline
- Input: 50k dictionary + Scrabble values
- Output: per-board percentile cutoffs serialized as binary blob (~5MB)
- Re-run on quarterly dictionary updates
- Server hosts; never shipped to client in full

### 9.4 Networking

- WebSocket persistent connection
- Server authoritative for all game state
- Client-side prediction only for UI responsiveness
- Reconnect window: 30s before auto-fold
- Latency budget: <150ms RTT smooth, graceful to 300ms

### 9.5 Latency Masking

- Squeeze animation (5s) absorbs final hand state sync
- Modifier reveal animation absorbs showdown calculation
- Loading transitions hide netcode handshakes

### 9.6 Tutorial Architecture

- **Separate `TutorialController` class** — NOT a modified `MatchHandler` or stripped Daily Ghost
- Deterministic state machine, ~12 hardcoded events
- All player inputs route through production input handlers (no tutorial-only code paths) — muscle memory transfers to real games
- Testable in CI as deterministic replay
- Estimated build effort: 1 week, parallel to MVP work

-----

## 10. Anti-Cheat System (Calibrated)

**Round 14 calibration outputs.** All thresholds specified with corpus, baseline requirements, and graduation paths.

### Layer 1: Obscurity Index

- **Corpus:** Google Books N-gram English (2010–2024 subset)
- **Bucketing:** log-frequency, deciles 1 (most common) → 10 (rarest)
- **Trigger:** ≥70% of submitted words at obscurity 7+ over rolling 20 hands
- **Activation:** only fires after player has 50 hands of baseline data
- **Rationale:** legitimate competitive Scrabble players know many obscurity-7+ words; cheaters cluster at 70%+ submissions. 40% threshold (original spec) would false-positive serious players.

### Layer 2: Delta Cadence Tracking

- **Baseline:** rolling 50-hand average rank percentile
- **Primary anomaly trigger:** 8 consecutive hands at 99th percentile when baseline <60th percentile
- **Secondary trigger:** word submission timing patterns inconsistent with human reading speed — lock-in <2s after hole letter reveal in ≥80% of hands over rolling 20-hand window
- **Activation:** baseline of ≥50 hands required before flagging activates
- **Rationale:** 5 consecutive 99th-percentile hands (original spec) is a hot streak. 8 separates streak from sustained anomaly.

### Layer 3: Shadow Pool with Graduation Path

- Flagged accounts silently routed to flagged-only matchmaking
- No notification, no appeal
- **Graduation:** 200 consecutive clean hands (no Layer 1 or Layer 2 triggers) → silent return to main pool
- **Repeat offender:** accounts previously shadowed have re-flag threshold lowered by 20%
- **Rationale:** permanent shadow without recovery starts an arms race once cheaters discover the system; graduation maintains long-term integrity

### Calibration Methodology

- **Clean cohort seed:** 50 internal testers + 50 invited competitive Scrabble players (known-good baseline)
- **A/B target:** zero false positives in seed cohort across 1000 hands
- **If seed cohort trips flags:** tighten thresholds by 10% iteratively until clean
- **Continuous monitoring:** seed cohort baseline retained across spec updates as regression test

### Telemetry & Storage

- Per-hand telemetry: obscurity scores, rank percentile, submission timing, modifier choices
- ~1KB per hand × ~20 hands/day per active user
- **Retention: 90 days rolling.** Beyond 90 days, only flagged-account history retained.
- Estimated storage at 100k DAU: ~180GB rolling window
- Cold storage of flagged history: indefinite (legal/repeat-offender tracking)

-----

## 11. Onboarding Tutorial (Scaffolded Play, 75 Seconds)

**Round 12 output.** Resolves prior Open Question #3.

### Design Principles

- **Scaffolded play, not narrated tutorial.** Player is “tricked into” playing a Golden Hand; every choice is forced but feels impactful. No “Next” buttons — only gameplay actions advance the timer.
- **Lead with Score-to-Rank.** The biggest new concept gets the first dopamine hit (visible rank jump on tile drag).
- **Show stakes before forcing choices.** Modifier Wager trade-off must be visible BEFORE the player commits, so they understand the gamble rather than learning by accident.
- **Daily Ghost CTA at end.** Tutorial completion routes player to Daily Ghost, never to Ranked.

### 75-Second Golden Path

|Time         |Phase                          |Player Action                                                                                                                                                                                       |Concept Taught                                         |
|-------------|-------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------|
|**0:00–0:15**|**Aha Hook**                   |Mid-Build phase. Board: A-R-I-N. Hole: T-E-S. Ghost hand points to TRAIN; rank meter shows ONE PAIR. Player drags S → TRAINS → meter jumps to THREE OF A KIND, screen flashes gold.                 |Score-to-Rank: longer/better words = higher poker ranks|
|**0:15–0:25**|**Agency Moment**              |Two valid words highlighted: STAIN (Pair) or STRAIN (Two Pair). Player must choose which to lock.                                                                                                   |You’re optimizing, not following a script              |
|**0:25–0:35**|**Modifier Draft**             |Forced single-option pick: “+15 if word ends in -S.”                                                                                                                                                |Modifiers add bonus points if conditions met           |
|**0:35–0:50**|**Read with X-Ray**            |Opponent’s hole tiles briefly visible: “They have O and U — predict their rank.” Tooltip explicitly states: “Right = +5 chips. Wrong = -3 chips. Or skip.” Player taps PAIR. Tiles flip back hidden.|Read mechanic with risk/reward made explicit           |
|**0:50–1:00**|**Squeeze + Wager with Stakes**|“Reveal T to scare them.” Then Modifier Wager: “REVEAL = guaranteed +15. HIDE = +30 IF you win, but **0 if you lose.** Tutorial pick: HIDE.” Player taps HIDE knowing the stakes.                   |Hidden modifier is a real gamble, not free upside      |
|**1:00–1:10**|**Showdown Payoff**            |Opponent reveals PAIR. You reveal THREE OF A KIND. Hidden modifier triggers, doubles to +30 → bumps rank to FULL HOUSE. Read prediction resolves correct → +5 chips. Sweep pot.                     |All mechanics executed in sequence                     |
|**1:10–1:15**|**CTA Handoff**                |“Nice. Daily Ghost has more hands ready — same rules, no chip risk. Play one?” → routes to Daily Ghost queue.                                                                                       |Sequencing: never land in Ranked first                 |

### Tutorial Quality Metrics (Sub-Score 8.6)

|Sub-metric                                             |Target|Notes                                                   |
|-------------------------------------------------------|------|--------------------------------------------------------|
|Mastery (player can name all 7 mechanics post-tutorial)|9/10  |Read mechanic explicitly explained including risk       |
|Completion (% reaching CTA)                            |9/10  |Scaffolded play, no “Next” buttons                      |
|Time (≤75s actual play)                                |8/10  |15s over original 60s budget, but mastery gain justifies|
|Retention Handoff (% accepting Daily Ghost CTA)        |9/10  |Explicit sequencing                                     |

### Tutorial Failure Modeling (Deferred)

Current tutorial is all-success. Real-world onboarding should include at least one safe failure (e.g., a previous “hand” the player observes losing a hidden modifier wager). **Deferred to v1.1** based on playtest data — if completion-to-Ranked retention is healthy, no failure mode needed.

-----

## 12. Edge Case Rulings

|Situation                         |Resolution                                                     |
|----------------------------------|---------------------------------------------------------------|
|All checks through, no bets       |Pot returns to small blind                                     |
|Word collision (multiplayer)      |Highest Scrabble value wins; tiebreak by submission timestamp  |
|Invalid word at lock              |Player scores 0 for the hand                                   |
|Time-out during Build             |Highest-scoring valid word from current arrangement auto-locked|
|Disconnect during hand            |30s reconnect window, then auto-fold                           |
|Both players fold simultaneously  |Pot returns to small blind                                     |
|Tied final score AND rank         |Pot split                                                      |
|Hidden Modifier when hand lost    |Expires worthless (no consolation)                             |
|Read prediction with skip selected|0 effect; cannot be undone                                     |
|Player runs out of chips mid-hand |All-in posted; eligible only up to amount committed            |

-----

## 13. Prototype Scope (Aggressive MVP Cuts)

**Goal:** smallest playable build that tests bluffing dynamics hypothesis (score-to-rank + Read mechanic + modifier wager).

**CUT for prototype:**

- Matchmaking and accounts (use room codes / local pass-and-play)
- 15s Time Bank
- RNG Smoothing (use pure random)
- Salvage Floor (let scores go to zero)
- Continuous River drop (use hard phase stop)
- Dynamic modifier selection (hardcode Cards 1, 2, 7)
- Daily Ghost, Weekly Puzzle, Ranked Elo
- Word Book and all progression
- Bluff Grid / Table View sharing
- Multiplayer (heads-up only)
- Anti-cheat layers (trusted tester pool)
- Animations beyond functional minimum
- Tutorial (introduced in Phase 2 with Daily Ghost)

**KEEP for prototype:**

- Score-to-Rank Translation (the breakthrough — must test this)
- Read mechanic with skip option
- Simultaneous modifier draft
- Squeeze + Final Bet phases
- Modifier Wager (reveal vs hide)
- LUT for rank thresholds
- Server-authoritative core loop

-----

## 14. Playtest Plan

Metrics tracked from MVP, with action thresholds:

|Metric                            |Target (Success)       |Failure Threshold   |Failure Signal                        |
|----------------------------------|-----------------------|--------------------|--------------------------------------|
|Fold Rate                         |25–40%                 |<15% or >60%        |No fold equity OR math too opaque     |
|Build Time-to-Lock                |20–30s avg             |<10s or >38s        |Puzzle trivial OR cognitive overload  |
|Read Accuracy                     |40–60%                 |>80% or <20%        |Board solvable OR pure guessing       |
|Skip Read Rate                    |<30%                   |>60%                |Cognitive overload not solved         |
|Hand Completion Rate              |>90%                   |<80%                |Mechanic friction too high            |
|Post-Hand Replay Rate             |>70% in 10s            |<50%                |Low replay value                      |
|Drop-off at Final Bet             |<5%                    |>15%                |Math paralysis — Score-to-Rank failing|
|Modifier Draft Diversity (Phase 2)|All 10 cards picked ≥5%|Any card <2% or >35%|Deck v2 balance failing               |

-----

## 15. Build Sequence

### Phase 1 — Internal MVP (7–10 weeks)

- v12 heads-up core loop only
- Room codes or pass-and-play (no accounts)
- Internal team + 5–10 trusted testers
- **Goal:** validate bluffing hypothesis via playtest metrics

### Phase 2 — Closed Beta (8–12 weeks after MVP)

- Add accounts, matchmaking, Daily Ghost
- Add anti-cheat layers (Layer 1 + Layer 2; Shadow Pool routing)
- Restore RNG smoothing and salvage floor
- Build tutorial (parallel workstream, 1 week)
- 100–500 invite-only testers
- **Goal:** validate retention, onboarding, anti-cheat calibration against clean cohort

### Phase 3 — Soft Launch

- v12 heads-up + Daily Ghost public
- Word Book progression
- Single regional market (Canada, AU, or similar)
- **Goal:** validate viral coefficient and economy assumptions

### Phase 4 — Multiplayer Rollout

- v13 3–6 player tables
- Tournament structure
- Table View shares
- Global launch trigger

**Critical rule: v12 Ranked NEVER ships alone.** Per peer engineering review, players need Daily Ghost as tutorial first. Shipping Ranked-only sends new players into a meat grinder.

-----

## 16. Cost Estimate (MVP to playable)

**Team:** 2–3 engineers (1 Unity client, 1 Nakama backend, 1 full-stack floater) + 1 designer

|Workstream                                        |Duration      |
|--------------------------------------------------|--------------|
|Backend authoritative state machine (Nakama/Go)   |2–3 weeks     |
|Unity client UI + flow state sync                 |3–4 weeks     |
|LUT generation + Trie validator integration       |1–2 weeks     |
|Netcode edge case buffer (disconnects, reconnects)|1 week        |
|**Total**                                         |**7–10 weeks**|

**Critical dependency:** backend engineer must have prior Nakama runtime experience. **Add 3 weeks if learning on the job.**

Phase 2 additional scope: 8–12 weeks (includes tutorial: 1 week parallel).

-----

## 17. Engineering Red Flags (Resolved)

### 17.1 Modifier Draft Timing — RESOLVED

- **Original:** 5s shared pool with turn-order picks
- **Problem:** with network latency, second player has <2s to read and pick
- **Resolution:** simultaneous blind draft from independent 2-card pools (v12); multiplayer keeps turn-order but extends Setup to 5s × player count (v13)

### 17.2 Client LUT Exposure — RESOLVED

- **Original:** client computes projected rank in real-time
- **Problem:** shipping full LUT exposes thresholds to dataminers
- **Resolution:** client receives lightweight heuristic approximation for UI only; server holds canonical LUT as source of truth
- **Implication:** showdown rank may occasionally differ from in-Build projected rank — tune heuristic to minimize divergence

### 17.3 Anti-Cheat River Window Myth — RESOLVED

- **Original assumption:** 10s River Flex too short for solvers
- **Reality:** mobile solvers return in <100ms
- **Resolution:** 3-layer anti-cheat (Obscurity Index + Delta Cadence + Shadow Pool) replaces speed-based deterrence entirely (see Section 10)

### 17.4 Modifier Deck Double-Dipping — RESOLVED

- **Original:** Bingo Boost (+15) stacked with base bingo bonus (+15) for +30 total
- **Problem:** double-dip exploit — drafting card 8 doubled an already-large bonus
- **Resolution:** Bingo Boost now REPLACES base bingo bonus, total +30 not stacked

### 17.5 Undefined Modifier — RESOLVED

- **Original:** Card 10 “Alliterative” used undefined term “positional alliteration”
- **Problem:** hard build blocker — not implementable as written
- **Resolution:** replaced with Triple Threat (word has 3+ of same letter, +25)

### 17.6 Tutorial Read Mechanic Gap — RESOLVED

- **Original peer AI tutorial draft:** scripted Read tap without explaining mechanic
- **Problem:** players would reach Phase 3 of first real hand not knowing what Read does
- **Resolution:** 15s tutorial segment with X-Ray reveal + explicit risk/reward tooltip + showdown resolution feedback (Section 11)

### 17.7 Daily Ghost Storage Cost — RESOLVED

- **Original spec:** Daily Ghost replays human decisions, exact mechanism undefined
- **Problem:** full match replay storage at 100k DAU ≈ 50GB/day, prohibitive
- **Resolution:** Seed Hybrid — store ~250-byte decision payload per match (final word, draft choice, revealed letter, wager, bet actions), client synthesizes animations. ~25MB/day total, 1000× reduction. See Section 6.2.
- **Caveat:** payload fidelity to validate in Phase 2 engineering test; expand to max 1KB if needed

-----

## 18. Deferred Decisions

### 18.1 Monetization Model — RESOLVED (Working Hypothesis)

Ticket Economy adopted as working hypothesis in v12.3 — see Section 8.2. Quarantines monetization to v13 tournaments, preserves v12 free play, uses familiar poker buy-in pattern. **ARPDAU modeling under multiple structures still required pre-launch** (economist consultation).

### 18.2 Localization

v1 ships English-only. Letter-value scoring is English-anchored. Non-Latin scripts (Cyrillic, CJK, RTL) are multi-quarter engineering work. Defer until v12 traction validates investment.

### 18.3 Mobile vs Tablet Table Size

6-player tables (~120s hands) may exceed mobile attention span. Possible split: 2–4 player on mobile, 2–6 on tablet/web. Decide post-Phase 2 based on playtest data.

### 18.4 Daily Ghost AI Behavior Model — RESOLVED

Seed Hybrid (telemetry-seeded AI with ~250-byte decision payload, client-side animation synthesis) adopted in v12.3 — see Section 6.2. Payload fidelity validation deferred to Phase 2 engineering test.

-----

## 19. Post-Launch Roadmap (Sequenced Honestly)

Rejected from v1 but preserved for future sequencing based on traction data:

- Harmonic Scale (letter-as-musical-note layer)
- Visual Ascension (rank-crossing animations)
- Showdown Reels (TikTok auto-generation)
- Ink Economy / Word Gilding cosmetics
- Word Syndicates (20-player teams with communal Vault)
- Rush Hour daily windows
- Tournament bracket events
- Spectator mode
- Replay system
- Continuous Build phase (vs hard-phase prototype)
- Blank/wildcard tiles
- Bonus Dictionary as gameplay-accessible
- Tutorial failure modeling (one observed loss to teach Wager risk)

Order by post-launch data, not designer enthusiasm.

-----

## 20. Open Questions Still Live

**One remaining:**

1. **ARPDAU validation across monetization structures** — Section 8.2 adopts Ticket Economy as working hypothesis. Pre-launch validation required: model expected revenue under Ticket Economy vs cosmetic-only vs hybrid (battle pass + tickets) using comparable F2P game data. **Requires game economist with mobile F2P modeling experience. Not council-resolvable.**

**Previously open, resolved in v12.3:**

- ~Monetization model structure~ — Section 8.2 Ticket Economy hypothesis (Round 15)
- ~Daily Ghost AI behavior model~ — Section 6.2 Seed Hybrid telemetry approach (Round 15)

**Previously open, resolved in v12.2:**

- ~Modifier card balance~ — Round 13, deck v2 ships
- ~Onboarding sequence~ — Round 12, 75s scaffolded play
- ~Anti-cheat threshold tuning~ — Round 14, full calibration with corpus + cohort method

-----

## 21. Methodology Acknowledgment

This document integrates 15 LLM Council rounds, 3 peer AI review cycles, engineering correction passes, three surface-specific calibration rounds (tutorial, modifier balance, anti-cheat), and one production-architecture round (Daily Ghost AI + monetization hypothesis) applying Karpathy’s Autoresearch and LLM Council principles.

**Score trajectory (7-axis main metric):**

- v1 baseline: 4.9
- End Round 3 (rules saturated): 9.6 → expanded to 9.05 on new 7-axis metric (Round 5)
- End Round 7 (heads-up final): 9.40
- End Round 10 (engineering integrated): 9.25
- End Round 11 (main loop saturated): 9.25

**Surface-specific sub-scores (Rounds 12–14):**

- Tutorial Quality: 6.8 → 8.6 (+1.8)
- Modifier Quality: 6.2 → 8.4 (+2.2)
- Anti-Cheat Quality: 5.4 → 8.8 (+3.4)

**Production-architecture round (Round 15):**

- Daily Ghost AI: Seed Hybrid adopted, ~250-byte payload, 1000× storage reduction vs full replay
- Monetization: Ticket Economy adopted as working hypothesis pending economist validation

**Per-surface saturation principle confirmed:** main loop saturated at Round 11; surface-specific loops (12–14) and architecture round (15) produced real deltas because each started from a less-developed baseline. The final remaining open question (ARPDAU validation) is not council-resolvable — it requires market data and revenue modeling expertise outside any AI council’s capacity.

**Honest caveats:**

- All scores are model estimates, not playtest data
- The Ticket Economy is a structural hypothesis, not a validated revenue model
- The 250-byte Daily Ghost payload is an architectural starting point, not empirically validated
- Real metric from here forward is human testers hitting buttons and live revenue data
- This document exists to enable that data collection
- Loop saturation reached and verified across main metric, three surface metrics, and architecture decisions

-----

**Build can commence.**
