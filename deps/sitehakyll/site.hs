--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import           Hakyll
--------------------------------------------------------------------------------

main :: IO ()
main = hakyll $ do
    match ("images/*" .||. "posts/**/*.png" .||. "posts/**/*.pdf") $ do
        route   idRoute
        compile copyFileCompiler

    match "stylesheets/**.scss" $ compile getResourceBody

    match "posts/include/biblio/bib/*.bib" $ compile biblioCompiler

    match "posts/include/biblio/csl/*.csl" $ compile cslCompiler

    scssDependencies <- makePatternDependency "stylesheets/**.scss"
    rulesExtraDependencies [scssDependencies] $
        create ["css/style.css"] $ do
           route idRoute
           compile sassCompiler

    match "*.md" $ do
        route   $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= relativizeUrls

    bibDependencies <- makePatternDependency "posts/include/biblio/bib/*.bib"
    cslDependencies <- makePatternDependency "posts/include/biblio/csl/*.csl"
    rulesExtraDependencies [bibDependencies, cslDependencies] $
      match "posts/*.md" $ do
        route $ setExtension "html"
        compile $ pandocBiblioCompiler "posts/include/biblio/csl/ecology.csl" "posts/include/biblio/bib/FFF.bib"
            >>= loadAndApplyTemplate "templates/post.html"    postCtx
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= relativizeUrls

    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*.md"
            let archiveCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Archives"            `mappend`
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls


    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*.md"
            let indexCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    defaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateCompiler


--------------------------------------------------------------------------------
postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y" `mappend`
    defaultContext

--------------------------------------------------------------------------------
sassCompiler :: Compiler (Item String)
sassCompiler = loadBody (fromFilePath "stylesheets/ffwd-fish.scss")
    >>= makeItem
    >>= withItemBody (unixFilter "scss" ["-s", "-C", "-I", "stylesheets"])
    >>= return . fmap compressCss
