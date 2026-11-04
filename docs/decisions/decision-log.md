# Decision log

Newest at the bottom. Entries are never edited after acceptance; a change of mind gets a new entry
that supersedes the old one. Status is one of ACCEPTED, PROPOSED (needs the user) or SUPERSEDED.

## D-001 · 2026-11-01 · ACCEPTED · Pin `llvmorg-23.1.1`

- **Decision:** use Homebrew LLVM 23.1.1 (`llvmorg-23.1.1`, `6dfe1677ab8d`) for reconnaissance
  and the spike.
- **Alternatives:** build LLVM main; adopt a candidate repo's own pin.
- **Evidence:** Homebrew ships `mlir-opt` with the TOSA passes, the MLIR CMake package and
  `libMLIRTosaToLinalg.a`. No build cost on an 8 GB machine.
- **Revisit:** if a needed fix lands after 23.1.1, or when an NPU target with its own pin is chosen.

## D-002 · 2026-11-01 · ACCEPTED · Haskell driver, process boundary, C++ only for the listener

- **Alternatives:**
  - Haskell bindings to MLIR's C API: high integration cost.
  - Python bindings: not used.
  - An all-C++ engine.
- **Evidence:** the CLI plus the action log already give outcome classes and pattern attempts
  (O1–O6). Pattern success needs `RewriterBase::Listener` (O4).
  See [architecture](../design/architecture.md).

## D-003 · 2026-11-01 · ACCEPTED · "Successfully handled" = S2

- **Decision:** validity passes, conversion succeeds, the output verifies, and no non-legal
  source op remains ([problem statement §3](../research/problem-statement.md)).
- **Alternatives:** S0, S1, S3.
- **Evidence:** O3 has S0 true in-process with invalid output. The conversion is full
  (`TosaToLinalgPass.cpp:72`).

## D-004 · 2026-11-01 · SUPERSEDED by D-010 · First target: `tosa-to-linalg` and `tosa-to-linalg-pipeline` at the pin

- **Alternatives:** TorchToTosa, tt-mlir TTIR→TTNN, mlir-aie VectorToAIEVec, the Intel NPU
  compiler (not inspected).
- **Evidence:** [problem statement §5](../research/problem-statement.md).
- **Scope change if accepted:** for the first target, "targeting NPU dialects" narrows to "an
  NPU-facing operator set (TOSA) lowered to Linalg". An NPU dialect becomes the second target.
  This is not in force until the user accepts it (OQ-1).

## D-005 · 2026-11-01 · SUPERSEDED by D-010 · Domain D0

- **Decision:** a single `tosa.reduce_sum`, with letters {1, s, ?}, an axis mark, and element
  types f32, bf16 and i32. `tosa.add` is the control. Both validity oracles are used.
- **Alternatives:**
  - Elementwise ops only: rank-uniform, so the theorem is trivially true and too weak.
  - Transpose: permutations break the finite alphabet. Keep it as a later negative case.
- **Evidence:** [rank-bound §2](../theory/rank-bound.md); O3.

## D-006 · 2026-11-01 · ACCEPTED · Framing correction: "black box" applies to execution only

- **Decision:** the rank theorem's hypotheses A2 and A3 are white-box obligations on the
  conversion's source.
- **Why:** a finite black-box test is complete only given a bound on the implementation's states
  (Chow 1978). That bound must come from source.
- **Effect:** CLAUDE.md's provisional novelty wording changed from "applied to real MLIR
  conversions as black boxes" to "black-box execution, with rank obligations discharged against
  the source".

## D-007 · 2026-11-01 · ACCEPTED · Reachability vocabulary

"Not observed" is an empirical label. "Unreachable in D" is allowed only through Corollary 2 of
[rank-bound](../theory/rank-bound.md), with its obligations discharged.

## D-008 · 2026-11-01 · PROPOSED · Theorem shape

- **Decision:** a finite-state abstraction over per-dimension words (Theorem 1), with a symmetric
  threshold variant (Theorem 2) for enumeration.
- **Alternatives:**
  - Presburger conditions on r alone: cannot express per-position letters or axis roles.
  - Symbolic execution of the C++ patterns: too costly at this scale.
  - An empirical cutoff: forbidden by rule 4.
- **Evidence:** the inventory shows column-local loops and mark-relative roles; O3 shows a
  locality window.

## D-009 · 2026-11-01 · ACCEPTED · Scope record

