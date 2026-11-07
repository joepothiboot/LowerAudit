# TODO: L11 fixes

Exp D and Exp E ([spike plan §2](experiments/initial-spike.md)) cannot run. This file records why, reports each falsification condition, and specifies the adapter flag and the `lower-audit adversarial` subcommand, for you to write.

**Status:** Exp D and Exp E have not run. There is no `results/` folder, and no `src/`, `app/`, `adapter/` or `test/` file changed.

**Labels (rule 6):** **[F]** read from this repository or from Homebrew MLIR's headers. **[M]** measured here on 2026-11-06. **[H]** hypothesis, not run.

**Citations:** target locations are at tt-mlir `f9dc1b3e5101`, as cited by `expected-outcomes.md`. They were not re-read here, since the target's source is not in this repo. MLIR headers are at Homebrew 23.1.1.

## What blocks the run, in order

| # | Blocker | Evidence | Who clears it |
|---|---|---|---|
| 1 | The slice in architecture §3 is still proposed, so rule 12 blocks implementation | **[F]** `architecture.md:63` | you, by accepting it |
| 2 | The functions Exp D and E call are stubs | **[M]** 80 `error "TODO` bodies in `src/` on this branch, plus `main` (`app/Main.hs:4`) | you, through their REVIEWs |
| 3 | `run` and `patterns` do not exist | [TODO-l6-fixes](TODO-l6-fixes.md); `TODO-l8-fixes.md` | you |
| 4 | The rank analyzer is stubs, so the mutant has nothing to go through | **[M]** 206 of 219 tests in its groups fail on `TODO:` | you, through [TODO-l10](TODO-l10.md) |
| 5 | The adapter converts nothing. It is unbuilt, and it targets TosaToLinalg | **[F]** `adapter/main.cpp:84-120`; [TODO-l7](TODO-l7.md) | you, through L7's REVIEW |
| 6 | The filter flag is not a one-line change | below | you |
| 7 | N does not exist: nothing declares k or k_V, so "ranks N to N+4" has no meaning | **[F]** every `states` and `validityStates` is null in `data/rank-ledger-tt-mlir-f9dc1b3e5101.json`; rank-bound §6, "Smallest N: unknown" | you, with an abstraction for the closure |
| 8 | `ttmlir-opt` does not exist here, and neither it nor a target adapter can be built | **[F]** D-015; `architecture.md:30` | you, with a new decision entry |

**With 1–7 cleared and 8 not,** one part can run: the mutant, on synthetic outcomes. That tests the analyzer and says nothing about the target.

## Falsification conditions

None was evaluated. None is met or cleared.

| Exp | Condition (`initial-spike.md:74,81`) | Result | What exists |
|---|---|---|---|
| D | A counterexample appears at rank ≥ N | not evaluated | no N, no runs |
| D | An obligation is false | not evaluated | **[H]** on paper, A2 looks false for si32 in the pipeline (rank-bound §2, `initial-spike.md:68`). The ledger has every obligation `open`, none `refuted` |
| D | The analyzer certifies the mutant | not evaluated | `conditional` is a stub. See Open question 3: as written, this cannot always be met |
| E | The injected gap is missed | not evaluated | no flag, no adapter that converts |
| E | A reported witness is not shortlex-minimal | not evaluated | no witness exists |

**Witness rank, size, and time to the first witness:** none exist, so none are reported. **[H]** The prediction on record for the injected gap is a rank-1 witness (`initial-spike.md:25`). For the raw negative index it is P4, at rank 3 in the pipeline (`expected-outcomes.md:56`). No time has been measured on `ttmlir-opt`.

## The request, as applied

The request's wording comes from the superseded target. Its experiments are read as the spike plan now states them, as in [TODO-l6-fixes](TODO-l6-fixes.md) and `TODO-l8-fixes.md`. See Decisions and Open question 1.

| Request | Spike plan, on D0-tt |
|---|---|
| `ReduceConverter<ReduceSumOp>` | `ReductionProdOpConversionPattern` (`initial-spike.md:78`) |
| the axis at every position, every partner letter | every mark set at each rank up to the agreed bound (`:71`) |
| representatives 3 and 7 | the same, and sizes around `kMaxIntegerProdUnrollSize` (`:70`) |
| ranks N to N+4 with all-dynamic bulk, bare | the same (`:72`) |
| the O3 family | the raw negative index (`:78`). O3 stays parked and untriaged, for L13.3 |

