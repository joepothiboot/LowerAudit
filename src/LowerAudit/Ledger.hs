module LowerAudit.Ledger (
    Ledger,
    LedgerEntry (..),
    LedgerError (..),
    Obligation (..),
    ObligationId (..),
    ObligationStatus (..),
    Required,
    Scope (..),
    ledgerEntries,
    obligationsInDoc,
    parseLedger,
    readEvidence,
    requiredIds,
) where

import Data.ByteString.Lazy (ByteString)
import Data.Text (Text)

newtype ObligationId = ObligationId Text
    deriving (Eq, Ord, Show)

data ObligationStatus = Open | Discharged | Refuted
    deriving (Eq, Show)

data Obligation = Obligation
    { obligationId :: ObligationId
    , obligationStatus :: ObligationStatus
    , obligationEvidence :: [Text]
    }
    deriving (Eq, Show)

data Scope = Scope
    { scopeTarget :: Text
    , scopeConversion :: Text
    , scopeDomain :: Text
    , scopeOracle :: Text
    }
    deriving (Eq, Show)

data LedgerEntry = LedgerEntry
    { entryScope :: Scope
    , entryStates :: Maybe Int
    , entryValidityStates :: Maybe Int
    , entryObligations :: [Obligation]
    }
    deriving (Eq, Show)

newtype Ledger = IssuedLedger [LedgerEntry]
    deriving (Eq, Show)

newtype Required = IssuedRequired [ObligationId]
    deriving (Eq, Show)

data LedgerError
    = NoObligationsInDoc
    | RepeatedInDoc ObligationId
    | MalformedLedger String
    | RepeatedScope Scope
    | RepeatedObligation Scope ObligationId
    | Unreadable FilePath
    deriving (Eq, Show)

obligationsInDoc :: Text -> Either LedgerError Required
obligationsInDoc = error "TODO: obligationsInDoc"

requiredIds :: Required -> [ObligationId]
requiredIds = error "TODO: requiredIds"

parseLedger :: ByteString -> Either LedgerError Ledger
parseLedger = error "TODO: parseLedger"

ledgerEntries :: Ledger -> [LedgerEntry]
ledgerEntries = error "TODO: ledgerEntries"

readEvidence :: FilePath -> FilePath -> IO (Either LedgerError (Required, Ledger))
readEvidence = error "TODO: readEvidence"
