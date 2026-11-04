# TODO: L2

Component A of [architecture §2](design/architecture.md), for D0-tt (D-013, D-017) under V_ttir (D-014).

**Status:** stubs and tests only. Rule 12 still holds: the slice in architecture §3 is proposed, not accepted. `vTtir` is
a reading of the source and has never been compared with `ttmlir-opt`, which cannot run here (D-015).

**Labels (rule 6):** **[F]** read from source. **[H]** hypothesis, not run. Citations to `.cpp`, `.td` and lit `.mlir` files are at
tt-mlir `f9dc1b3e5101`, read 2026-11-04, with the short file names the [problem statement](research/problem-statement.md) uses.

Implement in this order:

1. `LowerAudit.Domain`: `rank`, `dimArgOf`, `mkAbstractCase`
2. `LowerAudit.Oracle`: `vTtir`
3. `LowerAudit.Concretize`: `representativeSize`, `concretizeDim`, `concretize`

Run with `make test`. Every failure is `TODO: <function>` until that function exists. `test/Generators.hs` is complete
and is not a TODO.

## Spec: rank

- **Signature:** `rank :: AbstractCase -> Int`
- **Behaviour:** the tensor rank, |w| ([rank-bound §4](theory/rank-bound.md)).
- **Edge and error cases:** none. Rank ≥ 1 by type.
- **Tests:** `LowerAudit.Domain / rank`.

## Spec: dimArgOf

- **Signature:** `dimArgOf :: AbstractCase -> Maybe [Int]`
- **Behaviour:** the raw `dim_arg` a word denotes. One entry per marked position, in ascending position order. At rank r, a
  mark at position p gives p if `Positive` and p − r if `Negative`.
- **Edge and error cases:** a word with no marks gives `Nothing`, never `Just []`. The two mean opposite things to the
  verifier (see `vTtir`). Position order differs from numeric order: `Positive` at 0 and `Negative` at 2 of 3 is `[0, -1]`.
- **Tests:** `LowerAudit.Domain / dimArgOf`, and the round trip under `mkAbstractCase`.

## Spec: mkAbstractCase

- **Signature:** `mkAbstractCase :: Params -> NonEmpty DimLetter -> Maybe [Int] -> Either DomainError AbstractCase`
- **Behaviour:** reads a raw `dim_arg` into per-position marks on the given letters, deciding membership in D0-tt. `Nothing`
  gives no marks. An entry d ≥ 0 marks position d `Positive`. An entry d < 0 marks position d + r `Negative`. Marks are a
  set (D-013), so list order does not change the result.
- **Edge and error cases,** in this order of precedence:

  | Error | When | Source |
  |---|---|---|
  | `EmptyDimArg` | `Just []` | `problem-statement.md:133` |
  | `DimNotInRank d` | the first entry, in list order, outside −r ≤ d < r | `TTIROps.cpp:6708` |
  | `RepeatedPosition p` | the first entry, in list order, naming a position an earlier entry named; p is that position, 0 ≤ p < r | D-017; `rank-bound.md:187` |

- **Tests:** `LowerAudit.Domain / mkAbstractCase`. The property there states the invariant: every generated case rebuilds
  from its own parts.

## Spec: vTtir

- **Signature:** `vTtir :: ConcreteCase -> Either Violation ()`
- **Behaviour:** the declared V_ttir. It applies these rules in the verifier's order, and the first failure is the result:

  | Order | Rule | Violation | Source row |
  |---|---|---|---|
  | 1 | every entry satisfies −r ≤ d < r; the first failing entry in list order is named | `DimOutOfRange d` | `TTIROps.cpp:6708` |
  | 2 | raw values are distinct, so `[d, d−r]` passes | `DimsNotUnique` | `TTIROps.cpp:6713,6717` |
  | 3 | the result shape equals the expected shape | `ResultShapeMismatch expected actual` | `TTIROps.cpp:6723-6739` |

  **Expected shape:** each position, in order. An unreduced position keeps its input dim. A reduced position becomes
  `Size 1` under `keep_dim` and disappears otherwise. Which positions are reduced: `Nothing`, all of them (`:6702-6703`);
  `Just list`, the ones listed, with a negative d naming d + r (`:6714`), so `Just []` reduces none.

