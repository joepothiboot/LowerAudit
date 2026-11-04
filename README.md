# LowerAudit

**NPU Lowering Coverage: Rank-Bounded Coverage Analysis of Real MLIR Lowering Pipelines**

> **Status:** research planning; no tool code yet. Every claim of novelty or feasibility below is
> provisional until the 8–15 November 2026 spike ([plan](docs/experiments/initial-spike.md)).
> Current facts are in [STATUS.md](STATUS.md).

## Problem

An MLIR lowering is a set of C++ rewrite patterns run by the dialect-conversion driver. Which
inputs it actually handles is spread across pattern guards, helper functions, type converters,
and the builders and verifiers of the ops it creates. Lit tests sample a few shapes: at
LLVM 23.1.1, the TosaToLinalg reduce tests use ranks 1–3 only.

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
- Proposed first target: upstream `tosa-to-linalg` at `llvmorg-23.1.1`. It runs from Homebrew
  with no LLVM build and has a spec-backed validity oracle. Its output is Linalg, not an NPU
  dialect; an NPU-dialect second target will be chosen after the spike.
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

    adapter/                          C++ listener adapter, built against the pinned MLIR
    results/<date>-<target>-<what>/   one folder per run: inputs, commands, outputs
