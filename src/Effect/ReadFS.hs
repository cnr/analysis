
{-# language TemplateHaskell #-}

module Effect.ReadFS
  ( ReadFS(..)
  , readFSToIO

  , readContentsBS
  , readContentsText
  , doesFileExist
  , doesDirExist

  , fileInputParser
  , fileInputJson
  ) where

import Prologue

import           Control.Exception hiding (throw)
import qualified Data.ByteString as BS
import qualified Data.Text as T
import           Data.Text.Encoding (decodeUtf8)
import           Path (Dir, File, Path, toFilePath)
import qualified Path.IO as PIO
import           Polysemy
import           Polysemy.Error hiding (catch)
import           Polysemy.Input
import           Text.Megaparsec (Parsec, runParser)

import Diagnostics

data ReadFS m a where
  ReadContentsBS   :: Path b File -> ReadFS m ByteString
  ReadContentsText :: Path b File -> ReadFS m Text
  DoesFileExist    :: Path b File -> ReadFS m Bool
  DoesDirExist     :: Path b Dir  -> ReadFS m Bool

makeSem ''ReadFS

type Parser = Parsec Void Text

fileInputParser :: Members '[ReadFS, Error CLIErr] r => Parser a -> Path b File -> InterpreterFor (Input a) r
fileInputParser parser file = interpret $ \case
  Input -> do
    let path = toFilePath file

    contents <- readContentsText file
    case runParser parser path contents of
      Left err -> throw (FileParseError path (T.pack (show err)))
      Right a -> pure a
{-# INLINE fileInputParser #-}

fileInputJson :: (FromJSON a, Members '[ReadFS, Error CLIErr] r) => Path b File -> InterpreterFor (Input a) r
fileInputJson file = interpret $ \case
  Input -> do
    contents <- readContentsBS file
    case eitherDecodeStrict contents of
      Left err -> throw (FileParseError (toFilePath file) (T.pack err))
      Right a -> pure a
{-# INLINE fileInputJson #-}

readFSToIO :: Members '[Embed IO, Error CLIErr] r => InterpreterFor ReadFS r
readFSToIO = interpret $ \case
  ReadContentsBS file -> fromEitherM $
    (Right <$> BS.readFile (toFilePath file))
    `catch`
    (\(e :: IOException) -> pure (Left (FileReadError (toFilePath file) (T.pack (show e)))))
  ReadContentsText file -> fromEitherM $
    (Right . decodeUtf8 <$> BS.readFile (toFilePath file))
    `catch`
    (\(e :: IOException) -> pure (Left (FileReadError (toFilePath file) (T.pack (show e)))))
  DoesFileExist file -> PIO.doesFileExist file
  DoesDirExist dir -> PIO.doesDirExist dir
{-# INLINE readFSToIO #-}
