{-# LANGUAGE OverloadedStrings #-}

module RankSpec (tests) where

import Control.Monad (replicateM)
import Data.List (find, isInfixOf, nub)
import Data.Text (Text)
import Data.Text qualified as T
import LowerAudit.Automaton (Dfa, mkDfa, run)
import LowerAudit.Ledger (
    Ledger,
    LedgerError (..),
    ObligationId (..),
    Required,
    Scope (..),
    obligationsInDoc,
    parseLedger,
    readEvidence,
 )
import LowerAudit.Patterns (
    CertificateConflict (..),
    DomainEntry (..),
    DomainState (..),
    PatternState (..),
    RegisteredPattern (..),
    markUnreachable,
    unreachableCertificate,
 )
import LowerAudit.Rank (
    Abstraction (..),
    Bound (..),
    Certificate,
    CertificateRefusal (..),
    Claim (..),
    Conditional,
    ConditionalRefusal (..),
    Empirical (..),
    LetterChange (..),
    Level (..),
    Proof (..),
    Proved,
    ProvedRefusal (..),
    Question (..),
    RankInput (..),
    RankProfile (..),
    RankReport (..),
    Stability (..),
    Subject (..),
    UnmetObligation (..),
    Verdict (..),
    certifiedBound,
    certifiedPattern,
    certifiedScope,
    certifyUnreachable,
    conditional,
    conditionalBound,
    empirical,
    highestLevel,
    levelName,
    proved,
    provedProof,
    rankReport,
    renderRankReport,
 )
import RankFixtures (
    Table (..),
    allWords,
    assumptions,
    docOf,
    entryJson,
    fromTable,
    genTable,
    ledgerOf,
    mustDfa,
    tableAccepts,
    tableSize,
 )
import Test.Tasty (TestTree, localOption, mkTimeout, testGroup)
import Test.Tasty.HUnit (Assertion, assertBool, assertFailure, testCase, (@?=))
import Test.Tasty.QuickCheck (
    Gen,
    Property,
    counterexample,
    elements,
    forAll,
    sublistOf,
    suchThat,
    testProperty,
    (.&&.),
    (===),
 )

ab :: String
ab = "ab"

scope :: Scope
scope = Scope "target" "conversion" "domain" "oracle"

count :: Char -> String -> Int
count c = length . filter (== c)

equalCounts :: String -> Bool
equalCounts w = count 'a' w == count 'b' w

oddA :: String -> Bool
oddA = odd . count 'a'

lastIsA :: String -> Bool
lastIsA w = take 1 (reverse w) == "a"

secondToLastIsA :: String -> Bool
secondToLastIsA w = take 1 (drop 1 (reverse w)) == "a"

firstIsA :: String -> Bool
firstIsA w = take 1 w == "a"

allValid :: String -> Int -> (String -> o) -> Subject Char o
allValid letters limit = Subject letters limit (const True)

coverage :: (o -> Bool) -> Question o
coverage = Question Coverage

everyWord :: String -> Dfa Int Char Bool
everyWord letters = mustDfa (mkDfa letters [0] 0 const (const True))

nonEmptyWords :: String -> Dfa Bool Char Bool
nonEmptyWords letters = mustDfa (mkDfa letters [False, True] False (\_ _ -> True) id)

parityOfA :: String -> Dfa Int Char Bool
parityOfA letters = mustDfa (mkDfa letters [0, 1] 0 step (== 1))
  where
    step q 'a' = 1 - q
    step q _ = q

parityFourStates :: Dfa Int Char Bool
parityFourStates = mustDfa (mkDfa ab [0, 1, 2, 3] 0 step odd)
  where
    step q 'a' = (q + 1) `mod` 4
    step q _ = q

parityWithStrandedState :: Dfa Int Char Bool
parityWithStrandedState = mustDfa (mkDfa ab [0, 1, 2] 0 step (== 1))
  where
    step 2 _ = 2
    step q 'a' = 1 - q
    step q _ = q

lastIsADfa :: Dfa Bool Char Bool
lastIsADfa = mustDfa (mkDfa ab [False, True] False (\_ c -> c == 'a') id)

secondToLastDfa :: Dfa (Bool, Bool) Char Bool
secondToLastDfa =
    mustDfa
        ( mkDfa
            ab
            [(x, y) | x <- [False, True], y <- [False, True]]
            (False, False)
            (\(_, y) c -> (y, c == 'a'))
            fst
        )

aboveFourDfa :: Dfa Int Char Bool
aboveFourDfa = mustDfa (mkDfa "a" [0 .. 5] 0 (\q _ -> min 5 (q + 1)) (> 4))

partialMarksDfa :: Dfa (Int, Bool) Char Bool
partialMarksDfa =
    mustDfa
        ( mkDfa
            "mu"
            [(c, seen) | c <- [0, 1, 2], seen <- [False, True]]
            (0, False)
            step
            (\(c, seen) -> c == 2 && seen)
        )
  where
    step (c, seen) 'm' = (min 2 (c + 1), seen)
    step (c, _) _ = (c, True)

partialMarks :: String -> Bool
partialMarks w = count 'm' w >= 2 && count 'u' w >= 1

counterDfa :: String -> Int -> Dfa Int Char Int
counterDfa letters n = mustDfa (mkDfa letters [0 .. n - 1] 0 (\q _ -> (q + 1) `mod` n) id)

everyWordOf :: String -> Int -> Dfa Int Char Bool
everyWordOf letters n = mustDfa (mkDfa letters [0 .. n - 1] 0 (\q _ -> (q + 1) `mod` n) (const True))

residueIs :: Int -> Int -> Dfa Int Char Bool
residueIs n r = mustDfa (mkDfa "a" [0 .. n - 1] 0 (\q _ -> (q + 1) `mod` n) (== r))

rankOneOnly :: String -> Dfa Int Char Bool
rankOneOnly letters = mustDfa (mkDfa letters [0, 1, 2] 0 (\q _ -> min 2 (q + 1)) (== 1))

boundedCounter :: Int -> Dfa (Maybe Int) Char Bool
boundedCounter m = mustDfa (mkDfa ab states (Just 0) step (== Just 0))
  where
    states = Nothing : map Just [-m .. m]
    step Nothing _ = Nothing
    step (Just d) c = inRange (if c == 'a' then d + 1 else d - 1)
    inRange d
        | abs d > m = Nothing
        | otherwise = Just d

asThenBs :: Dfa Int Char Bool
asThenBs = mustDfa (mkDfa ab [0, 1, 2] 0 step (< 2))
  where
    step 0 'a' = 0
    step 0 _ = 1
    step 1 'b' = 1
    step _ _ = 2

isAsThenBs :: String -> Bool
isAsThenBs w = not ("ba" `isInfixOf` w)

constantFalse :: Dfa Int Char Bool
constantFalse = mustDfa (mkDfa ab [0] 0 const (const False))

hiddenGuard :: String -> Bool
hiddenGuard w = length w >= 12 && equalCounts w

parityAbstraction :: Abstraction Char Bool
parityAbstraction = Abstraction (parityOfA ab) (everyWord ab)

paritySubject :: Subject Char Bool
paritySubject = allValid ab 3 oddA

neverViolated :: Question Bool
neverViolated = coverage (const False)

issue :: (Eq o, Show o) => Question o -> Abstraction Char o -> Subject Char o -> Conditional Char
issue question abstraction subject =
    either (error . show) id (conditional question (Just abstraction) subject)

boundOf :: (Eq o, Show o) => Question o -> Abstraction Char o -> Subject Char o -> Bound Char
boundOf question abstraction = conditionalBound . issue question abstraction

sizes :: Bound Char -> (Int, Int, Int)
sizes b = (boundStates b, boundValidityStates b, boundN b)

parityConditional :: Conditional Char
parityConditional = issue neverViolated parityAbstraction paritySubject

syntheticEvidence :: Text
syntheticEvidence = "synthetic: records nothing about any target"

discharged :: Text -> (Text, Text, [Text])
discharged i = (i, "discharged", [syntheticEvidence])

opened :: Text -> (Text, Text, [Text])
opened i = (i, "open", [])

evidenceFor :: [Text] -> Maybe Int -> Maybe Int -> [(Text, Text, [Text])] -> Either LedgerError (Required, Ledger)
evidenceFor doc k v obligations =
    (,) <$> obligationsInDoc (docOf doc) <*> parseLedger (ledgerOf [entryJson scope k v obligations])

fullEvidence :: Int -> Int -> Either LedgerError (Required, Ledger)
fullEvidence k v = evidenceFor assumptions (Just k) (Just v) (map discharged assumptions)

gateIn :: Scope -> Either LedgerError (Required, Ledger) -> Conditional Char -> Either ProvedRefusal (Proved Char)
gateIn within evidence bound =
    either (error . show) (\(required, ledger) -> proved within required ledger bound) evidence

gate :: Either LedgerError (Required, Ledger) -> Conditional Char -> Either ProvedRefusal (Proved Char)
gate = gateIn scope

parityThrough :: [Text] -> Maybe Int -> Maybe Int -> [(Text, Text, [Text])] -> Either ProvedRefusal (Proof Char)
parityThrough doc k v obligations =
    provedProof <$> gate (evidenceFor doc k v obligations) parityConditional

allOpenExcept :: [Text] -> [(Text, Text, [Text])]
allOpenExcept done = [if i `elem` done then discharged i else opened i | i <- assumptions]

unmet :: (ObligationId -> UnmetObligation) -> Text -> UnmetObligation
unmet how = how . ObligationId

report :: (Eq o) => Question o -> Maybe (Abstraction Char o) -> Either LedgerError (Required, Ledger) -> Subject Char o -> RankReport Char o
report question abstraction evidence subject =
    rankReport (RankInput subject 2 question abstraction scope evidence)

insertAt :: Int -> Char -> String -> String
insertAt p c w = take p w ++ c : drop p w

referenceProfile :: String -> (String -> Bool) -> (String -> Bool) -> Int -> RankProfile Char Bool
referenceProfile letters valid outcome r =
    RankProfile r (nub (map outcome (filter valid (replicateM r letters)))) changes
  where
    changes =
        [ LetterChange (x, y) positions
        | (i, x) <- zip [0 :: Int ..] letters
        , (j, y) <- zip [0 :: Int ..] letters
        , i < j
        , let positions = [p | p <- [0 .. r - 1], any (changesAt x y p) (replicateM (r - 1) letters)]
        , not (null positions)
        ]
    changesAt x y p context =
        let withX = insertAt p x context
            withY = insertAt p y context
         in valid withX && valid withY && outcome withX /= outcome withY

genValidAndOutcome :: Gen (Table, Table)
genValidAndOutcome = do
    letters <- elements ["ab", "ba", "abc"]
    (,) <$> genTable letters 3 <*> genTable letters 3

profilesMatchTheDefinition :: (Table, Table) -> Property
profilesMatchTheDefinition (validity, outcome) =
    let letters = tableLetters validity
        guarded w
            | tableAccepts validity w = tableAccepts outcome w
            | otherwise = error "ran an invalid case"
        subject = Subject letters 3 (tableAccepts validity) guarded
     in empiricalProfiles (empirical 9 subject)
            === map (referenceProfile letters (tableAccepts validity) guarded) [1, 2, 3]

genOutcomeAndValidity :: Gen (Table, Table)
genOutcomeAndValidity = do
    letters <- elements ["ab", "ba"]
    (,) <$> genTable letters 3 <*> genTable letters 2

cutoffAgreesWithBruteForce :: (Table, Table) -> Property
cutoffAgreesWithBruteForce (outcome, validity) =
    let k = tableSize outcome
        kV = tableSize validity
        n = k * kV
        letters = tableLetters outcome
        depth = 2 * n - 1
        violating w = tableAccepts validity w && tableAccepts outcome w
        subject = Subject letters depth (tableAccepts validity) (tableAccepts outcome)
        bound = boundOf (coverage id) (Abstraction (fromTable outcome) (fromTable validity)) subject
        belowN = find violating (allWords letters (n - 1))
     in sizes bound === (k, kV, n)
            .&&. boundCheckedTo bound === depth
            .&&. boundClaim bound === Coverage
            .&&. boundVerdict bound === maybe HoldsBelowBound ViolatedAt belowN
            .&&. counterexample "Theorem 1: a violation past the bound with none below it" (find violating (allWords letters depth) === belowN)

anyDeclarationIsRefuted :: Table -> Property
anyDeclarationIsRefuted declared =
    let depth = 2 * tableSize declared - 1
        disagrees w = tableAccepts declared w /= equalCounts w
        subject = allValid ab depth equalCounts
        result = conditional (coverage not) (Just (Abstraction (fromTable declared) (everyWord ab))) subject
     in case find disagrees (allWords ab depth) of
            Nothing -> counterexample "pigeonhole: a table agreed with equal counts to 2k - 1" False
            Just w -> result === Left (OutcomeDisagrees w (tableAccepts declared w) (equalCounts w))

declaredAgainstEqualCounts :: Int -> Either (ConditionalRefusal Char Bool) (Conditional Char)
declaredAgainstEqualCounts m =
    let k = 2 * m + 2
     in conditional (coverage not) (Just (Abstraction (boundedCounter m) (everyWord ab))) (allValid ab (2 * k - 1) equalCounts)

anySubsetOpen :: [Text] -> Property
anySubsetOpen open =
    parityThrough assumptions (Just 2) (Just 1) [if i `elem` open then opened i else discharged i | i <- assumptions]
        === Left (ObligationsUnmet (map (unmet StillOpen) open))

neverAppliesQuestion :: Text -> Question [Text]
neverAppliesQuestion p = Question (NeverApplies p) (elem p)

patternDfa :: Dfa Int Char [Text]
patternDfa = mustDfa (mkDfa ab [0, 1] 0 step (\q -> ["Q" | q == 1]))
  where
    step q 'a' = 1 - q
    step q _ = q

patternSubject :: Subject Char [Text]
patternSubject = allValid ab 3 (\w -> ["Q" | oddA w])

patternAbstraction :: Abstraction Char [Text]
patternAbstraction = Abstraction patternDfa (everyWord ab)

provedFor :: Question [Text] -> Proved Char
provedFor question =
    either (error . show) id (gate (fullEvidence 2 1) (issue question patternAbstraction patternSubject))

certificateFor :: Text -> Certificate
certificateFor p =
    either (error . show) id (certifyUnreachable (provedFor (neverAppliesQuestion p)))

entryFor :: Text -> DomainState -> DomainEntry
entryFor p = DomainEntry (RegisteredPattern p Nothing) [(Registered, 3)]

refusalOf :: Either e b -> Maybe e
refusalOf = either Just (const Nothing)

lineOf :: Text -> Text -> Text
lineOf label text =
    case filter (T.isPrefixOf (label <> ":")) (T.lines text) of
        [line] -> line
        other -> error ("expected one " ++ show label ++ " line, got " ++ show other)

labels :: Text -> [Text]
labels = map (T.takeWhile (/= ':')) . T.lines

mentions :: Text -> Text -> Assertion
mentions text expected =
    assertBool (show text ++ " should mention " ++ show expected) (expected `T.isInfixOf` text)

refusedAt :: Text -> Text -> Assertion
refusedAt label text =
    assertBool (show text) ((label <> ": REFUSED") `T.isPrefixOf` lineOf label text)

parityReport :: Either LedgerError (Required, Ledger) -> RankReport Char Bool
parityReport evidence = report neverViolated (Just parityAbstraction) evidence paritySubject

equalCountsReport :: Maybe (Abstraction Char Bool) -> RankReport Char Bool
equalCountsReport abstraction = report (coverage not) abstraction (fullEvidence 4 1) (allValid ab 7 equalCounts)

committedScope :: Text -> Scope
committedScope conversion = Scope "tt-mlir f9dc1b3e5101" conversion "D0-tt" "V_ttir"

tests :: TestTree
tests =
    testGroup
        "LowerAudit.Rank"
        [ empiricalTests
        , conditionalTests
        , equalCountsTests
        , knownLimitTests
        , provedTests
        , committedLedgerTests
        , certificateTests
        , reportTests
        ]

empiricalTests :: TestTree
empiricalTests =
    testGroup
        "EMPIRICAL"
        [ testCase "only the last letter matters: the last position, at each rank" $
            empirical 2 (allValid ab 6 lastIsA)
                @?= Empirical
                    [ RankProfile 1 [True, False] [LetterChange ('a', 'b') [0]]
                    , RankProfile 2 [True, False] [LetterChange ('a', 'b') [1]]
                    , RankProfile 3 [True, False] [LetterChange ('a', 'b') [2]]
                    ]
                    (StableFrom 1)
        , testCase "only the first letter matters: position 0, at each rank" $
            empirical 2 (allValid ab 6 firstIsA)
                @?= Empirical
                    [ RankProfile 1 [True, False] [LetterChange ('a', 'b') [0]]
                    , RankProfile 2 [True, False] [LetterChange ('a', 'b') [0]]
                    , RankProfile 3 [True, False] [LetterChange ('a', 'b') [0]]
                    ]
                    (StableFrom 1)
        , testCase "a role counted from the end, second to last, settles once it exists" $
            empirical 2 (allValid ab 6 secondToLastIsA)
                @?= Empirical
                    [ RankProfile 1 [False] []
                    , RankProfile 2 [True, False] [LetterChange ('a', 'b') [0]]
                    , RankProfile 3 [True, False] [LetterChange ('a', 'b') [1]]
                    , RankProfile 4 [True, False] [LetterChange ('a', 'b') [2]]
                    ]
                    (StableFrom 2)
        , testCase "parity: every position, and the same outcomes in another first-seen order" $
            empirical 1 (allValid ab 6 oddA)
                @?= Empirical
                    [ RankProfile 1 [True, False] [LetterChange ('a', 'b') [0]]
                    , RankProfile 2 [False, True] [LetterChange ('a', 'b') [0, 1]]
                    ]
                    (StableFrom 1)
        , testCase "a constant function changes at no position" $
            empirical 1 (allValid ab 6 (const True))
                @?= Empirical
                    [RankProfile 1 [True] [], RankProfile 2 [True] []]
                    (StableFrom 1)
        , testCase "a letter that changes nothing is absent: b and c are alike under parity of a" $
            map profileChanges (empiricalProfiles (empirical 1 (allValid "abc" 6 oddA)))
                @?= [ [LetterChange ('a', 'b') [0], LetterChange ('a', 'c') [0]]
                    , [LetterChange ('a', 'b') [0, 1], LetterChange ('a', 'c') [0, 1]]
                    ]
        , testCase "pairs are in declared alphabet order, earlier letter first" $
            map profileChanges (empiricalProfiles (empirical 0 (allValid "ba" 6 oddA)))
                @?= [[LetterChange ('b', 'a') [0]]]
        , testCase "a window of 0 stops after rank 1" $
            empirical 0 (allValid ab 6 lastIsA)
                @?= Empirical [RankProfile 1 [True, False] [LetterChange ('a', 'b') [0]]] (StableFrom 1)
        , testCase "no rank to look at gives no profile" $
            empirical 2 (allValid ab 0 lastIsA) @?= Empirical [] (NotStableBy 0)
        , testCase "running out of ranks before the window closes is not stable" $
            empiricalStability (empirical 5 (allValid ab 3 (const True))) @?= NotStableBy 3
        , testCase "a rank threshold is invisible at a small window: stopped at rank 3, stable, and wrong about rank 5" $
            let result = empirical 2 (allValid ab 9 ((> 4) . length))
             in (empiricalStability result, map profileRank (empiricalProfiles result))
                    @?= (StableFrom 1, [1, 2, 3])
        , testCase "a window of 3 still misses the threshold" $
            empiricalStability (empirical 3 (allValid ab 9 ((> 4) . length))) @?= StableFrom 1
        , testCase "a window of 4 reaches the threshold and settles after it" $
            let result = empirical 4 (allValid ab 9 ((> 4) . length))
             in ( empiricalStability result
                , map (\p -> (profileRank p, profileOutcomes p)) (empiricalProfiles result)
                )
                    @?= ( StableFrom 5
                        ,
                            [ (1, [False])
                            , (2, [False])
                            , (3, [False])
                            , (4, [False])
                            , (5, [True])
                            , (6, [True])
                            , (7, [True])
                            , (8, [True])
                            , (9, [True])
                            ]
                        )
        , testCase "positions that jump between ends never settle" $
            empiricalStability
                (empirical 2 (allValid ab 7 (\w -> if even (length w) then lastIsA w else firstIsA w)))
                @?= NotStableBy 7
        , testCase "letter pairs that alternate never settle, at the same positions" $
            empiricalStability
                (empirical 2 (allValid "abc" 6 (\w -> take 1 (reverse w) == (if even (length w) then "a" else "b"))))
                @?= NotStableBy 6
        , testCase "a change across the validity boundary is not a change, and invalid words are not run" $
            let valid = notElem 'c'
                outcome w
                    | valid w = lastIsA w
                    | otherwise = error "ran an invalid case"
             in map profileChanges (empiricalProfiles (empirical 1 (Subject "abc" 6 valid outcome)))
                    @?= [[LetterChange ('a', 'b') [0]], [LetterChange ('a', 'b') [1]]]
        , testCase "a rank with no valid word has no outcomes and no changes" $
            empirical 1 (Subject ab 6 (const False) (error "ran an invalid case") :: Subject Char Bool)
                @?= Empirical [RankProfile 1 [] [], RankProfile 2 [] []] (StableFrom 1)
        , testProperty "profiles match the definition, on random validity and outcome" $
            forAll genValidAndOutcome profilesMatchTheDefinition
        ]

conditionalTests :: TestTree
conditionalTests =
    testGroup
        "CONDITIONAL"
        [ testGroup
            "the right N, from known automata"
            [ testCase "parity of a, every word valid: 2 * 1" $
                sizes (boundOf neverViolated parityAbstraction paritySubject) @?= (2, 1, 2)
            , testCase "the last letter, a role counted from the end: 2 * 1" $
                sizes (boundOf neverViolated (Abstraction lastIsADfa (everyWord ab)) (allValid ab 3 lastIsA))
                    @?= (2, 1, 2)
            , testCase "the second-to-last letter: 4 * 1" $
                sizes (boundOf neverViolated (Abstraction secondToLastDfa (everyWord ab)) (allValid ab 7 secondToLastIsA))
                    @?= (4, 1, 4)
            , testCase "a threshold at rank 4, on non-empty words: 6 * 2, a counter saturating at 5 (S3)" $
                sizes
                    ( boundOf
                        neverViolated
                        (Abstraction aboveFourDfa (nonEmptyWords "a"))
                        (Subject "a" 23 (not . null) ((> 4) . length))
                    )
                    @?= (6, 2, 12)
            , testCase "a partial mark summary, marks capped at 2 and whether one is unmarked: 6 * 1 (S1)" $
                sizes (boundOf neverViolated (Abstraction partialMarksDfa (everyWord "mu")) (allValid "mu" 11 partialMarks))
                    @?= (6, 1, 6)
            , testCase "N follows the declaration: parity declared with 4 states gives 4, not the smallest bound" $
                sizes (boundOf neverViolated (Abstraction parityFourStates (everyWord ab)) (allValid ab 7 oddA))
                    @?= (4, 1, 4)
            , testCase "a declared state no word reaches still counts, as Theorem 1 states k" $
                sizes (boundOf neverViolated (Abstraction parityWithStrandedState (everyWord ab)) (allValid ab 5 oddA))
                    @?= (3, 1, 3)
            , testCase "the check runs to 2N - 1, and says so" $
                boundCheckedTo (boundOf neverViolated parityAbstraction paritySubject) @?= 3
            , testCase "the claim is carried through" $
                boundClaim (boundOf (Question (NeverApplies "P") (const False)) parityAbstraction paritySubject)
                    @?= NeverApplies "P"
            ]
        , testGroup
            "the verdict"
            [ testCase "no violation below N" $
                boundVerdict (boundOf neverViolated parityAbstraction paritySubject) @?= HoldsBelowBound
            , testCase "N is tight: the only witness is at rank N - 1, by counters of coprime period" $
                let bound =
                        boundOf
                            (coverage (== 2))
                            (Abstraction (counterDfa "a" 3) (residueIs 5 4))
                            (Subject "a" 29 ((== 4) . (`mod` 5) . length) ((`mod` 3) . length))
                 in (boundN bound, boundVerdict bound) @?= (15, ViolatedAt (replicate 14 'a'))
            , testCase "a threshold's witness is its shortest word" $
                boundVerdict
                    ( boundOf
                        (coverage id)
                        (Abstraction aboveFourDfa (nonEmptyWords "a"))
                        (Subject "a" 23 (not . null) ((> 4) . length))
                    )
                    @?= ViolatedAt "aaaaa"
            , testCase "a partial mark set's witness is shortlex-first" $
                boundVerdict (boundOf (coverage id) (Abstraction partialMarksDfa (everyWord "mu")) (allValid "mu" 11 partialMarks))
                    @?= ViolatedAt "mmu"
            , testCase "a violating word that is not valid does not count" $
                boundVerdict
                    ( boundOf
                        (coverage not)
                        (Abstraction lastIsADfa (nonEmptyWords ab))
                        (Subject ab 7 (not . null) lastIsA)
                    )
                    @?= ViolatedAt "b"
            , testCase "shortlex follows the declared alphabet: under ab, a first" $
                boundVerdict (boundOf (coverage id) (Abstraction (rankOneOnly ab) (everyWord ab)) (allValid ab 5 ((== 1) . length)))
                    @?= ViolatedAt "a"
            , testCase "shortlex follows the declared alphabet: under ba, b first" $
                boundVerdict (boundOf (coverage id) (Abstraction (rankOneOnly "ba") (everyWord "ba")) (allValid "ba" 5 ((== 1) . length)))
                    @?= ViolatedAt "b"
            , testProperty "Theorem 1, on random automata: k, k_V, N, the check depth and the first violation" $
                forAll genOutcomeAndValidity cutoffAgreesWithBruteForce
            ]
        , testGroup
            "refusals"
            [ testCase "no declared abstraction, no bound" $
                conditional neverViolated Nothing paritySubject @?= Left NoAbstraction
            , testCase "a declared alphabet other than the subject's" $
                refusalOf (conditional neverViolated (Just (Abstraction (parityOfA "ba") (everyWord "ba"))) paritySubject)
                    @?= Just (AlphabetDiffers "ba" "ab")
            , testCase "outcome and validity automata over different alphabets" $
                refusalOf (conditional neverViolated (Just (Abstraction (parityOfA ab) (everyWord "ba"))) paritySubject)
                    @?= Just (AlphabetDiffers "ab" "ba")
            , testCase "a declared outcome automaton the subject contradicts: first such word in shortlex" $
                refusalOf (conditional neverViolated (Just parityAbstraction) (allValid ab 3 (\w -> oddA w && w /= "ba")))
                    @?= Just (OutcomeDisagrees "ba" True False)
            , testCase "a declared validity automaton the oracle contradicts" $
                refusalOf (conditional neverViolated (Just parityAbstraction) (Subject ab 3 (/= "ab") oddA))
                    @?= Just (ValidityDisagrees "ab" False)
            , testCase "the walk is one shortlex order over both kinds: the earlier word wins" $
                refusalOf
                    ( conditional
                        neverViolated
                        (Just parityAbstraction)
                        (Subject ab 3 (/= "ab") (\w -> oddA w /= (w == "a")))
                    )
                    @?= Just (OutcomeDisagrees "a" True False)
            , testCase "a word the declared and observed validity both reject is not run" $
                let valid = not . null
                    outcome w
                        | valid w = lastIsA w
                        | otherwise = error "ran an invalid case"
                 in sizes (boundOf neverViolated (Abstraction lastIsADfa (nonEmptyWords ab)) (Subject ab 7 valid outcome))
                        @?= (2, 2, 4)
            , testCase "the declared outcome automaton is free on invalid words" $
                let valid = notElem 'b'
                    outcome = const True
                    declared = mustDfa (mkDfa ab [0, 1] (0 :: Int) (\q c -> if c == 'b' then 1 else q) (== 0))
                    validity = mustDfa (mkDfa ab [0, 1] (0 :: Int) (\q c -> if c == 'b' then 1 else q) (== 0))
                 in sizes (boundOf neverViolated (Abstraction declared validity) (Subject ab 7 valid outcome))
                        @?= (2, 2, 4)
            , testCase "observed ranks short of 2N - 1 are refused, naming N, the ranks needed and the ranks held" $
                refusalOf (conditional neverViolated (Just parityAbstraction) (allValid ab 2 oddA))
                    @?= Just (RanksShort 2 3 2)
            , testCase "observed ranks of exactly 2N - 1 are enough" $
                sizes (boundOf neverViolated parityAbstraction (allValid ab 3 oddA)) @?= (2, 1, 2)
            , testCase "a disagreement within the observed ranks outranks being short" $
                refusalOf (conditional neverViolated (Just parityAbstraction) (allValid ab 2 (const False)))
                    @?= Just (OutcomeDisagrees "a" True False)
            , localOption (mkTimeout 30_000_000)
                $ testCase "an enormous N is refused without walking to it"
                $ refusalOf
                    ( conditional
                        (coverage (const False))
                        (Just (Abstraction (counterDfa ab 1000) (everyWordOf ab 1000)))
                        (allValid ab 2 ((`mod` 1000) . length))
                    )
                    @?= Just (RanksShort 1000000 1999999 2)
            ]
        ]

equalCountsTests :: TestTree
equalCountsTests =
    testGroup
        "equal counts of two letters is refused above EMPIRICAL"
        ( [ testCase "the empirical level still answers: its profile alternates and never settles" $
                empiricalStability (reportEmpirical (equalCountsReport Nothing)) @?= NotStableBy 7
          , testCase "with no declared abstraction, CONDITIONAL refuses" $
                refusalOf (reportConditional (equalCountsReport Nothing)) @?= Just NoAbstraction
          , testCase "with no declared abstraction, a full ledger does not reach PROVED" $
                refusalOf (reportProved (equalCountsReport Nothing)) @?= Just NoConditionalBound
          , testCase "with no declared abstraction, the highest level is EMPIRICAL" $
                highestLevel (equalCountsReport Nothing) @?= EmpiricalLevel
          , testCase "with a false declaration, a full ledger does not reach PROVED" $
                let result = equalCountsReport (Just (Abstraction (boundedCounter 1) (everyWord ab)))
                 in (refusalOf (reportProved result), highestLevel result)
                        @?= (Just NoConditionalBound, EmpiricalLevel)
          , testProperty "every automaton of up to 4 states is refuted by 2k - 1, at the first word it gets wrong" $
                forAll (genTable ab 4) anyDeclarationIsRefuted
          , testCase "ranks too few to show the disagreement are still refused" $
                refusalOf (conditional (coverage not) (Just (Abstraction (boundedCounter 2) (everyWord ab))) (allValid ab 5 equalCounts))
                    @?= Just (RanksShort 6 11 5)
          , testCase "on valid words a*b*, the language a^n b^n, a declaration is refuted too" $
                refusalOf
                    ( conditional
                        (coverage not)
                        (Just (Abstraction (boundedCounter 1) asThenBs))
                        (Subject ab 23 isAsThenBs equalCounts)
                    )
                    @?= Just (OutcomeDisagrees "aabb" False True)
          , testCase "on non-empty valid words, a declaration is refuted too" $
                refusalOf
                    ( conditional
                        (coverage not)
                        (Just (Abstraction (boundedCounter 1) (nonEmptyWords ab)))
                        (Subject ab 15 (not . null) equalCounts)
                    )
                    @?= Just (OutcomeDisagrees "aabb" False True)
          , testCase "stable is not regular: with a neutral letter the profile settles at rank 2, and CONDITIONAL still refuses" $
                let result = report (coverage not) Nothing (fullEvidence 8 1) (allValid "abc" 4 equalCounts)
                 in (empiricalStability (reportEmpirical result), highestLevel result)
                        @?= (StableFrom 2, EmpiricalLevel)
          ]
            ++ concatMap boundedCounterTests [0, 1, 2, 3]
        )

boundedCounterTests :: Int -> [TestTree]
boundedCounterTests m =
    [ testCase (name "agrees with equal counts on every rank below N: checking only those would pass it") $
        let ws = allWords ab (k - 1)
         in map (run (boundedCounter m)) ws @?= map (Just . equalCounts) ws
    , testCase (name "is refuted at the first word past its range") $
        refusalOf (declaredAgainstEqualCounts m)
            @?= Just (OutcomeDisagrees (replicate (m + 1) 'a' ++ replicate (m + 1) 'b') False True)
    ]
  where
    k = 2 * m + 2
    name text = "a counter clipped at " ++ show m ++ " " ++ text

knownLimitTests :: TestTree
knownLimitTests =
    testGroup
        "known limits, kept on purpose: no finite run can establish A3"
        [ testCase "a non-regular guard past the checked ranks gets through CONDITIONAL, which only ever said if" $
            let result = report (coverage id) (Just (Abstraction constantFalse (everyWord ab))) (Left (Unreadable "none")) (allValid ab 1 hiddenGuard)
             in (fmap (sizes . conditionalBound) (reportConditional result), highestLevel result)
                    @?= (Right (1, 1, 1), ConditionalLevel)
        , testCase "its verdict is false of the function, and true of the declaration" $
            let bound = boundOf (coverage id) (Abstraction constantFalse (everyWord ab)) (allValid ab 1 hiddenGuard)
             in (boundVerdict bound, hiddenGuard (replicate 6 'a' ++ replicate 6 'b'))
                    @?= (HoldsBelowBound, True)
        , testCase "the open ledger is what stops it at CONDITIONAL" $
            let result =
                    report
                        (coverage id)
                        (Just (Abstraction constantFalse (everyWord ab)))
                        (evidenceFor assumptions (Just 1) (Just 1) (map opened assumptions))
                        (allValid ab 1 hiddenGuard)
             in refusalOf (reportProved result) @?= Just (ObligationsUnmet (map (unmet StillOpen) assumptions))
        , testCase "false evidence passes the gate: it checks that evidence is recorded, not that it is true" $
            highestLevel
                ( report
                    (coverage id)
                    (Just (Abstraction constantFalse (everyWord ab)))
                    (fullEvidence 1 1)
                    (allValid ab 1 hiddenGuard)
                )
                @?= ProvedLevel
        ]

provedTests :: TestTree
provedTests =
    testGroup
        "PROVED"
        [ testCase "every obligation discharged, with evidence: the bound, the scope and the evidence in document order" $
            parityThrough assumptions (Just 2) (Just 1) (map discharged (reverse assumptions))
                @?= Right
                    ( Proof
                        (conditionalBound parityConditional)
                        scope
                        [(ObligationId i, [syntheticEvidence]) | i <- assumptions]
                    )
        , testGroup
            "refuses when any obligation is open"
            ( [ testCase ("only " ++ T.unpack i ++ " open") $
                    parityThrough assumptions (Just 2) (Just 1) (allOpenExcept (filter (/= i) assumptions))
                        @?= Left (ObligationsUnmet [unmet StillOpen i])
              | i <- assumptions
              ]
                ++ [ testCase "all open" $
                        parityThrough assumptions (Just 2) (Just 1) (map opened assumptions)
                            @?= Left (ObligationsUnmet (map (unmet StillOpen) assumptions))
                   , testProperty "any non-empty set open: refused, naming exactly those, in document order" $
                        forAll (sublistOf assumptions `suchThat` (not . null)) anySubsetOpen
                   ]
            )
        , testCase "an open obligation with evidence is still open" $
            parityThrough assumptions (Just 2) (Just 1) (("A3", "open", ["partial reading"]) : map discharged (filter (/= "A3") assumptions))
                @?= Left (ObligationsUnmet [unmet StillOpen "A3"])
        , testCase "discharged with no evidence is not evidence" $
            parityThrough assumptions (Just 2) (Just 1) (("A2", "discharged", []) : map discharged (filter (/= "A2") assumptions))
                @?= Left (ObligationsUnmet [unmet NoEvidenceRecorded "A2"])
        , testCase "discharged with blank evidence is not evidence" $
            parityThrough assumptions (Just 2) (Just 1) (("A2", "discharged", ["", "  \n"]) : map discharged (filter (/= "A2") assumptions))
                @?= Left (ObligationsUnmet [unmet NoEvidenceRecorded "A2"])
        , testCase "refuted is not discharged, whatever evidence it has" $
            parityThrough assumptions (Just 2) (Just 1) (("A2", "refuted", ["a counterexample"]) : map discharged (filter (/= "A2") assumptions))
                @?= Left (ObligationsUnmet [unmet RefutedObligation "A2"])
        , testCase "an obligation the ledger omits is refused" $
            parityThrough assumptions (Just 2) (Just 1) (map discharged (filter (/= "A5") assumptions))
                @?= Left (ObligationsUnmet [unmet MissingFromLedger "A5"])
        , testCase "an entry that lists nothing is refused, not vacuous" $
            parityThrough assumptions (Just 2) (Just 1) []
                @?= Left (ObligationsUnmet (map (unmet MissingFromLedger) assumptions))
        , testCase "a new row in rank-bound.md closes the gate by itself" $
            parityThrough (assumptions ++ ["A6"]) (Just 2) (Just 1) (map discharged assumptions)
                @?= Left (ObligationsUnmet [unmet MissingFromLedger "A6"])
        , testCase "a row removed from rank-bound.md is refused until the ledger follows" $
            parityThrough (filter (/= "A5") assumptions) (Just 2) (Just 1) (map discharged assumptions)
                @?= Left (ObligationsUnmet [unmet NotInDoc "A5"])
        , testCase "every problem is listed, in document order, ledger-only ones last" $
            parityThrough
                ["A1", "A2", "A3", "A4", "A5"]
                (Just 2)
                (Just 1)
                [ ("A9", "discharged", [syntheticEvidence])
                , ("A4", "refuted", ["a counterexample"])
                , ("A3", "discharged", [])
                , ("A2", "open", [])
                , ("A5", "discharged", [syntheticEvidence])
                ]
                @?= Left
                    ( ObligationsUnmet
                        [ unmet MissingFromLedger "A1"
                        , unmet StillOpen "A2"
                        , unmet NoEvidenceRecorded "A3"
                        , unmet RefutedObligation "A4"
                        , unmet NotInDoc "A9"
                        ]
                    )
        , testGroup
            "scope"
            [ testCase "another target is another scope" $
                refusedElsewhere scope{scopeTarget = "another target"}
            , testCase "another conversion is another scope: bare is not pipeline" $
                refusedElsewhere scope{scopeConversion = "another conversion"}
            , testCase "another domain is another scope" $
                refusedElsewhere scope{scopeDomain = "another domain"}
            , testCase "another oracle is another scope: a verdict can flip with the oracle" $
                refusedElsewhere scope{scopeOracle = "another oracle"}
            , testCase "the entry for this scope is the one read: another scope's evidence does not count" $
                let other = scope{scopeOracle = "another oracle"}
                    evidence =
                        (,)
                            <$> obligationsInDoc (docOf assumptions)
                            <*> parseLedger
                                ( ledgerOf
                                    [ entryJson other (Just 2) (Just 1) (map discharged assumptions)
                                    , entryJson scope (Just 2) (Just 1) (map opened assumptions)
                                    ]
                                )
                 in refusalOf (gate evidence parityConditional)
                        @?= Just (ObligationsUnmet (map (unmet StillOpen) assumptions))
            , testCase "and the reverse: another scope's open entry does not block this one, and the proof names this one" $
                let other = scope{scopeOracle = "another oracle"}
                    evidence =
                        (,)
                            <$> obligationsInDoc (docOf assumptions)
                            <*> parseLedger
                                ( ledgerOf
                                    [ entryJson other (Just 9) (Just 9) (map opened assumptions)
                                    , entryJson scope (Just 2) (Just 1) (map discharged assumptions)
                                    ]
                                )
                 in fmap (proofScope . provedProof) (gate evidence parityConditional) @?= Right scope
            ]
        , testGroup
            "the recorded abstraction must be the declared one"
            [ testCase "a null k with every obligation discharged is refused" $
                parityThrough assumptions Nothing (Just 1) (map discharged assumptions)
                    @?= Left AbstractionNotRecorded
            , testCase "a null k_V with every obligation discharged is refused" $
                parityThrough assumptions (Just 2) Nothing (map discharged assumptions)
                    @?= Left AbstractionNotRecorded
            , testCase "a smaller declared k than recorded is refused" $
                parityThrough assumptions (Just 6) (Just 1) (map discharged assumptions)
                    @?= Left (AbstractionDiffers (6, 1) (2, 1))
            , testCase "a different k_V is refused" $
                parityThrough assumptions (Just 2) (Just 3) (map discharged assumptions)
                    @?= Left (AbstractionDiffers (2, 3) (2, 1))
            , testCase "open obligations are reported before a missing k" $
                parityThrough assumptions Nothing Nothing (map opened assumptions)
                    @?= Left (ObligationsUnmet (map (unmet StillOpen) assumptions))
            ]
        , testCase "PROVED can carry a violation: the theorem's conclusion is a minimal gap" $
            let bound = issue (coverage id) parityAbstraction paritySubject
             in fmap (boundVerdict . proofBound . provedProof) (gate (fullEvidence 2 1) bound)
                    @?= Right (ViolatedAt "a")
        ]
  where
    refusedElsewhere other =
        refusalOf (gateIn other (fullEvidence 2 1) parityConditional) @?= Just (NoLedgerEntry other)

committedLedgerTests :: TestTree
committedLedgerTests =
    testGroup
        "the committed ledger leaves PROVED refused today; this is meant to fail when evidence is recorded"
        ( [ testCase (T.unpack conversion ++ ": all five obligations are named open") $
                committedRefusal (committedScope conversion)
                    >>= (@?= Just (ObligationsUnmet (map (unmet StillOpen) assumptions)))
          | conversion <-
                [ "bare: ReductionProdOpConversionPattern"
                , "bare: ReductionOpConversionPattern (ttir.sum)"
                , "pipeline"
                ]
          ]
            ++ [ testCase "a closure the ledger does not list has no entry" $
                    committedRefusal (committedScope "bare: anything else")
                        >>= (@?= Just (NoLedgerEntry (committedScope "bare: anything else")))
               , testCase "a ledger file that cannot be read leaves PROVED refused" $ do
                    evidence <- readEvidence "docs/theory/rank-bound.md" "data/no-such-ledger.json"
                    refusalOf (reportProved (parityReport evidence))
                        @?= Just (EvidenceUnusable (Unreadable "data/no-such-ledger.json"))
               ]
        )
  where
    committedRefusal within = do
        evidence <- readEvidence "docs/theory/rank-bound.md" "data/rank-ledger-tt-mlir-f9dc1b3e5101.json"
        pure (refusalOf (gateIn within evidence parityConditional))

certificateTests :: TestTree
certificateTests =
    testGroup
        "the certificate, from Corollary 2"
        [ testCase "a pattern that applies to no valid case below N, with PROVED, gets one" $
            let certificate = certificateFor "P"
             in (certifiedPattern certificate, certifiedScope certificate, certifiedBound certificate)
                    @?= ("P", scope, 2)
        , testCase "a pattern seen on a valid case below N does not, and the witness is minimal" $
            refusalOf (certifyUnreachable (provedFor (neverAppliesQuestion "Q")))
                @?= Just (PatternApplies "a")
        , testCase "a coverage proof is not a certificate about a pattern" $
            refusalOf (certifyUnreachable (either (error . show) id (gate (fullEvidence 2 1) parityConditional)))
                @?= Just (NotAboutAPattern :: CertificateRefusal Char)
        , testCase "only a Proved mints one: with an open obligation there is nothing to pass it" $
            refusalOf (gate (evidenceFor assumptions (Just 2) (Just 1) (allOpenExcept ["A1", "A2", "A4", "A5"])) (issue (neverAppliesQuestion "P") patternAbstraction patternSubject))
                @?= Just (ObligationsUnmet [unmet StillOpen "A3"])
        , testGroup
            "markUnreachable"
            [ testCase "sets Unreachable, naming this certificate, and keeps the pattern and its counts" $
                case markUnreachable (certificateFor "P") (entryFor "P" (NotObserved [])) of
                    Right (DomainEntry registered counts (Unreachable held)) -> do
                        registered @?= RegisteredPattern "P" Nothing
                        counts @?= [(Registered, 3)]
                        unreachableCertificate held @?= certificateFor "P"
                    other -> assertFailure ("expected Unreachable, got " ++ show other)
            , testCase "a certificate for another pattern is refused, naming the certificate's" $
                refusalOf (markUnreachable (certificateFor "P") (entryFor "R" (NotObserved [])))
                    @?= Just (CertificateForOtherPattern "P")
            , testCase "an observed survival contradicts it" $
                refusalOf (markUnreachable (certificateFor "P") (entryFor "P" ObservedSurvived))
                    @?= Just (CertificateContradicted ObservedSurvived)
            , testCase "an observed application contradicts it" $
                refusalOf (markUnreachable (certificateFor "P") (entryFor "P" ObservedApplied))
                    @?= Just (CertificateContradicted ObservedApplied)
            , testCase "an observed rollback contradicts it, on the stricter reading" $
                refusalOf (markUnreachable (certificateFor "P") (entryFor "P" ObservedRolledBack))
                    @?= Just (CertificateContradicted ObservedRolledBack)
            , testCase "another pattern is reported before a contradiction: it would not be about this one" $
                refusalOf (markUnreachable (certificateFor "P") (entryFor "R" ObservedSurvived))
                    @?= Just (CertificateForOtherPattern "P")
            ]
        ]

reportTests :: TestTree
reportTests =
    testGroup
        "the report"
        [ testGroup
            "rankReport"
            [ testCase "the empirical output uses the window and the subject" $
                reportEmpirical (parityReport (fullEvidence 2 1)) @?= empirical 2 paritySubject
            , testCase "the conditional output is conditional's" $
                reportConditional (parityReport (fullEvidence 2 1)) @?= Right parityConditional
            , testCase "the proved output is proved's, for the scope given" $
                fmap provedProof (reportProved (parityReport (fullEvidence 2 1)))
                    @?= fmap provedProof (gate (fullEvidence 2 1) parityConditional)
            , testCase "evidence that cannot be used refuses PROVED and leaves CONDITIONAL alone" $
                let result = parityReport (Left (Unreadable "a path"))
                 in (reportConditional result, refusalOf (reportProved result))
                        @?= (Right parityConditional, Just (EvidenceUnusable (Unreadable "a path")))
            , testCase "a refused CONDITIONAL is the reason PROVED gives, ahead of unusable evidence" $
                refusalOf (reportProved (report (coverage not) Nothing (Left (Unreadable "a path")) (allValid ab 3 equalCounts)))
                    @?= Just NoConditionalBound
            ]
        , testGroup
            "highestLevel"
            [ testCase "PROVED, with everything" $
                highestLevel (parityReport (fullEvidence 2 1)) @?= ProvedLevel
            , testCase "CONDITIONAL, with an open obligation" $
                highestLevel (parityReport (evidenceFor assumptions (Just 2) (Just 1) (map opened assumptions)))
                    @?= ConditionalLevel
            , testCase "EMPIRICAL, with no abstraction" $
                highestLevel (report neverViolated Nothing (fullEvidence 2 1) paritySubject) @?= EmpiricalLevel
            ]
        , testCase "levelName gives the three labels" $
            map levelName [minBound .. maxBound] @?= ["EMPIRICAL", "CONDITIONAL", "PROVED"]
        , testGroup
            "renderRankReport"
            [ testCase "three lines, one per level, each labelled, in order" $
                labels (renderRankReport (parityReport (fullEvidence 2 1)))
                    @?= ["EMPIRICAL", "CONDITIONAL", "PROVED"]
            , testCase "refused levels are labelled too, and say REFUSED" $ do
                let text = renderRankReport (equalCountsReport Nothing)
                labels text @?= ["EMPIRICAL", "CONDITIONAL", "PROVED"]
                refusedAt "CONDITIONAL" text
                refusedAt "PROVED" text
            , testCase "CONDITIONAL gives N and its factors" $ do
                let line = lineOf "CONDITIONAL" (renderRankReport (parityReport (fullEvidence 2 1)))
                mentions line "N = 2"
                mentions line "k = 2"
                mentions line "k_V = 1"
            , testCase "CONDITIONAL refused for short ranks still gives N" $ do
                let line = lineOf "CONDITIONAL" (renderRankReport (report neverViolated (Just parityAbstraction) (fullEvidence 2 1) (allValid ab 2 oddA)))
                mentions line "REFUSED"
                mentions line "N = 2"
            , testCase "PROVED, when it holds, gives N and is not refused" $ do
                let line = lineOf "PROVED" (renderRankReport (parityReport (fullEvidence 2 1)))
                mentions line "N = 2"
                assertBool (show line) (not ("REFUSED" `T.isInfixOf` line))
            , testCase "PROVED refused names the open obligations" $ do
                let line = lineOf "PROVED" (renderRankReport (parityReport (evidenceFor assumptions (Just 2) (Just 1) (allOpenExcept ["A1", "A2", "A4", "A5"]))))
                mentions line "REFUSED"
                mentions line "A3"
            , testCase "EMPIRICAL says where it settled" $
                mentions (lineOf "EMPIRICAL" (renderRankReport (parityReport (fullEvidence 2 1)))) "stable from rank 1"
            , testCase "EMPIRICAL says when it did not" $
                mentions (lineOf "EMPIRICAL" (renderRankReport (equalCountsReport Nothing))) "not stable by rank 7"
            , testCase "EMPIRICAL claims no bound, by rule 4" $ do
                let line = lineOf "EMPIRICAL" (renderRankReport (parityReport (fullEvidence 2 1)))
                assertBool (show line) (not ("N =" `T.isInfixOf` line))
                mapM_
                    (\word -> assertBool (show line ++ " says " ++ show word) (not (word `T.isInfixOf` T.toLower line)))
                    ["bound", "proved", "certif", "all ranks", "every rank"]
            ]
        ]
