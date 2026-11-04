module OracleSpec (tests) where

import LowerAudit.Domain (ConcreteCase (..), Dim (..), Params (..))
import LowerAudit.Oracle (Violation (..), vTtir)
import Numeric.Natural (Natural)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

sizes :: [Natural] -> [Dim]
sizes = map Size

verdict :: String -> [Dim] -> Maybe [Int] -> Bool -> [Dim] -> Either Violation () -> TestTree
verdict name input dims keep result expected =
    testCase name $
        sequence_
            [ vTtir (ConcreteCase (Params o e keep) input result dims) @?= expected
            | o <- [minBound ..]
            , e <- [minBound ..]
            ]

accepted :: String -> [Dim] -> Maybe [Int] -> Bool -> [Dim] -> TestTree
accepted name input dims keep result = verdict name input dims keep result (Right ())

mismatch :: String -> [Dim] -> Maybe [Int] -> Bool -> [Dim] -> [Dim] -> TestTree
mismatch name input dims keep result expectedShape =
    verdict name input dims keep result (Left (ResultShapeMismatch expectedShape result))

tests :: TestTree
tests =
    testGroup
        "LowerAudit.Oracle"
        [ testGroup
            "accepted lit shapes, TTIROps.cpp:6694-6742"
            [ accepted "simple_prod.mlir:13" (sizes [128, 10, 32, 4]) (Just [1]) False (sizes [128, 32, 4])
            , accepted "simple_prod.mlir:25" (sizes [128, 10, 32, 4]) (Just [0, 1, 2, 3]) False []
            , accepted "simple_prod.mlir:37" (sizes [128, 10, 4]) (Just [1]) False (sizes [128, 4])
            , accepted "simple_prod.mlir:49" (sizes [128, 10, 4]) (Just [0, 1, 2]) False []
            , accepted "simple_prod.mlir:61" (sizes [128]) (Just [0]) False []
            , accepted "simple_prod.mlir:73" (sizes [128, 10, 4]) Nothing False []
            ]
        , testGroup
            "no rank cap, problem-statement §2"
            [ accepted "F7, negative_reduce_prod_op.mlir:6: rank 5 fails ttnn.prod, not V_ttir" (sizes [128, 10, 32, 4, 1]) (Just [0]) False (sizes [10, 32, 4, 1])
            , accepted "rank 9, dim_arg absent" (sizes (replicate 9 2)) Nothing False []
            ]
        , testGroup
            "dim range, TTIROps.cpp:6708"
            [ verdict "F2, negative_invalid_dim_low.mlir:6: -3 at rank 2" (sizes [128, 10]) (Just [-3]) False (sizes [128]) (Left (DimOutOfRange (-3)))
            , verdict "F3, negative_invalid_dim_high.mlir:6: 2 at rank 2" (sizes [128, 10]) (Just [2]) False (sizes [128]) (Left (DimOutOfRange 2))
            , accepted "low end: -r is in range" (sizes [128, 10]) (Just [-2]) False (sizes [10])
            , accepted "high end: r - 1 is in range" (sizes [128, 10]) (Just [1]) False (sizes [128])
            , verdict "the first entry out of range, in list order, is named" (sizes [128, 10]) (Just [5, -5]) False [] (Left (DimOutOfRange 5))
            ]
        , testGroup
            "negative dims, TTIROps.cpp:6714"
            [ accepted "d names position d + r" (sizes [128, 10]) (Just [-1]) False (sizes [128])
            , mismatch "not position -d" (sizes [128, 10]) (Just [-1]) False (sizes [10]) (sizes [128])
            ]
        , testGroup
            "uniqueness on raw values, TTIROps.cpp:6713,6717"
            [ verdict "F4, negative_repeating_dims.mlir:6" (sizes [128, 10, 32, 4]) (Just [1, 2, 3, 2]) False (sizes [128]) (Left DimsNotUnique)
            , accepted "X1, rank-bound §5: [d, d - r] has distinct raw values, so it passes" (sizes [128, 10]) (Just [1, -1]) False (sizes [128])
            , verdict "range comes first: :6708 returns inside the loop, :6717 runs after it" (sizes [128, 10]) (Just [1, 1, 5]) False (sizes [128]) (Left (DimOutOfRange 5))
            , verdict "uniqueness comes before the shape: :6717 returns before :6733" (sizes [128, 10]) (Just [1, 1]) False (sizes [128, 10]) (Left DimsNotUnique)
            ]
        , testGroup
            "result shape, TTIROps.cpp:6723-6739"
            [ mismatch "F5, negative_shape_mismatch.mlir:7: keep_dim false drops the dim" (sizes [128, 16, 32]) (Just [2]) False (sizes [128, 16, 1]) (sizes [128, 16])
            , mismatch "F5, negative_shape_mismatch.mlir:16: keep_dim true keeps a 1" (sizes [128, 16, 32]) (Just [2]) True (sizes [128, 16]) (sizes [128, 16, 1])
            , mismatch "F5, negative_shape_mismatch.mlir:25: absent, keep_dim true is all 1s" (sizes [128, 16, 32]) Nothing True (sizes [128, 16, 1]) (sizes [1, 1, 1])
            , mismatch "F5, negative_shape_mismatch.mlir:34: absent, keep_dim false is rank 0" (sizes [128, 16, 32]) Nothing False (sizes [128, 16, 1]) []
            , mismatch "F6, like O7: tensor<2xf32> -> tensor<2x2x1xf32>, dim 0" (sizes [2]) (Just [0]) False (sizes [2, 2, 1]) []
            , mismatch "same length, wrong size" (sizes [128, 16, 32]) (Just [2]) True (sizes [128, 16, 7]) (sizes [128, 16, 1])
            ]
        , testGroup
            "dynamic dims, TTIROps.cpp:6726,6728,6733"
            [ accepted ":6726: an unreduced ? stays ?" [DynamicSize, Size 3] (Just [1]) False [DynamicSize]
            , mismatch ":6733: a static size does not match an expected ?" [DynamicSize, Size 3] (Just [1]) False (sizes [2]) [DynamicSize]
            , accepted ":6728: a reduced ? with keep_dim is 1" [DynamicSize, Size 3] (Just [0]) True (sizes [1, 3])
            , mismatch ":6733: ? does not match an expected 1" [DynamicSize, Size 3] (Just [0]) True [DynamicSize, Size 3] (sizes [1, 3])
            ]
        , testGroup
            "absent and empty dim_arg are opposites, TTIROps.cpp:6702-6703,6723-6730"
            [ accepted "absent reduces every position" (sizes [2, 3]) Nothing False []
            , accepted "[] reduces no position" (sizes [2, 3]) (Just []) False (sizes [2, 3])
            , mismatch "[] is not reduce-all" (sizes [2, 3]) (Just []) False [] (sizes [2, 3])
            ]
        , testGroup
            "rank 0 input, outside D0-tt but judged by the same rules, TTIROps.cpp:6708"
            [ accepted "absent, rank 0 result" [] Nothing False []
            , verdict "no entry is in range" [] (Just [0]) False [] (Left (DimOutOfRange 0))
            ]
        ]
