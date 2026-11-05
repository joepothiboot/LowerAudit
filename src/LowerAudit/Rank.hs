module LowerAudit.Rank (
    Certificate,
    certifiedPattern,
) where

import Data.Text (Text)

data Certificate
    deriving (Eq, Show)

certifiedPattern :: Certificate -> Text
certifiedPattern = error "TODO: certifiedPattern"
