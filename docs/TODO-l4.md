# TODO: L4

Component C1 and the classifying half of component D in [architecture §2](design/architecture.md).

**Status:** stubs, tests, fixtures and data files. Rule 12 still holds: the slice in architecture §3 is proposed, not accepted.
`ttmlir-opt` cannot run here (D-015), so every test that needs it skips, and no TTIR fixture has been parsed by it.

**Labels (rule 6):** **[F]** read from source. **[M]** measured here on Homebrew `mlir-opt` 23.1.1. **[H]** hypothesis, not run.

**Citations:** read 2026-11-04. Unmarked `.cpp`, `.td`, `.inc` and lit `.mlir` paths are at tt-mlir `f9dc1b3e5101` or LLVM
`4efe170d858e`, whichever repository holds the file. Anything marked *(23.1.1)* is at `llvmorg-23.1.1`.

Implement [TODO-l2](TODO-l2.md) and [TODO-l3](TODO-l3.md) first: the live oracle test uses them. Then, in this order:

1. `LowerAudit.Run`, pure: `toolPathFrom`, `ttmlirTarget`, `tosaProbeTarget`, `stepArgs`
2. `LowerAudit.Run`, IO: `findTool`, `resolveTool`, `runInvocation`, `runValidity`, `runCase`
3. `LowerAudit.Classify`: `isGap`, `lastPassStarted`, `parseRejections`, `validityVerdict`, `classify`

Run with `make test`. Until then, every L4 failure is `TODO: <function>`. Afterwards the `ttmlir-opt` tests still pass with
`skipped: ...` in their output.

## Diagnostics Classify relies on

Copy these exactly. Only the rows under "Listed in data files" may name a documented rejection, and they are not to appear in `src/`.

**In code, at the target's pins:**

| Text | Means | Source |
|---|---|---|
| `error: ` | a diagnostic of error severity, after an optional location | `llvm/lib/Support/SourceMgr.cpp:511-512`; `mlir/lib/IR/Diagnostics.cpp:264` (the default handler) |
| `failed to legalize operation '` | the driver's failure, full conversion | `mlir/lib/Transforms/Utils/DialectConversion.cpp:3323` |
| `failed to legalize operation '`, then `' that was explicitly marked illegal` | the same, partial conversion | `DialectConversion.cpp:3330-3331` |
| `error: '`, then `' op ` | an op-level error, from a verifier or from a pass (Open question 1) | `mlir/lib/IR/Operation.cpp:673` |
| `LLVM ERROR: ` at the start of a line | a fatal error. With `GenCrashDiag` it aborts, so a signal shows it; without, it is exit 1 | `llvm/lib/Support/ErrorHandling.cpp:124,135,137,149-156` |
| `operation being parsed with an unregistered dialect` | the tool lacks the dialect; says nothing about the case | `mlir/lib/AsmParser/Parser.cpp:1512-1514` |
| `custom op '`, then `' is unknown` | the same, in custom syntax | `Parser.cpp:2126` |
| `// -----// IR Dump Before ` at the start of a line, then the pass name | that pass is starting | `mlir/lib/Pass/IRPrinting.cpp:79-80`; `mlir/include/mlir/Pass/PassManager.h:387` (default stream `errs()`); `llvm/lib/Support/raw_ostream.cpp:914-915` (unbuffered) |

The name ends at a space at the pin (`TTNNLayout (ttnn-layout)`) and at a colon on 23.1.1 (`TosaToLinalg: tosa-to-linalg{...}`) **[M]**.

**Listed in data files, not in code:**

