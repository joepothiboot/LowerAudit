# Initial spike, 8–15 November 2026

Goal: answer the seven spike questions (§4) with evidence, then freeze scope on 15 Nov. The
project decision follows on 30 Nov, after the advisor's response.

Assumptions:

- About 12 hours over 8 days. This is an assumption; correct it if wrong.
- The pin `llvmorg-23.1.1` via Homebrew. No LLVM build happens in this spike.
- OQ-1 (the first target) is answered before day 1.

## 1. Daily plan

| Day | Goal | Measurable output | Done when |
|---|---|---|---|
| Sun 8 | Freeze target, D0 and oracles. Write expected outcomes **before** any run. | problem statement §6 frozen; expected-outcome table committed | the table's commit predates every results folder |
| Mon 9 | Haskell vertical slice ([architecture](../design/architecture.md) §3) | `results/2026-11-09-slice/` | O1 (rank 2), O3 and O7's control are classified automatically |
| Tue 10 | Exp A and F on the CLI tier | `results/2026-11-10-d0/`: 1,926 V_tosa1.0 cases; V_mlir cases up to rank 4; controls | zero unexplained outcomes; F controls 100% correct |
| Wed 11 | C++ adapter and Exp B | adapter builds against Homebrew MLIR; `events.jsonl` for D0 | fidelity 100%; begin/end/success per case; at least one match failure with its reason (unranked control) |
| Thu 12 | Exp C: finish the `ReduceConverter` closure inventory (`inferExpandShapeOutputShape`, verifiers of created ops, type converter) | [rank-bound](../theory/rank-bound.md) §2 and §5 updated | each D0 outcome is predicted by the abstraction, or the mismatch is recorded |
| Fri 13 | Exp D and E: adversarial checks and known-gap injection | `results/2026-11-13-adversarial/` | injected gap found with a rank-1 witness; no prediction violated, or the violation is recorded |
| Sat 14 | Theory and novelty: instantiate Theorem 1 for D0; inventory one tt-mlir threshold pattern; read the full texts in the [novelty audit](../research/novelty-audit.md) §4 | rank-bound §6 ledger; novelty-audit updated | every obligation has a status |
| Sun 15 | Decision: fill §4, freeze scope, write a note for the advisor | decision-log entry; STATUS.md | the topic is frozen or explicitly not frozen |

## 2. Experiments

Every experiment records:

- the pin and the `mlir-opt --version` output;
- exact command lines;
- the case files and their ids;
- the generator's git SHA;
- one results folder per run.

### A. Basic coverage

- **Hypothesis:** under V_tosa1.0, the pipeline lowers every D0 case of rank 1–6. Under V_mlir,
  the bare pass lowers every D0 case except the frame class predicted in rank-bound §5.
- **Method:** enumerate D0 under both oracles, run the CLI tier, classify.
- **Controls:** Exp F cases interleaved; two full repeat runs.
- **Measure:** counts per class by rank, axis role, letters and element type; time per case.
- **Falsified if:** any V_tosa1.0 case is not `LOWERED`; any V_mlir failure falls outside the
  predicted class; or the two runs disagree.

### B. Pattern-reachability instrumentation

- **Hypothesis:** listener events separate attempted, match-failed (with reason) and applied.
  Begin counts equal the action log's `apply-pattern` counts.
- **Method:** run the adapter on D0 plus controls.
- **Controls:** the fidelity check; an unranked input, which should give a match failure with the
  reason "unranked tensors not supported" (`TosaToLinalg.cpp:1168`).
- **Expected:** `ReduceConverter<ReduceSumOp>` is applied on every `LOWERED` and `OUTPUT_INVALID`
  case. No other pattern is applied on D0.
- **Falsified if:** begin counts differ from the action log; an event names a pattern whose root
  op is absent; or a fidelity mismatch occurs.
- **Known limit:** D0 may contain no rollback. Showing that rolled-back successes are told apart
  needs a constructed case, which is still to be found.

### C. Rank behaviour vs. the static conditions

- **Hypothesis H1:** the outcome depends only on the element type, whether r = 1, and the letters
  at {axis, partner}.
- **Method:** predict each outcome from the inventory, compare with the observations, and
  separately derive empirically which positions matter.
- **Controls:** ranks 7–10 on the bare pass; a second and third representative for `s`.
- **Falsified if:** changing only bulk letters, or only the rank beyond the frame, changes an
  outcome.

### D. Theorem validation

- **Hypothesis:** A1–A5 hold for the `ReduceConverter` closure with a small N.
- **Method:** check each obligation against the source, citing `file:line`. Then try to break it:
  - out-of-class representatives (A2);
  - the axis at every position, with every combination of letters at the partner;
  - ranks N to N+4 with all-dynamic bulk, which can only falsify;
  - a synthetic mutant outcome function with a non-regular guard, which the rank analyzer must
    refuse to certify.
- **Falsified if:** a counterexample appears at rank ≥ N; an obligation is false; or the analyzer
  certifies the mutant.

### E. Known-gap detection

- **Hypothesis:** the tool finds (a) an injected gap, by filtering `ReduceConverter<ReduceSumOp>`
  out of the adapter's pattern set, and (b) the O3 family, each with a minimal witness.
- **Controls:** an unmodified adapter run.
- **Measure:** witness rank and size; time to the first witness.
- **Falsified if:** the injected gap is missed, or a reported witness is not shortlex-minimal.

### F. False-positive control

