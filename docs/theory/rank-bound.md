# Rank bound: inventory, theorem, proof status

All source locations are at `llvmorg-23.1.1` (`6dfe1677ab8d`) unless stated otherwise.

> **Status (2026-11-01).** No rank theorem is established for any target. Theorem 1 and its
> corollaries are proved as generic statements about an abstraction. Whether TosaToLinalg
> satisfies the abstraction's assumptions is **open**. Theorem 2 is a proof sketch.

## 1. Four propositions that must not be confused

Fix a conversion C, a domain D and a bound R. Each proposition below is about cases of rank > R.

| | Proposition | Notes |
|---|---|---|
| P1 | **Same branches.** Every case takes the same decisions as some case of rank ≤ R, with loop bodies compared per iteration class. | Almost never literally true, because traces grow with rank. Useful only as a proof tool. |
| P2 | **Same outcome.** There is a rank-reducing map ρ that preserves validity and the outcome class. | Implies P4. |
| P3 | **Same pattern set.** The set of patterns applied equals that for ρ(x). | Independent of P2. O3 applies the same pattern as a lowered case but ends `OUTPUT_INVALID`. |
| P4 | **Same coverage verdict.** If every valid case of rank ≤ R is `LOWERED`, so is every valid case. | The property the project wants. P4 does not imply P2. |

## 2. Rank-dependency inventory (TosaToLinalg, partial)

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

## 3. The eight questions, answered for the inspected part

These answers are provisional.

1. **Finitely many constant thresholds?** In the conversion patterns, almost none: only the conv
   rank tests, which are fixed-rank anyway. Rank dependence comes from loops and from positions
   relative to the axis. Constant thresholds appear in validation (MAX_RANK).
2. **Loops or indexing that block a cutoff?** None seen so far. Loops are column-local or
   mark-local. The index shift `i > axis ? i+1 : i` is an order test against the mark, which is
   finite-state. Permutations (transpose) cannot be written in a finite alphabet, but the pattern
   treats every permutation the same way.
3. **Hidden dependencies in helpers?** Yes. O3's failure condition lives in the tensor dialect's
   `ExpandShapeOp` builder and verifier, not in TosaToLinalg. Any inventory must follow the call
   graph into other dialects.
4. **Finitely many rank-equivalence classes?** Conjectured for `ReduceConverter` (H1, §6).
   Not proved.
5. **Property preserved beyond the bound:** the candidate is P2 together with P3, hence P4, for D0
   on the bare pass, conditional on the obligations.
6. **Smallest sufficient bound:** unknown. The conjectured frame gives a bound of about 2–3 for
   `ReduceConverter` alone. The observed minimal witness for O3 is rank 2. Under V_tosa1.0 the
   domain already ends at rank 6, so the question only matters for the bare pass and for level
   `none`.
7. **Assumptions:** A1–A5 in §4.
8. **How to check them:** see the "Check" column in §4.

## 4. Formal model

**Abstract cases.**

- Fix a finite set A of rank-independent parameters, such as element type and flags.
- Fix a finite per-position alphabet Σ. For D0, a letter is (input letter, result letter, axis
  mark), with each dimension letter drawn from {1, s, ?}.
- An abstract case is (a, w) with a ∈ A and w ∈ Σ*. Its rank is |w|.
- The concretization γ maps 1 → 1, s → a chosen n ≥ 2, and ? → dynamic.
- V ⊆ A × Σ* is the declared validity oracle.
- O(a, w) is the observed outcome of running C on γ(a, w): a pair of the class (§3 of the
  [problem statement](../research/problem-statement.md)) and the set of patterns applied and
  surviving. Out, the set of possible outcomes, is finite.

