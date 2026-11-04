# Decision brief: OQ-9, the NPU-dialect first target

Written 2026-11-04. This brief changes no decision's status. The docs recommend no candidate as the
first NPU target, so this brief recommends none. TorchToTosa is excluded by D-010, and NXP Neutron
stays out (D-009).

**Labels (rule 6):** **[F]** read from source at the commit below. **[H]** hypothesis, not run.
**[E]** estimate taken from the project's own docs. Nothing was built or executed for this brief.

**Question:** which NPU-dialect conversion is the first target, and on what domain?
(`docs/risks-and-open-questions.md:27`)

## Commits read

| Short name | Conversion | Repository @ commit (date) | LLVM source @ commit (version, date) |
|---|---|---|---|
| **tt** | TTIR→TTNN | `tenstorrent/tt-mlir` @ `f9dc1b3e5101` (2026-10-26) | `llvm/llvm-project` @ `4efe170d858e` (22.0 dev, 2025-10-06) |
| **aie** | VectorToAIEVec | `Xilinx/mlir-aie` @ `7553ce5647ff` (2026-10-31) | `ROCm/llvm-project` @ `bdf04ebb32d7` (24.0 dev, 2026-10-01) |
| **vpux** | IE→VPU | `openvinotoolkit/npu_compiler` @ `3009fe6a0e38` (2026-11-03, tip of `develop`) | `intel-staging/npu-compiler-llvm` @ `980c1ca33aad` (23.0 dev, 2026-09-02) |

Citations are `file:line` at these commits. Against the current pin `6dfe1677ab8d` (GitHub compare):
tt's LLVM is 33,634 commits behind; vpux's fork has diverged, 42 ahead and 18,434 behind. aie's LLVM
is on a different fork and was not compared.

## At a glance

| | tt | aie | vpux |
|---|---|---|---|
| macOS arm64 documented | yes, compiler only | no | no |
| Conversion driver | full | partial | full |
| Patterns reachable without editing source | yes, public populate | no, `static` | partly, header plus generated file |
| Rank logic on the most obvious reduce op | none | verifier caps rank at 1 | none |
| Rank threshold found | 4 and others; see below | 1 and 2 | 4 |
| Spec behind the oracle | none found in repo | none found in repo | OpenVINO opset spec, not read |

## 1. LLVM pin and build dependencies [F]

| | LLVM | Other dependencies | Source |
|---|---|---|---|
| tt | Own commit, built with projects `mlir,lld`, target `host`, assertions and Python bindings on, `MinSizeRel`. | flatbuffers; stablehlo and shardy (clone and patch only); Python 3.12; Ninja; CMake ≥ 3.24; googletest on macOS. tt-metal only with runtime or OpModel on. | `env/CMakeLists.txt:4-8,64-69,82-102`; `getting-started.md:17-22,49`; `third_party/CMakeLists.txt:134` |
| aie | Own commit from the ROCm fork. Configures with an LLVM older than major 24 are rejected, so Homebrew 23.1.1 fails. Assertions and Python bindings on, `Release`. | CMake ≥ 3.30; Python; submodules `aie-rt`, `aie_api`, `bootgen`. Vitis, XRT and Peano are optional. | `clone-llvm.sh:18-20`; `CMakeLists.txt:15,103-111,143-146,300`; `build-llvm.sh:24-41`; `Building.md:65-70` |
| vpux | Fork pinned as a submodule, built inside the compiler's CMake tree unless `ENABLE_PREBUILT_LLVM_MLIR_LIBS` is set. | A built OpenVINO at `88f8c6bf7c46` (required by CMake); submodules `vpucostmodel`, `elf`, `gtest-parallel`; Ninja; CMake ≥ 3.20; ccache for developer presets. | `.gitmodules:1-14`; `thirdparty/CMakeLists.txt:79,96`; `CMakeLists.txt:13,52`; `validation/openvino_config.json:2`; `how_to_build.md:9-17,27-30` |

## 2. macOS arm64 and compilers

Here: Apple clang 21.0.0 and Homebrew LLVM 23.1.1 (`STATUS.md:13,15`).

