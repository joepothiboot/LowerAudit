{-# LANGUAGE OverloadedStrings #-}

module ReportSpec (at, tests) where

import Control.Monad (foldM)
import Data.Aeson (Value (..), decode, object, (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString.Lazy qualified as Lazy
import Data.ByteString.Lazy.Char8 qualified as Char8
import Data.Text (Text)
import Data.Text qualified as Text
import LowerAudit.Classify (
    Classification (..),
    DocumentedRejection (..),
    Outcome (..),
    OutcomeClass (..),
    RejectionStage (..),
    Stage (..),
 )
import LowerAudit.Manifest (CaseId (..))
import LowerAudit.Report (
    ModeEntry (..),
    OutcomeLine (..),
    StepEntry (..),
    caseFileName,
    modeEntry,
    outcomeJson,
    shellCommand,
    summaryHeader,
    summarySection,
 )
import LowerAudit.Run (RunRecord (..), StepResult (..), Termination (..))
import System.Process (readProcess)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, assertBool, testCase, (@?=))

at :: [Text] -> Value -> Maybe Value
at path start = foldM down start path
  where
    down v key = case v of
        Object o -> KeyMap.lookup (Key.fromText key) o
        _ -> Nothing

zeros :: String
zeros = replicate 64 '0'

casePath :: String
casePath = "results/20261105T120000Z-slice/case_" <> zeros <> ".mlir"

validityCommand :: [String]
validityCommand = ["ttmlir-opt", "--mlir-disable-threading", casePath]

bareCommand :: [String]
bareCommand =
    [ "ttmlir-opt"
    , "--mlir-disable-threading"
    , "--mlir-print-ir-before-all"
    , "--ttcore-register-device"
    , "--ttnn-layout"
    , "--convert-ttir-to-ttnn"
    , casePath
    ]

pipelineCommand :: [String]
pipelineCommand =
    [ "ttmlir-opt"
    , "--mlir-disable-threading"
    , "--mlir-print-ir-before-all"
    , "--ttir-to-ttnn-runtime-pipeline"
    , casePath
    ]

exit0 :: [String] -> StepEntry
exit0 command = StepEntry command (Exited 0)

bareFailed :: ModeEntry
bareFailed =
    ModeEntry
        (Classified (Outcome ConversionFailed (Just (NamedConversion "ConvertTTIRToTTNN"))))
        (exit0 validityCommand)
        (Just (StepEntry bareCommand (Exited 1)))
        [Text.pack casePath <> ":2:8: error: failed to legalize operation 'ttir.prod'"]

pipelineLowered :: ModeEntry
pipelineLowered =
    ModeEntry
        (Classified (Outcome Lowered Nothing))
        (exit0 validityCommand)
        (Just (exit0 pipelineCommand))
        []

sampleLine :: OutcomeLine
sampleLine =
    OutcomeLine
        "20261105T120000Z"
        (CaseId (Text.pack zeros))
        "V_ttir"
        [("tt-mlir", "f9dc1b3e5101"), ("llvm", "4efe170d858e")]
        bareFailed
        pipelineLowered

invalidEntry :: ModeEntry
invalidEntry =
    ModeEntry
        (Classified (Outcome Invalid (Just ParseAndVerify)))
        (StepEntry validityCommand (Exited 1))
        Nothing
        ["case.mlir:2:8: error: 'ttir.prod' op Expected output shape (), got (2, 2, 1)"]

invalidLine :: OutcomeLine
invalidLine = sampleLine{lineBare = invalidEntry, linePipeline = invalidEntry}

bareJson :: ModeEntry -> Maybe Value
bareJson entry = decode (outcomeJson sampleLine{lineBare = entry}) >>= at ["modes", "bare"]

entryWith :: Classification -> ModeEntry
entryWith c = pipelineLowered{entryClassification = c}

fieldsOf :: Classification -> [Maybe Value]
fieldsOf c =
    [ bareJson (entryWith c) >>= at [key]
    | key <- ["class", "rejectionId", "stage", "pass", "reason"]
    ]

expectFields :: Text -> Maybe Text -> Maybe Text -> Maybe Text -> Maybe Text -> [Maybe Value]
expectFields cls rejected stage pass reason =
    Just (String cls) : map (Just . maybe Null String) [rejected, stage, pass, reason]

terminationJson :: Termination -> Maybe Value
terminationJson t =
    bareJson pipelineLowered{entryConversion = Just (StepEntry ["tool"] t)}
        >>= at ["conversion", "termination"]

step :: Termination -> Text -> StepResult
step t err = StepResult ["tool", "case.mlir"] t "" err Nothing

accepted :: StepResult
accepted = step (Exited 0) ""

rank5Line :: Text
rank5Line = "case.mlir:2:8: error: 'ttnn.prod' op Input tensor rank is greater than 4 for reduce(product)."

prodRank :: DocumentedRejection
prodRank =
    DocumentedRejection
        "ttnn-prod-rank"
        "'ttnn.prod' op Input tensor rank is greater than 4 for reduce(product)."
        AtVerification
        "TTNNOps.cpp:6029-6030"
        "negative_reduce_prod_op.mlir:4"

contains :: Text -> Text -> Assertion
contains whole part = assertBool (Text.unpack part <> " is missing") (part `Text.isInfixOf` whole)

tests :: TestTree
tests =
    testGroup
        "LowerAudit.Report"
        [ testCase "caseFileName, architecture's case_*.mlir" $
            caseFileName (CaseId "ab12") @?= "case_ab12.mlir"
        , testGroup
            "shellCommand"
            [ testCase "plain words stay bare, so the command reads as typed" $
                shellCommand ["ttmlir-opt", "--ttnn-layout", "results/a_b.c/case_1.mlir"]
                    @?= "ttmlir-opt --ttnn-layout results/a_b.c/case_1.mlir"
            , testCase "an = is quoted: as a first word it would read as an assignment" $
                shellCommand ["a=b"] @?= "'a=b'"
            , testCase "sh reads back the exact words" $ do
                let exact =
                        [ "a b"
                        , "it's"
                        , "--pass-pipeline=builtin.module(func.func(tosa-to-linalg))"
                        , "$HOME"
                        , ""
                        , "*"
                        , "x\ny"
                        ]
                out <- readProcess "/bin/sh" ["-c", Text.unpack (shellCommand ("printf" : "%s|" : exact))] ""
                out @?= concatMap (<> "|") exact
            ]
        , testGroup
            "modeEntry"
            [ testCase "the classifier decides, with the list it was given" $
                entryClassification (modeEntry [prodRank] (RunRecord accepted (Just (step (Exited 1) rank5Line))))
                    @?= Classified (Outcome (ExpectedRejection "ttnn-prod-rank") (Just Verification))
            , testCase "both steps are recorded as they ran" $ do
                let entry = modeEntry [] (RunRecord accepted (Just (step (Signalled 6) "")))
                entryValidity entry @?= StepEntry ["tool", "case.mlir"] (Exited 0)
                entryConversion entry @?= Just (StepEntry ["tool", "case.mlir"] (Signalled 6))
            , testCase "no conversion stays absent" $
                entryConversion (modeEntry [] (RunRecord (step (Exited 1) "x: error: y\n") Nothing)) @?= Nothing
            , testCase "a rejection at validity keeps its diagnostic" $
                entryDiagnostics (modeEntry [] (RunRecord (step (Exited 1) "x: error: y\n") Nothing)) @?= ["x: error: y"]
            , testCase "only evidence lines survive, not IR dumps or notes" $
                entryDiagnostics
                    ( modeEntry
                        []
                        ( RunRecord
                            accepted
                            ( Just
                                ( step
                                    (Signalled 6)
                                    ( Text.unlines
                                        [ "// -----// IR Dump Before TTNNLayout (ttnn-layout) //----- //"
                                        , "module {"
                                        , "}"
                                        , rank5Line
                                        , "case.mlir:2:8: note: see current operation"
                                        , "LLVM ERROR: fatal"
                                        , "Assertion failed: (val >= 0), function alignUp"
                                        , "Stack dump:"
                                        ]
                                    )
                                )
                            )
                        )
                    )
                    @?= [rank5Line, "LLVM ERROR: fatal", "Assertion failed: (val >= 0), function alignUp"]
            ]
        , testGroup
            "outcomeJson, the schema in docs/TODO-l5.md"
            [ testCase "docs/TODO-l5.md's example line is exactly these bytes" $ do
                doc <- Lazy.readFile "docs/TODO-l5.md"
                filter (Lazy.isPrefixOf "{\"") (Char8.lines doc) @?= [outcomeJson sampleLine]
            , testCase "one line: no newline, even with one in a diagnostic" $
                Char8.count '\n' (outcomeJson sampleLine{lineBare = bareFailed{entryDiagnostics = ["a\nb"]}}) @?= 0
            , testCase "the oracle and the pin travel with every result" $ do
                let line = decode (outcomeJson sampleLine)
                (line >>= at ["oracle"]) @?= Just "V_ttir"
                (line >>= at ["pin", "tt-mlir"]) @?= Just "f9dc1b3e5101"
                (line >>= at ["pin", "llvm"]) @?= Just "4efe170d858e"
            , testCase "no conversion is null" $
                (bareJson invalidEntry >>= at ["conversion"]) @?= Just Null
            , testGroup
                "class, rejectionId, stage, pass, reason"
                [ testCase "INVALID" $
                    fieldsOf (Classified (Outcome Invalid (Just ParseAndVerify)))
                        @?= expectFields "INVALID" Nothing (Just "parse-and-verify") Nothing Nothing
                , testCase "EXPECTED_REJECTION carries its id" $
                    fieldsOf (Classified (Outcome (ExpectedRejection "ttnn-prod-rank") (Just Verification)))
                        @?= expectFields "EXPECTED_REJECTION" (Just "ttnn-prod-rank") (Just "verification") Nothing Nothing
                , testCase "LOWERED has no stage" $
                    fieldsOf (Classified (Outcome Lowered Nothing))
                        @?= expectFields "LOWERED" Nothing Nothing Nothing Nothing
                , testCase "CONVERSION_FAILED, with no pass to name" $
                    fieldsOf (Classified (Outcome ConversionFailed (Just Conversion)))
                        @?= expectFields "CONVERSION_FAILED" Nothing (Just "conversion") Nothing Nothing
                , testCase "OUTPUT_INVALID" $
                    fieldsOf (Classified (Outcome OutputInvalid (Just Verification)))
                        @?= expectFields "OUTPUT_INVALID" Nothing (Just "verification") Nothing Nothing
                , testCase "CRASH names its pass" $
                    fieldsOf (Classified (Outcome Crash (Just (NamedConversion "TTNNLayout"))))
                        @?= expectFields "CRASH" Nothing (Just "named-conversion") (Just "TTNNLayout") Nothing
                , testCase "TIMEOUT" $
                    fieldsOf (Classified (Outcome Timeout (Just Conversion)))
                        @?= expectFields "TIMEOUT" Nothing (Just "conversion") Nothing Nothing
                , testCase "UNEXPLAINED is not one of the seven, and keeps its reason" $
                    fieldsOf (Unexplained ParseAndVerify "unknown flag")
                        @?= expectFields "UNEXPLAINED" Nothing (Just "parse-and-verify") Nothing (Just "unknown flag")
                ]
            , testGroup
                "termination"
                [ testCase "exited" $
                    terminationJson (Exited 1) @?= Just (object ["kind" .= ("exited" :: Text), "code" .= (1 :: Int)])
                , testCase "signalled" $
                    terminationJson (Signalled 6) @?= Just (object ["kind" .= ("signalled" :: Text), "signal" .= (6 :: Int)])
                , testCase "timed out" $
                    terminationJson TimedOut @?= Just (object ["kind" .= ("timed-out" :: Text)])
                , testCase "failed to start" $
                    terminationJson (StartFailed "no such file")
                        @?= Just (object ["kind" .= ("start-failed" :: Text), "reason" .= ("no such file" :: Text)])
                ]
            ]
        , testGroup
            "summary"
            [ testCase "the header names the run, the oracle and the pin" $
                mapM_
                    (contains (summaryHeader sampleLine))
                    ["20261105T120000Z", "V_ttir", "tt-mlir", "f9dc1b3e5101", "llvm", "4efe170d858e"]
            , testCase "a section names the case, its classes and the failing pass" $
                mapM_
                    (contains (summarySection sampleLine))
                    [Text.pack zeros, Text.pack (caseFileName (lineCaseId sampleLine)), "CONVERSION_FAILED", "LOWERED", "ConvertTTIRToTTNN"]
            , testCase "a section has the exact reproduce command of every step" $
                mapM_
                    (contains (summarySection sampleLine) . shellCommand)
                    [validityCommand, bareCommand, pipelineCommand]
            , testCase "an invalid case says no conversion ran" $ do
                contains (summarySection invalidLine) "INVALID"
                contains (summarySection invalidLine) (shellCommand validityCommand)
                contains (summarySection invalidLine) "no conversion"
            ]
        ]
