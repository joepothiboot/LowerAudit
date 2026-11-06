# TODO: L8 fixes

Exp B ([spike plan §2](experiments/initial-spike.md)) cannot run, and there is no implementation of [TODO-l8](TODO-l8.md) to review. This file records why, what can be said without a run, and the missing `lower-audit patterns` subcommand, for you to write.

**Status:** Exp B has not run. There is no `results/` folder, and no `src/`, `app/`, `adapter/` or `test/` file changed.

**Labels (rule 6):** **[F]** read from source. **[M]** measured here on 2026-11-06. **[H]** hypothesis, not run.

**Citations:** tt-mlir `f9dc1b3e5101` and LLVM `4efe170d858e`, unless marked *(record)*, which is `llvmorg-23.1.1`.

## What blocks the run, in order

| # | Blocker | Evidence | Who clears it |
|---|---|---|---|
| 1 | The slice in architecture §3 is still proposed, so rule 12 blocks implementation | **[F]** `architecture.md:63` | you, by accepting it |
| 2 | `LowerAudit.Patterns` is all stubs. The only commit touching it is `0d1111f`, the stubs | **[M]** 95 of its 99 tests fail on `TODO:`. The file in the working tree equals the blob at `HEAD` | you, through [TODO-l8](TODO-l8.md) |
| 3 | Everything Exp B calls is a stub too: 47 functions from L2–L5, plus `main` | **[M]** `cabal run lower-audit -- patterns` dies at `TODO: main` (`app/Main.hs:4`) | you, through their REVIEWs |
| 4 | The adapter converts nothing: 7 stubs. It is unbuilt, and it targets TosaToLinalg | **[F]** `adapter/main.cpp:84-119`; [TODO-l7](TODO-l7.md) Decisions | you, through L7's REVIEW |
| 5 | `run`'s schedule and controls do not exist | [TODO-l6-fixes](TODO-l6-fixes.md) | you |
| 6 | `patterns` does not exist | this file | you |
| 7 | `ttmlir-opt` does not exist here, and neither it nor a target adapter can be built | **[F]** D-015; `architecture.md:30` | you, with a new decision entry |
| 8 | D-018 is proposed, not accepted, and the reason half of Exp B depends on it | **[F]** D-018 | you |

## Exp B's falsification conditions (`initial-spike.md:56`)

None was evaluated. None is met or cleared.

| Condition | Result | What exists |
|---|---|---|
| Begin counts differ from the action log | not evaluated | **Do not run it as written.** See below |
| An event names a pattern whose root op is absent | not evaluated | `analyzeCase` is specified to report it as `RootMismatch`, and is a stub |
| A fidelity mismatch | not evaluated | The check is in `test/AdapterSpec.hs`, and skips with no adapter |

The record does not fill these in. [TODO-l7](TODO-l7.md)'s 18-of-18 fidelity and its begin counts came from a throwaway on TosaToLinalg, since deleted. It says nothing about the target.

**The hypothesis is already partly refuted on paper.** It says listener events separate match failures "with reason". **[F]** The listener alone never receives a reason (D-018). `initial-spike.md:52` still says otherwise, pending your decision on D-018.

**The begin-count check would falsify itself on the target.** **[F]** The bare command runs `--ttnn-layout` before the conversion, and that pass calls `applyPatternsGreedily` (`TTNNLayout.cpp:931,957`). The greedy driver goes through the same applicator (`GreedyPatternRewriteDriver.cpp:620`), which logs an `ApplyPatternAction` (`PatternApplicator.cpp:197`). **[H]** So the log holds attempts by patterns the conversion's listener never sees, and any layout rewrite makes the counts differ with nothing wrong. [TODO-l7](TODO-l7.md)'s "one pass" reasoning holds for TosaToLinalg only. See `conversionAttempts`.

## Does D0 contain a rollback?

**Not known: no event stream exists, on either domain. A constructed case is still needed.** Everything below is a prediction from source, not a result, and rule 3's caution applies.

| Kind of rollback | D0-tt, bare | D0 *(record)* |
|---|---|---|
| **Pattern-level:** a success whose new IR does not legalize, seen as two failure ends | **[H]** none. **[F]** T, P and Σ create only TTNN ops (`TTIRToTTNN.cpp:67,78,176,233,275`), the dialect is legal (`TTIRToTTNNPass.cpp:44`), and `legalizePatternResult` fails only when a part of the new IR does not legalize | **[H]** none. **[F]** `ReduceConverter` ends in `tensor.expand_shape` (`TosaToLinalg.cpp:1370`), unknown ops are legal (`TosaToLinalgPass.cpp:65`), and no `tosa` op is created in the helper or in `PointwiseConverter`'s range. Callees were not all read |
| **Whole-conversion:** a success end, then another op fails and everything is undone | **[H]** possible on P3, P4, P6 and P7. Row P3 of `expected-outcomes.md` says T "may apply and roll back". **[F]** The driver undoes on any failure (`DialectConversion.cpp:3415-3419`). Whether T applies first is unconfirmed | **[H]** none. A case is one op, so nothing has succeeded before it fails |

