{-# LANGUAGE OverloadedStrings #-}

module PatternsSpec (tests) where

import Data.ByteString.Lazy (ByteString)
import Data.Text (Text)
import LowerAudit.Classify (
    Classification (..),
    Outcome (..),
    OutcomeClass (..),
    Stage (..),
 )
import LowerAudit.Manifest (CaseId (..))
import LowerAudit.Patterns (
    Attempt (..),
    CaseReport (..),
    CaseRun (..),
    Considered (..),
    ConversionEnd (..),
    DomainEntry (..),
    DomainState (..),
    EndStatus (..),
    Event (..),
    PatternError (..),
    PatternState (..),
    RegisteredPattern (..),
    analyzeCase,
    analyzeDomain,
    attemptsOf,
    conversionEnd,
    parseEvents,
    parseRegistered,
 )
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, testCase, (@?=))

prod :: Text
prod = "ReductionProdOpConversionPattern"

layout :: Text
layout = "ToLayoutOpConversionPattern"

generic :: Text
generic = "GenericPattern"

prodOp :: Text
prodOp = "ttir.prod"

layoutOp :: Text
layoutOp = "ttir.to_layout"

otherOp :: Text
otherOp = "ttir.other"

reason :: Text
reason = "partial dim_arg"

begin :: Text -> Text -> Event
begin = PatternBegin

failed :: Text -> Event
failed name = PatternEnd name EndFailure

succeeded :: Text -> Event
succeeded name = PatternEnd name EndSuccess

registered :: [RegisteredPattern]
registered =
    [ RegisteredPattern prod (Just prodOp)
    , RegisteredPattern layout (Just layoutOp)
    , RegisteredPattern generic Nothing
    ]

lowered, conversionFailed, crashed, timedOut, outputInvalid, invalid :: Classification
lowered = Classified (Outcome Lowered Nothing)
conversionFailed = Classified (Outcome ConversionFailed (Just Conversion))
crashed = Classified (Outcome Crash (Just Conversion))
timedOut = Classified (Outcome Timeout (Just Conversion))
outputInvalid = Classified (Outcome OutputInvalid (Just Verification))
invalid = Classified (Outcome Invalid (Just ParseAndVerify))

caseOne, caseTwo, caseThree :: CaseId
caseOne = CaseId "c1"
caseTwo = CaseId "c2"
caseThree = CaseId "c3"

attemptsAre :: ConversionEnd -> [Event] -> [Attempt] -> Assertion
attemptsAre end events expected = attemptsOf end events @?= Right expected

refusedWith :: ConversionEnd -> [Event] -> PatternError -> Assertion
refusedWith end events expected = attemptsOf end events @?= Left expected

statesOf :: Classification -> [Event] -> Either PatternError [(Text, PatternState)]
statesOf classification events =
    reportStates <$> analyzeCase registered (CaseRun caseOne classification events)

statesAre :: Classification -> [Event] -> (PatternState, PatternState, PatternState) -> Assertion
statesAre classification events (prodState, layoutState, genericState) =
    statesOf classification events
        @?= Right [(prod, prodState), (layout, layoutState), (generic, genericState)]

reportOf :: CaseId -> [Attempt] -> CaseReport
reportOf name attempts =
    CaseReport name attempts [(known, best known) | RegisteredPattern known _ <- registered]
  where
    best known =
        maximum (Registered : [attemptState attempt | attempt <- attempts, attemptPattern attempt == known])

entryFor :: Text -> [CaseReport] -> [DomainEntry]
entryFor name reports =
    [entry | entry <- analyzeDomain registered reports, registeredName (domainPattern entry) == name]

stateOverDomain :: Text -> [CaseReport] -> [DomainState]
stateOverDomain name reports = map domainState (entryFor name reports)

countsOver :: Text -> [CaseReport] -> [[(PatternState, Int)]]
countsOver name reports = map domainCounts (entryFor name reports)

counts :: [(PatternState, Int)] -> [(PatternState, Int)]
counts given = [(state, sum [n | (other, n) <- given, other == state]) | state <- [minBound .. maxBound]]

malformed :: Int -> ByteString -> Assertion
malformed line input = parseEvents input @?= Left (MalformedLine line)

malformedDump :: Int -> ByteString -> Assertion
malformedDump line input = parseRegistered input @?= Left (MalformedLine line)

