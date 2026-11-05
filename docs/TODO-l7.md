# TODO: L7

Component C2 in [architecture §2](design/architecture.md): the listener adapter, on the dated TosaToLinalg record.

**Status:** stubs and tests, plus the four parts the request asks to have written in full: `adapter/CMakeLists.txt`, `main`'s argument handling, `JsonLineWriter` and `dumpPatterns`. Rule 12 still holds: the slice in architecture §3 is proposed, not accepted. Nothing here can run on the target (D-015), and nothing here is evidence about it.

**Labels (rule 6):** **[F]** read from source. **[M]** measured here on Homebrew MLIR 23.1.1. **[H]** hypothesis, not run.

**Citations:** read 2026-11-05. Unmarked paths are at `llvmorg-23.1.1` (`6dfe1677ab8d`), the commit D-001 records and Homebrew's version. Anything marked *(target)* is at LLVM `4efe170d858e`.

## Build and run

```sh
cmake -S adapter -B adapter/build -G Ninja
cmake --build adapter/build
make test
```

`--test-options='-p "listener adapter"'` on `cabal test` runs this group alone. `LOWER_AUDIT_ADAPTER` overrides the binary's default path, `adapter/build/lower-audit-adapter`.

If CMake cannot find MLIR after one retry, stop and say so. Do not build LLVM (D-015).

## Order

Implement these from [TODO-l4](TODO-l4.md) first, since the comparing tests call them: `toolPathFrom`, `tosaProbeTarget`, `stepArgs`, `findTool`, `resolveTool`. Then, in this order. Each step brings the next `TODO` into view:

1. `runConversion`
2. `convertFunction`
3. `buildTarget`
4. `observeMatchFailures`
5. `notifyPatternBegin`
6. `notifyPatternEnd`
7. `notifyMatchFailure`
8. Delete `todo`, `ExitTodo`, the `[[maybe_unused]]` on `events`, and the exit-3 check in `runAdapter` in `test/AdapterSpec.hs`.

Until then, what you see:

| State | Result of the 69 tests in this group |
|---|---|
| Adapter not built, as on CI | all pass, each printing `skipped: adapter not built at ...` |
| Stub adapter built, L4 still stubs | the 13 in `arguments` and `the pattern-name dump` pass; 36 fail on `TODO: resolveTool`; 20 fail on `TODO: runConversion` |
| Stub adapter built, L4's functions written | the same 13 pass; 56 fail on `TODO: runConversion` |

## Schema: `events.jsonl` and the dump

One JSON object per line, ending in a newline. Compact with sorted keys, as `outcomes.jsonl` in [TODO-l5](TODO-l5.md), so equal lines are equal bytes. **[F]** `llvm::json` prints object keys sorted (`llvm/lib/Support/JSON.cpp:790`).

| `kind` | Other fields | Written by | Called from |
|---|---|---|---|
| `pattern-begin` | `op`: the root op's name. `pattern`: the pattern's debug name | `notifyPatternBegin` | `DialectConversion.cpp:2759-2760` |
| `match-failure` | `reason`: the text the pattern gave | `notifyMatchFailure` | the wrapper from `observeMatchFailures`, not the driver (D-018) |
| `pattern-end` | `pattern`. `status`: `success` or `failure` | `notifyPatternEnd` | `DialectConversion.cpp:2798-2799,2829-2830` |
| `registered` | `pattern`. `root`: the root op's name, or null | `dumpPatterns` | on stdout, never in the events file |

**Example,** printed by the throwaway implementation on `test/golden/tosa/unranked-reduce-sum.mlir`:

```json
{"kind":"pattern-begin","op":"tosa.reduce_sum","pattern":"(anonymous namespace)::ReduceConverter<mlir::tosa::ReduceSumOp>"}
{"kind":"match-failure","reason":"unranked tensors not supported"}
{"kind":"pattern-end","pattern":"(anonymous namespace)::ReduceConverter<mlir::tosa::ReduceSumOp>","status":"failure"}
```

**Rules for readers:**

