module Main where

import Onchain (tradeSerialized, oneShotSerialized)
import Data.Aeson (ToJSON)
import Data.Aeson.Text (encodeToLazyText)
import qualified Data.Text.Lazy.IO as I
import GHC.Generics (Generic)
import Prelude

data Scripts = Scripts {trade :: String, oneShot :: String} deriving (Show, Generic, ToJSON)

scripts :: Scripts
scripts = Scripts {trade = tradeSerialized, oneShot = oneShotSerialized}

main :: IO ()
main = do
  I.writeFile "scripts.json" (encodeToLazyText scripts)
  putStrLn "Scripts compiled"