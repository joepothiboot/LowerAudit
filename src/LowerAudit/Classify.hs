module LowerAudit.Classify (
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
) where

import Data.ByteString.Lazy (ByteString)
import Data.Text (Text)
import LowerAudit.Run (RunRecord, StepResult)

data OutcomeClass
    = Invalid
    | ExpectedRejection Text
    | Lowered
    | ConversionFailed
    | OutputInvalid
    | Crash
    | Timeout
    deriving (Eq, Show)

data Stage
    = ParseAndVerify
    | NamedConversion Text
    | Conversion
    | Verification
    deriving (Eq, Show)

data Outcome = Outcome
    { outcomeClass :: OutcomeClass
    , failingStage :: Maybe Stage
    }
    deriving (Eq, Show)

data Classification
    = Classified Outcome
    | Unexplained Stage Text
    deriving (Eq, Show)

data RejectionStage = AtVerification | AtPass
    deriving (Eq, Show)

data DocumentedRejection = DocumentedRejection
    { rejectionId :: Text
    , rejectionDiagnostic :: Text
    , rejectionStage :: RejectionStage
    , rejectionSource :: Text
    , rejectionDocumentedBy :: Text
    }
    deriving (Eq, Show)

data ValidityVerdict
    = ValidityAccepted
    | ValidityRejected
    | ValidityInconclusive Text
    deriving (Eq, Show)

parseRejections :: ByteString -> Either String [DocumentedRejection]
parseRejections = error "TODO: parseRejections"

lastPassStarted :: Text -> Maybe Text
lastPassStarted = error "TODO: lastPassStarted"

validityVerdict :: StepResult -> ValidityVerdict
validityVerdict = error "TODO: validityVerdict"

classify :: [DocumentedRejection] -> RunRecord -> Classification
classify = error "TODO: classify"

isGap :: OutcomeClass -> Bool
isGap = error "TODO: isGap"