NXP Neutron (Idea M) is a separate candidate and stays out unless the user chooses it.

## D-010 · 2026-11-04 · ACCEPTED · OQ-1 answered no: the first target must be an NPU dialect

- **Decision:** a non-NPU first target is not acceptable. This closes OQ-1 and supersedes D-004 and
  D-005, because D0 is defined on TOSA's `reduce_sum`. The replacement target is open (OQ-9), and so
  is its domain. The user's reason is not yet recorded.
- **Alternatives:** TosaToLinalg first with an NPU second target (D-004).
- **Effect:** no target or domain is accepted, so CLAUDE.md rule 12 still blocks implementation code.
  D-001 and the spike's no-source-build limit need revisiting once a target is chosen. The spike's
  day table is kept.
- **Rework needed, not yet done:**
  - `CLAUDE.md`: Current scope; Unknowns that gate work; the rule 12 references to D-004 and D-005.
  - `README.md`: Current stage.
  - `STATUS.md`: Candidates and literature, if the target's facts change; H1 and H2.
  - `docs/research/problem-statement.md`: status line; §1 examples; §5; §6; §7 (RQ1–RQ3).
  - `docs/theory/rank-bound.md`: §2; §3; §5; the §6 ledger. §1 and the generic theorems in §4 do not
    depend on the target; A5's check and the remarks do.
  - `docs/design/architecture.md`: status line; §1 pass, target and Homebrew details; §2 rows A, B,
    C1, C2 and E; §3.
  - `docs/experiments/initial-spike.md`: assumptions; §1; §2 experiments A–F; §3 and the source-build
    limit in §4 row 1; the probes stay as a record.
  - `docs/risks-and-open-questions.md`: R1, R2, R4, R5, R6, R7, R9, R11; OQ-3, OQ-4, OQ-5.
  - `docs/research/novelty-audit.md`: §3's condition on non-trivial rank logic, once the target is known.

## D-011 · 2026-11-04 · ACCEPTED · Reason for D-010; build limit and failure rule until OQ-9

- **Decision:**
  - The reason for D-010 is research strength: TosaToLinalg's rank logic looks too shallow (R1).
  - OQ-9 stays open. The user decides after [brief-oq9](brief-oq9.md).
  - The source-build limit stays in force until the user decides from that brief.
  - If the first target's build fails on this machine, stop and report a negative result.
- **Alternatives:** lift the build limit now; move to another target after a failed build.
- **Evidence:** R1 (`docs/risks-and-open-questions.md:9`).
- **Correction to D-010:** its rework list places the build limit in `initial-spike.md` §4 row 1. The
  limit is at `docs/experiments/initial-spike.md` lines 9 and 109. D-010 itself is left unedited, as
  this log's rules require.
- **New evidence (rule 11):** [brief-oq9](brief-oq9.md) records corrections to the target comparison in
  problem statement §5. They are applied with the D-010 rework.

## D-012 · 2026-11-04 · ACCEPTED · First target: tt-mlir TTIR→TTNN; its LLVM pin added

- **Decision:** the first target is TTIR→TTNN at `tenstorrent/tt-mlir` `f9dc1b3e5101`. Its LLVM pin is
  `llvm/llvm-project` `4efe170d858e` (22.0 dev). This closes OQ-9 and replaces the target D-004 proposed.
  D-001 is not superseded: it still applies to the eight TosaToLinalg probes, as a record.
- **Alternatives:** mlir-aie VectorToAIEVec; the Intel NPU compiler IE→VPU; superseding D-001 outright.
- **Evidence:** [brief-oq9](brief-oq9.md) §1, §2, §7, §8. The user's reason for this choice is not
  recorded.
- **Open:** the exact commands for "bare pass" and "pipeline". Brief §7 lists candidates, and they were
  not part of this decision.

## D-013 · 2026-11-04 · ACCEPTED · Domain: `ttir.prod`, as brief §5 tt-A

- **Decision:** a single `ttir.prod`, with letters {1, s, ?}, a set of dim marks, `keep_dim`, and element
  types f32, bf16 and si32. `ttir.sum` is the control. This replaces the domain D-005 proposed. Brief
  tt-A also lists positive or negative dim encoding as a parameter.
- **Alternatives:** `ttir.batch_norm_inference` (rank capped by its verifier); `ttir.sum` alone (no rank
  logic in its pattern).
