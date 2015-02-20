
deploy: .docker
	docker run --rm -u $$(id -u):$$(id -g) -v $$PWD/site:/site -w /site vizowl/ffwd-fish /app/ffwd-fish-site build
	divshot push
	divshot promote development production

.docker: site/site.hs
	docker build -t "vizowl/ffwd-fish" site
	touch $@