beginLine, reasonLine, endLine :: ByteString
beginLine = "{\"kind\":\"pattern-begin\",\"op\":\"ttir.prod\",\"pattern\":\"ReductionProdOpConversionPattern\"}"
reasonLine = "{\"kind\":\"match-failure\",\"reason\":\"partial dim_arg\"}"
endLine = "{\"kind\":\"pattern-end\",\"pattern\":\"ReductionProdOpConversionPattern\",\"status\":\"failure\"}"

dumpProd, dumpLayout, dumpGeneric :: ByteString
dumpProd = "{\"kind\":\"registered\",\"pattern\":\"ReductionProdOpConversionPattern\",\"root\":\"ttir.prod\"}"
dumpLayout = "{\"kind\":\"registered\",\"pattern\":\"ToLayoutOpConversionPattern\",\"root\":\"ttir.to_layout\"}"
dumpGeneric = "{\"kind\":\"registered\",\"pattern\":\"GenericPattern\",\"root\":null}"

parsing :: TestTree
parsing =
    testGroup
        "parsing, the schema in docs/TODO-l7.md"
        [ testGroup
            "parseEvents"
            [ testCase "the three kinds, in order" $
                parseEvents (beginLine <> "\n" <> reasonLine <> "\n" <> endLine <> "\n")
                    @?= Right [begin prodOp prod, MatchFailure reason, failed prod]
            , testCase "a success status" $
                parseEvents "{\"kind\":\"pattern-end\",\"pattern\":\"p\",\"status\":\"success\"}\n"
                    @?= Right [succeeded "p"]
            , testCase "an empty file has no events: a case that did not parse" $
                parseEvents "" @?= Right []
            , testCase "a last line with no newline still counts" $
                parseEvents beginLine @?= Right [begin prodOp prod]
            , testCase "a line that is not JSON is named by number" $
                malformed 2 (beginLine <> "\nnot json\n")
            , testCase "a truncated last line is refused, not dropped" $
                malformed 2 (beginLine <> "\n{\"kind\":\"pattern-e")
            , testCase "a blank line" $ malformed 2 (beginLine <> "\n\n" <> endLine <> "\n")
            , testCase "an unknown kind" $ malformed 1 "{\"kind\":\"nope\"}\n"
            , testCase "a missing field" $ malformed 1 "{\"kind\":\"pattern-begin\",\"pattern\":\"p\"}\n"
            , testCase "a field of the wrong type" $ malformed 1 "{\"kind\":\"match-failure\",\"reason\":1}\n"
            , testCase "an unknown status" $ malformed 1 "{\"kind\":\"pattern-end\",\"pattern\":\"p\",\"status\":\"maybe\"}\n"
            , testCase "a dump line is not an event" $ malformed 1 (dumpProd <> "\n")
            ]
        , testGroup
            "parseRegistered"
            [ testCase "names and roots, in registration order" $
                parseRegistered (dumpProd <> "\n" <> dumpLayout <> "\n")
                    @?= Right [RegisteredPattern prod (Just prodOp), RegisteredPattern layout (Just layoutOp)]
            , testCase "a null root is no root" $
                parseRegistered (dumpGeneric <> "\n") @?= Right [RegisteredPattern generic Nothing]
            , testCase "an absent root is refused: the adapter always writes it" $
                malformedDump 1 "{\"kind\":\"registered\",\"pattern\":\"p\"}\n"
            , testCase "an event line is not a registration" $ malformedDump 1 (beginLine <> "\n")
            , testCase "a line that is not JSON is named by number" $ malformedDump 2 (dumpProd <> "\nnope\n")
            , testCase "one name twice has no stable identity, and is refused" $
                parseRegistered (dumpProd <> "\n" <> dumpLayout <> "\n" <> dumpProd <> "\n")
                    @?= Left (DuplicateRegistration prod)
            ]
        ]

