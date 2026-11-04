# Initial spike, 8–15 November 2026

Goal: answer the seven spike questions (§4) with evidence on the accepted target (D-012 to D-014), then
freeze scope on 15 Nov. The project decision follows on 30 Nov, after the advisor's response.

Assumptions:

- About 12 hours over 8 days. This is an assumption; correct it if wrong.
- Commits: tt-mlir `f9dc1b3e5101`, LLVM `4efe170d858e`. No LLVM or project source build happens here (D-015).
- The target and domain are accepted. OQ-10, OQ-11 and OQ-12 are answered before day 1.

**Standing limit.** D-015 keeps the source-build limit in force, and `ttmlir-opt` needs a source build. So
every row or experiment marked **gated** below cannot run until a new decision entry lifts the limit. All
hypotheses here are unrun.

## 1. Daily plan

| Day | Goal | Measurable output | Done when | Gated? |
|---|---|---|---|---|
| Sun 8 | Freeze domain and modes. Write expected outcomes **before** any run. | problem statement §6 frozen; expected-outcome table committed | the table's commit predates every results folder | no |
| Mon 9 | Haskell vertical slice ([architecture](../design/architecture.md) §3) | `results/2026-11-09-slice/` | three slice cases are classified automatically | **gated**; generator and pure classifier are not |
| Tue 10 | Exp A and F on the CLI tier | `results/2026-11-10-d0-tt/`: V_ttir cases to the agreed rank; controls | zero unexplained outcomes; F controls 100% correct | **gated** |
| Wed 11 | C++ adapter and Exp B | adapter builds against the tt-mlir tree; `events.jsonl` for D0-tt | fidelity 100%; begin/end/success per case; at least one match failure with its reason (partial marks, bare pass) | **gated** |
| Thu 12 | Exp C: finish the `ReductionProdOpConversionPattern` closure inventory (verifiers and builders of created ops, the decomposition chain) | [rank-bound](../theory/rank-bound.md) §2 and §5 updated | reading done; each outcome predicted, or the mismatch recorded once runs exist | reading no; comparison **gated** |
| Fri 13 | Exp D and E: adversarial checks and known-gap injection | `results/2026-11-13-adversarial/` | injected gap found with a rank-1 witness; no prediction violated, or the violation is recorded | **gated** |
| Sat 14 | Theory and novelty: check Theorem 1's obligations against D0-tt; read the full texts in the [novelty audit](../research/novelty-audit.md) §4 | rank-bound §6 ledger; novelty-audit updated | every obligation has a status | no |
| Sun 15 | Decision: fill §4, freeze scope, write a note for the advisor | decision-log entry; STATUS.md | the topic is frozen or explicitly not frozen | no |

## 2. Experiments

Every experiment records:

- the commits and the `ttmlir-opt --version` output;
- exact command lines;
- the case files and their ids;
- the generator's git SHA;
- one results folder per run.

All class predictions below come from conjectures H6 and H7 in [rank-bound](../theory/rank-bound.md) §5. Exact
commands wait for OQ-11.

### A. Basic coverage (gated)

- **Hypothesis:** the table in rank-bound §5: `LOWERED` at r ≤ 4 for one or all marks, a match failure for partial marks on the bare pass, and a documented rejection at r ≥ 5.
- **Method:** enumerate D0-tt under V_ttir, run the CLI tier, classify.
- **Controls:** Exp F cases interleaved; two full repeat runs.
- **Measure:** counts per class by rank, mark summary, letters and element type; time per case.
- **Falsified if:** any failure falls outside the predicted classes, or the two runs disagree.

### B. Pattern-reachability instrumentation (gated)

- **Hypothesis:** listener events separate attempted, match-failed (with reason) and applied. Begin counts equal the action log's `apply-pattern` counts.
- **Method:** run the adapter on D0-tt plus controls.
- **Controls:** the fidelity check; a partial-mark `ttir.prod` on the bare pass, which should give a match failure with the reason at `TTIRToTTNN.cpp:259-261`.
- **Expected:** `ReductionProdOpConversionPattern` is applied on every case that reaches it and converts. `ReductionOpConversionPattern<ttir::SumOp, ttnn::SumOp>` is applied on the control.
- **Falsified if:** begin counts differ from the action log; an event names a pattern whose root op is absent; or a fidelity mismatch occurs.
- **Known limit:** D0-tt may contain no rollback. Showing that rolled-back successes are told apart needs a constructed case, which is still to be found.

### C. Rank behaviour vs. the static conditions (reading now; comparison gated)

- **Hypothesis H6:** the outcome depends only on the features listed in rank-bound §5.
- **Method:** predict each outcome from the inventory, compare with the observations, and separately derive empirically which positions matter.
- **Controls:** ranks 5–10 on the bare pass; a second and third representative for `s`.
- **Falsified if:** changing only bulk letters, or only the rank beyond 5, changes an outcome.

