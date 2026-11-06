# Closure checklist: `ReduceConverter<ReduceSumOp>`

> **Status (2026-11-06).** A worksheet. Every answer is blank, so nothing here discharges A2 or A3 for this
> pattern. The call graph was read from source at `llvmorg-23.1.1` (`6dfe1677ab8d`); nothing was run. It is the graph
> visible by reading: virtual dispatch, ODS traits and generated code may hide more, and a missed callee is a defect in
> this file. **The target is parked** (D-010). This uses TosaToLinalg as the [§7 record](rank-bound.md) left it, and
> changes no claim about TTIR→TTNN.

## Questions

Answer these for each function. S1–S8 and A2 are defined in [rank-bound §4](rank-bound.md). The alphabet is D0's, from
the [problem statement](../research/problem-statement.md): letters {1, s, ?} with an axis mark; element types f32, bf16, i32.

| | Question | How to answer |
|---|---|---|
| **Q1** | Which rank-dependent expressions does the function have? | One row each, as `line: expression`. Write `none` if there are none. Add rows as needed. |
| **Q2** | Is each expression one of S1–S8? | The class, or `none of S1–S8`. S5 and S6 break A3, and S7 needs a separate argument. |
| **Q3** | Does each use of a static size go through a predicate that is constant on each letter (A2)? | `line: predicate: yes/no`, or `no static size used`. |

## Line count

Raw lines are `end - start + 1`, after merging overlaps per file. Code lines leave out blank lines and comment-only lines.
Whole functions are counted, including branches for other reduce ops, so each function's count is an upper bound on what `ReduceSumOp` executes in it.

| Slice | Functions | Raw lines | Code lines |
|---|---:|---:|---:|
| Registration and type converter (A1) | 3 | 132 | 116 |
| Pattern and helpers (A2) | 6 | 324 | 243 |
| Created ops: builders and per-op verifiers (A3–A7, A9, A10) | 57 | 933 | 797 |
| Created ops: structured and `expand_shape` verifiers, shared utilities (A8, A11, A12) | 42 | 724 | 610 |
| **Hand-written, the scope requested (A1–A12)** | **108** | **2113** | **1766** |
| Addition: folder (X) | 1 | 11 | 11 |
| **Hand-written with the addition** | **109** | **2124** | **1777** |
| Generated code (Part B) | 75 | 930 | 868 |
| Everything listed | 184 | 3054 | 2645 |

### Against the 2k stop rule

