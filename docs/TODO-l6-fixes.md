# TODO: L6 fixes

The tool cannot run Exp A and Exp F ([spike plan §2](experiments/initial-spike.md)). This file specifies the missing `lower-audit run` subcommand, for you to write.

**Status:** Exp A and Exp F have not run. There is no `results/` folder, the Result column of [expected outcomes](experiments/expected-outcomes.md) is not filled, and no `src/`, `app/` or `test/` file changed.

**Labels (rule 6):** **[F]** read from this repository. **[M]** measured here on 2026-11-05. **[H]** hypothesis, not run.

## What blocks the run, in order

| # | Blocker | Evidence | Who clears it |
|---|---|---|---|
| 1 | The slice in architecture §3 is still proposed, so rule 12 blocks implementation | **[F]** `architecture.md:63` | you, by accepting it |
| 2 | The L2–L5 functions are stubs: 47 in `src/` plus `main` | **[M]** `cabal run lower-audit -- run` dies at `error "TODO: main"` (`app/Main.hs:4`) | you, through their REVIEWs |
| 3 | `run` does not exist | this file | you |
| 4 | `ttmlir-opt` does not exist here, and building it needs a source build | **[F]** D-015 | you, with a new decision entry |

With 1–3 cleared and 4 not, `run` exits 2 on this machine, as `slice` does.

## Spec order

1. `LowerAudit.Exhaustive`, pure: `predict`, `controls`, `schedule`, `caseJson`, `observe`, `repeatDifferences`, `classCounts`, `predictionCounts`, `confusionMatrix`, `verdictA`, `verdictF`, `renderSummary`
2. `LowerAudit.Exhaustive`, IO: `runRepeat`, `runExhaustive`
3. `app/Main.hs`: `main`

`Exhaustive` calls `LowerAudit.Slice` (`formatRunId`, `sliceOptions`), so `Slice.runCommand` cannot call back into it without an import cycle. `main` does the dispatch.

No tests exist for any of this. The Tests line of each entry says what should check it.

## Folder

`results/<run-id>-d0-tt/`:

| File | Holds |
|---|---|
| `manifest.json` | `manifestJson` of `mkManifest <git SHA> (d0tt <max-rank> Rep2)` |
| `tool-version.txt` | stdout of `ttmlir-opt --version` |
| `invocation.txt` | the `lower-audit run` command, and the resolved tool path |
| `cases/case_<id>.mlir` | each distinct case, once |
| `cases.jsonl` | one line per scheduled run, see `caseJson` |
| `repeat-<n>/outcomes.jsonl` | L5's schema, unchanged; line i belongs to line i of `cases.jsonl` |
| `repeat-<n>/commands.txt` | every command as run, in order, as `shellCommand` |
| `repeat-<n>/timings.jsonl` | `{"seq":i,"bareSeconds":x,"pipelineSeconds":y}`, kept apart so `outcomes.jsonl` can compare byte for byte |
| `summary.md` | `renderSummary` |

Both repeats share one run id and one `cases/` folder, so their commands, and with a deterministic tool their `outcomes.jsonl` files, are equal bytes.

## Types

```haskell
data Control = Control
    { controlId :: Text
    , controlText :: Text
    , controlExpected :: Mode -> Prediction
    }

data Prediction = Prediction
    { predictedRow :: Text
    , predictedClass :: OutcomeClass
    , predictedPass :: Maybe Text
    }

data Role = DomainCase AbstractCase | ControlCase Control

data Scheduled = Scheduled
    { scheduledSeq :: Int
    , scheduledRole :: Role
    , scheduledText :: Text
    }

data Observation = Observation
    { observedScheduled :: Scheduled
    , observedBare :: Classification
    , observedPipeline :: Classification
    , observedLine :: Text
    , observedBareSeconds :: Double
    , observedPipelineSeconds :: Double
    }

data Facet = ByRank | ByMarks | ByLetters | ByElementType | ByOp | ByKeepDim

data Difference = Difference
    { differenceSeq :: Int
    , differenceMode :: Mode
    , differenceFirst :: Classification
    , differenceSecond :: Classification
    }

data Verdict = Met [Text] | NotMet
```

## Spec: predict