## Is the filter flag one line?

No, so this request stops and specifies it. **[F]** The removal itself is available: `RewritePatternSet::getNativePatterns` returns a mutable list (`PatternMatch.h:840`), and each pattern has a debug name (`:140`, set at `:260-261`). But the flag touches:

1. a field in `Options` (`adapter/main.cpp:142-147`);
2. a branch in `parseArgs` (`:152-162`), and the check of which arguments go together (`:163-167`);
3. `runConversion`'s signature, and its call (`:116`, `:210`);
4. `convertFunction`'s signature (`:111`), to reach the pattern set;
5. the removal, and the check that the name exists;
6. the usage text (`:176-178`).

Items 3–5 land in functions that are still stubs, so there is nowhere yet to attach it.

## Spec: --drop-pattern

- **Where:** `adapter/main.cpp`.
- **Usage:** `lower-audit-adapter --events=<events.jsonl> --drop-pattern=<debug name> <input.mlir>`
- **Behaviour:** in `convertFunction`, after the populate call and before `observeMatchFailures`, remove the one pattern with exactly this debug name. Nothing else changes. Without the flag, the adapter's output and events are byte-identical to today's.
- **Edge and error cases:**
  - A name in no pattern exits 2, nothing judged, and says so. Otherwise a typo gives an unfiltered run, and Exp E reads it as a missed gap.
  - A name held by more than one pattern exits 2. `parseRegistered` already refuses a repeated name.
  - `--drop-pattern` with `--dump-patterns` is a usage error.
  - A filtered run fails the fidelity check by construction, so it is never compared with `ttmlir-opt`.
- **[H]** The name is the full type name: O4 logged `(anonymous namespace)::ReduceConverter<mlir::tosa::ReduceSumOp>`, which suggests the same shape on the target. Take it from `--dump-patterns`, and do not write it by hand.
- **Tests:** in `test/AdapterSpec.hs`, skipped with no adapter: an unknown name exits 2; a known name gives no begin event for that pattern on any fixture; no flag leaves every fixture unchanged; a case that lowers unfiltered exits 1 filtered.

## Spec order

1. `adapter/main.cpp`: `--drop-pattern`
2. `LowerAudit.Adversarial`, pure: `boundFromLedger`, `representativeCases`, `markSetCases`, `dynamicBulkCases`, `mutantOutcome`, `firstWitness`, `verdictD`, `verdictE`, `renderAdversarialSummary`
3. `LowerAudit.Adversarial`, IO: `runAdversarial`
4. `app/Main.hs`: `main`

No tests exist for any of this. The Tests line of each entry says what should check it. `predict`, `Prediction`, `Scheduled`, `Observation`, `Verdict` and `observe` are [TODO-l6-fixes](TODO-l6-fixes.md)'s, and `CaseCheck` is `TODO-l8-fixes.md`'s.

## Folder

`results/<run-id>-adversarial/`:

| File | Holds |
|---|---|
| `manifest.json`, `tool-version.txt`, `invocation.txt`, `cases/`, `cases.jsonl` | as in [TODO-l6-fixes](TODO-l6-fixes.md) |
| `d/representatives.jsonl` | `outcomes.jsonl`'s schema, plus `representative`: one line per case and representative |
| `d/mark-sets.jsonl`, `d/dynamic-bulk.jsonl` | `outcomes.jsonl`'s schema |
| `d/mutant.txt` | `renderRankReport` of the mutant's report, labelled at each level |
| `e/registered.jsonl` | the adapter's `--dump-patterns`, as printed |
| `e/unfiltered/events/`, `e/filtered/events/` | the adapter's events, per case |
| `e/injected.jsonl` | one line per case: the unfiltered class, the filtered exit code, and whether the dropped pattern began |
| `e/negative-index.jsonl` | `outcomes.jsonl`'s schema, pipeline cases of rows P4 and P7 |
| `witnesses.jsonl` | one line per witness, see `firstWitness` |
| `summary.md` | `renderAdversarialSummary` |

## Types

```haskell
data Witness = Witness
    { witnessKind :: Text
    , witnessCase :: CaseId
    , witnessRank :: Int
    , witnessBytes :: Int
    , witnessCasesBefore :: Int
    , witnessSeconds :: Double
    }
```

## Spec: boundFromLedger