- **Lines come in the order the driver acts:** a begin, any match failures, then an end.
- **Nesting.** **[F]** New IR is legalized inside `onSuccess`, before its end (`DialectConversion.cpp:2821-2830`), so a pattern applied to a generated op appears between its parent's begin and end. No fixture does this.
- **`status: failure` does not always mean the match failed.** **[F]** When a pattern returns success but its new IR cannot be legalized, `PatternApplicator.cpp:229,239` calls both `onSuccess` and `onFailure`, so the listener gets two ends: `DialectConversion.cpp:2829-2830`, then `:2798-2799`. **[M]** A pattern constructed in the throwaway to replace `tosa.add` with `tosa.custom` printed begin, end `failure`, end `failure`, and then the next pattern's begin. Do not remove the duplicate. It is the visible sign of a rollback. *(target)* The structure is the same (`DialectConversion.cpp:2758,2792`; `PatternApplicator.cpp:229,239`). **[H]** Not run there.
- **Every line is flushed as it is written,** so a crash keeps the lines before it. **[F]** The action log does not survive a crash ([TODO-l4](TODO-l4.md)).
- **The file is overwritten on each run,** and exists even when it stays empty, as when the input does not parse.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | converted and verified; the module is on stdout |
| 1 | the input was rejected, the conversion failed, or the output did not verify; nothing on stdout. `mlir-opt` exits 1 for each of these |
| 2 | usage, or an input or events file that cannot be opened; nothing was judged |
| 3 | a stub was reached; goes away with the last stub |

## Spec: runConversion

- **Signature:** `ExitCode runConversion(std::unique_ptr<llvm::MemoryBuffer> input, JsonLineWriter &events)`
- **Behaviour:** what `mlir-opt` does for one input. Each row is what it mirrors:

  | Step | Mirrors |
  |---|---|
  | A `SourceMgr` holding `input`, and a context from `makeRegistry`, threading disabled | `MlirOptMain.cpp:653-657,661` |
  | A diagnostic handler on that `SourceMgr`, alive for the whole run | `MlirOptMain.cpp:682` |
  | Parse a module, with the resource map and parser config `mlir-opt` uses, verifying after the parse | `MlirOptMain.cpp:518-520,526-527` |
  | `loadPassDialects`, after the parse, as the pass manager does when it starts | `Pass.cpp:1053-1061` |
  | `convertFunction` on each `func.func` directly in the module, in order, sharing one `EventListener`. The first failure stops the loop | `Pass.cpp:870-873,887,891`: the adaptor for `func.func(...)`, with threading off |
  | Verify the module | `Pass.cpp:623-642`: the adaptor's own check |
  | Print the way `mlir-opt` prints, with the same flags and resource map and a final newline, on `llvm::outs()` | `MlirOptMain.cpp:627-631` |

- **Edge and error cases:**
  - A parse or verify failure returns `ExitModuleFailed`, with no conversion and an empty events file.
  - Any failure prints nothing on stdout: `mlir-opt` returns before its print (`MlirOptMain.cpp:596`).
  - A `func.func` nested in another op is not visited, matching the pipeline's nesting.
- **Tests:** every test in `fidelity`. `o7-ill-typed.mlir` is the parse failure.

## Spec: convertFunction

- **Signature:** `LogicalResult convertFunction(func::FuncOp func, EventListener &listener)`
- **Behaviour:** `runOnOperation` for one function, in the pass's order:

  | Step | Mirrors in `TosaToLinalgPass.cpp` |
  |---|---|
  | A pattern set and a target for the function's context | `:48-49` |
  | `buildTarget` | `:50-65` |
  | A type converter, with the TOSA conversions | `:67-68` |
  | The public `populateTosaToLinalgConversionPatterns` (`TosaToLinalg.h:49`) | `:71` |
  | `observeMatchFailures` | nothing: see Decisions |
  | A `ConversionConfig` with `listener` set, every other field left alone | `:72` uses the default config, so `listener` is the one difference |
  | `applyFullConversion` on the function | `:72` |
  | Verify the function if that succeeded | `Pass.cpp:623-642`: `--verify-each`, on by default, recursive for this pass (`:629`) |

