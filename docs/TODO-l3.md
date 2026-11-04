# TODO: L3

Component B of [architecture §2](design/architecture.md), for D0-tt (D-013, D-017).

**Status:** stubs, tests and golden files. Rule 12 still holds: the slice in architecture §3 is proposed, not accepted. No
golden file has been parsed by `ttmlir-opt`, which cannot run here (D-015).

**Labels (rule 6):** **[F]** read from source. **[H]** hypothesis, not run. Citations to `.cpp`, `.td` and lit `.mlir` files are at
tt-mlir `f9dc1b3e5101`, read 2026-11-04.

Implement [TODO-l2](TODO-l2.md) first: `concretize` and `representativeSize` are used here. Then, in this order:

1. `LowerAudit.Enumerate`: `enumerate`
2. `LowerAudit.Render`: `renderElementType`, `renderOpName`, `renderTensorType`, `renderCase`
3. `LowerAudit.Manifest`: `caseId`, `targetPin`, `d0tt`, `domainJson`, `domainHash`, `mkManifest`, `manifestJson`

Run with `make test`. Do not pass `--accept`: it overwrites the golden files with whatever the code produced.

## Spec: enumerate

- **Signature:** `enumerate :: Int -> [AbstractCase]`
- **Behaviour:** every abstract case of D0-tt with rank from 1 to the bound, once each, in this order: rank; then the word,
  position by position, each letter by `DimLetter` and then `Mark`, in declaration order; then op, element type, `keep_dim`.
- **Edge and error cases:** a bound ≤ 0 is empty. The list is lazy: the start of a huge bound arrives without building the rest.
- **Tests:** `LowerAudit.Enumerate`. The counts are computed from 2·9^r (`problem-statement.md:154`), per rank and per element
  type and op, for ranks 1–4, and for ranks 1–6 on one pair. Strict ascent on the order key also rules out duplicates.

## Spec: renderElementType

- **Signature:** `renderElementType :: ElementType -> Text`
- **Behaviour:** `f32`, `bf16`, `si32`.
- **Edge and error cases:** none.
- **Tests:** `LowerAudit.Render / names`.

## Spec: renderOpName

- **Signature:** `renderOpName :: ReduceOp -> Text`
- **Behaviour:** `ttir.prod`, `ttir.sum`.
- **Edge and error cases:** none.
- **Tests:** `LowerAudit.Render / names`.

## Spec: renderTensorType

- **Signature:** `renderTensorType :: ElementType -> [Dim] -> Text`
- **Behaviour:** MLIR's ranked tensor syntax: `tensor<128x10xf32>`, with `?` for `DynamicSize`.
- **Edge and error cases:** rank 0 is `tensor<bf16>` (`simple_prod.mlir:73`).
- **Tests:** `LowerAudit.Render / renderTensorType`.

## Spec: renderCase

- **Signature:** `renderCase :: ConcreteCase -> Text`
- **Behaviour:** the exact text of `test/golden/*.mlir`: one public `func.func` named `@case`, one op in generic form with its
  properties, one `return`, and a final newline.
- **Edge and error cases:** `dim_arg` is omitted when absent, and comes before `keep_dim` when present. `keep_dim` is always
  written (`TTIROps.td:2743`). Entries keep the case's list order. It renders what the case says and judges nothing, so an
  invalid `ConcreteCase` renders as well.
- **Tests:** `LowerAudit.Render / renderCase golden files`.

## Spec: caseId

- **Signature:** `caseId :: Text -> CaseId`
- **Behaviour:** the lowercase hex SHA-256 of the text's UTF-8 bytes.
- **Edge and error cases:** the empty text has an id too.
- **Tests:** `LowerAudit.Manifest / caseId`: two published or `shasum` vectors, ids pinned from `shasum -a 256` of each golden
  file, and distinct ids across ranks 1–2.

## Spec: targetPin

- **Signature:** `targetPin :: Pin`
- **Behaviour:** tt-mlir `f9dc1b3e5101` and LLVM `4efe170d858e` (D-012).
- **Edge and error cases:** none.
- **Tests:** `LowerAudit.Manifest / domain and manifest`.

## Spec: d0tt

- **Signature:** `d0tt :: Int -> Representative -> DomainSpec`
- **Behaviour:** D0-tt's parameters as data: name `D0-tt`; op and element type names; letters `1`, `s`, `?`; marks `unmarked`,
  `positive`, `negative`; `keep_dim` values; the rank bound; the representative's size.
- **Edge and error cases:** none. A bound is recorded as given.
- **Tests:** the `domainJson` golden, and the hash test.

## Spec: domainJson

