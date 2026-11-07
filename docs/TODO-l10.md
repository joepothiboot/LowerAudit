# TODO: L10

Component F in [architecture §2](design/architecture.md): the rank analyzer, on the model in [rank-bound §4](theory/rank-bound.md).

**Status:** stubs and tests. Rule 12 still holds: the slice in architecture §3 is proposed, not accepted. The target cannot run (D-015), so every outcome function in the tests is synthetic. Nothing here is evidence about TTIR→TTNN, and the committed ledger has every obligation open.

**Labels (rule 6):** **[F]** read from source or from this repo's docs. **[M]** measured here. **[H]** hypothesis, not run.

## Order

Run with `make test`, or `cabal test all --test-show-details=direct --test-options='-p "/LowerAudit.Automaton/ || /LowerAudit.Ledger/ || /LowerAudit.Rank/ || /certificate boundary/"'` for these groups alone.

`LowerAudit.Automaton`:

1. `mkDfa`. Remove the `-Wno-unused-top-binds` pragma at the top of the module once it builds a `Dfa`: only the unused constructor needs it.
2. `alphabet`, `stateCount`
3. `run`
4. `productDfa`
5. `reachableStates`
6. `shortestWord`
7. `isEmpty`

`LowerAudit.Ledger`:

8. `obligationsInDoc`, `requiredIds`
9. `parseLedger`, `ledgerEntries`
10. `readEvidence`

`LowerAudit.Rank`:

11. `empirical`
12. `conditional`, `conditionalBound`
13. `proved`, `provedProof`
14. `certifyUnreachable`, `certifiedPattern`, `certifiedScope`, `certifiedBound`
15. `markUnreachable`, in `LowerAudit.Patterns`
16. `rankReport`, `highestLevel`, `levelName`
17. `renderRankReport`

**[M]** 206 of the 219 tests in these groups fail now, each on `TODO: <function>`. The other 13 are the certificate boundary, 4 of them L8's. They pass now and must stay green.

## The three levels

| Level | Output | Rests on | Refused when |
|---|---|---|---|
| EMPIRICAL | `Empirical`: which letter changes, at which positions, change the outcome, per rank, and where that stopped changing | runs alone. Claims nothing beyond the ranks it looked at (rule 4) | never |
| CONDITIONAL | `Conditional`: N = k · k_V and the verdict below N | a declared abstraction, assumed. "If A1–A5 hold with this abstraction, ranks below N decide" | no abstraction; the abstraction contradicts the runs; too few ranks |
| PROVED | `Proved`: the same bound, with the evidence | CONDITIONAL, plus a ledger entry with evidence for every obligation in [rank-bound](theory/rank-bound.md) | CONDITIONAL refused; anything in the ledger missing, open, refuted or mismatched |

The `Certificate` for "unreachable in D" comes only from a `Proved` about one pattern: Corollary 2.

## Terms

- **Shortlex:** shorter first, then letter by letter in the alphabet's declared order. This is [TODO-l3](TODO-l3.md)'s order if the alphabet is listed by `DimLetter` and then `Mark`, in declaration order.
- **Valid:** `subjectValid` accepts the word. The outcome function is called on valid words only, here and at every level: an invalid case is not run.
- **Violation:** a valid word whose outcome the `Question`'s predicate holds for. `Coverage` questions say "not lowered". `NeverApplies p` questions say "p is in this outcome's patterns". See Decisions.
- **k, k_V, N, D:** the declared state counts of the outcome and validity automata; N = k · k_V; D = 2N − 1.

## Schema: `data/rank-ledger-<pin>.json`

A JSON array of entries, one file per pin, as `data/rejections-*.json`.

| Field | Type | Meaning |
|---|---|---|
| `target`, `conversion`, `domain`, `oracle` | string | the `Scope`, compared exactly. `conversion` holds the mode: bare is not pipeline |
| `states`, `validityStates` | integer or null, required | the k and k_V the evidence is for. Null means not known yet. Absent is malformed |
| `obligations` | array | one object per obligation |
| `obligations[].id` | string | as in rank-bound.md, such as `A3` |
| `obligations[].status` | string | exactly `open`, `discharged` or `refuted`, matching RQ3's "open, yes, no" |
| `obligations[].evidence` | array of strings | citations: `file:line` at the pin, or a results folder. May be empty |