The threshold is about 2,000 lines of transitive helpers ([spike plan §3](../experiments/initial-spike.md#3-stop-conditions), R2). The rule does not define a line, or say whether generated code counts, and those choices decide the result here:

| Reading | Lines | Against 2,000 |
|---|---:|---|
| Hand-written, code lines (A1–A12) | 1766 | -234 |
| Hand-written, raw, without registration and type converter (A2–A12) | 1981 | -19 |
| Hand-written, raw (A1–A12) | 2113 | +113 |
| Hand-written, raw, with the addition | 2124 | +124 |
| Hand-written and generated, raw | 3054 | +1054 |

**The closure is at the threshold, not clearly on either side of it.** Everything in the boundary table below is uncounted, so following any of it raises these numbers.

**This count does not trigger or clear the rule.** As written, the rule names `ReductionProdOpConversionPattern` on tt-mlir, not this pattern. Here the count only calibrates how large one reduce closure gets.

## Scope decisions to confirm

- **Not created for `ReduceSumOp`, so not listed:** the ops under `isNanIgnoreMode` (`TosaToLinalg.cpp:1220-1240`, `:1268-1279`, `:1290-1325`), since that flag is set only inside the `if constexpr` for `ReduceMinOp` and `ReduceMaxOp` (`:1210-1215`); and the `arith` ops of the other reduce kinds (`:1125-1153`).
- **Type converter:** listed as you asked. `ReduceConverter` is an `OpRewritePattern` registered without it (`TosaToLinalg.cpp:2238`, `:3084-3099`).
- **Addition, X1:** not on your list. The default folding mode is `BeforePatterns` (`DialectConversion.h:1466-1467`), and the pass passes no config (`TosaToLinalgPass.cpp:72`), so the driver tries this folder before the pattern (`DialectConversion.cpp:2602-2603`, `:2613`).
- **Builder path:** `TosaToLinalg.cpp:1370` passes `ReassociationExprs`, so it enters at the ODS builder `TensorOps.td:1158-1164` before reaching `TensorOps.cpp:1961`. The §7 record cites only the latter.
- **Generated code:** read from the headers Homebrew LLVM 23.1.1 installed under `/opt/homebrew/opt/llvm/include/mlir/`, which [STATUS](../../STATUS.md) records as this commit. They are not in git, so these line numbers hold only for that install.

## Call graph

IDs refer to the worksheet below. Unnumbered ops and functions are generated and are in Part B.

```text
F01 runOnOperation
├─ F03 populateTosaTypeConversion
├─ F02 populateTosaToLinalgConversionPatterns
└─ applyFullConversion (boundary)
   ├─ X1 ReduceSumOp::fold, tried before patterns
   └─ F04 ReduceConverter<ReduceSumOp>::matchAndRewrite
      └─ F05 reduceMatchAndRewriteHelper<ReduceSumOp>
         ├─ tensor.dim (:1185): F10 → F11 → F12
         ├─ tensor.empty (:1194, :1331): F15
         ├─ F06 createInitialValueForReduceOp (:1197)
         ├─ arith.constant (:1202)
         ├─ linalg.fill (:1204): F18 → F19 → FillOp::regionBuilder → F20
         ├─ linalg.reduce (:1245): F25 → F26
         │  └─ body lambda: arith.extf (:1253), F07 (:1256) → arith.addf | arith.addi, linalg.yield (:1283)
         ├─ linalg.generic (:1338): F32 → F33 → F34 → F26
         │  ├─ F09 (:1336), F08 (:1342)
         │  └─ body lambda: arith.truncf (:1344), linalg.yield (:1346)
         └─ tensor.expand_shape (:1370): F74 → F75, F76
            ├─ F77 → F78 → F10, F79
            ├─ F80 → F81 (OQ-4)
            │  ├─ F11, arith.divsi → F82 → F83
            │  └─ F85 → F84
            └─ F86 → F87, F88

Verifiers of created ops, run on the output IR:
tensor.dim           generated; F14
tensor.empty         F16 → F17 → F108
arith.constant       F13; F14
arith.addf, addi     generated; F63; F64 → F66; F14
arith.extf           F59 → F60; F64; F65 → F66; F67 → F68 → F70 → F71, F72 → F73
arith.truncf         F61 → F62; F64; F65 → F66; F67 → F69 → F70 → F71, F72 → F73
arith.divsi          generated; F63; F64 → F66; F14
linalg.yield         F57 → F58
linalg.fill          F21 → F22 → F23; F56 → F55; structured verifiers below
linalg.reduce        F27; F28, F29 → F30, F31; structured verifiers below
linalg.generic       no hand-written verifier; F56 → F55; structured verifiers below
structured verifiers F35 → F36 → F37, F38, F39, F42 → F43, F41 → F103, F40 → F102, F104
                     F35 → F50, F51, F47, F44 → F45, F46, F48
                     F52 → F53, F54
                     F49, F24, for fill's generated accessors
tensor.expand_shape  F89 → F17, F90
                     F90 → F91 → F92, F93, F94 → F95 → F96, F97, F98 → F99
                     F90 → F107, F105 → F106, F100, F101
```

## Part A: hand-written functions

Links go to the line range at the tag. "From" is the call site, or the hook that runs the function.

### A1. Registration and type converter

#### F01 · `TosaToLinalg::runOnOperation`

[`TosaToLinalgPass.cpp:47-74`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Conversion/TosaToLinalg/TosaToLinalgPass.cpp#L47-L74) · 28 lines · From: pass entry

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F02 · `populateTosaToLinalgConversionPatterns`

[`TosaToLinalg.cpp:3031-3101`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Conversion/TosaToLinalg/TosaToLinalg.cpp#L3031-L3101) · 71 lines · From: `TosaToLinalgPass.cpp:71`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F03 · `populateTosaTypeConversion`

[`TosaTypeConverters.cpp:20-52`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Tosa/Transforms/TosaTypeConverters.cpp#L20-L52) · 33 lines · From: `TosaToLinalgPass.cpp:68`. Passed to `PointwiseConverter` at `TosaToLinalg.cpp:3082`; `ReduceConverter` is registered at `:3084-3099` with the context only

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

### A2. Pattern body and helpers

#### F04 · `ReduceConverter<ReduceSumOp>::matchAndRewrite`

[`TosaToLinalg.cpp:2242-2245`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Conversion/TosaToLinalg/TosaToLinalg.cpp#L2242-L2245) · 4 lines · From: registered at `TosaToLinalg.cpp:3090`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F05 · `reduceMatchAndRewriteHelper<ReduceSumOp>`

[`TosaToLinalg.cpp:1161-1373`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Conversion/TosaToLinalg/TosaToLinalg.cpp#L1161-L1373) · 213 lines · From: `TosaToLinalg.cpp:2244`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F06 · `createInitialValueForReduceOp`

[`TosaToLinalg.cpp:1060-1108`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Conversion/TosaToLinalg/TosaToLinalg.cpp#L1060-L1108) · 49 lines · From: `TosaToLinalg.cpp:1197`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F07 · `createLinalgBodyCalculationForReduceOp`

[`TosaToLinalg.cpp:1112-1156`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Conversion/TosaToLinalg/TosaToLinalg.cpp#L1112-L1156) · 45 lines · From: `TosaToLinalg.cpp:1256`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F08 · `tosa::getNParallelLoopsAttrs`

[`ConversionUtils.cpp:20-24`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Tosa/Utils/ConversionUtils.cpp#L20-L24) · 5 lines · From: `TosaToLinalg.cpp:1342`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F09 · `Builder::getMultiDimIdentityMap`

[`Builders.cpp:392-399`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/IR/Builders.cpp#L392-L399) · 8 lines · From: `TosaToLinalg.cpp:1336`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

### A3. `tensor.dim` and `arith.constant`: builders

#### F10 · `DimOp::build(Value, int64_t)`

[`TensorOps.cpp:893-897`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Tensor/IR/TensorOps.cpp#L893-L897) · 5 lines · From: `TosaToLinalg.cpp:1185`; `TensorOps.cpp:64`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F11 · `arith::ConstantIndexOp::create`

[`ArithOps.cpp:384-392`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Arith/IR/ArithOps.cpp#L384-L392) · 9 lines · From: `TensorOps.cpp:896`; `Arith/Utils/Utils.cpp:73`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F12 · `arith::ConstantIndexOp::build`

[`ArithOps.cpp:378-382`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Arith/IR/ArithOps.cpp#L378-L382) · 5 lines · From: `ArithOps.cpp:388`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F13 · `arith::ConstantOp::verify`

[`ArithOps.cpp:231-251`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Arith/IR/ArithOps.cpp#L231-L251) · 21 lines · From: verifier of `arith.constant`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F14 · `detail::verifyInferredResultTypes`

[`InferTypeOpInterface.cpp:246-257`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Interfaces/InferTypeOpInterface.cpp#L246-L257) · 12 lines · From: `InferTypeOpInterface` verifier, for `tensor.dim` and `arith.constant`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

### A4. `tensor.empty`: builder and verifier

#### F15 · `EmptyOp::build(ArrayRef<int64_t>, Type, ValueRange, Attribute)`

[`TensorOps.cpp:1065-1070`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Tensor/IR/TensorOps.cpp#L1065-L1070) · 6 lines · From: `TosaToLinalg.cpp:1194`, `:1331`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F16 · `EmptyOp::verify`

[`TensorOps.cpp:1081-1084`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Tensor/IR/TensorOps.cpp#L1081-L1084) · 4 lines · From: verifier of `tensor.empty`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F17 · `verifyDynamicDimensionCount`

[`VerificationUtils.cpp:13-22`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Utils/VerificationUtils.cpp#L13-L22) · 10 lines · From: `TensorOps.cpp:1082`, `:2090`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

### A5. `linalg.fill`: builders and verifier

#### F18 · `buildStructuredOp`

[`LinalgOps.cpp:173-200`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Linalg/IR/LinalgOps.cpp#L173-L200) · 28 lines · From: `FillOp::build` (generated, from `TosaToLinalg.cpp:1204`)

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F19 · `fillStructuredOpRegion`

[`LinalgOps.cpp:138-167`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Linalg/IR/LinalgOps.cpp#L138-L167) · 30 lines · From: `LinalgOps.cpp:197`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F20 · `RegionBuilderHelper::yieldOutputs`

[`LinalgOps.cpp:686-691`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Linalg/IR/LinalgOps.cpp#L686-L691) · 6 lines · From: `FillOp::regionBuilder` (generated)

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F21 · `detail::verifyFillInterface`

[`LinalgInterfaces.cpp:1153-1172`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Linalg/IR/LinalgInterfaces.cpp#L1153-L1172) · 20 lines · From: `LinalgFillOpInterface` verifier, `LinalgInterfaces.td:189`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F22 · `isFillInterfaceImpl`

[`LinalgInterfaces.cpp:1132-1151`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Linalg/IR/LinalgInterfaces.cpp#L1132-L1151) · 20 lines · From: `LinalgInterfaces.cpp:1154`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F23 · `DestinationStyleOpInterface::isScalar`

[`DestinationStyleOpInterface.td:149-153`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Interfaces/DestinationStyleOpInterface.td#L149-L153) · 5 lines · From: `LinalgInterfaces.cpp:1140`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F24 · `LinalgOp::getNumParallelLoops (default)`

[`LinalgInterfaces.td:244-247`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Dialect/Linalg/IR/LinalgInterfaces.td#L244-L247) · 4 lines · From: `FillOp::getIndexingMaps` (generated)

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

### A6. `linalg.reduce`: builder and verifier

#### F25 · `ReduceOp::build(ValueRange, ValueRange, ArrayRef<int64_t>, bodyBuild, attrs)`

[`LinalgOps.cpp:1787-1805`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Linalg/IR/LinalgOps.cpp#L1787-L1805) · 19 lines · From: `TosaToLinalg.cpp:1245`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F26 · `buildGenericRegion`

[`LinalgOps.cpp:1116-1135`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Linalg/IR/LinalgOps.cpp#L1116-L1135) · 20 lines · From: `LinalgOps.cpp:1803`, `:1155`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F27 · `ReduceOp::verify`

[`LinalgOps.cpp:1918-2017`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Linalg/IR/LinalgOps.cpp#L1918-L2017) · 100 lines · From: verifier of `linalg.reduce`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F28 · `ReduceOp::getIteratorTypesArray`

[`LinalgOps.cpp:1807-1815`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Linalg/IR/LinalgOps.cpp#L1807-L1815) · 9 lines · From: interface queries from the structured verifiers

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F29 · `ReduceOp::getIndexingMaps`

[`LinalgOps.cpp:1817-1829`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Linalg/IR/LinalgOps.cpp#L1817-L1829) · 13 lines · From: interface queries from the structured verifiers

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F30 · `AffineMap::dropResults(ArrayRef<int64_t>)`

[`AffineMap.h:299-307`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/IR/AffineMap.h#L299-L307) · 9 lines · From: `LinalgOps.cpp:1825`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F31 · `AffineMap::getMultiDimIdentityMap`

[`AffineMap.cpp:332-339`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/IR/AffineMap.cpp#L332-L339) · 8 lines · From: `LinalgOps.cpp:1822`, `:1824`; `FillOp::getIndexingMaps` (generated)

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

### A7. `linalg.generic`: builders

#### F32 · `GenericOp::build(TypeRange, ..., ArrayRef<AffineMap>, ArrayRef<IteratorType>, bodyBuild, attrs)`

[`LinalgOps.cpp:1200-1210`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Linalg/IR/LinalgOps.cpp#L1200-L1210) · 11 lines · From: `TosaToLinalg.cpp:1338`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F33 · `GenericOp::build(TypeRange, ..., StringRef, StringRef, bodyBuild, attrs)`

[`LinalgOps.cpp:1159-1176`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Linalg/IR/LinalgOps.cpp#L1159-L1176) · 18 lines · From: `LinalgOps.cpp:1206`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F34 · `GenericOp::build(TypeRange, ..., ArrayAttr, ArrayAttr, StringAttr, StringAttr, bodyBuild, attrs)`

[`LinalgOps.cpp:1145-1157`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Linalg/IR/LinalgOps.cpp#L1145-L1157) · 13 lines · From: `LinalgOps.cpp:1166`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

### A8. Shared structured-op verifiers (`linalg.fill`, `linalg.reduce`, `linalg.generic`)

#### F35 · `detail::verifyStructuredOpInterface`

[`LinalgInterfaces.cpp:1323-1386`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Linalg/IR/LinalgInterfaces.cpp#L1323-L1386) · 64 lines · From: `LinalgStructuredInterface` verifier, `LinalgInterfaces.td:767`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F36 · `IndexingMapOpInterface::verifyImpl`

[`IndexingMapOpInterface.cpp:50-169`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Interfaces/IndexingMapOpInterface.cpp#L50-L169) · 120 lines · From: `LinalgInterfaces.cpp:1337`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F37 · `verifyIndexingMapOperandType`

[`IndexingMapOpInterface.cpp:17-48`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Interfaces/IndexingMapOpInterface.cpp#L17-L48) · 32 lines · From: `IndexingMapOpInterface.cpp:65`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F38 · `IndexingMapOpInterface::getIndexingMapsArray (default)`

[`IndexingMapOpInterface.td:41-45`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Interfaces/IndexingMapOpInterface.td#L41-L45) · 5 lines · From: `IndexingMapOpInterface.cpp:52`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F39 · `IndexingMapOpInterface::getMatchingIndexingMap (default)`

[`IndexingMapOpInterface.td:55-60`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Interfaces/IndexingMapOpInterface.td#L55-L60) · 6 lines · From: `IndexingMapOpInterface.cpp:68`, `:117`; `LinalgInterfaces.cpp:1343`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F40 · `IndexingMapOpInterface::getLoopsToShapesMap (default)`

[`IndexingMapOpInterface.td:80-83`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Interfaces/IndexingMapOpInterface.td#L80-L83) · 4 lines · From: `IndexingMapOpInterface.td:106`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F41 · `IndexingMapOpInterface::getShapesToLoopsMap (default)`

[`IndexingMapOpInterface.td:105-107`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Interfaces/IndexingMapOpInterface.td#L105-L107) · 3 lines · From: `IndexingMapOpInterface.cpp:97`; `LinalgInterfaces.cpp:1354`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F42 · `IndexingMapOpInterface::getStaticOperandShape (default)`

[`IndexingMapOpInterface.td:119-123`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Interfaces/IndexingMapOpInterface.td#L119-L123) · 5 lines · From: `IndexingMapOpInterface.cpp:84`, `:121`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F43 · `LinalgOp::getShape (default)`

[`LinalgInterfaces.td:700-712`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Dialect/Linalg/IR/LinalgInterfaces.td#L700-L712) · 13 lines · From: `IndexingMapOpInterface.td:121`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F44 · `LinalgOp::getReductionDims (default)`

[`LinalgInterfaces.td:295-298`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Dialect/Linalg/IR/LinalgInterfaces.td#L295-L298) · 4 lines · From: `LinalgInterfaces.cpp:1352`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F45 · `findPositionsOfType`

[`StructuredOpsUtils.h:77-84`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Dialect/Utils/StructuredOpsUtils.h#L77-L84) · 8 lines · From: `LinalgInterfaces.td:296`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F46 · `LinalgOp::getIteratorTypesArray (default, for `linalg.generic`)`

[`LinalgInterfaces.td:513-518`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Dialect/Linalg/IR/LinalgInterfaces.td#L513-L518) · 6 lines · From: `LinalgInterfaces.td:296`, `:309`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F47 · `LinalgOp::getNumLoops (default)`

[`LinalgInterfaces.td:308-310`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Dialect/Linalg/IR/LinalgInterfaces.td#L308-L310) · 3 lines · From: `LinalgInterfaces.cpp:1345`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F48 · `LinalgOp::getOpOperandsMatchingBBargs (default)`

[`LinalgInterfaces.td:594-602`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Dialect/Linalg/IR/LinalgInterfaces.td#L594-L602) · 9 lines · From: `LinalgInterfaces.cpp:1369`, `:1373`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F49 · `LinalgOp::getRank (default)`

[`LinalgInterfaces.td:380-394`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Dialect/Linalg/IR/LinalgInterfaces.td#L380-L394) · 15 lines · From: `FillOp::getIteratorTypesArray`, `FillOp::getIndexingMaps` (generated)

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F50 · `DestinationStyleOpInterface::hasPureTensorSemantics`

[`DestinationStyleOpInterface.td:191-202`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Interfaces/DestinationStyleOpInterface.td#L191-L202) · 12 lines · From: `LinalgInterfaces.cpp:1326`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F51 · `DestinationStyleOpInterface::hasPureBufferSemantics`

[`DestinationStyleOpInterface.td:175-187`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Interfaces/DestinationStyleOpInterface.td#L175-L187) · 13 lines · From: `LinalgInterfaces.cpp:1327`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F52 · `detail::verifyDestinationStyleOpInterface`

[`DestinationStyleOpInterface.cpp:29-62`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Interfaces/DestinationStyleOpInterface.cpp#L29-L62) · 34 lines · From: `DestinationStyleOpInterface` verifier, `DestinationStyleOpInterface.td:205`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F53 · `getNumTensorResults`

[`DestinationStyleOpInterface.cpp:18-26`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Interfaces/DestinationStyleOpInterface.cpp#L18-L26) · 9 lines · From: `DestinationStyleOpInterface.cpp:45`, `:47`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F54 · `DestinationStyleOpInterface::getTiedOpResult`

[`DestinationStyleOpInterface.td:156-165`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Interfaces/DestinationStyleOpInterface.td#L156-L165) · 10 lines · From: `DestinationStyleOpInterface.cpp:52`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F55 · `OpTrait::impl::verifyValueSizeAttr`

[`Operation.cpp:1268-1289`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/IR/Operation.cpp#L1268-L1289) · 22 lines · From: `Operation.cpp:1293`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F56 · `OpTrait::impl::verifyOperandSizeAttr`

[`Operation.cpp:1291-1294`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/IR/Operation.cpp#L1291-L1294) · 4 lines · From: `AttrSizedOperandSegments` trait on `linalg.fill` and `linalg.generic`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

### A9. Region body: `linalg.yield` and arith verifiers

#### F57 · `linalg::YieldOp::verify`

[`LinalgOps.cpp:2514-2523`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Linalg/IR/LinalgOps.cpp#L2514-L2523) · 10 lines · From: verifier of `linalg.yield`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F58 · `verifyYield`

[`LinalgOps.cpp:2491-2512`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Linalg/IR/LinalgOps.cpp#L2491-L2512) · 22 lines · From: `LinalgOps.cpp:2520`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F59 · `arith::ExtFOp::verify`

[`ArithOps.cpp:1713`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Arith/IR/ArithOps.cpp#L1713) · 1 line · From: verifier of `arith.extf`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F60 · `verifyExtOp<FloatType>`

[`ArithOps.cpp:1546-1557`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Arith/IR/ArithOps.cpp#L1546-L1557) · 12 lines · From: `ArithOps.cpp:1713`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F61 · `arith::TruncFOp::verify`

[`ArithOps.cpp:1836-1838`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Arith/IR/ArithOps.cpp#L1836-L1838) · 3 lines · From: verifier of `arith.truncf`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F62 · `verifyTruncateOp<FloatType>`

[`ArithOps.cpp:1560-1571`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Arith/IR/ArithOps.cpp#L1560-L1571) · 12 lines · From: `ArithOps.cpp:1837`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F63 · `OpTrait::impl::verifySameOperandsAndResultType`

[`Operation.cpp:1109-1142`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/IR/Operation.cpp#L1109-L1142) · 34 lines · From: trait on `arith.addf`, `arith.addi`, `arith.divsi`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F64 · `OpTrait::impl::verifyElementwise`

[`Operation.cpp:1316-1353`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/IR/Operation.cpp#L1316-L1353) · 38 lines · From: `ElementwiseMappable` trait on arith ops, `ArithOps.td:37`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F65 · `OpTrait::impl::verifySameOperandsAndResultShape`

[`Operation.cpp:1056-1069`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/IR/Operation.cpp#L1056-L1069) · 14 lines · From: trait on `arith.extf`, `arith.truncf`, `ArithOps.td:148`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F66 · `verifyCompatibleShapes(TypeRange)`

[`TypeUtilities.cpp:120-165`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/IR/TypeUtilities.cpp#L120-L165) · 46 lines · From: `Operation.cpp:1064`, `:1347`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F67 · `impl::verifyCastInterfaceOp`

[`CastInterfaces.cpp:39-59`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Interfaces/CastInterfaces.cpp#L39-L59) · 21 lines · From: `CastOpInterface` verifier, `CastInterfaces.td:47`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F68 · `arith::ExtFOp::areCastCompatible`

[`ArithOps.cpp:1709-1711`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Arith/IR/ArithOps.cpp#L1709-L1711) · 3 lines · From: `CastInterfaces.cpp:46`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F69 · `arith::TruncFOp::areCastCompatible`

[`ArithOps.cpp:1832-1834`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Arith/IR/ArithOps.cpp#L1832-L1834) · 3 lines · From: `CastInterfaces.cpp:46`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F70 · `checkWidthChangeCast`

[`ArithOps.cpp:1574-1586`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Arith/IR/ArithOps.cpp#L1574-L1586) · 13 lines · From: `ArithOps.cpp:1710`, `:1833`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F71 · `areValidCastInputsAndOutputs`

[`ArithOps.cpp:1533-1539`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Arith/IR/ArithOps.cpp#L1533-L1539) · 7 lines · From: `ArithOps.cpp:1576`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F72 · `getTypeIfLike`

[`ArithOps.cpp:1510-1514`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Arith/IR/ArithOps.cpp#L1510-L1514) · 5 lines · From: `ArithOps.cpp:1579`, `:1580`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F73 · `getUnderlyingType`

[`ArithOps.cpp:1496-1507`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Arith/IR/ArithOps.cpp#L1496-L1507) · 12 lines · From: `ArithOps.cpp:1512`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

### A10. `tensor.expand_shape`: builder path, including OQ-4

#### F74 · `ExpandShapeOp::build(Type, Value, ArrayRef<ReassociationExprs>), ODS body`

[`TensorOps.td:1158-1164`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Dialect/Tensor/IR/TensorOps.td#L1158-L1164) · 7 lines · From: `TosaToLinalg.cpp:1370`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F75 · `convertReassociationMapsToIndices`

[`ReshapeOpsUtils.cpp:433-444`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Utils/ReshapeOpsUtils.cpp#L433-L444) · 12 lines · From: `TensorOps.td:1162`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F76 · `ExpandShapeOp::build(Type, Value, ArrayRef<ReassociationIndices>)`

[`TensorOps.cpp:1961-1975`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Tensor/IR/TensorOps.cpp#L1961-L1975) · 15 lines · From: `TensorOps.td:1163`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F77 · `tensor::getMixedSizes`

[`TensorOps.cpp:69-76`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Tensor/IR/TensorOps.cpp#L69-L76) · 8 lines · From: `TensorOps.cpp:1965`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F78 · `tensor::getMixedSize`

[`TensorOps.cpp:60-67`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Tensor/IR/TensorOps.cpp#L60-L67) · 8 lines · From: `TensorOps.cpp:74`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F79 · `DimOp::fold`

[`TensorOps.cpp:925-982`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Tensor/IR/TensorOps.cpp#L925-L982) · 58 lines · From: `createOrFold`, `TensorOps.cpp:64`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F80 · `ExpandShapeOp::inferOutputShape`

[`TensorOps.cpp:1933-1944`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Tensor/IR/TensorOps.cpp#L1933-L1944) · 12 lines · From: `TensorOps.cpp:1967`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F81 · `inferExpandShapeOutputShape`

[`Arith/Utils/Utils.cpp:25-84`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Arith/Utils/Utils.cpp#L25-L84) · 60 lines · From: `TensorOps.cpp:1939`

**OQ-4:** the exact failure condition, with the lines that establish it:

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F82 · `arith::DivSIOp::fold`

[`ArithOps.cpp:833-854`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Arith/IR/ArithOps.cpp#L833-L854) · 22 lines · From: `createOrFold`, `Arith/Utils/Utils.cpp:74`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F83 · `foldDivMul`

[`ArithOps.cpp:778-791`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Arith/IR/ArithOps.cpp#L778-L791) · 14 lines · From: `ArithOps.cpp:839`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F84 · `getMixedValues(ArrayRef<int64_t>, ValueRange, MLIRContext*)`

[`StaticValueUtils.cpp:211-230`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Utils/StaticValueUtils.cpp#L211-L230) · 20 lines · From: `StaticValueUtils.cpp:233`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F85 · `getMixedValues(ArrayRef<int64_t>, ValueRange, Builder&)`

[`StaticValueUtils.cpp:231-234`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Utils/StaticValueUtils.cpp#L231-L234) · 4 lines · From: `Arith/Utils/Utils.cpp:36`, `:43`, `:83`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F86 · `ExpandShapeOp::build(Type, Value, ArrayRef<ReassociationIndices>, ArrayRef<OpFoldResult>)`

[`TensorOps.cpp:1950-1959`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Tensor/IR/TensorOps.cpp#L1950-L1959) · 10 lines · From: `TensorOps.cpp:1973`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F87 · `decomposeMixedValues`

[`StaticValueUtils.cpp:238-251`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Utils/StaticValueUtils.cpp#L238-L251) · 14 lines · From: `TensorOps.cpp:1955`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F88 · `getReassociationIndicesAttribute`

[`ReshapeOpsUtils.cpp:424-431`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Utils/ReshapeOpsUtils.cpp#L424-L431) · 8 lines · From: `TensorOps.cpp:1957`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

### A11. `tensor.expand_shape`: verifier

#### F89 · `ExpandShapeOp::verify`

[`TensorOps.cpp:2070-2102`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Tensor/IR/TensorOps.cpp#L2070-L2102) · 33 lines · From: verifier of `tensor.expand_shape`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F90 · `verifyTensorReshapeOp<ExpandShapeOp>`

[`TensorOps.cpp:2042-2068`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Tensor/IR/TensorOps.cpp#L2042-L2068) · 27 lines · From: `TensorOps.cpp:2101`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F91 · `verifyReshapeLikeTypes`

[`ReshapeOpsUtils.h:142-175`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Dialect/Utils/ReshapeOpsUtils.h#L142-L175) · 34 lines · From: `TensorOps.cpp:2048`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F92 · `isReassociationValid`

[`ReshapeOpsUtils.cpp:460-488`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Utils/ReshapeOpsUtils.cpp#L460-L488) · 29 lines · From: `ReshapeOpsUtils.h:167`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F93 · `reshapeLikeShapesAreCompatible`

[`ReshapeOpsUtils.cpp:490-523`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Utils/ReshapeOpsUtils.cpp#L490-L523) · 34 lines · From: `ReshapeOpsUtils.h:171`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F94 · `ExpandShapeOp::getReassociationMaps`

[`TensorOps.cpp:1985-1987`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Tensor/IR/TensorOps.cpp#L1985-L1987) · 3 lines · From: `ReshapeOpsUtils.h:158`; `TensorOps.cpp:2061`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F95 · `ExpandShapeOp::getReassociationExprs`

[`TensorOps.cpp:1988-1991`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Tensor/IR/TensorOps.cpp#L1988-L1991) · 4 lines · From: `TensorOps.cpp:1986`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F96 · `getReassociationIndices (ODS accessor)`

[`TensorOps.td:1086-1094`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/Dialect/Tensor/IR/TensorOps.td#L1086-L1094) · 9 lines · From: `TensorOps.cpp:1990`; `ReshapeOpsUtils.h:174`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F97 · `convertReassociationIndicesToExprs`

[`ReshapeOpsUtils.cpp:396-408`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Utils/ReshapeOpsUtils.cpp#L396-L408) · 13 lines · From: `TensorOps.cpp:1989`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F98 · `getSymbolLessAffineMaps`

[`ReshapeOpsUtils.cpp:446-458`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Utils/ReshapeOpsUtils.cpp#L446-L458) · 13 lines · From: `TensorOps.cpp:1986`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F99 · `getMaxPosOfType`

[`ReshapeOpsUtils.cpp:410-422`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Utils/ReshapeOpsUtils.cpp#L410-L422) · 13 lines · From: `ReshapeOpsUtils.cpp:448`, `:449`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F100 · `CollapseShapeOp::inferCollapsedType(RankedTensorType, ArrayRef<AffineMap>)`

[`TensorOps.cpp:2002-2027`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Tensor/IR/TensorOps.cpp#L2002-L2027) · 26 lines · From: `TensorOps.cpp:2063`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F101 · `tensor::isSameTypeWithoutEncoding`

[`TensorOps.cpp:130-138`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Tensor/IR/TensorOps.cpp#L130-L138) · 9 lines · From: `TensorOps.cpp:2064`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

### A12. Shared shape and affine utilities

#### F102 · `concatAffineMaps`

[`AffineMap.cpp:833-850`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/IR/AffineMap.cpp#L833-L850) · 18 lines · From: `IndexingMapOpInterface.td:82`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F103 · `inversePermutation`

[`AffineMap.cpp:788-810`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/IR/AffineMap.cpp#L788-L810) · 23 lines · From: `IndexingMapOpInterface.td:106`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F104 · `AffineMap::compose(ArrayRef<int64_t>)`

[`AffineMap.cpp:580-591`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/IR/AffineMap.cpp#L580-L591) · 12 lines · From: `IndexingMapOpInterface.cpp:106`, `:119`, `:120`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F105 · `ShapedType::getNumElements() (interface)`

[`BuiltinTypeInterfaces.td:351-354`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/IR/BuiltinTypeInterfaces.td#L351-L354) · 4 lines · From: `TensorOps.cpp:2053`, `:2054`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F106 · `ShapedType::getNumElements(ArrayRef<int64_t>)`

[`BuiltinTypeInterfaces.cpp:83-94`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/IR/BuiltinTypeInterfaces.cpp#L83-L94) · 12 lines · From: `BuiltinTypeInterfaces.td:353`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F107 · `ShapedType::hasStaticShape()`

[`BuiltinTypeInterfaces.td:379-382`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/IR/BuiltinTypeInterfaces.td#L379-L382) · 4 lines · From: `TensorOps.cpp:2052`; `Arith/Utils/Utils.cpp:40`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

#### F108 · `ShapedType::getNumDynamicDims()`

[`BuiltinTypeInterfaces.td:392-394`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/include/mlir/IR/BuiltinTypeInterfaces.td#L392-L394) · 3 lines · From: `VerificationUtils.cpp:15`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

## Part A addition: folder reached before the pattern

#### X1 · `ReduceSumOp::fold, from REDUCE_FOLDER`

[`TosaCanonicalizations.cpp:2072-2082`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.1/mlir/lib/Dialect/Tosa/IR/TosaCanonicalizations.cpp#L2072-L2082) · 11 lines · From: `DialectConversion.cpp:2603` → `:2672`, before `legalizeWithPattern` at `:2613`. Expanded at `TosaCanonicalizations.cpp:2089`

| Q1 | Q2 | Q3 |
|---|---|---|
| | | |

## Part B: generated functions

One row per function, because most are mechanical. Split a row if a function has more than one expression to record. A constraint helper shared by several ops is listed once, under the first op that uses it.

### `tosa.reduce_sum`

| ID | Function | Location | Lines | From | Q1 | Q2 | Q3 |
|---|---|---|---:|---|---|---|---|
| G01 | `ReduceSumOp::getAxis` | `TosaOps.cpp.inc:24276-24279` | 4 | `TosaToLinalg.cpp:2244` | | | |

### `tensor.dim`

| ID | Function | Location | Lines | From | Q1 | Q2 | Q3 |
|---|---|---|---:|---|---|---|---|
| G02 | `DimOp::create(Value, int64_t)` | `TensorOps.cpp.inc:1551-1557` | 7 | `TosaToLinalg.cpp:1185` | | | |
| G03 | `DimOp::build(Value, Value)` | `TensorOps.cpp.inc:1581-1595` | 15 | `TensorOps.cpp:897` | | | |
| G04 | `DimOp::inferReturnTypes` | `TensorOps.cpp.inc:1762-1768` | 7 | generated `DimOp::build`; `verifyInferredResultTypes` | | | |
| G05 | `DimOp::verifyInvariantsImpl` | `TensorOps.cpp.inc:1730-1756` | 27 | verifier of `tensor.dim` | | | |
| G06 | `__mlir_ods_local_type_constraint_TensorOps5` | `TensorOps.cpp.inc:85-93` | 9 | `tensor.dim` verifier | | | |
| G07 | `__mlir_ods_local_type_constraint_TensorOps6` | `TensorOps.cpp.inc:95-103` | 9 | `tensor.dim` verifier | | | |

### `tensor.empty`

| ID | Function | Location | Lines | From | Q1 | Q2 | Q3 |
|---|---|---|---:|---|---|---|---|
| G08 | `EmptyOp::create(ArrayRef<int64_t>, Type, ValueRange, Attribute)` | `TensorOps.cpp.inc:1952-1958` | 7 | `TosaToLinalg.cpp:1194`, `:1331` | | | |
| G09 | `EmptyOp::build(Type, ValueRange)` | `TensorOps.cpp.inc:1976-1979` | 4 | `TensorOps.cpp:1069` | | | |
| G10 | `EmptyOp::verifyInvariantsImpl` | `TensorOps.cpp.inc:2032-2052` | 21 | verifier of `tensor.empty` | | | |
| G11 | `__mlir_ods_local_type_constraint_TensorOps3` | `TensorOps.cpp.inc:65-73` | 9 | `tensor.empty` verifier | | | |
| G12 | `__mlir_ods_local_type_constraint_TensorOps7` | `TensorOps.cpp.inc:105-113` | 9 | `tensor.empty` verifier | | | |

### `arith.constant`

| ID | Function | Location | Lines | From | Q1 | Q2 | Q3 |
|---|---|---|---:|---|---|---|---|
| G13 | `ConstantOp::create(TypedAttr)` | `ArithOps.cpp.inc:4381-4387` | 7 | `TosaToLinalg.cpp:1202` | | | |
| G14 | `ConstantOp::build(TypedAttr)` | `ArithOps.cpp.inc:4366-4379` | 14 | generated `ConstantOp::create` | | | |
| G15 | `ConstantOp::build(Type, TypedAttr)` | `ArithOps.cpp.inc:4349-4352` | 4 | `ArithOps.cpp:380` | | | |
| G16 | `ConstantOp::inferReturnTypes` | `ArithOps.cpp.inc:4558-4566` | 9 | generated `ConstantOp::build`; `verifyInferredResultTypes` | | | |
| G17 | `ConstantOp::verifyInvariantsImpl` | `ArithOps.cpp.inc:4532-4550` | 19 | verifier of `arith.constant` | | | |
| G18 | `__mlir_ods_local_attr_constraint_ArithOps6` | `ArithOps.cpp.inc:218-224` | 7 | `arith.constant` verifier | | | |
| G19 | `__mlir_ods_local_type_constraint_ArithOps5` | `ArithOps.cpp.inc:118-126` | 9 | `arith.constant` verifier | | | |

### `linalg.fill`

| ID | Function | Location | Lines | From | Q1 | Q2 | Q3 |
|---|---|---|---:|---|---|---|---|
| G20 | `FillOp::create(ValueRange, ValueRange, attrs)` | `LinalgStructuredOps.cpp.inc:21114-21120` | 7 | `TosaToLinalg.cpp:1204` | | | |
| G21 | `FillOp::build(ValueRange, ValueRange, attrs)` | `LinalgStructuredOps.cpp.inc:21108-21112` | 5 | generated `FillOp::create` | | | |
| G22 | `FillOp::regionBuilder` | `LinalgNamedStructuredOps.yamlgen.cpp.inc:8997-9007` | 11 | `LinalgOps.cpp:162` | | | |
| G23 | `FillOp::getIteratorTypesArray` | `LinalgNamedStructuredOps.yamlgen.cpp.inc:8975-8978` | 4 | interface queries from the structured verifiers | | | |
| G24 | `FillOp::getIndexingMaps` | `LinalgNamedStructuredOps.yamlgen.cpp.inc:8980-8989` | 10 | interface queries from the structured verifiers | | | |
| G25 | `FillOp::verifyInvariantsImpl` | `LinalgStructuredOps.cpp.inc:21164-21197` | 34 | verifier of `linalg.fill` | | | |
| G26 | `__mlir_ods_local_region_constraint_LinalgStructuredOps1` | `LinalgStructuredOps.cpp.inc:317-326` | 10 | `linalg.fill` verifier | | | |
| G27 | `__mlir_ods_local_type_constraint_LinalgStructuredOps1` | `LinalgStructuredOps.cpp.inc:115-123` | 9 | `linalg.fill` verifier | | | |
| G28 | `__mlir_ods_local_type_constraint_LinalgStructuredOps2` | `LinalgStructuredOps.cpp.inc:125-133` | 9 | `linalg.fill` verifier | | | |
| G29 | `__mlir_ods_local_type_constraint_LinalgStructuredOps3` | `LinalgStructuredOps.cpp.inc:135-143` | 9 | `linalg.fill` verifier | | | |

### `linalg.reduce`

| ID | Function | Location | Lines | From | Q1 | Q2 | Q3 |
|---|---|---|---:|---|---|---|---|
| G30 | `ReduceOp::create(inputs, inits, dimensions, bodyBuild, attrs)` | `LinalgStructuredOps.cpp.inc:35485-35491` | 7 | `TosaToLinalg.cpp:1245` | | | |
| G31 | `ReduceOp::build(TypeRange, inputs, inits, ArrayRef<int64_t>)` | `LinalgStructuredOps.cpp.inc:35517-35523` | 7 | `LinalgOps.cpp:1792` | | | |
| G32 | `ReduceOp::verifyInvariantsImpl` | `LinalgStructuredOps.cpp.inc:35588-35626` | 39 | verifier of `linalg.reduce` | | | |
| G33 | `__mlir_ods_local_attr_constraint_LinalgStructuredOps10` | `LinalgStructuredOps.cpp.inc:301-309` | 9 | `linalg.reduce` verifier | | | |
| G34 | `__mlir_ods_local_region_constraint_LinalgStructuredOps2` | `LinalgStructuredOps.cpp.inc:328-337` | 10 | `linalg.reduce` verifier | | | |
| G35 | `__mlir_ods_local_type_constraint_LinalgStructuredOps5` | `LinalgStructuredOps.cpp.inc:155-163` | 9 | `linalg.reduce` verifier | | | |
| G36 | `__mlir_ods_local_type_constraint_LinalgStructuredOps6` | `LinalgStructuredOps.cpp.inc:165-173` | 9 | `linalg.reduce` verifier | | | |

### `linalg.generic`

| ID | Function | Location | Lines | From | Q1 | Q2 | Q3 |
|---|---|---|---:|---|---|---|---|
| G37 | `GenericOp::create(TypeRange, ..., ArrayRef<AffineMap>, ArrayRef<IteratorType>, bodyBuild, attrs)` | `LinalgStructuredOps.cpp.inc:22299-22305` | 7 | `TosaToLinalg.cpp:1338` | | | |
| G38 | `GenericOp::build(TypeRange, ..., ArrayAttr, ArrayAttr, StringAttr, StringAttr)` | `LinalgStructuredOps.cpp.inc:22323-22337` | 15 | `LinalgOps.cpp:1151` | | | |
| G39 | `GenericOp::verifyInvariantsImpl` | `LinalgStructuredOps.cpp.inc:22402-22453` | 52 | verifier of `linalg.generic` | | | |
| G40 | `__mlir_ods_local_attr_constraint_LinalgStructuredOps1` | `LinalgStructuredOps.cpp.inc:175-181` | 7 | `linalg.generic` verifier | | | |
| G41 | `__mlir_ods_local_attr_constraint_LinalgStructuredOps8` | `LinalgStructuredOps.cpp.inc:273-279` | 7 | `linalg.generic` verifier | | | |
| G42 | `__mlir_ods_local_attr_constraint_LinalgStructuredOps9` | `LinalgStructuredOps.cpp.inc:287-293` | 7 | `linalg.generic` verifier | | | |

### `linalg.yield`

| ID | Function | Location | Lines | From | Q1 | Q2 | Q3 |
|---|---|---|---:|---|---|---|---|
| G43 | `YieldOp::create(ValueRange)` | `LinalgOps.cpp.inc:2479-2485` | 7 | `TosaToLinalg.cpp:1283`, `:1346` | | | |
| G44 | `YieldOp::build(ValueRange)` | `LinalgOps.cpp.inc:2475-2477` | 3 | generated `YieldOp::create` | | | |
| G45 | `YieldOp::verifyInvariantsImpl` | `LinalgOps.cpp.inc:2530-2541` | 12 | verifier of `linalg.yield` | | | |
| G46 | `__mlir_ods_local_type_constraint_LinalgOps6` | `LinalgOps.cpp.inc:82-90` | 9 | `linalg.yield` verifier | | | |

### `arith.addf`

| ID | Function | Location | Lines | From | Q1 | Q2 | Q3 |
|---|---|---|---:|---|---|---|---|
| G47 | `AddFOp::create(ValueRange, attrs)` | `ArithOps.cpp.inc:709-715` | 7 | `TosaToLinalg.cpp:1118` | | | |
| G48 | `AddFOp::build(ValueRange, attrs)` | `ArithOps.cpp.inc:682-707` | 26 | generated `AddFOp::create` | | | |
| G49 | `AddFOp::inferReturnTypes` | `ArithOps.cpp.inc:819-827` | 9 | generated `AddFOp::build`; `verifyInferredResultTypes` | | | |
| G50 | `AddFOp::verifyInvariantsImpl` | `ArithOps.cpp.inc:779-813` | 35 | verifier of `arith.addf` | | | |
| G51 | `__mlir_ods_local_attr_constraint_ArithOps1` | `ArithOps.cpp.inc:148-154` | 7 | `arith.addf` verifier | | | |
| G52 | `__mlir_ods_local_attr_constraint_ArithOps2` | `ArithOps.cpp.inc:162-168` | 7 | `arith.addf` verifier | | | |
| G53 | `__mlir_ods_local_type_constraint_ArithOps1` | `ArithOps.cpp.inc:78-86` | 9 | `arith.addf` verifier | | | |

### `arith.addi`

| ID | Function | Location | Lines | From | Q1 | Q2 | Q3 |
|---|---|---|---:|---|---|---|---|
| G54 | `AddIOp::create(ValueRange, attrs)` | `ArithOps.cpp.inc:1287-1293` | 7 | `TosaToLinalg.cpp:1122` | | | |
| G55 | `AddIOp::build(ValueRange, attrs)` | `ArithOps.cpp.inc:1260-1285` | 26 | generated `AddIOp::create` | | | |
| G56 | `AddIOp::inferReturnTypes` | `ArithOps.cpp.inc:1393-1401` | 9 | generated `AddIOp::build`; `verifyInferredResultTypes` | | | |
| G57 | `AddIOp::verifyInvariantsImpl` | `ArithOps.cpp.inc:1357-1387` | 31 | verifier of `arith.addi` | | | |
| G58 | `__mlir_ods_local_attr_constraint_ArithOps3` | `ArithOps.cpp.inc:176-182` | 7 | `arith.addi` verifier | | | |
| G59 | `__mlir_ods_local_type_constraint_ArithOps2` | `ArithOps.cpp.inc:88-96` | 9 | `arith.addi` verifier | | | |

### `arith.extf`

| ID | Function | Location | Lines | From | Q1 | Q2 | Q3 |
|---|---|---|---:|---|---|---|---|
| G60 | `ExtFOp::create(Type, Value, FastMathFlagsAttr)` | `ArithOps.cpp.inc:6983-6989` | 7 | `TosaToLinalg.cpp:1253` | | | |
| G61 | `ExtFOp::build(Type, Value, FastMathFlagsAttr)` | `ArithOps.cpp.inc:6975-6981` | 7 | generated `ExtFOp::create` | | | |
| G62 | `ExtFOp::verifyInvariantsImpl` | `ArithOps.cpp.inc:7067-7093` | 27 | verifier of `arith.extf` | | | |

### `arith.truncf`

| ID | Function | Location | Lines | From | Q1 | Q2 | Q3 |
|---|---|---|---:|---|---|---|---|
| G63 | `TruncFOp::create(Type, Value)` | `ArithOps.cpp.inc:21712-21718` | 7 | `TosaToLinalg.cpp:1344` | | | |
| G64 | `TruncFOp::build(Type, Value)` | `ArithOps.cpp.inc:21706-21710` | 5 | generated `TruncFOp::create` | | | |
| G65 | `TruncFOp::verifyInvariantsImpl` | `ArithOps.cpp.inc:21822-21852` | 31 | verifier of `arith.truncf` | | | |

### `arith.divsi`

| ID | Function | Location | Lines | From | Q1 | Q2 | Q3 |
|---|---|---|---:|---|---|---|---|
| G66 | `DivSIOp::build(Value, Value, bool)` | `ArithOps.cpp.inc:6011-6028` | 18 | `createOrFold`, `Arith/Utils/Utils.cpp:74` | | | |
| G67 | `DivSIOp::inferReturnTypes` | `ArithOps.cpp.inc:6221-6229` | 9 | generated `DivSIOp::build`; `verifyInferredResultTypes` | | | |
| G68 | `DivSIOp::verifyInvariantsImpl` | `ArithOps.cpp.inc:6185-6215` | 31 | verifier of `arith.divsi` | | | |
| G69 | `__mlir_ods_local_attr_constraint_ArithOps7` | `ArithOps.cpp.inc:232-238` | 7 | `arith.divsi` verifier | | | |

### `tensor.expand_shape`

| ID | Function | Location | Lines | From | Q1 | Q2 | Q3 |
|---|---|---|---:|---|---|---|---|
| G70 | `ExpandShapeOp::create(Type, Value, ArrayRef<ReassociationExprs>)` | `TensorOps.cpp.inc:2374-2380` | 7 | `TosaToLinalg.cpp:1370`, through `PatternMatch.h:532` | | | |
| G71 | `ExpandShapeOp::build(Type, Value, ArrayRef<ReassociationExprs>)` | `TensorOps.cpp.inc:2367-2372` | 6 | generated `ExpandShapeOp::create` | | | |
| G72 | `ExpandShapeOp::build(Type, Value, ArrayAttr, ValueRange, ArrayRef<int64_t>)` | `TensorOps.cpp.inc:2447-2453` | 7 | `TensorOps.cpp:1956` | | | |
| G73 | `ExpandShapeOp::verifyInvariantsImpl` | `TensorOps.cpp.inc:2539-2575` | 37 | verifier of `tensor.expand_shape` | | | |
| G74 | `__mlir_ods_local_attr_constraint_TensorOps1` | `TensorOps.cpp.inc:166-172` | 7 | `tensor.expand_shape` verifier | | | |
| G75 | `__mlir_ods_local_attr_constraint_TensorOps3` | `TensorOps.cpp.inc:194-200` | 7 | `tensor.expand_shape` verifier | | | |

## Boundary: named, not counted

Follow one of these if an answer leads there, then add it to the worksheet and the count.

| What | Where | Why it is outside |
|---|---|---|
| Conversion driver | `OperationLegalizer::legalize` `DialectConversion.cpp:2537-2638`, `legalizeWithFold` `:2649-2707`, `legalizeWithPattern` `:2726`, `legalizePatternResult` `:2861`; `OpBuilder::tryFold` `Builders.cpp:478-555` | Generic machinery, shared by all patterns |
| Pattern plumbing | `replaceOpWithNewOp` `PatternMatch.h:529-535`; `notifyMatchFailure` | Generic machinery |
| Validity oracle for the source op (A5, not A3) | `verifyReduceOp` `TosaOps.cpp:4242-4290`; `ReduceInferReturnTypes` `TosaOps.cpp:4193-4207`; `isCompatibleReturnTypes` `TosaOps.cpp:4209-4216`; `ReduceSumOp::verifyInvariantsImpl` in `TosaOps.cpp.inc` | Decides whether a case is in V, before any conversion runs |
| Verifier dispatch | `OperationVerifier`; generated `verifyInvariants` wrappers and interface models; trait dispatch in `OpDefinition.h` | Calls the listed verifiers. **Not read for this file** |
| Structural traits | `ZeroRegions`, `OneRegion`, `SingleBlock`, `NOperands`, `OneResult`, `IsTerminator` and similar; `SingleBlockImplicitTerminator::verifyRegionTrait` `OpDefinition.h:993` | Named for region, operand and terminator structure. Only the last was read |
| Type-inference plumbing | `InferTypeOpInterface::refineReturnTypes`, `isCompatibleReturnTypes` | Called by the listed `verifyInferredResultTypes`. **Not read for this file** |
| Single-value accessors | `getRank`, `getDimSize`, `isDynamicDim` (`BuiltinTypeInterfaces.td:345-348`, `:398-401`, `:365-368`); `getNumDpsInputs`, `getDpsInitOperand` and similar | Each returns one stored value or a size. Their uses still count as answers in the caller |
| IR construction and uniquing | `RankedTensorType::get`, `AffineMap::get`, `Builder::get*Attr`, `getAffineDimExpr`, `AffineExpr::replaceDims`, `shiftSymbols` | Core IR. **Not read for this file** |
| Parsing and printing | Generated `parse` and `print`; `printCommonStructuredOpParts` | Outside the conversion. Relevant only if the runner re-parses output |
| Pipeline passes | Everything in `addTosaToLinalgPasses`, `TosaToLinalgPass.cpp:82` onward | This covers the bare pass only |
