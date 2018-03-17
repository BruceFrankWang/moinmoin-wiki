# VERSION 0.5
# AUTHOR:         Olav Grønås Gjerde <olav@backupbay.com>
# DESCRIPTION:    Image with MoinMoin wiki, uwsgi, nginx and self signed SSL
# TO_BUILD:       docker build -t moinmoin .
# TO_RUN:         docker run -it -p 80:80 -p 443:443 --name my_wiki moinmoin

FROM arm32v7/debian:stretch-slim

LABEL maintainer="Bruce Frank Wang <bruce.frank.wang@gmail.com>" \
    forked_from="olavgg/moinmoin-wiki <https://github.com/olavgg/moinmoin-wiki>"

# Set the variables
ENV MM_FILE=moin-1.9.9.tar.gz \
    MM_URL=http://static.moinmo.in/files \
    MM_SHA256SUM=4397d7760b7ae324d7914ffeb1a9eeb15e09933b61468072acd3c3870351efa4 \
    MM_PATCH_URL=https://bitbucket.org/thomaswaldmann/moin-1.9/commits \
    MM_PATCH_ID=561b7a9c2bd91b61d26cd8a5f39aa36bf5c6159e

# Whether change the repository to USTC mirror.
ARG USE_CN_REPO=FALSE

# Change the repository or not
RUN echo "MoinMoin 1.9.9 wiki engine Docker image!"; \
    if [ "$(echo ${USE_CN_REPO} | tr [:lower:] [:upper:])" = "TRUE" ]; then \
        echo "Changing the repositories..."; \
        cp /etc/apt/sources.list /etc/apt/backup-sources.list && \
        sed -i \
            -e 's/http:\/\/security.debian.org/http:\/\/mirrors.ustc.edu.cn\/debian-security/g' \
            -e 's/http:\/\/deb.debian.org/http:\/\/mirrors.ustc.edu.cn/g' \
            /etc/apt/sources.list; \
    else \
        echo "Using the official repositories."; \
    fi

# Install software
RUN apt-get update && apt-get install -y --no-install-recommends \
    python \
    curl \
    openssl \
    nginx \
    uwsgi \
    uwsgi-plugin-python \
    rsyslog

# Download MoinMoin
RUN curl -Ok ${MM_URL}/${MM_FILE} && \
    if [ "${MM_SHA256SUM}" != "$(sha256sum ${MM_FILE} | awk '{print($1)}')" ]; then \
        exit 1; \
    fi; \
    mkdir moinmoin && \
    tar xf ${MM_FILE} -C moinmoin --strip-components=1

# Install MoinMoin
ADD wikiconfig.py /moinmoin
ADD logo.png /moinmoin
RUN cd moinmoin && \
    python setup.py install --force --prefix=/usr/local && \
    mv /moinmoin/wikiconfig.py /usr/local/share/moin/ && \
    mv /moinmoin/logo.png /usr/local/lib/python2.7/dist-packages/MoinMoin/web/static/htdocs/common/ && \
    chown -Rh www-data:www-data /usr/local/share/moin/underlay && \
    chown -R www-data:www-data /usr/local/share/moin/data

# Configure nginx
ADD nginx.conf /etc/nginx/
ADD moinmoin.conf /etc/nginx/sites-available/
RUN mkdir -p /var/cache/nginx/cache && \
    ln -s \
        /etc/nginx/sites-available/moinmoin.conf \
        /etc/nginx/sites-enabled/moinmoin.conf && \
    rm /etc/nginx/sites-enabled/default

# Create self signed certificate
ADD generate_ssl_key.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/generate_ssl_key.sh && \
    /usr/local/bin/generate_ssl_key.sh moinmoin.example.org && \
    mv cert.pem /etc/ssl/certs/ && \
    mv key.pem /etc/ssl/private/

# Cleanup
RUN rm ${MM_FILE} && \
    rm -rf /moinmoin && \
    apt-get purge -qqy curl && \
    apt-get autoremove -qqy && apt-get clean && \
    rm -rf /tmp/* /var/lib/apt/lists/*

VOLUME /usr/local/share/moin/data

EXPOSE 80

CMD service rsyslog start && \
    service nginx start && \
    uwsgi --uid www-data \
        -s /tmp/uwsgi.sock \
        --plugins python \
        --pidfile /var/run/uwsgi-moinmoin.pid \
        --wsgi-file server/moin.wsgi \
        -M -p 4 \
        --chdir /usr/local/share/moin \
        --python-path /usr/local/share/moin \
        --harakiri 30 \
        --die-on-term