endOfConversion :: TestTree
endOfConversion =
    testGroup
        "conversionEnd: what the final class says about the rewrites"
        [ testCase "LOWERED keeps them" $ conversionEnd lowered @?= KeptRewrites
        , testCase "OUTPUT_INVALID keeps them: the conversion finished, then verification failed" $
            conversionEnd outputInvalid @?= KeptRewrites
        , testCase "a documented rejection at verification keeps them" $
            conversionEnd (Classified (Outcome (ExpectedRejection "ttnn-prod-rank") (Just Verification)))
                @?= KeptRewrites
        , testCase "a documented rejection in a pass undoes them" $
            conversionEnd (Classified (Outcome (ExpectedRejection "id") (Just Conversion))) @?= UndidRewrites
        , testCase "CONVERSION_FAILED undoes them" $ conversionEnd conversionFailed @?= UndidRewrites
        , testCase "CRASH gives no verdict" $ conversionEnd crashed @?= NoVerdict
        , testCase "TIMEOUT gives no verdict" $ conversionEnd timedOut @?= NoVerdict
        , testCase "UNEXPLAINED gives no verdict" $
            conversionEnd (Unexplained Conversion "unknown") @?= NoVerdict
        , testCase "INVALID ran no conversion" $ conversionEnd invalid @?= NoConversion
        ]

singleAttempts :: TestTree
singleAttempts =
    testGroup
        "one state per stream"
        [ testCase "attempted: a begin with no end, on a crash" $
            attemptsAre NoVerdict [begin prodOp prod] [Attempt prod prodOp Attempted []]
        , testCase "match failed, with its reason" $
            attemptsAre
                UndidRewrites
                [begin prodOp prod, MatchFailure reason, failed prod]
                [Attempt prod prodOp MatchFailed [reason]]
        , testCase "match failed, with no reason" $
            attemptsAre UndidRewrites [begin prodOp prod, failed prod] [Attempt prod prodOp MatchFailed []]
        , testCase "several reasons stay in order" $
            attemptsAre
                KeptRewrites
                [begin prodOp prod, MatchFailure "first", MatchFailure "second", failed prod]
                [Attempt prod prodOp MatchFailed ["first", "second"]]
        , testCase "applied: it returned success, and the run gave no verdict" $
            attemptsAre
                NoVerdict
                [begin layoutOp layout, succeeded layout]
                [Attempt layout layoutOp Applied []]
        , testCase "survived: it returned success, and the rewrites were kept" $
            attemptsAre
                KeptRewrites
                [begin layoutOp layout, succeeded layout]
                [Attempt layout layoutOp Survived []]
        , testCase "rolled back: two failure ends, its new IR did not legalize" $
            attemptsAre
                KeptRewrites
                [begin prodOp prod, failed prod, failed prod, begin otherOp generic, succeeded generic]
                [Attempt prod prodOp RolledBack [], Attempt generic otherOp Survived []]
        , testCase "rolled back: a success end, then the whole conversion failed" $
            attemptsAre
                UndidRewrites
                [begin layoutOp layout, succeeded layout, begin prodOp prod, MatchFailure reason, failed prod]
                [Attempt layout layoutOp RolledBack [], Attempt prod prodOp MatchFailed [reason]]
        , testCase "a reason on a pattern that then succeeds does not change its state" $
            attemptsAre
                KeptRewrites
                [begin prodOp prod, MatchFailure reason, succeeded prod]
                [Attempt prod prodOp Survived [reason]]
        ]

