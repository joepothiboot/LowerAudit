module LowerAudit.Concretize (
    Representative (..),
    concretize,
    concretizeDim,
    representativeSize,
) where

import LowerAudit.Domain (AbstractCase, ConcreteCase, Dim, DimLetter)
import Numeric.Natural (Natural)

data Representative = Rep2 | Rep3 | Rep7
    deriving (Eq, Show, Enum, Bounded)

representativeSize :: Representative -> Natural
representativeSize = error "TODO: representativeSize"

concretizeDim :: Representative -> DimLetter -> Dim
concretizeDim = error "TODO: concretizeDim"

concretize :: Representative -> AbstractCase -> ConcreteCase
concretize = error "TODO: concretize"