### D. Theorem validation (reading now; checks gated)

- **Hypothesis:** A1–A5 hold for the `ReductionProdOpConversionPattern` closure. **[H]** A2 already looks false for si32 in the pipeline (rank-bound §2).
- **Method:** check each obligation against the source, citing `file:line`. Then try to break it:
  - out-of-class representatives (A2), including sizes around `kMaxIntegerProdUnrollSize`;
  - every mark set at each rank up to the agreed bound;
  - ranks N to N+4 with all-dynamic bulk, which can only falsify;
  - a synthetic mutant outcome function with a non-regular guard, which the rank analyzer must refuse to certify.
- **Falsified if:** a counterexample appears at rank ≥ N; an obligation is false; or the analyzer certifies the mutant.

### E. Known-gap detection (gated)

- **Hypothesis:** the tool finds (a) an injected gap, by filtering `ReductionProdOpConversionPattern` out of the adapter's pattern set, and (b) the candidate gaps in rank-bound §5 if OQ-10 includes negative encoding, each with a minimal witness.
- **Controls:** an unmodified adapter run.
- **Measure:** witness rank and size; time to the first witness.
- **Falsified if:** the injected gap is missed, or a reported witness is not shortlex-minimal.

### F. False-positive control (gated)

- **Hypothesis:** invalid or unsupported inputs are never reported as gaps.
- **Controls:**
  - unranked input (op definition, `TTIROps.td:2742`);
  - dim out of range (`negative_invalid_dim_low.mlir`, `negative_invalid_dim_high.mlir`);
  - repeated dims (`negative_repeating_dims.mlir`);
  - result shape mismatch (`negative_shape_mismatch.mlir`);
  - rank 5 (`negative_reduce_prod_op.mlir:1-7`), with the class OQ-12 sets;
  - an ill-typed case like O7.
- **Measure:** a confusion matrix of true class against reported class.
- **Falsified if:** any invalid control is reported as `CONVERSION_FAILED` or `OUTPUT_INVALID`.

## 3. Stop conditions

- An outcome is nondeterministic: stop and fix A1 before anything else.
- A first-target build, if one is ever allowed, fails on this machine: stop and report a negative result (D-011).
- The adapter does not build against the tt-mlir tree within 3 hours: continue on the action log, which gives attempts only, and set Q4 to CONDITIONAL.
- The closure inventory for `ReductionProdOpConversionPattern` exceeds about 2k lines of transitive helpers: record it as negative evidence for practicality (R2) and stop theorem work.
- Any step needs an LLVM or project source build: out of scope until a new decision entry lifts the limit (D-015).

## 4. GO / CONDITIONAL GO / NO-GO per spike question

| # | Question | GO | CONDITIONAL GO | NO-GO |
|---|---|---|---|---|
| 1 | Built and run reproducibly? | D0-tt outcomes identical across two runs at the commits; adapter builds | CLI only | nondeterministic outcomes, or the pin is unusable |
| 2 | Meaningful domain declared? | D0-tt under V_ttir, with at least 2 mark or rank classes | only rank-uniform ops | validity not mechanically decidable |
| 3 | Outcomes classified reliably? | Exp F 100%; no unexplained outcome | ≤ 5% unexplained, each with a ticket | crashes, verifier failures and conversion failures cannot be told apart |
| 4 | Pattern applications observable? | listener separates attempt, success and failure, with fidelity 100% | attempts only (action log) | neither |
| 5 | Rank-sensitive conditions exist? | position classes or thresholds found in the closure | only uniform loops: theorem trivial here, second target required | only constructs S5 or S6 |
| 6 | Plausible theorem with explicit obligations? | Theorem 1 instantiated for D0-tt with every obligation discharged | stated, with listed obligations still open | an unrepairable counterexample to the abstraction |
| 7 | Defensible novelty gap? | novelty-audit §4 reads done; nothing found that does the combination | reads incomplete, or advisor input pending | a prior work does the combination |

Overall:

- **GO** if no row is NO-GO and at most two rows are CONDITIONAL.
- **NO-GO** if row 1, 3, 6 or 7 is NO-GO.
- **CONDITIONAL GO** otherwise.

**Consequence of D-015 for this table.** While the limit holds, rows 1, 3 and 4 have no evidence, because they all
need runs. Row 1's NO-GO lists "the pin is unusable", and row 1 being NO-GO makes the overall result NO-GO. The rule
is unchanged here. If the limit is still in force on 15 Nov, the user must decide how to read row 1 before filling
the table.

## Reconnaissance probes run on 2026-11-01

A dated record, on the superseded target TosaToLinalg. Citations are at `llvmorg-23.1.1`.

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

The predictions made for this target on 2026-11-01 were never tested; they are kept in [rank-bound](../theory/rank-bound.md) §7.