So the spike's known limit (`initial-spike.md:57`) likely holds for the pattern-level kind and likely fails for the whole-conversion kind. The second kind cannot show that `attemptsOf`'s two-end rule works on a real stream. The constructed case is what would. **[M]** *(record, 2026-11-05)* One exists only as a past measurement: a throwaway pattern replacing `tosa.add` with `tosa.custom` printed begin, end `failure`, end `failure`. No fixture or test holds it. See Open question 2.

## Spec order

1. `LowerAudit.PatternsRun`, pure: `patternLine`, `conversionAttempts`, `verdictB`, `renderPatternSummary`
2. `LowerAudit.PatternsRun`, IO: `runPatterns`
3. `app/Main.hs`: `main`

No tests exist for any of this. The Tests line of each entry says what should check them.

## Folder

`results/<run-id>-patterns/`:

| File | Holds |
|---|---|
| `manifest.json`, `tool-version.txt`, `invocation.txt`, `cases/`, `cases.jsonl` | as in [TODO-l6-fixes](TODO-l6-fixes.md) |
| `registered.jsonl` | the adapter's `--dump-patterns`, as printed |
| `events/case_<id>.jsonl` | the adapter's events for that case |
| `patterns.jsonl` | one line per registered pattern, in registration order: `patternLine` |
| `summary.md` | `renderPatternSummary` |

## Schema: `patterns.jsonl`

One compact JSON object per line, with sorted keys, as `outcomes.jsonl`.

| Field | Type | Meaning |
|---|---|---|
| `caseCounts` | object, string to integer | exactly the keys `registered`, `attempted`, `match-failed`, `rolled-back`, `applied`, `survived`, from `domainCounts` |
| `considered` | array, or null | null unless `state` is `not-observed`. One `{"caseCount","firstCase","op","reasons"}` per `Considered`. The array may be empty |
| `oracle` | string | `V_ttir` |
| `pattern` | string | the debug name |
| `pin` | object, string to string | as in `outcomes.jsonl` |
| `root` | string, or null | the registered root |
| `runId` | string | |
| `state` | string | `survived`, `applied`, `rolled-back`, `not-observed`, or `unreachable-in-d` |

## Types

```haskell
data CaseCheck = CaseCheck
    { checkScheduled :: Scheduled
    , checkBegins :: [Text]
    , checkLogged :: [Text]
    , checkFidelity :: Bool
    , checkReport :: Either PatternError CaseReport
    }
```

## Spec: patternLine

- **Signature:** `patternLine :: Text -> Text -> [(Text, Text)] -> DomainEntry -> ByteString`
- **Behaviour:** the schema above, from the run id, oracle, pin and entry. `firstCase` is the first of `consideredCases`, which the schedule makes a smallest-rank witness.
- **Edge and error cases:** `unreachable-in-d` appears only for `Unreachable`, so only with a certificate. Nothing may print that string from `NotObserved` (rule 3).
- **Tests:** a golden for one line per `DomainState` that can be built today; no newline, even with one in a reason.

## Spec: conversionAttempts