- **Edge and error cases:**
  - `DynamicSize` equals only `DynamicSize`, since `:6733` compares raw shape values.
  - Op and element type play no part: both ops call one verifier (`:6769-6772,6831-6834`).
  - No rank rule applies, including at rank 5 (F7). At rank 0 no entry is in range.
- **Tests:** `LowerAudit.Oracle`. Each test name carries its source row and its control id from
  [expected outcomes](experiments/expected-outcomes.md), F2–F7 and X1. Each row runs under every op and element type.

## Spec: representativeSize

- **Signature:** `representativeSize :: Representative -> Natural`
- **Behaviour:** `Rep2`, `Rep3` and `Rep7` are 2, 3 and 7 (`problem-statement.md:132`).
- **Edge and error cases:** none. Each is ≥ 2 (`rank-bound.md:73`).
- **Tests:** `LowerAudit.Concretize / representativeSize`.

## Spec: concretizeDim

- **Signature:** `concretizeDim :: Representative -> DimLetter -> Dim`
- **Behaviour:** γ on one letter (`rank-bound.md:73`): `One` is `Size 1`, `Static` is the representative's size, `Dynamic`
  is `DynamicSize`.
- **Edge and error cases:** only `Static` depends on the representative.
- **Tests:** `LowerAudit.Concretize / concretizeDim`.

## Spec: concretize

- **Signature:** `concretize :: Representative -> AbstractCase -> ConcreteCase`
- **Behaviour:** γ on a case. `concreteParams` is unchanged. `inputShape` is `concretizeDim` at each position. `dimArg` names
  the marked positions as `dimArgOf` does. `resultShape` is the shape V_ttir requires (`problem-statement.md:138`).
- **Edge and error cases:** no marks means every position is reduced, so the result is rank 0 without `keep_dim` and all
  ones with it. All marked without `keep_dim` is also rank 0 (`simple_prod.mlir:25`). An unmarked `?` stays `?` in the result.
- **Tests:** `LowerAudit.Concretize / concretize examples` and `/ concretize properties`.

## Decisions

- **Model D0-tt, not D0.** D0, V_mlir, V_tosa1.0, `MAX_RANK`, the single axis mark and the result letter belong to the dated
  record (`problem-statement.md:174-203`), superseded by D-010, D-013 and D-014. D-013 replaces the single mark with a set,
  and `rank-bound.md:70-71` drops the result letter. **[F]** V_ttir has no rank rule, so `MAX_RANK` has nothing to
  parameterize. `ttnn.prod`'s rank > 4 belongs to the output verifier, not the oracle.
- **Every `AbstractCase` is in D0-tt.** `NonEmpty` gives rank ≥ 1. One `Mark` per position gives a set of in-range positions
  with no repeats. The result is derived, so it has no field. The types count exactly D-017's cases: 9 letters and 2 values of
  `keep_dim` give 2·9^r per element type and op. So the constructor is public, and no check guards it.
- **The smart constructor is at the raw list.** A type cannot tie a `[Int]` to a rank, so that is where `mkAbstractCase` goes.
  It rejects `[]` and `[d, d−r]`, which V_ttir accepts: membership in D0-tt and validity are separate questions.
- **`vTtir` judges `ConcreteCase`, not `AbstractCase`.** Over abstract cases it would be constant, with no rule left to test,
  and controls F2–F6 have no abstract form. Validity of (a, w) is `vTtir . concretize rep`, and a property checks it under
  every representative (architecture §2 row A). **[H]** If the declared oracle matches the real verifier, V_a is Σ⁺ and
  k_V = 1, which settles A5 (`rank-bound.md:85`) for this encoding. Not recorded there, since no run backs it.
- **`ConcreteCase` lives in `LowerAudit.Domain`,** so that `LowerAudit.Oracle` need not depend on `LowerAudit.Concretize`.
- **`Size Natural`:** a negative size cannot be written. **`Representative`** is a closed type, so a size below 2 cannot be
  chosen. **Canonical `dim_arg` order** is ascending position (Open question 8).
- **No new dependencies.** The library stays on `base`. The tests now import `tasty-quickcheck`, which `TODO-l0.md` lists as
  not yet imported.
- **`-Wno-orphans` in `test/Generators.hs`:** `Arbitrary` is a test-only dependency, so its instances cannot sit with the
  types. `-Wall` warns otherwise.

