{-# LANGUAGE OverloadedStrings #-}

module ProbeSpec (liveCase, tests) where

import Data.ByteString.Lazy qualified as Lazy
import Data.Maybe (fromMaybe, isNothing)
import Data.Text (Text)
import Data.Text qualified as Text
import LowerAudit.Classify (
    Classification (..),
    DocumentedRejection,
    Outcome (..),
    OutcomeClass (..),
    Stage (..),
    classify,
    parseRejections,
 )
import LowerAudit.Run (
    Mode (..),
    RunOptions (..),
    RunRecord (..),
    StepResult (..),
    Target (..),
    Tool (..),
    resolveTool,
    runCase,
    tosaProbeTarget,
    ttmlirTarget,
 )
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, assertBool, assertFailure, testCaseInfo, (@?=))

liveCase :: String -> Tool -> (FilePath -> Assertion) -> TestTree
liveCase name tool act = testCaseInfo name $ do
    found <- resolveTool tool
    case found of
        Left why -> pure ("skipped: " <> Text.unpack why)
        Right path -> "" <$ act path

options :: RunOptions
options = RunOptions 60 True Nothing

rejections :: FilePath -> IO [DocumentedRejection]
rejections path = do
    bytes <- Lazy.readFile path
    either (\e -> assertFailure (path <> ": " <> e)) pure (parseRejections bytes)

classOf :: Classification -> Either String OutcomeClass
classOf c = case c of
    Classified o -> Right (outcomeClass o)
    Unexplained _ why -> Left (Text.unpack why)

tosaData :: FilePath
tosaData = "data/rejections-llvmorg-23.1.1-probes.json"

tosaFile :: FilePath -> FilePath
tosaFile name = "test/golden/tosa" </> name

o1 :: Int -> FilePath
o1 r = "o1-rank" <> show r <> ".mlir"

tosaProbe :: String -> FilePath -> Mode -> OutcomeClass -> TestTree
tosaProbe name file mode expected =
    liveCase name MlirOpt $ \tool -> do
        listed <- rejections tosaData
        record <- runCase tool tosaProbeTarget options mode (tosaFile file)
        classOf (classify listed record) @?= Right expected

tosaProbes :: TestTree
tosaProbes =
    testGroup
        "recorded probes on Homebrew mlir-opt, classes hand-labelled from the probe table"
        [ testGroup
            "O1"
            ( [tosaProbe ("r = " <> show r <> ", bare: exit 0") (o1 r) Bare Lowered | r <- [1 .. 8]]
                ++ [tosaProbe ("r = " <> show r <> ", pipeline: exit 0") (o1 r) Pipeline Lowered | r <- [1 .. 6]]
                ++ [ tosaProbe
                        ("r = " <> show r <> ", pipeline: failed level check")
                        (o1 r)
                        Pipeline
                        (ExpectedRejection "tosa-level-rank")
                   | r <- [7, 8]
                   ]
            )
        , tosaProbe "O2, pipeline: dynamic, failed level check" "o2-dynamic.mlir" Pipeline (ExpectedRejection "tosa-level-dynamic")
        , tosaProbe "O3, bare: output fails verification" "o3-dynamic-result.mlir" Bare OutputInvalid
        , liveCase "O4, bare: the action log records the attempt" MlirOpt $ \tool ->
            withSystemTempDirectory "lower-audit" $ \dir -> do
                let opts = options{logActionsTo = Just (dir </> "actions.txt")}
                record <- runCase tool tosaProbeTarget opts Bare (tosaFile (o1 2))
                classOf (classify [] record) @?= Right Lowered
                logged <- maybe (assertFailure "no action log") pure (conversionResult record >>= actionLog)
                assertBool "apply-pattern" ("apply-pattern" `Text.isInfixOf` logged)
                assertBool "ReduceConverter" ("ReduceConverter<mlir::tosa::ReduceSumOp>" `Text.isInfixOf` logged)
        , liveCase "O5: a pass that cannot be scheduled is not a class" MlirOpt $ \tool -> do
            record <- runCase tool tosaProbeTarget{bareFlags = ["--tosa-to-linalg"]} options Bare (tosaFile (o1 2))
            case classify [] record of
                Unexplained _ _ -> pure ()
                other -> assertFailure (show other)
        , testGroup
            "O6: exit 0 in both modes"
            [ tosaProbe (file <> ", " <> show mode) file mode Lowered
            | file <- ["o6-add-rank0.mlir", "o6-add-broadcast.mlir"]
            , mode <- [minBound ..]
            ]
        , testGroup
            "O7: invalid, and no conversion runs"
            [ liveCase (show mode) MlirOpt $ \tool -> do
                record <- runCase tool tosaProbeTarget options mode (tosaFile "o7-ill-typed.mlir")
                classOf (classify [] record) @?= Right Invalid
                assertBool "no conversion" (isNothing (conversionResult record))
            | mode <- [minBound ..]
            ]
        ]