`data/rank-ledger-tt-mlir-f9dc1b3e5101.json` mirrors rank-bound §6's three open rows: the two closures and the pipeline. **To record evidence:** change the status, add the citations and k and k_V, update rank-bound §6, and change the test `the committed ledger leaves PROVED refused today` in the same commit. That test is meant to fail then.

## Spec: mkDfa

- **Signature:** `mkDfa :: (Ord q, Eq a) => [a] -> [q] -> q -> (q -> a -> q) -> (q -> o) -> Either (DfaError q a) (Dfa q a o)`
- **Behaviour:** a DFA with output, from its letters, states, start, step and output. The letter list is the alphabet, and its order is the shortlex order.
- **Edge and error cases:**
  - `DuplicateLetter x`, `DuplicateState q`.
  - `StartNotDeclared q`.
  - `StepLeavesStates q x q'`: the first step out of the declared states, by declared state and then declared letter, not by `Ord`. This is what makes `stateCount` a true k.
  - The step is applied to declared letters only. A letter outside the alphabet may be undefined.
  - No letters is allowed: the language is then the empty word or nothing.
- **Tests:** `mkDfa`.

## Spec: alphabet

- **Signature:** `alphabet :: Dfa q a o -> [a]`
- **Behaviour:** the letters, in declared order.
- **Tests:** `alphabet and stateCount`.

## Spec: stateCount

- **Signature:** `stateCount :: Dfa q a o -> Int`
- **Behaviour:** the number of declared states, reachable or not. This is the k of Theorem 1.
- **Tests:** `alphabet and stateCount`; `the product has k * k' states`.

## Spec: run

- **Signature:** `run :: (Eq a) => Dfa q a o -> [a] -> Maybe o`
- **Behaviour:** the output of the state the word ends in.
- **Edge and error cases:**
  - The empty word gives the start state's output.
  - `Nothing` for a word with any letter outside the alphabet, wherever it is, and the step must not be applied to that letter.
- **Tests:** `run`.

## Spec: productDfa

- **Signature:** `productDfa :: (Eq a) => Dfa q a o -> Dfa r a p -> Either (AlphabetMismatch a) (Dfa (q, r) a (o, p))`
- **Behaviour:** the synchronous product. Its output is the pair of outputs, its alphabet is the operands', and it has k · k' declared states.
- **Edge and error cases:** `AlphabetMismatch left right` unless the two alphabets are equal as lists. The same letters in another order are refused, since shortlex would be ambiguous.
- **Tests:** `productDfa`, including the law: on every word to rank 5, the product accepts exactly what both accept.

## Spec: reachableStates

- **Signature:** `reachableStates :: (Ord q) => Dfa q a o -> [q]`
- **Behaviour:** the states some word reaches, including the start, ascending by `Ord`, without repeats.
- **Tests:** `reachableStates`.

## Spec: shortestWord

- **Signature:** `shortestWord :: (Ord q) => (o -> Bool) -> Dfa q a o -> Maybe [a]`
- **Behaviour:** the first word in shortlex order whose output satisfies the predicate. `Nothing` if there is none.
- **Edge and error cases:**
  - The empty word comes first when the start state's output satisfies it.
  - Length comes before letters: with both accepted, `b` comes before `aa`.
  - Only reachable states count.
  - The word found is always shorter than `stateCount`: Theorem 1's step 3.
- **Tests:** `shortestWord`, including brute-force comparison on random automata and on products.

## Spec: isEmpty

- **Signature:** `isEmpty :: (Ord q) => (o -> Bool) -> Dfa q a o -> Bool`
- **Behaviour:** whether no word's output satisfies the predicate. An accepting state no word reaches does not count.
- **Tests:** `isEmpty`, including brute-force comparison up to the state count.

## Spec: obligationsInDoc

- **Signature:** `obligationsInDoc :: Text -> Either LedgerError Required`
- **Behaviour:** from the text of rank-bound.md, one id per Markdown table row whose first cell is exactly `A` followed by one or more digits, in document order.
- **Edge and error cases:**
  - Prose, and rows such as `S1`, `A1–A5 for the closure` or `A3′`, are not obligations.
  - `NoObligationsInDoc`: none found. A restructured document must close the gate, not open it.
  - `RepeatedInDoc i`: the first id seen twice.
