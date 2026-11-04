{-# OPTIONS_GHC -Wno-orphans #-}

module Generators (shrinkMeasure) where

import Data.Foldable (toList)
import Data.List.NonEmpty (nonEmpty)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Maybe (mapMaybe)
import LowerAudit.Concretize (Representative)
import LowerAudit.Domain (
    AbstractCase (..),
    DimLetter,
    ElementType,
    Letter (..),
    Mark (..),
    Params (..),
    ReduceOp,
 )
import Test.Tasty.QuickCheck (
    Arbitrary (..),
    Gen,
    arbitraryBoundedEnum,
    chooseInt,
    elements,
    oneof,
    shrinkList,
    sized,
    vectorOf,
 )

shrinkEnum :: (Bounded a, Enum a, Eq a) => a -> [a]
shrinkEnum x = takeWhile (/= x) [minBound ..]

instance Arbitrary ReduceOp where
    arbitrary = arbitraryBoundedEnum
    shrink = shrinkEnum

instance Arbitrary ElementType where
    arbitrary = arbitraryBoundedEnum
    shrink = shrinkEnum

instance Arbitrary DimLetter where
    arbitrary = arbitraryBoundedEnum
    shrink = shrinkEnum

instance Arbitrary Mark where
    arbitrary = arbitraryBoundedEnum
    shrink = shrinkEnum

instance Arbitrary Representative where
    arbitrary = arbitraryBoundedEnum
    shrink = shrinkEnum

instance Arbitrary Letter where
    arbitrary = Letter <$> arbitrary <*> arbitrary
    shrink (Letter d m) =
        [Letter d' m | d' <- shrink d]
            ++ [Letter d m' | m' <- shrink m]

instance Arbitrary Params where
    arbitrary = Params <$> arbitrary <*> arbitrary <*> arbitrary
    shrink (Params o e k) =
        [Params o' e k | o' <- shrink o]
            ++ [Params o e' k | e' <- shrink e]
            ++ [Params o e k' | k' <- shrink k]

genMarks :: Int -> Gen [Mark]
genMarks r =
    oneof
        [ pure (replicate r Unmarked)
        , vectorOf r (elements [Positive, Negative])
        , vectorOf r arbitrary
        , do
            p <- chooseInt (0, r - 1)
            m <- elements [Positive, Negative]
            pure (replicate p Unmarked ++ m : replicate (r - 1 - p) Unmarked)
        ]

instance Arbitrary AbstractCase where
    arbitrary = do
        r <- sized (\n -> chooseInt (1, 1 + n `div` 10))
        letters <- vectorOf r arbitrary
        marks <- genMarks r
        p <- arbitrary
        pure (AbstractCase p (NonEmpty.fromList (zipWith Letter letters marks)))
    shrink (AbstractCase p w) =
        [AbstractCase p' w | p' <- shrink p]
            ++ [AbstractCase p w' | w' <- mapMaybe nonEmpty (shrinkList shrink (toList w))]

shrinkMeasure :: AbstractCase -> Int
shrinkMeasure (AbstractCase (Params o e k) w) =
    fromEnum o + fromEnum e + fromEnum k + sum (letterWeight <$> w)
  where
    letterWeight (Letter d m) = 1 + fromEnum d + fromEnum m