| Id | Text | Source | Documented by |
|---|---|---|---|
| `ttnn-prod-rank` | `'ttnn.prod' op Input tensor rank is greater than 4 for reduce(product).` | `lib/Dialect/TTNN/IR/TTNNOps.cpp:6029-6030` | `test/ttmlir/Dialect/TTNN/reduction/negative_reduce_prod_op.mlir:4`; D-017 |
| `tosa-level-rank` *(23.1.1)* | `op failed level check: operand rank(shape) <= MAX_RANK` | `mlir/lib/Dialect/Tosa/Transforms/TosaValidation.cpp:275-276` | `mlir/test/Dialect/Tosa/level_check.mlir:366`, on `tosa.reduce_sum` |
| `tosa-level-dynamic` *(23.1.1)* | `op failed level check: operand shape dimension cannot be dynamic when targeting TOSA specification version 1.0 or below` | `TosaValidation.cpp:909-911` | `mlir/test/Dialect/Tosa/tosa-validation-version-1p0-invalid.mlir:166`, on `tosa.argmax` only |

**Deliberately not relied on:**

- `Assertion failed:`, `PLEASE submit a bug report` and `Stack dump:`. An assert aborts, and LLVM's handler re-raises what it catches
  (`llvm/lib/Support/Unix/Signals.inc:403,433`), so the signal is the evidence.
- Any text in the action log, for classifying. See "The action log cannot name a crash's pass".
- `failed to legalize generated ...` (`DialectConversion.cpp:2642,2908,2922`): debug logging only.

**Flags, and why exit 0 is enough for S2:**

