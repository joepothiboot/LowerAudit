module LowerAudit.Report (
    ModeEntry (..),
    OutcomeLine (..),
    StepEntry (..),
    appendOutcome,
    appendSummary,
    caseFileName,
    modeEntry,
    outcomeJson,
    shellCommand,
    summaryHeader,
    summarySection,
) where

import Data.ByteString.Lazy (ByteString)
import Data.Text (Text)
import LowerAudit.Classify (Classification, DocumentedRejection)
import LowerAudit.Manifest (CaseId)
import LowerAudit.Run (RunRecord, Termination)

data StepEntry = StepEntry
    { entryCommand :: [String]
    , entryTermination :: Termination
    }
    deriving (Eq, Show)

data ModeEntry = ModeEntry
    { entryClassification :: Classification
    , entryValidity :: StepEntry
    , entryConversion :: Maybe StepEntry
    , entryDiagnostics :: [Text]
    }
    deriving (Eq, Show)

data OutcomeLine = OutcomeLine
    { lineRunId :: Text
    , lineCaseId :: CaseId
    , lineOracle :: Text
    , linePin :: [(Text, Text)]
    , lineBare :: ModeEntry
    , linePipeline :: ModeEntry
    }
    deriving (Eq, Show)

caseFileName :: CaseId -> FilePath
caseFileName = error "TODO: caseFileName"

shellCommand :: [String] -> Text
shellCommand = error "TODO: shellCommand"

modeEntry :: [DocumentedRejection] -> RunRecord -> ModeEntry
modeEntry = error "TODO: modeEntry"

outcomeJson :: OutcomeLine -> ByteString
outcomeJson = error "TODO: outcomeJson"

summaryHeader :: OutcomeLine -> Text
summaryHeader = error "TODO: summaryHeader"

summarySection :: OutcomeLine -> Text
summarySection = error "TODO: summarySection"

appendOutcome :: FilePath -> OutcomeLine -> IO ()
appendOutcome = error "TODO: appendOutcome"

appendSummary :: FilePath -> OutcomeLine -> IO ()
appendSummary = error "TODO: appendSummary"
