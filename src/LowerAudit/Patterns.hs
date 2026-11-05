module LowerAudit.Patterns (
    Attempt (..),
    CaseReport (..),
    CaseRun (..),
    CertificateConflict (..),
    Considered (..),
    ConversionEnd (..),
    DomainEntry (..),
    DomainState (..),
    EndStatus (..),
    Event (..),
    PatternError (..),
    PatternState (..),
    RegisteredPattern (..),
    UnreachableInD,
    analyzeCase,
    analyzeDomain,
    attemptsOf,
    conversionEnd,
    markUnreachable,
    parseEvents,
    parseRegistered,
    unreachableCertificate,
) where

import Data.ByteString.Lazy (ByteString)
import Data.Text (Text)
import LowerAudit.Classify (Classification)
import LowerAudit.Manifest (CaseId)
import LowerAudit.Rank (Certificate)

data EndStatus = EndSuccess | EndFailure
    deriving (Eq, Show)

data Event
    = PatternBegin Text Text
    | MatchFailure Text
    | PatternEnd Text EndStatus
    deriving (Eq, Show)

data RegisteredPattern = RegisteredPattern
    { registeredName :: Text
    , registeredRoot :: Maybe Text
    }
    deriving (Eq, Show)

data PatternState
    = Registered
    | Attempted
    | MatchFailed
    | RolledBack
    | Applied
    | Survived
    deriving (Eq, Ord, Show, Enum, Bounded)

data ConversionEnd
    = KeptRewrites
    | UndidRewrites
    | NoVerdict
    | NoConversion
    deriving (Eq, Show)

data Attempt = Attempt
    { attemptPattern :: Text
    , attemptOp :: Text
    , attemptState :: PatternState
    , attemptReasons :: [Text]
    }
    deriving (Eq, Show)

data CaseRun = CaseRun
    { runCase :: CaseId
    , runClassification :: Classification
    , runEvents :: [Event]
    }
    deriving (Eq, Show)

data CaseReport = CaseReport
    { reportCase :: CaseId
    , reportAttempts :: [Attempt]
    , reportStates :: [(Text, PatternState)]
    }
    deriving (Eq, Show)

data Considered = Considered
    { consideredOp :: Text
    , consideredCases :: [CaseId]
    , consideredReasons :: [Text]
    }
    deriving (Eq, Show)

newtype UnreachableInD = FromCertificate {unreachableCertificate :: Certificate}
    deriving (Eq, Show)

data DomainState
    = ObservedSurvived
    | ObservedApplied
    | ObservedRolledBack
    | NotObserved [Considered]
    | Unreachable UnreachableInD
    deriving (Eq, Show)

data DomainEntry = DomainEntry
    { domainPattern :: RegisteredPattern
    , domainCounts :: [(PatternState, Int)]
    , domainState :: DomainState
    }
    deriving (Eq, Show)

data PatternError
    = MalformedLine Int
    | DuplicateRegistration Text
    | UnregisteredPattern Text
    | RootMismatch Text Text
    | UnmatchedEnd Text
    | ReasonOutsideAttempt Text
    | OpenAttempt Text
    | EventsWithoutConversion
    deriving (Eq, Show)

data CertificateConflict
    = CertificateForOtherPattern Text
    | CertificateContradicted DomainState
    deriving (Eq, Show)

parseEvents :: ByteString -> Either PatternError [Event]
parseEvents = error "TODO: parseEvents"

parseRegistered :: ByteString -> Either PatternError [RegisteredPattern]
parseRegistered = error "TODO: parseRegistered"

conversionEnd :: Classification -> ConversionEnd
conversionEnd = error "TODO: conversionEnd"

attemptsOf :: ConversionEnd -> [Event] -> Either PatternError [Attempt]
attemptsOf = error "TODO: attemptsOf"

analyzeCase :: [RegisteredPattern] -> CaseRun -> Either PatternError CaseReport
analyzeCase = error "TODO: analyzeCase"

analyzeDomain :: [RegisteredPattern] -> [CaseReport] -> [DomainEntry]
analyzeDomain = error "TODO: analyzeDomain"

markUnreachable :: Certificate -> DomainEntry -> Either CertificateConflict DomainEntry
markUnreachable = error "TODO: markUnreachable"
