RMARKDOWNSRC := $(shell ls site/posts/*.rmd)
RMARKEDDOWN := $(RMARKDOWNSRC:.rmd=.md)
SITEBUILDER := $(shell cd deps/sitehakyll && stack path --local-install-root)/bin/ffwd-fish-site
HASDOCKER ?= $(shell which docker)
.PHONY: watch site clean deploy
.SECONDARY:

site: $(SITEBUILDER) $(RMARKEDDOWN)
	cd site && $(SITEBUILDER) build

watch: $(SITEBUILDER) $(RMARKEDDOWN)
	cd site && $(SITEBUILDER) watch

clean: $(SITEBUILDER)
	cd site && $(SITEBUILDER) clean

$(SITEBUILDER): deps/sitehakyll/site.hs \
								deps/sitehakyll/ffwd-fish-site.cabal \
								deps/sitehakyll/stack.yaml
	$(if $(HASDOCKER),cd deps/sitehakyll && stack docker pull)
	cd deps/sitehakyll && stack $(if $(HASDOCKER),--docker) build

deps/%/.docker: deps/%/Dockerfile deps/%/*
	$(if $(HASDOCKER),docker build -t "ffwdfish/$*" deps/$*)
	touch $@

site/posts/%.md: site/posts/%.rmd deps/siter/.docker
	$(if $(HASDOCKER),docker run --rm -u $$(id -u):$$(id -g) -v $$PWD:/work -w /work ffwdfish/siter) \
		Rscript -e 'require("rmarkdown"); rmarkdown::render("$(<)",output_options =list(variant = "markdown"))'

deploy: ../FFWD-Fish-gh-pages site
ifeq (refs/heads/gh-pages,$(shell cd ../FFWD-Fish-gh-pages && git symbolic-ref HEAD))
	cp -r site/_site/* $<
	cd $< && git add -A && git commit -amdeploy && git push origin gh-pages
endif
