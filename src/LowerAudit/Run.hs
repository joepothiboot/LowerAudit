module LowerAudit.Run (
    Mode (..),
    RunOptions (..),
    RunRecord (..),
    Step (..),
    StepResult (..),
    Target (..),
    Termination (..),
    Tool (..),
    findTool,
    resolveTool,
    runCase,
    runInvocation,
    runValidity,
    stepArgs,
    toolPathFrom,
    tosaProbeTarget,
    ttmlirTarget,
) where

import Data.Text (Text)

data Tool = MlirOpt | TtmlirOpt
    deriving (Eq, Show, Enum, Bounded)

data Mode = Bare | Pipeline
    deriving (Eq, Show, Enum, Bounded)

data Step = ValidityStep | ConversionStep Mode
    deriving (Eq, Show)

data Target = Target
    { targetTool :: Tool
    , validityFlags :: [String]
    , bareFlags :: [String]
    , pipelineFlags :: [String]
    }
    deriving (Eq, Show)

data RunOptions = RunOptions
    { timeoutSeconds :: Int
    , printPassBanners :: Bool
    , logActionsTo :: Maybe FilePath
    }
    deriving (Eq, Show)

data Termination
    = Exited Int
    | Signalled Int
    | TimedOut
    | StartFailed Text
    deriving (Eq, Show)

data StepResult = StepResult
    { stepCommand :: [String]
    , termination :: Termination
    , stdoutText :: Text
    , stderrText :: Text
    , actionLog :: Maybe Text
    }
    deriving (Eq, Show)

data RunRecord = RunRecord
    { validityResult :: StepResult
    , conversionResult :: Maybe StepResult
    }
    deriving (Eq, Show)

toolPathFrom :: Tool -> Maybe String -> FilePath
toolPathFrom = error "TODO: toolPathFrom"

findTool :: Tool -> FilePath -> IO (Either Text FilePath)
findTool = error "TODO: findTool"

resolveTool :: Tool -> IO (Either Text FilePath)
resolveTool = error "TODO: resolveTool"

ttmlirTarget :: Target
ttmlirTarget = error "TODO: ttmlirTarget"

tosaProbeTarget :: Target
tosaProbeTarget = error "TODO: tosaProbeTarget"

stepArgs :: Target -> RunOptions -> Step -> FilePath -> [String]
stepArgs = error "TODO: stepArgs"

runInvocation :: Int -> Maybe FilePath -> FilePath -> [String] -> IO StepResult
runInvocation = error "TODO: runInvocation"

runValidity :: FilePath -> Target -> RunOptions -> FilePath -> IO StepResult
runValidity = error "TODO: runValidity"

runCase :: FilePath -> Target -> RunOptions -> Mode -> FilePath -> IO RunRecord
runCase = error "TODO: runCase"
