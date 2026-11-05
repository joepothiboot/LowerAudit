module Main (main) where

import ClassifySpec qualified
import ConcretizeSpec qualified
import DomainSpec qualified
import EnumerateSpec qualified
import ExecutableOracleSpec qualified
import LowerAudit (toolName)
import ManifestSpec qualified
import OracleSpec qualified
import ProbeSpec qualified
import RenderSpec qualified
import ReportSpec qualified
import RunSpec qualified
import SliceSpec qualified
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
            , RunSpec.tests
            , ClassifySpec.tests
            , ProbeSpec.tests
            , ExecutableOracleSpec.tests
            , ReportSpec.tests
            , SliceSpec.tests
            ]
