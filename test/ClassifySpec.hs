{-# LANGUAGE OverloadedStrings #-}

module ClassifySpec (tests) where

import Data.ByteString.Lazy qualified as Lazy
import Data.Either (isLeft)
import Data.Text (Text)
import Data.Text qualified as Text
import LowerAudit.Classify (
    Classification (..),
    DocumentedRejection (..),
    Outcome (..),
    OutcomeClass (..),
    RejectionStage (..),
    Stage (..),
    ValidityVerdict (..),
    classify,
    isGap,
    lastPassStarted,
    parseRejections,
    validityVerdict,
 )
import LowerAudit.Run (RunRecord (..), StepResult (..), Termination (..))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, assertBool, assertFailure, testCase, (@?=))

step :: Termination -> Text -> StepResult
step t err = StepResult ["tool"] t "" err Nothing

accepted :: StepResult
accepted = step (Exited 0) ""

converted :: Termination -> Text -> RunRecord
converted t err = RunRecord accepted (Just (step t err))

rejectedAtValidity :: Text -> RunRecord
rejectedAtValidity err = RunRecord (step (Exited 1) err) Nothing

outcome :: OutcomeClass -> Maybe Stage -> Classification
outcome c s = Classified (Outcome c s)

unexplainedAt :: Stage -> Classification -> Assertion
unexplainedAt expected c = case c of
    Unexplained s _ -> s @?= expected
    other -> assertFailure ("expected Unexplained, got " <> show other)

bannerPin :: Text -> Text -> Text
bannerPin name arg =
    "// -----// IR Dump Before " <> name <> " (" <> arg <> ") //----- //\nmodule {\n}\n\n"

bannerLlvm23 :: Text -> Text -> Text
bannerLlvm23 name arg =
    "// -----// IR Dump Before " <> name <> ": " <> arg <> " //----- //\nmodule {\n}\n\n"

rank5Diag :: Text
rank5Diag =
    "case.mlir:2:8: error: 'ttnn.prod' op Input tensor rank is greater than 4 for reduce(product).\n"
        <> "case.mlir:2:8: note: see current operation: \"ttnn.prod\"() : () -> ()\n"

legalizeFullDiag :: Text
legalizeFullDiag = "case.mlir:2:8: error: failed to legalize operation 'ttir.prod'\n"

legalizePartialDiag :: Text
legalizePartialDiag =
    "case.mlir:2:8: error: failed to legalize operation 'ttir.prod' that was explicitly marked illegal\n"

o3Diag :: Text
o3Diag =
    "o3.mlir:2:8: error: 'tensor.expand_shape' op expected number of static shape dims to be equal to the output rank (2) but found 0 inputs instead\n"

levelCheckDiag :: Text
levelCheckDiag =
    "o1.mlir:2:8: error: 'tosa.reduce_sum' op failed level check: operand rank(shape) <= MAX_RANK\n"

o7Diag :: Text
o7Diag = "o7.mlir:2:8: error: 'tosa.reduce_sum' op expect output tensor rank to be equal to input tensor rank\n"

f6Diag :: Text
f6Diag = "case.mlir:2:8: error: 'ttir.prod' op Expected output shape (), got (2, 2, 1)\n"

unregisteredDiag :: Text
unregisteredDiag =
    "case.mlir:2:19: error: operation being parsed with an unregistered dialect. If this is intended, please use -allow-unregistered-dialect with the MLIR tool used\n"

customUnknownDiag :: Text
customUnknownDiag = "case.mlir:2:8: error: custom op 'ttir.prod' is unknown\n"

unknownFlagDiag :: Text
unknownFlagDiag = "mlir-opt: Unknown command line argument '--nope'.  Try: 'mlir-opt --help'\n"

noInputDiag :: Text
noInputDiag = "cannot open input file 'case.mlir': No such file or directory\n"

scheduleDiag :: Text
scheduleDiag =
    "<unknown>:0: error: unable to schedule pass 'TosaToLinalg' on a PassManager intended to run on 'builtin.module'!\n"

fatalDiag :: Text
fatalDiag = "LLVM ERROR: something fatal\n"

prodRank :: DocumentedRejection
prodRank =
    DocumentedRejection
        "ttnn-prod-rank"
        "'ttnn.prod' op Input tensor rank is greater than 4 for reduce(product)."
        AtVerification
        "TTNNOps.cpp:6029-6030"
        "negative_reduce_prod_op.mlir:4"