- **Signature:** `conversionAttempts :: [RegisteredPattern] -> Text -> [Text]`
- **Behaviour:** from an action log, the pattern on each `` `apply-pattern pattern: `` line, as `attemptsInLog` in `test/AdapterSpec.hs`, keeping only names that match a registered pattern, in order. `--ttnn-layout`'s attempts drop out.
- **Edge and error cases:** **[H]** This assumes no name is registered in both passes. Check the first real log. The log's name carries a suffix, so match by prefix as `beginCount` does.
- **Tests:** a hand-written log with greedy attempts mixed in.

## Spec: verdictB

- **Signature:** `verdictB :: [CaseCheck] -> Verdict`
- **Behaviour:** `initial-spike.md:56`. `Met` if, on any case: the begins differ from `checkLogged` in number; `checkReport` is `Left (RootMismatch _ _)`; or `checkFidelity` is false. The `Text`s name each kind, with a count and a first witness.
- **Edge and error cases:**
  - A fidelity mismatch voids that case's results (`architecture.md:33`): keep it out of `analyzeDomain`, and count it.
  - Any other `Left` also voids the case. It is listed separately, as a problem with the stream or the tool, and is not one of the three conditions.
- **Tests:** none; each condition alone; a case with another `Left`, which does not meet it.

## Spec: renderPatternSummary

- **Signature:** `renderPatternSummary :: Manifest -> Text -> [CaseCheck] -> [DomainEntry] -> Text`
- **Behaviour:** the whole of `summary.md`:
  1. Pin, oracle, generator SHA, domain hash, rank bound, and cases run against cases voided.
  2. `verdictB`, each condition on its own line.
  3. Exp B's control: on a partial-mark `ttir.prod` in the bare mode, whether `ReductionProdOpConversionPattern` is `MatchFailed` with the reason at `TTIRToTTNN.cpp:259-261`, as an exact string compare.
  4. Exp B's expected rows: `ReductionProdOpConversionPattern` and the `ttir.sum` pattern, with counts per state.
  5. **Rollback:** counts of two-end attempts, of successes under a failed ancestor, and of successes undone with the conversion, each with a first witness. Zero prints as `none observed on the tested cases`, followed by `a constructed case is still needed` if the two-end count is zero.
  6. Every pattern by `DomainState`. Each not-observed pattern lists its `considered` entries, or says it was never begun on a tested case.
- **Edge and error cases:** the words "unreachable" and "never fires" may not describe a not-observed pattern. Section 2 comes first, because a falsifier voids what follows it.
- **Tests:** a snapshot on a hand-made run; a zero-rollback run prints both sentences.

## Spec: runPatterns

- **Signature:** `runPatterns :: [String] -> IO ExitCode`
- **Behaviour:** `["--max-rank", n]`. For each entry of `schedule n`, one at a time: the bare CLI step with its action log, then the adapter on the same case, then the fidelity compare and `analyzeCase`. After the last, `analyzeDomain`, and write the folder.
- **Edge and error cases:**

  | Condition | Exit | When |
  |---|---|---|
  | a missing tool or adapter, or `n` not ≥ 1 | 2, naming the cause | before any folder is made |
  | a dirty generator tree, as in `runExhaustive` | 2 | before any folder is made |
  | a met falsifier | 0: a finding, not a failure | at the end |

  The class given to `analyzeCase` is the CLI's bare one. The adapter's exit code cannot supply it: exit 1 covers parse, conversion and verify failures alike ([TODO-l7](TODO-l7.md)).
- **Tests:** the executable on stand-in tools, as `SliceSpec` does: every file in the folder table; each exit 2 makes no folder.

## Spec: main

- **Signature:** `main :: IO ()`
- **Behaviour:** `"patterns" : rest` goes to `runPatterns rest`. The rest is as [TODO-l6-fixes](TODO-l6-fixes.md) specifies. The usage text names it too.
- **Tests:** one naming `patterns`.

## Decisions

- **The request is read as D0-tt, as in [TODO-l6-fixes](TODO-l6-fixes.md),** because D0 was superseded (D-010), Exp B's text is written for D0-tt (`initial-spike.md:54-55`), and `ReduceOp` holds no TOSA op. See Open question 1.
- **No results folder was written.** A folder of that name would read as a run, and none happened. A throwaway analyzer and adapter on Homebrew could have produced one, but not from your tool and not on the target.
- **No review notes on the implementation,** because there is none. That also leaves nothing to log in `docs/LEARNING-LOG.md` and nothing to mutate. The earlier mutation table in [TODO-l8](TODO-l8.md) was against a throwaway.
- **The action log is compared after filtering, not by count alone.** See the begin-count section above.
- **The adapter's events give pattern states; the CLI gives the class.** That keeps one classifier, and fidelity ties the two runs together.

## Shortcuts

- **`considered` holds a count and a first witness, not all case ids.** At a bound of 4, a list could reach 88,560 ids per pattern. The ids can be recovered from `events/`.
- **Bare mode only.** The adapter observes one pass, so D and W in `expected-outcomes.md` stay checked from output IR, if at all.
- **No rerun comparison here.** Exp A's two repeats cover determinism on the CLI tier. Stop if a rerun of this differs, as for any run.

## Open questions

1. **Did you mean D0 on TosaToLinalg?** It is the one version that could run here without lifting D-015: once blockers 2–4 and an adapted `patterns` are done, Homebrew's `mlir-opt` and the L7 adapter are enough. It would be a dated record, not evidence about the target, and needs a decision entry and predictions written first ([TODO-l6-fixes](TODO-l6-fixes.md) Open question 1 has the same shape). *Spec:* D0-tt only.
2. **What is the constructed rollback case?** **[H]** One candidate: an adapter-only pattern, behind a flag, that replaces `ttir.sum` with a partial-mark `ttir.prod`. P then fails on the new op, which should give P's match failure nested in two failure ends on the injected pattern, the nesting no fixture has. It would run apart from D0-tt, and it fails the fidelity check by construction, as Exp E's filtering does. *Spec:* not included.
3. **Should `initial-spike.md:52,57` change?** Line 52 depends on D-018. Line 57 could name the two kinds of rollback. *Spec:* both unchanged, since that file changes only by your decision.
