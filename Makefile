RMARKDOWNSRC := $(shell ls site/posts/*.rmd)
RMARKEDDOWN := $(RMARKDOWNSRC:.rmd=.md)

.PHONY: build
build: $(RMARKEDDOWN) deps/sitehakyll/.docker
	docker run --rm -u $$(id -u):$$(id -g) -v $$PWD/site:/site -w /site ffwdfish/sitehakyll ffwd-fish-site build

.PHONY: watch
watch: $(RMARKEDDOWN) deps/sitehakyll/.docker
	docker run --rm -it -u $$(id -u):$$(id -g) -v $$PWD/site:/site -w /site -p 8000:8000 ffwdfish/sitehakyll ffwd-fish-site watch -h 0.0.0.0

.PHONY: deploy
deploy:
	echo "hello"

deps/%/.docker: deps/%/Dockerfile deps/%/*
	docker build -t "ffwdfish/$*" deps/$*
	touch $@

site/posts/%.md: site/posts/%.rmd deps/siter/.docker
	docker run --rm -u $$(id -u):$$(id -g) -v $$PWD/site/posts:/work \
		-w /work ffwdfish/siter Rscript -e 'require("rmarkdown"); rmarkdown::render("$(<F)")'

