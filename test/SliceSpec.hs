{-# LANGUAGE OverloadedStrings #-}

module SliceSpec (tests) where

import Data.Aeson (FromJSON, Result (..), Value (..), decode, fromJSON)
import Data.ByteString.Lazy qualified as Lazy
import Data.ByteString.Lazy.Char8 qualified as Char8
import Data.List (isInfixOf, isSuffixOf)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), secondsToDiffTime)
import LowerAudit.Domain (ConcreteCase (..), Dim (..), ElementType (..), Params (..), ReduceOp (..))
import LowerAudit.Manifest (CaseId (..), caseId)
import LowerAudit.Oracle (vTtir)
import LowerAudit.Render (renderCase)
import LowerAudit.Report (OutcomeLine (..), caseFileName, outcomeJson, shellCommand, summaryHeader, summarySection)
import LowerAudit.Run (
    Mode (..),
    RunOptions (..),
    Step (..),
    Tool (..),
    stepArgs,
    tosaProbeTarget,
    ttmlirTarget,
 )
import LowerAudit.Slice (
    SliceEnv (..),
    formatRunId,
    runSlice,
    sliceCase,
    sliceFolder,
    sliceOptions,
 )
import ProbeSpec (liveCase, rejections)
import ReportSpec (at)
import System.Directory (
    copyFile,
    createDirectoryIfMissing,
    doesDirectoryExist,
    findExecutable,
    getPermissions,
    listDirectory,
    setOwnerExecutable,
    setPermissions,
 )