- **Signature:** `predict :: AbstractCase -> Mode -> Prediction`
- **Behaviour:** the frozen rows of `expected-outcomes.md`, as data. Total on D0-tt. *One* is |`dim_arg`| = 1, *all* is absent or |`dim_arg`| = r, *partial* is anything else.

  | Op | Letters | r | Marks | Sign | Type | Row | Bare | Pipeline |
  |---|---|---|---|---|---|---|---|---|
  | prod | static | ≤ 4 | one or all | any | f32, bf16 | P1 | `LOWERED` | `LOWERED` |
  | prod | static | ≤ 4 | one or all | any | si32 | P2 | `LOWERED` | `LOWERED` |
  | prod | static | 3–4 | partial | no negative | any | P3 | `CONVERSION_FAILED` | `LOWERED` |
  | prod | static | 3–4 | partial | negative | any | P4 | `CONVERSION_FAILED` | `CRASH`, decomposition |
  | prod | static | ≥ 5 | one or all | any | any | P5 | `EXPECTED_REJECTION` | `EXPECTED_REJECTION` |
  | prod | static | ≥ 5 | partial | no negative | any | P6 | `CONVERSION_FAILED` | `EXPECTED_REJECTION` |
  | prod | static | ≥ 5 | partial | negative | any | P7 | `CONVERSION_FAILED` | `CRASH`, decomposition |
  | prod | `?` in the last two | any | any | any | any | P8 | `CRASH`, `TTNNLayout` | `CRASH`, `TTNNLayout` |
  | prod | `?` only before the last two | ≥ 3 | any | any | any | P9 | `CRASH`, `TTNNLayout` | `CRASH`, `TTNNLayout` |
  | sum | static | any | any | any | any | S1 | `LOWERED` | `LOWERED` |
  | sum | `?` in the last two | any | any | any | any | S2 | `CRASH`, `TTNNLayout` | `CRASH`, `TTNNLayout` |
  | sum | `?` only before the last two | ≥ 3 | any | any | any | S3 | `CRASH`, `TTNNLayout` | `CRASH`, `TTNNLayout` |

  `EXPECTED_REJECTION` is `ExpectedRejection "ttnn-prod-rank"`.
- **Edge and error cases:** on P8 and P9 in the pipeline, a partial case with a negative entry crashes in decomposition instead (`expected-outcomes.md:64`). `predictedPass` is a substring of the pass name: `TTNNLayout` or `Decomposition`. **[H]** The second has never been seen in a banner.
- **Tests:** one hand-picked case per row and mode, checked against the table; totality over `enumerate 3`.

## Spec: controls

- **Signature:** `controls :: [Control]`
- **Behaviour:** seven cases covering F1–F8, in id order. F7 and F8 are one case, whose expectation differs by mode only in its row name.

  | Id | Text | Expected in both modes |
  |---|---|---|
  | `F1` | a literal: `ttir.prod` on `tensor<*xf32>`. `ConcreteCase` cannot hold an unranked input | `INVALID` |
  | `F2`–`F6` | `renderCase` of the five `invalidControls` values now in `test/ExecutableOracleSpec.hs`. Move them to `src/` and import them there | `INVALID` |
  | `F7/F8` | `test/golden/o1-shape-prod-rank5.mlir`, from `concretize Rep2`: letters s⁵, `dim_arg` `[4]`, f32 | `ExpectedRejection "ttnn-prod-rank"`; pipeline is F7, bare is F8 |

- **Edge and error cases:** F1's text is not generated, so `V_ttir` has no say on it. Only the tool judges it.
- **Tests:** the F2–F6 ids equal those of the moved values; the F7/F8 text equals the golden.

## Spec: schedule

- **Signature:** `schedule :: Int -> [Scheduled]`
- **Behaviour:** the run order for a rank bound: all of `controls`, then `enumerate` under `Rep2` with all of `controls` again after every 1,000 domain cases, and all of `controls` last. `scheduledSeq` counts from 0.
- **Edge and error cases:** lazy, like `enumerate`. A bound ≤ 0 still gives the controls once each at the start and once at the end.
- **Tests:** the domain cases, in order, equal `enumerate`; 2·9^r·6 of them at each rank; no gap between control rounds exceeds 1,000; two calls render equal bytes.

## Spec: caseJson

- **Signature:** `caseJson :: Scheduled -> ByteString`
- **Behaviour:** one compact line with sorted keys:
  - always `seq`, `caseId`, `kind` (`domain` or `control`);
  - a control adds `control`, its id;
  - a domain case adds `op`, `elementType`, `keepDim`, `rank`, `letters`, `dimArg`, and `rows`, an object of the `predict` row per mode.
- **Edge and error cases:** absent `dim_arg` is null. This is the `cases.jsonl` that [TODO-l3](TODO-l3.md) left for the runner, and it records the link from an id to its abstract case that TODO-l3's Open question 3 asks for.
- **Tests:** a golden for one domain case and one control.

