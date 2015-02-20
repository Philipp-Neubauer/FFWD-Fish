FROM r-base

COPY site.hs /tmp/

RUN sed -i 's/http.debian.net/ftp.nz.debian.org/' /etc/apt/sources.list
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        libbibutils2 liblua5.1 libghc-hakyll-dev ruby &&\
    mkdir /app && ghc /tmp/site.hs -o /app/ffwd-fish-site && \
    apt-get install && \
    apt-get remove -y libghc-hakyll-dev && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*
    
RUN gem install sass
EXPOSE 8000