| Item | Source |
|---|---|
| `ttmlir-opt` is `MlirOptMain` | `tools/ttmlir-opt/ttmlir-opt.cpp:21-22` |
| `--mlir-disable-threading` | `mlir/lib/IR/MLIRContext.cpp:58` |
| `--log-actions-to` | `mlir/lib/Debug/CLOptionsSetup.cpp:30` |
| `--mlir-print-ir-before-all` | `mlir/lib/Pass/PassManagerOptions.cpp:41` |
| `--verify-each` defaults on, and verifies after each pass (S1) | `mlir/lib/Tools/mlir-opt/MlirOptMain.cpp:183-186,558`; `mlir/lib/Pass/Pass.cpp:619,638` |
| Full conversion with TTIR illegal (S2's legality part) | `lib/Conversion/TTIRToTTNN/TTIRToTTNNPass.cpp:47,71-72` |
| Pass names, from the definitions | `include/ttmlir/Conversion/Passes.td:45,158`; `include/ttmlir/Dialect/TTNN/Transforms/Passes.td:24`. **[M]** a banner printed the definition's name for `TosaToLinalg`; **[H]** the same for these |

## Spec: toolPathFrom

- **Signature:** `toolPathFrom :: Tool -> Maybe String -> FilePath`
- **Behaviour:** the one place a tool's location is decided. A given value wins. Otherwise `MlirOpt` is
  `/opt/homebrew/opt/llvm/bin/mlir-opt` and `TtmlirOpt` is `ttmlir-opt`.
- **Edge and error cases:** none. The value comes from `LOWER_AUDIT_MLIR_OPT` or `LOWER_AUDIT_TTMLIR_OPT`, read by `resolveTool`.
- **Tests:** `LowerAudit.Run / tool location`.

## Spec: ttmlirTarget

- **Signature:** `ttmlirTarget :: Target`
- **Behaviour:** D-017's commands. Validity has no flags, bare is `--ttcore-register-device --ttnn-layout --convert-ttir-to-ttnn`, and
  pipeline is `--ttir-to-ttnn-runtime-pipeline`.
- **Edge and error cases:** none.
- **Tests:** `LowerAudit.Run / targets`.

## Spec: tosaProbeTarget

- **Signature:** `tosaProbeTarget :: Target`
- **Behaviour:** the [probe table](experiments/initial-spike.md#reconnaissance-probes-run-on-2026-11-01)'s commands on `MlirOpt`.
- **Edge and error cases:** a dated record. It exists so the probes can run; it is not a second target (D-012, D-014).
- **Tests:** `LowerAudit.Run / targets`.

## Spec: stepArgs

- **Signature:** `stepArgs :: Target -> RunOptions -> Step -> FilePath -> [String]`
- **Behaviour:** the arguments after the tool name, in exactly this order: `--mlir-disable-threading`; on a conversion step,
  `--mlir-print-ir-before-all` if `printPassBanners`, then `--log-actions-to=<path>` if `logActionsTo`; the step's flags; the case path.
- **Edge and error cases:** a validity step ignores the banner and log options, since no pass runs.
- **Tests:** `LowerAudit.Run / stepArgs`.

## Spec: findTool

- **Signature:** `findTool :: Tool -> FilePath -> IO (Either Text FilePath)`
- **Behaviour:** `Right` with an executable's path. Otherwise `Left`, with a message naming the path and the tool's environment variable,
  since tests print it as the reason they skipped.
- **Edge and error cases:** a bare name is looked up on `PATH`. An absolute path comes back unchanged.
- **Tests:** `LowerAudit.Run / tool location`.

## Spec: resolveTool

- **Signature:** `resolveTool :: Tool -> IO (Either Text FilePath)`
- **Behaviour:** reads the tool's variable, then `toolPathFrom`, then `findTool`.
- **Edge and error cases:** an empty variable is not pinned.
- **Tests:** indirectly, by every test in `probes` and `executable oracle`.

## Spec: runInvocation

- **Signature:** `runInvocation :: Int -> Maybe FilePath -> FilePath -> [String] -> IO StepResult`
- **Behaviour:** runs one process directly, with no shell, under a wall-clock limit in seconds. Records the command (tool first), how it
  ended, stdout and stderr separately, and the log file named by the second argument, if it exists afterwards.
- **Edge and error cases:**
  - A negative `ExitFailure` becomes `Signalled` with the positive number. The `process` docs define that encoding.
  - Past the limit the process is stopped, the result is `TimedOut`, and output written so far is kept. **[F]** LLVM tools act on SIGTERM
    (`Signals.inc:218,403`).
  - A tool that cannot start is `StartFailed`, not an exception.
  - Output larger than a pipe holds must neither block nor truncate.
  - Bytes that are not UTF-8 must not raise.
  - A missing log is `Nothing`. **[F]** A crash removes it (see below).
- **Tests:** `LowerAudit.Run / runInvocation` and `/ action log`, on `/bin/sh`, so they need no MLIR tool.

## Spec: runValidity

- **Signature:** `runValidity :: FilePath -> Target -> RunOptions -> FilePath -> IO StepResult`
- **Behaviour:** the oracle's step alone: `stepArgs` for `ValidityStep`, on the tool at the first argument, with no log.
- **Edge and error cases:** none beyond `runInvocation`.
- **Tests:** `executable oracle`, and through `runCase`.

## Spec: runCase

- **Signature:** `runCase :: FilePath -> Target -> RunOptions -> Mode -> FilePath -> IO RunRecord`
- **Behaviour:** `runValidity`, then the mode's conversion step only if validity exited 0.
- **Edge and error cases:** anything else leaves `conversionResult` as `Nothing`, so an invalid case never reaches a conversion.
- **Tests:** `probes / O7` for the invalid path, the rest of `probes` for the other.

## Spec: isGap

- **Signature:** `isGap :: OutcomeClass -> Bool`
- **Behaviour:** true for `ConversionFailed`, `OutputInvalid`, `Crash`, `Timeout` (`problem-statement.md:36`).
- **Edge and error cases:** `ExpectedRejection` is not a gap, and is still reported.
- **Tests:** `LowerAudit.Classify / isGap`.

## Spec: lastPassStarted

- **Signature:** `lastPassStarted :: Text -> Maybe Text`
- **Behaviour:** the pass name in the last `IR Dump Before` line of stderr.
- **Edge and error cases:** both banner formats in the table. `IR Dump After` does not count. `Nothing` if there is no banner.
- **Tests:** `LowerAudit.Classify / lastPassStarted`.

## Spec: parseRejections

- **Signature:** `parseRejections :: ByteString -> Either String [DocumentedRejection]`
- **Behaviour:** reads a data file: a JSON list of objects with `id`, `diagnostic`, `stage`, `source` and `documentedBy`, all required.
  `stage` is `verification` or `pass`.
- **Edge and error cases:** refuses an unknown stage, a missing citation and an empty `diagnostic`, which would match every error line.
- **Tests:** `LowerAudit.Classify / parseRejections` and `/ the data files`.

## Spec: validityVerdict

- **Signature:** `validityVerdict :: StepResult -> ValidityVerdict`
- **Behaviour:** what a validity step says about the case. Exit 0 accepts. A non-zero exit with an `error: ` line rejects.
- **Edge and error cases:** `ValidityInconclusive`, with a reason, for a signal, a timeout, a failed start, `LLVM ERROR: `, a non-zero exit
  with no `error: ` line (an unknown flag, a missing input file), and either dialect diagnostic in the table. **[M]** Homebrew `mlir-opt`
  rejected the one TTIR golden tried with the first of those. **[F]** The check is on the dialect, not the case (`Parser.cpp:1508-1514`), so reading it as a rejection would make every case `INVALID`.
- **Tests:** `LowerAudit.Classify / validityVerdict`.

## Spec: classify

- **Signature:** `classify :: [DocumentedRejection] -> RunRecord -> Classification`
- **Behaviour:** the first rule that holds decides.

  **The validity step:**

  | Order | Validity step | Result | Stage |
  |---|---|---|---|
  | 1 | signal, or `LLVM ERROR: ` | `Crash` | `ParseAndVerify` |
  | 2 | timed out | `Timeout` | `ParseAndVerify` |
  | 3 | `ValidityRejected` | `Invalid` | `ParseAndVerify` |
  | 4 | any other non-zero or failed start | `Unexplained` | `ParseAndVerify` |
  | 5 | exit 0, no conversion recorded | `Unexplained` | `Conversion` |

  **The conversion step.** "Pass stage" is `NamedConversion` of `lastPassStarted` on its stderr, or `Conversion` if that is `Nothing`.

  | Order | Conversion step | Result | Stage |
  |---|---|---|---|
  | 6 | exit 0 | `Lowered` | none |
  | 7 | signal | `Crash` | pass stage |
  | 8 | timed out | `Timeout` | pass stage |
  | 9 | failed to start | `Unexplained` | `Conversion` |
  | 10 | `LLVM ERROR: ` | `Crash` | pass stage |
  | 11 | an `error: ` line contains a listed `diagnostic`; the first listed entry wins | `ExpectedRejection` with its id | `Verification` for `verification`, pass stage for `pass` |
  | 12 | an `error: ` line has `failed to legalize operation '` | `ConversionFailed` | pass stage |
  | 13 | an `error: ` line is an op-level error | `OutputInvalid` | `Verification` |
  | 14 | anything else | `Unexplained` | pass stage |

- **Edge and error cases:**
  - A failed validity step decides whatever a conversion record says.
  - A documented text in stderr rescues nothing outside rule 11: not a crash, not a timeout, not a validity failure.
  - A `note:` line never matches rule 11.
- **Tests:** `LowerAudit.Classify`, on hand-written records; `probes`, on real runs. The test "rank 5, not listed" shows no rejection lives in code.

## Decisions

- **The prompt predates the retarget, so it is applied to D0-tt, as in L2 and L3, with three consequences:**

  | The prompt says | Why it cannot apply as written | What is here |
  |---|---|---|
  | The oracle and `mlir-opt` agree | **[M]** `mlir-opt` has no TTIR dialect: it rejected a TTIR golden as unregistered. D-014 defines V_ttir by `ttmlir-opt` | The test runs `ttmlir-opt` and skips when it is missing |
  | Validity steps of each oracle | D-014 keeps one oracle, with no flags | One validity step per target |
  | Probe classes from `expected-outcomes.md` | It has no O rows, only F6 ("like O7"), and it is frozen, so none can be added | Two fixture sets, below |

- **Two fixture sets.** Architecture row C1 says the recorded probes belong to `mlir-opt`, so the probe inputs stay TOSA. Each also has a TTIR form, extending
  L3's goldens, which is the only set `expected-outcomes.md` can label.

  | Probe | TOSA input in `test/golden/tosa/`, `mlir-opt` | Class, **hand-labelled from the probe table** | TTIR form in `test/golden/`, `ttmlir-opt` | Class and row, **from `expected-outcomes.md`** |
  |---|---|---|---|---|
  | O1 | `o1-rank1` to `o1-rank8` | bare `LOWERED`; pipeline `LOWERED` to r = 6, then `EXPECTED_REJECTION` | `o1-shape-prod-rank2`; `o1-shape-prod-rank5` | `LOWERED`, P1; `EXPECTED_REJECTION`, P5 |
  | O2 | `o2-dynamic`, pipeline | `EXPECTED_REJECTION` | `o2-letters-prod-keep` | `CRASH` in `TTNNLayout`, P8 |
  | O3 | `o3-dynamic-result`, bare | `OUTPUT_INVALID` | `o3-letters-prod-dynamic` | `CRASH` in `TTNNLayout`, P8. O3's bug is in `tensor.expand_shape` and does not carry over |
  | O4 | `o1-rank2` with an action log | `LOWERED` | `o1-shape-prod-rank2` with an action log | `LOWERED`, P1 |
  | O5 | `o1-rank2` with `--tosa-to-linalg` | not a class: `Unexplained` | none: a command error with no TTIR form | |
  | O6 | `o6-add-rank0`, `o6-add-broadcast` | `LOWERED` | `control-sum-rank2` | `LOWERED`, S1. Rank 0 has no form in D0-tt |
  | O7 | `o7-ill-typed` | `INVALID` | `o7-ill-typed-prod` | `INVALID`, F6 |

  **[M]** All 27 TOSA commands reproduced the probe table's exit codes and diagnostics when the fixtures were written. No class was
  taken from those runs. The hand labels are not predictions: they come from a table written after running.

- **The action log cannot name a crash's pass.** `expected-outcomes.md` predicts crashes "in decomposition" and "in `ttnn-layout`", and D-017 requires the stage.
  **[F]** The log is a `ToolOutputFile` (`CLOptionsSetup.cpp:100-109`), registered for removal on a signal (`ToolOutputFile.cpp:24`), and the crash
  handler removes it (`Signals.inc:390`). **[M]** Sending SIGABRT during `TosaToLinalg`: the log was 0 bytes while running and gone afterwards, while the
  stderr banner named the pass. So `RunOptions` has `printPassBanners`, and the log stays for Exp B's attempt counts. This flag is not in the prompt or D-017 (Open question 2).
- **`Unexplained` is not an outcome class.** It keeps §3's seven classes, and stops an unrecognised failure from being counted as a gap or as `INVALID`
  (Open question 3). A run that cannot judge the case is not evidence about it.
- **`Stage`:** `problem-statement.md:80` lists "parse and verify, named conversion, conversion, verification". `Conversion` is what remains when no pass can be named.
- **Data files, one per pin:** the two LLVM commits have different diagnostics, and a target must not pick up the other's rejections. They live in `data/`.
- **The executable-oracle sample:** every 97th of `enumerate 3`, under each representative, plus F2–F6. Every generated case should be accepted, so without those
  controls the test could never see a false rejection by the declared side.
- **Tool variables:** `LOWER_AUDIT_MLIR_OPT` follows the CLAUDE.md rule. `LOWER_AUDIT_TTMLIR_OPT` is the same rule, with no Homebrew default to use.
- **`-threaded`** on the executable and test suite: the `process` docs ask for it when waiting on a process without blocking other threads. **[M]** The timeout test
  also passed without it on a throwaway implementation, so this is a precaution, not a shown need. The rest of the suite was checked only with it on.
- **The tests were checked** against a throwaway implementation in a scratch copy, since deleted: all 151 L4 tests selected passed on it, 14 of them by skipping, and one
  more added afterwards passed in a rerun of `LowerAudit.Run`. That shows they can pass; it says nothing about the target.

  | Dependency | Used by | Reason |
  |---|---|---|
  | `process`, `directory` | library | running tools, finding them, reading logs; both ship with GHC |
  | `aeson` | library, test | data files, findings; already used |
  | `directory`, `filepath` | test | paths and folders; both ship with GHC |
  | `temporary` | test | scratch folders; already in the plan through `tasty-golden` |

## Shortcuts

- **One process per step, with no batching** (architecture row C1), for crash isolation. Its cost is untimed (R9).
- **No `outcomes.jsonl`.** The slice writes it (L5).
- **The rejection list is an argument.** Whoever starts a run loads the file for its pin.
- **The O-probe TTIR forms are not a coverage run.** They cover one case per row. Exp A and F are L6.
- **No stage is compared for the TOSA probes,** only the class. The probe table records no stage.

## Open questions

1. **Verifier failure or a pass's own op error (`Operation.cpp:673`; `Pass.cpp:638`).** Both print `error: '<op>' op ...` and exit 1. Nothing in stderr or the action log separates them on the CLI:
   the action has completed in both cases (`Pass.cpp:603-612`). *Stub:* rule 13 calls both `OUTPUT_INVALID`, and a test pins it on an unlisted level check. That
   check is a pass error, so the class is known wrong there. Both classes are gaps, so coverage is unaffected, but the
   class split is what spike row 3 asks about. **[H]** A second run with `--verify-each=false`, or the adapter's explicit verifier (L7), could separate them. How many passes
   in the pipeline emit op errors was not inventoried.
2. **Is `--mlir-print-ir-before-all` acceptable on the runs?** D-017's commands do not include it. **[H]** It only prints, and it needs threading off, which is already so. Not run on
   `ttmlir-opt`. Without it, stage names in `expected-outcomes.md` rows P4, P7, P8, P9, S2, S3 and X2 cannot be checked. **[M]** `--log-actions-to=-` also kept its lines through one abort,
   on stdout, but no source read promises that, and it mixes with the printed IR. *Stub:* the flag, as an option.
3. **`Unexplained` beyond §3.** Should it stay as a separate result? Exp A's "zero unexplained outcomes" (`initial-spike.md:22`) would then be a count of exactly this. *Stub:* yes.
4. **The hand labels for O1–O7.** They are yours to change: nothing frozen backs them. Two are arguable:
   - O1 at r ≥ 7 and O2 in the pipeline are `EXPECTED_REJECTION` here, under a validity step of plain `mlir-opt`. Under the record's V_tosa1.0 they would be `INVALID`, but D-014
     drops that oracle.
   - O2's lit line is on `tosa.argmax`, not `tosa.reduce_sum`. The diagnostic is the same, and the row counts as documented.
5. **Crash rows and the build.** The TTIR tests for O2 and O3 expect `CRASH`, which `expected-outcomes.md:25` makes conditional on tt-mlir having assertions. That build
   type is undecided. Without assertions these tests may fail, and that would be a prediction turning out wrong, not a test to edit.
6. **`findings/executable-oracle.jsonl`:** it is rewritten on each live run and does not exist yet. It is not git-ignored, so findings stay visible. Should it be tracked, or copied into a results folder?
7. **Does exit 0 imply S2 in the pipeline?** The source settles it for the bare pass. **[H]** Nothing after the conversion reintroduces a TTIR op; those passes were not read. *Stub:* stdout is captured
   but not read.
