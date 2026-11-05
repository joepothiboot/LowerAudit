# TODO: L8

Component E in [architecture §2](design/architecture.md): the pattern analyzer, on the states in [problem statement §4](research/problem-statement.md).

**Status:** stubs and tests. Rule 12 still holds: the slice in architecture §3 is proposed, not accepted. The target cannot run (D-015), so every stream in `test/PatternsSpec.hs` is hand-written. Its pattern names are labels, not observations, and nothing here is evidence about TTIR→TTNN.

**Labels (rule 6):** **[F]** read from source. **[M]** measured here. **[H]** hypothesis, not run.

**Citations:** read 2026-11-05 at the target's LLVM `4efe170d858e`, unless marked *(record)*, which is `llvmorg-23.1.1`.

## Order

Run with `make test`, or `cabal test all --test-show-details=direct --test-options='-p "/LowerAudit.Patterns/ || /certificate boundary/"'` for these groups alone.

1. `parseEvents`
2. `parseRegistered`
3. `conversionEnd`
4. `attemptsOf`
5. `analyzeCase`
6. `analyzeDomain`

**Wait for L10:** `certifiedPattern` and `markUnreachable`. No `Certificate` can exist yet, so no test can reach them. Leave both as stubs.

Until then, **[M]** 95 of these 99 tests fail, each on `TODO: <function>`. The other 4 are the certificate boundary. They pass now and must stay green.

## The states

"Case" is one `events.jsonl` plus the case's class. "Domain" is every case given to `analyzeDomain`.

| `PatternState` | A pattern has it on a case when its best attempt is |
|---|---|
| `Registered` | none: no begin on this case |
| `Attempted` | a begin with no end: the process died inside it |
| `MatchFailed` | one failure end |
| `RolledBack` | two failure ends; or a success end, under an enclosing attempt that ended in failure; or a success end in a run whose rewrites were undone |
| `Applied` | a success end in a run with no verdict on its rewrites |
| `Survived` | a success end in a run that kept its rewrites |

The constructors are in the order "best" means, and `Ord` follows it.

| `DomainState` | When |
|---|---|
| `ObservedSurvived` | `Survived` on at least one case |
| `ObservedApplied` | otherwise `Applied` on at least one case |
| `ObservedRolledBack` | otherwise `RolledBack` on at least one case |
| `NotObserved` | otherwise. Holds the conditions it was considered under, possibly none |
| `Unreachable` | never produced by `analyzeDomain`. Only `markUnreachable` can, from a `Certificate` |

