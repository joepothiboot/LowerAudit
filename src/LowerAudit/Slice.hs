module LowerAudit.Slice (
    SliceEnv (..),
    formatRunId,
    runCommand,
    runSlice,
    sliceCase,
    sliceFolder,
    sliceOptions,
) where

import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import LowerAudit.Classify (DocumentedRejection)
import LowerAudit.Domain (ConcreteCase, DomainError)
import LowerAudit.Report (OutcomeLine)
import LowerAudit.Run (RunOptions, Target)
import System.Exit (ExitCode)

data SliceEnv = SliceEnv
    { envRunId :: Text
    , envTool :: FilePath
    , envTarget :: Target
    , envOracle :: Text
    , envPin :: [(Text, Text)]
    , envRejections :: [DocumentedRejection]
    , envFolder :: FilePath
    }
    deriving (Eq, Show)

formatRunId :: UTCTime -> Text
formatRunId = error "TODO: formatRunId"

sliceFolder :: Text -> FilePath
sliceFolder = error "TODO: sliceFolder"

sliceCase :: Either DomainError ConcreteCase
sliceCase = error "TODO: sliceCase"

sliceOptions :: RunOptions
sliceOptions = error "TODO: sliceOptions"

runSlice :: SliceEnv -> Text -> IO OutcomeLine
runSlice = error "TODO: runSlice"

runCommand :: [String] -> IO ExitCode
runCommand = error "TODO: runCommand"
