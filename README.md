# FFWD-Fish

Future Fisheries under climate change

## Building the site

This site requires haskell, ruby and R to build.

### Haskell part

On Ubuntu ```apt-get install ghc cabal-install``` and on a mac
(assuming you have [homebrew](http://brew.sh/))
```brew install ghc cabal-install```. Then run:

```
cabal update
cd site
cabal sandbox init  # if you are on ubuntu you may have to skip this step
cabal install --only-dependencies
```

### Ruby part

Assuming you have ruby installed run

```
gem install sass
```

### R part

Assuming you have R installed start the R interpreter and run ```install.packages('rmarkdown')```

