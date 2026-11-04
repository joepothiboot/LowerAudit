{-# LANGUAGE OverloadedStrings #-}

module ManifestSpec (tests) where

import Data.List (nub)
import Data.Text (Text)
import LowerAudit.Concretize (Representative (..), concretize)
import LowerAudit.Enumerate (enumerate)
import LowerAudit.Manifest (
    CaseId (..),
    Pin (..),
    caseId,
    d0tt,
    domainHash,
    domainJson,
    manifestJson,
    mkManifest,
    targetPin,
 )
import LowerAudit.Render (renderCase)
import RenderSpec (goldenCases)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Golden (goldenVsString)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

placeholderSha :: Text
placeholderSha = "0123456789abcdef0123456789abcdef01234567"

pinnedCaseIds :: [(FilePath, CaseId)]
pinnedCaseIds =
    [ ("o1-shape-prod-rank2.mlir", CaseId "fa1914022f64d442ec0013c729d39ba36ffdc5b2eaed12a7f912795a4041b94f")
    , ("o3-letters-prod-dynamic.mlir", CaseId "1774129ebfdd64340b4693d82a547595ad150ff27f11ede7391bbcfd53338ea2")
    , ("control-sum-rank2.mlir", CaseId "3e229c284be804c57a24b205a6331e5d0eaa956893606dbf20788b1b352951c6")
    , ("prod-absent-rank0-bf16.mlir", CaseId "764d378ffd648d0f43a9051e99cb19370d7768b9a5cec32c62cb8a6b071bd57a")
    , ("prod-negative-keep-si32.mlir", CaseId "ae5ec82c6ac8ecba12aa9dc85acaf9031ef91aa7286cb96672e8ccaadf255c48")
    ]

tests :: TestTree
tests =
    testGroup
        "LowerAudit.Manifest"
        [ testGroup
            "caseId"
            [ testCase "SHA-256 of \"abc\", FIPS 180-4 example" $
                caseId "abc" @?= CaseId "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
            , testCase "SHA-256 of the empty text" $
                caseId "" @?= CaseId "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
            , testGroup
                "stable across runs: ids pinned from shasum -a 256 of the golden files"
                [ testCase file $
                    fmap (caseId . renderCase) (lookup file goldenCases) @?= Just expected
                | (file, expected) <- pinnedCaseIds
                ]
            , testCase "distinct cases get distinct ids, ranks 1-2" $
                let ids = map (caseId . renderCase . concretize Rep2) (enumerate 2)
                 in length (nub ids) @?= length ids
            ]
        , testGroup
            "domain and manifest"
            [ testCase "D-012: the pin" $
                targetPin @?= Pin "f9dc1b3e5101" "4efe170d858e"
            , goldenVsString
                "domainJson lists D0-tt's parameters"
                "test/golden/domain-d0-tt-r4-rep2.json"
                (pure (domainJson (d0tt 4 Rep2)))
            , testCase "domainHash, pinned from shasum -a 256 of that golden file" $
                domainHash (d0tt 4 Rep2)
                    @?= "7510edb1ab21ab05e9a0952dce0e69fd028e1579ec9ca41e10fcdef35e712224"
            , testCase "the hash changes with the rank bound and the representative"
                $ assertBool "hashes collide"
                $ let hashes = map domainHash [d0tt 4 Rep2, d0tt 5 Rep2, d0tt 4 Rep3]
                   in length (nub hashes) == length hashes
            , goldenVsString
                "manifestJson"
                "test/golden/manifest-d0-tt-r4-rep2.json"
                (pure (manifestJson (mkManifest placeholderSha (d0tt 4 Rep2))))
            ]
        ]
