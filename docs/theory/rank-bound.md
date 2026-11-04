# Rank bound: inventory, theorem, proof status

Current source locations are at tt-mlir `f9dc1b3e5101`, with LLVM `4efe170d858e`, unless stated
otherwise. Locations at `llvmorg-23.1.1` appear only in the dated record (§7).

> **Status (2026-11-04).** No rank theorem is established for any target. Theorem 1 and its
> corollaries are proved as generic statements about an abstraction. Whether TTIR→TTNN satisfies the
> abstraction's assumptions is **open**, and nothing has been run on it. §5 is a conjecture. Theorem 2 is
> a proof sketch.

**Labels:** **[F]** read from source. **[H]** hypothesis, not run.

## 1. Four propositions that must not be confused

Fix a conversion C, a domain D and a bound R. Each proposition below is about cases of rank > R.

| | Proposition | Notes |
|---|---|---|
| P1 | **Same branches.** Every case takes the same decisions as some case of rank ≤ R, with loop bodies compared per iteration class. | Almost never literally true, because traces grow with rank. Useful only as a proof tool. |
| P2 | **Same outcome.** There is a rank-reducing map ρ that preserves validity and the outcome class. | Implies P4. |
| P3 | **Same pattern set.** The set of patterns applied equals that for ρ(x). | Independent of P2. O3 applied the same pattern as a lowered case but ended `OUTPUT_INVALID`. |
| P4 | **Same coverage verdict.** If every valid case of rank ≤ R is `LOWERED`, so is every valid case. | The property the project wants. P4 does not imply P2. |

## 2. Rank-dependency inventory (TTIR→TTNN, partial)

Read for `ttir.prod` and `ttir.sum` on 2026-11-04. **[F]** for what the code says. The S classes and
proof obligations are **[H]** until the closure inventory exists.

| Location | Rank-dependent expression | Semantic effect | Class | Proof obligation |
|---|---|---|---|---|
| `TTIRToTTNN.cpp:226-239` (`sum`) | none | 1:1 replacement, no failure return | none | confirm through the `ttnn.sum` builder and verifier |
| `TTIROps.cpp:6699-6730`, `:6831-6833` | per-position mask; `-r ≤ d < r`; uniqueness on raw values | validity; result shape | S1, S2, S4 | none for the bound itself; encode in V_ttir |
| `TTIRToTTNN.cpp:251-258` | `size > 1 && size < rank` | match failure for a partial mark set | S1 | regular only as a finite summary: at least two marks, one unmarked position |
| `TTIRToTTNN.cpp:268-273` | `dimArg->size() == 1` | one dim is passed through; otherwise reduce all | S1 | `size` counts list entries, not positions (§5) |
| `TTNNOps.cpp:6026-6031`, `:6085-6087` | `rank > 4` for `ttnn.prod` | output fails to verify | S3, S8 | counter saturating at 5; absent from TTIR, so it lives in the output op |
| `TTNNOps.cpp:5985-6017`, `:6063-6067` | per-position mask, no cap, for `ttnn.sum` | shape check | S1 | column locality; **note** `ttnn.prod` calls only the rank check (`:6085-6087`) |
| `TTIRToTTIRDecompositionPass.cpp:176-183` | `size == 1 || size == rank` | legality of `ttir.prod` in the decomposition pass | S1 | same summary as above |
| `TTIRToTTIRDecomposition.cpp:1809-1845` | one `ttir.prod` per reduced dim | chain length grows with the number of marks | S7 | **needs the separate argument S7 asks for** |
| `TTIROps.cpp:6845-6858` | none; boolean-valued input | canonicalizer may rewrite `prod` to `min` | none | **[H]** not reached by a lone function argument |
| `IntegerProdOpRewritePattern.cpp:24,31,47-48` | integer type, one dim, size test against `kMaxIntegerProdUnrollSize` | workaround after conversion | breaks A2 for `s` on si32 | pipeline only; the letter `s` is not constant under this predicate |
| `lib/Dialect/TTNN/Utils/Utils.cpp:289-301`; `include/ttmlir/Utils.h:49`; `TTNNLayout.cpp:86-87,243-245` | `alignUp` on the last two dims of a tiled shape, with `assert(val >= 0)` | **[H]** `?` in those positions aborts `ttnn-layout`, before the conversion | S4 | regular as a role relative to the end; depends on tt-mlir's build having assertions |
| `TTNNPipelines.cpp:392` | element-type normalization | may change element types before conversion | unknown | pipeline only; not read |
| Not yet inventoried | `ttcore-register-device`, `ttnn-layout`, the workarounds pass (`TTNNPipelines.cpp:332`), fusing, canonicalization, the `ttnn.prod` builder | unknown | unknown | needed for any pipeline-level claim |

