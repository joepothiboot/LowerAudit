# TODO: L5

The vertical slice in [architecture §3](design/architecture.md), with the part of component G it needs.

**Status:** stubs and tests. Rule 12 still holds: the slice in architecture §3 is proposed, not accepted (Open question 1).
`ttmlir-opt` cannot run here (D-015), so the slice's acceptance on the target skips, and nothing here has run on it.

**Labels (rule 6):** **[F]** read from source. **[M]** measured here on Homebrew `mlir-opt` 23.1.1. **[H]** hypothesis, not run.

Implement [TODO-l2](TODO-l2.md), [TODO-l3](TODO-l3.md) and [TODO-l4](TODO-l4.md) first: the slice calls them. Then, in this order:

1. `LowerAudit.Report`, pure: `caseFileName`, `shellCommand`, `modeEntry`, `outcomeJson`, `summaryHeader`, `summarySection`
2. `LowerAudit.Report`, IO: `appendOutcome`, `appendSummary`
3. `LowerAudit.Slice`: `formatRunId`, `sliceFolder`, `sliceCase`, `sliceOptions`, `runSlice`, `runCommand`
4. `app/Main.hs`: `main`

Run with `make test`. Until then, every L5 failure is `TODO: <function>`. Afterwards the `ttmlir-opt` acceptance still passes with
`skipped: ...` in its output, and the `mlir-opt` acceptance runs for real on this machine.

## Schema: `outcomes.jsonl`

One JSON object per line, one line per case, ending in a newline. A line holds both modes. Keys are sorted and the JSON is compact, as in
`domainJson`, so equal lines are equal bytes.

**The line:**

| Field | Type | Meaning |
|---|---|---|
| `caseId` | string | `caseId` of the case text. The case is `case_<caseId>.mlir` in the same folder |
| `modes` | object | exactly the keys `bare` and `pipeline`, each a mode entry |
| `oracle` | string | the validity oracle this result is relative to: `V_ttir`, or `V_mlir` on the dated record |
| `pin` | object, string to string | commit per repository: `tt-mlir` and `llvm` for the target, `llvm` alone on the record |
| `runId` | string | the folder is `<runId>-slice` |

**A mode entry:**

| Field | Type | Meaning |
|---|---|---|
| `class` | string | `INVALID`, `EXPECTED_REJECTION`, `LOWERED`, `CONVERSION_FAILED`, `OUTPUT_INVALID`, `CRASH`, `TIMEOUT`, or `UNEXPLAINED` |
| `conversion` | step, or null | the conversion step; null when validity did not exit 0, since none ran |
| `diagnostics` | array of strings | evidence lines of stderr, validity's first (see `modeEntry`) |
| `pass` | string, or null | the pass, only when `stage` is `named-conversion` |
| `reason` | string, or null | why, only when `class` is `UNEXPLAINED` |
| `rejectionId` | string, or null | the data file's `id`, only when `class` is `EXPECTED_REJECTION` |
| `stage` | string, or null | `parse-and-verify`, `named-conversion`, `conversion` or `verification`; null only for `LOWERED` |
| `validity` | step | the validity step |

**A step:**

| Field | Type | Meaning |
|---|---|---|
| `command` | array of strings | the command as run, tool first |
| `termination` | object | one of the four below |

| `kind` | Other field | From |
|---|---|---|
| `exited` | `code`, integer | `Exited` |
| `signalled` | `signal`, positive integer | `Signalled` |
| `timed-out` | none | `TimedOut` |
| `start-failed` | `reason`, string | `StartFailed` |

**Example.** Written by hand to show the format, with a placeholder id. It is not a result: nothing has run on the target. A test requires this line to equal
`outcomeJson` of its sample, byte for byte, and to be the only line in this file that starts with `{"`.

