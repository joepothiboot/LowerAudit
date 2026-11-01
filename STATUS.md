# Status: 2026-11-01

**Stage:** reconnaissance complete. Spike not started. No tool code.
**Blocked on:** OQ-1 ([open questions](docs/risks-and-open-questions.md)).

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

- **OQ-1:** whether a non-NPU first target is acceptable.

## Next actions

1. The user answers OQ-1.
2. Read the full texts listed in [novelty audit §4](docs/research/novelty-audit.md).
3. Search the upstream tracker for O3 (OQ-3).
4. Read `inferExpandShapeOutputShape` (OQ-4).
5. Run the [spike](docs/experiments/initial-spike.md).
