RMARKDOWNSRC := $(shell ls site/posts/*.rmd)
RMARKEDDOWN := $(RMARKDOWNSRC:.rmd=.md)

.PHONY: build
build: $(RMARKEDDOWN) deps/sitehakyll/.docker
	docker run --rm -u $$(id -u):$$(id -g) -v $$PWD/site:/site -w /site vizowl/ffwd-fish ffwd-fish-site build

.PHONY: watch
watch: $(RMARKEDDOWN) deps/sitehakyll/.docker
	docker run --rm -u $$(id -u):$$(id -g) -v $$PWD/site:/site -w /site vizowl/ffwd-fish ffwd-fish-site watch

.PHONY: deploy
deploy:
	echo "hello"

deps/%/.docker: deps/%/Dockerfile deps/%/*
	docker build -t "ffwd-fish/$*" deps/$*
	touch $@

site/posts/%.md: site/posts/%.rmd deps/siter/.docker
	docker run --rm -u $$(id -u):$$(id -g) -v $$PWD/site/posts:/work \
		-w /work ffwd-fish/siter Rscript -e 'require("rmarkdown"); rmarkdown::render("$(<F)")'