Thresholds elsewhere in the same conversions are in [brief-oq9](../decisions/brief-oq9.md) §4 and outside D0-tt:
batch norm's `rank == 5`, `rank < 4`, and its `% tileWidth` test (`TTIRToTTIRDecomposition.cpp:843-864`).

## 3. The eight questions, answered for the inspected part

These answers are provisional, read from source, and not run.

1. **Finitely many constant thresholds?** For `ttir.prod`, one found: `rank > 4` in the output verifier.
2. **Loops or indexing that block a cutoff?** None seen in the pattern. The decomposition chain is S7,
   which S1–S6 do not cover. Its raw indexing is a separate concern (§5).
3. **Hidden dependencies in helpers?** Yes. The threshold is in `ttnn.prod`'s verifier, not in the pattern.
   The same lesson as O3, on a different target: the inventory must follow created ops.
4. **Finitely many rank-equivalence classes?** Conjectured (H6, §5). Not proved.
5. **Property preserved beyond the bound:** the candidate is P2 together with P3 for D0-tt, conditional on the
   obligations. **[H]** P4 in its "all lowered" form is false if the rank-5 case counts as a failure,
   since `LOWERED` then stops at rank 4. What the theorem would then give is a bound on where outcomes stop changing.
6. **Smallest sufficient bound:** unknown.
7. **Assumptions:** A1–A5 in §4.
8. **How to check them:** see the "Check" column in §4.

## 4. Formal model

**Abstract cases.**

- Fix a finite set A of rank-independent parameters, such as element type and flags.
- Fix a finite per-position alphabet Σ. For D0-tt, a letter is (dim letter from {1, s, ?}, mark). The
  result letter is not part of it, because V_ttir determines the result from the letter and `keep_dim`.
- An abstract case is (a, w) with a ∈ A and w ∈ Σ*. Its rank is |w|.
- The concretization γ maps 1 → 1, s → a chosen n ≥ 2, and ? → dynamic.
- V ⊆ A × Σ* is the declared validity oracle.
- O(a, w) is the observed outcome of running C on γ(a, w): a pair of the class (§3 of the
  [problem statement](../research/problem-statement.md)) and the set of patterns applied and
  surviving. Out, the set of possible outcomes, is finite.

| | Assumption | Check |
|---|---|---|
| A1 | **Determinism.** O is a function. | repeated runs; `--mlir-disable-threading` |
| A2 | **Representative independence.** Every concretization of (a, w) has the same outcome. | source: every use of a static size goes through a predicate that is constant on each letter (`== 1`, `> 1`, `isDynamic`); tests: alternative representatives. **[H]** Fails as written for si32 in the pipeline (§2) |
| A3 | **Finite-state rank dependence.** For each a, a deterministic automaton with output and at most k states computes w ↦ O(a, w). | the source conditions S1–S8 below, for every function on the transitive call path, including builders and verifiers of created ops |
| A4 | **Faithful observation.** The recorded outcome equals the true one. | adapter output identical to `ttmlir-opt` output; listener begin counts match the action log; rollback attribution |
| A5 | **Regular validity.** V_a is recognized by an automaton with at most k_V states. | write V_ttir as an automaton from `verifyReduceOp`. **[H]** A positive-only encoding looks regular. Negative encoding is rank-relative (S4), and its uniqueness rule needs checking |

