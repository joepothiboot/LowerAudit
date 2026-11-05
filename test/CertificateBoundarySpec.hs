{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fdefer-type-errors -Wno-deferred-type-errors -Wno-deferred-out-of-scope-variables #-}

module CertificateBoundarySpec (tests) where

import Control.Exception (TypeError (..), evaluate, try)
import Data.Coerce (coerce)
import Data.List (isInfixOf)
import Data.Text (Text)
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
        ]
