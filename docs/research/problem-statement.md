# Problem statement

Status: **draft, 2026-11-01**. The target and domain below are *proposed* (D-004, D-005 in the
[decision log](../decisions/decision-log.md)) and need the user's acceptance before the spike.

## 1. Problem

An MLIR lowering is a set of C++ rewrite patterns run by the dialect-conversion driver. Which
inputs a lowering actually handles is spread across pattern guards, helper functions, type
converters, and the builders and verifiers of the ops the patterns create. Lit tests sample a few
shapes. At the pin, the TosaToLinalg reduce tests use input ranks 1–3 and one unranked case only.

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
| Validity oracle | Decides whether a case belongs to D. Every result names its oracle (below). |
| Outcome | The class C's run falls into (§3), plus the set of patterns applied. |
| Gap | A valid case whose outcome is `CONVERSION_FAILED`, `OUTPUT_INVALID`, `CRASH` or `TIMEOUT`. |

Two validity oracles are used. A case's verdict can depend on which one is chosen (observation O3
in the [spike plan](../experiments/initial-spike.md#reconnaissance-probes-run-on-2026-11-01)):

- **V_mlir**: the MLIR parser and op verifiers accept the case (`mlir-opt case.mlir`, no passes).
- **V_tosa1.0**: V_mlir, plus `tosa-attach-target` and `tosa-validate` accept it. Use the
  defaults the pipeline itself uses: level `8k`, profiles `pro_int,pro_fp`, extension `doubleround`
  (`TosaToLinalgPass.cpp:105–111`, `Passes.td:167`). At the pin this rejects rank > 6
  (`TargetEnv.h:43`, `TosaValidation.cpp:276`) and every dynamic dimension (`TosaValidation.cpp:910`).

## 3. Outcome classes and the meaning of "successfully handled"

| Class | Detected by | Gap? |
|---|---|---|
| `INVALID` | the chosen validity oracle rejects the case | no |
| `EXPECTED_REJECTION` | conversion fails, and the failure is documented at the pin (a `*-invalid.mlir` lit test, or a pattern's match-failure reason that a test exercises, e.g. "unranked tensors not supported", `TosaToLinalg.cpp:1168`) | no, but reported |
| `LOWERED` | see the definition below | no |
| `CONVERSION_FAILED` | the driver reports a legalization failure | yes |
| `OUTPUT_INVALID` | conversion completes but the output does not verify (O3) | yes |
| `CRASH` | signal, assertion or LLVM fatal error | yes |
| `TIMEOUT` | wall-clock limit exceeded | yes |

Candidate definitions of "successfully handled":

- **S0**: the pass returns success.
- **S1**: S0, and the output module verifies.
- **S2**: S1, and no source-dialect op remains except those the conversion target declares legal.
- **S3**: S2, and a further downstream pipeline also succeeds.

**Recommendation: S2.**

- `tosa-to-linalg` runs `applyFullConversion` with the TOSA dialect illegal except nine ops
  (`TosaToLinalgPass.cpp:50–72`). For it, S0 already implies the legality part of S2. The extra
  check is cheap and protects partial conversions added later.
- S1 is necessary. O3 is a case where S0 holds in-process but the output is invalid. On the CLI,
  `mlir-opt` verifies after every pass by default, so S0 and S1 coincide there. An in-process
  adapter must call the verifier explicitly.
- S3 is rejected because it tests other passes.

The failing stage (validation, named conversion, conversion, verification) is always recorded.

## 4. Pattern states

| State | Meaning | Observable at the pin via |
|---|---|---|
| registered | in the pattern set | adapter dumps pattern debug names; default names are C++ type names (O4) |
| considered | the driver selected it for an op (root-name match, recursion guard passed) | listener `notifyPatternBegin` (`DialectConversion.cpp:2760`) |
| attempted | `matchAndRewrite` invoked | listener begin; action log `apply-pattern` (`PatternApplicator.h:30–40`) |
| match failed | returned failure, optionally with a reason | listener `notifyPatternEnd(failure)` (`DialectConversion.cpp:2799`), `notifyMatchFailure` |
| applied | returned success | listener `notifyPatternEnd(success)` (`DialectConversion.cpp:2830`) |
| survived | applied and not rolled back | begin/end nesting plus final IR; rollback is on by default (`DialectConversion.h:1463`) |
| not observed | registered, never applied on any tested case | analysis over results |
| unreachable in D | proven never to apply on any valid case of D | **only** via Corollary 2 of [rank-bound](../theory/rank-bound.md), with obligations discharged |

The action log (`--log-actions-to`) works in the release build but records attempts only, never
the result (O4). Success requires the listener, which requires a C++ adapter
([architecture](../design/architecture.md)).

## 5. First target (proposed, D-004)

| Candidate | Source @ commit (date) | Output dialect | LLVM pin | Runs here today | Rank logic (grep proxy: `getRank()` lines / rank-vs-constant lines) |
|---|---|---|---|---|---|
| **TosaToLinalg** (upstream) | llvm-project `llvmorg-23.1.1` = `6dfe1677ab8d` | linalg, tensor, scf, arith | same | **yes**, Homebrew | 50 / 2. Per-dimension loops, axis-relative cases; the pipeline's validation caps rank at 6 |
| TorchToTosa | torch-mlir `56d788c4bda3` (2026-10-30) | TOSA (NPU-facing operator set) | `0223b87de6dd` | no, source build | 124 / 83. Checks rank 0, ≤1, <3, ==3, ==4 |
| TTIR→TTNN and TTIR decomposition | tt-mlir `f9dc1b3e5101` (2026-10-26) | TTNN (Tenstorrent) | `4efe170d858e` | no, source build; README lists Mac OS | 54 / 33. `rank == 4` hardware convention, `< 2`, `< 4`, `> 4` |
| VectorToAIEVec | mlir-aie `7553ce5647ff` (2026-10-31) | AIEVec (AMD AIE NPU) | `bdf04ebb32d7` | no; README lists Linux and Windows only | 37 / 33. Mostly `rank != 1`, so the rank domain is about {1}; a theorem would be degenerate |
| Intel NPU compiler | not inspected | VPU dialects | n/a | n/a | missing input |

The grep counts are a crude proxy: they count lines, not semantics.

**Recommendation:** `tosa-to-linalg` (bare pass) and `tosa-to-linalg-pipeline` at the pin, for
these reasons:

- It costs nothing to build.
- TOSA gives a spec-backed validity oracle.
- It has real rank and position boundaries: MAX_RANK and the axis cases.
- It already produced one untriaged gap candidate (O3).

Costs of this choice:

1. Its output is Linalg, not an NPU dialect. That narrows the mission wording and needs the
   user's acceptance (OQ-1).
2. Its rank logic is shallow, so the theorem may hold with a tiny bound and look trivial (risk R1).

Choose an NPU-dialect second target (tt-mlir or TorchToTosa) after the spike, using the spike's
build-time and inventory data.

## 6. Domain D0 (proposed, D-005)

Representative op: `tosa.reduce_sum` (`ReduceConverter<ReduceSumOp>`, `TosaToLinalg.cpp:2238`,
helper `:1161–1373`). Control op: `tosa.add`, whose lowering is uniform across dimensions
(`TosaToLinalg.cpp:767–1056`).

| Parameter | Values | Notes |
|---|---|---|
| rank r | 1, 2, … (unbounded under V_mlir; ≤ 6 under V_tosa1.0) | the input and result have the same rank |
| axis | 0 … r−1 | rank-indexed attribute, encoded as a mark on one position |
| input dim letter at each position | `1`, `s` (static > 1), `?` (dynamic) | representatives for `s`: 2, plus 3 and 7 to check abstraction soundness (A2) |
| result dim letter at the axis | `1`, `?` | `?` is accepted by V_mlir and triggers O3 |
| result dim letter elsewhere | equal to the input letter | widening this needs a decision entry |
| element type | f32, bf16, i32 | bf16 takes the widened-accumulator path (`TosaToLinalg.cpp:1174–1177`) |

Inside D0: the cases above under each oracle. Outside D0, with the reason:

- unranked tensors: an `EXPECTED_REJECTION` control.
- quantized and unsigned types: separate type-conversion logic, not yet inspected.
- other reduce ops: D1, after D0.
- multi-op programs: they need a cross-op validity model.
- fixed-rank named ops such as conv2d: a single-rank domain, so no rank question arises.

Enumeration size, abstract cases per element type:

- V_tosa1.0, letters {1, s}, ranks 1–6: Σ r·2^r = 642, so 1,926 for three element types.
- V_mlir, letters {1, s, ?} with the result axis in {1, ?}, ranks 1–6: Σ 2r·3^r = 12,030 per type.

Both are small enough to run exhaustively in minutes. That needs confirming in Exp A.

## 7. Research questions, in falsifiable form

- **RQ1 (coverage):** under each oracle, which D0 cases are gaps? Report minimal witnesses
  (shortest rank first) or "none in D0 up to rank R".
- **RQ2 (reachability):** for the patterns registered at `TosaToLinalg.cpp:3031–3101`, which apply
  on D0 and D1? Every non-observed pattern is reported with the root-op conditions under which it
  was considered.
- **RQ3 (rank):** do the assumptions of Theorem 1 hold for `ReduceConverter`'s transitive closure,
  and with what bound N? Answer yes, no with the violating construct, or open with the remaining
  obligations.
- **RQ4 (practicality):** report adapter size, cost per 1,000 cases, and the fidelity-check pass
  rate against `mlir-opt`.
