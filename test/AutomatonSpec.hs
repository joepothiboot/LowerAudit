module AutomatonSpec (tests) where

import Data.List (find, nub, sort)
import LowerAudit.Automaton (
    AlphabetMismatch (..),
    Dfa,
    DfaError (..),
    alphabet,
    isEmpty,
    mkDfa,
    productDfa,
    reachableStates,
    run,
    shortestWord,
    stateCount,
 )
import RankFixtures (
    Table (..),
    allWords,
    fromTable,
    genPair,
    genTable,
    mustDfa,
    tableAccepts,
    tableSize,
    tableState,
    trackingStates,
 )
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (Gen, Property, elements, forAll, testProperty, (===))

refusal :: Either e b -> Maybe e
refusal = either Just (const Nothing)

mustProduct :: (Eq a, Show a) => Dfa q a o -> Dfa r a p -> Dfa (q, r) a (o, p)
mustProduct left right = either (error . show) id (productDfa left right)

anyTable :: Int -> Gen Table
anyTable maxStates = do
    letters <- elements ["ab", "ba", "abc"]
    genTable letters maxStates

acceptsBAndAa :: Table
acceptsBAndAa =
    Table
        "ab"
        0
        [[1, 3], [2, 4], [4, 4], [4, 4], [4, 4]]
        [False, False, True, True, False]

acceptsAbAndBa :: String -> Table
acceptsAbAndBa letters
    | letters == "ab" = Table letters 0 rowsAb accepting
    | otherwise = Table letters 0 rowsBa accepting
  where
    rowsAb = [[1, 2], [4, 3], [3, 4], [4, 4], [4, 4]]
    rowsBa = [[2, 1], [3, 4], [4, 3], [4, 4], [4, 4]]
    accepting = [False, False, False, True, False]

strandedAccept :: Table
strandedAccept = Table "a" 0 [[0], [0]] [False, True]

lockstep :: Dfa (Int, Int) Char (Bool, Bool)
lockstep = mustProduct (fromTable toggle) (fromTable toggle)
  where
    toggle = Table "a" 0 [[1], [0]] [False, True]

productIsIntersection :: (Table, Table) -> Property
productIsIntersection (t, u) =
    let combined = mustProduct (fromTable t) (fromTable u)
        ws = allWords (tableLetters t) 5
     in map (fmap (uncurry (&&)) . run combined) ws
            === map (\w -> Just (tableAccepts t w && tableAccepts u w)) ws

productKeepsBothOutputs :: (Table, Table) -> Property
productKeepsBothOutputs (t, u) =
    let combined = mustProduct (fromTable t) (fromTable u)
        ws = allWords (tableLetters t) 4
     in map (run combined) ws === map (\w -> Just (tableAccepts t w, tableAccepts u w)) ws

productCountsPairs :: (Table, Table) -> Property
productCountsPairs (t, u) =
    stateCount (mustProduct (fromTable t) (fromTable u)) === tableSize t * tableSize u

productEmptiness :: (Table, Table) -> Property
productEmptiness (t, u) =
    let combined = mustProduct (fromTable t) (fromTable u)
        both w = tableAccepts t w && tableAccepts u w
     in isEmpty (uncurry (&&)) combined
            === not (any both (allWords (tableLetters t) (tableSize t * tableSize u)))

productShortest :: (Table, Table) -> Property
productShortest (t, u) =
    let combined = mustProduct (fromTable t) (fromTable u)
        both w = tableAccepts t w && tableAccepts u w
     in shortestWord (uncurry (&&)) combined
            === find both (allWords (tableLetters t) (tableSize t * tableSize u))

emptinessIsBruteForce :: Table -> Property
emptinessIsBruteForce t =
    isEmpty id (fromTable t)
        === not (any (tableAccepts t) (allWords (tableLetters t) (tableSize t)))

shortestIsFirstInShortlex :: Table -> Property
shortestIsFirstInShortlex t =
    shortestWord id (fromTable t)
        === find (tableAccepts t) (allWords (tableLetters t) (tableSize t))

shortestIsBelowStateCount :: Table -> Bool
shortestIsBelowStateCount t =
    maybe True ((< tableSize t) . length) (shortestWord id (fromTable t))

reachableIsBruteForce :: Table -> Property
reachableIsBruteForce t =
    reachableStates (trackingStates t)
        === sort (nub (map (tableState t) (allWords (tableLetters t) (tableSize t))))

runFollowsTheTable :: Table -> Property
runFollowsTheTable t =
    let ws = allWords (tableLetters t) 4
     in map (run (fromTable t)) ws === map (Just . tableAccepts t) ws

stepsOutTwice :: Int -> Char -> Int
stepsOutTwice 0 'a' = 5
stepsOutTwice 1 'b' = 6
stepsOutTwice q _ = q

stepsOutOnSecondLetter :: Int -> Char -> Int
stepsOutOnSecondLetter 0 'b' = 6
stepsOutOnSecondLetter 1 'a' = 5
stepsOutOnSecondLetter q _ = q

stepsOutFromEach :: Int -> Char -> Int
stepsOutFromEach q _ = q + 10

noForeignStep :: Int -> Char -> Int
noForeignStep q c
    | c == 'z' = error "stepped on a letter outside the alphabet"
    | otherwise = q

