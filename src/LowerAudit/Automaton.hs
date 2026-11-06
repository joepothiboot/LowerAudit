{-# OPTIONS_GHC -Wno-unused-top-binds #-}

module LowerAudit.Automaton (
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
) where

data Dfa q a o = IssuedDfa [a] [q] q (q -> a -> q) (q -> o)

data DfaError q a
    = DuplicateLetter a
    | DuplicateState q
    | StartNotDeclared q
    | StepLeavesStates q a q
    deriving (Eq, Show)

data AlphabetMismatch a = AlphabetMismatch [a] [a]
    deriving (Eq, Show)

mkDfa :: (Ord q, Eq a) => [a] -> [q] -> q -> (q -> a -> q) -> (q -> o) -> Either (DfaError q a) (Dfa q a o)
mkDfa = error "TODO: mkDfa"

alphabet :: Dfa q a o -> [a]
alphabet = error "TODO: alphabet"

stateCount :: Dfa q a o -> Int
stateCount = error "TODO: stateCount"

run :: (Eq a) => Dfa q a o -> [a] -> Maybe o
run = error "TODO: run"

productDfa :: (Eq a) => Dfa q a o -> Dfa r a p -> Either (AlphabetMismatch a) (Dfa (q, r) a (o, p))
productDfa = error "TODO: productDfa"

reachableStates :: (Ord q) => Dfa q a o -> [q]
reachableStates = error "TODO: reachableStates"

shortestWord :: (Ord q) => (o -> Bool) -> Dfa q a o -> Maybe [a]
shortestWord = error "TODO: shortestWord"

isEmpty :: (Ord q) => (o -> Bool) -> Dfa q a o -> Bool
isEmpty = error "TODO: isEmpty"
