# Expected outcomes for D0-tt, before any run

> **Owner: the user. Editable until this file is first committed.** The user changes any prediction they
> disagree with before that commit.
>
> **After that commit the file is frozen.** Later sessions may add a "Result" column. They never change a
> prediction, including one that turns out wrong.

Written 2026-11-04, before any `results/` folder exists. **Nothing here has been run.** No `ttmlir-opt` exists on
this machine (D-015). Every class below is a prediction from reading source.

**Labels (rule 6):** **[F]** read from source. **[H]** hypothesis, including every predicted class.

## Setup

| Item | Value |
|---|---|
| Commits | tt-mlir `f9dc1b3e5101`; LLVM `4efe170d858e`. All citations are at these commits |
| Domain | D0-tt (D-013), with positive or negative dims and no repeated positions (D-017) |
| Oracle | V_ttir only (D-014): `ttmlir-opt case.mlir`, no passes |
| Bare pass | `ttmlir-opt --ttcore-register-device --ttnn-layout --convert-ttir-to-ttnn case.mlir` (D-017) |
| Pipeline | `ttmlir-opt --ttir-to-ttnn-runtime-pipeline case.mlir`, no options (D-017) |
| Classes | [problem statement §3](../research/problem-statement.md). A `ttnn.prod` rank failure is `EXPECTED_REJECTION` (D-017) |

**Assumption on the build.** Every `CRASH` here assumes tt-mlir's own code is compiled with assertions. `SmallVector.h`
and `alignUp` are headers, so their asserts follow tt-mlir's build type, which is undecided. LLVM's libraries have
assertions on (`env/CMakeLists.txt:68`), but that setting does not cover tt-mlir's code.

**Terms.** Marks: *one* means |`dim_arg`| = 1. *All* means `dim_arg` absent or |`dim_arg`| = r. *Partial* means
1 < |`dim_arg`| < r, so r ≥ 3. *Static* means letters from {1, s}. *Negative* means at least one negative entry in `dim_arg`.

**Pattern sets.** Applied patterns are named by the pass that runs them. A later adapter may observe only the
conversion pass, so the patterns in **D** and **W** may have to be checked from the output IR instead.

| Name | Patterns | Pass | Source |
|---|---|---|---|
| **T** | `TensorEmptyConversionPattern`, `ToLayoutOpConversionPattern` | conversion; handles what `--ttnn-layout` inserts | `TTIRToTTNN.cpp:43,154`; `TTNNLayout.cpp:206,243-245`; `include/ttmlir/Dialect/TTIR/Utils/Utils.h:145-147` |
| **P** | `ReductionProdOpConversionPattern` | conversion | `TTIRToTTNN.cpp:243-280,3878` |
| **Σ** | `ReductionOpConversionPattern<ttir::SumOp, ttnn::SumOp>` | conversion | `TTIRToTTNN.cpp:226-239,3874` |
| **D** | `ReductionProdPattern` | `ttir-to-ttir-decomposition`, pipeline only | `TTIRToTTIRDecomposition.cpp:1797-1845`; `TTNNPipelines.cpp:58` |
| **W** | `IntegerProdOpRewritePattern` | workarounds, pipeline only, on by default | `IntegerProdOpRewritePattern.cpp:15,47-48`; `TTNNWorkaroundsPatterns.cpp:447`; `TTNNPipelines.h:283-286` |

## Predictions for `ttir.prod`

`keep_dim` and bulk letters are predicted not to change a class (H6), except where a row names them.