| | Platform support | Compiler requirement | Compared with this machine |
|---|---|---|---|
| tt | **[F]** Offline compiler supported on macOS; runtime is not (`getting-started.md:15,123-127`). OpModel is off on Apple (`CMakeLists.txt:105-108`). A macOS workflow exists with runtime off (`call-build-macos.yml:21`), but it only triggers manually or by `workflow_call` (`:3-10`), and no other workflow calls it. Its recent results were not checked. | **[F]** `Clang >= 14 & <= 18` (`getting-started.md:18`). A search of the CMake files found no version check enforcing it. LLVM at this pin needs AppleClang ≥ 10 (`CheckCompilerVersion.cmake:11`). | **[F]** Both 21 and 23 are numerically outside the documented range. **[H]** Apple's version numbers do not map onto upstream clang's, so the effect is unknown until a build runs. |
| aie | **[F]** Documented for Ubuntu and Windows (`README.md:82-85`, `Building.md:5`). CI is Ubuntu and Windows (`buildAndTestMulti.yml:50-64`). macOS wheel builds are commented out as out of date (`mlirAIEDistro.yml:115-122`). | **[F]** `clang-14` and `lld-14` in the Ubuntu instructions (`Building.md:117`). AppleClang ≥ 10 for LLVM at this pin. | **[H]** Unsupported here. LLVM alone may compile, but the project's own macOS path is abandoned. |
| vpux | **[F]** Linux and Windows only (`how_to_build.md:21,118`); a search of the guides and CMake entry files found no macOS mention. CI is Ubuntu and Windows. Presets are named `build-x86_64` (`CMakePresets.json:7`). | **[F]** GCC 11.4+ or Clang 17+, or Visual Studio 2022 (`how_to_build.md:27,124`). AppleClang is not listed. | **[H]** Unsupported here, and arm64 may be unsupported independently of the OS. OpenVINO's own macOS support was not inspected. |

## 3. Disk, memory and time, from project docs only

Nothing was measured. This machine has 8 GiB of RAM and about 157 GiB free (`STATUS.md:14`).

| | Disk | Memory | Time |
|---|---|---|---|
| tt | **[E]** "at least 128GB", and "with LLVM installation and full SW stack we quickly reach 80 gigs", for an Ubuntu VM with the full stack (`macos-ubuntu-vm.md:28-29`) | **[E]** 16 GB recommended for that VM (`macos-ubuntu-vm.md:26`). OOM is a documented risk, with parallel level 4 as the workaround (`getting-started.md:116`). | Not documented, beyond "takes time" (`getting-started.md:97`). The macOS job's limit is 600 minutes (`call-build-macos.yml:24`), which is a ceiling, not a measurement. |
| aie | Not documented | Not documented | Not documented |
| vpux | Not documented; **[E]** a 10–20+ GB ccache is advised for OpenVINO plus compiler, in the Windows notes (`developer_tools.md:75-77`) | Not documented | Not documented |

## 4. Rank-dependent logic, classified S1–S8 (`docs/theory/rank-bound.md:134-145`)

The grep proxy reproduces for tt: 54 `getRank()` lines and 33 rank-vs-constant lines across the two
conversions. Only 6 of those 33 are in the file holding `convert-ttir-to-ttnn`'s patterns; the rest
are in the decomposition pass. Classes below are from reading the code **[F]**; whether each makes
A3 hold is **[H]** until a closure inventory exists.

### tt

