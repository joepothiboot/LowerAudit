# Decision brief: OQ-1, D-004, D-005

Written 2026-11-04. This brief changes no decision's status. The only recommendations are the ones
the docs already make. Citations are `repo-path:line`.

Decide in this order. D-005 is defined against the D-004 target
(`docs/research/problem-statement.md:119`), and D-004 depends on the OQ-1 answer
(`docs/decisions/decision-log.md:38-40`).

## OQ-1: first target

**Question:** is a non-NPU first target (TosaToLinalg) acceptable for the spike?
(`docs/risks-and-open-questions.md:26`)

| Option | Enables | Costs |
|---|---|---|
| **Yes** | Starts the spike with no LLVM build (`docs/decisions/decision-log.md:11-12`). An NPU dialect becomes the second target (`docs/decisions/decision-log.md:39`). | Narrows the mission wording to "an NPU-facing operator set (TOSA) lowered to Linalg" (`docs/decisions/decision-log.md:38-39`). The theorem may look trivial on this target (`docs/risks-and-open-questions.md:9`). |
| **No, it must be NPU** | The first target matches the project title (`README.md:3`). | Each NPU candidate needs a source build of its own LLVM pin (`STATUS.md:39-40`), on 8 GiB of RAM (`STATUS.md:13`). A source build is out of scope for the spike as planned (`docs/experiments/initial-spike.md:109`), so the plan would need changing. The documented mitigation is to defer the NPU target and time one build first (`docs/risks-and-open-questions.md:12`). |

**Docs' position:** the recommendation under D-004 implies Yes (`docs/research/problem-statement.md:100-115`).

**Evidence that would change the answer:**

- advisor or programme input that the first target must be NPU (not yet collected);
- a timed LLVM build that fits the machine (`docs/risks-and-open-questions.md:12`).

**Blocked until answered:** all target-dependent spike work. Only theory and the reading list may
proceed (`docs/experiments/initial-spike.md:110-111`).

## D-004: which first target

**Question:** which conversion is the first target?
(`docs/decisions/decision-log.md:33`)

Rank figures are grep counts of `getRank()` lines / rank-vs-constant lines, which the docs call a
crude proxy (`docs/research/problem-statement.md:98`).

| Option | Enables | Costs | Source |
|---|---|---|---|
| **`tosa-to-linalg` + pipeline** (proposed) | Runs today, has a spec-backed oracle, real rank and position boundaries, and one gap candidate (O3). Rank figures 50 / 2. | Output is not an NPU dialect. Rank logic is shallow. | `docs/research/problem-statement.md:92,100-112` |
| TorchToTosa | Thresholds on rank 0, ≤1, <3, ==3, ==4. Rank figures 124 / 83. | Source build at its own pin. Output is TOSA, still not an NPU dialect. | `docs/research/problem-statement.md:93` |
| tt-mlir TTIR→TTNN | A real NPU dialect with a `rank == 4` convention. Rank figures 54 / 33. | Source build at its own pin. | `docs/research/problem-statement.md:94` |
| mlir-aie VectorToAIEVec | A real NPU dialect (AMD AIE). | Source build; its README lists Linux and Windows only. Mostly `rank != 1`, so a theorem would be degenerate. | `docs/research/problem-statement.md:95` |
| Intel NPU compiler | Unknown. | Not inspected, so this needs reconnaissance first. | `docs/research/problem-statement.md:96` |

**Docs' position:** `tosa-to-linalg` and the pipeline, with the second target chosen after the
spike (`docs/research/problem-statement.md:100,114-115`).

**Evidence that would change the answer:**

- OQ-1 answered No;
- spike Q5 coming back CONDITIONAL, which requires a second target but does not replace the first
  (`docs/experiments/initial-spike.md:121`);
- a needed fix landing after the pin (`docs/decisions/decision-log.md:13`).

**Blocked until accepted:** all implementation code (`CLAUDE.md:108`,
`docs/design/architecture.md:3`).

## D-005: domain D0

**Question:** which input domain does the first target get checked on?
(`docs/decisions/decision-log.md:42`)

| Option | Enables | Costs | Source |
|---|---|---|---|
| **D0: one `tosa.reduce_sum`, letters {1, s, ?}, axis mark, f32 / bf16 / i32; `tosa.add` as control; both oracles** (proposed) | Rank-indexed axis and position classes. Includes O3. Exhaustive at 1,926 cases under V_tosa1.0 and 12,030 per element type under V_mlir, ranks 1–6. | One op and no multi-op programs, so cross-op failures are missed. Unconfirmed that it runs in minutes. | `docs/research/problem-statement.md:119-130,142-145`; `docs/risks-and-open-questions.md:18` |
| Elementwise ops only | Simplest domain. | Rank-uniform, so the theorem is trivially true and too weak. | `docs/decisions/decision-log.md:47` |
| Transpose | A later negative case. | Permutations break the finite alphabet. | `docs/decisions/decision-log.md:48`; `docs/theory/rank-bound.md:143` |

**Docs' position:** D0 (`docs/decisions/decision-log.md:44-45`).

**Evidence that would change the answer:**

- H1 falsified by Exp C (`docs/experiments/initial-spike.md:66-67`);
- the closure inventory exceeding about 2k lines (`docs/experiments/initial-spike.md:107-108`);
- bf16 or i32 failing V_tosa1.0 for reasons other than rank or dynamic dims (open item 1 below),
  which would change the 1,926 count.

**Blocked until accepted:** the expected-outcome table and all implementation code
(`docs/experiments/initial-spike.md:16`, `CLAUDE.md:108`).

## Open items for this decision

Hypotheses, not verified. No probe was run for this brief, so the expected-outcome table still
predates any new results.

1. **bf16 under V_tosa1.0.** The oracle's defaults are profiles `pro_int,pro_fp` and extension
   `doubleround` (`docs/research/problem-statement.md:36-37`), which names no bf16 extension. If
   `tosa-validate` rejects bf16 `reduce_sum`, those 642 cases become `INVALID`. The V_tosa1.0 count
   of valid cases then falls to 1,284, not the 1,926 used in the docs
   (`docs/research/problem-statement.md:142`, `docs/experiments/initial-spike.md:18`).
2. **Rank 1 with a `?` result** has not been probed (`docs/theory/rank-bound.md:164`).

## Where the docs disagree

Among `STATUS.md`, `README.md` and `CLAUDE.md`:

| Topic | Disagreement |
|---|---|
| Target | `README.md:50` names only `tosa-to-linalg`. `CLAUDE.md:37-38` also names `tosa-to-linalg-pipeline`. |
| What blocks work | `STATUS.md:4,66,70` and `CLAUDE.md:91` list only OQ-1. `CLAUDE.md:108` also requires D-004 and D-005 to be accepted before code. |

Found in other docs while checking:

| Topic | Disagreement |
|---|---|
| H1's location | `docs/theory/rank-bound.md:54` points to §6, but H1 is in §5 (`docs/theory/rank-bound.md:149`, `STATUS.md:48`). |
| Lit-test ranks | `README.md:14` says the reduce tests use "ranks 1–3 only". `docs/research/problem-statement.md:11` and `docs/experiments/initial-spike.md:148` add one unranked case. |
| Time budget | ~10 h/week (`docs/risks-and-open-questions.md:12,19`) vs. about 12 hours over 8 days (`docs/experiments/initial-spike.md:8`). Both are assumptions. |
