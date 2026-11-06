{-# LANGUAGE OverloadedStrings #-}

module RankFixtures (
    Table (..),
    allWords,
    assumptions,
    docOf,
    entryJson,
    fromTable,
    genPair,
    genTable,
    ledgerOf,
    mustDfa,
    tableAccepts,
    tableSize,
    tableState,
    trackingStates,
) where

import Control.Monad (replicateM)
import Data.Aeson (Value, encode, object, (.=))
import Data.ByteString.Lazy (ByteString)
import Data.List (elemIndex)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import LowerAudit.Automaton (Dfa, DfaError, mkDfa)
import LowerAudit.Ledger (Scope (..))
import Test.Tasty.QuickCheck (Gen, chooseInt, elements, frequency, vectorOf)

data Table = Table
    { tableLetters :: String
    , tableStart :: Int
    , tableNext :: [[Int]]
    , tableAccept :: [Bool]
    }
    deriving (Show)

tableSize :: Table -> Int
tableSize = length . tableNext

tableStep :: Table -> Int -> Char -> Int
tableStep t q c = tableNext t !! q !! fromMaybe 0 (elemIndex c (tableLetters t))

tableState :: Table -> String -> Int
tableState t = foldl' (tableStep t) (tableStart t)

tableAccepts :: Table -> String -> Bool
tableAccepts t w = tableAccept t !! tableState t w

mustDfa :: (Show q, Show a) => Either (DfaError q a) (Dfa q a o) -> Dfa q a o
mustDfa = either (error . show) id

fromTable :: Table -> Dfa Int Char Bool
fromTable t =
    mustDfa (mkDfa (tableLetters t) [0 .. tableSize t - 1] (tableStart t) (tableStep t) (tableAccept t !!))

trackingStates :: Table -> Dfa Int Char Int
trackingStates t =
    mustDfa (mkDfa (tableLetters t) [0 .. tableSize t - 1] (tableStart t) (tableStep t) id)

allWords :: String -> Int -> [String]
allWords letters limit = [w | n <- [0 .. limit], w <- replicateM n letters]

genTable :: String -> Int -> Gen Table
genTable letters maxStates = do
    size <- chooseInt (1, maxStates)
    next <- vectorOf size (vectorOf (length letters) (chooseInt (0, size - 1)))
    accept <- vectorOf size (frequency [(1, pure True), (2, pure False)])
    start <- chooseInt (0, size - 1)
    pure (Table letters start next accept)

genPair :: [String] -> Int -> Gen (Table, Table)
genPair alphabets maxStates = do
    letters <- elements alphabets
    (,) <$> genTable letters maxStates <*> genTable letters maxStates

assumptions :: [Text]
assumptions = ["A1", "A2", "A3", "A4", "A5"]

docOf :: [Text] -> Text
docOf ids =
    T.unlines
        ( ["| | Assumption | Check |", "|---|---|---|"]
            ++ ["| " <> i <> " | stated | checked |" | i <- ids]
        )

entryJson :: Scope -> Maybe Int -> Maybe Int -> [(Text, Text, [Text])] -> Value
entryJson scope states validityStates obligations =
    object
        [ "target" .= scopeTarget scope
        , "conversion" .= scopeConversion scope
        , "domain" .= scopeDomain scope
        , "oracle" .= scopeOracle scope
        , "states" .= states
        , "validityStates" .= validityStates
        , "obligations"
            .= [ object ["id" .= i, "status" .= status, "evidence" .= evidence]
               | (i, status, evidence) <- obligations
               ]
        ]

ledgerOf :: [Value] -> ByteString
ledgerOf = encode