| Id | Cases | Mode | Predicted class | Predicted applied patterns | Rests on |
|---|---|---|---|---|---|
| P1 | r ≤ 4; one or all; static; f32 or bf16; any sign | bare | `LOWERED` | T, P | H6; `TTIRToTTNN.cpp:258,268-273`; `simple_prod.mlir` for pipeline ranks 1, 3, 4 only |
| P1 | same | pipeline | `LOWERED` | T, P | H6; `TTIRToTTIRDecompositionPass.cpp:176-183` (legal, not decomposed); `simple_prod.mlir` |
| P2 | r ≤ 4; one or all; static; si32; any sign | bare | `LOWERED` | T, P | H6; `TTIRToTTNN.cpp:258,268-273` |
| P2 | same | pipeline | `LOWERED` | T, P; plus W when `dim_arg` has one entry, since reps 1, 2, 3, 7 are ≤ 16 | H6; `IntegerProdOpRewritePattern.cpp:31,47-48` |
| P3 | 3 ≤ r ≤ 4; partial; static; no negative | bare | `CONVERSION_FAILED` | P attempted, match failed with the reason at `TTIRToTTNN.cpp:259-261`; T may apply and roll back | `TTIRToTTNN.cpp:258-261`; no lit test seen, so not `EXPECTED_REJECTION` |
| P3 | same | pipeline | `LOWERED` | D; T; P once per mark; plus W per link on si32 | `TTIRToTTIRDecompositionPass.cpp:176-183`; `TTIRToTTIRDecomposition.cpp:1809-1845` |
| P4 | 3 ≤ r ≤ 4; partial; static; negative | bare | `CONVERSION_FAILED` | as P3 bare | `TTIRToTTNN.cpp:258-261`; the pattern tests size only |
| P4 | same | pipeline | `CRASH`, in decomposition | D attempted; nothing survives | `TTIRToTTIRDecomposition.cpp:1835` (`shape[dim]`), `:1837` (`erase`); `SmallVector.h:294,741`; candidate gap in [rank-bound §5](../theory/rank-bound.md) |
| P5 | r ≥ 5; one or all; static | bare | `EXPECTED_REJECTION` | T, P applied; output then fails `ttnn.prod`'s verifier | `TTNNOps.cpp:6026-6031,6085-6087`; `negative_reduce_prod_op.mlir:1-7` for r = 5, one dim, f32 only; H6 beyond that |
| P5 | same | pipeline | `EXPECTED_REJECTION` | T, P applied; W not reached | same |
| P6 | r ≥ 5; partial; static; no negative | bare | `CONVERSION_FAILED` | as P3 bare; no `ttnn.prod` is created | `TTIRToTTNN.cpp:258-261`, which runs before any verifier sees a `ttnn.prod` |
| P6 | same | pipeline | `EXPECTED_REJECTION` | D; T; P per mark; the first link still has rank r | `TTIRToTTIRDecomposition.cpp:1831-1845`; `TTNNOps.cpp:6026-6031` |
| P7 | r ≥ 5; partial; static; negative | bare | `CONVERSION_FAILED` | as P3 bare | as P6 bare |
| P7 | same | pipeline | `CRASH`, in decomposition | D attempted; nothing survives | as P4 pipeline. Decomposition runs before the conversion (`TTNNPipelines.cpp:58,419`) |
| P8 | any r, any marks; `?` in one of the last two positions | bare | `CRASH`, in `--ttnn-layout` | none; the conversion never starts | `TTNNLayout.cpp:86-87,243-245`; `TTNNOpsAttrs.cpp:1606-1607`; `lib/Dialect/TTNN/Utils/Utils.cpp:289-301`; `include/ttmlir/Utils.h:49` (`assert(val >= 0)`); `kDynamic` is negative |
| P8 | same | pipeline | `CRASH`, in `ttnn-layout` | none in the conversion; D on partial, no-negative cases | same, plus `TTNNPipelines.cpp:171`. A partial negative case crashes earlier, as P4 |
| P9 | r ≥ 3; any marks; `?` only before the last two positions | bare | `CRASH`, in `--ttnn-layout` | none | **weakest row.** `collapsedLinearAffineMap` multiplies by `shape[d]` (`TTCoreOpsTypes.cpp:885`); `MemRefType` rejects negative sizes other than `kDynamic` (LLVM `BuiltinTypes.cpp:687`). The path between them was not traced |
| P9 | same | pipeline | `CRASH`, in `ttnn-layout` | none in the conversion; D on partial, no-negative cases | same |

## Predictions for the control, `ttir.sum`

| Id | Cases | Mode | Predicted class | Predicted applied patterns | Rests on |
|---|---|---|---|---|---|
| S1 | any r; any marks; static; any type; any sign | bare | `LOWERED` | T, Σ | H7; `TTIRToTTNN.cpp:226-239`, with no failure return; `TTNNOps.cpp:5985-6017,6063-6067`, with no rank cap |
| S1 | same | pipeline | `LOWERED` | T, Σ | **beyond H7**, which covers the bare pass; `simple_sum.mlir:6,17` for ranks 2 and 4, bf16 only |
| S2 | any r; `?` in one of the last two positions | bare | `CRASH`, in `--ttnn-layout` | none | same path as P8; layout does not depend on the op |
| S2 | same | pipeline | `CRASH`, in `ttnn-layout` | none in the conversion | same |
| S3 | r ≥ 3; `?` only before the last two positions | bare | `CRASH`, in `--ttnn-layout` | none | same path as P9 |
| S3 | same | pipeline | `CRASH`, in `ttnn-layout` | none in the conversion | same |

## Outside the domain: repeated positions

`[d, d−r]` names one position twice. V_ttir accepts it because uniqueness is checked on raw values
(`TTIROps.cpp:6713,6717`), but D-017 keeps it out of D0-tt, so these are probes and do not count toward coverage.
At r ≥ 5, X1's cases are predicted as P5.

