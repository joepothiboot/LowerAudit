# LowerAudit

**NPU Lowering Coverage: Rank-Bounded Coverage Analysis of Real MLIR Lowering Pipelines**

> **Status:** research planning; a build skeleton but no tool logic yet. Every claim of novelty or
> feasibility below is provisional until the spike ([plan](docs/experiments/initial-spike.md)).
> Current facts are in [STATUS.md](STATUS.md).

## Problem

An MLIR lowering is a set of C++ rewrite patterns run by the dialect-conversion driver. Which
inputs it actually handles is spread across pattern guards, helper functions, type converters,
and the builders and verifiers of the ops it creates. Lit tests sample a few shapes: in tt-mlir at
`f9dc1b3e5101`, the TTNN `ttir.prod` reduction tests use ranks 1, 3 and 4, plus one negative test at rank 5.

For a declared input domain, two questions follow:

- **Coverage:** is every valid case lowered?
- **Reachability:** which registered patterns ever apply, and which are never observed?

Tensor rank makes the domain infinite. Passing at ranks 1–6 says nothing about rank 7 unless
something about the code guarantees it.

## Proposed contribution (provisional)

1. A checker that enumerates a declared domain exhaustively within bounds, runs the **real**
   conversion, and classifies each case against an explicit validity oracle, spec-backed where
   possible.
2. Pattern-reachability reports built from the driver's own listener events. They separate
   attempted, applied, rolled-back and never-observed patterns.
3. A **sufficient-rank theorem**. If the conversion's rank-dependent behaviour is finite-state over
   a per-dimension abstraction, with proof obligations checked against the source, then checking
   every rank below a computable bound establishes coverage at every rank. It also proves
   unreachability for every rank.

Already known, and not claimed here:

- completeness checks for formal instruction-selector specifications;
- sufficient completeness of rewrite systems;
- rule-coverage counters in production compilers;
- complete backends generated from ISA specifications;
- cutoff theorems in parameterized verification.

See the [novelty audit](docs/research/novelty-audit.md). The candidate contribution is the
combination, applied to real MLIR conversions.

## Current stage

- Workspace, toolchain and literature reconnaissance were done on 2026-11-01.
- First target, accepted: TTIR→TTNN in tt-mlir at `f9dc1b3e5101`, an NPU dialect, on `ttir.prod` with
  `ttir.sum` as the control. Its validity oracle is the TTIR verifiers; no spec backs it.
- It needs an LLVM and project source build, and a source-build limit is in force, so **nothing has been
  run on this target**. What is written about it comes from reading its source.
- An earlier proposed target, upstream `tosa-to-linalg`, was rejected as an NPU first target. Its eight
  probes and inventory are kept as a dated record.
- Topic freeze is 15 Nov 2026. The project decision is 30 Nov 2026.

## Repository layout

Present now:

    CLAUDE.md           project rules for AI sessions
    STATUS.md           facts, hypotheses, blockers, next actions
    docs/research/      problem statement, novelty audit
    docs/theory/        rank-bound theorem and proof status
    docs/design/        architecture and the Haskell/MLIR boundary
    docs/experiments/   spike plan, experiment specs, reconnaissance probes
    docs/decisions/     decision log
    docs/risks-and-open-questions.md
    docs/LEARNING-LOG.md  quiz results
    docs/TODO-l0.md       setup decisions and dependency reasons
    lower-audit.cabal     the one cabal package
    cabal.project         compiler pin
    Makefile              build, test, check
    src/, app/, test/     Haskell library, executable and tests (skeleton only)

Planned (created when first needed, not before):

    adapter/                          C++ listener adapter, built against the target's tree
    results/<date>-<target>-<what>/   one folder per run: inputs, commands, outputs
