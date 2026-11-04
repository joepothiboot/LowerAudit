module Main (main) where

import LowerAudit (toolName)
import Test.Tasty (defaultMain, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

main :: IO ()
main =
    defaultMain $
        testGroup
            "lower-audit"
            [testCase "tool name" (toolName @?= "lower-audit")]