The input schema is in [TODO-l7](TODO-l7.md#schema-eventsjsonl-and-the-dump).

## Spec: parseEvents

- **Signature:** `parseEvents :: ByteString -> Either PatternError [Event]`
- **Behaviour:** one `Event` per line of an events file, in order: `pattern-begin` to `PatternBegin op pattern`, `match-failure` to `MatchFailure reason`, `pattern-end` to `PatternEnd pattern status`.
- **Edge and error cases:**
  - An empty file is no events. **[F]** The adapter writes one when the input does not parse.
  - A last line with no newline still counts.
  - Anything else is `MalformedLine n`, counting from 1, for the first bad line: not JSON, truncated, blank, an unknown `kind` or `status`, a missing field, a field of the wrong type, or a `registered` line.
  - A truncated last line is refused rather than dropped, so a damaged file cannot change a state silently.
- **Tests:** `parseEvents`.

## Spec: parseRegistered

- **Signature:** `parseRegistered :: ByteString -> Either PatternError [RegisteredPattern]`
- **Behaviour:** one `RegisteredPattern` per line of `--dump-patterns`, in registration order. A null `root` is `Nothing`.
- **Edge and error cases:**
  - `MalformedLine n` as above, including an absent `root` (the adapter always writes one) and any line whose `kind` is not `registered`.
  - One name twice is `DuplicateRegistration name`. See Shortcuts.
- **Tests:** `parseRegistered`.

## Spec: conversionEnd

- **Signature:** `conversionEnd :: Classification -> ConversionEnd`
- **Behaviour:**

  | Classification | Result | Why |
  |---|---|---|
  | `Lowered` | `KeptRewrites` | |
  | `OutputInvalid` | `KeptRewrites` | the conversion finished, then verification failed: O3's shape |
  | `ExpectedRejection`, stage `Verification` | `KeptRewrites` | the same, documented: P5 in `expected-outcomes.md` |
  | `ExpectedRejection`, any other stage | `UndidRewrites` | |
  | `ConversionFailed` | `UndidRewrites` | **[F]** `DialectConversion.cpp:3415-3419` |
  | `Crash`, `Timeout`, `Unexplained` | `NoVerdict` | the process did not report how it ended |
  | `Invalid` | `NoConversion` | **[F]** the adapter stops before converting |

- **Edge and error cases:** the classification must be the bare mode's, the only one the adapter observes.
- **Tests:** `conversionEnd`.

## Spec: attemptsOf

- **Signature:** `attemptsOf :: ConversionEnd -> [Event] -> Either PatternError [Attempt]`
- **Behaviour:** one `Attempt` per begin, listed in begin order, so a parent comes before what is nested in it. Its pattern and op come from the begin, and its state from the table above.
  - A reason belongs to the innermost attempt open at that point, in the order given.
  - An end closes the innermost open attempt, and must name it.
  - A failure end straight after a first failure end of the same pattern, with nothing between them, is that attempt's second end.
  - A success under any enclosing attempt that ended in failure is `RolledBack`. `MatchFailed` stays `MatchFailed` there.
  - A parent still open at a crash does not roll back what finished inside it.
  - An attempt's reasons do not affect its state.
- **Edge and error cases:**
  - `UnmatchedEnd name`: an end with nothing to close or naming another pattern, a third failure end, a failure end after a success end, or a second end that is not adjacent to the first.
  - `ReasonOutsideAttempt reason`: a reason with nothing open.
  - `OpenAttempt name`: an attempt still open under `KeptRewrites` or `UndidRewrites`, naming the innermost. Only `NoVerdict` allows one.
  - `EventsWithoutConversion`: any event under `NoConversion`.
  - No events is an empty list under any end.
- **Tests:** `attemptsOf`: `one state per stream`, `nesting`, and `a stream the driver cannot have written is refused`.

## Spec: analyzeCase

- **Signature:** `analyzeCase :: [RegisteredPattern] -> CaseRun -> Either PatternError CaseReport`
- **Behaviour:** applies `conversionEnd` and `attemptsOf`, and checks every begin against the dump. `reportStates` has one entry per registered pattern, in registration order: the best state among its attempts, or `Registered`.
- **Edge and error cases:**
  - `UnregisteredPattern name`: a begin names a pattern not in the dump.
  - `RootMismatch name op`: a begin's op differs from the pattern's root. This is Exp B's falsifier (`initial-spike.md:56`). A pattern with no root may begin on any op.
  - Errors from `attemptsOf` pass through unchanged.
- **Tests:** `analyzeCase`.

## Spec: analyzeDomain

- **Signature:** `analyzeDomain :: [RegisteredPattern] -> [CaseReport] -> [DomainEntry]`
- **Behaviour:** one entry per registered pattern, in registration order.
  - `domainCounts`: every `PatternState`, ascending, with the number of cases in which it is this pattern's state. They sum to the number of reports.
  - `domainState`: the table above.
  - `NotObserved` holds one `Considered` per distinct op from this pattern's attempts, in first-seen order. Each has that op's cases in report order and its reasons in first-seen order, both without repeats.
- **Edge and error cases:**
  - No reports: every pattern is `NotObserved []`. That is all the label claims (rule 3).
  - A rolled-back pattern is not `NotObserved`: §4 defines that as "never applied", and it applied. See Decisions.
- **Tests:** `analyzeDomain`, and `from the two files to the domain`, which needs `parseRegistered`, `parseEvents` and `analyzeCase` too.

## Spec: certifiedPattern

Waits for L10.

- **Signature:** `certifiedPattern :: Certificate -> Text`
- **Behaviour:** the debug name of the pattern the certificate is about.
- **Tests:** none can reach it yet.

## Spec: markUnreachable

Waits for L10.

- **Signature:** `markUnreachable :: Certificate -> DomainEntry -> Either CertificateConflict DomainEntry`
- **Behaviour:** the entry with its state set to `Unreachable`, keeping its counts.
- **Edge and error cases:**
  - `CertificateForOtherPattern name`: the certificate names another pattern.
  - `CertificateContradicted state`: the entry is `ObservedSurvived`, `ObservedApplied` or `ObservedRolledBack`. A certificate must not overrule an observation. This is a counterexample to the certificate, to report and not to hide.
- **Tests:** none can reach it yet. L10 adds three once it can mint: both conflicts and the success.

## Decisions

- **The certificate has no constructor at all yet.** `LowerAudit.Rank` declares `data Certificate` empty, so no value of it exists anywhere in the project, and `UnreachableInD` cannot be built without bottom. The request's "cannot be produced here by accident" holds as strongly as it can. It also leaves L10 free to decide what a certificate holds.
  - **For L10:** add the constructor in `LowerAudit.Rank`, leave it unexported, and call it `IssuedCertificate`, so the boundary test keeps its meaning. Corollary 2 is the only sanctioned route ([rank-bound §4](theory/rank-bound.md)), and rule 9 applies to what it records.
  - **The cost:** `markUnreachable` has no test until then.
- **`FromCertificate` is hidden as well, for a different reason.** If `UnreachableInD` could be wrapped directly, a real certificate could be attached to the wrong pattern, or to one that was observed. Hiding it makes `markUnreachable`'s two checks the only way in.
- **The should-fail test uses `-fdefer-type-errors`, not a subprocess.** Each forgery compiles to a value that throws its own compile error when forced, so it runs against the real library with no new dependency. A `ghc` subprocess would need a package database with `aeson` in it, which `cabal test` does not supply.
  - The test asserts the message, so failing for another reason cannot pass. Its open imports are deliberate: with an import list, exporting a constructor would change nothing and the test could never fail.
  - Deferral is confined to `CertificateBoundarySpec`, because anywhere else it would turn a typo into a runtime failure.
  - **[M]** A constructor sharing its type's name cannot be tested this way: GHC 9.10.3 reports `Illegal term-level use of the type constructor` (GHC-01928) as a hard error, deferred or not. That is why the two constructors have their own names.
  - **[M]** The test does see what it should. See the table below.
- **"Survived" reads the case's class, not the final IR.** §4 says "begin/end nesting plus final IR", but architecture §1 avoids parsing MLIR output in Haskell, and the class already says how the run ended.
- **A success end does not mean a pattern's work lasted, and two failure ends are not the only sign of a rollback.** **[F]** When any op fails to convert, the driver undoes every rewrite so far, with no listener call (`DialectConversion.cpp:3415-3419`; on by default, `DialectConversion.h:1417`; *(record)* `DialectConversion.cpp:3471`).
  - This extends [TODO-l7](TODO-l7.md)'s Open question 5, which took the two ends to be the only sign.
  - **[H]** It also bears on the spike's known limit, "D0-tt may contain no rollback" (`initial-spike.md:57`). P3 in `expected-outcomes.md` predicts that T "may apply and roll back" on the bare pass, which would be this kind. The double-end kind remains unconstructed. Neither file is changed here.
- **"Considered" and "attempted" are one observation, so they are one state.** §4 lists both, with the listener's begin as evidence for each. **[F]** The driver sends the begin only once it has decided to run the pattern (`DialectConversion.cpp:2716-2720`; `PatternApplicator.cpp:190-191`), so no stream can show one without the other. `Attempted` stands for both, as in CLAUDE.md's chain of states, and "considered" survives as the name of the conditions `NotObserved` records. See Open question 2.
- **Rolled back everywhere gets its own domain state.** It meets neither "survived" nor §4's "not observed", and merging it into either would misreport the pattern.
- **A stream that contradicts its class is refused, not repaired:** an open attempt on a case that finished, or events on an invalid case. The second matters most, since Corollary 2 is about valid cases.
- **The tests were checked** against a throwaway implementation in a scratch copy, since deleted. **[M]** All 99 passed. Each row below is one change to it. The first run left two changes uncaught, and the tests `siblings stay in begin order` and `a reason between two ends, with a parent open` were added for them.

  | Change | Tests failing, of 99 |
  |---|---|
  | two ends not recognised | 7 |
  | no verdict reads as survived | 5 |
  | a crash reads as undone | 4 |
  | a child ignores a failed ancestor | 3 |
  | whole-conversion undo ignored | 2 |
  | `OUTPUT_INVALID` undoes | 2 |
  | events accepted with no conversion | 2 |
  | applied reads as survived, over the domain | 2 |
  | reasons not deduplicated | 2 |
  | counts drop `Registered` | 2 |
  | a case's state is its first attempt, not its best | 2 |
  | **`UnreachableInD (..)` exported** | 2 |
  | **`Certificate` given an exported newtype constructor** | 2 |
  | each of: a third end accepted; a non-adjacent second end accepted; a child ignores a grandparent; attempts in end order; reasons reversed; an open attempt accepted; a rejection at verification undoes; root unchecked; unregistered unchecked; duplicates accepted; `root` optional; rolled back reads as not observed; case ids not deduplicated; `Considered` drops an op | 1 |

  That shows the tests can pass and can fail. It says nothing about the target.

  | Dependency | Used by | Reason |
  |---|---|---|
  | none new | | `aeson`, `bytestring` and `text` are already in the library |

## Shortcuts

- **A pattern's identity is its debug name,** and a repeated name is refused. Architecture row E lists identity as unresolved. The refusal keeps a duplicate from merging two patterns silently. **[H]** Whether the target's dump has any is unknown. If it does, identify patterns by name and root, since begin events carry the op.
- **No `patterns.jsonl`.** Architecture row E names that output, and the request asks for the computation. Add it with the schema when Exp B runs.
- **No file reading.** Both parsers take bytes, so the caller reads the files.
- **The first error stops a case.** A caller that wants to continue past a bad case has to do so itself.
- **`domainCounts` is a list.** At 1,195,740 cases (problem statement §6) a list per pattern may be slow. **[H]** Never timed. Change the representation inside `analyzeDomain` if a run shows it.
- **Reasons depend on D-018,** which is still proposed. If reasons are dropped, `MatchFailure`, `attemptReasons` and `consideredReasons` go too.

## Open questions

1. **Three failure ends in a row, for one pattern nested in itself.** `begin P, begin P, end failure, end failure, end failure` has two readings: the inner one rolled back and the outer failed to match, or the reverse. Neither survives, so only which attempt carries which label differs. **[F]** It needs a pattern with bounded recursion (`DialectConversion.cpp:2814`). Whether one exists on the target's path is unknown. *Stub:* no test pins it, and four ends are pinned. A reasonable implementation takes the second end as the inner's.
2. **Should §4 keep "considered" as its own row?** See Decisions. *Stub:* one state. `problem-statement.md` is unchanged, since it is your call.
3. **What are "root-op conditions"?** *Stub:* the op's name, the cases, and the reasons. A case id joins to its rank, marks and letters through `cases.jsonl`. Alternatively, `Considered` could hold those features directly, at the price of tying this module to D0-tt.
   - Also, `NotObserved []` covers two different things: the root op never occurring, and a pattern being shadowed by another of the same root. RQ2 may want them apart. Telling them apart needs only other patterns' begins, though a legal op leaves no begin at all.
4. **Does a rolled-back observation contradict a certificate?** Corollary 2 concerns "applied and survives", and §4's "unreachable" concerns "never to apply". They differ for a pattern that only ever rolled back. *Stub:* the stricter reading, a conflict. Decide with L10, and record it in `rank-bound.md`.
5. **Is `OutputInvalid` always "kept"?** [TODO-l4](TODO-l4.md)'s classifier cannot separate a failing verifier from a pass's own op error, and [TODO-l7](TODO-l7.md)'s Open question 4 notes that the adapter's verify step could. If a pattern's own error lands here, a state could read `Survived` when the rewrites were undone. *Stub:* kept, per §3's definition.
6. **What should a certificate carry besides the pattern?** CLAUDE.md declares the oracle per result, and "unreachable in D" is relative to D, so L10's certificate should probably also name the domain, the oracle and the bound N. *Stub:* the type is empty, so nothing is decided.
7. **Accepting the slice.** Rule 12 still blocks implementation. *Stub:* nothing changed in architecture §3 or `STATUS.md`.
