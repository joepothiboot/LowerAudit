module Main (main) where

import ConcretizeSpec qualified
import DomainSpec qualified
import EnumerateSpec qualified
import LowerAudit (toolName)
import ManifestSpec qualified
import OracleSpec qualified
import RenderSpec qualified
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
            , EnumerateSpec.tests
            , RenderSpec.tests
            , ManifestSpec.tests
            ]
