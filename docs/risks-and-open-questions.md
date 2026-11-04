# Risks and open questions

Updated 2026-11-01. Likelihood and impact are rated H, M or L.

## Risks

| Id | Category | Risk | L | I | Early signal | Mitigation |
|---|---|---|---|---|---|---|
| R1 | theory | The theorem is trivial on the first target. TosaToLinalg's rank logic is mostly uniform loops plus axis roles, so N is tiny and the result reads as obvious. | H | H | spike Q5 is CONDITIONAL | pick the second target for real threshold logic (tt-mlir `rank == 4` family, or TorchToTosa) |
| R2 | theory | Obligations cannot be discharged for real C++. Rank logic hides in helpers of other dialects (O3: `ExpandShapeOp::build`), so the closure inventory grows without bound. | M | H | the closure exceeds ~2k lines for one pattern | restrict claims to closures that were inventoried; mechanize a scan for rank-dependent expressions; Exp D adversarial checks |
| R3 | novelty | Thin novelty: never-fired-rule reporting already exists (GlobalISel), and the theorem's math is standard. | M | H | the full-text reads ([novelty audit](research/novelty-audit.md) §4) find the combination | make the source-discharged rank obligations the contribution; finish the reading list before the freeze |
| R4 | scope | The cheap target is not an NPU dialect. NPU-dialect targets need an LLVM build per pin on an 8 GB machine at ~10 h/week. | M | M | OQ-1 answered "must be NPU" | defer the NPU target to after the spike; time one LLVM build before committing |
| R5 | instrumentation | Pattern success needs a listener, so the adapter rebuilds the pass's target, which is a fidelity risk. Rollback attribution is unclear. The action log lacks status (O4). | M | M | fidelity mismatches | byte-equal output check against `mlir-opt`; report attempts-only where needed |
| R6 | evaluation | Verdicts flip with the validity oracle (O3 is a gap under V_mlir and invalid under V_tosa1.0). | H | M | none, already observed | report every result per oracle; headline the spec oracle |
| R7 | evaluation | The default pipeline caps rank at 6, so "all ranks" adds nothing there. | H | M | none, already observed | aim the all-rank claim at the bare pass, level `none`, and targets without caps |
| R8 | technical | Pin drift. Upstream TOSA and dialect conversion change monthly; One-Shot conversion is removing rollback. | M | M | the claims stop holding at a newer pin | everything is pinned; re-verify on each pin change |
| R9 | technical | Combinatorial growth beyond toy domains (\|Σ\|^r). | M | M | V_mlir runs exceed hours | Theorem 2 enumeration over multisets; batching |
| R10 | evaluation | Single-op domains miss failures that arise across op boundaries (type conversion between ops). | M | M | historical issues that are mostly multi-op | measure the share of single-op issues before claiming coverage of the failure population |
| R11 | process | The time budget (assumed ~10 h/week) is too small for engine, theory and a second target. | M | H | spike days overrun | the stop conditions in the spike plan; cut the second target first |
| R12 | technical | Nondeterministic outcomes from threading. | L | M | repeat runs differ | `--mlir-disable-threading` |

## Open questions

| Id | Question | Blocks | Who decides |
|---|---|---|---|
| OQ-1 | **Closed 2026-11-04: no (D-010).** Is a non-NPU first target (TosaToLinalg) acceptable for the spike? | nothing | user |
| OQ-9 | **Closed 2026-11-04: tt-mlir TTIR→TTNN on `ttir.prod` (D-012, D-013).** Which NPU-dialect conversion is the first target, and what is its domain? | nothing | user |
| OQ-2 | **Closed 2026-11-04: V_ttir, the only oracle (D-014).** Which oracle gives headline numbers? | nothing | user |
| OQ-3 | Is O3 a known upstream issue, and is a dynamic result dim at the axis intended to be valid TOSA in MLIR? | O3 triage | evidence: upstream tracker, TOSA spec |
| OQ-4 | Exact failure condition of `inferExpandShapeOutputShape` at the pin | rank-bound §5 | source reading |
| OQ-5 | Second target: which, now that tt-mlir is first (D-012)? The option set is open; TorchToTosa's status as a second target is unsettled by D-010. | after the spike | user, with spike data |
| OQ-6 | Can pattern success be observed without rebuilding the pass target (e.g. an action handler)? Current reading: no. | C2 design | source reading |
| OQ-7 | How much of obligation checking can be mechanized for C++ patterns? | RQ3 strength | research |
| OQ-8 | Does a standard-math cutoff theorem with source-discharged obligations count as the theory component? | topic freeze | advisor |
