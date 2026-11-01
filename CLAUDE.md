## Mission
 
Build a research tool that evaluates the coverage and reachability of real MLIR lowering pipelines targeting NPU dialects.
 
The tool treats an existing conversion pipeline as an executable system rather than reimplementing its lowering rules. It generates or enumerates valid source-operation configurations within a declared domain, runs them through the real conversion, and records which cases are successfully lowered and which registered patterns fire.
 
The research goal is to establish a principled completeness result: under explicit assumptions about how the conversion depends on tensor rank, determine a sufficient rank bound such that checking all relevant cases up to that bound is enough to establish the result for all ranks.
 
## Core research questions
 
1. **Case coverage:** Does the real conversion successfully lower every valid source-operation configuration in a declared domain?
2. **Pattern reachability:** Which registered lowering patterns fire, which never fire, and under what conditions?
3. **Rank generalization:** Can rank-dependent behavior be characterized so that a finite set of rank checks is sufficient to reason about all ranks?
4. **Practicality:** Can these checks be performed against real MLIR conversion pipelines without replacing their implementation?
 
## Intended architecture
 
- **Haskell driver:** Orchestrate test generation, execution, result collection, normalization, analysis, and report generation.
- **MLIR execution layer:** Invoke the actual conversion pipeline and preserve its real conversion behavior.
- **Input-domain model:** Explicitly describe valid source operations, types, attributes, shapes, and other relevant parameters.
- **Coverage analysis:** Record successfully lowered cases, rejected cases, and unexplained failures.
- **Pattern instrumentation:** Determine which registered patterns are attempted and which successfully apply, to the extent the MLIR implementation permits reliable observation.
- **Rank analysis:** Identify rank-sensitive conditions and derive a sufficient bound only where a sound argument is possible.
- **Reporting:** Produce reproducible coverage reports, pattern-reachability reports, and counterexample inputs.
 
## Scope boundaries
 
This is not a general claim to solve compiler lowering completeness for arbitrary compilers.
 
The target is real MLIR conversion infrastructure and a declared, technically bounded source domain. Every completeness statement must specify that domain and its assumptions.
 
General lowering completeness is established prior art. The intended contribution is the narrower combination of:
- systematic coverage checking against real conversion implementations;
- reporting never-fired or unreachable lowering patterns;
- a sufficient-rank argument that can generalize finite checks to an unbounded rank domain, when the conversion satisfies the required conditions.
 
Do not claim that a finite empirical test establishes completeness for all inputs or all ranks.
 
## Implementation preference
 
Use Haskell as the orchestration and analysis driver. Do not force the MLIR implementation itself into Haskell. Use the smallest practical integration layer needed to execute and observe the real conversion pipeline.
 
Keep the tool modular so that the input generator, MLIR adapter, coverage model, rank analysis, and reporting can be independently tested.
 
## Research discipline
 
- Distinguish verified facts, hypotheses, assumptions, and open questions.
- Cite primary sources and exact versions/commits for claims about MLIR and target conversions.
- Do not treat a pattern that did not fire in a test corpus as proven unreachable.
- Do not confuse pattern reachability with lowering completeness.
- Do not infer a sufficient rank bound from a few passing examples.
- Do not describe the project as novel until the closest prior work has been checked.
- Preserve negative results and counterexamples.
- Record every scope change and theorem assumption.
 
## Current status
 
Research candidate E (#2), intended flagship master's research direction.
 
The narrowed novelty claim is provisional:
A checker for every case in a declared domain, including never-fired pattern reporting, applied to real MLIR conversions as black boxes, with a sufficient-rank theorem that extends finite-rank checks to all ranks under stated conditions.
 
A feasibility spike is planned for 8–15 November 2026. The most important early question is whether the target conversion's rank-sensitive behavior is governed by finite threshold comparisons or whether it contains constructs that invalidate a finite sufficient-rank argument.
 
The project is not yet authorized to assume that the theorem exists or that the target conversion satisfies its conditions.