- **Signature:** `boundFromLedger :: Scope -> Ledger -> Either Text Int`
- **Behaviour:** k · k_V from the scope's entry, so that N has one source and is never typed in by hand.
- **Edge and error cases:** `Left`, naming the cause, for a scope with no entry or a null k or k_V. **[M]** That is every scope today. The obligations may stay open: this N is conditional, and the summary must say so.
- **Tests:** a recorded entry; no entry; each null.

## Spec: representativeCases

- **Signature:** `representativeCases :: Int -> [(AbstractCase, Representative)]`
- **Behaviour:** for each case of `enumerate` up to the bound that has a static letter `s`, the case under `Rep3` and under `Rep7`. A2 predicts the same outcome as under `Rep2`, which Exp A already ran.
- **Edge and error cases:**
  - A case with no `s` is left out: the representatives cannot differ.
  - Each case is rendered with one representative throughout, so a mix-dependent outcome is not seen ([TODO-l2](TODO-l2.md) records this).
  - **`Representative` cannot express the spike's "sizes around `kMaxIntegerProdUnrollSize`".** It holds 2, 3 and 7 only (`Concretize.hs:11`). **[F]** `expected-outcomes.md:52` implies the limit is 16. See Open question 4.
- **Tests:** none for a word of `1`s and `?`s; two per word with an `s`; the rendered sizes.

## Spec: markSetCases

- **Signature:** `markSetCases :: Int -> [AbstractCase]`
- **Behaviour:** every mark set at each rank up to the bound, on a word of only `s`, for each op, element type and `keep_dim`, in `enumerate`'s order. This costs 3^r per parameter, not 9^r, so it can go higher than Exp A's bound.
- **Edge and error cases:** the bound is an argument. Which bound is an Open question in [TODO-l6-fixes](TODO-l6-fixes.md).
- **Tests:** 3^r per parameter at rank r; a subsequence of `enumerate`.

## Spec: dynamicBulkCases

- **Signature:** `dynamicBulkCases :: Int -> [AbstractCase]`
- **Behaviour:** for each rank from N to N + 4:

  | Part | Values |
  |---|---|
  | Letters | `?` at every position; and `?` everywhere except `s` in the last two |
  | `dim_arg` | absent; `[0]`; `[r-1]`; `[0, 1]`; `[0, -1]` |
  | Params | both ops, f32, `keep_dim` false |

  So 20 cases per rank, and 100 in all.
- **Edge and error cases:** N ≥ 3 is needed for the partial lists to be partial. A smaller N drops them. The bare mode only, as the request says.
- **Tests:** 100 cases at N = 3; each passes `mkAbstractCase`; each has a `predict` row.

## Spec: mutantOutcome

- **Signature:** `mutantOutcome :: o -> ([Letter] -> o) -> [Letter] -> o`
- **Behaviour:** the first argument where the word has at least one `s` and as many `1` as `s`; otherwise the function's own answer. This is the non-regular guard of `initial-spike.md:73`, and its lowest firing is at rank 2.
- **Edge and error cases:**
  - **The guard counts static letters on purpose, and the first argument must differ from what the base gives there.** **[H]** P8 and P9 predict `CRASH` for every word holding a `?`. A guard on `?` that returns `CRASH` would equal the base function wherever it fires, so the mutant would be regular, and certifying it would be correct. `1s` is P1 or S1, predicted `LOWERED`, so `CRASH` differs there.
  - It is run through `rankReport` with `subjectMaxRank` equal to the run's bound, and with the declared abstraction, if any. With none, `conditional` answers `NoAbstraction`, and the summary has to say that was the path taken.
- **Tests:** `1s`, `s1` and `1s?` fire; `1`, `s`, `?` and `?s` do not; a word with marks still counts letters. Through the analyzer: the highest level is EMPIRICAL, with and without an abstraction of the base function.

## Spec: firstWitness

- **Signature:** `firstWitness :: Text -> (Observation -> Bool) -> [Observation] -> Maybe Witness`
- **Behaviour:** the first observation in run order that the predicate holds for, with its rank, the bytes of its `.mlir` text, how many domain cases came before it, and the seconds from the first case's start until it was classified. Controls are skipped.
- **Edge and error cases:** run order is shortlex only because `schedule` follows `enumerate`, so `verdictE` checks that instead of assuming it.
- **Tests:** none matching; a control that matches is skipped; the counts and sums on a hand-made run.

