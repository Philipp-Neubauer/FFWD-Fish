RMARKDOWNSRC := $(shell ls site/posts/*.rmd)
RMARKEDDOWN := $(RMARKDOWNSRC:.rmd=.md)
SITEBUILDER := $(shell cd deps/sitehakyll && stack path --local-install-root)/bin/ffwd-fish-site
.PHONY: watch site

site: $(SITEBUILDER) $(RMARKEDDOWN)
	cd site && $^ build

watch: $(SITEBUILDER) $(RMARKEDDOWN)
	cd site && $^ watch

clean: $(SITEBUILDER)
	cd site && $^ clean

$(SITEBUILDER): deps/sitehakyll/site.hs \
															deps/sitehakyll/ffwd-fish-site.cabal \
															deps/sitehakyll/stack.yaml
	cd deps/sitehakyll && stack build

site/posts/%.md: site/posts/%.rmd
	Rscript -e 'require("rmarkdown"); rmarkdown::render("$(<)")'
