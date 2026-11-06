{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fdefer-type-errors -Wno-deferred-type-errors -Wno-deferred-out-of-scope-variables #-}

module CertificateBoundarySpec (tests) where

import Control.Exception (TypeError (..), evaluate, try)
import Data.Coerce (coerce)
import Data.List (isInfixOf)
import Data.Text (Text)
import LowerAudit.Automaton
import LowerAudit.Ledger
import LowerAudit.Patterns
import LowerAudit.Rank
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, assertBool, assertFailure, testCase)

forgedCertificate :: Certificate
forgedCertificate = IssuedCertificate "p"

coercedCertificate :: Certificate
coercedCertificate = coerce ("p" :: Text)

forgedState :: UnreachableInD
forgedState = FromCertificate undefined

coercedState :: UnreachableInD
coercedState = coerce (undefined :: Certificate)

forgedConditional :: Conditional Char
forgedConditional = IssuedConditional undefined

coercedConditional :: Conditional Char
coercedConditional = coerce (undefined :: Bound Char)

forgedProof :: Proved Char
forgedProof = IssuedProof undefined

coercedProof :: Proved Char
coercedProof = coerce (undefined :: Proof Char)

forgedLedger :: Ledger
forgedLedger = IssuedLedger []

coercedLedger :: Ledger
coercedLedger = coerce ([] :: [LedgerEntry])

forgedRequired :: Required
forgedRequired = IssuedRequired []

coercedRequired :: Required
coercedRequired = coerce ([] :: [ObligationId])

forgedDfa :: Dfa Int Char Bool
forgedDfa = IssuedDfa

refused :: [String] -> a -> Assertion
refused expected value = do
    result <- try (evaluate value)
    case result of
        Left (TypeError message) -> assertBool message (all (`isInfixOf` message) expected)
        Right _ -> assertFailure "the value was built"

outOfScope :: String -> [String]
outOfScope constructor = ["Data constructor not in scope", constructor]

notCoercible :: [String]
notCoercible = ["Couldn't match representation of type"]

tests :: TestTree
tests =
    testGroup
        "the certificate boundary: each of these must not compile, and is deferred to here"
        [ testCase "no constructor builds a Certificate" $
            refused (outOfScope "IssuedCertificate") forgedCertificate
        , testCase "text does not coerce to a Certificate" $
            refused notCoercible coercedCertificate
        , testCase "no constructor builds UnreachableInD" $
            refused (outOfScope "FromCertificate") forgedState
        , testCase "UnreachableInD does not coerce from a Certificate" $
            refused notCoercible coercedState
        , testCase "no constructor builds a Conditional, so PROVED cannot start from a made-up bound" $
            refused (outOfScope "IssuedConditional") forgedConditional
        , testCase "a Bound does not coerce to a Conditional" $
            refused notCoercible coercedConditional
        , testCase "no constructor builds a Proved, so a Certificate has one route" $
            refused (outOfScope "IssuedProof") forgedProof
        , testCase "a Proof does not coerce to a Proved" $
            refused notCoercible coercedProof
        , testCase "no constructor builds a Ledger, so it comes through the parser" $
            refused (outOfScope "IssuedLedger") forgedLedger
        , testCase "entries do not coerce to a Ledger" $
            refused notCoercible coercedLedger
        , testCase "no constructor builds Required, so the obligations come from the document" $
            refused (outOfScope "IssuedRequired") forgedRequired
        , testCase "ids do not coerce to Required" $
            refused notCoercible coercedRequired
        , testCase "no constructor builds a Dfa, so k cannot be understated" $
            refused (outOfScope "IssuedDfa") forgedDfa
        ]
