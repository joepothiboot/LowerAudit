module LowerAudit.Oracle (
    Violation (..),
    vTtir,
) where

import LowerAudit.Domain (ConcreteCase, Dim)

data Violation
    = DimOutOfRange Int
    | DimsNotUnique
    | ResultShapeMismatch [Dim] [Dim]
    deriving (Eq, Show)

vTtir :: ConcreteCase -> Either Violation ()
vTtir = error "TODO: vTtir"
