{-# LANGUAGE OverloadedStrings #-}

module AdapterSpec (tests) where

import Data.Aeson (Value (..), decodeStrict, object, (.=))
import Data.Bifunctor (first)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as Char8
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding (decodeUtf8Lenient)
import LowerAudit.Run (
    Mode (..),
    RunOptions (..),
    Step (..),
    Tool (..),
    resolveTool,
    stepArgs,
    tosaProbeTarget,
 )
import ReportSpec (at)
import System.Directory (doesFileExist)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO (IOMode (..), withBinaryFile)
import System.IO.Temp (withSystemTempDirectory)
import System.Process (CreateProcess (..), StdStream (..), proc, waitForProcess, withCreateProcess)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, assertBool, assertFailure, testCaseInfo, (@?=))

adapterPathFrom :: Maybe String -> FilePath
adapterPathFrom value = case value of
    Just path | not (null path) -> path
    _ -> "adapter/build/lower-audit-adapter"

findAdapter :: IO (Either String FilePath)
findAdapter = do
    path <- adapterPathFrom <$> lookupEnv "LOWER_AUDIT_ADAPTER"
    built <- doesFileExist path
    pure $
        if built
            then Right path
            else
                Left
                    ( "adapter not built at "
                        <> path
                        <> ": run cmake -S adapter -B adapter/build -G Ninja && cmake --build adapter/build, or set LOWER_AUDIT_ADAPTER"
                    )

orSkip :: IO (Either String a) -> (a -> IO String) -> IO String
orSkip find act = find >>= either (pure . ("skipped: " <>)) act

adapterCase :: String -> (FilePath -> Assertion) -> TestTree
adapterCase name act = testCaseInfo name $ orSkip findAdapter $ \adapter -> "" <$ act adapter

comparedCase :: String -> (FilePath -> FilePath -> Assertion) -> TestTree
comparedCase name act =
    testCaseInfo name $
        orSkip findAdapter $ \adapter ->
            orSkip (first Text.unpack <$> resolveTool MlirOpt) $ \mlirOpt ->
                "" <$ act adapter mlirOpt

data Captured = Captured
    { exitOf :: ExitCode
    , stdoutOf :: ByteString
    , stderrOf :: ByteString
    }

capture :: FilePath -> FilePath -> [String] -> IO Captured
capture dir tool args = do
    let outPath = dir </> "stdout"
        errPath = dir </> "stderr"
    code <-
        withBinaryFile outPath WriteMode $ \out ->
            withBinaryFile errPath WriteMode $ \err ->
                withCreateProcess (proc tool args){std_in = NoStream, std_out = UseHandle out, std_err = UseHandle err} $
                    \_ _ _ process -> waitForProcess process
    Captured code <$> ByteString.readFile outPath <*> ByteString.readFile errPath

jsonLines :: ByteString -> IO [Value]
jsonLines = mapM parse . Char8.lines
  where
    parse line = maybe (assertFailure ("not JSON: " <> show line)) pure (decodeStrict line)

runAdapter :: FilePath -> FilePath -> FilePath -> IO (Captured, [Value])
runAdapter dir adapter file = do
    let events = dir </> "events.jsonl"
    result <- capture dir adapter ["--events=" <> events, file]
    assertBool (Char8.unpack (stderrOf result)) (exitOf result /= ExitFailure 3)
    written <- ByteString.readFile events
    (,) result <$> jsonLines written

tosaFile :: FilePath -> FilePath
tosaFile name = "test/golden/tosa" </> name

reduceSum :: Text
reduceSum = "(anonymous namespace)::ReduceConverter<mlir::tosa::ReduceSumOp>"

addOp :: Text
addOp = "(anonymous namespace)::PointwiseConverter<mlir::tosa::AddOp>"

resizeBroadcast :: Text
resizeBroadcast = "(anonymous namespace)::MaterializeResizeBroadcast"

resizeUnary :: Text
resizeUnary = "(anonymous namespace)::ResizeUnaryConverter"

resizeGeneric :: Text
resizeGeneric = "(anonymous namespace)::GenericResizeConverter"

begin :: Text -> Text -> Value
begin op name = object ["kind" .= String "pattern-begin", "op" .= op, "pattern" .= name]

end :: Text -> Text -> Value
end name status = object ["kind" .= String "pattern-end", "pattern" .= name, "status" .= status]

matchFailure :: Text -> Value
matchFailure reason = object ["kind" .= String "match-failure", "reason" .= reason]

applied :: Text -> Text -> [Value]
applied op name = [begin op name, end name "success"]

data Fixture = Fixture
    { fixtureFile :: FilePath
    , fixtureExit :: ExitCode
    , fixtureEvents :: [Value]
    }

unrankedReason :: Text
unrankedReason = "unranked tensors not supported"

