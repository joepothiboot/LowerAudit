module ConcretizeSpec (tests) where

import Data.Foldable (toList)
import Data.List.NonEmpty (NonEmpty (..))
import Generators ()
import LowerAudit.Concretize (
    Representative (..),
    concretize,
    concretizeDim,
    representativeSize,
 )
import LowerAudit.Domain (
    AbstractCase (..),
    ConcreteCase (..),
    Dim (..),
    DimLetter (..),
    ElementType (..),
    Letter (..),
    Mark (..),
    Params (..),
    ReduceOp (..),
 )
import LowerAudit.Oracle (vTtir)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (
    Property,
    conjoin,
    counterexample,
    property,
    testProperty,
    (===),
 )

keeping :: Params
keeping = Params Prod F32 True

dropping :: Params
dropping = Params Prod F32 False

prop_marksAreAtMarkedPositions :: Representative -> AbstractCase -> Property
prop_marksAreAtMarkedPositions rep c =
    fmap (map entry) (dimArg (concretize rep c)) === expected
  where
    letters = toList (word c)
    r = length letters
    entry d = if d < 0 then (d + r, Negative) else (d, Positive)
    marked = [(p, mark l) | (p, l) <- zip [0 ..] letters, mark l /= Unmarked]
    expected = if null marked then Nothing else Just marked

prop_staticIsAtLeastTwo :: Representative -> AbstractCase -> Property
prop_staticIsAtLeastTwo rep c =
    conjoin (zipWith check (toList (word c)) (inputShape (concretize rep c)))
  where
    check (Letter Static _) (Size n) = counterexample (show n) (property (n >= 2))
    check (Letter Static _) dim = counterexample (show dim) (property False)
    check _ _ = property True

tests :: TestTree
tests =
    testGroup
        "LowerAudit.Concretize"
        [ testGroup
            "representativeSize"
            [ testCase "problem-statement §6 dim letter row: 2, 3 and 7" $
                map representativeSize [Rep2, Rep3, Rep7] @?= [2, 3, 7]
            , testCase "rank-bound §4: every representative is a size >= 2" $
                all ((>= 2) . representativeSize) [minBound .. maxBound] @?= True
            ]
        , testGroup
            "concretizeDim"
            [ testCase "rank-bound §4: 1 -> 1, under every representative" $
                map (`concretizeDim` One) [Rep2, Rep3, Rep7] @?= [Size 1, Size 1, Size 1]
            , testCase "rank-bound §4: s -> the chosen representative" $
                map (`concretizeDim` Static) [Rep2, Rep3, Rep7] @?= [Size 2, Size 3, Size 7]
            , testCase "rank-bound §4: ? -> dynamic, under every representative" $
                map (`concretizeDim` Dynamic) [Rep2, Rep3, Rep7] @?= [DynamicSize, DynamicSize, DynamicSize]
            ]
        , testGroup
            "concretize examples"
            [ testCase "architecture §3 step 1: rank 3, one positive dim, static, keep_dim false" $
                concretize Rep2 (AbstractCase dropping (Letter Static Unmarked :| [Letter Static Positive, Letter Static Unmarked]))
                    @?= ConcreteCase dropping [Size 2, Size 2, Size 2] [Size 2, Size 2] (Just [1])
            , testCase "negative mark on ?, keep_dim true: the reduced position is 1" $
                concretize Rep7 (AbstractCase keeping (Letter Static Unmarked :| [Letter Dynamic Negative, Letter One Unmarked]))
                    @?= ConcreteCase keeping [Size 7, DynamicSize, Size 1] [Size 7, Size 1, Size 1] (Just [-2])
            , testCase "no marks, keep_dim false: dim_arg absent, rank 0 result" $
                concretize Rep3 (AbstractCase dropping (Letter Static Unmarked :| [Letter Dynamic Unmarked]))
                    @?= ConcreteCase dropping [Size 3, DynamicSize] [] Nothing
            , testCase "no marks, keep_dim true: dim_arg absent, every position is 1" $
                concretize Rep3 (AbstractCase keeping (Letter Static Unmarked :| [Letter Dynamic Unmarked]))
                    @?= ConcreteCase keeping [Size 3, DynamicSize] [Size 1, Size 1] Nothing
            , testCase "all marked, keep_dim false: a full list, rank 0 result" $
                concretize Rep2 (AbstractCase dropping (Letter One Positive :| [Letter Dynamic Negative]))
                    @?= ConcreteCase dropping [Size 1, DynamicSize] [] (Just [0, -1])
            , testCase "partial marks: an unmarked ? stays in the result" $
                concretize Rep2 (AbstractCase dropping (Letter Dynamic Unmarked :| [Letter Static Positive, Letter One Negative]))
                    @?= ConcreteCase dropping [DynamicSize, Size 2, Size 1] [DynamicSize] (Just [1, -1])
            ]
        , testGroup
            "concretize properties"
            [ testProperty "preserves rank" $
                \rep c -> length (inputShape (concretize rep c)) === length (word c)
            , testProperty "applies concretizeDim at each position" $
                \rep c ->
                    inputShape (concretize rep c)
                        === map (concretizeDim rep . dimLetter) (toList (word c))
            , testProperty "leaves op, element type and keep_dim unchanged" $
                \rep c -> concreteParams (concretize rep c) === params c
            , testProperty "dim_arg names exactly the marked positions, with each mark's sign" prop_marksAreAtMarkedPositions
            , testProperty "every representative maps s to a size >= 2" prop_staticIsAtLeastTwo
            , testProperty "architecture §2 row A: every generated case passes V_ttir under every representative" $
                \c -> conjoin [vTtir (concretize rep c) === Right () | rep <- [minBound .. maxBound]]
            ]
        ]