- **Edge and error cases:**
  - Failure returns `failure()`, and the driver has already reported it.
  - Patterns and the converter are built per function, as in the pass.
  - Do not change `allowPatternRollback`. Its other value is experimental and turns a rollback into a fatal error (`DialectConversion.h:1451-1463`).
- **Tests:** `fidelity` and `begin events`. `o3-dynamic-result.mlir` needs the verify: it converts, then fails verification.

## Spec: buildTarget

- **Signature:** `void buildTarget(ConversionTarget &target)`
- **Behaviour:** the target in `runOnOperation`, every line:

  | `TosaToLinalgPass.cpp` | Sets | **[M]** What notices if it is removed |
  |---|---|---|
  | `:50-51` | linalg, tensor and scf dialects legal | nothing, see below |
  | `:52` | tosa dialect illegal | 45 tests |
  | `:55` | `tosa::ApplyScaleOp` legal | `legal-ops.mlir` |
  | `:56` | `tosa::IfOp` legal | `legal-cond-if.mlir`, on stderr only |
  | `:57` | `tosa::ConstOp` legal | `legal-ops.mlir` |
  | `:58` | `tosa::ConstShapeOp` legal | `legal-ops.mlir`, `resize-attempts.mlir` |
  | `:59` | `tosa::WhileOp` legal | `legal-while-loop.mlir`, on stderr only |
  | `:60` | `tosa::ConcatOp` legal | `legal-ops.mlir` |
  | `:61` | `tosa::SliceOp` legal | `legal-ops.mlir` |
  | `:62` | `tosa::ReshapeOp` legal | `legal-ops.mlir` |
  | `:63` | `tosa::PadOp` legal | `legal-ops.mlir` |
  | `:65` | every op with no entry above legal | 46 tests |

- **Edge and error cases:** **[M]** Removing `:50-51` changes nothing on any fixture, because `:65` already makes those ops legal. Mirror it anyway: the point is the same target, and no test can check that line.
- **Tests:** `fidelity`, by the table above.

## Spec: observeMatchFailures

- **Signature:** `void observeMatchFailures(RewritePatternSet &patterns, RewriterBase::Listener &listener)`
- **Behaviour:** replaces each entry of `patterns.getNativePatterns()`, in place, with a pattern that runs the original and shows its match failures to `listener`. The pass has nothing like it; D-018 says why it is needed and what else was considered.
  - The replacement has the original's root, benefit, generated ops, debug name, debug labels and recursion flag. The driver orders patterns by those (`DialectConversion.cpp:2938-2960,3062-3102`), and events and the action log name them.
  - Its `matchAndRewrite` puts a listener on the rewriter for the length of the original's `matchAndRewrite`, puts the old one back, and returns the original's result unchanged. Upstream makes the same move in debug builds (`PatternApplicator.cpp:214-222`).
  - That listener forwards everything to the one it displaced, which is the driver's own bookkeeping (`DialectConversion.cpp:2154`), and also tells `listener` about match failures. `RewriterBase::ForwardingListener` is the public base (`PatternMatch.h:431`).
- **Edge and error cases:**
  - **[M]** All 56 patterns have a root op, so interface and trait roots do not occur at this pin.
  - A reason the driver raises itself is not seen: it calls its own method directly (`DialectConversion.cpp:1520`).
  - **[M]** Replacing every benefit with 1 changes nothing here, so no test can catch losing them. `tosa.resize` is the only root with several patterns, ties come out in reverse registration order (`DialectConversion.cpp:2975,3090`), and registration is in ascending benefit (`TosaToLinalg.cpp:3035-3040`). Copy the benefit anyway. Reversed benefits are caught, by `resize-attempts.mlir`.
- **Tests:** the unranked control, and `events` on `resize-attempts.mlir`, which has two reasons. `fidelity` on all 18 fixtures shows the wrapper changes no output.

## Spec: notifyPatternBegin