- **Tests:** `obligationsInDoc`, including one on the real file, which fails if §4's table changes.

## Spec: requiredIds

- **Signature:** `requiredIds :: Required -> [ObligationId]`
- **Behaviour:** the ids, in document order.
- **Tests:** through `obligationsInDoc`.

## Spec: parseLedger

- **Signature:** `parseLedger :: ByteString -> Either LedgerError Ledger`
- **Behaviour:** the schema above, keeping file order.
- **Edge and error cases:**
  - `MalformedLedger message`: not JSON, truncated, not an array, a missing or mistyped field, or an unknown `status`. Tests do not read the message. An unknown status must never read as `discharged` or `open`.
  - `RepeatedScope scope`: two entries for one scope.
  - `RepeatedObligation scope i`: one id twice in an entry, since one of the two lines would be ignored. The same id in two scopes is fine.
  - An empty array is a ledger with no entries.
- **Tests:** `parseLedger`, and `the committed ledger`.

## Spec: ledgerEntries

- **Signature:** `ledgerEntries :: Ledger -> [LedgerEntry]`
- **Behaviour:** the entries, in file order.
- **Tests:** through `parseLedger`.

## Spec: readEvidence

- **Signature:** `readEvidence :: FilePath -> FilePath -> IO (Either LedgerError (Required, Ledger))`
- **Behaviour:** reads the document and then the ledger, and parses both. The arguments are the document's path and the ledger's.
- **Edge and error cases:**
  - Every failure is a `Left`, never an exception, so PROVED is refused rather than the program crashing.
  - `Unreadable path`: a missing or unreadable file, naming that file, or a document that is not UTF-8.
  - The document is UTF-8 whatever the locale. **[F]** rank-bound.md is not ASCII.
  - The document's error comes first if both are bad. Errors from the two parsers pass through.
- **Tests:** `readEvidence`.

## Spec: empirical

- **Signature:** `empirical :: (Eq a, Eq o) => Natural -> Subject a o -> Empirical a o`
- **Behaviour:** the first argument is the window. One `RankProfile` per rank from 1, stopping as below. Rank 0 is left out, as in problem statement §6.
  - `profileOutcomes`: the distinct outcomes of the rank's valid words, in first-seen shortlex order.
  - `profileChanges`: one `LetterChange (x, y) positions` per letter pair with at least one position, where x comes before y in the alphabet, in that order. A position p, counted from 0 and ascending, is listed when some two valid words of this rank that differ only at p, with x there in one and y in the other, have different outcomes.
  - **A profile extends the previous one** when all three hold: the same outcomes as a set; the same letter pairs; and for each pair, its positions as a mask over this rank reduce to the previous mask by deleting one position.
  - **Stop:** at the first rank R where the last `window` steps all extend. `StableFrom (R - window)`, with profiles to R.
  - Otherwise, at `subjectMaxRank`: `NotStableBy subjectMaxRank`, with every profile to it.
- **Edge and error cases:**
  - Window 0: `StableFrom 1` after rank 1.
  - `subjectMaxRank` below 1: no profiles, `NotStableBy subjectMaxRank`.
  - A rank with no valid word: no outcomes, no changes.
  - A pair across the validity boundary is not a change, and the invalid word is not run.
- **Tests:** `EMPIRICAL`, including a property against a direct reading of this definition.

## Spec: conditional

- **Signature:** `conditional :: (Eq a, Eq o) => Question o -> Maybe (Abstraction a o) -> Subject a o -> Either (ConditionalRefusal a o) (Conditional a)`
- **Behaviour:** with R = `subjectMaxRank`, in this order:
  1. `NoAbstraction` if none is declared.
  2. `AlphabetDiffers outcome validity` if the two automata's alphabets differ. `AlphabetDiffers declared subject` if they differ from `subjectLetters`. Equal as lists.
  3. Every word of rank up to the smaller of D and R, in one shortlex walk that stops at the first disagreement:
     - `ValidityDisagrees w answer`: the validity automaton differs from `subjectValid`, whose answer this is.
     - `OutcomeDisagrees w declared observed`: the word is valid, and the outcome automaton differs from `subjectOutcome`.
  4. `RanksShort n d r` if R is below D, with N, D and R.
  5. Otherwise a `Conditional`, whose `Bound` has k, k_V, N, D, the question's claim and the verdict: `ViolatedAt w` for the shortlex-first violation, or `HoldsBelowBound`.
