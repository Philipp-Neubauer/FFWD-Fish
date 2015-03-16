FROM r-base

MAINTAINER chris@dragonfly.co.nz

COPY dependencies.r /tmp/
RUN Rscript /tmp/dependencies.r

RUN sed -i 's/http.debian.net/ftp.nz.debian.org/' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
        pandoc &&\
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*