## Spec: verdictD

- **Signature:** `verdictD :: Int -> [Observation] -> [(Observation, Observation)] -> [LedgerEntry] -> Level -> Verdict`
- **Behaviour:** the arguments are N, every Exp D observation, each `Rep3` or `Rep7` observation with its `Rep2` one, the ledger, and the mutant's `highestLevel`. `Met` if any holds. The `Text`s name each kind, with a count and a first witness.
  - A case of rank ≥ N is a failure whose class differs from `predict`.
  - A representative changes the class on its case, or the ledger has a `Refuted` obligation.
  - The mutant's level is above `EmpiricalLevel`.
- **Edge and error cases:**
  - A difference at rank ≥ N falsifies either the abstraction or the prediction. The summary says it cannot tell which.
  - Below N, enumeration is not exhaustive, so "no violation below it" is not established, and this is not Theorem 1's counterexample as such.
  - A representative's difference on si32 in the pipeline is **expected** to be reachable (rank-bound §2). It still meets the condition.
- **Tests:** none; each kind alone; the first witness named.

## Spec: verdictE

- **Signature:** `verdictE :: [(Observation, Int)] -> Maybe Witness -> [Text] -> Verdict`
- **Behaviour:** the arguments are each `ttir.prod` case that is `LOWERED` unfiltered, in run order, with its filtered exit code; the first witness; and the names that began on filtered runs. `Met` if any holds:
  - No witness exists, or a case that lowers unfiltered and uses the pattern exits 0 when filtered.
  - The dropped pattern's name began on a filtered run. The flag failed.
  - An earlier case in `enumerate` also qualifies: the witness is not shortlex-minimal.
- **Edge and error cases:**
  - Filtered exit 1 covers rejected, failed and did not verify alike ([TODO-l7](TODO-l7.md)). That is enough here, since the case is known to be valid and to lower unfiltered.
  - A signal is a witness too, and is labelled as a crash.
  - The control is `ttir.sum`: its class must not change when the prod pattern is dropped. A change is listed as a problem with the flag, and voids the result.
  - **Raw negative index:** reported separately, not as a falsifier. A `CRASH` is a candidate gap, to triage, and not automatically a gap. No crash may mean tt-mlir's build has no assertions (`expected-outcomes.md:25-27`), so the build type goes in the summary.
- **Tests:** none; each kind alone; a sum that changes; a witness that is not first.

## Spec: renderAdversarialSummary

- **Signature:** `renderAdversarialSummary :: Manifest -> Text -> Int -> Verdict -> Verdict -> [Witness] -> Text -> Text`
- **Behaviour:** the whole of `summary.md`:
  1. Pin, oracle, generator SHA, domain hash, N, and the line `N comes from a declared abstraction whose obligations are <status>`.
  2. `verdictD`, each condition on its own line.
  3. `verdictE`, each condition on its own line.
  4. One line per witness: rank, bytes, cases before it, seconds to it, and the reproduce command.
  5. Row counts against `predict`, with `predicted failure did not occur` listed as in [TODO-l6-fixes](TODO-l6-fixes.md).
  6. `renderRankReport`'s three labelled lines for the mutant.
- **Edge and error cases:** section 2 and 3's verdicts come first because a falsifier voids what follows. Passing all conditions may not be worded as proving anything (rule 4). A raw-negative-index crash may not be called a gap before triage.
- **Tests:** a snapshot on a hand-made run; a run with no witness prints `none`.

## Spec: runAdversarial

- **Signature:** `runAdversarial :: [String] -> IO ExitCode`
- **Behaviour:** `["--max-rank", n, "--scope", conversion]`. Resolve the tools, the data files and N, make the folder, run Exp D's three case sets, build the mutant's report, run Exp E's filtered and unfiltered sets, then write `summary.md`.
- **Edge and error cases:**

  | Condition | Exit | When |
  |---|---|---|
  | a missing tool or adapter, a null k, a dropped-pattern name not in the dump, or `n` not ≥ 1 | 2, naming the cause | before any folder is made |
  | a dirty generator tree, as in `runExhaustive` | 2 | before any folder is made |
  | a witness re-run once gives another class (`initial-spike.md:98`) | 3; the summary is still written | at the end |
  | a met falsifier | 0: a finding, not a failure | at the end |

