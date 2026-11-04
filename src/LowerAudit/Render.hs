module LowerAudit.Render (
    renderCase,
    renderElementType,
    renderOpName,
    renderTensorType,
) where

import Data.Text (Text)
import LowerAudit.Domain (ConcreteCase, Dim, ElementType, ReduceOp)

renderElementType :: ElementType -> Text
renderElementType = error "TODO: renderElementType"

renderOpName :: ReduceOp -> Text
renderOpName = error "TODO: renderOpName"

renderTensorType :: ElementType -> [Dim] -> Text
renderTensorType = error "TODO: renderTensorType"

renderCase :: ConcreteCase -> Text
renderCase = error "TODO: renderCase"
