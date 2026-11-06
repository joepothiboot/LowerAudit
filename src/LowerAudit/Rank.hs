module LowerAudit.Rank (
    Abstraction (..),
    Bound (..),
    Certificate,
    CertificateRefusal (..),
    Claim (..),
    Conditional,
    ConditionalRefusal (..),
    Empirical (..),
    LetterChange (..),
    Level (..),
    Proof (..),
    Proved,
    ProvedRefusal (..),
    Question (..),
    RankInput (..),
    RankProfile (..),
    RankReport (..),
    Stability (..),
    Subject (..),
    UnmetObligation (..),
    Verdict (..),
    certifiedBound,
    certifiedPattern,
    certifiedScope,
    certifyUnreachable,
    conditional,
    conditionalBound,
    empirical,
    highestLevel,
    levelName,
    proved,
    provedProof,
    rankReport,
    renderRankReport,
) where

import Data.Text (Text)
import LowerAudit.Automaton (Dfa)
import LowerAudit.Ledger (Ledger, LedgerError, ObligationId, Required, Scope)
import Numeric.Natural (Natural)

data Subject a o = Subject
    { subjectLetters :: [a]
    , subjectMaxRank :: Int
    , subjectValid :: [a] -> Bool
    , subjectOutcome :: [a] -> o
    }

data LetterChange a = LetterChange
    { changeLetters :: (a, a)
    , changePositions :: [Int]
    }
    deriving (Eq, Show)

data RankProfile a o = RankProfile
    { profileRank :: Int
    , profileOutcomes :: [o]
    , profileChanges :: [LetterChange a]
    }
    deriving (Eq, Show)

data Stability
    = StableFrom Int
    | NotStableBy Int
    deriving (Eq, Show)

data Empirical a o = Empirical
    { empiricalProfiles :: [RankProfile a o]
    , empiricalStability :: Stability
    }
    deriving (Eq, Show)

data Abstraction a o = forall q v. (Ord q, Ord v) => Abstraction (Dfa q a o) (Dfa v a Bool)

data Claim
    = Coverage
    | NeverApplies Text
    deriving (Eq, Show)

data Question o = Question Claim (o -> Bool)

data Verdict a
    = HoldsBelowBound
    | ViolatedAt [a]
    deriving (Eq, Show)

data Bound a = Bound
    { boundStates :: Int
    , boundValidityStates :: Int
    , boundN :: Int
    , boundCheckedTo :: Int
    , boundClaim :: Claim
    , boundVerdict :: Verdict a
    }
    deriving (Eq, Show)

newtype Conditional a = IssuedConditional (Bound a)
    deriving (Eq, Show)

data ConditionalRefusal a o
    = NoAbstraction
    | AlphabetDiffers [a] [a]
    | ValidityDisagrees [a] Bool
    | OutcomeDisagrees [a] o o
    | RanksShort Int Int Int
    deriving (Eq, Show)

data Proof a = Proof
    { proofBound :: Bound a
    , proofScope :: Scope
    , proofEvidence :: [(ObligationId, [Text])]
    }
    deriving (Eq, Show)

newtype Proved a = IssuedProof (Proof a)
    deriving (Eq, Show)

data UnmetObligation
    = MissingFromLedger ObligationId
    | StillOpen ObligationId
    | RefutedObligation ObligationId
    | NoEvidenceRecorded ObligationId
    | NotInDoc ObligationId
    deriving (Eq, Show)

data ProvedRefusal
    = NoConditionalBound
    | EvidenceUnusable LedgerError
    | NoLedgerEntry Scope
    | ObligationsUnmet [UnmetObligation]
    | AbstractionNotRecorded
    | AbstractionDiffers (Int, Int) (Int, Int)
    deriving (Eq, Show)

data Certificate = IssuedCertificate Text Scope Int
    deriving (Eq, Show)

data CertificateRefusal a
    = NotAboutAPattern
    | PatternApplies [a]
    deriving (Eq, Show)

data Level = EmpiricalLevel | ConditionalLevel | ProvedLevel
    deriving (Eq, Ord, Show, Enum, Bounded)

data RankInput a o = RankInput
    { inputSubject :: Subject a o
    , inputWindow :: Natural
    , inputQuestion :: Question o
    , inputAbstraction :: Maybe (Abstraction a o)
    , inputScope :: Scope
    , inputEvidence :: Either LedgerError (Required, Ledger)
    }

data RankReport a o = RankReport
    { reportEmpirical :: Empirical a o
    , reportConditional :: Either (ConditionalRefusal a o) (Conditional a)
    , reportProved :: Either ProvedRefusal (Proved a)
    }
    deriving (Eq, Show)

empirical :: (Eq a, Eq o) => Natural -> Subject a o -> Empirical a o
empirical = error "TODO: empirical"

conditional :: (Eq a, Eq o) => Question o -> Maybe (Abstraction a o) -> Subject a o -> Either (ConditionalRefusal a o) (Conditional a)
conditional = error "TODO: conditional"

conditionalBound :: Conditional a -> Bound a
conditionalBound = error "TODO: conditionalBound"

proved :: Scope -> Required -> Ledger -> Conditional a -> Either ProvedRefusal (Proved a)
proved = error "TODO: proved"

provedProof :: Proved a -> Proof a
provedProof = error "TODO: provedProof"

certifyUnreachable :: Proved a -> Either (CertificateRefusal a) Certificate
certifyUnreachable = error "TODO: certifyUnreachable"

certifiedPattern :: Certificate -> Text
certifiedPattern = error "TODO: certifiedPattern"

certifiedScope :: Certificate -> Scope
certifiedScope = error "TODO: certifiedScope"

certifiedBound :: Certificate -> Int
certifiedBound = error "TODO: certifiedBound"

rankReport :: (Eq a, Eq o) => RankInput a o -> RankReport a o
rankReport = error "TODO: rankReport"

highestLevel :: RankReport a o -> Level
highestLevel = error "TODO: highestLevel"

levelName :: Level -> Text
levelName = error "TODO: levelName"

renderRankReport :: (Show a, Show o) => RankReport a o -> Text
renderRankReport = error "TODO: renderRankReport"