nesting :: TestTree
nesting =
    testGroup
        "nesting: new IR is legalized before its parent's end"
        [ testCase "attempts are listed by begin, parent first" $
            attemptsAre
                KeptRewrites
                [begin prodOp prod, begin layoutOp layout, succeeded layout, succeeded prod]
                [Attempt prod prodOp Survived [], Attempt layout layoutOp Survived []]
        , testCase "siblings stay in begin order" $
            attemptsAre
                KeptRewrites
                [begin prodOp prod, begin layoutOp layout, succeeded layout, begin otherOp generic, succeeded generic, succeeded prod]
                [Attempt prod prodOp Survived [], Attempt layout layoutOp Survived [], Attempt generic otherOp Survived []]
        , testCase "a child's success dies with its rolled-back parent" $
            attemptsAre
                KeptRewrites
                [begin prodOp prod, begin layoutOp layout, succeeded layout, failed prod, failed prod]
                [Attempt prod prodOp RolledBack [], Attempt layout layoutOp RolledBack []]
        , testCase "and with a rolled-back grandparent" $
            attemptsAre
                KeptRewrites
                [ begin prodOp prod
                , begin layoutOp layout
                , begin otherOp generic
                , succeeded generic
                , succeeded layout
                , failed prod
                , failed prod
                ]
                [ Attempt prod prodOp RolledBack []
                , Attempt layout layoutOp RolledBack []
                , Attempt generic otherOp RolledBack []
                ]
        , testCase "a child's success dies with a parent that ended in one failure" $
            attemptsAre
                KeptRewrites
                [begin prodOp prod, begin layoutOp layout, succeeded layout, failed prod]
                [Attempt prod prodOp MatchFailed [], Attempt layout layoutOp RolledBack []]
        , testCase "a child that failed to match stays match failed under a rolled-back parent" $
            attemptsAre
                KeptRewrites
                [begin prodOp prod, begin layoutOp layout, failed layout, failed prod, failed prod]
                [Attempt prod prodOp RolledBack [], Attempt layout layoutOp MatchFailed []]
        , testCase "a crash inside a child: the open parent is attempted, the child applied" $
            attemptsAre
                NoVerdict
                [begin prodOp prod, begin layoutOp layout, succeeded layout]
                [Attempt prod prodOp Attempted [], Attempt layout layoutOp Applied []]
        , testCase "a reason belongs to the innermost open attempt" $
            attemptsAre
                KeptRewrites
                [begin prodOp prod, begin layoutOp layout, MatchFailure reason, failed layout, succeeded prod]
                [Attempt prod prodOp Survived [], Attempt layout layoutOp MatchFailed [reason]]
        , testCase "after a child closes, a reason is its parent's" $
            attemptsAre
                KeptRewrites
                [begin prodOp prod, begin layoutOp layout, failed layout, MatchFailure reason, succeeded prod]
                [Attempt prod prodOp Survived [reason], Attempt layout layoutOp MatchFailed []]
        , testCase "one pattern nested in itself, both rolled back: four ends" $
            attemptsAre
                KeptRewrites
                [ begin prodOp prod
                , begin otherOp prod
                , failed prod
                , failed prod
                , failed prod
                , failed prod
                ]
                [Attempt prod prodOp RolledBack [], Attempt prod otherOp RolledBack []]
        , testCase "one pattern twice in a row is two attempts" $
            attemptsAre
                KeptRewrites
                [begin prodOp prod, failed prod, begin otherOp prod, succeeded prod]
                [Attempt prod prodOp MatchFailed [], Attempt prod otherOp Survived []]
        ]

malformedStreams :: TestTree
malformedStreams =
    testGroup
        "a stream the driver cannot have written is refused"
        [ testCase "an end with no begin" $ refusedWith KeptRewrites [failed prod] (UnmatchedEnd prod)
        , testCase "an end naming another pattern than the open one" $
            refusedWith KeptRewrites [begin prodOp prod, failed layout] (UnmatchedEnd layout)
        , testCase "a third failure end" $
            refusedWith KeptRewrites [begin prodOp prod, failed prod, failed prod, failed prod] (UnmatchedEnd prod)
        , testCase "a failure end after a success end" $
            refusedWith KeptRewrites [begin prodOp prod, succeeded prod, failed prod] (UnmatchedEnd prod)
        , testCase "a second failure end that is not adjacent to the first" $
            refusedWith
                KeptRewrites
                [begin prodOp prod, failed prod, begin layoutOp layout, succeeded layout, failed prod]
                (UnmatchedEnd prod)
        , testCase "a reason outside any attempt" $
            refusedWith KeptRewrites [MatchFailure reason] (ReasonOutsideAttempt reason)
        , testCase "a reason between the two ends of a rollback" $
            refusedWith KeptRewrites [begin prodOp prod, failed prod, MatchFailure reason, failed prod] (ReasonOutsideAttempt reason)
        , testCase "a reason between two ends, with a parent open: the second end is unmatched" $
            refusedWith
                KeptRewrites
                [begin layoutOp layout, begin prodOp prod, failed prod, MatchFailure reason, failed prod]
                (UnmatchedEnd prod)
        , testCase "an open attempt when the rewrites were kept" $
            refusedWith KeptRewrites [begin prodOp prod] (OpenAttempt prod)
        , testCase "an open attempt when they were undone" $
            refusedWith UndidRewrites [begin prodOp prod] (OpenAttempt prod)
        , testCase "any event where no conversion ran" $
            refusedWith NoConversion [begin prodOp prod, failed prod] EventsWithoutConversion
        , testCase "no conversion and no events is fine" $ attemptsAre NoConversion [] []
        , testCase "no events at all is fine" $ attemptsAre KeptRewrites [] []
        ]