- **Hypothesis:** invalid or unsupported inputs are never reported as gaps.
- **Controls:**
  - unranked input (documented match failure);
  - axis out of range (verifier);
  - result shape mismatch (verifier);
  - rank 7 under V_tosa1.0 (validation);
  - dynamic dims under V_tosa1.0 (validation);
  - an ill-typed case like O7.
- **Measure:** a confusion matrix of true class against reported class.
- **Falsified if:** any control is reported as `CONVERSION_FAILED` or `OUTPUT_INVALID`.

## 3. Stop conditions

- An outcome is nondeterministic: stop and fix A1 before anything else.
- The adapter does not build against Homebrew MLIR within 3 hours: continue on the action log,
  which gives attempts only, and set Q4 to CONDITIONAL.
- The closure inventory for `ReduceConverter` exceeds about 2k lines of transitive helpers:
  record it as negative evidence for practicality (R2) and stop theorem work.
- Any step needs an LLVM source build: out of scope for this spike.
- OQ-1 is unanswered on day 1: do only target-independent work (theory, the reading list) until
  it is.

## 4. GO / CONDITIONAL GO / NO-GO per spike question

| # | Question | GO | CONDITIONAL GO | NO-GO |
|---|---|---|---|---|
| 1 | Built and run reproducibly? | D0 outcomes identical across two runs at the pin; adapter builds | CLI only | nondeterministic outcomes, or the pin is unusable |
| 2 | Meaningful domain declared? | D0 under both oracles, with at least 2 position classes | only rank-uniform ops | validity not mechanically decidable |
| 3 | Outcomes classified reliably? | Exp F 100%; no unexplained outcome | ≤ 5% unexplained, each with a ticket | crashes, verifier failures and conversion failures cannot be told apart |
| 4 | Pattern applications observable? | listener separates attempt, success and failure, with fidelity 100% | attempts only (action log) | neither |
| 5 | Rank-sensitive conditions exist? | position classes or thresholds found in the closure | only uniform loops: theorem trivial here, second target required | only constructs S5 or S6 |
| 6 | Plausible theorem with explicit obligations? | Theorem 1 instantiated for D0 with every obligation discharged | stated, with listed obligations still open | an unrepairable counterexample to the abstraction |
| 7 | Defensible novelty gap? | novelty-audit §4 reads done; nothing found that does the combination | reads incomplete, or advisor input pending | a prior work does the combination |

Overall:

- **GO** if no row is NO-GO and at most two rows are CONDITIONAL.
- **NO-GO** if row 1, 3, 6 or 7 is NO-GO.
- **CONDITIONAL GO** otherwise.

## Reconnaissance probes run on 2026-11-01

Probes were run with Homebrew `mlir-opt` 23.1.1. The inputs were scratch files and are not kept
in the repo; the commands are below.

- `BARE='--pass-pipeline=builtin.module(func.func(tosa-to-linalg))'`
- `PIPE='--tosa-to-linalg-pipeline'`

| Id | Input | Command | Observation |
|---|---|---|---|
| O1 | `tosa.reduce_sum`, static shape 2^r, axis r−1, r = 1..8 | `$BARE`, `$PIPE` | bare: exit 0 for r = 1..8. Pipeline: exit 0 for r ≤ 6; exit 1 for r = 7, 8 with `failed level check: operand rank(shape) <= MAX_RANK` |
| O2 | `tosa.reduce_sum (tensor<?x?xf32>) -> tensor<?x1xf32>`, axis 1 | `$PIPE` | `failed level check: operand shape dimension cannot be dynamic when targeting TOSA specification version 1.0 or below` |
| O3 | `tosa.reduce_sum %a {axis = 1 : i32} : (tensor<?x?xf32>) -> tensor<?x?xf32>` | `$BARE` | the pattern is attempted (action log), conversion completes, then the output fails verification: `'tensor.expand_shape' op expected number of static shape dims to be equal to the output rank (2) but found 0 inputs instead`; reassociation `[[0, 1]]`, empty `static_output_shape`. Mechanism: `TosaToLinalg.cpp:1370` → `TensorOps.cpp:1961–1975` → `:2075`. Not covered by lit tests at the pin. In V_mlir, out of V_tosa1.0. **Untriaged; the upstream tracker has not been searched.** |
| O4 | O1 at r = 2 | `$BARE --log-actions-to=-` | logs `apply-conversion` and `` `apply-pattern pattern: (anonymous namespace)::ReduceConverter<mlir::tosa::ReduceSumOp> ``, begin and completed only, no result status |
| O5 | any | `--tosa-to-linalg` at module level | `unable to schedule pass 'TosaToLinalg' on a PassManager intended to run on 'builtin.module'`; nest it under `func.func` |
| O6 | `tosa.add` at rank 0, and rank-3 static broadcast `2x1x3 + 1x4x3` | `$BARE`, `$PIPE` | exit 0 in both modes |
| O7 | a generator bug (BSD `seq 1 0` counts down) produced `tensor<2xf32> -> tensor<2x2x1xf32>` | both | exit 1, which looked like a rank-1 gap; a correct rank-1 input gives exit 0 in both modes. **Lesson: invalid inputs must be classified as `INVALID` before any gap is claimed (Exp F).** |
| O8 | lit tests at the pin, `test/Conversion/TosaToLinalg/*.mlir` | grep | reduce tests use input ranks 1–3 plus one unranked case and axes 0–2; no result type is dynamic at the axis |
