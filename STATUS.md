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

**Target, read from source on 2026-11-04 (nothing run)**

At tt-mlir `f9dc1b3e5101` and LLVM `4efe170d858e`; citations are in the
[problem statement](docs/research/problem-statement.md) and [rank-bound](docs/theory/rank-bound.md).

- `convert-ttir-to-ttnn` is a full conversion with a public populate function, and the listener API is
  present at this LLVM.
- V_ttir has no rank cap for `ttir.prod`, but `ttnn.prod`'s verifier rejects rank > 4, and a negative
  lit test documents that at rank 5.
- The `ttir.prod` pattern fails to match a partial mark set. The decomposition pass splits such a set
  into a chain, and it is what the pipeline runs first.
- The target needs its own LLVM source build; this machine's compilers are numerically outside its
  documented clang range.

**Record: MLIR at `llvmorg-23.1.1` (TosaToLinalg, verified 2026-11-01)**

- `tosa-to-linalg` runs `applyFullConversion`. TOSA is illegal except for nine ops, and unknown
  ops are legal (`TosaToLinalgPass.cpp:50–72`).
- The pipeline validates by default (`:132`). The attached level defaults to `8k`
  (`Passes.td:167`). MAX_RANK is 6 at `8k` and 32 at `none` (`TargetEnv.h:43,45`).
- Pattern success is observable through `RewriterBase::Listener::notifyPatternBegin/End`
  (`PatternMatch.h:407,414`), called by the conversion driver (`DialectConversion.cpp:2760,2799,2830`).
- The action log records attempts only (`PatternApplicator.h:30–40`).

**Record: probes O1–O8, on TosaToLinalg** ([spike plan](docs/experiments/initial-spike.md#reconnaissance-probes-run-on-2026-11-01))

- The pipeline rejects rank ≥ 7 and every dynamic dimension.
- The bare pass lowered static `reduce_sum` at ranks 1–8.
- O3 is an untriaged candidate gap: an invalid `tensor.expand_shape`, valid under V_mlir only.

**Candidates and literature**

- NPU candidates were read at pinned commits and compared in
  [brief-oq9](docs/decisions/brief-oq9.md). Each pins a different LLVM, so it needs a source build.
- 16 papers, preprints and reports, plus two software artifacts (GlobalISel rule coverage and the
  MLIR conversion hooks), are verified at bibliographic or abstract level
  ([novelty audit](docs/research/novelty-audit.md)).
  ACT proves completeness for *generated* backends, relative to its rewrite axioms.

## Provisional hypotheses (not verified)

- **H3:** tt-mlir contains enough threshold logic to make Theorem 1 non-trivial. Not settled: `ttir.sum`'s
  pattern is rank-free, and `ttir.prod`'s one threshold found so far is a documented rejection.
- **H4:** no published work combines exhaustive, oracle-judged coverage of real MLIR conversions
  with a rank cutoff.
- **H6:** `ttir.prod`'s outcome depends only on element type, whether r > 4, the mark summary, `keep_dim`,
  possibly `?`, and the mode ([rank-bound §5](docs/theory/rank-bound.md)).
- **H7:** `ttir.sum`'s outcome on the bare pass does not depend on rank.

Parked with TosaToLinalg, never tested ([rank-bound §7](docs/theory/rank-bound.md)):

- **H1:** `ReduceConverter`'s outcome depends only on element type, whether r = 1, and the
  {axis, partner} letters.
- **H2:** `PointwiseConverter`'s outcome does not depend on rank.
- **H5:** O3 is a defect rather than intended behaviour.

## Completed investigations

- Workspace and toolchain inventory.
- Partial rank-dependency inventory of TosaToLinalg.
- Comparison of target candidates.
- Literature reconnaissance.
- Eight CLI probes.

## Unresolved blockers

- **Source-build limit:** in force with no end date (D-015; [spike plan](docs/experiments/initial-spike.md)
  assumptions and §3). No `ttmlir-opt` exists here, so the conversion and V_ttir cannot execute.
- **Rule 12:** the target and domain are accepted, but the vertical slice in
  [architecture §3](docs/design/architecture.md) is still proposed, so implementation code waits.
- **OQ-10, OQ-11, OQ-12:** dim encoding, mode commands and the class of the rank-5 rejection. These block
  the expected outcomes.

If a first-target build is ever allowed and fails on this machine: stop and report a negative result
(D-011).

## Next actions

1. The user answers OQ-10, OQ-11 and OQ-12, and accepts or changes the vertical slice.
2. Write the expected outcomes, before any run.
3. The user decides whether and when to lift the build limit. The spike's experiments cannot run until
   then, and its GO table's row 1 has no evidence (see the [spike plan](docs/experiments/initial-spike.md) §4).
4. Read the full texts listed in [novelty audit §4](docs/research/novelty-audit.md).
5. Ask the advisor whether a verifier-only oracle is acceptable (D-014, OQ-8).

Parked with TosaToLinalg, kept as a record: searching the upstream tracker for O3 (OQ-3) and reading
`inferExpandShapeOutputShape` (OQ-4).