perCase :: TestTree
perCase =
    testGroup
        "analyzeCase: one state per registered pattern, in registration order"
        [ testCase "registered: no begin on this case" $
            statesAre lowered [begin layoutOp layout, succeeded layout] (Registered, Survived, Registered)
        , testCase "attempted, on a crash" $
            statesAre crashed [begin prodOp prod] (Attempted, Registered, Registered)
        , testCase "match failed, with the case's class" $
            statesAre conversionFailed [begin prodOp prod, MatchFailure reason, failed prod] (MatchFailed, Registered, Registered)
        , testCase "applied, then a crash on the next pattern" $
            statesAre crashed [begin layoutOp layout, succeeded layout, begin prodOp prod] (Attempted, Applied, Registered)
        , testCase "applied, then a timeout" $
            statesAre timedOut [begin layoutOp layout, succeeded layout] (Registered, Applied, Registered)
        , testCase "survived, though the output did not verify: O3's shape" $
            statesAre outputInvalid [begin prodOp prod, succeeded prod] (Survived, Registered, Registered)
        , testCase "rolled back with two ends" $
            statesAre lowered [begin prodOp prod, failed prod, failed prod] (RolledBack, Registered, Registered)
        , testCase "rolled back with the conversion: a partial mark on the bare pass" $
            statesAre
                conversionFailed
                [begin layoutOp layout, succeeded layout, begin prodOp prod, MatchFailure reason, failed prod]
                (MatchFailed, RolledBack, Registered)
        , testCase "the best attempt decides: match failed on one op, survived on another" $
            statesAre lowered [begin otherOp generic, failed generic, begin prodOp generic, succeeded generic] (Registered, Registered, Survived)
        , testCase "the best attempt decides: rolled back on one op, survived on another" $
            statesAre lowered [begin otherOp generic, failed generic, failed generic, begin prodOp generic, succeeded generic] (Registered, Registered, Survived)
        , testCase "the best attempt decides: applied beats an open attempt" $
            statesAre crashed [begin otherOp generic, succeeded generic, begin prodOp generic] (Registered, Registered, Applied)
        , testCase "the report keeps the case and every attempt" $
            analyzeCase registered (CaseRun caseTwo conversionFailed [begin prodOp prod, MatchFailure reason, failed prod])
                @?= Right
                    ( CaseReport
                        caseTwo
                        [Attempt prod prodOp MatchFailed [reason]]
                        [(prod, MatchFailed), (layout, Registered), (generic, Registered)]
                    )
        , testCase "a pattern with no root may begin on any op" $
            statesAre lowered [begin otherOp generic, succeeded generic] (Registered, Registered, Survived)
        , testCase "a pattern not in the dump is refused" $
            statesOf lowered [begin prodOp "Unknown", succeeded "Unknown"] @?= Left (UnregisteredPattern "Unknown")
        , testCase "a begin on an op that is not the pattern's root is refused: Exp B's falsifier" $
            statesOf lowered [begin layoutOp prod, succeeded prod] @?= Left (RootMismatch prod layoutOp)
        , testCase "events on an invalid case are refused: they could not count as valid evidence" $
            statesOf invalid [begin prodOp prod, failed prod] @?= Left EventsWithoutConversion
        , testCase "an invalid case with no events reports every pattern as registered" $
            statesAre invalid [] (Registered, Registered, Registered)
        , testCase "a stream error reaches the caller" $
            statesOf lowered [failed prod] @?= Left (UnmatchedEnd prod)
        ]

prodFailed :: [Attempt]
prodFailed = [Attempt prod prodOp MatchFailed [reason]]