- **Signature:** `void notifyPatternBegin(const Pattern &pattern, Operation *op) override`
- **Behaviour:** writes a `pattern-begin` line. The driver calls this just before it tries the pattern (`DialectConversion.cpp:2759-2760`), and the action log's entry follows (`PatternApplicator.cpp:190,197`), so the two counts should match.
- **Edge and error cases:** `op` is valid here. It may not be by the matching end, which is why only the begin names it.
- **Tests:** `begin events equal the action log's apply-pattern lines`, and `events`.

## Spec: notifyPatternEnd

- **Signature:** `void notifyPatternEnd(const Pattern &pattern, LogicalResult status) override`
- **Behaviour:** writes a `pattern-end` line.
- **Edge and error cases:** the two ends of a rollback are both written, see the schema. No fixture has a rollback.
- **Tests:** `events`.

## Spec: notifyMatchFailure

- **Signature:** `void notifyMatchFailure(Location loc, function_ref<void(Diagnostic &)> reasonCallback) override`
- **Behaviour:** builds the diagnostic, as the debug-only code does (`DialectConversion.cpp:2137-2138`), and writes a `match-failure` line with its text.
- **Edge and error cases:** quotes and newlines in a reason are escaped by the writer. **[F]** Invalid UTF-8 is repaired rather than written raw (`llvm/Support/JSON.h:319-322`). **[M]** Without `observeMatchFailures` this method is never called.
- **Tests:** the unranked control (`TosaToLinalg.cpp:1168`), and `events` on `resize-attempts.mlir` (`TosaToLinalg.cpp:1765,1871`).

## Written in full, for reference

| Part | Mirrors or uses |
|---|---|
| `makeRegistry` | `mlir-opt.cpp:331-332`. Not mirrored: `registerAllPasses` (`:326`), since no pass runs, and `registerAllGPUToLLVMIRTranslations` (`:337`). **[H]** No GPU op reaches this conversion |
| `loadPassDialects` | the pass's dependent dialects (`TosaToLinalgPass.cpp:41-45`), plus `tosa`, which a parse loads on a real run and the dump has no parse to load |
| `dumpPatterns` | `TosaToLinalgPass.cpp:67-68,71`, one line per entry of `getNativePatterns` (`PatternMatch.h:840`), in registration order. **[M]** 56 lines |
| `JsonLineWriter` | `llvm::json`, already linked |
| `parseArgs`, `main` | `openInputFile` as in `MlirOptMain.cpp:824`, so diagnostics name the same path |

## Decisions

