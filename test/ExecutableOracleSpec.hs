{-# LANGUAGE OverloadedStrings #-}

module ExecutableOracleSpec (tests) where

import Data.Aeson (Value, encode, object, (.=))
import Data.ByteString.Lazy.Char8 qualified as Lazy
import Data.Maybe (catMaybes)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import LowerAudit.Classify (ValidityVerdict (..), validityVerdict)
import LowerAudit.Concretize (Representative (..), concretize)
import LowerAudit.Domain (ConcreteCase (..), Dim (..), ElementType (..), Params (..), ReduceOp (..))
import LowerAudit.Enumerate (enumerate)
import LowerAudit.Oracle (Violation (..), vTtir)
import LowerAudit.Render (renderCase)
import LowerAudit.Run (RunOptions (..), Tool (..), runValidity, ttmlirTarget)
import ProbeSpec (liveCase)
import System.Directory (createDirectoryIfMissing)
import System.FilePath (takeDirectory, (</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertFailure, testCase, (@?=))

findingsPath :: FilePath
findingsPath = "findings/executable-oracle.jsonl"

everyNth :: Int -> [a] -> [a]
everyNth n xs = case xs of
    [] -> []
    x : _ -> x : everyNth n (drop n xs)

generatedSample :: [ConcreteCase]
generatedSample =
    [concretize rep c | rep <- [Rep2, Rep3, Rep7], c <- everyNth 97 (enumerate 3)]

prodF32 :: Params
prodF32 = Params Prod F32 False

invalidControls :: [ConcreteCase]
invalidControls =
    [ ConcreteCase prodF32 [Size 128, Size 10] [Size 128] (Just [-3])
    , ConcreteCase prodF32 [Size 128, Size 10] [Size 128] (Just [2])
    , ConcreteCase prodF32 [Size 128, Size 10, Size 32, Size 4] [Size 128] (Just [1, 2, 3, 2])
    , ConcreteCase prodF32 [Size 128, Size 16, Size 32] [Size 128, Size 16, Size 1] (Just [2])
    , ConcreteCase prodF32 [Size 2] [Size 2, Size 2, Size 1] (Just [0])
    ]

agree :: Either Violation () -> ValidityVerdict -> Bool
agree declared executable = case (declared, executable) of
    (Right (), ValidityAccepted) -> True
    (Left _, ValidityRejected) -> True
    _ -> False

finding :: Text -> Either Violation () -> ValidityVerdict -> Maybe Value
finding text declared executable
    | agree declared executable = Nothing
    | otherwise =
        Just
            ( object
                [ "case" .= text
                , "declared" .= show declared
                , "executable" .= show executable
                ]
            )

writeFindings :: FilePath -> [Value] -> IO ()
writeFindings path found = do
    createDirectoryIfMissing True (takeDirectory path)
    Lazy.writeFile path (Lazy.unlines (map encode found))

judge :: FilePath -> FilePath -> (Int, ConcreteCase) -> IO (Maybe Value)
judge tool dir (i, c) = do
    let text = renderCase c
        path = dir </> ("case-" <> show i <> ".mlir")
    TextIO.writeFile path text
    result <- runValidity tool ttmlirTarget (RunOptions 60 False Nothing) path
    pure (finding text (vTtir c) (validityVerdict result))

tests :: TestTree
tests =
    testGroup
        "executable oracle"
        [ testGroup
            "a disagreement is never hidden"
            [ testCase "both accept" $ agree (Right ()) ValidityAccepted @?= True
            , testCase "accepted by declaration, rejected by the tool" $ agree (Right ()) ValidityRejected @?= False
            , testCase "rejected by declaration, accepted by the tool" $ agree (Left DimsNotUnique) ValidityAccepted @?= False
            , testCase "both reject" $ agree (Left DimsNotUnique) ValidityRejected @?= True
            , testCase "a tool that cannot judge is not agreement, even with a declared rejection" $
                agree (Left DimsNotUnique) (ValidityInconclusive "x") @?= False
            , testCase "a tool that cannot judge is not agreement with a declared acceptance" $
                agree (Right ()) (ValidityInconclusive "x") @?= False
            , testCase "findings land in the file, one line each" $
                withSystemTempDirectory "lower-audit" $ \dir -> do
                    let path = dir </> "nested" </> "findings.jsonl"
                        found = catMaybes [finding "a" (Right ()) ValidityRejected, finding "b" (Right ()) ValidityAccepted]
                    writeFindings path found
                    written <- TextIO.readFile path
                    length (Text.lines written) @?= 1
            ]
        , liveCase "V_ttir and ttmlir-opt agree on a sample and on F2-F6" TtmlirOpt $ \tool ->
            withSystemTempDirectory "lower-audit" $ \dir -> do
                found <- catMaybes <$> mapM (judge tool dir) (zip [0 ..] (generatedSample ++ invalidControls))
                writeFindings findingsPath found
                case found of
                    [] -> pure ()
                    _ -> assertFailure (show (length found) <> " disagreements in " <> findingsPath)
        ]
