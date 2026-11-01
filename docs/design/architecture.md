# Architecture (minimum credible design)

Status: **design only, 2026-11-01.** No code until D-004 and D-005 are accepted (CLAUDE.md rule 12).

## 1. Boundary

```
Haskell driver: lower-audit
  domain model -> generator -> case_*.mlir
      | run mlir-opt (CLI)     -> exit code, diagnostics, action log (attempts)
      | run adapter (C++)      -> events.jsonl (begin/end/match-failure reason), output.mlir
  <- coverage analyzer, pattern analyzer, rank analyzer, reports
      -> results/<date>-<target>-<what>/
```

- **Processes and files only.** No FFI, no Haskell bindings to MLIR. Cases are short `.mlir`
  text, and Haskell writes them directly.
- **MLIR is the execution authority.** The CLI tier runs the shipped `mlir-opt` at the pin.
- **The C++ adapter exists only because pattern success is not observable otherwise.** In the
  release build, the action log gives attempts but no result (O4), and `-debug-only` is
  unavailable because assertions are off.
- The adapter must not become a second implementation. The pass builds its conversion target
  inside `runOnOperation` (`TosaToLinalgPass.cpp:48–72`), so the adapter rebuilds the same
  target and calls the public `populateTosaToLinalgConversionPatterns`.
- **Fidelity check:** for every case, the adapter's printed output must equal `mlir-opt`'s.
  Any mismatch voids the adapter's results for that case.

Where Haskell earns its place:

- algebraic types for cases and outcomes, with exhaustive matching;
- lazy, deterministic enumeration in shortlex order, so the first witness has minimal rank;
- small pure automata code for the rank analyzer (product, emptiness, shortest word);
- QuickCheck-style property tests for the generator and classifier.

Where it would cost without benefit: binding MLIR's C API, or parsing MLIR output in Haskell.
Both are avoided; structured facts come from the adapter as JSON.

## 2. Components

| | Component | Responsibility | Input → output | Language | Depends on | Test strategy | Unresolved |
|---|---|---|---|---|---|---|---|
| A | Domain model | case types, letters, both validity oracles as declared predicates, concretization (two or three representatives per letter) | domain spec → `Case` values | Haskell | base, text | every generated non-control case passes V_mlir; the declared and executable oracles agree, and every disagreement is logged as a finding | whether V_tosa1.0 is modelled in Haskell or only run through `tosa-validate` (plan: both, compared) |
| B | Case generator | exhaustive shortlex enumeration; case id = hash of the text; run manifest (pin, generator git SHA, domain hash) | `Case`s → `.mlir` files and `cases.jsonl` | Haskell | A | counts equal closed forms (642 per element type under V_tosa1.0, ranks 1–6) | random sampling for extensions beyond exhaustive bounds: seeded, recorded |
| C1 | CLI runner | run `mlir-opt` for each oracle step and each conversion mode, with timeout and `--mlir-disable-threading` | `.mlir` → exit code, stderr, action log | Haskell (`process`) | `mlir-opt` 23.1.1 | golden fixtures from probes O1–O7 | batching with `--split-input-file` vs. one process per case (crash isolation) |
| C2 | Listener adapter | parse, run the same conversion with `ConversionConfig::listener`, emit begin, end and match-failure-reason events, verify, print | `.mlir` → `events.jsonl`, `output.mlir` | C++ (~200 lines, CMake, `find_package(MLIR)` from Homebrew) | Homebrew MLIR CMake package | fidelity check; listener begin count equals action-log count | rollback attribution from begin/end nesting; whether to add an `allowPatternRollback=false` run (fatal error, so one process per case) |
| D | Coverage analyzer | classify per oracle (problem statement §3); triage gaps as spec-required, documented or unknown; summaries by rank, axis role, letters, element type | runs → `outcomes.jsonl` | Haskell | B, C | hand-labelled fixtures; Exp F confusion matrix | exact diagnostic strings at the pin |
| E | Pattern analyzer | per-pattern state (problem statement §4); "not observed" with the conditions under which the pattern was considered; "unreachable in D" only with a certificate from F | events → `patterns.jsonl` | Haskell | C2, F | known-gap injection (Exp E) | stable pattern identity across pins (names are C++ type names) |
| F | Rank analyzer | (i) **empirical**: which positions and letters change the outcome, increasing R until stable; (ii) **conditional**: N from the declared abstraction; (iii) **proved** only when every obligation in [rank-bound](../theory/rank-bound.md) has evidence | inventory + outcomes → bound report with a status label | Haskell | D | synthetic outcome functions with known automata, including a non-regular one (equal counts) that must be **rejected** | how much of the obligation checking can be mechanized |
| G | Reporter | `summary.md`, witness `.mlir` files with the exact reproduce command and pin, `file:line` links | all jsonl → files | Haskell | D, E, F | snapshot test of one report | none |

## 3. Minimal vertical slice (first code, after acceptance)

1. Generate one valid case: `tosa.reduce_sum` with input rank 2, axis 1, static, f32.
2. Run the real conversion:
   `mlir-opt --pass-pipeline='builtin.module(func.func(tosa-to-linalg))'`, then
   `--tosa-to-linalg-pipeline`.
3. Capture the exit code and diagnostics, and classify the outcome.
4. Append one JSON line to `results/<date>-slice/outcomes.jsonl`.
5. Write `summary.md` with the reproduce command.

Acceptance: the slice reproduces O1 (rank 2), O3 and O7's control automatically. Then extend, in
this order:

1. adapter events (Exp B);
2. exhaustive D0 (Exp A, F);
3. rank analyzer (Exp C, D).

Skipped on purpose: a database, a config system, a parallel scheduler (`xargs -P` will do), a UI,
and FFI. Add one only when a measured need appears.
