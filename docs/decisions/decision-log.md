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

## D-004 · 2026-11-01 · PROPOSED · First target: `tosa-to-linalg` and `tosa-to-linalg-pipeline` at the pin

- **Alternatives:** TorchToTosa, tt-mlir TTIR→TTNN, mlir-aie VectorToAIEVec, the Intel NPU
  compiler (not inspected).
- **Evidence:** [problem statement §5](../research/problem-statement.md).
- **Scope change if accepted:** for the first target, "targeting NPU dialects" narrows to "an
  NPU-facing operator set (TOSA) lowered to Linalg". An NPU dialect becomes the second target.
  This is not in force until the user accepts it (OQ-1).

## D-005 · 2026-11-01 · PROPOSED · Domain D0

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