| Location | Expression | Class | Note |
|---|---|---|---|
| `TTIRToTTNN.cpp:226-239` (`sum`, `mean`, `max`, `min`) | none | none | 1:1, no failure return |
| `TTIROps.cpp:6699-6730` | per-position mask; `-r ≤ d < r` | S1, S2, S4 | shared reduce verifier; no rank cap |
| `TTNNOps.cpp:6028`, `:6085-6086` | `rank > 4` for `ttnn.prod` only | S3, S8 | TTIR has no such cap (`TTIROps.cpp:6831-6833`), so the limit lives in the output op's verifier, as with O3 |
| `TTIRToTTNN.cpp:251-258` | `size > 1 && size < rank` | S1 | looks like S5, but **[H]** is regular: at least two marks and one unmarked position |
| `TTIRToTTIRDecomposition.cpp:1809-1845`; `…Pass.cpp:176-183` | chain with one `ttir.prod` per reduced dim | S7 | chain length grows with the number of marks |
| `TTIRToTTIRDecomposition.cpp:825-878` | `rank == 5`, `rank < 4`, `rank == 3` | S2, S3, S4 | **breaks A2 as written:** `reshapedShape.back() % tileWidth == 0` (`:864`) is not constant on the letter `s` |
| `TTIROps.cpp:7113`; `TTNNOps.cpp:3870-3884`; `…Pass.cpp:105-106` | batch norm: TTIR rank 2–5, TTNN rank 4 | S3 | rank is capped by the source verifier |
| `TTIRToTTNN.cpp:1377-1385,1412-1418` (group norm) | channel moved to last; `rank > 4` | S1–S4 | permutation built from a mark, so finite |

**RQ3 and R1:**

- **[F]** `ttir.sum`'s pattern is as rank-free as anything in TosaToLinalg, so a `sum` domain would not answer R1.
- **[H]** Real thresholds exist, but each has a limit. Batch norm's rank is capped at 5 by the source verifier, so an all-rank claim adds nothing there (compare R7). `ttir.prod` has no source cap, but its threshold is a documented rejection at rank 5 (`negative_reduce_prod_op.mlir:1-7`). That is an `EXPECTED_REJECTION` and a non-trivial N, not a gap.
- **[H] Candidate gap, by reading only.** `ReductionProdPattern` indexes `shape[dim]` with the raw `dim_arg` value (`TTIRToTTIRDecomposition.cpp:1818,1831-1837`), while the verifier allows negative values (`TTIROps.cpp:6708`). A multi-dimension `ttir.prod` with negative dims could crash the bare decomposition pass. Earlier pipeline passes may normalize them. Untriaged.

### aie

| Location | Expression | Class | Note |
|---|---|---|---|
| `VectorToAIEVecConversions.cpp`, 15 lines, e.g. `:2973,3838,5703` | `rank != 1` guard | S3, c = 1 | most patterns only match rank 1 |
| `VectorToAIEVecConversions.cpp:5426-5467`; `VectorToVectorConversions.cpp:320,380,561,668,672` | flatten n-D to rank 1, gated on `rank < 2` | S3, c = 2 | 22 of 56 lit files use rank ≥ 2 vectors, 9 use rank ≥ 3 |
| `AIEVecUtils.h:59`; `VectorToAIEVecConversions.cpp:2528-2531,6738-6753` | lanes = product of all dims, tested against a table and 256/512 bits | breaks A2 for `s` | **[H]** needs a concrete-size alphabet, regular only because the product is compared with finite values |
| `VectorToAIEVecConversions.cpp:6135-6144` | n-D forms stay legal "to surface a clearer error from a later stage" | S3 | a partial conversion can succeed while the op remains |

**RQ3 and R1:** **[H]** The thresholds stop at 2, so N is small and R1 largely remains. Lane arithmetic is the non-trivial part, but it concerns sizes, not rank. **[F]** `vector.reduction` is capped at rank ≤ 1 by its own verifier (`VectorOps.cpp:736` at the LLVM pin), so the reduce family gives no rank domain.

### vpux

| Location | Expression | Class | Note |
|---|---|---|---|
| `convert_layers_to_VPU.td:285-289` (`ReduceSum`) | none | none | generated 1:1 rewrite |
| `convert_layers_to_VPU.cpp:736-756` (`Add`) | `rank < 4`: pad to 4D, then reshape back | S3, c = 4 | a real threshold on a common op |
| `:730-733` (`Add`) | operand ranks must be equal, else match failure | S5-like | **[H]** regular over a padded pair alphabet. **[H]** A gap candidate if `IE.Add` accepts differing ranks through broadcast (`add.cpp:41`); not checked. |
| `:141,:803` | `size != 3`, `rank != 4` errors | S3 | fixed-rank ops |
| `:425-430` (`ReduceMean`) | DMA interface branch | unknown | `isSupported` not read |