| Id | Cases | Mode | Predicted class | Predicted applied patterns | Rests on |
|---|---|---|---|---|---|
| X1 | 2 ≤ r ≤ 4; list length = r with a repeated position; static | bare | `LOWERED`, with a correctness question: every dim is reduced while the result type records fewer | T, P | `TTIRToTTNN.cpp:258,269`; `TTNNOps.cpp:6085-6087` checks rank only |
| X1 | same | pipeline | `LOWERED`, same question | T, P | `TTIRToTTIRDecompositionPass.cpp:176-183` |
| X2 | r ≥ 3; 1 < list length < r with a repeated position; static | bare | `CONVERSION_FAILED` | as P3 bare | `TTIRToTTNN.cpp:258-261` |
| X2 | same | pipeline | `CRASH`, in decomposition | D attempted | as P4 pipeline |

## Exp F controls

A control V_ttir rejects is `INVALID` and no conversion runs, so its prediction is the same in both modes. All four
lit files use `ttir.sum`. `ttir.prod` shares the verifier (`TTIROps.cpp:6694-6742,6831-6833`), so the prediction
covers both ops.

| Id | Control | Predicted class | Predicted applied patterns | Rests on |
|---|---|---|---|---|
| F1 | unranked input | `INVALID` | none | `TTIROps.td:2742` (`AnyRankedTensor`) |
| F2 | dim too low, `-3` at r = 2 | `INVALID` | none | `test/ttmlir/Dialect/TTIR/reduction/negative_invalid_dim_low.mlir` |
| F3 | dim too high, `2` at r = 2 | `INVALID` | none | `test/ttmlir/Dialect/TTIR/reduction/negative_invalid_dim_high.mlir` |
| F4 | repeated dims, `[1, 2, 3, 2]` | `INVALID` | none | `test/ttmlir/Dialect/TTIR/reduction/negative_repeating_dims.mlir` |
| F5 | result shape mismatch | `INVALID` | none | `test/ttmlir/Dialect/TTIR/reduction/negative_shape_mismatch.mlir` |
| F6 | ill-typed like O7: `tensor<2xf32> -> tensor<2x2x1xf32>`, dim 0 | `INVALID` | none | `TTIROps.cpp:6723-6739` |
| F7 | rank 5, one dim, f32 (V_ttir accepts it), pipeline | `EXPECTED_REJECTION` | T, P applied, as P5 | `negative_reduce_prod_op.mlir:1-7` |
| F8 | the same case, bare | `EXPECTED_REJECTION` | T, P applied, as P5 | **[H]** the lit test runs the pipeline only; `TTNNOps.cpp:6026-6031` |

## Predictions I am least sure of

1. **P9 and S3, `?` before the last two positions.** The path was traced only as far as `collapsedLinearAffineMap`,
   not through `evalShape` or `buildMemRef`. `kDynamic` could survive to a valid memref. Then these cases would reach
   the conversion and could end `LOWERED`.
2. **P8 and S2, `?` in the last two positions.** The assert is plain in the source, but no lit test exercises it, and
   the prediction needs the build assumption. Without assertions `alignUp` returns a negative size that is not
   `kDynamic`, which `MemRefType::verify` should reject in LLVM's assertion-enabled code. The class is probably still
   `CRASH`, though that path was not traced either.
3. **P4, P7 and X2, negative partial lists.** No pass found before decomposition normalizes `dim_arg`, but only the
   `ttir.prod` canonicalizer was read, and fusing was checked by its pattern names, not in full. Without assertions in
   tt-mlir, these are out-of-bounds accesses with undefined behaviour, so no single class can be predicted.
4. **S1 in the pipeline at r ≥ 5.** H7 covers the bare pass only. No test was read for `ttir.sum` at that rank, and the
   workarounds, fusing and later passes were not inventoried for it.
5. **P2 and P3 on si32.** The body of `IntegerProdOpRewritePattern` after its guards was not read, and neither was the
   bf16 operand workaround's effect (`TTNNWorkaroundsPass.cpp:1058-1065`). The rewrite could produce output that later
   fails. No `ttir.prod` lit test on si32 was found under `test/ttmlir/Dialect/TTNN/reduction/`.
6. **P5, P6 and F8 beyond the lit shape.** The verifier reading is direct, but only r = 5, one dim, f32 in the pipeline
   is tested. Treating all of them as `EXPECTED_REJECTION` is D-017's rule applied by conjecture. P6's first link could
   also fail in some other way first.
7. **P3 and P6 bare as gaps.** By the class table these are gaps, since no test exercises the match failure. The source
   comment (`TTIRToTTNN.cpp:255-257`) says decomposition is meant to remove them first. The prediction is the class,
   not a claim that this is a defect.
8. **Whether T rolls back on failure rows.** Order of legalization and rollback were not read for this case. It affects
   the applied set only, not the class.
9. **The no-option pipeline here.** Lit runs it with no options (`simple_prod.mlir:1`), but the default device
   registration has never run on this machine, and the optional passes in `TTNNPipelines.cpp` were not all read.