- **Evidence:** [brief-oq9](brief-oq9.md) §4, §5. Hypotheses, not verified: the domain was not run, and
  its enumeration size is not computed. A set of marks replaces D-005's single axis mark, so theorem
  alphabet and counts change.
- **Known at the commit:** a rank-5 `ttir.prod` fails in `ttnn.prod`'s verifier, and a negative lit test
  documents it (`negative_reduce_prod_op.mlir:1-7`), so that is not automatically a gap.

## D-014 · 2026-11-04 · ACCEPTED · One validity oracle: V_ttir

- **Decision:** the only oracle is V_ttir: the parser and TTIR verifiers accept the case (`ttmlir-opt`,
  no passes). V_mlir and V_tosa1.0 do not apply to this domain. Headline numbers use V_ttir (OQ-2).
- **Alternatives:** adding a declared spec-based oracle. No spec was found in the tt-mlir repository.
- **Evidence:** [brief-oq9](brief-oq9.md) §6.
- **Cost:** a verdict means "the TTIR verifier accepts it", not "a spec requires it". O3-style verdict
  flips between oracles cannot occur. Whether this is acceptable to the advisor is unasked.

## D-015 · 2026-11-04 · ACCEPTED · The source-build limit stays

- **Decision:** the limit at `docs/experiments/initial-spike.md` lines 9 and 109 stays in force with no
  end date, until a new entry lifts it. This settles the decision D-011 left open. D-011's failure rule
  stands, but no build runs, so it cannot fire.
- **Alternatives:** one capped MLIR-only build at the target's pin.
- **Effect:** no `ttmlir-opt` exists here, so neither D-012's conversion nor D-014's oracle can execute.
  Nothing target-dependent can run until this is lifted. The spike plan's coverage, pattern and
  adversarial experiments are blocked.
- **Rework needed, not yet done** (this list replaces D-010's):
  - `CLAUDE.md`: Stage line; Current scope; Distinctions (the oracle and pass-vs-pipeline items);
    Architecture preferences (the `mlir-opt` fidelity wording); Unknowns that gate work; rule 12's
    references to D-004 and D-005.
  - `README.md`: Status note; Problem (lit-test example); Current stage.
  - `STATUS.md`: MLIR at the pin; Probes; Candidates and literature; H1, H2, H3, H5.
  - `docs/research/problem-statement.md`: status line; §1; §2; §3; §4 citations; §5; §6; §7.
  - `docs/theory/rank-bound.md`: pin note and status; §2; §3; §4 (alphabet, A5's check, Theorem 2's
    frame, the MAX_RANK remark); §5; §6.
  - `docs/design/architecture.md`: status line; §1; §2 rows A, B, C1, C2, D and E; §3.
  - `docs/experiments/initial-spike.md`: goal and assumptions; §1; §2 experiments A–F; §3; §4 rows 1, 2,
    5 and 6; the probes stay as a record.
  - `docs/risks-and-open-questions.md`: R1, R2, R4, R5, R6, R7, R8, R9, R11; OQ-3, OQ-4, OQ-6, OQ-8.
  - `docs/research/novelty-audit.md`: §2's "at the pin" rows; §3's condition on non-trivial rank logic.

## D-016 · 2026-11-04 · ACCEPTED · Docs reworked for the accepted target (rule 11)

- **Decision:** the rework listed in D-010 and D-015 is done. TosaToLinalg's probes, inventory, predictions and
  comparison stay as dated records. No decision, research question or novelty claim changed.
- **Citations:** current `file:line` citations were read at tt-mlir `f9dc1b3e5101` and LLVM `4efe170d858e`, and
  anything unread or unrun is marked as a hypothesis. Citations at `llvmorg-23.1.1` appear only in records.
- **New names:** D0-tt for D-013's domain; H6 and H7 for the conjectures in `docs/theory/rank-bound.md` §5.
  H1, H2 and H5 are parked, never tested.
- **New open questions:** OQ-10 (dim encoding), OQ-11 (mode commands), OQ-12 (class of a documented rejection whose
  output does not verify). New risk: R13.
- **Citation update:** D-011 and D-015 cite the build limit at `initial-spike.md` lines 9 and 109. After this
  rework it is at lines 9 and 102.
- **Proposed, not accepted:** the vertical slice in `docs/design/architecture.md` §3, so rule 12 still holds.