overDomain :: TestTree
overDomain =
    testGroup
        "analyzeDomain"
        [ testCase "one entry per registered pattern, in registration order" $
            map domainPattern (analyzeDomain registered []) @?= registered
        , testCase "survived on one case is enough" $
            stateOverDomain prod [reportOf caseOne prodFailed, reportOf caseTwo [Attempt prod prodOp Survived []]]
                @?= [ObservedSurvived]
        , testCase "survived beats applied and rolled back" $
            stateOverDomain
                prod
                [ reportOf caseOne [Attempt prod prodOp Applied []]
                , reportOf caseTwo [Attempt prod prodOp RolledBack []]
                , reportOf caseThree [Attempt prod prodOp Survived []]
                ]
                @?= [ObservedSurvived]
        , testCase "applied, never known to survive" $
            stateOverDomain prod [reportOf caseOne [Attempt prod prodOp Applied []]] @?= [ObservedApplied]
        , testCase "applied beats rolled back" $
            stateOverDomain
                prod
                [reportOf caseOne [Attempt prod prodOp RolledBack []], reportOf caseTwo [Attempt prod prodOp Applied []]]
                @?= [ObservedApplied]
        , testCase "rolled back everywhere: it did apply, and never survived" $
            stateOverDomain prod [reportOf caseOne [Attempt prod prodOp RolledBack []]] @?= [ObservedRolledBack]
        , testCase "counts are cases per state, and sum to the cases" $
            countsOver
                prod
                [ reportOf caseOne prodFailed
                , reportOf caseTwo [Attempt prod prodOp Survived []]
                , reportOf caseThree [Attempt layout layoutOp Survived []]
                ]
                @?= [counts [(Registered, 1), (MatchFailed, 1), (Survived, 1)]]
        , testCase "a case counts once, under its best state" $
            countsOver prod [reportOf caseOne (prodFailed ++ [Attempt prod otherOp Survived []])]
                @?= [counts [(Survived, 1)]]
        , testGroup
            "not observed, with the conditions it was considered under"
            [ testCase "never begun on any case: considered under nothing" $
                stateOverDomain prod [reportOf caseOne []] @?= [NotObserved []]
            , testCase "no cases at all: not observed, and that is all that can be said" $
                stateOverDomain prod [] @?= [NotObserved []]
            , testCase "match failed on two cases: the root op, both cases, the reason once" $
                stateOverDomain prod [reportOf caseOne prodFailed, reportOf caseTwo prodFailed]
                    @?= [NotObserved [Considered prodOp [caseOne, caseTwo] [reason]]]
            , testCase "a case with no attempt is not listed" $
                stateOverDomain prod [reportOf caseOne prodFailed, reportOf caseTwo []]
                    @?= [NotObserved [Considered prodOp [caseOne] [reason]]]
            , testCase "no reason given: considered, with none" $
                stateOverDomain prod [reportOf caseOne [Attempt prod prodOp MatchFailed []]]
                    @?= [NotObserved [Considered prodOp [caseOne] []]]
            , testCase "open at a crash: considered, not observed" $
                stateOverDomain prod [reportOf caseOne [Attempt prod prodOp Attempted []]]
                    @?= [NotObserved [Considered prodOp [caseOne] []]]
            , testCase "two root ops, in first-seen order, each with its own reasons" $
                stateOverDomain
                    generic
                    [ reportOf caseOne [Attempt generic otherOp MatchFailed ["a"]]
                    , reportOf caseTwo [Attempt generic prodOp MatchFailed ["b"], Attempt generic otherOp MatchFailed ["c"]]
                    ]
                    @?= [ NotObserved
                            [ Considered otherOp [caseOne, caseTwo] ["a", "c"]
                            , Considered prodOp [caseTwo] ["b"]
                            ]
                        ]
            , testCase "attempted twice in one case: the case is listed once" $
                stateOverDomain prod [reportOf caseOne (prodFailed ++ prodFailed)]
                    @?= [NotObserved [Considered prodOp [caseOne] [reason]]]
            ]
        , testCase "from the two files to the domain" $ do
            let dump = dumpProd <> "\n" <> dumpLayout <> "\n" <> dumpGeneric <> "\n"
                events = beginLine <> "\n" <> reasonLine <> "\n" <> endLine <> "\n"
                run patterns = analyzeCase patterns . CaseRun caseOne conversionFailed
                result = do
                    patterns <- parseRegistered dump
                    report <- parseEvents events >>= run patterns
                    pure (map domainState (analyzeDomain patterns [report]))
            result
                @?= Right
                    [ NotObserved [Considered prodOp [caseOne] [reason]]
                    , NotObserved []
                    , NotObserved []
                    ]
        ]

tests :: TestTree
tests =
    testGroup
        "LowerAudit.Patterns, on hand-written streams"
        [ parsing
        , endOfConversion
        , testGroup "attemptsOf" [singleAttempts, nesting, malformedStreams]
        , perCase
        , overDomain
        ]