- **Edge and error cases:**
  - The outcome automaton is free on invalid words, and the outcome function is not called on them.
  - N counts declared states, including ones no word reaches, as Theorem 1 states k. See Open question 2.
  - Rank 0 is walked. On a domain without it, the validity automaton rejects the empty word.
  - An enormous N must return at once: nothing past R may be looked at.
  - A disagreement within R outranks `RanksShort`.
- **Tests:** `CONDITIONAL`, and `equal counts of two letters is refused above EMPIRICAL`.

## Spec: conditionalBound

- **Signature:** `conditionalBound :: Conditional a -> Bound a`
- **Behaviour:** the facts inside. `Bound` is a plain record, and only `conditional` can wrap one.
- **Tests:** through `conditional`.

## Spec: proved

- **Signature:** `proved :: Scope -> Required -> Ledger -> Conditional a -> Either ProvedRefusal (Proved a)`
- **Behaviour:** in this order:
  1. `NoLedgerEntry scope` if no entry has exactly this scope.
  2. `ObligationsUnmet problems` if any exist. `problems` has one item per required id with a problem, in document order, then one `NotInDoc i` per ledger-only id, in ledger order:
     - `MissingFromLedger i`
     - `StillOpen i`, whatever evidence it holds
     - `RefutedObligation i`, whatever evidence it holds
     - `NoEvidenceRecorded i`: discharged, with no evidence or only blank strings
  3. `AbstractionNotRecorded` if k or k_V is null.
  4. `AbstractionDiffers (recorded k, recorded k_V) (declared k, declared k_V)` unless they are equal.
  5. Otherwise a `Proved`, whose `Proof` has the bound unchanged, the scope, and each required id with its evidence, in document order.
- **Edge and error cases:**
  - An entry listing nothing is not vacuous: every id is missing.
  - A row added to rank-bound.md closes the gate with no code change. A row removed does too, until the ledger follows.
  - A verdict of `ViolatedAt` still proves: the conclusion is then a minimal gap.
  - Only one entry is read: another scope's evidence does not count.
- **Tests:** `PROVED`, and `the committed ledger leaves PROVED refused today`.

## Spec: provedProof

- **Signature:** `provedProof :: Proved a -> Proof a`
- **Behaviour:** the facts inside. `Proof` is a plain record, and only `proved` can wrap one.
- **Tests:** through `proved`.

## Spec: certifyUnreachable

- **Signature:** `certifyUnreachable :: Proved a -> Either (CertificateRefusal a) Certificate`
- **Behaviour:** Corollary 2. A claim of `NeverApplies p` with a verdict of `HoldsBelowBound` gives a certificate holding p, the scope and N.
- **Edge and error cases:**
  - `NotAboutAPattern`: the claim is `Coverage`. Coverage is not reachability.
  - `PatternApplies w`: the verdict is `ViolatedAt w`.
- **Tests:** `the certificate, from Corollary 2`.

## Spec: certifiedPattern

- **Signature:** `certifiedPattern :: Certificate -> Text`
- **Behaviour:** the debug name of the pattern.
- **Tests:** `the certificate, from Corollary 2`.

## Spec: certifiedScope

- **Signature:** `certifiedScope :: Certificate -> Scope`
- **Behaviour:** the target, conversion, domain and oracle it holds for.
- **Tests:** `the certificate, from Corollary 2`.

## Spec: certifiedBound

- **Signature:** `certifiedBound :: Certificate -> Int`
- **Behaviour:** the bound N.
- **Tests:** `the certificate, from Corollary 2`.

## Spec: markUnreachable

