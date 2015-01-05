
SITE_DIR = _site
HTML = $(addsuffix .html, $(basename $(shell find site/pages -iname "*.rmd")))

all:
	make site
	make deploy

site: $(HTML) $(SITE_DIR) site/assets/**/*
	rsync -r -u -v site/assets $(HTML) $(SITE_DIR)
	

$(SITE_DIR):
	mkdir -p $(SITE_DIR)

site/pages/%.html:site/pages/%.rmd
	cd $(@D); echo $(<F); Rscript -e 'require("rmarkdown"); rmarkdown::render("$(<F)")'

deploy:
	git subtree push --prefix _site origin gh-pages
