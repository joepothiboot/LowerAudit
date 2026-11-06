{-# LANGUAGE OverloadedStrings #-}

module LedgerSpec (tests) where

import Data.Aeson (Key, object, (.=))
import Data.Aeson.Types (Pair)
import Data.Bifunctor (bimap)
import Data.ByteString.Lazy (ByteString)
import Data.ByteString.Lazy qualified as ByteString
import Data.Text (Text)
import Data.Text.Encoding (decodeUtf8)
import Data.Text.IO qualified as Text
import LowerAudit.Ledger (
    LedgerEntry (..),
    LedgerError (..),
    Obligation (..),
    ObligationId (..),
    ObligationStatus (..),
    Required,
    Scope (..),
    ledgerEntries,
    obligationsInDoc,
    parseLedger,
    readEvidence,
    requiredIds,
 )
import RankFixtures (assumptions, docOf, entryJson, ledgerOf)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, assertFailure, testCase, (@?=))

rankBoundDoc :: FilePath
rankBoundDoc = "docs/theory/rank-bound.md"

committedLedger :: FilePath
committedLedger = "data/rank-ledger-tt-mlir-f9dc1b3e5101.json"

scope :: Scope
scope = Scope "target" "conversion" "domain" "oracle"

otherScope :: Scope
otherScope = scope{scopeOracle = "another oracle"}

committedScope :: Text -> Scope
committedScope conversion = Scope "tt-mlir f9dc1b3e5101" conversion "D0-tt" "V_ttir"

idsOf :: Required -> [Text]
idsOf required = [i | ObligationId i <- requiredIds required]

docIds :: Text -> Either LedgerError [Text]
docIds = fmap idsOf . obligationsInDoc

parsedEntries :: ByteString -> Either LedgerError [LedgerEntry]
parsedEntries = fmap ledgerEntries . parseLedger

malformed :: ByteString -> Assertion
malformed bytes =
    case parseLedger bytes of
        Left (MalformedLedger _) -> pure ()
        other -> assertFailure ("expected MalformedLedger, got " ++ show other)

obligationOf :: Text -> ObligationStatus -> [Text] -> Obligation
obligationOf = Obligation . ObligationId

oneEntry :: [(Text, Text, [Text])] -> ByteString
oneEntry obligations = ledgerOf [entryJson scope (Just 2) (Just 1) obligations]

wellFormed :: [Pair]
wellFormed =
    [ "target" .= ("t" :: Text)
    , "conversion" .= ("c" :: Text)
    , "domain" .= ("d" :: Text)
    , "oracle" .= ("o" :: Text)
    , "states" .= (2 :: Int)
    , "validityStates" .= (1 :: Int)
    , "obligations" .= ([] :: [Text])
    ]

without :: Key -> ByteString
without field = ledgerOf [object (filter ((/= field) . fst) wellFormed)]

replacing :: Pair -> ByteString
replacing pair = ledgerOf [object (pair : filter ((/= fst pair) . fst) wellFormed)]

oneObligation :: [Pair] -> ByteString
oneObligation fields = replacing ("obligations" .= [object fields])

evidenceFrom :: FilePath -> FilePath -> IO (Either LedgerError ([Text], [LedgerEntry]))
evidenceFrom doc ledger = do
    result <- readEvidence doc ledger
    pure (fmap (bimap idsOf ledgerEntries) result)