ttirData :: FilePath
ttirData = "data/rejections-tt-mlir-f9dc1b3e5101.json"

ttirFile :: FilePath -> FilePath
ttirFile name = "test/golden" </> name

ttirProbe :: String -> FilePath -> Mode -> OutcomeClass -> Maybe Stage -> TestTree
ttirProbe name file mode expected stage =
    liveCase (name <> ", " <> show mode) TtmlirOpt $ \tool -> do
        listed <- rejections ttirData
        record <- runCase tool ttmlirTarget options mode (ttirFile file)
        classify listed record @?= Classified (Outcome expected stage)

ttirForms :: TestTree
ttirForms =
    testGroup
        "TTIR forms of the probes on ttmlir-opt, classes from expected-outcomes.md"
        [ testGroup "O1 at r = 2: row P1" [ttirProbe "o1" "o1-shape-prod-rank2.mlir" m Lowered Nothing | m <- [minBound ..]]
        , testGroup
            "O1 at r = 5: row P5"
            [ ttirProbe "o1" "o1-shape-prod-rank5.mlir" m (ExpectedRejection "ttnn-prod-rank") (Just Verification)
            | m <- [minBound ..]
            ]
        , testGroup
            "O2: row P8, in ttnn-layout"
            [ ttirProbe "o2" "o2-letters-prod-keep.mlir" m Crash (Just (NamedConversion "TTNNLayout"))
            | m <- [minBound ..]
            ]
        , testGroup
            "O3: row P8, in ttnn-layout"
            [ ttirProbe "o3" "o3-letters-prod-dynamic.mlir" m Crash (Just (NamedConversion "TTNNLayout"))
            | m <- [minBound ..]
            ]
        , liveCase "O4: row P1, the action log records the attempt" TtmlirOpt $ \tool ->
            withSystemTempDirectory "lower-audit" $ \dir -> do
                let opts = options{logActionsTo = Just (dir </> "actions.txt")}
                record <- runCase tool ttmlirTarget opts Bare (ttirFile "o1-shape-prod-rank2.mlir")
                classify [] record @?= Classified (Outcome Lowered Nothing)
                let logged = fromMaybe "" (conversionResult record >>= actionLog) :: Text
                assertBool "ReductionProdOpConversionPattern" ("ReductionProdOpConversionPattern" `Text.isInfixOf` logged)
        , testGroup "O6: row S1, the control" [ttirProbe "o6" "control-sum-rank2.mlir" m Lowered Nothing | m <- [minBound ..]]
        , testGroup
            "O7: row F6"
            [ ttirProbe "o7" "o7-ill-typed-prod.mlir" m Invalid (Just ParseAndVerify)
            | m <- [minBound ..]
            ]
        ]

tests :: TestTree
tests = testGroup "probes" [tosaProbes, ttirForms]
