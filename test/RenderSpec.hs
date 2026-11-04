{-# LANGUAGE OverloadedStrings #-}

module RenderSpec (goldenCases, tests) where

import Data.ByteString.Lazy qualified as Lazy
import Data.Text.Encoding (encodeUtf8)
import LowerAudit.Domain (
    ConcreteCase (..),
    Dim (..),
    ElementType (..),
    Params (..),
    ReduceOp (..),
 )
import LowerAudit.Render (
    renderCase,
    renderElementType,
    renderOpName,
    renderTensorType,
 )
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Golden (goldenVsString)
import Test.Tasty.HUnit (testCase, (@?=))

goldenCases :: [(FilePath, ConcreteCase)]
goldenCases =
    [
        ( "o1-shape-prod-rank2.mlir"
        , ConcreteCase (Params Prod F32 False) [Size 2, Size 2] [Size 2] (Just [1])
        )
    ,
        ( "o3-letters-prod-dynamic.mlir"
        , ConcreteCase (Params Prod F32 False) [DynamicSize, DynamicSize] [DynamicSize] (Just [1])
        )
    ,
        ( "control-sum-rank2.mlir"
        , ConcreteCase (Params Sum F32 False) [Size 2, Size 2] [Size 2] (Just [1])
        )
    ,
        ( "prod-absent-rank0-bf16.mlir"
        , ConcreteCase (Params Prod BF16 False) [Size 128, Size 10, Size 4] [] Nothing
        )
    ,
        ( "prod-negative-keep-si32.mlir"
        , ConcreteCase
            (Params Prod SI32 True)
            [Size 7, DynamicSize, Size 1]
            [Size 1, DynamicSize, Size 1]
            (Just [-3, 2])
        )
    ]

tests :: TestTree
tests =
    testGroup
        "LowerAudit.Render"
        [ testGroup
            "names"
            [ testCase "element types, simple_prod.mlir and problem-statement §6" $
                map renderElementType [F32, BF16, SI32] @?= ["f32", "bf16", "si32"]
            , testCase "op names, simple_prod.mlir:13 and negative_invalid_dim_low.mlir:6" $
                map renderOpName [Prod, Sum] @?= ["ttir.prod", "ttir.sum"]
            ]
        , testGroup
            "renderTensorType"
            [ testCase "static" $
                renderTensorType F32 [Size 128, Size 10] @?= "tensor<128x10xf32>"
            , testCase "rank 0 has no separator, simple_prod.mlir:73" $
                renderTensorType BF16 [] @?= "tensor<bf16>"
            , testCase "dynamic is ?" $
                renderTensorType SI32 [DynamicSize, Size 3] @?= "tensor<?x3xsi32>"
            ]
        , testGroup
            "renderCase golden files"
            [ goldenVsString file ("test/golden/" <> file) $
                pure (Lazy.fromStrict (encodeUtf8 (renderCase c)))
            | (file, c) <- goldenCases
            ]
        ]
