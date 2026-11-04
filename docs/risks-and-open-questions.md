# Risks and open questions

Updated 2026-11-04 for the accepted target (D-012 to D-015). Ratings are judgments, and nothing has run on the target. Likelihood and impact are rated H, M or L.

## Risks

| Id | Category | Risk | L | I | Early signal | Mitigation |
|---|---|---|---|---|---|---|
| R1 | theory | The theorem is trivial on the first target. D-010 rejected TosaToLinalg for this reason. It may recur on tt-mlir: `ttir.sum`'s pattern is rank-free, and `ttir.prod`'s threshold found so far is one documented rejection at rank 5 (hypothesis: small N). | H | H | spike Q5 is CONDITIONAL; the §5 conjecture in rank-bound holds with a tiny N | report it as a result; consider a richer op through a new decision entry |
| R2 | theory | Obligations cannot be discharged for real C++. Rank logic hides in helpers and output verifiers (O3 on the earlier target; `ttnn.prod`'s verifier on this one), and the pipeline adds passes not yet read, so the closure inventory grows without bound. | M | H | the closure exceeds ~2k lines for one pattern | restrict claims to closures that were inventoried; mechanize a scan for rank-dependent expressions; Exp D adversarial checks |
| R3 | novelty | Thin novelty: never-fired-rule reporting already exists (GlobalISel), and the theorem's math is standard. | M | H | the full-text reads ([novelty audit](research/novelty-audit.md) §4) find the combination | make the source-discharged rank obligations the contribution; finish the reading list before the freeze |
| R4 | scope | **Occurred.** The target is an NPU dialect and needs an LLVM and project source build on an 8 GB machine at ~10 h/week. Docs recommend 16 GB for a VM of the full stack and report OOM risk. D-015 currently forbids the build. | H | H | OQ-1 answered "must be NPU" (2026-11-04) | time one capped build before relying on the target, if the limit is lifted; a failed build stops the work (D-011) |
| R5 | instrumentation | Pattern success needs a listener, so the adapter rebuilds the pass's target, which is a fidelity risk. Rollback attribution is unclear. The action log lacked status at the earlier pin (O4); not re-checked at this LLVM. | M | M | fidelity mismatches | byte-equal output check against `ttmlir-opt`; report attempts-only where needed |
| R6 | evaluation | The only oracle is V_ttir, with no spec behind it (D-014). A "gap" means only that the TTIR verifier accepted a case the conversion could not handle, and a verifier bug cannot be told apart. O3's flip between oracles was observed on the earlier target and cannot appear here. | H | M | a gap that upstream calls invalid input | name the oracle on every result; triage against lit tests and upstream; ask the advisor (OQ-8) |
| R7 | evaluation | Hypothesis: `ttnn.prod` rejects rank > 4, so above that an all-rank claim may only say "every case is rejected". (On the earlier target, the pipeline capped rank at 6.) | H | M | Exp A shows every rank ≥ 5 case failing | state what the bound means for this op; use `ttir.sum` to show an uncapped case |
| R8 | technical | Pin drift. tt-mlir moves quickly, and its LLVM pin is already 33,634 commits behind `llvmorg-23.1.1` (LLVM 22 dev). One-Shot conversion is removing rollback upstream. | M | M | the claims stop holding at a newer commit | everything is pinned; re-verify on each pin change |
| R9 | technical | Combinatorial growth. D0-tt has 2·9^r cases per type and op at rank r (D-017), which is about 1.2M at ranks 1–6. Cost per case is untimed. | H | M | V_ttir runs exceed hours | a smaller rank bound; Theorem 2 enumeration over multisets; batching |
| R10 | evaluation | Single-op domains miss failures that arise across op boundaries (type conversion between ops). | M | M | historical issues that are mostly multi-op | measure the share of single-op issues before claiming coverage of the failure population |
| R11 | process | The time budget (assumed ~10 h/week) is too small for a source build, engine, theory and a second target. | H | H | spike days overrun | the stop conditions in the spike plan; cut the second target first |
| R12 | technical | Nondeterministic outcomes from threading. | L | M | repeat runs differ | `--mlir-disable-threading` |
| R13 | process | The accepted target cannot run while D-015 holds, so the spike's run-based questions have no evidence, and GO table row 1 lists "the pin is unusable" as NO-GO. | H | H | still in force at the 15 Nov decision | the user decides whether to lift the limit or how to read row 1 |

## Open questions

| Id | Question | Blocks | Who decides |
|---|---|---|---|
| OQ-1 | **Closed 2026-11-04: no (D-010).** Is a non-NPU first target (TosaToLinalg) acceptable for the spike? | nothing | user |
| OQ-9 | **Closed 2026-11-04: tt-mlir TTIR→TTNN on `ttir.prod` (D-012, D-013).** Which NPU-dialect conversion is the first target, and what is its domain? | nothing | user |
| OQ-2 | **Closed 2026-11-04: V_ttir, the only oracle (D-014).** Which oracle gives headline numbers? | nothing | user |
| OQ-3 | Parked with TosaToLinalg (D-010). Is O3 a known upstream issue, and is a dynamic result dim at the axis intended to be valid TOSA in MLIR? | O3 triage only | evidence: upstream tracker, TOSA spec |
| OQ-4 | Parked with TosaToLinalg (D-010). Exact failure condition of `inferExpandShapeOutputShape` at `llvmorg-23.1.1` | rank-bound §7 record only | source reading |
| OQ-5 | Second target: which, now that tt-mlir is first (D-012)? The option set is open; TorchToTosa's status as a second target is unsettled by D-010. | after the spike | user, with spike data |
| OQ-6 | Can pattern success be observed without rebuilding the pass target (e.g. an action handler, or `-debug-only`, since assertions are on at this LLVM)? Reading at the earlier pin: no. Not re-read here. | C2 design | source reading |
| OQ-7 | How much of obligation checking can be mechanized for C++ patterns? | RQ3 strength | research |
| OQ-8 | Does a standard-math cutoff theorem with source-discharged obligations count as the theory component? Is a verifier-only oracle (D-014) acceptable? | topic freeze | advisor |
| OQ-10 | **Closed 2026-11-04: yes, with no repeated positions (D-017).** Does D0-tt include negative dim encoding? | nothing | user |
| OQ-11 | **Closed 2026-11-04: the lit bare prefix and `--ttir-to-ttnn-runtime-pipeline` (D-017).** What are the exact bare-pass and pipeline commands? | nothing | user |
| OQ-12 | **Closed 2026-11-04: `EXPECTED_REJECTION`, keyed on the diagnostic (D-017).** Which class does a failure take if it is both `OUTPUT_INVALID` and documented, such as `ttir.prod` at rank 5? | nothing | user |