**Theorem 1 (coverage cutoff).** Assume A1–A5 and let N = k·k_V. If every (a, w) ∈ V with
|w| < N is `LOWERED`, then every (a, w) ∈ V is `LOWERED`.

*Proof.*

1. Fix a. Let Bad_a = {w ∈ V_a : O(a, w) is not `LOWERED`}.
2. Bad_a is accepted by the product of V_a's automaton and the outcome automaton. Its accepting
   states are those whose output is not `LOWERED`. The product has at most N states.
3. Suppose Bad_a is non-empty and take a shortest word in it. If that word had length ≥ N, its run
   would repeat a state. Cutting out the loop gives a shorter accepted word, a contradiction.
   So a shortest word in Bad_a has length < N.
4. The hypothesis says no word of length < N is in Bad_a. Hence Bad_a = ∅. ∎

*Status:* proved, for the abstraction, not for any target. The argument is elementary. **The research
burden is entirely in establishing A2, A3 and a value of k for real code.**

**Corollary 1 (minimal witnesses).** If a gap exists, one exists at rank < N. Enumerating in
increasing rank therefore returns a witness of minimal rank.

**Corollary 2 (unreachability in D).** For a pattern p, the set {w ∈ V_a : p is applied and
survives} is regular with at most N states. If p applies to no valid case of rank < N, it applies
to no valid case of D at any rank. *This is the only sanctioned route to the label "unreachable
in D"* (CLAUDE.md rule 3).

