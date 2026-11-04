# Architecture (minimum credible design)

Status: **design only, reworked 2026-11-04 for the accepted target** (D-012 to D-015). The target cannot be
built or run here while D-015 holds. Implementation code still waits on CLAUDE.md rule 12.

**Labels:** **[F]** read from tt-mlir `f9dc1b3e5101` or its LLVM `4efe170d858e`. **[H]** hypothesis, not run.

## 1. Boundary

```
Haskell driver: lower-audit
  domain model -> generator -> case_*.mlir
      | run ttmlir-opt (CLI)   -> exit code, diagnostics, action log (attempts)
      | run adapter (C++)      -> events.jsonl (begin/end/match-failure reason), output.mlir
  <- coverage analyzer, pattern analyzer, rank analyzer, reports
      -> results/<date>-<target>-<what>/
```

- **Processes and files only.** No FFI, no Haskell bindings to MLIR. Cases are short `.mlir`
  text, and Haskell writes them directly.
- **MLIR is the execution authority.** The CLI tier runs `ttmlir-opt`, built from the pinned commit.
- **The C++ adapter exists only because pattern success is not observable otherwise.** **[H]** This was shown
  on the Homebrew build (O4) and is not re-tested here. tt-mlir's LLVM has assertions on
  (`env/CMakeLists.txt:68`), so `-debug-only` may offer another route (OQ-6).
- The adapter must not become a second implementation. **[F]** The pass builds its conversion target
  inside `runOnOperation` (`TTIRToTTNNPass.cpp:40-67`), so the adapter rebuilds the same
  target and calls the public `populateTTIRToTTNNPatterns` (`TTIRToTTNN.h:13`).
- **[F]** The listener API is present at this LLVM: `PatternMatch.h:407,414`, `DialectConversion.h:1386`, and
  driver calls at `DialectConversion.cpp:2719,2758,2792`.
- **[H]** The adapter links tt-mlir's own libraries, as `ttmlir-opt` does (`tools/ttmlir-opt/CMakeLists.txt:4`),
  not a Homebrew `find_package(MLIR)`.
- **Fidelity check:** for every case, the adapter's printed output must equal `ttmlir-opt`'s.
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
| A | Domain model | case types, letters, a set of dim marks, `keep_dim`, V_ttir as a declared predicate, concretization (two or three representatives per letter) | domain spec → `Case` values | Haskell | base, text | every generated non-control case passes V_ttir; the declared and executable oracles agree, and every disagreement is logged as a finding | none on encoding (D-017) |
| B | Case generator | exhaustive shortlex enumeration; case id = hash of the text; run manifest (commits, generator git SHA, domain hash) | `Case`s → `.mlir` files and `cases.jsonl` | Haskell | A | counts equal the closed forms in the problem statement §6 | exhaustive rank bound; random sampling beyond it: seeded, recorded |
| C1 | CLI runner | run `ttmlir-opt` for V_ttir and each conversion mode, with timeout and `--mlir-disable-threading` | `.mlir` → exit code, stderr, action log | Haskell (`process`) | `ttmlir-opt` at the commit | **[H]** no target fixtures exist until it can run; recorded probes O1–O7 belong to `mlir-opt` | batching with `--split-input-file` vs. one process per case (crash isolation) |
| C2 | Listener adapter | parse, run the same conversion with `ConversionConfig::listener`, emit begin, end and match-failure-reason events, verify, print | `.mlir` → `events.jsonl`, `output.mlir` | C++, CMake, built against the tt-mlir build tree | tt-mlir at the commit | fidelity check; listener begin count equals action-log count | rollback attribution; whether the decomposition pass also needs an adapter, since it is partial and takes a config (`TTIRToTTIRDecomposition.h:18`) |
| D | Coverage analyzer | classify (problem statement §3); triage gaps as documented or unknown; summaries by rank, mark summary, letters, element type | runs → `outcomes.jsonl` | Haskell | B, C | hand-labelled fixtures; Exp F confusion matrix | exact diagnostic strings |
| E | Pattern analyzer | per-pattern state (problem statement §4); "not observed" with the conditions under which the pattern was considered; "unreachable in D" only with a certificate from F | events → `patterns.jsonl` | Haskell | C2, F | known-gap injection (Exp E) | stable pattern identity across pins |
| F | Rank analyzer | (i) **empirical**: which positions and letters change the outcome, increasing R until stable; (ii) **conditional**: N from the declared abstraction; (iii) **proved** only when every obligation in [rank-bound](../theory/rank-bound.md) has evidence | inventory + outcomes → bound report with a status label | Haskell | D | synthetic outcome functions with known automata, including a non-regular one (equal counts) that must be **rejected** | how much of the obligation checking can be mechanized |
| G | Reporter | `summary.md`, witness `.mlir` files with the exact reproduce command and commits, `file:line` links | all jsonl → files | Haskell | D, E, F | snapshot test of one report | none |

**Without a build:** A, B, F and the pure half of D can be written and tested on synthetic inputs. C1, C2, E's
real input, and every run need `ttmlir-opt`.

## 3. Minimal vertical slice

**Proposed, not accepted (rule 12).** First code, after acceptance:

1. Generate one valid case: `ttir.prod` at input rank 3, one positive dim, static, f32, `keep_dim = false`.
2. Run the real conversion in both modes, with the commands in D-017.
3. Capture the exit code and diagnostics, and classify the outcome.
4. Append one JSON line to `results/<date>-slice/outcomes.jsonl`.
5. Write `summary.md` with the reproduce command.

Acceptance, three cases classified automatically as the frozen predictions say:

- rank 3 `ttir.prod` above;
- the documented rank-5 rejection (`negative_reduce_prod_op.mlir:1-7`);
- an ill-typed control, for O7's lesson: an invalid input must be `INVALID`, never a gap.

**This slice cannot run while D-015 holds.** Up to step 1, plus classifying hand-written run records, it can be
built and tested without a target.

Then extend, in this order:

1. adapter events (Exp B);
2. exhaustive D0-tt (Exp A, F);
3. rank analyzer (Exp C, D).

Skipped on purpose: a database, a config system, a parallel scheduler (`xargs -P` will do), a UI,
and FFI. Add one only when a measured need appears.

**Record:** the 2026-11-01 slice targeted `tosa.reduce_sum` through `mlir-opt` and was to reproduce O1, O3 and O7's
control. It was never written. The probes are in the [spike plan](../experiments/initial-spike.md#reconnaissance-probes-run-on-2026-11-01).