- **Tests:** the executable on stand-in tools, as `SliceSpec` does: every file in the folder table; each exit 2 makes no folder; a stand-in that changes its answer gives 3.

## Spec: main

- **Signature:** `main :: IO ()`
- **Behaviour:** `"adversarial" : rest` goes to `runAdversarial rest`. The rest is as [TODO-l6-fixes](TODO-l6-fixes.md) and `TODO-l8-fixes.md` specify. The usage text names it too.
- **Tests:** one naming `adversarial`.

## Decisions

- **No results folder was written.** A folder of that name would read as a run, and none happened. Direct `mlir-opt` probes or the L10 throwaway could have filled one, but not from your tool and not on the target. This is the same choice as `TODO-l8-fixes.md`.
- **The adapter is unchanged.** The request allows a one-line flag, and this one is not, by the list above.
- **The request is read as D0-tt.** D-010 superseded TosaToLinalg, and the spike plan's Exp D and E are written for D0-tt. The flag and the verdicts do not depend on the target. Only the pattern's name and `predict` do.
- **N is read from the ledger, not passed on the command line.** A typed N could not be traced to anything, and rule 4 makes the source of a bound matter.
- **A dropped name that does not exist is an error.** A missed gap is a falsifier, so a typo must not be able to produce one.
- **Exp D reuses Exp A for most of its enumeration.** Only representatives, mark sets at higher rank, and dynamic bulk are new. `Rep2` outcomes come from the same schedule.

## Shortcuts

- **One pattern at a time.** Exp E names one. A list can wait until a second is needed.
- **One filtered mode.** The adapter observes the bare conversion only, so a filtered pipeline is out. The raw negative index needs the pipeline and no filter, so it is CLI only.
- **Witnesses are re-run once, not twice.** That is enough to trip the stop rule on an obvious difference. Exp A's two repeats remain the determinism check.
- **`witnessBytes` is the size of the `.mlir` text.** The request asks for "size" without defining it.

## Open questions

1. **Did you mean D0 on TosaToLinalg?** The request names its pattern, its axis and O3. It is the one version that could run here without lifting D-015: once blockers 1–6 are done, Homebrew's `mlir-opt` and the L7 adapter are enough. It needs a TOSA generator and validity step, a decision entry reversing D-010's effect for this experiment (rules 8 and 10), and predictions written first, though rank-bound §7 records one never tested: `?` at both axis and partner is `OUTPUT_INVALID` at every rank ≥ 2. It would be a dated record, not evidence about the target. This is [TODO-l6-fixes](TODO-l6-fixes.md)'s Open question 1 again, and it is now the third request to raise it. *Spec:* D0-tt only.
2. **Does all-dynamic bulk test anything on the bare pass?** **[H]** P8 and P9 predict `CRASH` in `--ttnn-layout` for all 100 cases of `dynamicBulkCases`, before the conversion starts, if tt-mlir's build has assertions. P9 is the weakest row. So ranks N to N+4 would mostly exercise the layout pass, not the closure Theorem 1 is about, and could only falsify P8 and P9. Static bulk at those ranks would reach the conversion. *Spec:* as the request says.
3. **Should `initial-spike.md:73-74` change?** Exp D is falsified if the analyzer certifies the mutant. **[M]** On L10's tests against a throwaway, a guard that fires within the checked ranks is refused, and one past them reaches CONDITIONAL ([TODO-l10](TODO-l10.md) Open question 8). This mutant fires at rank 2, so it should be refused whenever the abstraction is checked that far, but the condition as written promises more than any black-box check can. *Spec:* that file is unchanged.
4. **How should "sizes around 16" be expressed?** `Representative` is an enum of 2, 3 and 7, and problem statement §6 lists those. Sizes 15, 16 and 17 need either new constructors, which changes the domain's representatives (rule 8), or a probe list outside the domain. It matters only for si32 in the pipeline, where A2 already looks false. *Spec:* left out of `representativeCases`, so Exp D's text is only partly covered.
5. **What is the agreed bound?** Exp D says "up to the agreed bound", and [TODO-l6-fixes](TODO-l6-fixes.md)'s Open question 2 has not settled it. `markSetCases` and `representativeCases` both take it as an argument.
6. **Where should this file's commit go?** It cites L10's API, which is only on `feat/l10-rank-analyzer`, uncommitted. *Suggestion:* with or after the L10 stubs.