- **The target is rebuilt, not reused, because the pass builds it inside `runOnOperation`.** It is a local variable (`TosaToLinalgPass.cpp:49-65`), handed straight to `applyFullConversion` with a default config (`:72`). The struct is in an anonymous namespace (`:38-39`), and `createTosaToLinalg` returns a plain `Pass` (`:78-80`), so no caller can reach the target or supply a config, and a listener cannot be attached. The public part is the pattern population (`TosaToLinalg.h:49`). The cost is a copy that can drift, which is what the fidelity check and CMake's `EXACT` version are for.
- **The request is followed as written, on TosaToLinalg and Homebrew. That makes this a dated record, not a second target (D-012).** The request predates the retarget. Unlike L2–L6, it cannot move to D0-tt: the target's adapter needs tt-mlir's build tree (architecture row C2), which D-015 forbids, and a stub must build. Nothing here says anything about TTIR→TTNN. On retargeting, `buildTarget`, `loadPassDialects`, the populate call and the CMake change (architecture §1 cites the target's lines). **[H]** The rest carries over.
- **"The L3 golden cases" means `test/golden/tosa/`.** L3's goldens are now TTIR forms ([TODO-l3](TODO-l3.md)). **[M]** On all 8, `mlir-opt` and the throwaway adapter both exit 1 with identical stderr, the unregistered-dialect error, so they would pass the check and show nothing. The TOSA forms, added in L4, are the probes L3 was named after.
- **The match-failure reason needs one more stub.** As written, the request cannot work: "a ConversionConfig whose listener writes ... match-failure reason".
  - **[F]** `ConversionPatternRewriterImpl::notifyMatchFailure` is the rewriter's listener (`DialectConversion.cpp:2154`), and its whole body is inside `LLVM_DEBUG` (`:2134-2143`). It never calls `config.listener`, in any build. **[F]** `LLVM_DEBUG` compiles to nothing with `NDEBUG` (`llvm/Support/Debug.h:83-85,119`). *(target)* The same code is at `DialectConversion.cpp:2077-2086`.
  - **[M]** On the throwaway with the listener alone, the unranked control gave begin and end `failure`, and no reason.
  - The test you asked for is kept, so `observeMatchFailures` exists to make it satisfiable. **[M]** With it, the control gives the exact reason and all 18 fixtures stay byte-identical. This is a design addition you did not ask for. D-018 records it as proposed, with the alternative of dropping reasons (Open question 1).
- **Stubs beyond the two named.** The request lists what to stub and what to write in full, and leaves out parsing, running, verifying and printing. STUB's rule decides: anything not listed as written is a stub. They are `runConversion` and `convertFunction`.
- **The fidelity check also compares the exit code and stderr, though the request says output.** Stdout alone cannot judge a failing case. **[M]** 5 of the 18 fixtures print nothing from either tool, so comparing stdout would pass a stub that exits 1. Removing `tosa::IfOp` or `tosa::WhileOp` from the target is caught only on stderr. Stderr also pins the failure's stage and the IR at that point, through `see current operation: %8 = ...`.
- **The test asserts `mlir-opt`'s own result before comparing,** so a wrong path or flag cannot pass with both tools failing alike. The expected exit codes are from **[M]** runs, not predictions.
- **Five fixtures were added to the goldens.** **[M]** The goldens contain only `reduce_sum` and `add`, so alone they check none of the nine `addLegalOp` lines, and no op with several patterns.

  | File | From | Why |
  |---|---|---|
  | `unranked-reduce-sum.mlir` | `tosa-to-linalg-invalid.mlir:63-67` | the unranked control you asked for. **[M]** `mlir-opt` accepts it with no pass and fails on the bare pass |
  | `legal-ops.mlir` | syntax from `mlir/test/Dialect/Tosa/ops.mlir` | seven of the legal ops; lowers, with no pattern attempted |
  | `legal-cond-if.mlir`, `legal-while-loop.mlir` | the same | the other two. **[M]** The bare pass fails on the `tosa.yield` inside, which is not legal; without the line it fails on the outer op instead |
  | `resize-attempts.mlir` | `tosa-to-linalg-resize.mlir:368,427-430` | the one root with several patterns: three attempts in order, two reasons |

- **`beginCount` counts `` `apply-pattern pattern: ``, not `apply-pattern`.** **[F]** Each action logs two lines holding that tag (`ActionLogging.cpp:45,54,74`; `PatternApplicator.h:35,39-41`). **[M]** A plain count would double. It also compares each begin's pattern with the log's, in order. On its own that check cannot see an empty name, because it compares prefixes. `events` can.
- **The action log counts only for the bare pass:** one pass, one conversion per function, with `--mlir-disable-threading` from `stepArgs`, so the order is fixed.
- **A listener changes the driver's path.** **[F]** With one attached, blocks are moved op by op rather than in bulk (`DialectConversion.cpp:1639,2294`). **[F]** `TosaToLinalg.cpp` calls neither path by name, and the fixtures do not show the driver reaching them another way. **[M]** A plain conversion, with no listener and no wrapper, gave the same stdout and stderr as `mlir-opt` on all 18 fixtures, and so did the listener with the wrapper. So this difference is untested here. It could matter on the target, and the fidelity check is what would show it.
- **CMake:**

  | Line | Why |
  |---|---|
  | `LANGUAGES C CXX` | **[M]** `LLVMConfig.cmake:290` pulls in `FindLibEdit.cmake:28`, which needs C. Configure fails without it, after finding MLIR |
  | `EXACT` | the pin. **[M]** Asking for 23.1.2 stops at configure |
  | `MLIR LLVM`, no static `libMLIR*.a` | `MLIR_LINK_MLIR_DYLIB` is set (`MLIRConfig.cmake:24`), and `AddMLIR.cmake:748-758` links the dylib alone in that case. **[M]** `otool -L` shows the two dylibs `mlir-opt` links |
  | `Release` by default | `NDEBUG`, to match the libraries (`LLVMConfig.cmake:20,277`) |

- **The tests were checked** against a throwaway implementation in a scratch copy, since deleted, with a throwaway `LowerAudit.Run` holding only L4's functions these tests call. All 69 passed, none by skipping. Each row below is one change to it:

  | Change | Tests failing, of 69 |
  |---|---|
  | listener alone, no wrapper | 3 |
  | no listener | 28 |
  | wrapper loses the debug name | 14 |
  | listener drops ends | 14 |
  | prints in generic form | 13 |
  | no diagnostic handler | 5 |
  | prints the module after a failure | 4 |
  | reversed benefits | 2 |
  | no verification | 1 |
  | each target line removed | see `buildTarget` |
  | every benefit 1; no `loadPassDialects`; no `:50-51` | **0.** These survive, and are explained in the specs above and in Shortcuts |

  That shows the tests can pass and can fail. It says nothing about the target.

  | Dependency | Used by | Reason |
  |---|---|---|
  | MLIR and LLVM dylibs from Homebrew | adapter | the request; already installed |
  | none new | tests | `aeson`, `bytestring`, `directory`, `filepath`, `process`, `temporary`, `text` are already there |

## Shortcuts

- **One file,** `adapter/main.cpp`. Split it if the implementation makes it hard to read.
- **Stubs have external linkage,** so the compiler does not warn that nothing calls them yet.
- **The adapter's location is in the test module,** because nothing in `src/` runs it yet. Move it when L8 does.
- **Events are checked as `Value`s in the tests.** There is no Haskell type for them until the pattern analyzer (L8).
- **No `-o`.** Stdout is the output. Architecture row C2's `output.mlir` is a redirect.
- **An event names an op by name only,** with no location. Two ops of one name are told apart by order alone.
- **Only the pattern hooks and match failures are written.** `notifyOperationInserted` and the rest keep their empty defaults, so IR changes are not recorded.
- **The bare pass only.** The pipeline's other passes are not observed. Architecture row C2 lists the same open question for the target's decomposition pass.
- **No fixture has nesting or a rollback.** The rollback shape was measured once, on a pattern written for that purpose, and is not pinned by a test.
- **`loadPassDialects` is not tested in the conversion.** **[M]** After parsing TOSA with the full registry, all 15 dialects are already loaded, so removing the call changes nothing here. It stays as the mirror of `TosaToLinalgPass.cpp:41-45`.

## Open questions

1. **D-018: wrap the patterns, or drop reasons?** Wrapping keeps the test you asked for, and Exp B's "with its reason" (`initial-spike.md:23,52,54`), at the price of a shim between the driver and every pattern. Dropping reasons removes `observeMatchFailures`, `notifyMatchFailure` and the `match-failure` kind, and the unranked test would check only `pattern-end` with `failure`. Reasons would then come from reading the source. *Stub:* wrapping, proposed and not accepted. `initial-spike.md` is unchanged.
2. **Accepting the slice.** Rule 12 still blocks implementation, and the four written parts exist because the request names them. They run no conversion. *Stub:* nothing changed in architecture §3 or `STATUS.md`.
3. **Does comparing stderr go too far?** It makes the check stricter than the request's "output", and ties it to `mlir-opt`'s diagnostic format. Both are the same library at this pin, so **[M]** it holds. If `ttmlir-opt` adds handlers of its own, the target's check may have to relax it. *Stub:* compared.
4. **Could the adapter's verify step answer [TODO-l4](TODO-l4.md)'s Open question 1?** It separates a verifier failure from a pass's own op error, which the CLI cannot. **[H]** Nothing uses it yet. *Stub:* events do not record which step failed.
5. **What should L8 do with two ends in a row?** They are the only rollback sign found. **[M]** Measured once. It could settle "rollback attribution" (architecture row C2), but only if D0-tt has a rollback, which Exp B doubts (`initial-spike.md:57`). *Stub:* written as delivered.
