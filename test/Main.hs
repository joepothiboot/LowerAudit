module Main (main) where

import ConcretizeSpec qualified
import DomainSpec qualified
import LowerAudit (toolName)
import OracleSpec qualified
import Test.Tasty (defaultMain, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

main :: IO ()
main =
    defaultMain $
        testGroup
            "lower-audit"
            [ testCase "tool name" (toolName @?= "lower-audit")
            , DomainSpec.tests
            , OracleSpec.tests
            , ConcretizeSpec.tests
            ]