**Theorem 2 (symmetric threshold variant, reduces enumeration).** Suppose each word splits into a
*frame* of at most d positions with regular roles (first, last, marked) and a *bulk* of the remaining
positions. Assume (A3′) that O(a, w) and V_a(w) depend only on the frame letters with
their roles and, for each σ ∈ Σ, on min(#σ in the bulk, t). Then every combination of outcome
and validity that occurs at some rank also occurs at rank ≤ d + t·|Σ|. It suffices to test one
word per (frame assignment, capped count vector).

*Proof sketch.* Deleting bulk positions of a letter whose count exceeds t leaves the capped counts
unchanged. It also leaves the frame roles unchanged, provided the frame contains every position
whose role depends on adjacency. *Status:* sketch; the role-preservation step must be checked for each
frame definition. **[H]** For D0-tt, marks can be numerous, so a mark may fit better as a capped count than
as a frame role. No frame has been defined. The earlier {axis, partner} frame belonged to D0 (§7).

**Remarks.**

- A guard on r mod m is finite-state, so Theorem 1 still applies, but A3′ fails unless counts are
  also taken mod m.
- A large explicit validity threshold should be handled analytically, not enumerated. MAX_RANK = 32 at
  TOSA level `none` was the recorded example (§7). **[F]** V_ttir has no such threshold for `ttir.prod`.
- Black-box testing cannot establish k. Chow's W-method gives a complete finite suite only
  *given* a bound on the implementation's states. That is why A3 needs source inspection
  (D-006).

### Source conditions that make A3 hold, and what breaks it

| | Condition | Effect on A3 |
|---|---|---|
| S1 | Loop bodies over dimensions decide using only the current letter and a finite summary of earlier ones | holds |
| S2 | Rank-indexed attributes (axis) are encoded as marks; tests against the mark are local | holds |
| S3 | Comparisons of r with constants | holds; a counter saturating at c+1 |
| S4 | Roles relative to the end (last, second-to-last) | holds; regular languages are closed under reversal |
| S5 | Comparison of two unbounded rank-dependent quantities (e.g. number of dynamic dims vs. number of static dims; `axis == r/2`) | **breaks A3**: the language is not regular |
| S6 | Behaviour that depends on a permutation beyond a finite abstraction of it (identity, last-two swap, …) | **breaks A3** |
| S7 | Rewrite chains whose length grows with r, with rank-dependent legality of the intermediate ops | needs a separate argument |
| S8 | All of S1–S7 must hold through helpers, type converters, and the builders and verifiers of created ops | O3 shows this is necessary |

## 5. Conjecture for D0-tt (`ttir.prod`; not a theorem)

**Everything in this section is conjecture.** No case has been run; no obligation is discharged; no bound
is claimed. It records what the source reading in §2 suggests, so that it can be falsified.

**H6 (conjecture).** O(a, w) depends only on:

- the element type;
- whether r > 4;
- the mark summary: one, all (`dim_arg` absent or |list| = r), or partial (1 < |list| < r);
- `keep_dim`, and the letter `?`, including whether it is in the last two positions;
- the sign of `dim_arg` entries on partial lists;
- the mode (bare or pipeline).

**H7 (conjecture).** `ttir.sum`'s outcome does not depend on r at all, on the bare pass.

**Predicted classes, to test only once the target can run.** This is the summary for static letters and positive dims.
The per-class predictions, frozen at their first commit, are in [expected outcomes](../experiments/expected-outcomes.md).

| Case | Bare pass | Pipeline | Rests on |
|---|---|---|---|
| r ≤ 4, one or all | `LOWERED`; `ReductionProdOpConversionPattern` applied | `LOWERED` | `TTIRToTTNN.cpp:251-278`; `simple_prod.mlir` for ranks 1, 3, 4 |
| 3 ≤ r ≤ 4, partial | match failure, then `CONVERSION_FAILED` | `LOWERED`, by a chain of single-dim `ttir.prod` | `TTIRToTTNN.cpp:258-261`; `TTIRToTTIRDecomposition.cpp:1809-1845`; no lit test seen for partial marks |
| r ≥ 5, one or all | fails `ttnn.prod`'s verifier: `EXPECTED_REJECTION` (D-017) | same | `TTNNOps.cpp:6028`; `negative_reduce_prod_op.mlir:1-7` for r = 5, one dim, f32 |
| r ≥ 5, partial | match failure, then `CONVERSION_FAILED`; no `ttnn.prod` is created | fails `ttnn.prod`'s verifier: `EXPECTED_REJECTION` (D-017) | `TTIRToTTNN.cpp:258-261`; `TTIRToTTIRDecomposition.cpp:1831-1845`. Corrected 2026-11-04: this row previously said the verifier fails in both modes |

**What would falsify H6:** an outcome that changes with bulk letters alone, with the rank beyond 5 alone, or with
the representative of `s` on f32.

**Known weak points, each [H]:**

- **`?`:** no `ttir.prod` lit test uses it. In the last two positions it should abort `ttnn-layout` if tt-mlir has assertions (§2), which would make `ttir.sum` crash too. In earlier positions the path was not traced to the end, and the workarounds were not read.
- **si32 in the pipeline:** the integer workaround tests a size against `kMaxIntegerProdUnrollSize`, so A2 as written fails there. The letter `s` may need splitting, or si32 restricting to the bare pass.
- **Unexamined passes:** H6 ignores everything listed "not yet inventoried" in §2.

**Candidate gaps, by reading only, and untriaged. D-017 puts the raw negative index in D0-tt and leaves repeated positions out, as probes:**

- **Raw negative index.** `ReductionProdPattern` uses `dim_arg` values directly as `shape[dim]` and
  `shape.begin() + dim` (`TTIRToTTIRDecomposition.cpp:1818,1831-1837`), while V_ttir allows negatives. A partial
  negative `dim_arg` could crash the decomposition pass, unless an earlier pass normalizes it.
- **Repeated position.** Uniqueness is checked on raw values (`TTIROps.cpp:6713,6717`), so `[d, d−r]` passes. Its
  `size` then counts 2 for one position. At r = 2, `TTIRToTTNN.cpp:258` sees "all" and `:269` passes no dim, so
  every dim would be reduced while the result type records one. This would be a correctness question, which is
  out of scope, but it could also change the outcome.

**Open:** k and N; the frame; the S7 argument for the chain; the `ttnn.prod` builder; everything needed for A3 on the pipeline.

## 6. Proof-status ledger

| Item | Status |
|---|---|
| Theorem 1, Corollaries 1 and 2 (generic) | proved (elementary); not yet reviewed by a second reader |
| Theorem 2 | proof sketch |
| H6, H7 for D0-tt | conjecture; not run |
| A1–A5 for the `ReductionProdOpConversionPattern` closure | open; pattern, decomposition pattern and both verifiers read; the rest listed in §2 |
| A1–A5 for the `ReductionOpConversionPattern` (`sum`) closure | open; pattern and verifiers read, builders not |
| Pipeline-level claim | open; most passes not read |
| Smallest N for D0-tt | unknown |
| Any target-level theorem | none |

## 7. Record: TosaToLinalg at `llvmorg-23.1.1` (2026-11-01)

Kept as written then, including its open items. D-010 superseded this target; O3 remains untriaged and parked.
All locations are at `llvmorg-23.1.1` (`6dfe1677ab8d`).

### Rank-dependency inventory (partial)

| Location | Rank-dependent expression | Semantic effect | Candidate bound | Proof obligation |
|---|---|---|---|---|
| `TargetEnv.h:43,45`; `TosaValidation.cpp:276,330–337`; pipeline default `TosaToLinalgPass.cpp:132`, level `Passes.td:167` | `rank(shape) <= MAX_RANK`, with MAX_RANK = 6 (`8k`) or 32 (`none`) | the pipeline rejects rank > MAX_RANK as `INVALID` (O1) | threshold 6 or 32 | none (explicit). Treat analytically; do not enumerate. |
| `TosaValidation.cpp:910` | dynamic dimension rejected for spec ≤ 1.0 | restricts letters to {1, s} under V_tosa1.0 (O2) | none (per-letter) | none |
| `TosaToLinalg.cpp:749–755, 1041–1043` | all operands and results ranked | unranked → match failure | n/a | documented-rejection control |
| `TosaToLinalg.cpp:808–822` with `767–804` | `for dim in 0..rank`: target size from the column at `dim` only | output shape | t = 1 (column letters) | column locality: no state crosses dimensions except the SSA cache `IndexPool` |
| `TosaToLinalg.cpp:824–946` | per (operand, dim): `scf.if` broadcast when dynamic and not the master operand; exits early for unary ops (926) and all-static shapes (930–939) | IR size linear in r; no failure path | t = 1 | confirm there is no failure path, including in the `scf.if`/`linalg.generic` builders |
| `TosaToLinalg.cpp:966–981` | per dim: `requiresBroadcast = (dim == 1 && resultDim != 1)` | affine map entry | t = 1 | column locality |
| `TosaToLinalg.cpp:956–958, 999–1001` | type conversion; body creation | element type × op only | none | show these do not read the shape |
| `TosaToLinalg.cpp:1181–1187` | `for i < rank: if (axis != i)` builds the reduced shape and dynamic dims | removes the axis position | position class {axis, other} | mark locality |
| `TosaToLinalg.cpp:1351–1364` | `i > axis ? i+1 : i`; `expandInputRank != 0` (r = 1); `axis < expandInputRank ? axis : expandInputRank - 1` (axis = last) | reassociation groups the axis with its **partner**: axis+1, or axis−1 if the axis is last; none if r = 1 | frame {axis, partner}; role r = 1 | window locality around the mark |
| `TosaToLinalg.cpp:1370` → `TensorOps.cpp:1961–1975` → verifier `TensorOps.cpp:2075` | `ExpandShapeOp::build` infers the output shape and, **if inference fails, silently builds with an empty shape** | `OUTPUT_INVALID` when the result type has `?` at the axis and at its partner (O3) | frame-local | read `inferExpandShapeOutputShape` (not yet read) to confirm the exact failure condition |
| `TosaToLinalg.cpp:2285` (Reverse), `2408–2409, 2448–2449` (ArgMax) | `i == axis`, `i != axis`, `iteratorTypes[axis] = reduction` | per-position role relative to the mark | frame {axis} | mark locality; ArgMax also needs an integer output type (2402–2403) |
| `TosaToLinalg.cpp:2324–2325, 2329` (Tile) | constant multiples required; loop over `multiples[i]` | non-constant multiples → no match | letters for multiples: {1, >1} | multiples are unbounded integers and need their own abstraction |
| `TosaToLinalgNamed.cpp:1089–1115` (Transpose) | permutation `perms` passed through, no failure path | permutation-uniform | n/a in the pattern | permutations are **not** a finite alphabet; the pipeline's canonicalization of transposes is not yet inspected |
| `TosaToLinalgNamed.cpp:333, 363` (Conv) | `4 == rank`, `5 == rank` | fixed-rank ops | single-rank domain | none: no rank question |
| Not yet inventoried | TOSA op verifiers, `populateTosaTypeConversion`, `tosa-infer-shapes`, `tosa-make-broadcastable`, canonicalization, `tosa-optional-decompositions`, `tosa-layerwise-constant-fold`, linalg and tensor verifiers | unknown | unknown | needed for any pipeline-level claim |

### The eight questions, as answered then

1. **Finitely many constant thresholds?** In the conversion patterns, almost none: only the conv
   rank tests, which are fixed-rank anyway. Rank dependence came from loops and from positions
   relative to the axis. Constant thresholds appeared in validation (MAX_RANK).
2. **Loops or indexing that block a cutoff?** None seen. Loops were column-local or mark-local. The index
   shift `i > axis ? i+1 : i` is an order test against the mark, which is finite-state. Permutations
   (transpose) cannot be written in a finite alphabet, but the pattern treated every permutation the same way.
3. **Hidden dependencies in helpers?** Yes. O3's failure condition lives in the tensor dialect's
   `ExpandShapeOp` builder and verifier, not in TosaToLinalg.
4. **Finitely many rank-equivalence classes?** Conjectured for `ReduceConverter` (H1). Not proved.
5. **Property preserved beyond the bound:** the candidate was P2 together with P3, hence P4, for D0 on the
   bare pass, conditional on the obligations.
6. **Smallest sufficient bound:** unknown. The conjectured frame gave about 2–3 for `ReduceConverter` alone. The
   observed minimal witness for O3 was rank 2. Under V_tosa1.0 the domain already ended at rank 6.

### Conjecture H1 for D0 (`tosa.reduce_sum`, bare pass, V_mlir)

**H1 (conjecture, never tested).** O(a, w) depends only on the element type, on whether r = 1, and on the
letters at the frame {axis, partner}. If so, P3 is constant: `ReduceConverter<ReduceSumOp>` is the only
pattern applied, since every op it creates is legal under the target at `TosaToLinalgPass.cpp:50–65`.

Evidence then: the only failure returns in the pattern were rankedness (1168), initial value (1199) and body
creation (1287), all depending on element type and op only; O3's mechanism is local to one reassociation group.

Open then: `inferExpandShapeOutputShape`; the verifiers of `linalg.reduce`, `linalg.fill` and `tensor.empty`;
rank 1 with a result type of `?`.

Prediction then, never tested: under V_mlir, the only non-`LOWERED` class is a result type with `?` at both the
axis and its partner, ending `OUTPUT_INVALID` at every rank ≥ 2. Under V_tosa1.0, every case of rank 1–6 is `LOWERED`.

### Ledger, as of 2026-11-01

| Item | Status |
|---|---|
| A1–A5 for `ReduceConverter` closure | open; pattern body and `ExpandShapeOp::build` read |
| A1–A5 for `PointwiseConverter` closure | open; pattern body read, builders not |
| Pipeline-level claim | open; under V_tosa1.0 the domain is finite (r ≤ 6) |