```json
{"caseId":"0000000000000000000000000000000000000000000000000000000000000000","modes":{"bare":{"class":"CONVERSION_FAILED","conversion":{"command":["ttmlir-opt","--mlir-disable-threading","--mlir-print-ir-before-all","--ttcore-register-device","--ttnn-layout","--convert-ttir-to-ttnn","results/20261105T120000Z-slice/case_0000000000000000000000000000000000000000000000000000000000000000.mlir"],"termination":{"code":1,"kind":"exited"}},"diagnostics":["results/20261105T120000Z-slice/case_0000000000000000000000000000000000000000000000000000000000000000.mlir:2:8: error: failed to legalize operation 'ttir.prod'"],"pass":"ConvertTTIRToTTNN","reason":null,"rejectionId":null,"stage":"named-conversion","validity":{"command":["ttmlir-opt","--mlir-disable-threading","results/20261105T120000Z-slice/case_0000000000000000000000000000000000000000000000000000000000000000.mlir"],"termination":{"code":0,"kind":"exited"}}},"pipeline":{"class":"LOWERED","conversion":{"command":["ttmlir-opt","--mlir-disable-threading","--mlir-print-ir-before-all","--ttir-to-ttnn-runtime-pipeline","results/20261105T120000Z-slice/case_0000000000000000000000000000000000000000000000000000000000000000.mlir"],"termination":{"code":0,"kind":"exited"}},"diagnostics":[],"pass":null,"reason":null,"rejectionId":null,"stage":null,"validity":{"command":["ttmlir-opt","--mlir-disable-threading","results/20261105T120000Z-slice/case_0000000000000000000000000000000000000000000000000000000000000000.mlir"],"termination":{"code":0,"kind":"exited"}}}},"oracle":"V_ttir","pin":{"llvm":"4efe170d858e","tt-mlir":"f9dc1b3e5101"},"runId":"20261105T120000Z"}
```

## Spec: caseFileName

- **Signature:** `caseFileName :: CaseId -> FilePath`
- **Behaviour:** `case_<id>.mlir` (architecture §1).
- **Edge and error cases:** none. A file name only, with no folder.
- **Tests:** `LowerAudit.Report / caseFileName`.

## Spec: shellCommand

- **Signature:** `shellCommand :: [String] -> Text`
- **Behaviour:** the command as one line for `/bin/sh`, whose words `sh` reads back exactly. Words are separated by one space. A non-empty word made only of ASCII
  letters, digits and `_ - . / :` stays bare. Any other word is single-quoted.
- **Edge and error cases:** an empty word, a single quote, a newline, and `$`, `*` and parentheses. `=` is quoted: in a first word it would read as an assignment.
- **Tests:** `LowerAudit.Report / shellCommand`, through a real `/bin/sh`.

## Spec: modeEntry

- **Signature:** `modeEntry :: [DocumentedRejection] -> RunRecord -> ModeEntry`
- **Behaviour:** one mode's run as recorded. `entryClassification` is `classify` with the given list. `entryValidity` and `entryConversion` take each step's command
  and termination. `entryDiagnostics` holds the evidence lines of validity's stderr and then the conversion's: lines containing `error: ` or `Assertion failed:`, or starting `LLVM ERROR: `.
- **Edge and error cases:** no conversion step stays `Nothing`. IR dumps, `note:` lines and stack dumps are dropped. These lines are recorded only: `classify` reads stderr itself,
  and `Assertion failed:` stays out of it ([TODO-l4](TODO-l4.md)).
- **Tests:** `LowerAudit.Report / modeEntry`.

## Spec: outcomeJson

- **Signature:** `outcomeJson :: OutcomeLine -> ByteString`
- **Behaviour:** the schema above: compact, keys sorted, with no trailing newline.
- **Edge and error cases:** a newline inside a diagnostic is escaped, so a line stays one line. `Unexplained` is class `UNEXPLAINED`, with `reason` set.
- **Tests:** `LowerAudit.Report / outcomeJson`. One test reads this file's example.

