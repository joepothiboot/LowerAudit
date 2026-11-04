# Status: 2026-11-04

**Stage:** reconnaissance complete. Spike not started. Cabal skeleton only; no tool logic.
**First target:** tt-mlir TTIR→TTNN at `f9dc1b3e5101`, on `ttir.prod`, oracle V_ttir (D-012 to D-014).
**Blocked on:** the source-build limit (D-015): the target cannot be built or run here.

## Confirmed facts (verified 2026-11-01)

**Workspace and tools**

- Before this session the repo held only `CLAUDE.md` (commit `1239d24`).
- Haskell: GHC 9.10.3, cabal 3.16.1.0, stack 3.11.1 (ghcup).
- Build tools: CMake 4.4.3, Ninja 1.13.2, Apple clang 21.0.0.
- Machine: macOS 27.0.1 arm64, 8 cores, 8 GiB RAM, about 157 GiB free.
- Homebrew LLVM 23.1.1 is `llvmorg-23.1.1` (`6dfe1677ab8d`), a Release build with assertions off,
  so `-debug-only` is unavailable.
- `mlir-opt` lives in `/opt/homebrew/opt/llvm/bin` and is not on PATH. It has the TOSA passes,
  `--log-actions-to` and `--mlir-debug-counter`. The MLIR CMake package and
  `libMLIRTosaToLinalg.a` are installed.

**MLIR at the pin**

- `tosa-to-linalg` runs `applyFullConversion`. TOSA is illegal except for nine ops, and unknown
  ops are legal (`TosaToLinalgPass.cpp:50–72`).
- The pipeline validates by default (`:132`). The attached level defaults to `8k`
  (`Passes.td:167`). MAX_RANK is 6 at `8k` and 32 at `none` (`TargetEnv.h:43,45`).
- Pattern success is observable through `RewriterBase::Listener::notifyPatternBegin/End`
  (`PatternMatch.h:407,414`), called by the conversion driver (`DialectConversion.cpp:2760,2799,2830`).
- The action log records attempts only (`PatternApplicator.h:30–40`).

**Probes O1–O8** ([spike plan](docs/experiments/initial-spike.md#reconnaissance-probes-run-on-2026-11-01))

- The pipeline rejects rank ≥ 7 and every dynamic dimension.
- The bare pass lowered static `reduce_sum` at ranks 1–8.
- O3 is an untriaged candidate gap: an invalid `tensor.expand_shape`, valid under V_mlir only.

**Candidates and literature**

- Candidate repos were inspected at their HEADs; commits are in
  [problem statement §5](docs/research/problem-statement.md). Each NPU candidate pins a different
  LLVM, so it needs a source build.
- 16 papers, preprints and reports, plus two software artifacts (GlobalISel rule coverage and the
  MLIR conversion hooks), are verified at bibliographic or abstract level
  ([novelty audit](docs/research/novelty-audit.md)).
  ACT proves completeness for *generated* backends, relative to its rewrite axioms.

## Provisional hypotheses (not verified)

- **H1:** `ReduceConverter`'s outcome depends only on element type, whether r = 1, and the
  {axis, partner} letters ([rank-bound §5](docs/theory/rank-bound.md)).
- **H2:** `PointwiseConverter`'s outcome does not depend on rank.
- **H3:** tt-mlir and TorchToTosa contain enough threshold logic to make Theorem 1 non-trivial.
- **H4:** no published work combines exhaustive, oracle-judged coverage of real MLIR conversions
  with a rank cutoff.
- **H5:** O3 is a defect rather than intended behaviour.

## Completed investigations

- Workspace and toolchain inventory.
- Partial rank-dependency inventory of TosaToLinalg.
- Comparison of target candidates.
- Literature reconnaissance.
- Eight CLI probes.

## Unresolved blockers

- **Source-build limit:** in force with no end date ([spike plan](docs/experiments/initial-spike.md)
  lines 9 and 109; D-015). No `ttmlir-opt` exists here, so the conversion and V_ttir cannot execute.
- **Rule 12:** the target and domain are accepted, but the minimal vertical slice still describes
  TosaToLinalg, so implementation code waits for the rework below.

If a first-target build is ever allowed and fails on this machine: stop and report a negative result
(D-011).

## Next actions

1. Do the rework listed in [D-015](docs/decisions/decision-log.md).
2. The user decides whether and when to lift the build limit; the spike cannot run on this target
   until then.
3. Read the full texts listed in [novelty audit §4](docs/research/novelty-audit.md).
4. Ask the advisor whether a verifier-only oracle is acceptable (D-014, OQ-8).

Parked with TosaToLinalg, kept as a record: searching the upstream tracker for O3 (OQ-3) and reading
`inferExpandShapeOutputShape` (OQ-4).
