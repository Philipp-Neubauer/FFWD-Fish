RMARKDOWNSRC := $(shell ls site/posts/*.rmd)
RMARKEDDOWN := $(RMARKDOWNSRC:.rmd=.md)

.PHONY: watch site

site: deps/sitehakyll/dist/build/ffwd-fish-site/ffwd-fish-site $(RMARKEDDOWN)
	cd site && ../deps/sitehakyll/dist/build/ffwd-fish-site/ffwd-fish-site build

watch: deps/sitehakyll/dist/build/ffwd-fish-site/ffwd-fish-site $(RMARKEDDOWN)
	cd site && ../deps/sitehakyll/dist/build/ffwd-fish-site/ffwd-fish-site watch

deps/sitehakyll/dist/build/ffwd-fish-site/ffwd-fish-site: 	deps/sitehakyll/site.hs \
															deps/sitehakyll/ffwd-fish-site.cabal \
															deps/sitehakyll/.cabal-sandbox/bin/hakyll-init
	cd deps/sitehakyll && cabal build

deps/sitehakyll/.cabal-sandbox/bin/hakyll-init: deps/sitehakyll/cabal.sandbox.config
	cd deps/sitehakyll && cabal install --only-dependencies

deps/sitehakyll/cabal.sandbox.config:
	cd deps/sitehakyll && cabal sandbox init

site/posts/%.md: site/posts/%.rmd
	Rscript -e 'require("rmarkdown"); rmarkdown::render("$(<)")'