## Spec: summaryHeader

- **Signature:** `summaryHeader :: OutcomeLine -> Text`
- **Behaviour:** the top of `summary.md`: a title with the run id, the oracle, and each pin entry with its commit, in the line's order.
- **Edge and error cases:** none.
- **Tests:** `LowerAudit.Report / summary`.

## Spec: summarySection

- **Signature:** `summarySection :: OutcomeLine -> Text`
- **Behaviour:** one case in `summary.md`: its id and file name; for each mode, the class, plus the rejection id, stage, pass and reason where the line has them; and the exact
  reproduce commands, as `shellCommand` of each step's recorded command, with a note that relative paths are from the directory the slice ran in.
- **Edge and error cases:** when a mode has no conversion step, it says `no conversion` ran. Layout beyond that is free: tests check content, not format.
- **Tests:** `LowerAudit.Report / summary`.

## Spec: appendOutcome

- **Signature:** `appendOutcome :: FilePath -> OutcomeLine -> IO ()`
- **Behaviour:** appends `outcomeJson` and a newline to `outcomes.jsonl` in the given folder, creating the file if needed.
- **Edge and error cases:** earlier lines are kept. An IO failure propagates: a lost result must not look like a recorded one.
- **Tests:** through `runSlice`.

## Spec: appendSummary

- **Signature:** `appendSummary :: FilePath -> OutcomeLine -> IO ()`
- **Behaviour:** in `summary.md` in the given folder: writes `summaryHeader` if the file is new, then appends `summarySection`.
- **Edge and error cases:** the header appears once however many cases the folder holds.
- **Tests:** through `runSlice`.

## Spec: formatRunId

- **Signature:** `formatRunId :: UTCTime -> Text`
- **Behaviour:** `YYYYMMDDTHHMMSSZ`, in UTC.
- **Edge and error cases:** none. It holds no colon, so it is safe in a path, and it sorts by time.
- **Tests:** `LowerAudit.Slice / the fixed parts`.

## Spec: sliceFolder

- **Signature:** `sliceFolder :: Text -> FilePath`
- **Behaviour:** `results/<run-id>-slice`, relative to where the command runs.
- **Edge and error cases:** none.
- **Tests:** `LowerAudit.Slice / the fixed parts`.

## Spec: sliceCase

- **Signature:** `sliceCase :: Either DomainError ConcreteCase`
- **Behaviour:** the one case the command generates, built with `mkAbstractCase` and `concretize`, not written out: `ttir.prod`, letters `s s s`, `dim_arg` `[2]`, f32, no `keep_dim`, representative 2.
- **Edge and error cases:** `Left` cannot occur for these values, and is still a value rather than a partial match.
- **Tests:** `LowerAudit.Slice / the fixed parts`, and live in the acceptance group.

## Spec: sliceOptions

- **Signature:** `sliceOptions :: RunOptions`
- **Behaviour:** a 60-second limit, banners on, no action log.
- **Edge and error cases:** none.
- **Tests:** `LowerAudit.Slice / the fixed parts`.

## Spec: runSlice

- **Signature:** `runSlice :: SliceEnv -> Text -> IO OutcomeLine`
- **Behaviour:** one case, from text:
  1. Create `envFolder` and its parents.
  2. Write the text to `caseFileName` of its `caseId` in that folder.
  3. `runCase` on that path, with `sliceOptions`, in `Bare` and then in `Pipeline`.
  4. Make the `OutcomeLine` with `modeEntry` and `envRejections`.
  5. `appendOutcome`, then `appendSummary`, and return the line.
- **Edge and error cases:**
  - A class says nothing about whether the slice worked, so a gap or `INVALID` returns normally.
  - A tool that cannot start is a recorded `UNEXPLAINED`, not an exception.
  - The same case twice in one folder gives two lines.
- **Tests:** `LowerAudit.Slice / runSlice on a stand-in tool`, and both acceptance groups.

