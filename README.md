# FFWD-Fish

[![Build Status](https://travis-ci.org/Philipp-Neubauer/FFWD-Fish.svg?branch=master)](https://travis-ci.org/Philipp-Neubauer/FFWD-Fish)

Future Fisheries under climate change

## Building the site

This site requires haskell, ruby and R to build.

### Haskell part

On a mac
(assuming you have [homebrew](http://brew.sh/))
```brew install haskell-stack ghc cabal-install```. Then run:

On ubuntu
``` wget -q -O- https://s3.amazonaws.com/download.fpcomplete.com/ubuntu/fpco.key | sudo apt-key add - ```

On 14.04
```echo 'deb http://download.fpcomplete.com/ubuntu/trusty stable main'|sudo tee /etc/apt/sources.list.d/fpco.list```

On 12.04
```echo 'deb http://download.fpcomplete.com/ubuntu/precise stable main'|sudo tee /etc/apt/sources.list.d/fpco.list```

then
```sudo apt-get update && sudo apt-get install stack -y```

### Ruby part

Assuming you have ruby installed run

```
gem install sass
```

### R part

Assuming you have R installed start the R interpreter and run ```install.packages('rmarkdown')```