## Spec: observe

- **Signature:** `observe :: Scheduled -> OutcomeLine -> (Double, Double) -> Observation`
- **Behaviour:** keeps what the summary needs from a recorded line: both classifications, the two times, and `outcomeJson` as text.
- **Edge and error cases:** none.
- **Tests:** through `runRepeat`.

## Spec: repeatDifferences

- **Signature:** `repeatDifferences :: [Observation] -> [Observation] -> [Difference]`
- **Behaviour:** one `Difference` per sequence number and mode whose classification differs, including its stage, pass and rejection id. Each control is also compared with its own first occurrence inside each repeat, so a drift within a run counts.
- **Edge and error cases:** both repeats run the same `schedule`, so their lengths match unless a repeat died, and then its exception has already ended the run. A line that differs only in its diagnostic text is not a `Difference`; `renderSummary` counts those lines separately.
- **Tests:** equal lists give none; a changed class, stage, or pass each give one; a drifting control gives one.

## Spec: classCounts

- **Signature:** `classCounts :: Facet -> Mode -> [Observation] -> [(Text, [(Text, Int)])]`
- **Behaviour:** over domain cases only, one row per facet value, counting by `class` from L5's schema, `UNEXPLAINED` included. Facet values:

  | Facet | Values |
  |---|---|
  | `ByRank` | each rank |
  | `ByMarks` | `absent`, `one`, `partial`, `all-listed`, each split by `no-negative` and `negative` |
  | `ByLetters` | `static`, `? in last two`, `? before last two` |
  | `ByElementType`, `ByOp`, `ByKeepDim` | each value |

- **Edge and error cases:** a count of zero is still printed for a class seen elsewhere in the run. Each row sums to the number of domain cases with that value.
- **Tests:** a hand-made list per facet.

## Spec: predictionCounts

- **Signature:** `predictionCounts :: [Observation] -> [(Text, Mode, Prediction, [(Text, Int)], [Text])]`
- **Behaviour:** per row and mode, the prediction, the observed classes with counts, and the `caseId` of the first case for each observed class that differs from the prediction. A class that matches but whose pass does not contain `predictedPass` is counted as `<class>, other pass`.
- **Edge and error cases:** a row with no cases, such as P5 at a bound of 4, appears with no counts and is marked `not run`, never as a pass.
- **Tests:** a hand-made list with a match, a class mismatch, a pass mismatch and an empty row.

## Spec: confusionMatrix

- **Signature:** `confusionMatrix :: [Observation] -> [((Text, Text), Int)]`
- **Behaviour:** over controls only, a count per pair of expected class and reported class, from every occurrence, mode and repeat. Reported classes include `UNEXPLAINED`.
- **Edge and error cases:** the expected class comes from `controlExpected`, so it is the frozen table's label, not independent ground truth.
- **Tests:** a hand-made list; the counts sum to controls × modes × occurrences.

## Spec: verdictA

- **Signature:** `verdictA :: [Observation] -> [Difference] -> Verdict`
- **Behaviour:** `initial-spike.md:48`: `Met` if any `Difference` exists, or any domain case in any mode is a failure whose class differs from its prediction. A failure is any class other than `LOWERED`, and `UNEXPLAINED` is one. The `Text`s name each kind, with a count and a first witness.
- **Edge and error cases:** `LOWERED` where a failure was predicted does not meet the condition as written, and is listed in the summary as `predicted failure did not occur` (Open question 4).
- **Tests:** each of: none, a difference, an outside failure, an `UNEXPLAINED`, a surprise `LOWERED`.

## Spec: verdictF

- **Signature:** `verdictF :: [Observation] -> Verdict`
- **Behaviour:** `initial-spike.md:94`: `Met` if any occurrence of F1–F6 is reported as `CONVERSION_FAILED` or `OUTPUT_INVALID`, in either mode.
- **Edge and error cases:** F7/F8 are not invalid, so they cannot meet it. A `CRASH` on an invalid control does not meet this condition, but it fails the 100% bar at `initial-spike.md:22,110`, which `renderSummary` reports as a separate line.
- **Tests:** each of F1–F6 in each of the two classes; `CRASH`; F7/F8 as `CONVERSION_FAILED`.

## Spec: renderSummary