## Spec: runCommand

- **Signature:** `runCommand :: [String] -> IO ExitCode`
- **Behaviour:** `["slice"]`, in this order:
  1. `resolveTool TtmlirOpt`.
  2. Read `data/rejections-tt-mlir-f9dc1b3e5101.json` with `parseRejections`.
  3. Take the current time for the run id, and use `sliceFolder` of it.
  4. Render `sliceCase`, then `runSlice` with `ttmlirTarget`, oracle `V_ttir`, and `targetPin` as `tt-mlir` and `llvm`.
  5. Print where the results are, and return `ExitSuccess`.
- **Edge and error cases:** exit 2 with a message on stderr, before any folder is made, for each of these:
  - a missing tool: the message is `resolveTool`'s;
  - a data file missing or unreadable: it names the file;
  - a `Left` from `sliceCase`;
  - any other arguments, or none: usage, naming `slice`.

  A gap is a finding, not a failure of the command, so it exits 0.
- **Tests:** `LowerAudit.Slice / lower-audit, the executable, on a stand-in tool`.

## Spec: main

- **Signature:** `main :: IO ()`
- **Behaviour:** passes the arguments to `runCommand`, and exits with its code. Nothing else belongs here.
- **Edge and error cases:** none.
- **Tests:** the same group: those tests run the built executable, with `cwd` and environment set.

## Decisions

- **The request predates the retarget, so it is applied to D0-tt, as in L2 to L4.** It named `mlir-opt`, which has no TTIR dialect ([TODO-l4](TODO-l4.md)), and
  `expected-outcomes.md` has no O rows and is frozen. So there are two acceptance groups, using L4's two fixture sets:

  | Case | On `ttmlir-opt`: class and stage from `expected-outcomes.md` | On `mlir-opt`: class hand-labelled from the probe table |
  |---|---|---|
  | The generated case, r = 3 (architecture §3) | `LOWERED`, P1 | none: TTIR |
  | O1 at r = 2 | `LOWERED`, P1 | `LOWERED` |
  | O3 | `CRASH` in `TTNNLayout`, P8 | `OUTPUT_INVALID`, bare only |
  | Documented rank 5 (architecture §3) | `EXPECTED_REJECTION`, F7 and F8 | none: its record is r = 7, and is not in the request or §3 |
  | O7's control | `INVALID`, F6 | `INVALID` |

  The `mlir-opt` group is the only live check of the slice here while D-015 holds. It is not a second target (D-012), and its labels are not predictions: they come from a table written after running.
- **The request and architecture §3 name different acceptance cases.** Both sets are tested: they cost one table row each, and every one has a row in `expected-outcomes.md`.
- **O3 in the pipeline on `mlir-opt` is not asserted.** The probe table records `$BARE` only. **[M]** Today it exits 1 with the `tosa-level-dynamic` text, as O2 does. The slice still records it.
- **One line holds both modes,** as the request asks. Exp A's analyses can flatten it; a mode has no meaning without its case.
- **`oracle` is on every line,** since CLAUDE.md declares the oracle per result and a verdict can flip with it.
- **`pin` is a labelled list, not `Pin`.** `Pin` has a required tt-mlir field, so the `mlir-opt` group would have to record a false commit. The target's list comes from `targetPin`.
- **Run id:** a UTC timestamp, so two runs do not mix. Architecture §3 says `<date>`; §1 says `<date>-<target>-<what>`; the request says `<run-id>-slice`, followed here. The id starts with the date.
- **"Exact reproduce command" means the tool's commands,** each step as run, flags included. Re-running `lower-audit slice` makes a new folder, so it reproduces the slice but not a given run.
- **Banners are on,** as in L4's Open question 2. So the recorded commands are D-017's plus `--mlir-disable-threading` and `--mlir-print-ir-before-all`, and the stages in `expected-outcomes.md` can be checked.
- **The slice writes the case under `results/`,** so the recorded commands stay valid after it ends.
- **The summary is appended, not rewritten,** so a folder with several cases keeps them all. Only tests do that today, since the command makes one case per folder.
- **The executable is tested as a process,** through `build-tool-depends`. `cwd` and environment can then be set per test without racing the other tests, and it covers `main`. Those tests run a stand-in `/bin/sh` script
  as the tool. They show the wiring works; they say nothing about the target.
