{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}

module Handler.NewsFeed
  ( getFeedR
  ) where

import Import

import qualified Data.Text.Lazy as LT
import Text.Blaze.Html.Renderer.Text as Text

import qualified Data.Map as M

getFeedR :: Handler TypedContent
getFeedR = do
  docs <- getDocs
  now <- liftIO getCurrentTime
  tups <- liftIO $ loadAllDocs docs
  newsFeed $ feed now tups

data LoadedFeedDocs =
  LoadedFeedDocs
    { ldocsLibraries :: !(Map Text (Page Html))
    , ldocsTutorials :: !(Map Text (Page Html))
    }

loadAllDocs :: Docs -> IO LoadedFeedDocs
loadAllDocs Docs {..} = do
  ldocsLibraries <- loadMap docsLibraries
  ldocsTutorials <- loadMap docsTutorials
  pure LoadedFeedDocs {..}
  where
    loadMap :: Map Text PageHtml -> IO (Map Text (Page Html))
    loadMap = traverse go
    go :: PageHtml -> IO (Page Html)
    go p@Page {..} = do
      body <- pageBody
      pure $ p {pageBody = body}

feed :: UTCTime -> LoadedFeedDocs -> Feed (Route App)
feed now ds =
  let entries = makeEntries ds
   in Feed
        { feedTitle = "FP Complete  Haskell"
        , feedLinkSelf = FeedR
        , feedLinkHome = HomeR
        , feedAuthor = "FP Complete"
        , feedDescription =
            "FP Complete is the leading provider of commercial Haskell tools and services"
        , feedLanguage = "en-us"
        , feedUpdated = maximum $ ncons now $ map feedEntryUpdated entries
        , feedLogo = Just (StaticR img_fplogo_svg, "FP Complete Logo")
        , feedEntries = entries
        }

makeEntries :: LoadedFeedDocs -> [FeedEntry (Route App)]
makeEntries LoadedFeedDocs {..} =
  sortOn (Down . feedEntryUpdated) $
  let makePageEntriesWithRoute rf = mapMaybe (uncurry makePageEntry . first rf) . M.toList
   in concat
        [ makePageEntriesWithRoute LibraryR ldocsLibraries
        , makePageEntriesWithRoute TutorialR ldocsTutorials
        ]

makePageEntry :: Route App -> Page Html -> Maybe (FeedEntry (Route App))
makePageEntry r Page {..} =
  flip fmap pagePublished $ \lu ->
    FeedEntry
      { feedEntryLink = r
      , feedEntryUpdated = lu
      , feedEntryTitle = LT.toStrict $ Text.renderHtml pageTitle
      , feedEntryContent = pageBody
      , feedEntryEnclosure = Nothing
      }