In `LowerAudit.Patterns`. This is [TODO-l8](TODO-l8.md#spec-markunreachable)'s entry, which waited for a certificate to exist, with the two points it left open now pinned.

- **Signature:** `markUnreachable :: Certificate -> DomainEntry -> Either CertificateConflict DomainEntry`
- **Behaviour:** the entry with its state set to `Unreachable`, holding this certificate, and its pattern and counts kept.
- **Edge and error cases:**
  - `CertificateForOtherPattern name`: the certificate names another pattern. `name` is the certificate's. This check comes first, since a contradiction means something only for the same pattern.
  - `CertificateContradicted state`: the entry is `ObservedSurvived`, `ObservedApplied` or `ObservedRolledBack`. A certificate must not overrule an observation. See Open question 6.
- **Tests:** `markUnreachable`, under the certificate group: the three L8 promised, once for each contradicting state, and the order of the two checks.

## Spec: rankReport

- **Signature:** `rankReport :: (Eq a, Eq o) => RankInput a o -> RankReport a o`
- **Behaviour:** all three outputs:
  - `reportEmpirical`: `empirical` with the window and subject.
  - `reportConditional`: `conditional` with the question, abstraction and subject.
  - `reportProved`, in this order: `NoConditionalBound` if CONDITIONAL was refused; `EvidenceUnusable e` if the evidence is a `Left e`; otherwise `proved`.
- **Edge and error cases:** a refused level never removes a lower one.
- **Tests:** `rankReport`; `equal counts of two letters is refused above EMPIRICAL`; `known limits`.

## Spec: highestLevel

- **Signature:** `highestLevel :: RankReport a o -> Level`
- **Behaviour:** `ProvedLevel` if PROVED holds, otherwise `ConditionalLevel` if CONDITIONAL holds, otherwise `EmpiricalLevel`.
- **Tests:** `highestLevel`.

## Spec: levelName

- **Signature:** `levelName :: Level -> Text`
- **Behaviour:** `EMPIRICAL`, `CONDITIONAL`, `PROVED`.
- **Tests:** `levelName gives the three labels`.

## Spec: renderRankReport

- **Signature:** `renderRankReport :: (Show a, Show o) => RankReport a o -> Text`
- **Behaviour:** exactly three lines, in the order EMPIRICAL, CONDITIONAL, PROVED, each starting with its label and a colon.
  - EMPIRICAL says `stable from rank R` or `not stable by rank R`. It must not contain `N =`, or any of `bound`, `proved`, `certif`, `all ranks`, `every rank` in any case (rule 4).
  - A refused level starts `LABEL: REFUSED`, and gives the reason.
  - CONDITIONAL, when it holds, gives `N = `, `k = ` and `k_V = `.
  - CONDITIONAL refused by `RanksShort` still gives `N = `.
  - PROVED, when it holds, gives `N = `. Refused by obligations, it names their ids.
- **Tests:** `renderRankReport`. The rest of the wording is open: see Open question 9.

## Decisions

- **The PROVED label is gated by the ledger, and is not computed.** This is the point of the level.
  - **No run can establish what PROVED claims.** Theorem 1 assumes A1–A5, and A2 and A3 are statements about the C++ on every path at every rank (D-006). A computed label could only look at finitely many ranks. For any such number there is a function that agrees with a small automaton up to it and is not regular. **[M]** `known limits` holds one: `hiddenGuard` is equal counts from rank 12, and agrees with a one-state automaton below that. Any rule computed from those ranks would either pass it or refuse everything. Chow's result has the same shape: a finite suite is complete only given a state bound, and that bound is the thing in question (rank-bound §4). Rule 4 forbids the shortcut.
  - **The evidence is not in this process.** The target's source is not in the repo, and nothing here reads C++. **[F]** rank-bound §4's Check column asks for repeated runs and adapter fidelity for A1 and A4, and for reading the source for A2, A3 and A5. Haskell sees only strings that name those.
  - **The gate computes what can be computed:** that the obligation list comes from rank-bound.md, so a new row closes the gate with no code change; that each obligation is discharged with non-blank evidence; that the scope matches exactly; that the recorded k and k_V are the declared ones; and that CONDITIONAL passed first. An unknown status is malformed, and a refuted obligation never passes.
  - **A label in git can be reviewed.** Promoting an obligation is a diff, with a citation, an author and a date. A computed label could flip with a change to a test. The test pinning today's refusal has to change in the same commit, on purpose.
  - **The cost:** false evidence gets a false PROVED. **[M]** `false evidence passes the gate` pins that, so nobody reads more into the label. The gate guarantees that evidence was recorded for every obligation, not that it is true. `proofEvidence` carries the citations so a report can show them. Review is the only check on their content.
- **CONDITIONAL checks the declaration to 2N − 1, not N − 1, and refuses if it cannot.** Theorem 1 needs only ranks below N, but that would not refuse equal counts.
  - **[M]** `boundedCounter m` has k = 2m + 2 states and agrees with equal counts on every rank below k, for m = 0 to 3. With k_V = 1, a check below N passes it. Its first error is `a^(m+1) b^(m+1)`, at rank N.
  - Depth 2k − 1 refutes every k-state automaton: among a⁰ … aᵏ, two reach one state, say aⁱ and aʲ with i < j ≤ k. Then aⁱbⁱ and aʲbⁱ get one output, and only the first has equal counts. The longer has length at most 2k − 1, and N ≥ k. **[M]** Checked on random automata of up to 4 states.
  - This is about equal counts, not regularity. The same pigeonhole gives only 3k − 1 for `#a = 2·#b`, and `hiddenGuard` shows no fixed depth is enough. A pass is never evidence for A3.
  - Too few ranks are refused rather than passed, or a clipped counter would get the label whenever the ranks ran out first. The refusal keeps N, so the number is not lost. N is still k · k_V: the extra depth is a cost, not part of the bound. See Open question 1.
- **Stable means the profile stops changing, on a definition chosen to be testable, not on a theorem.**
  - Positions are compared through deletion because a role like "last" moves with rank. Deleting one position is the rank-reducing map of P2 ([rank-bound §1](theory/rank-bound.md)) and Theorem 2's bulk.
  - Outcome sets are compared because a rank threshold changes no position at all. Without them, `(> 4) . length` would look constant.
  - **[M]** The tests pin what stable does not mean. At window 2 or 3 that threshold reads stable and stops before rank 5. At window 4 it reaches it and settles from 5. Equal counts over three letters is stable from rank 2 and still refused above EMPIRICAL. Over two letters it never settles, because odd ranks hold no equal-count word.
- **One `Question`, for both Theorem 1 and Corollary 2.** Theorem 1's proof uses "not `LOWERED`" only as a predicate on outputs, and Corollary 2 is the same argument with another predicate, so the code has one path. `Claim` records which it was, and only `NeverApplies` can mint a certificate. rank-bound.md is unchanged: it states the two separately. See Open question 7 for what "coverage" should mean on D0-tt.
- **The certificate holds the pattern, the scope and N.** This answers [TODO-l8](TODO-l8.md)'s Open question 6: an oracle-relative, domain-relative label should say so. The constructor is `IssuedCertificate`, unexported, as L8 asked, so its boundary tests keep their meaning.
- **Hidden wrappers around public records.** `Bound` and `Proof` are plain records, so they are readable and printable, but `Conditional` and `Proved` have no exported constructor. Exporting selectors from the wrapped types instead would not be enough: record update needs only the field in scope, so a caller could lower `boundN` on a real value. `Ledger`, `Required` and `Dfa` are hidden too: k cannot be understated, and the obligations come from the document and the parser. A test can still feed made-up bytes to `parseLedger`, and a program could too. The boundary holds against accident, not malice.
- **A third module.** The request names two. `LowerAudit.Ledger` holds the file format and the document reader, because Code style asks for small modules and neither depends on automata.
- **`Abstraction` hides its state types.** Existential quantification keeps q and v out of every signature above it, since nothing there depends on them.
- **The alphabet is an explicit list.** `Letter` has no `Ord`, and L3's shortlex is declaration order. A list means nothing has to derive an order that could disagree with it.
- **A refusal is a value.** Nothing throws, so a report can hold a refused level next to the levels below it.
- **The committed ledger is a data file**, as `data/rejections-*.json` is, one per pin. Every obligation is open and k is null, as rank-bound §6 says. It records no evidence, and is the honest state today.
- **Test ledgers are built in the test,** with the evidence `synthetic: records nothing about any target`. No file exists that could be mistaken for a record of a discharge.
- **The tests were checked** against a throwaway implementation in a scratch copy, since deleted. **[M]** All 219 passed. Each row below is one change to it, and all 114 changes were caught. The first run left three uncaught, and tests were added for them: `prose with pipes in it is not a row either`, a bare `A` row in `other tables' rows are not obligations`, and `and the reverse: another scope's open entry does not block this one`.

  | Change | Tests failing, of 219 |
  |---|---|
  | checks to 2N, not 2N − 1 | 50 |
  | **N is k + k_V** | 47 |
  | `stateCount` understates k by one | 40 |
  | **open passes the gate** | 18 |
  | window off by one; empirical starts at rank 0 | 15 |
  | **checks only to N − 1** | 14 |
  | `StableFrom` reports where it stopped; declared outcome not compared | 11 |
  | `run` reads the word backwards; positions numbered from 1; only the first problem named | 10 |
  | product steps only the left automaton; letter pairs in both directions; the verdict always holds; the claim is dropped | 9 |
  | **shortest word walks letters in reverse**; **no abstraction gets a trivial bound** | 8 |
  | masks compared from the start; checks only to 2N − 2; the scope is not matched | 7 |
  | N is max k k_V; N is k, validity ignored; checks only to N; only the target matched; any A-prefixed cell is an obligation; any letter and digits is an obligation | 6 |
  | masks compared from the end; **the document's list ignored, only listed obligations count** | 5 |
  | shortest word not reversed back; a missing file is an exception; empirical stops one rank short; **short ranks are certified anyway**; an omitted obligation passes; the k check before the obligations; `highestLevel` takes CONDITIONAL for granted | 4 |
  | a step out of the declared states accepted; `mkDfa` names the last bad step; **shortest word keeps each level backwards**; `isEmpty` counts unreachable states; reachable lists every declared state; **no obligation in the doc is vacuous success**; outcomes compared as lists; an invalid word's outcome run in a change; invalid words reach the outcome list; **the verdict ignores validity**; empty evidence counts | 3 |
  | a foreign letter stepped on; no alphabet check on the product; a repeated obligation accepted; the ledger's read error names the document; letter pairs not compared; a change across the validity boundary counts; N counts reachable outcome states; the walk ignores the observed ranks; the outcome run on invalid words; the outcome automaton held to invalid words; **refuted passes**; a ledger-only obligation passes; a differing k passes; a k recorded larger than declared passes; a null k passes; `highestLevel` never says PROVED; a refused level does not say REFUSED; another pattern's certificate accepted; the conflict names the entry's pattern; **`Conditional`, `Proved`, `Ledger` or `Required` constructor exported** (one row each) | 2 |
  | each of: a repeated state, a repeated letter or an undeclared start accepted; product compares alphabets as sets; product understates its states; **shortest word takes the last of a level**; reachable not sorted; a bare `A` or prose counts as a row; a repeated row accepted; **an unknown status reads as discharged**, or as open; an absent k or k_V reads as unknown; a repeated scope accepted; the ledger reported before the document; bad UTF-8 decoded leniently; stable ignores masks; outcomes not compared; the streak does not reset; short ranks refused before the walk; declared validity not compared; validity walked before outcome in two passes; the subject's alphabet or the two automata's alphabets not compared; blank evidence counts; open with evidence passes; ledger-only obligations come first; problems in ledger order; k_V not compared; evidence in ledger order; the proof holds the wrong scope; unusable evidence outranks a refused CONDITIONAL; **a coverage proof mints a certificate**; **a violation mints a certificate anyway**; the certificate holds the wrong N; EMPIRICAL claims a bound; a short-ranks refusal hides N; a rollback, a survival or an application does not contradict; the counts are lost; **`Certificate` or `Dfa` constructor exported** | 1 |

  That shows the tests can pass and can fail. It says nothing about the target, or about your implementation, which these tests have not yet met.

| Dependency | Used by | Reason |
|---|---|---|
| `containers` | `LowerAudit.Automaton` | added to the library, since the signatures take `Ord q`. A boot package, already in the plan through `aeson` |

## Shortcuts

- **`Subject` is a function, not a table of runs.** A real run has holes: a skipped case, or a rank never reached. Nothing here handles them. Set `subjectMaxRank` below the first hole, or give a hole its own outcome so that it disagrees.
- **One `Abstraction`, for one parameter a.** Theorem 1 is per a, and rank-bound §4 takes k as a bound over all a. Call the analyzer once per a. **[H]** A2 may hold for f32 and not si32 (rank-bound §2), so a scope may have to name the element type in `domain`.
- **The ledger holds k and k_V, not the automaton.** Two automata of the same size pass the same entry. N depends only on the counts, so the bound is unaffected, but the evidence for A3 may have been about the other one.
- **Scope fields are free text, compared exactly.** A typo refuses, which is the safe direction.
- **The walk is exhaustive,** so it costs |Σ|^D. Theorem 2 is a sketch and not in this request.
- **No subcommand, no `rank.jsonl`, no `app/` change.** No real outcomes exist to feed it. Component G is L19.

## Open questions

1. **What should CONDITIONAL do on the real domain?** **[H]** The threshold `r > 4` alone needs k ≥ 6 (S3), and excluding rank 0 needs k_V ≥ 2, so N ≥ 12 for D0-tt. Arithmetic, per parameter a, at 9 letters per position: Theorem 1's own hypothesis needs rank 11, 9¹¹ ≈ 3.1·10¹⁰ words at that rank alone, against the 1.2M at ranks 1–6 in problem statement §6. The check to D needs rank 23, 9²³ ≈ 8.9·10²¹. So on D0-tt this will answer `RanksShort`, naming N. That is R9, and it is what Theorem 2 is for, but it means this level cannot reach the target by enumeration, at any depth. *Stub:* the strict refusal, because anything weaker lets a clipped counter through. Decide with L12.2 whether a reduced suite replaces the walk.
2. **Should k count reachable states only?** Theorem 1 says "at most k", so the reachable count is also valid, and so is the count of a minimized automaton, and smaller N is exponentially cheaper. *Stub:* declared states, because that is the formula you asked for and it is what the source argument would bound. A test pins it.
3. **rank-bound §2's "Proof obligation" column has no ids, so the gate cannot see it.** It reads §4's A-rows, the assumptions Theorem 1 names, and the §2 entries and S1–S8 are what A2's and A3's evidence should cite. To gate them one by one, give them ids in a form `obligationsInDoc` reads. *Stub:* rank-bound.md is unchanged.
4. **Two records of the same status.** rank-bound §6 is the prose record under rule 9, and the ledger is what the code reads. A test compares their ids, not their statuses, so they can drift. Should §6 point to the file? *Stub:* §6 is unchanged, and the steps above say to update both.
5. **What counts as evidence?** *Stub:* any non-blank string. A stricter gate could require a `file:line` form (rule 2), an existing results folder, or a reviewer's name. That would catch a careless entry, not a false one.
6. **Does an observed rollback contradict a certificate?** [TODO-l8](TODO-l8.md)'s Open question 4, left for L10 to decide, and for rank-bound.md to record. Corollary 2 is about "applied and survives", and problem statement §4's "unreachable" is about "never to apply". They differ for a pattern that only ever rolled back. *Stub:* L8's stricter reading stays: `markUnreachable` reports a conflict, and a test pins it. A refused label is the safe error. What the certificate means then depends on the predicate you give `NeverApplies`, so the choice is yours to record.
7. **What does `Coverage` mean on D0-tt?** The analyzer takes any predicate. Theorem 1 says "not `LOWERED`", under which every rank ≥ 5 is a violation (rank-bound §3 item 5). `isGap` leaves `EXPECTED_REJECTION` out. Neither `Bound` nor the ledger records which was used, and a `Proved` reads the same either way. *Stub:* not recorded. Probably `Claim` should name it.
8. **Should `initial-spike.md:73-74` change?** Exp D says the analyzer "must refuse to certify" a mutant with a non-regular guard, and is falsified if it certifies one. **[M]** That holds for a guard that fires within the checked ranks. A guard past them reaches CONDITIONAL, which only ever says "if", and stops there unless the ledger is false. As written the falsifier cannot always be met. *Stub:* that file is unchanged, since it changes only by your decision. Rule 11 may call for a decision entry.
9. **Rendering details.** The tests pin the labels, the order, the listed phrases and the forbidden words. How profiles and refusals are written is free. Component G may want this as structured data.
10. **Unknown JSON fields.** No test pins them. A misspelled required field is malformed anyway, so ignoring extras, such as a `note`, is safe.
11. **The order between `mkDfa`'s error kinds.** Each test has one fault, so any order passes.
12. **Accepting the slice.** Rule 12 still blocks implementation. *Stub:* nothing changed in architecture §3 or `STATUS.md`.
