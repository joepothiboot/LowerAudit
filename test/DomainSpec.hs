module DomainSpec (tests) where

import Data.Foldable (toList)
import Data.List.NonEmpty (NonEmpty (..))
import Generators (shrinkMeasure)
import LowerAudit.Domain (
    AbstractCase (..),
    DimLetter (..),
    DomainError (..),
    ElementType (..),
    Letter (..),
    Mark (..),
    Params (..),
    ReduceOp (..),
    dimArgOf,
    mkAbstractCase,
    rank,
 )
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (
    Arbitrary (..),
    Property,
    checkCoverage,
    cover,
    property,
    testProperty,
    (===),
 )

prodF32 :: Params
prodF32 = Params Prod F32 False

staticWord :: NonEmpty Mark -> AbstractCase
staticWord marks = AbstractCase prodF32 (Letter Static <$> marks)

threeLetters :: NonEmpty DimLetter
threeLetters = One :| [Static, Dynamic]

onThreeLetters :: Mark -> Mark -> Mark -> AbstractCase
onThreeLetters a b c =
    AbstractCase prodF32 (Letter One a :| [Letter Static b, Letter Dynamic c])

prop_coverage :: AbstractCase -> Property
prop_coverage c =
    checkCoverage
        . cover 5 (marked == 0) "dim_arg absent"
        . cover 3 (marked == 1 && r > 4) "one mark above rank 4"
        . cover 5 (marked > 1 && marked < r) "partial marks"
        . cover 5 (marked == r) "all marked"
        . cover 5 (r > 4) "rank above 4"
        $ property True
  where
    letters = toList (word c)
    r = length letters
    marked = length (filter ((/= Unmarked) . mark) letters)

tests :: TestTree
tests =
    testGroup
        "LowerAudit.Domain"
        [ testGroup
            "rank"
            [ testCase "rank-bound §4: rank is |w|" $
                rank (staticWord (Unmarked :| [Positive, Unmarked])) @?= 3
            , testProperty "rank is the word length" $
                \c -> rank c === length (word c)
            ]
        , testGroup
            "dimArgOf"
            [ testCase "problem-statement §6 marks and count rows: no marks is dim_arg absent, not []" $
                dimArgOf (staticWord (Unmarked :| [Unmarked])) @?= Nothing
            , testCase "positive mark at position p is p" $
                dimArgOf (staticWord (Unmarked :| [Positive, Unmarked])) @?= Just [1]
            , testCase "D-017, TTIROps.cpp:6714: negative mark at position p is p - r" $
                dimArgOf (staticWord (Unmarked :| [Negative, Unmarked])) @?= Just [-2]
            , testCase "negative mark at position 0 is -r, the low end of TTIROps.cpp:6708" $
                dimArgOf (staticWord (Negative :| [Unmarked, Positive])) @?= Just [-3, 2]
            , testCase "entries follow position order, not numeric order" $
                dimArgOf (staticWord (Positive :| [Unmarked, Negative])) @?= Just [0, -1]
            , testCase "all marked is a full list, distinct from absent" $
                dimArgOf (staticWord (Positive :| [Positive, Positive])) @?= Just [0, 1, 2]
            ]
        , testGroup
            "mkAbstractCase"
            [ testCase "TTIROps.td:2744: absent dim_arg gives no marks" $
                mkAbstractCase prodF32 threeLetters Nothing
                    @?= Right (onThreeLetters Unmarked Unmarked Unmarked)
            , testCase "a non-negative entry marks that position Positive" $
                mkAbstractCase prodF32 threeLetters (Just [1])
                    @?= Right (onThreeLetters Unmarked Positive Unmarked)
            , testCase "TTIROps.cpp:6714: a negative entry d marks position d + r Negative" $
                mkAbstractCase prodF32 threeLetters (Just [-1])
                    @?= Right (onThreeLetters Unmarked Unmarked Negative)
            , testCase "TTIROps.cpp:6708 both ends of the range: -r and r - 1" $
                mkAbstractCase prodF32 threeLetters (Just [-3, 2])
                    @?= Right (onThreeLetters Negative Unmarked Positive)
            , testCase "D-013: marks are a set, so list order does not matter" $
                mkAbstractCase prodF32 threeLetters (Just [2, 0])
                    @?= mkAbstractCase prodF32 threeLetters (Just [0, 2])
            , testCase "problem-statement §6 marks row: an empty list is out" $
                mkAbstractCase prodF32 threeLetters (Just []) @?= Left EmptyDimArg
            , testCase "TTIROps.cpp:6708: r is outside the range" $
                mkAbstractCase prodF32 threeLetters (Just [3]) @?= Left (DimNotInRank 3)
            , testCase "TTIROps.cpp:6708: -r - 1 is outside the range" $
                mkAbstractCase prodF32 threeLetters (Just [-4]) @?= Left (DimNotInRank (-4))
            , testCase "the first entry outside the range, in list order, is named" $
                mkAbstractCase prodF32 threeLetters (Just [9, -9]) @?= Left (DimNotInRank 9)
            , testCase "D-017: a repeated raw value stays out" $
                mkAbstractCase prodF32 threeLetters (Just [1, 1]) @?= Left (RepeatedPosition 1)
            , testCase "D-017, rank-bound §5: [d, d - r] names one position twice and stays out" $
                mkAbstractCase prodF32 threeLetters (Just [1, -2]) @?= Left (RepeatedPosition 1)
            , testCase "the first entry repeating an earlier one, in list order, is named" $
                mkAbstractCase prodF32 threeLetters (Just [0, 1, 1, 0, 2, 2]) @?= Left (RepeatedPosition 1)
            , testCase "an entry outside the range is reported before a repeat" $
                mkAbstractCase prodF32 threeLetters (Just [0, 0, 9]) @?= Left (DimNotInRank 9)
            , testProperty "generated cases satisfy the constructor's invariants: they rebuild from their parts" $
                \c -> mkAbstractCase (params c) (dimLetter <$> word c) (dimArgOf c) === Right c
            ]
        , testGroup
            "generators"
            [ testProperty "cases reach every mark shape and ranks above 4" prop_coverage
            , testProperty "every shrink candidate is strictly smaller" $
                \c -> all (\s -> shrinkMeasure s < shrinkMeasure c) (shrink c)
            ]
        ]