| | Assumption | Check |
|---|---|---|
| A1 | **Determinism.** O is a function. | repeated runs; `--mlir-disable-threading` |
| A2 | **Representative independence.** Every concretization of (a, w) has the same outcome. | source: every use of a static size goes through a predicate that is constant on each letter (`== 1`, `> 1`, `isDynamic`); tests: alternative representatives |
| A3 | **Finite-state rank dependence.** For each a, a deterministic automaton with output and at most k states computes w ↦ O(a, w). | the source conditions S1–S8 below, for every function on the transitive call path, including builders and verifiers of created ops |
| A4 | **Faithful observation.** The recorded outcome equals the true one. | adapter output identical to `mlir-opt` output; listener begin counts match the action log; rollback attribution |
| A5 | **Regular validity.** V_a is recognized by an automaton with at most k_V states. | write V as an automaton from the spec: one axis mark, allowed letters, r ≤ MAX_RANK |

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

*Status:* proved. The argument is elementary. **The research burden is entirely in establishing
A2, A3 and a value of k for real code.**

**Corollary 1 (minimal witnesses).** If a gap exists, one exists at rank < N. Enumerating in
increasing rank therefore returns a witness of minimal rank.

**Corollary 2 (unreachability in D).** For a pattern p, the set {w ∈ V_a : p is applied and
survives} is regular with at most N states. If p applies to no valid case of rank < N, it applies
to no valid case of D at any rank. *This is the only sanctioned route to the label "unreachable
in D"* (CLAUDE.md rule 3).

**Theorem 2 (symmetric threshold variant, reduces enumeration).** Suppose each word splits into a
*frame* of at most d positions with regular roles (first, last, axis, partner) and a *bulk* of the
remaining positions. Assume (A3′) that O(a, w) and V_a(w) depend only on the frame letters with
their roles and, for each σ ∈ Σ, on min(#σ in the bulk, t). Then every combination of outcome
and validity that occurs at some rank also occurs at rank ≤ d + t·|Σ|. It suffices to test one
word per (frame assignment, capped count vector).

*Proof sketch.* Deleting bulk positions of a letter whose count exceeds t leaves the capped counts
unchanged. It also leaves the frame roles unchanged, provided the frame contains every position
whose role depends on adjacency (for D0, both neighbours of the axis). *Status:* sketch; the
role-preservation step must be checked for each frame definition.

**Remarks.**

- A guard on r mod m is finite-state, so Theorem 1 still applies, but A3′ fails unless counts are
  also taken mod m.
- MAX_RANK = 32 at level `none` makes Theorem 1's N at least 34. Enumerating every word below
  that is infeasible. Handle the validity threshold analytically, since it is explicit in
  `TargetEnv.h`, and apply Theorem 2 to the conversion alone.
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

## 5. Application to D0 (`tosa.reduce_sum`, bare pass, V_mlir)

**H1 (conjecture).** O(a, w) depends only on the element type, on whether r = 1, and on the
letters at the frame {axis, partner}. If so, P3 is constant: `ReduceConverter<ReduceSumOp>` is the
only pattern applied, since every op it creates is legal under the target at
`TosaToLinalgPass.cpp:50–65`.

Evidence for H1:

- The only failure returns in the pattern are rankedness (1168), initial value (1199) and body
  creation (1287). All three depend on element type and op only.
- O3's mechanism is local to one reassociation group.

Open:

- `inferExpandShapeOutputShape`.
- The verifiers of `linalg.reduce`, `linalg.fill` and `tensor.empty`.
- Rank 1 with a result type of `?` (not yet probed).

**Prediction to test in the spike.** Under V_mlir, the only non-`LOWERED` class is a result type
with `?` at both the axis and its partner, which ends `OUTPUT_INVALID` at every rank ≥ 2. Under
V_tosa1.0, every case of rank 1–6 is `LOWERED`.

## 6. Proof-status ledger

| Item | Status |
|---|---|
| Theorem 1, Corollaries 1 and 2 (generic) | proved (elementary); not yet reviewed by a second reader |
| Theorem 2 | proof sketch |
| A1–A5 for `ReduceConverter` closure | open; pattern body and `ExpandShapeOp::build` read; the rest listed above |
| A1–A5 for `PointwiseConverter` closure | open; pattern body read, builders not |
| Pipeline-level claim | open; under V_tosa1.0 the domain is finite (r ≤ 6), so an all-rank claim adds nothing there |
| Smallest N for D0 | unknown |