Grep proxy across `IE2VPU/`: 4 rank-vs-constant lines in `convert_layers_to_VPU.cpp` (965 lines), 0 in the other two files. **The surrounding pipeline was not inventoried.**

**RQ3 and R1:** **[H]** `IE.Add` gives one real threshold on an op with no rank cap seen so far, but the pass's rank logic is thin. A larger answer would need the `lower-IE-to-VPU` pipeline's closure, whose size is unknown (R2).

## 5. Candidate domains

Each is **[H]**: proposals to choose from, none accepted, and none checked against D-005's closed-form counts.

| | Source op | Letters and parameters | Element types | Control |
|---|---|---|---|---|
| tt-A | `ttir.prod` | {1, s, ?}, a set of dim marks, `keep_dim`, positive or negative encoding | f32, bf16, si32 (seen in lit) | `ttir.sum` (same family, no threshold) or `ttir.add` (`TTIRToTTNN.cpp:207-219`) |
| tt-B | `ttir.batch_norm_inference` | rank 2–5, a feature-dim mark; letters {1, s, tile-aligned}; weights rank 1 or 4 | f32 | `ttir.add` |
| aie-A | `arith.addf` / `addi` on n-D vectors | concrete dim sizes, `aie-target`; no `?` (`AIEVecUtils.h:57-58`) | i8, i16, i32, f32, bf16 | `vector.reduction` as a rank-capped negative |
| vpux-A | `IE.Add` | {1, s, ?}, platform, broadcast mode; `?` also needs a `bounds` attribute (`convert_layers_to_VPU_40XX.mlir:11-12`) | f16 (seen in lit) | `IE.SoftMax` (generated 1:1) or `IE.ReduceSum` |

**[F]** The tt repository also has `convert-tosa-to-ttir`, with a 1:1 `tosa.reduce_sum` pattern (`TosaToTTIRPatterns.cpp:220-236,481`; `reductions/sum.mlir:1,6`). It is a different conversion from the one named here. It would keep D0's op and spec oracle but not TTIR→TTNN's logic, and its pattern is as rank-free as `sum`.

## 6. The validity oracle that replaces V_tosa1.0

V_mlir's analogue (parser plus verifiers, no passes) exists for all three. None has TOSA's mechanical `tosa-validate` step.

| | Candidate oracle | Spec behind it |
|---|---|---|
| tt | `ttmlir-opt`, no passes: TTIR verifiers | **[F]** None found in the repo; `docs/src/specs/` covers cross-cutting features such as device and tensor layout (`specs.md:3-8`). TTNN's API docs are in tt-metal and were not inspected. **[H]** A verdict would mean "TTIR verifier accepts", a weaker oracle than the current headline (OQ-2). |
| aie | `aie-opt`, no passes: vector and arith verifiers | **[F]** None found in the repo. The lane table (`VectorToAIEVecConversions.cpp:6738-6753`) belongs to the conversion itself, so using it as an oracle would be **circular**. AMD's ISA docs were not inspected. |
| vpux | `vpux-opt --init-compiler=…`, no conversion: IE verifiers | **[F]** The compiler's docs point at OpenVINO's public operation specifications (`sw_layer_enabling.md:42,48`). **Not read for this brief.** **[H]** IE ops extend the opset (`reduce.td:213-214` adds padding attributes), so the mapping needs checking, and no tool validates against the spec. |

## 7. What replaces "bare pass", "pipeline" and `mlir-opt` [F]