tests :: TestTree
tests =
    testGroup
        "LowerAudit.Ledger"
        [ testGroup
            "obligationsInDoc"
            [ testCase "rows whose first cell is A and digits, in document order" $
                docIds (docOf ["A2", "A1", "A10"]) @?= Right ["A2", "A1", "A10"]
            , testCase "other tables' rows are not obligations" $
                docIds
                    "| S1 | a source condition | holds |\n\
                    \| A1–A5 for the closure | open |\n\
                    \| A3′ | a variant | x |\n\
                    \| A | no number | x |\n\
                    \| A1 | an assumption | a check |\n"
                    @?= Right ["A1"]
            , testCase "prose that names an assumption is not a row" $
                docIds "Assume A1–A5 and let N = k.\n| A1 | stated | checked |\n" @?= Right ["A1"]
            , testCase "prose with pipes in it is not a row either" $
                docIds "See the row | A2 | for more.\n| A1 | stated | checked |\n" @?= Right ["A1"]
            , testCase "a document with no obligation is refused, so PROVED cannot pass vacuously" $
                docIds "# Rank bound\nNothing to see.\n" @?= Left NoObligationsInDoc
            , testCase "an empty document is refused" $
                docIds "" @?= Left NoObligationsInDoc
            , testCase "a repeated row is refused" $
                docIds (docOf ["A1", "A2", "A1"]) @?= Left (RepeatedInDoc (ObligationId "A1"))
            , testCase "rank-bound.md holds exactly A1 to A5, and this test fails if that changes" $ do
                bytes <- ByteString.readFile rankBoundDoc
                docIds (decodeUtf8 (ByteString.toStrict bytes)) @?= Right assumptions
            ]
        , testGroup
            "parseLedger"
            [ testCase "one entry, as written" $
                parsedEntries
                    (oneEntry [("A1", "discharged", ["a citation"]), ("A2", "open", []), ("A3", "refuted", ["a witness"])])
                    @?= Right
                        [ LedgerEntry
                            scope
                            (Just 2)
                            (Just 1)
                            [ obligationOf "A1" Discharged ["a citation"]
                            , obligationOf "A2" Open []
                            , obligationOf "A3" Refuted ["a witness"]
                            ]
                        ]
            , testCase "an empty list is a ledger with no entries" $
                parsedEntries "[]" @?= Right []
            , testCase "a null k or k_V is not known yet" $
                fmap
                    (map (\e -> (entryStates e, entryValidityStates e)))
                    (parsedEntries (ledgerOf [entryJson scope Nothing Nothing []]))
                    @?= Right [(Nothing, Nothing)]
            , testCase "an unknown status is malformed, never taken as discharged" $
                malformed (oneEntry [("A1", "proved", ["a citation"])])
            , testCase "a repeated obligation is refused, since one of its lines would be ignored" $
                parseLedger (oneEntry [("A1", "open", []), ("A1", "discharged", ["a citation"])])
                    @?= Left (RepeatedObligation scope (ObligationId "A1"))
            , testCase "a repeated scope is refused" $
                parseLedger (ledgerOf [entryJson scope (Just 2) (Just 1) [], entryJson scope (Just 3) (Just 1) []])
                    @?= Left (RepeatedScope scope)
            , testCase "the same obligation in two scopes is fine" $
                fmap
                    length
                    ( parsedEntries
                        ( ledgerOf
                            [ entryJson scope (Just 2) (Just 1) [("A1", "open", [])]
                            , entryJson otherScope (Just 2) (Just 1) [("A1", "open", [])]
                            ]
                        )
                    )
                    @?= Right 2
            , testCase "bytes that are not JSON are malformed" $
                malformed "not json"
            , testCase "a truncated file is malformed" $
                malformed (ByteString.take 20 (oneEntry [("A1", "open", [])]))
            , testCase "a top level that is not a list is malformed" $
                malformed "{}"
            , testCase "an obligation without evidence is malformed" $
                malformed (oneObligation ["id" .= ("A1" :: Text), "status" .= ("open" :: Text)])
            , testCase "an obligation without an id is malformed" $
                malformed (oneObligation ["status" .= ("open" :: Text), "evidence" .= ([] :: [Text])])
            , testCase "an obligation without a status is malformed" $
                malformed (oneObligation ["id" .= ("A1" :: Text), "evidence" .= ([] :: [Text])])
            , testCase "evidence that is not a list is malformed" $
                malformed (oneObligation ["id" .= ("A1" :: Text), "status" .= ("open" :: Text), "evidence" .= ("x" :: Text)])
            , testCase "a k that is not a number is malformed" $
                malformed (replacing ("states" .= ("x" :: Text)))
            , testCase "an absent k is malformed: unknown is written null" $
                malformed (without "states")
            , testCase "an absent k_V is malformed: unknown is written null" $
                malformed (without "validityStates")
            , testCase "an entry with no obligations field is malformed" $
                malformed (without "obligations")
            , testCase "an entry with no target is malformed" $
                malformed (without "target")
            , testCase "an entry with no conversion is malformed" $
                malformed (without "conversion")
            , testCase "an entry with no domain is malformed" $
                malformed (without "domain")
            , testCase "an entry with no oracle is malformed" $
                malformed (without "oracle")
            ]
        , testGroup
            "readEvidence"
            [ testCase "reads the document and the ledger" $
                withSystemTempDirectory "ledger" $ \dir -> do
                    Text.writeFile (dir </> "doc.md") (docOf ["A1"])
                    ByteString.writeFile (dir </> "ledger.json") (oneEntry [("A1", "open", [])])
                    result <- evidenceFrom (dir </> "doc.md") (dir </> "ledger.json")
                    result
                        @?= Right (["A1"], [LedgerEntry scope (Just 2) (Just 1) [obligationOf "A1" Open []]])
            , testCase "a missing document is Unreadable, not an exception" $
                withSystemTempDirectory "ledger" $ \dir -> do
                    ByteString.writeFile (dir </> "ledger.json") "[]"
                    result <- evidenceFrom (dir </> "absent.md") (dir </> "ledger.json")
                    result @?= Left (Unreadable (dir </> "absent.md"))
            , testCase "a missing ledger is Unreadable, not an exception" $
                withSystemTempDirectory "ledger" $ \dir -> do
                    Text.writeFile (dir </> "doc.md") (docOf ["A1"])
                    result <- evidenceFrom (dir </> "doc.md") (dir </> "absent.json")
                    result @?= Left (Unreadable (dir </> "absent.json"))
            , testCase "with both missing, the document is named" $
                withSystemTempDirectory "ledger" $ \dir -> do
                    result <- evidenceFrom (dir </> "absent.md") (dir </> "absent.json")
                    result @?= Left (Unreadable (dir </> "absent.md"))
            , testCase "a document that is not UTF-8 is Unreadable, not an exception" $
                withSystemTempDirectory "ledger" $ \dir -> do
                    ByteString.writeFile (dir </> "doc.md") (ByteString.pack [0xFF, 0xFE, 0x41])
                    ByteString.writeFile (dir </> "ledger.json") "[]"
                    result <- evidenceFrom (dir </> "doc.md") (dir </> "ledger.json")
                    result @?= Left (Unreadable (dir </> "doc.md"))
            , testCase "rank-bound.md is not ASCII, and reads as UTF-8" $ do
                result <- evidenceFrom rankBoundDoc committedLedger
                fmap fst result @?= Right assumptions
            , testCase "the document's errors pass through" $
                withSystemTempDirectory "ledger" $ \dir -> do
                    Text.writeFile (dir </> "doc.md") "no table here\n"
                    ByteString.writeFile (dir </> "ledger.json") "[]"
                    result <- evidenceFrom (dir </> "doc.md") (dir </> "ledger.json")
                    result @?= Left NoObligationsInDoc
            , testCase "the ledger's errors pass through" $
                withSystemTempDirectory "ledger" $ \dir -> do
                    Text.writeFile (dir </> "doc.md") (docOf ["A1"])
                    ByteString.writeFile (dir </> "ledger.json") (oneEntry [("A1", "open", []), ("A1", "open", [])])
                    result <- evidenceFrom (dir </> "doc.md") (dir </> "ledger.json")
                    result @?= Left (RepeatedObligation scope (ObligationId "A1"))
            ]
        , testGroup
            "the committed ledger, data/rank-ledger-tt-mlir-f9dc1b3e5101.json"
            [ testCase "has one entry per row of rank-bound §6, every obligation open, no k recorded" $ do
                bytes <- ByteString.readFile committedLedger
                parsedEntries bytes
                    @?= Right
                        [ LedgerEntry (committedScope conversion) Nothing Nothing [obligationOf i Open [] | i <- assumptions]
                        | conversion <-
                            [ "bare: ReductionProdOpConversionPattern"
                            , "bare: ReductionOpConversionPattern (ttir.sum)"
                            , "pipeline"
                            ]
                        ]
            ]
        ]
