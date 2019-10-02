
module Strategy.Python.ReqTxt
  ( discover
  , strategy
  , analyze
  , configure
  )
  where

import Prologue hiding ((<?>), many, some)

import           Polysemy
import           Polysemy.Error
import           Polysemy.Output
import           Text.Megaparsec
import           Text.Megaparsec.Char

import           Config
import qualified Graph as G
import           Discovery.Core
import           Discovery.Walk
import           Effect.ReadFS
import           Strategy
import           Strategy.Python.Util
import           Types

discover :: Members '[Embed IO, Output ConfiguredStrategy] r => Path Abs Dir -> Sem r ()
discover = walk $ \_ _ files -> do
  case find (\f -> fileName f == "requirements.txt") files of
    Nothing -> walkContinue
    Just file  -> do
      output (configure file)
      walkContinue

strategy :: Strategy BasicFileOpts
strategy = Strategy
  { strategyName = "python-requirements"
  , strategyAnalyze = analyze
  }

analyze :: Members '[Error CLIErr, ReadFS, Embed IO] r => BasicFileOpts -> Sem r G.Graph
analyze BasicFileOpts{..} = do
  contents <- readContentsText targetFile
  case runParser requirementsTxtParser "source" contents of
    Left err -> throw $ StrategyFailed $ "failed to parse requirements.txt " <> show err -- TODO: better error
    Right a -> pure $ buildGraph a

type Parser = Parsec Void Text

requirementsTxtParser :: Parser [Req]
requirementsTxtParser = requirementParser `sepBy` newline

configure :: Path Rel File -> ConfiguredStrategy
configure = ConfiguredStrategy strategy . BasicFileOpts