| | Tool | Bare pass | Pipeline | Note |
|---|---|---|---|---|
| tt | `ttmlir-opt` | `--convert-ttir-to-ttnn`, module level (`Passes.td:158`) | `--ttir-to-ttnn-runtime-pipeline` (`TTNNPipelines.cpp:874`); the older `--ttir-to-ttnn-backend-pipeline` is marked deprecated (`:883-884`) but still used in lit | The shared passes run decomposition (`:58`), then layout and conversion (`:171-173`). Lit prefixes the bare pass with `--ttcore-register-device --ttnn-layout` (`avg_pool2d_negative_tests.mlir:1`). **[H]** Those two may be needed on every case. |
| aie | `aie-opt` | `--test-lower-vector-to-aievec`, a test pass (`VectorToAIEVecConversions.cpp:6889`), or `--lower-vector-to-aievec` (`ConvertVectorToAIEVec.cpp:158`) | `--convert-vector-to-aievec` (`ConvertVectorToAIEVec.cpp:145`) | Takes `aie-target`, whose default is `aie` (`VectorToAIEVecConversions.cpp:6901-6906`). Lit reaches it through the pipeline (`test-upd.mlir:8-10`). |
| vpux | `vpux-opt` | `--convert-layers-to-VPU`, function level (`passes.td:564`) | `--lower-IE-to-VPU` (`pipelines.cpp:151`, adds the pass at `:31`) | Always needs `--init-compiler="platform=… compilation-mode=…"` (`convert_layers_to_VPU.mlir:6-7`). |

**Effect on S2 (D-003):** tt's and vpux's bare passes are full conversions (`TTIRToTTNNPass.cpp:71-72`, `convert_layers_to_VPU.cpp:952`), so S0 implies legality, as now. tt's decomposition pass (`…Pass.cpp:216`) and aie's conversion (`VectorToAIEVecConversions.cpp:6954`) are partial, so S2's "no source op remains" becomes a real check there.

## 8. `RewriterBase::Listener` and the adapter design

**The listener still works at all three pins [F].** `notifyPatternBegin` and `notifyPatternEnd` are at `PatternMatch.h:407,414` in each, and the driver still calls them:

| LLVM pin | `ConversionConfig::listener` | `allowPatternRollback` | Driver calls (`DialectConversion.cpp`) |
|---|---|---|---|
| tt | `DialectConversion.h:1386` | `:1417` | `:2719,2758,2792` |
| aie | `:1432` | `:1463` | `:2761,2800,2831` |
| vpux | `:1432` | `:1463` | `:2756,2795,2826` |

**The adapter design carries over unevenly.** It needs a rebuilt target, the real patterns, and output identical to the tool's.

| | Target | Patterns | Result |
|---|---|---|---|
| tt | Rebuild from `TTIRToTTNNPass.cpp:41-60` | Public `populateTTIRToTTNNPatterns` (`TTIRToTTNN.h:13`) | **[H]** Direct analogue of the current design. Links tt-mlir's libraries (`tools/ttmlir-opt/CMakeLists.txt:4`), not Homebrew's. |
| aie | Rebuild from `VectorToAIEVecConversions.cpp:6908-6952`; predicates are `static` (`:5877,6154,6197,6459`) | `static` (same file, `:5265,5285,5303,5365,5783`); the public header offers only pipeline builders (`Passes.h:148`) | **[H]** Needs a source patch or compiling the `.cpp` into the adapter, which strains "unmodified" and "thin" (RQ4). |
| vpux | Rebuild from `convert_layers_to_VPU.cpp:895-912` | Rewrite classes in a public header, plus `populateWithGenerated` from a generated include (`:50,950`) | **[H]** Possible without source edits, but must mirror the 34 `patterns.add` lines (`:916-949`), which is a fidelity risk (R5). |

The vpux `Pat`-generated patterns and aie's multi-pass pipeline may also need separate checks on pattern naming and on greedy-driver stages. **[H]** With assertions on in tt's and aie's LLVM configuration, a broken invariant would show up as `CRASH`, where the Homebrew release build could not.

## 9. Effect on OQ-5

OQ-5 asks: second target, tt-mlir or TorchToTosa? (`docs/risks-and-open-questions.md:31`)

| If the first target is | OQ-5 becomes |
|---|---|
| tt | tt-mlir leaves the list, so OQ-5 needs a new option set. TorchToTosa's status as a *second* target is not settled by D-010. |
| aie or vpux | OQ-5 stands as written, with a second LLVM source build on top of the first (R4, R11). |