- **Signature:** `renderSummary :: Manifest -> Text -> Int -> [Observation] -> [Observation] -> Text`
- **Behaviour:** the whole of `summary.md`, from the manifest, run id, rank bound and both repeats:
  1. Pin, oracle `V_ttir`, generator SHA, domain hash, rank bound, representative, and the domain count against 2·9^r·6.
  2. Repeat differences: the count, then all of them, or `none`. Separately, lines differing only in diagnostic text.
  3. Exp A and Exp F verdicts, each condition on its own line, plus the 100% bar.
  4. `classCounts` for each facet and mode. Every table is headed `V_ttir`.
  5. `predictionCounts`, in the frozen file's order. A session fills the Result column from this.
  6. The confusion matrix, then each control's own counts.
  7. Every `UNEXPLAINED`, grouped by reason, with a count, its stage and a first witness. Every domain case reported `INVALID`, which contradicts architecture row A.
  8. Time per case: minimum, median and maximum, per mode, overall and per class.
  9. The reproduce command for each first witness, as `shellCommand`, with the note on relative paths from `summarySection`.
- **Edge and error cases:** an `UNEXPLAINED` is never counted as a gap or as `INVALID`. Section 2 comes first because a difference voids the rest (`initial-spike.md:98`). Counts come from repeat 1, since a difference makes them moot, and the summary says so.
- **Tests:** a snapshot on a hand-made run (architecture row G); content checks for an empty section printing `none`.

## Spec: runRepeat

- **Signature:** `runRepeat :: SliceEnv -> FilePath -> [Scheduled] -> IO [Observation]`
- **Behaviour:** `envFolder` is the top folder, and the `FilePath` is the repeat's. Per scheduled case, in order and one at a time: write `cases/case_<id>.mlir` if it is new; `runCase` with `sliceOptions` in `Bare`, then `Pipeline`, timing each with `getMonotonicTime`; make the line with `modeEntry` and `envRejections`; `appendOutcome`, append both step commands to `commands.txt` and the times to `timings.jsonl`.
- **Edge and error cases:** a tool that cannot start is a recorded `UNEXPLAINED`, as in `runSlice`. An IO failure on a results file propagates: a lost result must not look like a recorded one. Each line is on disk before the next case starts.
- **Tests:** a stand-in `/bin/sh` tool, as in `SliceSpec`, with a bound of 1.

## Spec: runExhaustive

- **Signature:** `runExhaustive :: [String] -> IO ExitCode`
- **Behaviour:** `["--max-rank", n]`, in this order:
  1. `resolveTool TtmlirOpt`.
  2. Read `data/rejections-tt-mlir-f9dc1b3e5101.json`.
  3. Take the git SHA from `git rev-parse HEAD`.
  4. Create the folder. Write `manifest.json`, `tool-version.txt`, `invocation.txt` and `cases.jsonl`.
  5. `runRepeat` twice, into `repeat-1` and `repeat-2`.
  6. `repeatDifferences`, then write `summary.md`.
  7. Print where the results are.
- **Edge and error cases:**

  | Condition | Exit | When |
  |---|---|---|
  | a missing tool, an unreadable data file, or `n` not ≥ 1 | 2, naming the cause | before any folder is made |
  | `git status --porcelain -- src app lower-audit.cabal cabal.project` is not empty, so the SHA would misdescribe the generator | 2 | before any folder is made |
  | `ttmlir-opt --version` does not exit 0 | 2 | before any folder is made |
  | the two repeats differ (`initial-spike.md:98`) | 3; the summary is still written | at the end |
  | a gap, or a falsified prediction | 0: a finding, not a failure | at the end |

- **Tests:** the executable on a stand-in tool: both repeats and every file in the folder table; a tool whose answer changes between calls gives 3; each exit 2 makes no folder.

## Spec: main

- **Signature:** `main :: IO ()`
- **Behaviour:** `"run" : rest` goes to `runExhaustive rest`, and anything else to `runCommand`. This changes [TODO-l5](TODO-l5.md)'s entry. The usage text in `runCommand` names `slice` and `run`.
- **Edge and error cases:** none. The tests at `test/SliceSpec.hs:378-385` only need the usage to name `slice`, so they still hold.
- **Tests:** those, plus one naming `run`.

## Decisions