- **The tests were checked** against a throwaway implementation in a scratch copy, since deleted. All 64 L5 tests passed on it: 5 by skipping, and 3 by running `mlir-opt`. L4's `LowerAudit.Run` and `LowerAudit.Classify`
  tests passed with them. Four sabotaged versions each failed (overwriting instead of appending, recording bare as pipeline, ignoring the rejection list, not quoting). **[M]** With `mlir-opt` set as `ttmlir-opt`, all 5 TTIR
  acceptance tests failed with `UNEXPLAINED`, not a false `INVALID`. That shows they can pass and can fail; it says nothing about the target.

  | Dependency | Used by | Reason |
  |---|---|---|
  | `time` | library, test | run id; ships with GHC |
  | `filepath` | library | paths; ships with GHC, already used by tests |
  | `process` | test | runs the executable and `/bin/sh`; ships with GHC, already used by the library |

## Shortcuts

- **No pattern sets.** `outcomes.jsonl` has no `patterns` field, and the acceptance compares class and stage only, not `expected-outcomes.md`'s "Predicted applied patterns" column. That needs the adapter (L7), so this slice says nothing on reachability.
- **No full stderr is kept,** only evidence lines. The reproduce command regenerates the rest.
- **The validity step runs twice per case,** once per mode, because `runCase` runs it. The two are recorded separately. Nothing compares them yet.
- **No `cases.jsonl` or manifest,** so a line does not record the generator's git SHA. Exp A needs both (L6).
- **One case, fixed.** No arguments and no domain. Exhaustive D0-tt is L6.
- **`data/` and `results/` are relative to the working directory,** so the command runs from the repository root.

## Open questions

1. **Accepting the slice.** Architecture §3 is still "proposed", and rule 12 blocks implementation until it is accepted. These are stubs only. Accepting it is your decision to record. *Stub:* nothing changed in architecture §3 or `STATUS.md`.
2. **The first run of `lower-audit slice`.** It targets `ttmlir-opt` only, so on this machine it stops at exit 2 while D-015 holds. The real slice runs here only through the `mlir-opt` acceptance group, and leaves nothing behind. **[M]** On the throwaway, `LOWER_AUDIT_TTMLIR_OPT` set to `mlir-opt` wrote a complete folder whose line says `UNEXPLAINED` at
   `parse-and-verify`, the only honest result for TTIR on that tool. A `--target` flag would need a TOSA case generator, which the record does not justify. *Stub:* no flag.
3. **Is `results/` tracked?** Nothing ignores it. Architecture §1 treats it as output, and `expected-outcomes.md` allows a later "Result" column. *Stub:* left alone. A run leaves it visible in `git status`.
4. **The 60-second limit.** Copied from L4's probes. **[H]** Never timed on `ttmlir-opt`, whose pipeline is larger.
5. **O3 and the build.** `CRASH` in the `ttmlir-opt` acceptance depends on `expected-outcomes.md:25`'s assertion assumption, as in [TODO-l4](TODO-l4.md) Open question 5. Without it the test may fail, and that would be a prediction turning out wrong, not a test to edit.
6. **`sliceCase`'s free choices.** Architecture §3 says "one positive dim". The last position and representative 2 are picked here. Row P1 covers any choice.
7. **`UNEXPLAINED` in the file.** It is an eighth value of `class`, following L4's Open question 3. Readers counting coverage must not treat it as a gap.
