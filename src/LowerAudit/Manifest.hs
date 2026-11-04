module LowerAudit.Manifest (
    CaseId (..),
    DomainSpec (..),
    Manifest (..),
    Pin (..),
    caseId,
    d0tt,
    domainHash,
    domainJson,
    manifestJson,
    mkManifest,
    targetPin,
) where

import Data.ByteString.Lazy (ByteString)
import Data.Text (Text)
import LowerAudit.Concretize (Representative)
import Numeric.Natural (Natural)

newtype CaseId = CaseId Text
    deriving (Eq, Show)

data Pin = Pin
    { ttMlirCommit :: Text
    , llvmCommit :: Text
    }
    deriving (Eq, Show)

data DomainSpec = DomainSpec
    { domainName :: Text
    , domainOps :: [Text]
    , domainElementTypes :: [Text]
    , domainDimLetters :: [Text]
    , domainMarks :: [Text]
    , domainKeepDim :: [Bool]
    , domainRankBound :: Int
    , domainRepresentative :: Natural
    }
    deriving (Eq, Show)

data Manifest = Manifest
    { manifestPin :: Pin
    , manifestGeneratorSha :: Text
    , manifestDomain :: DomainSpec
    , manifestDomainHash :: Text
    }
    deriving (Eq, Show)

caseId :: Text -> CaseId
caseId = error "TODO: caseId"

targetPin :: Pin
targetPin = error "TODO: targetPin"

d0tt :: Int -> Representative -> DomainSpec
d0tt = error "TODO: d0tt"

domainJson :: DomainSpec -> ByteString
domainJson = error "TODO: domainJson"

domainHash :: DomainSpec -> Text
domainHash = error "TODO: domainHash"

mkManifest :: Text -> DomainSpec -> Manifest
mkManifest = error "TODO: mkManifest"

manifestJson :: Manifest -> ByteString
manifestJson = error "TODO: manifestJson"