import System.Environment (getEnvironment)
import System.Exit (ExitCode (..))
import System.FilePath (takeDirectory, (</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (CreateProcess (..), proc, readCreateProcessWithExitCode)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, assertBool, assertEqual, assertFailure, testCase, (@?=))

standIn :: FilePath -> String -> IO FilePath
standIn dir body = do
    let path = dir </> "stand-in-tool"
    writeFile path ("#!/bin/sh\n" <> body <> "\n")
    permissions <- getPermissions path
    setPermissions path (setOwnerExecutable True permissions)
    pure path

lowers :: String
lowers = "exit 0"

failsBare :: String
failsBare =
    "case \"$*\" in *--convert-ttir-to-ttnn*) echo \"c.mlir:1:1: error: failed to legalize operation 'ttir.prod'\" >&2; exit 1;; esac"

rejectsAtValidity :: String
rejectsAtValidity = "echo \"c.mlir:1:1: error: 'ttir.prod' op Expected output shape\" >&2; exit 1"

abortsPipeline :: String
abortsPipeline =
    "case \"$*\" in *--ttir-to-ttnn-runtime-pipeline*) echo '// -----// IR Dump Before TTNNLayout (ttnn-layout) //----- //' >&2; kill -ABRT $$;; esac"

failsRank5 :: String
failsRank5 =
    "case \"$*\" in *--convert-ttir-to-ttnn*|*--ttir-to-ttnn-runtime-pipeline*) echo \"c.mlir:1:1: error: 'ttnn.prod' op Input tensor rank is greater than 4 for reduce(product).\" >&2; exit 1;; esac"

ttirPin :: [(Text, Text)]
ttirPin = [("tt-mlir", "f9dc1b3e5101"), ("llvm", "4efe170d858e")]

ttirEnv :: FilePath -> FilePath -> SliceEnv
ttirEnv tool = SliceEnv "test-run" tool ttmlirTarget "V_ttir" ttirPin []

tosaEnv :: FilePath -> FilePath -> SliceEnv
tosaEnv tool = SliceEnv "test-run" tool tosaProbeTarget "V_mlir" [("llvm", "6dfe1677ab8d")] []

ttirData :: FilePath
ttirData = "data/rejections-tt-mlir-f9dc1b3e5101.json"

tosaData :: FilePath
tosaData = "data/rejections-llvmorg-23.1.1-probes.json"

onStandIn :: String -> (FilePath -> SliceEnv -> IO a) -> IO a
onStandIn body act =
    withSystemTempDirectory "lower-audit" $ \dir -> do
        tool <- standIn dir body
        let folder = dir </> "nested" </> "x-slice"
        act folder (ttirEnv tool folder)

outcomeLines :: FilePath -> IO [Value]
outcomeLines folder = do
    bytes <- Lazy.readFile (folder </> "outcomes.jsonl")
    mapM parseLine (Char8.lines bytes)

parseLine :: Lazy.ByteString -> IO Value
parseLine bytes = maybe (assertFailure ("not JSON: " <> show bytes)) pure (decode bytes)

oneLine :: FilePath -> IO Value
oneLine folder = do
    found <- outcomeLines folder
    case found of
        [line] -> pure line
        _ -> assertFailure (show (length found) <> " lines in outcomes.jsonl")

type Verdict = [Maybe Value]

verdictOf :: Text -> Value -> Verdict
verdictOf mode line = [at ["modes", mode, key] line | key <- ["class", "rejectionId", "stage", "pass"]]

verdict :: Text -> Maybe Text -> Maybe Text -> Maybe Text -> Verdict
verdict cls rejected stage pass = Just (String cls) : map (Just . maybe Null String) [rejected, stage, pass]

lowered :: Verdict
lowered = verdict "LOWERED" Nothing Nothing Nothing

invalid :: Verdict
invalid = verdict "INVALID" Nothing (Just "parse-and-verify") Nothing

generatedText :: IO Text
generatedText = either (assertFailure . show) (pure . renderCase) sliceCase

fromValue :: (FromJSON a) => Maybe Value -> IO a
fromValue found = case fmap fromJSON found of
    Just (Success a) -> pure a
    _ -> assertFailure ("unexpected: " <> show found)

contains :: Text -> Text -> Assertion
contains whole part = assertBool (Text.unpack part <> " is missing") (part `Text.isInfixOf` whole)

hasCommandFor :: Value -> Text -> [String] -> Assertion
hasCommandFor line mode expected = do
    command <- fromValue (at ["modes", mode, "conversion", "command"] line)
    command @?= expected

acceptance ::
    String ->
    Tool ->
    FilePath ->
    (FilePath -> FilePath -> SliceEnv) ->
    IO Text ->
    [(Text, Verdict)] ->
    TestTree
acceptance name tool dataPath env readCase expected =
    liveCase name tool $ \path ->
        withSystemTempDirectory "lower-audit" $ \dir -> do
            listed <- rejections dataPath
            text <- readCase
            _ <- runSlice (env path (dir </> "x-slice")){envRejections = listed} text
            line <- oneLine (dir </> "x-slice")
            sequence_ [verdictOf mode line @?= v | (mode, v) <- expected]

goldenText :: FilePath -> IO Text
goldenText = TextIO.readFile . ("test/golden" </>)

bothModes :: Verdict -> [(Text, Verdict)]
bothModes v = [("bare", v), ("pipeline", v)]

ttirAcceptance :: String -> IO Text -> [(Text, Verdict)] -> TestTree
ttirAcceptance name = acceptance name TtmlirOpt ttirData ttirEnv

tosaAcceptance :: String -> IO Text -> [(Text, Verdict)] -> TestTree
tosaAcceptance name = acceptance name MlirOpt tosaData tosaEnv

cli :: FilePath -> [(String, String)] -> [String] -> IO (ExitCode, String, String)
cli dir extra args = do
    exe <- findExecutable "lower-audit" >>= maybe (assertFailure "lower-audit is not on PATH") pure
    inherited <- getEnvironment
    let kept = filter ((`notElem` map fst extra) . fst) inherited
    readCreateProcessWithExitCode (proc exe args){cwd = Just dir, env = Just (extra <> kept)} ""

withCliDir :: String -> (FilePath -> [(String, String)] -> IO a) -> IO a
withCliDir body act =
    withSystemTempDirectory "lower-audit" $ \dir -> do
        tool <- standIn dir body
        createDirectoryIfMissing True (takeDirectory (dir </> ttirData))
        copyFile ttirData (dir </> ttirData)
        act dir [("LOWER_AUDIT_TTMLIR_OPT", tool)]

cliSlice :: FilePath -> [(String, String)] -> IO FilePath
cliSlice dir extra = do
    (code, _, err) <- cli dir extra ["slice"]
    assertEqual err ExitSuccess code
    folders <- listDirectory (dir </> "results")
    case folders of
        [folder] -> do
            assertBool folder ("-slice" `isSuffixOf` folder)
            pure ("results" </> folder)
        _ -> assertFailure ("folders: " <> show folders)

noResults :: FilePath -> Assertion
noResults dir = do
    made <- doesDirectoryExist (dir </> "results")
    assertBool "results/ was created" (not made)

failsWith :: (ExitCode, String, String) -> String -> Assertion
failsWith (code, _, err) part = do
    assertEqual err (ExitFailure 2) code
    assertBool err (part `isInfixOf` err)

tests :: TestTree
tests =
    testGroup
        "LowerAudit.Slice"
        [ testGroup
            "the fixed parts"
            [ testCase "formatRunId is UTC, sorts by time, and is safe in a path" $
                formatRunId (UTCTime (fromGregorian 2026 11 5) (secondsToDiffTime 3723)) @?= "20261105T010203Z"
            , testCase "sliceFolder" $
                sliceFolder "20261105T010203Z" @?= "results/20261105T010203Z-slice"
            , testCase "sliceCase is architecture §3's case: rank 3, one positive dim, static, f32, no keep_dim" $
                sliceCase
                    @?= Right
                        ( ConcreteCase
                            (Params Prod F32 False)
                            [Size 2, Size 2, Size 2]
                            [Size 2, Size 2]
                            (Just [2])
                        )
            , testCase "sliceCase passes the declared V_ttir" $
                fmap vTtir sliceCase @?= Right (Right ())
            , testCase "sliceOptions: a limit, banners on to name the stage, no action log" $
                sliceOptions @?= RunOptions 60 True Nothing
            ]
        , testGroup
            "runSlice on a stand-in tool, so no MLIR tool is needed"
            [ testCase "the folder is created, and the case is written under its id" $
                onStandIn lowers $ \folder env -> do
                    line <- runSlice env "the case\n"
                    lineCaseId line @?= caseId "the case\n"
                    written <- TextIO.readFile (folder </> caseFileName (caseId "the case\n"))
                    written @?= "the case\n"
            , testCase "one call is one line, holding both modes" $
                onStandIn lowers $ \folder env -> do
                    _ <- runSlice env "the case\n"
                    line <- oneLine folder
                    sequence_ [verdictOf mode line @?= lowered | (mode, _) <- bothModes lowered]
            , testCase "the line on disk is the line returned" $
                onStandIn lowers $ \folder env -> do
                    returned <- runSlice env "the case\n"
                    line <- oneLine folder
                    Just line @?= decode (outcomeJson returned)
            , testCase "the run's identity is recorded" $
                onStandIn lowers $ \folder env -> do
                    _ <- runSlice env "the case\n"
                    line <- oneLine folder
                    at ["runId"] line @?= Just "test-run"
                    at ["oracle"] line @?= Just "V_ttir"
                    at ["pin", "tt-mlir"] line @?= Just "f9dc1b3e5101"
                    at ["caseId"] line @?= Just (let CaseId i = caseId "the case\n" in String i)
            , testCase "commands are recorded as run: stepArgs with sliceOptions, on the written file" $
                onStandIn lowers $ \folder env -> do
                    _ <- runSlice env "the case\n"
                    line <- oneLine folder
                    let file = folder </> caseFileName (caseId "the case\n")
                        tool = envTool env
                    hasCommandFor line "bare" (tool : stepArgs ttmlirTarget sliceOptions (ConversionStep Bare) file)
                    hasCommandFor line "pipeline" (tool : stepArgs ttmlirTarget sliceOptions (ConversionStep Pipeline) file)
                    validity <- fromValue (at ["modes", "bare", "validity", "command"] line)
                    validity @?= tool : stepArgs ttmlirTarget sliceOptions ValidityStep file
            , testCase "a second call appends, and keeps the first line" $
                onStandIn lowers $ \folder env -> do
                    _ <- runSlice env "first\n"
                    _ <- runSlice env "second\n"
                    found <- outcomeLines folder
                    map (at ["caseId"]) found
                        @?= [ Just (let CaseId i = caseId c in String i)
                            | c <- ["first\n", "second\n"]
                            ]
            , testCase "summary.md: one header, one section per call" $
                onStandIn lowers $ \folder env -> do
                    first <- runSlice env "first\n"
                    second <- runSlice env "second\n"
                    summary <- TextIO.readFile (folder </> "summary.md")
                    Text.count (summaryHeader first) summary @?= 1
                    mapM_ (contains summary . summarySection) [first, second]
            , testCase "the modes are classified apart" $
                onStandIn failsBare $ \folder env -> do
                    _ <- runSlice env "the case\n"
                    line <- oneLine folder
                    verdictOf "bare" line @?= verdict "CONVERSION_FAILED" Nothing (Just "conversion") Nothing
                    verdictOf "pipeline" line @?= lowered
            , testCase "a crash names its pass, through the banner sliceOptions asks for" $
                onStandIn abortsPipeline $ \folder env -> do
                    _ <- runSlice env "the case\n"
                    line <- oneLine folder
                    verdictOf "pipeline" line @?= verdict "CRASH" Nothing (Just "named-conversion") (Just "TTNNLayout")
                    at ["modes", "pipeline", "conversion", "termination", "signal"] line @?= Just (Number 6)
                    verdictOf "bare" line @?= lowered
            , testCase "invalid in both modes, and no conversion is recorded" $
                onStandIn rejectsAtValidity $ \folder env -> do
                    _ <- runSlice env "the case\n"
                    line <- oneLine folder
                    sequence_
                        [ do
                            verdictOf mode line @?= invalid
                            at ["modes", mode, "conversion"] line @?= Just Null
                        | (mode, _) <- bothModes invalid
                        ]
            , testCase "the summary of an invalid case has its reproduce command" $
                onStandIn rejectsAtValidity $ \folder env -> do
                    _ <- runSlice env "the case\n"
                    summary <- TextIO.readFile (folder </> "summary.md")
                    let file = folder </> caseFileName (caseId "the case\n")
                    contains summary (shellCommand (envTool env : stepArgs ttmlirTarget sliceOptions ValidityStep file))
            , testCase "a missing tool is recorded as UNEXPLAINED, not as a class" $
                withSystemTempDirectory "lower-audit" $ \dir -> do
                    _ <- runSlice (ttirEnv "/nonexistent/tool" dir) "the case\n"
                    line <- oneLine dir
                    at ["modes", "bare", "class"] line @?= Just "UNEXPLAINED"
            ]
        , testGroup
            "lower-audit, the executable, on a stand-in tool"
            [ testCase "slice: one folder, one line, the generated case, D-012's pin, V_ttir" $
                withCliDir lowers $ \dir extra -> do
                    folder <- cliSlice dir extra
                    line <- oneLine (dir </> folder)
                    text <- generatedText
                    let name = caseFileName (caseId text)
                    written <- TextIO.readFile (dir </> folder </> name)
                    written @?= text
                    at ["oracle"] line @?= Just "V_ttir"
                    at ["pin", "tt-mlir"] line @?= Just "f9dc1b3e5101"
                    at ["pin", "llvm"] line @?= Just "4efe170d858e"
                    sequence_ [verdictOf mode line @?= lowered | (mode, _) <- bothModes lowered]
            , testCase "slice: the run id in the line is the folder's" $
                withCliDir lowers $ \dir extra -> do
                    folder <- cliSlice dir extra
                    line <- oneLine (dir </> folder)
                    runId <- fromValue (at ["runId"] line)
                    folder @?= sliceFolder runId
            , testCase "slice: the commands use the path relative to where it ran" $
                withCliDir lowers $ \dir extra -> do
                    folder <- cliSlice dir extra
                    line <- oneLine (dir </> folder)
                    text <- generatedText
                    command <- fromValue (at ["modes", "bare", "conversion", "command"] line) :: IO [String]
                    drop (length command - 1) command @?= [folder </> caseFileName (caseId text)]
            , testCase "slice: summary.md is written, with a bare command" $
                withCliDir lowers $ \dir extra -> do
                    folder <- cliSlice dir extra
                    summary <- TextIO.readFile (dir </> folder </> "summary.md")
                    mapM_ (contains summary) ["--convert-ttir-to-ttnn", "--ttir-to-ttnn-runtime-pipeline", "f9dc1b3e5101"]
            , testCase "slice: a gap is a finding, so the command still succeeds" $
                withCliDir failsBare $ \dir extra -> do
                    folder <- cliSlice dir extra
                    line <- oneLine (dir </> folder)
                    at ["modes", "bare", "class"] line @?= Just "CONVERSION_FAILED"
            , testCase "slice: the pin's data file decides EXPECTED_REJECTION" $
                withCliDir failsRank5 $ \dir extra -> do
                    folder <- cliSlice dir extra
                    line <- oneLine (dir </> folder)
                    at ["modes", "bare", "rejectionId"] line @?= Just "ttnn-prod-rank"
            , testCase "slice: a missing tool stops it, says what to set, and writes nothing" $
                withCliDir lowers $ \dir _ -> do
                    result <- cli dir [("LOWER_AUDIT_TTMLIR_OPT", "/nonexistent/ttmlir-opt")] ["slice"]
                    failsWith result "LOWER_AUDIT_TTMLIR_OPT"
                    noResults dir
            , testCase "slice: a missing data file stops it, names the file, and writes nothing" $
                withSystemTempDirectory "lower-audit" $ \dir -> do
                    tool <- standIn dir lowers
                    result <- cli dir [("LOWER_AUDIT_TTMLIR_OPT", tool)] ["slice"]
                    failsWith result ttirData
                    noResults dir
            , testCase "no subcommand: usage names slice" $
                withCliDir lowers $ \dir extra -> do
                    result <- cli dir extra []
                    failsWith result "slice"
            , testCase "an unknown subcommand: usage names slice, and nothing runs" $
                withCliDir lowers $ \dir extra -> do
                    result <- cli dir extra ["nope"]
                    failsWith result "slice"
                    noResults dir
            ]
        , testGroup
            "acceptance, classes and stages from expected-outcomes.md; ttmlir-opt, skips without it"
            [ ttirAcceptance "the generated case, r = 3: row P1" generatedText (bothModes lowered)
            , ttirAcceptance "O1 at r = 2: row P1" (goldenText "o1-shape-prod-rank2.mlir") (bothModes lowered)
            , ttirAcceptance
                "O3: row P8, in ttnn-layout"
                (goldenText "o3-letters-prod-dynamic.mlir")
                (bothModes (verdict "CRASH" Nothing (Just "named-conversion") (Just "TTNNLayout")))
            , ttirAcceptance
                "documented rank 5: rows F7, F8"
                (goldenText "o1-shape-prod-rank5.mlir")
                (bothModes (verdict "EXPECTED_REJECTION" (Just "ttnn-prod-rank") (Just "verification") Nothing))
            , ttirAcceptance "O7's control: row F6" (goldenText "o7-ill-typed-prod.mlir") (bothModes invalid)
            ]
        , testGroup
            "acceptance on the record, classes hand-labelled from the probe table; mlir-opt, skips without it"
            [ tosaAcceptance "O1 at r = 2" (goldenText "tosa/o1-rank2.mlir") (bothModes lowered)
            , tosaAcceptance
                "O3, bare, the only mode the table records"
                (goldenText "tosa/o3-dynamic-result.mlir")
                [("bare", verdict "OUTPUT_INVALID" Nothing (Just "verification") Nothing)]
            , tosaAcceptance "O7's control" (goldenText "tosa/o7-ill-typed.mlir") (bothModes invalid)
            ]
        ]