**[F]** TosaToLinalg stays runnable from Homebrew in every case, so its eight probes remain a usable record, but D-010 removes it as first target. Whether it returns as a comparison target is an open question for you.

## Docs' position, and what would change the answer

The docs recommend no first NPU target. Their closest statements are to choose an NPU second target
with tt-mlir or TorchToTosa after the spike (`docs/research/problem-statement.md:114-115`) and to time
one LLVM build before committing (`docs/risks-and-open-questions.md:12`).

**Evidence that would change the answer:**

- a build at the pin succeeding or failing on this machine;
- a closure inventory showing whether a chosen domain's thresholds survive (R2);
- advisor input on whether "TTIR verifier accepts" is an acceptable oracle (OQ-8 is the nearest open question);
- reading the OpenVINO opset spec, for vpux;
- triage of the two gap candidates above.

**Blocked until answered:** every target-dependent item: the expected outcomes, all implementation code (`CLAUDE.md:108`), and the D-010 rework. The theory's generic theorems and the novelty reading are not blocked.

## Corrections to existing docs

Not applied here; they belong to the D-010 rework.

| Location | Says | Found |
|---|---|---|
| `docs/research/problem-statement.md:94` | tt-mlir's "README lists Mac OS" | The statement is in `docs/src/getting-started.md:15`. |
| `docs/research/problem-statement.md:94` | No mention of a compiler bound | `Clang >= 14 & <= 18` is documented, which this machine's compilers fall outside. |
| `docs/research/problem-statement.md:95` | aie's rank domain is "about {1}" | Rank ≥ 2 vectors are flattened and tested in lit, so the threshold is at 2. Still shallow. |
| `STATUS.md:40-41` | Each NPU candidate pins a different LLVM | True, and tt's pin is about a year older than ours, on LLVM 22. |

## The build-limit decision you must make next

The limit is at `docs/experiments/initial-spike.md:9,109` and stays in force until you decide (D-011).

**Choice:**

1. **Keep the limit.** No candidate can be built, so every comparison above stays unmeasured, and target-dependent work stays blocked.
2. **Lift it for one capped MLIR-only build,** at a pin you name.

**Set these if you lift it:** which pin; the job count; a wall-clock cap; a disk cap; a location outside this repo; and whether exceeding a cap counts as "the build fails" under D-011's stop rule. As written, that rule ends the study's first-target attempt on failure, so a cap set too tightly would produce a negative result about the cap, not about the target.

**What one capped build would cost:**

| Pin | What it builds | Cost evidence | What it would and would not show |
|---|---|---|---|
| tt | LLVM 22 dev with `mlir,lld` (`env/CMakeLists.txt:64`), upstream source | Disk: **[H]** below the documented 80 GB, which covers the full stack in a VM. Memory: **[E]** 16 GB recommended against 8 GiB here; OOM documented. Time: not documented. Needs `/opt/ttmlir-toolchain` via `sudo`, or `TTMLIR_TOOLCHAIN_DIR` set elsewhere (`getting-started.md:82-88`). | Shows LLVM builds here. Does **not** produce `ttmlir-opt`: flatbuffers, the venv and tt-mlir itself come after. |
| aie | LLVM 24 dev from the ROCm fork (`build-llvm.sh`) | Disk, memory and time: not documented. No macOS path to follow. | Shows the fork's LLVM builds here. Says nothing about `aie-opt` on an unsupported OS. |
| vpux | LLVM 23 dev fork, normally built inside the compiler's tree | Disk, memory and time: not documented. **[H]** A standalone MLIR-only build is not a documented route. | Least informative: OpenVINO must also build, on a platform whose presets are named x86_64. |

**Two cap-related trade-offs [F]:**

- tt's and aie's LLVM configurations hard-code Python bindings on (`env/CMakeLists.txt:69`, `build-llvm.sh:35`). Turning them off to save time would make the capped build differ from the project's configuration.
- The documented job cap is `-DCMAKE_BUILD_PARALLEL_LEVEL=4` (`getting-started.md:116`, `call-build-macos.yml:68`). On 8 GiB, that value has no evidence behind it for this machine.
