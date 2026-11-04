module LowerAudit.Domain (
    AbstractCase (..),
    ConcreteCase (..),
    Dim (..),
    DimLetter (..),
    DomainError (..),
    ElementType (..),
    Letter (..),
    Mark (..),
    Params (..),
    ReduceOp (..),
    dimArgOf,
    mkAbstractCase,
    rank,
) where

import Data.List.NonEmpty (NonEmpty)
import Numeric.Natural (Natural)

data ReduceOp = Prod | Sum
    deriving (Eq, Show, Enum, Bounded)

data ElementType = F32 | BF16 | SI32
    deriving (Eq, Show, Enum, Bounded)

data DimLetter = One | Static | Dynamic
    deriving (Eq, Show, Enum, Bounded)

data Mark = Unmarked | Positive | Negative
    deriving (Eq, Show, Enum, Bounded)

data Letter = Letter
    { dimLetter :: DimLetter
    , mark :: Mark
    }
    deriving (Eq, Show)

data Params = Params
    { op :: ReduceOp
    , elementType :: ElementType
    , keepDim :: Bool
    }
    deriving (Eq, Show)

data AbstractCase = AbstractCase
    { params :: Params
    , word :: NonEmpty Letter
    }
    deriving (Eq, Show)

data Dim = Size Natural | DynamicSize
    deriving (Eq, Show)

data ConcreteCase = ConcreteCase
    { concreteParams :: Params
    , inputShape :: [Dim]
    , resultShape :: [Dim]
    , dimArg :: Maybe [Int]
    }
    deriving (Eq, Show)

data DomainError
    = EmptyDimArg
    | DimNotInRank Int
    | RepeatedPosition Int
    deriving (Eq, Show)

rank :: AbstractCase -> Int
rank = error "TODO: rank"

dimArgOf :: AbstractCase -> Maybe [Int]
dimArgOf = error "TODO: dimArgOf"

mkAbstractCase :: Params -> NonEmpty DimLetter -> Maybe [Int] -> Either DomainError AbstractCase
mkAbstractCase = error "TODO: mkAbstractCase"