fixtures :: [Fixture]
fixtures =
    [ Fixture ("o1-rank" <> show r <> ".mlir") ExitSuccess (applied "tosa.reduce_sum" reduceSum)
    | r <- [1 .. 8 :: Int]
    ]
        ++ [ Fixture "o2-dynamic.mlir" ExitSuccess (applied "tosa.reduce_sum" reduceSum)
           , Fixture "o3-dynamic-result.mlir" (ExitFailure 1) (applied "tosa.reduce_sum" reduceSum)
           , Fixture "o6-add-broadcast.mlir" ExitSuccess (applied "tosa.add" addOp)
           , Fixture "o6-add-rank0.mlir" ExitSuccess (applied "tosa.add" addOp)
           , Fixture "o7-ill-typed.mlir" (ExitFailure 1) []
           , Fixture
                "unranked-reduce-sum.mlir"
                (ExitFailure 1)
                [begin "tosa.reduce_sum" reduceSum, matchFailure unrankedReason, end reduceSum "failure"]
           , Fixture
                "resize-attempts.mlir"
                ExitSuccess
                ( [ begin "tosa.resize" resizeBroadcast
                  , matchFailure "tosa.resize has no broadcasting behavior"
                  , end resizeBroadcast "failure"
                  , begin "tosa.resize" resizeUnary
                  , matchFailure "tosa.resize is not a pure 1x1->1x1 image operation"
                  , end resizeUnary "failure"
                  ]
                    ++ applied "tosa.resize" resizeGeneric
                )
           , Fixture "legal-ops.mlir" ExitSuccess []
           , Fixture "legal-cond-if.mlir" (ExitFailure 1) []
           , Fixture "legal-while-loop.mlir" (ExitFailure 1) []
           ]

plain :: RunOptions
plain = RunOptions 60 False Nothing

fidelity :: Fixture -> FilePath -> FilePath -> Assertion
fidelity fixture adapter mlirOpt =
    withSystemTempDirectory "lower-audit" $ \dir -> do
        let file = tosaFile (fixtureFile fixture)
        reference <- capture dir mlirOpt (stepArgs tosaProbeTarget plain (ConversionStep Bare) file)
        exitOf reference @?= fixtureExit fixture
        assertBool "mlir-opt prints a module exactly when it lowers" $
            ByteString.null (stdoutOf reference) == (fixtureExit fixture /= ExitSuccess)
        (observed, _) <- runAdapter dir adapter file
        exitOf observed @?= exitOf reference
        stdoutOf observed @?= stdoutOf reference
        stderrOf observed @?= stderrOf reference

attemptsInLog :: Text -> [Text]
attemptsInLog = map (snd . Text.breakOnEnd marker) . filter (marker `Text.isInfixOf`) . Text.lines
  where
    marker = "`apply-pattern pattern: "

beginPatterns :: [Value] -> [Text]
beginPatterns events =
    [ name
    | event <- events
    , at ["kind"] event == Just "pattern-begin"
    , Just (String name) <- [at ["pattern"] event]
    ]

beginCount :: Fixture -> FilePath -> FilePath -> Assertion
beginCount fixture adapter mlirOpt =
    withSystemTempDirectory "lower-audit" $ \dir -> do
        let file = tosaFile (fixtureFile fixture)
            logPath = dir </> "actions.txt"
        _ <- capture dir mlirOpt (stepArgs tosaProbeTarget plain{logActionsTo = Just logPath} (ConversionStep Bare) file)
        attempts <- attemptsInLog . decodeUtf8Lenient <$> ByteString.readFile logPath
        length attempts @?= length (beginPatterns (fixtureEvents fixture))
        (_, events) <- runAdapter dir adapter file
        let begun = beginPatterns events
        length begun @?= length attempts
        assertBool (show (begun, attempts)) (and (zipWith Text.isPrefixOf begun attempts))

usageCase :: String -> [String] -> TestTree
usageCase name args =
    adapterCase name $ \adapter ->
        withSystemTempDirectory "lower-audit" $ \dir -> do
            result <- capture dir adapter args
            exitOf result @?= ExitFailure 2
            assertBool (Char8.unpack (stderrOf result)) ("usage: " `ByteString.isInfixOf` stderrOf result)

dumpCase :: String -> (Captured -> Assertion) -> TestTree
dumpCase name check =
    adapterCase name $ \adapter ->
        withSystemTempDirectory "lower-audit" $ \dir ->
            capture dir adapter ["--dump-patterns"] >>= check

nonEmptyAt :: Text -> Value -> Bool
nonEmptyAt key line = case at [key] line of
    Just (String text) -> not (Text.null text)
    _ -> False

