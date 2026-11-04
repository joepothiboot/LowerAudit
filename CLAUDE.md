# LowerAudit: project memory

*NPU Lowering Coverage: Rank-Bounded Coverage Analysis of Real MLIR Lowering Pipelines.*
Research candidate E (#2), the intended flagship master's direction.

**Stage:** reconnaissance done (2026-11-01). Spike runs 8–15 Nov 2026. Topic freeze 15 Nov;
project decision 30 Nov.

Read [STATUS.md](STATUS.md) first. This file holds only stable rules and pointers; detail lives in `docs/`.

## Mission

Treat an existing MLIR conversion as an executable system, not as rules to re-implement:

- enumerate the valid source-op cases in a declared domain;
- run the real conversion on them;
- record which cases lower and which registered patterns fire.

Under explicit assumptions about how the conversion depends on tensor rank, find a bound such that
checking the ranks below it establishes the result for all ranks. The project is not authorized
to assume that this theorem exists, or that a target satisfies it.

## Research questions

1. **Coverage:** does the real conversion lower every valid case in the declared domain D?
2. **Reachability:** which registered patterns are observed to apply, which never are, and under
   what conditions?
3. **Rank generalization:** under which source-level conditions does a finite rank check imply the
   result for all ranks? Does the target meet them?
4. **Practicality:** can 1–3 be run against unmodified MLIR conversions with a thin adapter?

## Current scope (provisional; see the decision log)

- **Pin:** Homebrew LLVM 23.1.1 = `llvmorg-23.1.1`, `6dfe1677ab8d`. Tools are in
  `/opt/homebrew/opt/llvm/bin`, not on PATH. It is a Release build with assertions off, so there is
  no `-debug-only`; `--log-actions-to` works.
- **Proposed first target** (D-004, awaiting the user): `tosa-to-linalg` and
  `tosa-to-linalg-pipeline` at the pin. Its output is Linalg, **not an NPU dialect**.
- **Proposed domain D0** (D-005): a single `tosa.reduce_sum`, with `tosa.add` as the
  rank-uniform control. See the [problem statement](docs/research/problem-statement.md).
- **Out of scope:** multi-op programs; semantic correctness of the output; NXP Neutron (Idea M,
  a separate candidate).
- **Provisional novelty claim:** a checker for every case in a declared domain, with
  never-fired-pattern reporting, applied to real MLIR conversions. Execution is black-box; the
  rank obligations are discharged against the source (D-006). A sufficient-rank theorem extends
  finite-rank checks to all ranks under stated conditions.

## Architecture preferences

- Haskell (GHC 9.10.3, cabal 3.16) drives everything: domain, enumeration, classification, rank
  analysis, reports. Keep these modules independently testable.
- MLIR remains the execution authority. The boundary is processes and files: `.mlir` in, JSON
  lines out. No FFI.
- C++ is used only for a small adapter that attaches `RewriterBase::Listener`. Its output must
  match `mlir-opt`'s byte for byte (the fidelity check).
  See [architecture](docs/design/architecture.md).

## Distinctions that must not blur

- **Coverage is not reachability.** A pattern can fire on every case and coverage can still fail
  (O3).
- **Pattern states:** registered → attempted → match failed or applied → survived or rolled back
  → *not observed* on the tested set. "Unreachable in D" is only allowed via Corollary 2 of the
  rank theorem, with its obligations discharged.
- **Four rank propositions:** same branch, same outcome, same pattern set, same coverage verdict
  ([rank-bound](docs/theory/rank-bound.md)).
- **The validity oracle is declared per result** (V_mlir or V_tosa1.0). A verdict can flip with
  the oracle (O3).
- **Pass vs. pipeline:** the default pipeline validates first (rank ≤ 6, static shapes only); the
  bare pass does not.
- **A failure is not automatically a gap:** classify it as invalid, documented rejection, or gap,
  then triage gaps against the spec.

## Prior-work pointers

| Line of work | Works |
|---|---|
| Instruction-selector completeness | Emmelmann CC'92; Brandner ASAP'10 |
| Sufficient completeness | Maude SCC; Rocha & Meseguer LPAR'10 |
| Exhaustiveness and useless clauses | Maranget JFP'07 |
| Generated complete backends | ACT, OOPSLA'26 |
| Rule coverage in a production compiler | LLVM GlobalISel `CodeGenCoverage` |
| Cutoffs and counter abstraction | Emerson & Kahlon CADE'00; Pnueli, Xu & Zuck CAV'02 |
| Complete test suites under a state bound | Chow TSE'78 |

The matrix, verdict and links are in the [novelty audit](docs/research/novelty-audit.md).

## Unknowns that gate work

The full list is in [risks and open questions](docs/risks-and-open-questions.md). Gating now:
OQ-1 (whether a non-NPU first target is acceptable).

## Operating rules for AI sessions

1. Read `CLAUDE.md` and `STATUS.md` before proposing project work.
2. Inspect relevant source code before making claims about implementation behaviour. Cite it at
   the pin as `file:line`.
3. Never claim a pattern is unreachable merely because it did not fire in a finite test.
4. Never claim all-rank completeness based only on empirical finite-rank tests.
5. Cite primary sources for research claims. Mark preprints and technical reports as such.
6. Keep verified facts separate from hypotheses and assumptions, and label each.
7. Prefer small, runnable experiments over speculative architecture.
8. Do not broaden the declared input domain without recording the decision.
9. Record theorem assumptions and proof status explicitly in `docs/theory/rank-bound.md`.
10. Do not silently change the project's research question or novelty claim.
11. When new evidence contradicts the current framing, update the relevant files and explain the
    change in the decision log.
12. Do not write implementation code until the initial target, the domain and the minimal vertical
    slice are sufficiently understood and accepted (D-004, D-005).

Also:

- Preserve negative results and counterexamples.
- Do not call the project novel before the audit's "not yet checked" list is done.
- Keep these docs self-contained: do not cite or depend on other local repositories.
- Keep project memory in this repo, not in global AI memory.

## Modes for coding sessions

Every coding prompt begins with `Mode: BUILD | STUB | REVIEW | QUIZ`. "You" is the AI session; "the
user" writes the Haskell and C++ in STUB and REVIEW work. The operating rules above win over this
section.

- **BUILD:** you write it. Prompts that run experiments are BUILD and never edit `src/` or
  `adapter/`.
- **STUB:** you write only types, signatures with bodies `error "TODO: <function>"` (C++: a body
  that reports "TODO: <function>" and fails), tests, and `docs/TODO-<phase>.md`. No implementation,
  not even a hint. The project must build, and new tests fail only on the TODOs. The TODO file lists
  the functions in the order to implement them, with one `## Spec: <function>` entry each
  (signature, behaviour, edge and error cases, which tests check it). Anything the tests do not pin
  down goes under "Open questions".
- **REVIEW:** the user wrote it. Run the tests, read `git diff`, and coach with the hint ladder.
  Never rewrite the user's code unless they type `show solution`.
- **QUIZ:** 5 multiple-choice questions (A–D), one at a time; grade each, explain why each
  distractor is wrong. At least 3 on purpose and design trade-offs. Append to
  [docs/LEARNING-LOG.md](docs/LEARNING-LOG.md).
- **Hint ladder:** (1) a question, (2) a pointer to the exact doc page (GHC User's Guide, Hackage,
  MLIR docs or a header at the pin), (3) a skeleton with holes, (4) a full solution only on
  `show solution`.
- **Code style:** no prose comments or Haddock in `src/`, `app/`, `adapter/` or `test/`; only
  comments a tool needs (pragmas). Specs, design notes, extension and dependency reasons, and
  deliberate shortcuts go in `docs/TODO-<phase>.md` under "Spec", "Decisions" and "Shortcuts". Small
  modules, explicit export lists, flat conditionals, no partial functions in `src/`.
- **Missing binaries:** tests that need `mlir-opt` or the adapter skip (not fail) when the binary is
  missing, and print why.
- **`mlir-opt` location:** read from one place (an environment variable with the Homebrew path as
  the default), never hard-coded twice.

## File map

| File | Holds |
|---|---|
| [STATUS.md](STATUS.md) | facts, hypotheses, blockers, next actions |
| [docs/LEARNING-LOG.md](docs/LEARNING-LOG.md) | quiz results from QUIZ sessions |
| [docs/research/problem-statement.md](docs/research/problem-statement.md) | terms, success definition, target comparison, domain D0, RQs |
| [docs/research/novelty-audit.md](docs/research/novelty-audit.md) | prior work, comparison matrix, verdict |
| [docs/theory/rank-bound.md](docs/theory/rank-bound.md) | rank-dependency inventory, theorem, obligations, proof status |
| [docs/design/architecture.md](docs/design/architecture.md) | components, Haskell/MLIR boundary, vertical slice |
| [docs/experiments/initial-spike.md](docs/experiments/initial-spike.md) | 8–15 Nov plan, experiments A–F, GO criteria, probes run |
| [docs/risks-and-open-questions.md](docs/risks-and-open-questions.md) | risks and open questions |
| [docs/decisions/decision-log.md](docs/decisions/decision-log.md) | decisions, alternatives, evidence |
