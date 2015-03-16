FROM haskell


RUN sed -i 's/http.debian.net/ftp.nz.debian.org/' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
        ruby1.9.1 &&\
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

RUN gem install sass

EXPOSE 8000

COPY ffwd-fish-site.cabal /build/
RUN cabal update && cd /build && cabal install --only-dependencies --global && rm -r /root/.cabal

COPY site.hs /build/
RUN cd /build && cabal install --global
