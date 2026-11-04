module EnumerateSpec (tests) where

import Data.Foldable (toList)
import Data.List (find, isPrefixOf)
import Data.List.NonEmpty qualified as NonEmpty
import LowerAudit.Domain (
    AbstractCase (..),
    DimLetter (..),
    ElementType (..),
    Letter (..),
    Mark (..),
    Params (..),
    ReduceOp (..),
 )
import LowerAudit.Enumerate (enumerate)
import Test.Tasty (TestTree, localOption, mkTimeout, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

caseRank :: AbstractCase -> Int
caseRank = length . word

casesPerTypeAndOpAtRank :: Int -> Int
casesPerTypeAndOpAtRank r = 2 * 9 ^ r

casesPerTypeAndOpUpTo :: Int -> Int
casesPerTypeAndOpUpTo bound = sum (map casesPerTypeAndOpAtRank [1 .. bound])

typesTimesOps :: Int
typesTimesOps =
    length [minBound .. maxBound :: ElementType]
        * length [minBound .. maxBound :: ReduceOp]

shortlexKey :: AbstractCase -> (Int, [(Int, Int)], (Int, Int, Int))
shortlexKey (AbstractCase (Params o e k) w) =
    ( length w
    , [(fromEnum d, fromEnum m) | Letter d m <- toList w]
    , (fromEnum o, fromEnum e, fromEnum k)
    )

isForTypeAndOp :: ElementType -> ReduceOp -> AbstractCase -> Bool
isForTypeAndOp e o c = elementType (params c) == e && op (params c) == o

tests :: TestTree
tests =
    testGroup
        "LowerAudit.Enumerate"
        [ testGroup
            "problem-statement §6 count table, second row (D-017)"
            [ testCase "each rank 1-4 has 2·9^r cases per element type and op" $
                sequence_
                    [ length (filter ((== r) . caseRank) (enumerate 4))
                        @?= casesPerTypeAndOpAtRank r * typesTimesOps
                    | r <- [1 .. 4]
                    ]
            , testCase "ranks 1-4, every element type and op alone" $
                sequence_
                    [ length (filter (isForTypeAndOp e o) (enumerate 4)) @?= casesPerTypeAndOpUpTo 4
                    | e <- [minBound ..]
                    , o <- [minBound ..]
                    ]
            , testCase "ranks 1-6, one element type and op" $
                length (filter (isForTypeAndOp F32 Prod) (enumerate 6)) @?= casesPerTypeAndOpUpTo 6
            ]
        , testGroup
            "shortlex order, architecture §1"
            [ testCase "rank first, then letters, then params: strictly ascending, so no duplicates" $
                let keys = map shortlexKey (enumerate 3)
                 in assertBool "not strictly ascending" (and (zipWith (<) keys (drop 1 keys)))
            , testCase "the first case of each rank is shortlex-minimal" $
                sequence_
                    [ find ((== r) . caseRank) (enumerate 4)
                        @?= Just
                            ( AbstractCase
                                (Params Prod F32 False)
                                (NonEmpty.fromList (replicate r (Letter One Unmarked)))
                            )
                    | r <- [1 .. 4]
                    ]
            , testCase "enumeration up to R is a prefix of enumeration up to R + 1" $
                sequence_
                    [ assertBool (show bound) (enumerate bound `isPrefixOf` enumerate (bound + 1))
                    | bound <- [0 .. 3]
                    ]
            ]
        , testGroup
            "bounds"
            [ testCase "rank 0 is outside D0-tt: bound 0 is empty" $ enumerate 0 @?= []
            , testCase "a negative bound is empty" $ enumerate (-1) @?= []
            , localOption (mkTimeout 2000000)
                $ testCase "lazy: the start of a huge bound arrives without building it"
                $ length (take 10 (enumerate 1000000)) @?= 10
            ]
        ]
