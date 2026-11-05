{-# LANGUAGE OverloadedStrings #-}

module RunSpec (tests) where

import Data.Maybe (isNothing)
import Data.Text qualified as Text
import GHC.Clock (getMonotonicTime)
import LowerAudit.Run (
    Mode (..),
    RunOptions (..),
    Step (..),
    StepResult (..),
    Target (..),
    Termination (..),
    Tool (..),
    findTool,
    runInvocation,
    stepArgs,
    toolPathFrom,
    tosaProbeTarget,
    ttmlirTarget,
 )
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertFailure, testCase, (@?=))

sh :: Int -> String -> IO StepResult
sh limit script = runInvocation limit Nothing "/bin/sh" ["-c", script]

plain :: RunOptions
plain = RunOptions 30 False Nothing

tests :: TestTree
tests =
    testGroup
        "LowerAudit.Run"
        [ testGroup
            "tool location, one place"
            [ testCase "mlir-opt defaults to the Homebrew path" $
                toolPathFrom MlirOpt Nothing @?= "/opt/homebrew/opt/llvm/bin/mlir-opt"
            , testCase "ttmlir-opt defaults to its bare name, D-015: no Homebrew build exists" $
                toolPathFrom TtmlirOpt Nothing @?= "ttmlir-opt"
            , testCase "the environment value wins" $
                map (`toolPathFrom` Just "/x/tool") [minBound ..] @?= ["/x/tool", "/x/tool"]
            , testCase "a missing tool is Left, and says what to set" $ do
                found <- findTool TtmlirOpt "/nonexistent/ttmlir-opt"
                case found of
                    Right path -> assertFailure ("found " <> path)
                    Left why -> do
                        assertBool "names the path" ("/nonexistent/ttmlir-opt" `Text.isInfixOf` why)
                        assertBool "names the variable" ("LOWER_AUDIT_TTMLIR_OPT" `Text.isInfixOf` why)
            , testCase "a missing mlir-opt names its own variable" $ do
                found <- findTool MlirOpt "/nonexistent/mlir-opt"
                assertBool "names the variable" (either ("LOWER_AUDIT_MLIR_OPT" `Text.isInfixOf`) (const False) found)
            , testCase "an executable is Right, with its path" $ do
                found <- findTool MlirOpt "/bin/sh"
                found @?= Right "/bin/sh"
            ]
        , testGroup
            "targets"
            [ testCase "ttmlirTarget is D-017's commands, V_ttir has no flags" $
                ttmlirTarget
                    @?= Target
                        TtmlirOpt
                        []
                        ["--ttcore-register-device", "--ttnn-layout", "--convert-ttir-to-ttnn"]
                        ["--ttir-to-ttnn-runtime-pipeline"]
            , testCase "tosaProbeTarget is the probe table's commands" $
                tosaProbeTarget
                    @?= Target
                        MlirOpt
                        []
                        ["--pass-pipeline=builtin.module(func.func(tosa-to-linalg))"]
                        ["--tosa-to-linalg-pipeline"]
            ]
        , testGroup
            "stepArgs"
            [ testCase "validity: threading off, no pass flags" $
                stepArgs ttmlirTarget plain ValidityStep "case.mlir"
                    @?= ["--mlir-disable-threading", "case.mlir"]
            , testCase "validity ignores the banner and log options: no pass runs" $
                stepArgs ttmlirTarget (RunOptions 30 True (Just "log.txt")) ValidityStep "case.mlir"
                    @?= ["--mlir-disable-threading", "case.mlir"]
            , testCase "bare" $
                stepArgs ttmlirTarget plain (ConversionStep Bare) "case.mlir"
                    @?= [ "--mlir-disable-threading"
                        , "--ttcore-register-device"
                        , "--ttnn-layout"
                        , "--convert-ttir-to-ttnn"
                        , "case.mlir"
                        ]
            , testCase "pipeline" $
                stepArgs ttmlirTarget plain (ConversionStep Pipeline) "case.mlir"
                    @?= ["--mlir-disable-threading", "--ttir-to-ttnn-runtime-pipeline", "case.mlir"]
            , testCase "banners and log come before the mode flags" $
                stepArgs ttmlirTarget (RunOptions 30 True (Just "log.txt")) (ConversionStep Pipeline) "case.mlir"
                    @?= [ "--mlir-disable-threading"
                        , "--mlir-print-ir-before-all"
                        , "--log-actions-to=log.txt"
                        , "--ttir-to-ttnn-runtime-pipeline"
                        , "case.mlir"
                        ]
            ]
        , testGroup
            "runInvocation, on /bin/sh"
            [ testCase "exit 0: stdout and stderr stay apart, command is recorded" $ do
                r <- sh 30 "echo out; echo err >&2"
                termination r @?= Exited 0
                stdoutText r @?= "out\n"
                stderrText r @?= "err\n"
                stepCommand r @?= ["/bin/sh", "-c", "echo out; echo err >&2"]
            , testCase "a non-zero exit" $ do
                r <- sh 30 "echo err >&2; exit 3"
                termination r @?= Exited 3
                stderrText r @?= "err\n"
            , testCase "SIGABRT is a signal, not an exit code" $ do
                r <- sh 30 "kill -ABRT $$"
                termination r @?= Signalled 6
            , testCase "SIGSEGV is a signal, not an exit code" $ do
                r <- sh 30 "kill -SEGV $$"
                termination r @?= Signalled 11
            , testCase "a tool that outlives the limit is stopped soon after it" $ do
                start <- getMonotonicTime
                r <- sh 1 "exec sleep 30"
                end <- getMonotonicTime
                termination r @?= TimedOut
                assertBool ("took " <> show (end - start) <> " s") (end - start < 10)
            , testCase "stderr written before a timeout is kept, so the stage can be named" $ do
                r <- sh 1 "echo early >&2; exec sleep 30"
                termination r @?= TimedOut
                stderrText r @?= "early\n"
            , testCase "more output than a pipe holds neither blocks nor truncates" $ do
                r <- sh 60 "head -c 1000000 /dev/zero | tr '\\0' x >&2; head -c 1000000 /dev/zero | tr '\\0' y"
                termination r @?= Exited 0
                Text.length (stderrText r) @?= 1000000
                Text.length (stdoutText r) @?= 1000000
            , testCase "bytes that are not UTF-8 do not raise" $ do
                r <- sh 30 "printf 'a\\377b' >&2"
                termination r @?= Exited 0
                assertBool "keeps what it can" ("a" `Text.isPrefixOf` stderrText r)
            , testCase "a tool that cannot start is a value, not an exception" $ do
                r <- runInvocation 30 Nothing "/nonexistent/tool" []
                case termination r of
                    StartFailed _ -> pure ()
                    other -> assertFailure (show other)
            ]
        , testGroup
            "action log"
            [ testCase "read back when the tool leaves it" $
                withSystemTempDirectory "lower-audit" $ \dir -> do
                    let path = dir </> "log.txt"
                    r <- runInvocation 30 (Just path) "/bin/sh" ["-c", "echo logged > " <> path]
                    actionLog r @?= Just "logged\n"
            , testCase "Nothing when a crash removed it, ToolOutputFile.cpp:24" $
                withSystemTempDirectory "lower-audit" $ \dir -> do
                    r <- runInvocation 30 (Just (dir </> "log.txt")) "/bin/sh" ["-c", "kill -ABRT $$"]
                    termination r @?= Signalled 6
                    assertBool "no log" (isNothing (actionLog r))
            , testCase "Nothing when none was asked for" $ do
                r <- sh 30 "true"
                assertBool "no log" (isNothing (actionLog r))
            ]
        ]