tests :: TestTree
tests =
    testGroup
        "LowerAudit.Automaton"
        [ testGroup
            "mkDfa"
            [ testCase "a repeated letter is refused" $
                refusal (mkDfa "aa" [0 :: Int] 0 const (const ())) @?= Just (DuplicateLetter 'a')
            , testCase "a repeated state is refused" $
                refusal (mkDfa "a" [0 :: Int, 0] 0 const (const ())) @?= Just (DuplicateState 0)
            , testCase "a start state that was not declared is refused" $
                refusal (mkDfa "a" [0 :: Int] 9 const (const ())) @?= Just (StartNotDeclared 9)
            , testCase "a step out of the declared states is refused, so k cannot be understated" $
                refusal (mkDfa "ab" [0 :: Int, 1] 0 stepsOutTwice (const ()))
                    @?= Just (StepLeavesStates 0 'a' 5)
            , testCase "the step named is the first by declared state, then declared letter" $
                refusal (mkDfa "ab" [0 :: Int, 1] 0 stepsOutOnSecondLetter (const ()))
                    @?= Just (StepLeavesStates 0 'b' 6)
            , testCase "declared order, not Ord, picks the step named" $
                refusal (mkDfa "ab" [1 :: Int, 0] 0 stepsOutFromEach (const ()))
                    @?= Just (StepLeavesStates 1 'a' 11)
            , testCase "letters outside the alphabet are not stepped on" $
                fmap stateCount (mkDfa "a" [0 :: Int] 0 noForeignStep (const ())) @?= Right 1
            ]
        , testGroup
            "alphabet and stateCount"
            [ testCase "the alphabet keeps its declared order" $
                alphabet (fromTable (acceptsAbAndBa "ba")) @?= "ba"
            , testCase "every declared state counts, reachable or not" $
                stateCount (fromTable strandedAccept) @?= 2
            ]
        , testGroup
            "run"
            [ testCase "the empty word gives the start state's output" $
                run (fromTable strandedAccept) "" @?= Just False
            , testCase "a letter outside the alphabet gives Nothing, without stepping on it" $
                run (mustDfa (mkDfa "a" [0 :: Int] 0 noForeignStep (const ()))) "az" @?= Nothing
            , testCase "a letter outside the alphabet at the start gives Nothing" $
                run (mustDfa (mkDfa "a" [0 :: Int] 0 noForeignStep (const ()))) "za" @?= Nothing
            , testProperty "follows the transition table" $
                forAll (anyTable 6) runFollowsTheTable
            ]
        , testGroup
            "productDfa"
            [ testCase "different letters are refused" $
                refusal (productDfa (fromTable (Table "a" 0 [[0]] [True])) (fromTable (Table "b" 0 [[0]] [True])))
                    @?= Just (AlphabetMismatch "a" "b")
            , testCase "the same letters in another order are refused" $
                refusal (productDfa (fromTable (acceptsAbAndBa "ab")) (fromTable (acceptsAbAndBa "ba")))
                    @?= Just (AlphabetMismatch "ab" "ba")
            , testCase "the alphabet is the operands'" $
                alphabet (mustProduct (fromTable (acceptsAbAndBa "ba")) (fromTable (acceptsAbAndBa "ba"))) @?= "ba"
            , testProperty "the product language is the intersection" $
                forAll (genPair ["ab", "ba", "abc"] 5) productIsIntersection
            , testProperty "the product outputs the pair of outputs" $
                forAll (genPair ["ab", "ba", "abc"] 5) productKeepsBothOutputs
            , testProperty "the product has k * k' states" $
                forAll (genPair ["ab", "ba", "abc"] 5) productCountsPairs
            ]
        , testGroup
            "reachableStates"
            [ testCase "a declared state no word reaches is left out" $
                reachableStates (fromTable strandedAccept) @?= [0]
            , testCase "a product reaches only the pairs a word reaches" $
                reachableStates lockstep @?= [(0, 0), (1, 1)]
            , testProperty "the states some word reaches, ascending, without repeats" $
                forAll (anyTable 6) reachableIsBruteForce
            ]
        , testGroup
            "isEmpty"
            [ testCase "an accepting state no word reaches does not count" $
                isEmpty id (fromTable strandedAccept) @?= True
            , testCase "an accepting start state means the empty word is accepted" $
                isEmpty id (fromTable (Table "a" 0 [[0]] [True])) @?= False
            , testProperty "agrees with brute-force enumeration up to the state count" $
                forAll (anyTable 6) emptinessIsBruteForce
            , testProperty "on a product, agrees with brute-force enumeration" $
                forAll (genPair ["ab", "ba"] 3) productEmptiness
            ]
        , testGroup
            "shortestWord"
            [ testCase "the empty word comes first when it is accepted" $
                shortestWord id (fromTable (Table "a" 0 [[0]] [True])) @?= Just ""
            , testCase "with no letters, only the empty word can be accepted" $
                shortestWord id (fromTable (Table "" 0 [[]] [True])) @?= Just ""
            , testCase "with no letters and a rejecting start, nothing is accepted" $
                shortestWord id (fromTable (Table "" 0 [[]] [False])) @?= Nothing
            , testCase "length comes before letters: b is shorter than aa" $
                shortestWord id (fromTable acceptsBAndAa) @?= Just "b"
            , testCase "letters break a tie: ab before ba" $
                shortestWord id (fromTable (acceptsAbAndBa "ab")) @?= Just "ab"
            , testCase "the declared alphabet sets the order: under ba, ba comes first" $
                shortestWord id (fromTable (acceptsAbAndBa "ba")) @?= Just "ba"
            , testCase "an accepting state no word reaches gives Nothing" $
                shortestWord id (fromTable strandedAccept) @?= Nothing
            , testProperty "is the first accepted word in shortlex order" $
                forAll (anyTable 6) shortestIsFirstInShortlex
            , testProperty "is shorter than the state count" $
                forAll (anyTable 6) shortestIsBelowStateCount
            , testProperty "on a product, is the first word both accept" $
                forAll (genPair ["ab", "ba"] 3) productShortest
            ]
        ]
