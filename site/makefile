
MD = $(addsuffix .md, $(basename $(shell find posts/. -iname "*.rmd")))

all: $(MD) dist/build/ffwd-fish-site/ffwd-fish-site

posts/%.md: posts/%.rmd
	cd $(@D); echo $(<F); Rscript -e 'require("rmarkdown"); rmarkdown::render("$(<F)")'

dist/setup-config: site.cabal
	cabal configure

dist/build/ffwd-fish-site/ffwd-fish-site: dist/setup-config site.hs
	cabal build