levelRank :: DocumentedRejection
levelRank =
    DocumentedRejection
        "tosa-level-rank"
        "op failed level check: operand rank(shape) <= MAX_RANK"
        AtPass
        "TosaValidation.cpp:275-276"
        "level_check.mlir:366"

tests :: TestTree
tests =
    testGroup
        "LowerAudit.Classify"
        [ testGroup
            "LOWERED, S2 by exit 0"
            [ testCase "validity and conversion both exit 0" $
                classify [] (converted (Exited 0) "") @?= outcome Lowered Nothing
            , testCase "the action logger's stderr line changes nothing, CLOptionsSetup.cpp:93" $
                classify [] (converted (Exited 0) "ExecutionContext registered on the context\n")
                    @?= outcome Lowered Nothing
            , testCase "a warning changes nothing" $
                classify [] (converted (Exited 0) "case.mlir:1:1: warning: odd\n")
                    @?= outcome Lowered Nothing
            , testCase "the documented text in a successful run's stderr changes nothing" $
                classify [prodRank] (converted (Exited 0) rank5Diag) @?= outcome Lowered Nothing
            ]
        , testGroup
            "CRASH"
            [ testCase "SIGABRT, assert, P8 bare: named by the last banner" $
                classify
                    []
                    ( converted
                        (Signalled 6)
                        ( bannerPin "TTCoreRegisterDevicePass" "ttcore-register-device"
                            <> bannerPin "TTNNLayout" "ttnn-layout"
                            <> "Assertion failed: (val >= 0), function alignUp\n"
                        )
                    )
                    @?= outcome Crash (Just (NamedConversion "TTNNLayout"))
            , testCase "SIGSEGV, P4 pipeline: in decomposition" $
                classify [] (converted (Signalled 11) (bannerPin "TTIRToTTIRDecomposition" "ttir-to-ttir-decomposition"))
                    @?= outcome Crash (Just (NamedConversion "TTIRToTTIRDecomposition"))
            , testCase "with no banners the pass cannot be named" $
                classify [] (converted (Signalled 6) "") @?= outcome Crash (Just Conversion)
            , testCase "a crash outranks a documented diagnostic in the same stderr" $
                classify [prodRank] (converted (Signalled 6) rank5Diag) @?= outcome Crash (Just Conversion)
            , testCase "a crash outranks a legalization failure in the same stderr" $
                classify [] (converted (Signalled 11) legalizeFullDiag) @?= outcome Crash (Just Conversion)
            , testCase "LLVM ERROR with exit 1, usage fatal error, ErrorHandling.cpp:124,137" $
                classify [] (converted (Exited 1) (bannerPin "TTNNLayout" "ttnn-layout" <> fatalDiag))
                    @?= outcome Crash (Just (NamedConversion "TTNNLayout"))
            , testCase "a crash while judging validity is CRASH, not INVALID" $
                classify [] (RunRecord (step (Signalled 6) "") Nothing)
                    @?= outcome Crash (Just ParseAndVerify)
            , testCase "LLVM ERROR while judging validity is CRASH, not INVALID" $
                classify [] (rejectedAtValidity fatalDiag) @?= outcome Crash (Just ParseAndVerify)
            ]
        , testGroup
            "TIMEOUT"
            [ testCase "in conversion, named by the last banner" $
                classify [] (converted TimedOut (bannerPin "ConvertTTIRToTTNN" "convert-ttir-to-ttnn"))
                    @?= outcome Timeout (Just (NamedConversion "ConvertTTIRToTTNN"))
            , testCase "in conversion, no banners" $
                classify [] (converted TimedOut "") @?= outcome Timeout (Just Conversion)
            , testCase "while judging validity is TIMEOUT, not INVALID" $
                classify [] (RunRecord (step TimedOut "") Nothing) @?= outcome Timeout (Just ParseAndVerify)
            , testCase "documented text in stderr does not rescue a timeout" $
                classify [prodRank] (converted TimedOut rank5Diag) @?= outcome Timeout (Just Conversion)
            ]
        , testGroup
            "OUTPUT_INVALID, verifier after a successful pass, Pass.cpp:619,638"
            [ testCase "O3: the expand_shape diagnostic" $
                classify [] (converted (Exited 1) o3Diag) @?= outcome OutputInvalid (Just Verification)
            , testCase "O3: banners do not rename the stage" $
                classify [] (converted (Exited 1) (bannerLlvm23 "TosaToLinalg" "tosa-to-linalg" <> o3Diag))
                    @?= outcome OutputInvalid (Just Verification)
            , testCase "O3: a listed rejection for some other diagnostic does not apply" $
                classify [prodRank, levelRank] (converted (Exited 1) o3Diag)
                    @?= outcome OutputInvalid (Just Verification)
            ]
        , testGroup
            "EXPECTED_REJECTION comes only from the list, D-017"
            [ testCase "rank 5, P5, listed" $
                classify [prodRank] (converted (Exited 1) rank5Diag)
                    @?= outcome (ExpectedRejection "ttnn-prod-rank") (Just Verification)
            , testCase "rank 5, not listed: the same run is a gap, so no string lives in code" $
                classify [] (converted (Exited 1) rank5Diag) @?= outcome OutputInvalid (Just Verification)
            , testCase "the list decides, whatever the text says" $
                classify
                    [prodRank{rejectionId = "other", rejectionDiagnostic = "'ttnn.prod' op something else"}]
                    (converted (Exited 1) "case.mlir:2:8: error: 'ttnn.prod' op something else\n")
                    @?= outcome (ExpectedRejection "other") (Just Verification)
            , testCase "another ttnn.prod verifier message does not match" $
                classify [prodRank] (converted (Exited 1) "case.mlir:2:8: error: 'ttnn.prod' op Input must be ranked\n")
                    @?= outcome OutputInvalid (Just Verification)
            , testCase "the diagnostic in a note does not count, only an error line" $
                classify
                    [prodRank]
                    (converted (Exited 1) (o3Diag <> "case.mlir:2:8: note: 'ttnn.prod' op Input tensor rank is greater than 4 for reduce(product).\n"))
                    @?= outcome OutputInvalid (Just Verification)
            , testCase "the first entry that matches names the rejection" $
                classify [prodRank, prodRank{rejectionId = "second"}] (converted (Exited 1) rank5Diag)
                    @?= outcome (ExpectedRejection "ttnn-prod-rank") (Just Verification)
            ]
        , testGroup
            "validation failure, O1 at r = 7, O2"
            [ testCase "listed: EXPECTED_REJECTION, in the validation pass" $
                classify
                    [levelRank]
                    (converted (Exited 1) (bannerLlvm23 "TosaValidation" "tosa-validate" <> levelCheckDiag))
                    @?= outcome (ExpectedRejection "tosa-level-rank") (Just (NamedConversion "TosaValidation"))
            , testCase "listed, no banners" $
                classify [levelRank] (converted (Exited 1) levelCheckDiag)
                    @?= outcome (ExpectedRejection "tosa-level-rank") (Just Conversion)
            , testCase "not listed: reads as OUTPUT_INVALID on the CLI, Open question 1" $
                classify [] (converted (Exited 1) levelCheckDiag) @?= outcome OutputInvalid (Just Verification)
            ]
        , testGroup
            "CONVERSION_FAILED"
            [ testCase "full conversion, P3 bare, DialectConversion.cpp:3323" $
                classify [] (converted (Exited 1) (bannerPin "ConvertTTIRToTTNN" "convert-ttir-to-ttnn" <> legalizeFullDiag))
                    @?= outcome ConversionFailed (Just (NamedConversion "ConvertTTIRToTTNN"))
            , testCase "partial conversion, DialectConversion.cpp:3330-3331" $
                classify [] (converted (Exited 1) (bannerPin "TTIRToTTIRDecomposition" "ttir-to-ttir-decomposition" <> legalizePartialDiag))
                    @?= outcome ConversionFailed (Just (NamedConversion "TTIRToTTIRDecomposition"))
            , testCase "no banners" $
                classify [] (converted (Exited 1) legalizeFullDiag) @?= outcome ConversionFailed (Just Conversion)
            , testCase "P3 stays a failure with the real list in hand: no lit test, no rejection" $
                classify [prodRank] (converted (Exited 1) legalizeFullDiag)
                    @?= outcome ConversionFailed (Just Conversion)
            , testCase "the legalization line outranks an op error before it" $
                classify [] (converted (Exited 1) ("case.mlir:2:8: error: 'ttir.prod' op bad\n" <> legalizeFullDiag))
                    @?= outcome ConversionFailed (Just Conversion)
            ]
        , testGroup
            "INVALID, never a gap"
            [ testCase "O7: ill-typed input" $
                classify [] (rejectedAtValidity o7Diag) @?= outcome Invalid (Just ParseAndVerify)
            , testCase "F6: the same on TTIR, TTIROps.cpp:6733-6738" $
                classify [] (rejectedAtValidity f6Diag) @?= outcome Invalid (Just ParseAndVerify)
            , testCase "O7 is not a gap" $
                isGap Invalid @?= False
            , testCase "a parse error is INVALID" $
                classify [] (rejectedAtValidity "case.mlir:1:1: error: expected '->' in function type\n")
                    @?= outcome Invalid (Just ParseAndVerify)
            , testCase "the failed validity step decides, whatever a conversion record says" $
                sequence_
                    [ classify [prodRank] (RunRecord (step (Exited 1) o7Diag) (Just (step t e)))
                        @?= outcome Invalid (Just ParseAndVerify)
                    | t <- [Exited 0, Exited 1, Signalled 6, TimedOut, StartFailed "x"]
                    , e <- ["", legalizeFullDiag, rank5Diag, o3Diag, fatalDiag]
                    ]
            , testCase "documented text at validity is still INVALID" $
                classify [prodRank] (rejectedAtValidity rank5Diag) @?= outcome Invalid (Just ParseAndVerify)
            ]
        , testGroup
            "Unexplained: a broken run is not evidence about the case"
            [ testCase "TTIR on a tool without the dialect is not INVALID, Parser.cpp:1512" $
                unexplainedAt ParseAndVerify (classify [] (rejectedAtValidity unregisteredDiag))
            , testCase "custom op unknown, Parser.cpp:2126" $
                unexplainedAt ParseAndVerify (classify [] (rejectedAtValidity customUnknownDiag))
            , testCase "unknown flag at validity" $
                unexplainedAt ParseAndVerify (classify [] (rejectedAtValidity unknownFlagDiag))
            , testCase "input file missing" $
                unexplainedAt ParseAndVerify (classify [] (rejectedAtValidity noInputDiag))
            , testCase "exit 1 with nothing on stderr at validity" $
                unexplainedAt ParseAndVerify (classify [] (rejectedAtValidity ""))
            , testCase "the tool did not start at validity" $
                unexplainedAt ParseAndVerify (classify [] (RunRecord (step (StartFailed "x") "") Nothing))
            , testCase "the tool did not start at conversion" $
                unexplainedAt Conversion (classify [] (converted (StartFailed "x") ""))
            , testCase "O5: pass cannot be scheduled, not a conversion failure" $
                unexplainedAt Conversion (classify [] (converted (Exited 1) scheduleDiag))
            , testCase "unknown flag at conversion" $
                unexplainedAt Conversion (classify [] (converted (Exited 1) unknownFlagDiag))
            , testCase "exit 1 with nothing on stderr at conversion, named by the banner" $
                unexplainedAt
                    (NamedConversion "TTNNLayout")
                    (classify [] (converted (Exited 1) (bannerPin "TTNNLayout" "ttnn-layout")))
            , testCase "exit 134 from a shell wrapper is not a signal" $
                unexplainedAt Conversion (classify [] (converted (Exited 134) ""))
            , testCase "validity passed but no conversion was recorded" $
                unexplainedAt Conversion (classify [] (RunRecord accepted Nothing))
            ]
        , testGroup
            "isGap, problem-statement §2"
            [ testCase "the four gap classes" $
                map isGap [ConversionFailed, OutputInvalid, Crash, Timeout] @?= [True, True, True, True]
            , testCase "the three that are not" $
                map isGap [Invalid, ExpectedRejection "x", Lowered] @?= [False, False, False]
            ]
        , testGroup
            "lastPassStarted"
            [ testCase "none" $ lastPassStarted "case.mlir:1:1: error: x\n" @?= Nothing
            , testCase "the pin's format, IRPrinting.cpp:79-80" $
                lastPassStarted (bannerPin "TTNNLayout" "ttnn-layout") @?= Just "TTNNLayout"
            , testCase "LLVM 23.1.1's format, with options" $
                lastPassStarted (bannerLlvm23 "TosaToLinalg" "tosa-to-linalg{disable-tosa-decompositions=false}")
                    @?= Just "TosaToLinalg"
            , testCase "the last of several" $
                lastPassStarted (bannerPin "A" "a" <> bannerPin "B" "b" <> "tail\n") @?= Just "B"
            , testCase "After banners do not count" $
                lastPassStarted "// -----// IR Dump After Later (later) //----- //\n" @?= Nothing
            ]
        , testGroup
            "validityVerdict"
            [ testCase "exit 0 accepts" $ validityVerdict accepted @?= ValidityAccepted
            , testCase "an error line rejects" $ validityVerdict (step (Exited 1) f6Diag) @?= ValidityRejected
            , testGroup
                "the rest cannot judge the case"
                [ testCase name (inconclusive (validityVerdict r))
                | (name, r) <-
                    [ ("unregistered dialect", step (Exited 1) unregisteredDiag)
                    , ("custom op unknown", step (Exited 1) customUnknownDiag)
                    , ("unknown flag", step (Exited 1) unknownFlagDiag)
                    , ("no input", step (Exited 1) noInputDiag)
                    , ("no stderr", step (Exited 1) "")
                    , ("fatal error", step (Exited 1) fatalDiag)
                    , ("signal", step (Signalled 6) "")
                    , ("timeout", step TimedOut "")
                    , ("did not start", step (StartFailed "x") "")
                    ]
                ]
            ]
        , testGroup
            "parseRejections"
            [ testCase "one entry" $
                parseRejections
                    "[{\"id\":\"a\",\"diagnostic\":\"b\",\"stage\":\"verification\",\"source\":\"c:1\",\"documentedBy\":\"d:2\"}]"
                    @?= Right [DocumentedRejection "a" "b" AtVerification "c:1" "d:2"]
            , testCase "the pass stage" $
                map rejectionStage
                    <$> parseRejections
                        "[{\"id\":\"a\",\"diagnostic\":\"b\",\"stage\":\"pass\",\"source\":\"c:1\",\"documentedBy\":\"d:2\"}]"
                    @?= Right [AtPass]
            , testCase "an empty list is valid" $ parseRejections "[]" @?= Right []
            , testCase "not JSON" $ assertBool "Left" (isLeft (parseRejections "nope"))
            , testCase "a missing citation is refused" $
                assertBool
                    "Left"
                    (isLeft (parseRejections "[{\"id\":\"a\",\"diagnostic\":\"b\",\"stage\":\"pass\",\"source\":\"c:1\"}]"))
            , testCase "an unknown stage is refused" $
                assertBool
                    "Left"
                    (isLeft (parseRejections "[{\"id\":\"a\",\"diagnostic\":\"b\",\"stage\":\"later\",\"source\":\"c:1\",\"documentedBy\":\"d:2\"}]"))
            , testCase "an empty diagnostic is refused: it would match every error line" $
                assertBool
                    "Left"
                    (isLeft (parseRejections "[{\"id\":\"a\",\"diagnostic\":\"\",\"stage\":\"pass\",\"source\":\"c:1\",\"documentedBy\":\"d:2\"}]"))
            ]
        , testGroup
            "the data files"
            [ testCase "data/rejections-tt-mlir-f9dc1b3e5101.json holds D-017's rejection" $ do
                entries <- dataFile "data/rejections-tt-mlir-f9dc1b3e5101.json"
                classify entries (converted (Exited 1) rank5Diag)
                    @?= outcome (ExpectedRejection "ttnn-prod-rank") (Just Verification)
            , testCase "data/rejections-tt-mlir-f9dc1b3e5101.json leaves P3 a gap" $ do
                entries <- dataFile "data/rejections-tt-mlir-f9dc1b3e5101.json"
                classify entries (converted (Exited 1) legalizeFullDiag)
                    @?= outcome ConversionFailed (Just Conversion)
            , testCase "data/rejections-llvmorg-23.1.1-probes.json holds both level checks" $ do
                entries <- dataFile "data/rejections-llvmorg-23.1.1-probes.json"
                map rejectionId entries @?= ["tosa-level-rank", "tosa-level-dynamic"]
            , testCase "every entry cites a source line and a test line" $ do
                entries <-
                    (<>)
                        <$> dataFile "data/rejections-tt-mlir-f9dc1b3e5101.json"
                        <*> dataFile "data/rejections-llvmorg-23.1.1-probes.json"
                sequence_
                    [ assertBool (Text.unpack (rejectionId e)) (cites (rejectionSource e) && cites (rejectionDocumentedBy e))
                    | e <- entries
                    ]
            ]
        ]

inconclusive :: ValidityVerdict -> Assertion
inconclusive v = case v of
    ValidityInconclusive _ -> pure ()
    other -> assertFailure (show other)

cites :: Text -> Bool
cites = Text.isInfixOf ":"

dataFile :: FilePath -> IO [DocumentedRejection]
dataFile path = do
    bytes <- Lazy.readFile path
    either (\e -> assertFailure (path <> ": " <> e)) pure (parseRejections bytes)