unrankedCase :: TestTree
unrankedCase =
    adapterCase "the unranked control is a match failure, with TosaToLinalg.cpp:1168's reason" $ \adapter ->
        withSystemTempDirectory "lower-audit" $ \dir -> do
            (result, events) <- runAdapter dir adapter (tosaFile "unranked-reduce-sum.mlir")
            exitOf result @?= ExitFailure 1
            [at ["reason"] event | event <- events, at ["kind"] event == Just "match-failure"]
                @?= [Just (String unrankedReason)]

repeatCase :: TestTree
repeatCase =
    adapterCase "two runs over one events path: equal, and not appended" $ \adapter ->
        withSystemTempDirectory "lower-audit" $ \dir -> do
            (result, events) <- runAdapter dir adapter (tosaFile "o1-rank2.mlir")
            (again, eventsAgain) <- runAdapter dir adapter (tosaFile "o1-rank2.mlir")
            eventsAgain @?= events
            stdoutOf again @?= stdoutOf result

eventsCase :: Fixture -> TestTree
eventsCase fixture =
    adapterCase (fixtureFile fixture) $ \adapter ->
        withSystemTempDirectory "lower-audit" $ \dir -> do
            (_, events) <- runAdapter dir adapter (tosaFile (fixtureFile fixture))
            events @?= fixtureEvents fixture

tests :: TestTree
tests =
    testGroup
        "the listener adapter, skips when it is not built"
        [ testGroup
            "arguments"
            [ usageCase "none" []
            , usageCase "an unknown flag" ["--nope"]
            , usageCase "an input without --events" ["case.mlir"]
            , usageCase "--events without an input" ["--events=events.jsonl"]
            , usageCase "two inputs" ["--events=events.jsonl", "a.mlir", "b.mlir"]
            , usageCase "--dump-patterns with an input" ["--dump-patterns", "case.mlir"]
            , usageCase "--dump-patterns with --events" ["--dump-patterns", "--events=events.jsonl"]
            , adapterCase "a missing input stops it, names the file, and writes no events" $ \adapter ->
                withSystemTempDirectory "lower-audit" $ \dir -> do
                    let events = dir </> "events.jsonl"
                    result <- capture dir adapter ["--events=" <> events, "/nonexistent/case.mlir"]
                    exitOf result @?= ExitFailure 2
                    assertBool "names the file" ("/nonexistent/case.mlir" `ByteString.isInfixOf` stderrOf result)
                    written <- doesFileExist events
                    assertBool "events file was created" (not written)
            , adapterCase "an events file that cannot be opened stops it, and names the file" $ \adapter ->
                withSystemTempDirectory "lower-audit" $ \dir -> do
                    result <- capture dir adapter ["--events=/nonexistent/events.jsonl", tosaFile "o1-rank1.mlir"]
                    exitOf result @?= ExitFailure 2
                    assertBool "names the file" ("/nonexistent/events.jsonl" `ByteString.isInfixOf` stderrOf result)
            ]
        , testGroup
            "the pattern-name dump"
            [ dumpCase "exits 0, and prints nothing on stderr" $ \result -> do
                exitOf result @?= ExitSuccess
                stderrOf result @?= ""
            , dumpCase "every line is a registered pattern, with its root" $ \result -> do
                registered <- jsonLines (stdoutOf result)
                assertBool "no lines" (not (null registered))
                mapM_ (\line -> at ["kind"] line @?= Just "registered") registered
                assertBool "an empty name" (all (nonEmptyAt "pattern") registered)
                assertBool "an empty root" (all (nonEmptyAt "root") registered)
            , dumpCase "lines are compact with sorted keys, and name the fixtures' patterns" $ \result -> do
                let printed = Char8.lines (stdoutOf result)
                assertBool "reduce_sum" $
                    "{\"kind\":\"registered\",\"pattern\":\"(anonymous namespace)::ReduceConverter<mlir::tosa::ReduceSumOp>\",\"root\":\"tosa.reduce_sum\"}"
                        `elem` printed
                assertBool "add" $
                    "{\"kind\":\"registered\",\"pattern\":\"(anonymous namespace)::PointwiseConverter<mlir::tosa::AddOp>\",\"root\":\"tosa.add\"}"
                        `elem` printed
            , adapterCase "two runs print equal bytes" $ \adapter ->
                withSystemTempDirectory "lower-audit" $ \dir -> do
                    printed <- capture dir adapter ["--dump-patterns"]
                    again <- capture dir adapter ["--dump-patterns"]
                    stdoutOf again @?= stdoutOf printed
            ]
        , testGroup
            "fidelity: exit code, stdout and stderr equal mlir-opt's, byte for byte, on the bare pass"
            [comparedCase (fixtureFile fixture) (fidelity fixture) | fixture <- fixtures]
        , testGroup
            "begin events equal the action log's apply-pattern lines, in number and pattern"
            [comparedCase (fixtureFile fixture) (beginCount fixture) | fixture <- fixtures]
        , testGroup "events" (unrankedCase : repeatCase : map eventsCase fixtures)
        ]