- **Signature:** `domainJson :: DomainSpec -> ByteString`
- **Behaviour:** the exact bytes of `test/golden/domain-d0-tt-r4-rep2.json`: compact JSON, keys sorted, no trailing newline.
- **Edge and error cases:** list values keep their order.
- **Tests:** that golden.

## Spec: domainHash

- **Signature:** `domainHash :: DomainSpec -> Text`
- **Behaviour:** the lowercase hex SHA-256 of `domainJson`.
- **Edge and error cases:** it changes with the rank bound and the representative.
- **Tests:** a hash pinned from `shasum -a 256` of the golden file, and the change test.

## Spec: mkManifest

- **Signature:** `mkManifest :: Text -> DomainSpec -> Manifest`
- **Behaviour:** builds the manifest from the generator's git SHA and the domain, with `targetPin` and `domainHash` filled in.
- **Edge and error cases:** the SHA is recorded as given, unchecked.
- **Tests:** the `manifestJson` golden.

## Spec: manifestJson

- **Signature:** `manifestJson :: Manifest -> ByteString`
- **Behaviour:** the exact bytes of `test/golden/manifest-d0-tt-r4-rep2.json`, under the same rules as `domainJson`.
- **Edge and error cases:** none.
- **Tests:** that golden.

## Decisions

- **Model D0-tt, not D0.** `tosa.reduce_sum`, `tosa.add`, 642 and 12,030 belong to the dated record (`problem-statement.md:174-203`).
  This phase renders `ttir.prod` and `ttir.sum` and counts `problem-statement.md:154`.
- **Hashing library: `SHA`** (pure Haskell). SHA-256 is not something to write by hand, and `base` has none. It also prints hex,
  so it needs no second package. Rejected: `cryptohash-sha256`, which needs a hex encoder as well and binds C; `crypton`, far
  larger than one hash needs; `hashable`, which is neither cryptographic nor stable across versions. **[H]** Its speed will not
  matter beside one process per case; this was not timed. Swapping it later does not change any id.
- **JSON library: `aeson`.** It avoids hand-written escaping, and the project's other JSON files will need it. **[F]** The domain hash
  depends on exact bytes, and the sorted key order comes from its default `ordered-keymap` flag. The golden files catch a change.
- **Goldens are TTIR forms of the probes, not the probes.** The syntax follows the lit tests at the pin.

  | File | From | Note |
  |---|---|---|
  | `o1-shape-prod-rank2.mlir` | O1 at r = 2: static 2^r, last dim | |
  | `o3-letters-prod-dynamic.mlir` | O3: `?x?`, dim 1 | O3's bug is in `tensor.expand_shape`, so it does not carry over. Its `?x?` result would be invalid here, so the result is `?` |
  | `control-sum-rank2.mlir` | the control | Same shape as the O1 file, so only the op differs |
  | `prod-absent-rank0-bf16.mlir` | `simple_prod.mlir:73` | absent `dim_arg`, rank 0 result |
  | `prod-negative-keep-si32.mlir` | none | negative entries, `keep_dim` true, `?`, si32 |

- **Determinism is tested across runs only.** A pure function gives the same result twice in one process, so such a test could not fail.
  Golden files and pinned ids fail if the bytes ever change.
- **Order within a rank is word, then params,** so all parameters of one word are adjacent. The first witness has minimal rank either way.
- **The git SHA is an argument,** so `LowerAudit.Manifest` stays pure. Whoever starts a run reads it.
- **`OverloadedStrings`** in `test/RenderSpec.hs` and `test/ManifestSpec.hs`, for `Text` literals.

  | Dependency | Used by | Reason |
  |---|---|---|
  | `aeson`, `SHA` | library | above |
  | `bytestring`, `text` | library, test | case text and JSON bytes; both ship with GHC |

## Shortcuts

- **No `cases.jsonl` yet,** although architecture §2 row B lists it. Add it with the runner, which is its first reader.
- **No seeded sampling beyond the bound,** which row B also lists. The bound is undecided (Open question 1).
- **One representative per manifest.** A run over several writes one manifest each.

## Open questions

1. **The exhaustive rank bound (`problem-statement.md:131`, "not decided").** Ranks 1–6 are 1,195,740 cases per element type and op, so
   7,174,440 in all. The test enumerates that in about 1.4 s at `-O1` on a throwaway implementation; running them is untimed (R9).
2. **Whether the wrapper can change an outcome.** The name `@case` and `public` are not parameters. Lit uses `func.func public` with
   other names. **[H]** Neither matters. Only a run can confirm it, and a change now would change every id.
3. **Case ids and A2.** The id hashes concrete text, so one abstract case has a different id under each representative. Comparing
   representatives must therefore join on the abstract case, not the id. Nothing records that link yet; `cases.jsonl` is the likely place.
4. **Whether `manifestJson` should carry the mode commands (D-017).** They describe a run, not the generator, so they are out for now.