## Shortcuts

- **Generated rank stops at 10** (`test/Generators.hs`). The domain has no such cap. Raise it if a rule or a bound needs it.
- **F1 (unranked) and a differing result element type cannot be written as a `ConcreteCase`.** They stay hand-written `.mlir`
  controls.
- **`vTtir` encodes only `verifyReduceOp`** (Open question 7).

## Open questions

Each one names the line it comes from and what the stub does meanwhile. Line numbers are in
`docs/research/problem-statement.md` unless stated.

1. **What the word with no marks means (`:133,153-154`).** Line 133 lists "a set of reduced positions, or `dim_arg` absent". The
   counts 2^r and 3^r only add up if the no-mark word is the absent case, so a mark means "listed", not "reduced". *Stub:* as
   read, pinned by tests. Confirm.
2. **The empty list (`:133`, "out until decided").** **[F]** It is not a spelling of absent: `[]` reduces nothing
   (`TTIROps.cpp:6702-6730`), so the verifier accepts it only when the result equals the input. V_ttir therefore accepts a case
   D0-tt excludes. *Stub:* `mkAbstractCase` rejects it and `vTtir` judges it. Admitting it would make 3^r + 1 mark options per
   rank, which the per-position alphabet cannot express.
3. **Rank 0 (`:131`, "excluded for now, as in D-005").** D-005 is superseded, and its text does not mention rank. **[F]** By
   reading, V_ttir accepts `tensor<f32> -> tensor<f32>` with `dim_arg` absent. *Stub:* `NonEmpty` excludes it from
   `AbstractCase`, and `vTtir` judges it. Is the exclusion still wanted, and why?
4. **Size 0 (`:132,141-147`).** No letter covers it, since `s` is "static > 1", and "Outside D0-tt" does not list it.
   **[F]** `verifyReduceOp` has no size rule, so by reading V_ttir accepts it. *Stub:* unreachable from `AbstractCase`. Should
   it be listed as outside?
5. **The result element type (`:138-139`).** "The result type follows", but the reason given covers shape only. **[F]**
   `verifyReduceOp` reads no element type, and the op adds no element-type trait (`TTIROps.td:311,2715-2716,2742-2746`), so by
   reading V_ttir accepts `f32` in and `si32` out. *Stub:* `ConcreteCase` has one element type. Does this need a control?
6. **`?` under V_ttir (`:41,132`).** Line 132 raises `?` for the pipeline only, and line 41 does not mention it. **[F]** Raw
   comparison (`TTIROps.cpp:6726,6733`) means an unreduced `?` must stay `?`, and a reduced `?` under `keep_dim` must be 1. *Stub:*
   tests pin this reading. Line 132 says no `ttir.prod` lit test uses `?`, so only a run can confirm it.
7. **"Parser and TTIR verifiers" against the rules listed (`:40-41`).** Line 40 defines V_ttir by everything `ttmlir-opt` checks.
   Line 41 lists the shared verifier's three checks. *Stub:* line 41 only. Not modelled: entries fitting i32
   (`TTIROps.td:2744`), `keep_dim` being required (`TTIROps.td:2743`), the enclosing function's return type. **[H]** These do not change
   a verdict on cases the generator renders correctly.
8. **List order (`:133,135,154`).** Marks are a set, `dim_arg` is a list, and the counts include each set once. Nothing says `[2, 0]`
   and `[0, 2]` are one case, and V_ttir accepts both. *Stub:* one case, in position order. **[F]** The decomposition sorts the list
   (`TTIRToTTIRDecomposition.cpp:1824`) and the conversion pattern tests its size only (`rank-bound.md:33-34`). **[H]** Order does
   not change an outcome; the other passes were not read.
9. **Representatives and A2 (`:132`; `rank-bound.md:40,73,82,179`).** Not a validity question, but the tests leave it open.
   (a) γ chooses one n and A2 says every concretization. *Stub:* one representative per case, so `s,s` is never `2x3`, and A2's check
   cannot see an outcome that depends on the mix. (b) 2, 3 and 7 are all ≤ 16 (`expected-outcomes.md:52`), so varying them cannot
   reach the one known A2 break, the size test on si32. A fourth representative above 16 is one constructor; it is not added
   because line 132 names three.
