# Problem statement

Status: **reworked 2026-11-04 for the accepted target** (D-012 to D-015 in the
[decision log](../decisions/decision-log.md)). Nothing here has been executed on the target.

**Labels (rule 6):** **[F]** read from source at the commits below. **[H]** hypothesis, not run.

**Commits:** tt-mlir `f9dc1b3e5101`; its LLVM, `llvm/llvm-project` `4efe170d858e` (22.0 dev). Current
`file:line` citations are at these commits. Citations at `llvmorg-23.1.1` appear only in the dated
[record](#8-record-tosatolinalg-at-llvmorg-2311-2026-11-01).

## 1. Problem

An MLIR lowering is a set of C++ rewrite patterns run by the dialect-conversion driver. Which
inputs a lowering actually handles is spread across pattern guards, helper functions, type
converters, and the builders and verifiers of the ops the patterns create. Lit tests sample a few
shapes. **[F]** In `test/ttmlir/Dialect/TTNN/reduction/`, the `ttir.prod` tests use input ranks 1, 3 and
4 (`simple_prod.mlir`), plus one negative test at rank 5 (`negative_reduce_prod_op.mlir:1-7`).

For a declared input domain D, this project asks:

- **Coverage:** is every valid case in D lowered?
- **Reachability:** which registered patterns are observed to apply on D, and which never are?
- **Rank generalization:** when D is unbounded in tensor rank, under what conditions do checks
  up to a finite rank imply the result for every rank? See [rank-bound](../theory/rank-bound.md).

## 2. Terms

| Term | Meaning |
|---|---|
| Conversion under test C | A pass or pass pipeline at a pinned commit, invoked unmodified. |
| Case | One `func.func` containing one source op, with its operand/result types and attributes, as `.mlir` text. |
| Domain D | A set of cases given by parameters plus validity constraints (§6). |
| Validity oracle | Decides whether a case belongs to D. Every result names its oracle. |
| Outcome | The class C's run falls into (§3), plus the set of patterns applied. |
| Gap | A valid case whose outcome is `CONVERSION_FAILED`, `OUTPUT_INVALID`, `CRASH` or `TIMEOUT`. |

There is one validity oracle (D-014):

- **V_ttir**: the parser and TTIR verifiers accept the case (`ttmlir-opt case.mlir`, no passes).
  **[F]** For `ttir.prod` the shared verifier checks dim range, uniqueness and result shape, with no rank
  cap (`TTIROps.cpp:6694-6742,6831-6833`). **[F]** No operator spec backs it in the repository
  (`docs/src/specs/specs.md:3-8`). A verdict means "the TTIR verifier accepts it", not "a spec requires
  it". **[H]** Whether that is acceptable is unasked (OQ-8).

## 3. Outcome classes and the meaning of "successfully handled"

| Class | Detected by | Gap? |
|---|---|---|
| `INVALID` | V_ttir rejects the case | no |
| `EXPECTED_REJECTION` | the failure is documented at the commit: a negative lit test, or a pattern's match-failure reason that a test exercises | no, but reported |
| `LOWERED` | see the definition below | no |
| `CONVERSION_FAILED` | the driver reports a legalization failure | yes |
| `OUTPUT_INVALID` | conversion completes but the output does not verify (O3 is the recorded example) | yes |
| `CRASH` | signal, assertion or LLVM fatal error | yes |
| `TIMEOUT` | wall-clock limit exceeded | yes |

**Open (OQ-12):** **[H]** a rank-5 `ttir.prod` should convert and then fail `ttnn.prod`'s verifier
(`TTNNOps.cpp:6026-6031,6085-6087`), and `negative_reduce_prod_op.mlir:1-7` documents that diagnostic.
It is therefore both "output does not verify" and "documented". This table does not say which class
wins, and the choice must be made before predictions are frozen.

Candidate definitions of "successfully handled":

- **S0**: the pass returns success.
- **S1**: S0, and the output module verifies.
- **S2**: S1, and no source-dialect op remains except those the conversion target declares legal.
- **S3**: S2, and a further downstream pipeline also succeeds.

**S2 is the accepted definition (D-003).**

- **[F]** `convert-ttir-to-ttnn` runs `applyFullConversion` with TTIR illegal (`TTIRToTTNNPass.cpp:47,71-72`).
  For that pass, S0 already implies the legality part of S2.
- **[F]** The decomposition pass that the pipeline runs first uses `applyPartialConversion`
  (`TTIRToTTIRDecompositionPass.cpp:216`), so the legality check matters when reading its stage alone.
- S1 is necessary: O3 is the recorded case where S0 held in-process but the output was invalid. **[H]**
  An in-process adapter must call the verifier explicitly here too.
- S3 is rejected because it tests other passes.

The failing stage (parse and verify, named conversion, conversion, verification) is always recorded.

## 4. Pattern states

| State | Meaning | Observable at the commit via |
|---|---|---|
| registered | in the pattern set | **[H]** adapter dumps pattern debug names; `populateTTIRToTTNNPatterns` is at `TTIRToTTNN.cpp:3800-3963` |
| considered | the driver selected it for an op | **[F]** listener `notifyPatternBegin` (`DialectConversion.cpp:2719`) |
| attempted | `matchAndRewrite` invoked | **[F]** listener begin. **[H]** action log, not re-read at this LLVM |
| match failed | returned failure, optionally with a reason | **[F]** listener `notifyPatternEnd(failure)` (`DialectConversion.cpp:2758`). `TTIRToTTNN.cpp:259-261` is one such reason |
| applied | returned success | **[F]** listener `notifyPatternEnd(success)` (`DialectConversion.cpp:2792`) |
| survived | applied and not rolled back | **[H]** begin/end nesting plus final IR. **[F]** Rollback defaults on (`DialectConversion.h:1417`) |
| not observed | registered, never applied on any tested case | analysis over results |
| unreachable in D | proven never to apply on any valid case of D | **only** via Corollary 2 of [rank-bound](../theory/rank-bound.md), with obligations discharged |

**[H]** Assertions are on in the project's LLVM configuration (`env/CMakeLists.txt:68`), so `-debug-only`
may be available, unlike the Homebrew build. Nothing here depends on that yet.

## 5. First target (accepted, D-012)

**TTIR→TTNN in tt-mlir at `f9dc1b3e5101`.** Tool: `ttmlir-opt`.

**[F] Why it is not runnable here today:** the limit stays in force (D-015), and tt-mlir needs its own
LLVM source build (`env/CMakeLists.txt:5,64-74`). It is 33,634 commits behind `llvmorg-23.1.1`, so Homebrew's
LLVM does not stand in for it. Comparison of the candidates, with costs, is in
[brief-oq9](../decisions/brief-oq9.md), a dated record.

**[F] What is known about running it:**

| Item | Fact |
|---|---|
| Platform | Offline compiler is supported on macOS, runtime is not (`docs/src/getting-started.md:15,123-127`). |
| Compiler | Docs ask for `Clang >= 14 & <= 18` (`getting-started.md:18`); Apple clang 21.0.0 and Homebrew 23.1.1 are numerically outside it. **[H]** Effect unknown until a build runs. |
| Target definition | `TTIRToTTNNPass.cpp:41-60`, with an identity type converter (`:62-64`). |
| Patterns | Public `populateTTIRToTTNNPatterns` (`TTIRToTTNN.h:13`). |

**Modes are not decided (OQ-11).** **[F]** Candidates:

- bare: `--convert-ttir-to-ttnn` (`Passes.td:158`), which lit prefixes with `--ttcore-register-device --ttnn-layout`
  (`avg_pool2d_negative_tests.mlir:1`);
- pipeline: `--ttir-to-ttnn-runtime-pipeline` (`TTNNPipelines.cpp:874`). The name `--ttir-to-ttnn-backend-pipeline`
  is marked deprecated and calls the same function (`:883-885`), and is what lit uses.

## 6. Domain (accepted, D-013)

Called **D0-tt** below. Representative op: `ttir.prod`
(`ReductionProdOpConversionPattern`, `TTIRToTTNN.cpp:243-280`). Control op: `ttir.sum`
(`ReductionOpConversionPattern`, `:226-239`).

| Parameter | Values | Notes |
|---|---|---|
| rank r | 1, 2, … | **[F]** no rank cap in V_ttir. Rank 0 is excluded for now, as in D-005; the exhaustive upper bound is not decided |
| dim letter at each position | `1`, `s` (static > 1), `?` (dynamic) | representatives for `s`: 2, plus 3 and 7, as before. **[H]** whether `?` survives the pipeline is unknown; no `ttir.prod` lit test uses it |
| dim marks | a set of reduced positions, or `dim_arg` absent (all) | **[F]** `I32ArrayAttr`, optional (`TTIROps.td:2744`). **[H]** an empty list is out until decided |
| `keep_dim` | true, false | **[F]** determines the result shape in the verifier (`TTIROps.cpp:6724-6730`) |
| dim encoding | **open (OQ-10)** | **[F]** the verifier allows `-r ≤ d < r` (`:6708`); brief tt-A lists negative encoding; D-013 does not settle it |
| element type | f32, bf16, si32 | **[F]** all seen in `ttir.prod` or `ttir.sum` lit |

The result type follows from these: **[F]** the verifier requires exactly that shape
(`TTIROps.cpp:6723-6739`), so it adds no parameter.

Outside D0-tt, with the reason:

- unranked tensors: **[F]** rejected by the op definition (`AnyRankedTensor`, `TTIROps.td:2742`), so an `INVALID` control.
- quantized and other element types: not inspected.
- other reduce ops (`mean`, `max`, `min`): later domain.
- multi-op programs: they need a cross-op validity model.
- `ttir.batch_norm_inference`: **[F]** the source verifier caps rank at 2–5 (`TTIROps.cpp:7113`), so an all-rank claim adds nothing there.

**Enumeration size (arithmetic only, per element type, per op).** At rank r: 3^r letter words, 2 values of `keep_dim`.

| Encoding | Mark options at rank r | Cases at rank r | Ranks 1–4 | Ranks 1–6 |
|---|---|---|---|---|
| positive only | 2^r | 2·6^r | 3,108 | 111,972 |
| positive or negative per marked dim | 3^r | 2·9^r | 14,760 | 1,195,740 |

These exclude repeated-position lists such as `[d, d−r]` (§5 of [rank-bound](../theory/rank-bound.md)). **[H]** Whether either
column is small enough for one process per case is unknown: this was never timed on `ttmlir-opt`.

## 7. Research questions, in falsifiable form

- **RQ1 (coverage):** under V_ttir, which D0-tt cases are gaps? Report minimal witnesses (shortest
  rank first) or "none in D0-tt up to rank R".
- **RQ2 (reachability):** for the patterns registered at `TTIRToTTNN.cpp:3800-3963`, which apply on D0-tt?
  Every non-observed pattern is reported with the root-op conditions under which it was considered.
- **RQ3 (rank):** do the assumptions of Theorem 1 hold for `ReductionProdOpConversionPattern`'s transitive
  closure, and with what bound N? Answer yes, no with the violating construct, or open with the remaining
  obligations.
- **RQ4 (practicality):** report adapter size, cost per 1,000 cases, and the fidelity-check pass
  rate against `ttmlir-opt`.

RQ1–RQ4 need a built target. While D-015 holds, only RQ3's source-reading obligations can advance.

## 8. Record: TosaToLinalg at `llvmorg-23.1.1` (2026-11-01)

Kept as written then. D-004 and D-005 proposed this and were superseded (D-010). Citations are at
`llvmorg-23.1.1`, not the current commits.

### Target comparison, as of 2026-11-01

| Candidate | Source @ commit (date) | Output dialect | LLVM pin | Runs here today | Rank logic (grep proxy: `getRank()` lines / rank-vs-constant lines) |
|---|---|---|---|---|---|
| TosaToLinalg (upstream) | llvm-project `llvmorg-23.1.1` = `6dfe1677ab8d` | linalg, tensor, scf, arith | same | yes, Homebrew | 50 / 2. Per-dimension loops, axis-relative cases; the pipeline's validation caps rank at 6 |
| TorchToTosa | torch-mlir `56d788c4bda3` (2026-10-30) | TOSA (NPU-facing operator set) | `0223b87de6dd` | no, source build | 124 / 83. Checks rank 0, ≤1, <3, ==3, ==4 |
| TTIR→TTNN and TTIR decomposition | tt-mlir `f9dc1b3e5101` (2026-10-26) | TTNN (Tenstorrent) | `4efe170d858e` | no, source build; README lists Mac OS | 54 / 33. `rank == 4` hardware convention, `< 2`, `< 4`, `> 4` |
| VectorToAIEVec | mlir-aie `7553ce5647ff` (2026-10-31) | AIEVec (AMD AIE NPU) | `bdf04ebb32d7` | no; README lists Linux and Windows only | 37 / 33. Mostly `rank != 1`, so the rank domain is about {1}; a theorem would be degenerate |
| Intel NPU compiler | not inspected | VPU dialects | n/a | n/a | missing input |

Later corrections to this table are in [brief-oq9](../decisions/brief-oq9.md) ("Corrections to existing docs").

### Oracles and domain D0, as proposed 2026-11-01

- **V_mlir**: `mlir-opt case.mlir`, no passes.
- **V_tosa1.0**: V_mlir, plus `tosa-attach-target` and `tosa-validate`, at level `8k`, profiles
  `pro_int,pro_fp`, extension `doubleround` (`TosaToLinalgPass.cpp:105–111`, `Passes.td:167`). It rejected
  rank > 6 (`TargetEnv.h:43`, `TosaValidation.cpp:276`) and every dynamic dimension (`TosaValidation.cpp:910`).
- **D0**: one `tosa.reduce_sum` (`ReduceConverter<ReduceSumOp>`, `TosaToLinalg.cpp:2238`, helper
  `:1161–1373`), control `tosa.add` (`:767–1056`); letters {1, s, ?} with an axis mark; result letter at the
  axis in {1, ?}, elsewhere equal to the input letter; element types f32, bf16, i32.
- **Counts:** V_tosa1.0, letters {1, s}, ranks 1–6: Σ r·2^r = 642, so 1,926 for three element types.
  V_mlir, ranks 1–6: Σ 2r·3^r = 12,030 per type.

Observations O1–O8 from that target are in the [spike plan](../experiments/initial-spike.md#reconnaissance-probes-run-on-2026-11-01).