- **The request is applied to D0-tt, as in L2–L5, because the tool and the frozen file cannot take it as written.** If you do want the TOSA domain, see Open question 1.

  | The request says | Why it cannot apply | Here |
  |---|---|---|
  | D0 | Superseded by D-010 (D-005). **[F]** `ReduceOp` is `Prod` or `Sum`, and `renderOpName` only knows TTIR | D0-tt (D-013) |
  | V_tosa1.0 and V_mlir, per oracle | D-014: neither applies to this domain | V_ttir only; every table says so |
  | `mlir-opt --version` | **[M]** `mlir-opt` has no TTIR dialect ([TODO-l4](TODO-l4.md)) | `ttmlir-opt --version` |
  | Ranks 1–6 and up to rank 4 | Those bounds belong to D0's oracles | `--max-rank`, with no default (Open question 2) |
  | Axis role | D0's single axis mark. D-013 replaced it with a set of marks | `ByMarks` |
  | `results/<run-id>-d0/` | That names the superseded domain | `results/<run-id>-d0-tt/` (`initial-spike.md:22`) |
  | Result column of `expected-outcomes.md` | **[F]** It has rows for D0-tt only, and is frozen, so TOSA results would have no row | Filled from section 5 of the summary, after a real run |

- **The experiment gets its own module.** `Slice` runs one case and its summary is per case; this needs a run-level one.
- **L5's `outcomes.jsonl` schema does not change.** Repeat number, role and time live beside it, so the byte comparison stays honest and L5's example test holds.
- **Each repeat finishes before they are compared.** The stop rule still applies afterwards, and the full list is what fixing A1 needs.
- **One control round per 1,000 cases.** By arithmetic, about 90 rounds of 7 at a bound of 4, under 1% extra. Enough to catch drift across a long run. The number is free to change.

## Shortcuts

- **One case at a time, no `--jobs`.** Architecture §3 skips a scheduler until a need is measured. Add it if the first timing asks for it; output order must stay fixed.
- **No resume.** An interrupted run is restarted in a new folder. Add it if a run this long is actually lost.
- **One representative.** Exp A names no second one; Exp C and D do.
- **Observations stay in memory.** **[H]** Fine at a bound of 4; not sized for 5.
- **The class is all the CLI tier can see of a match failure.** Exp A's hypothesis says "match failure"; `CONVERSION_FAILED` is the observable form. The reason needs the adapter (Exp B).

## Open questions

1. **D0 on `mlir-opt`?** It is the only version of this that could run here without lifting D-015, and it is what the request literally names. It needs a TOSA generator, a V_tosa1.0 validity step, a new decision entry reversing D-010's effect for this experiment (rules 8 and 10), and new predictions written before running, since none exist. *Spec:* not included.
2. **The rank bound (`problem-statement.md:131`, "not decided").** A bound of 4 leaves P5–P7 with no domain case, so only F7/F8 touch r ≥ 5. A bound of 5 tests them at about nine times the cost. Times are **[H]**: four process starts per case at **[M]** 34 ms each, the median for Homebrew `mlir-opt` on `o1-rank4`. `ttmlir-opt`'s larger pipeline and any crash handling will add to that.

   | Bound | Domain cases | Hours, one repeat, sequential | `outcomes.jsonl`, one repeat, at L5's example line size |
   |---|---|---|---|
   | 4 | 88,560 | at least 3.3 | about 146 MB |
   | 5 | 797,148 | at least 30 | about 1.3 GB |
   | 6 | 7,174,440 | at least 271 | about 12 GB |

3. **What gets committed?** At every bound in the table, `outcomes.jsonl` is over GitHub's 100 MB file limit, and **[M]** each case file takes a 4 KB block. [TODO-l5](TODO-l5.md) Open question 3 is still open. *Spec:* writes everything locally. A likely answer is to track `manifest.json`, `tool-version.txt`, `invocation.txt` and `summary.md`, and to ignore or compress the rest.
4. **Is a surprise `LOWERED` a falsification?** `initial-spike.md:48` says "any failure falls outside the predicted classes", which a lowered case is not. Yet the hypothesis on the line above predicts a rejection at r ≥ 5. *Spec:* follows the wording and reports the case separately.
5. **Mass crashes.** **[F]** P8, P9, S2 and S3 predict a crash for every word with a `?`: 80% of words at r = 4. **[H]** Symbolized stack dumps could dominate run time, and macOS may write a crash report per process. `LLVM_DISABLE_SYMBOLIZATION=1` in the environment would avoid the first. Neither was measured, and both depend on where a lifted D-015 builds the tool.
6. **The pipeline's validity step runs again.** `runCase` runs it per mode (TODO-l5's Shortcuts), so four processes per case, not three. *Spec:* keeps that, since the second is a cheap determinism check. `repeatDifferences` does not compare the two within one line; it could.
7. **The decomposition pass's banner name.** `predictedPass` assumes it contains `Decomposition`. **[H]** Confirm from the first crash; a wrong substring shows as `<class>, other pass`, not a false class.
