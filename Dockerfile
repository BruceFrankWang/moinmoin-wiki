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
RUN curl -Ok \
  ${MM_URL}/${MM_FILE}
RUN if [ "${MM_SHA256SUM}" != "$(sha256sum ${MM_FILE} | awk '{print($1)}')" ]; then \
        exit 1; \
    fi;
RUN mkdir moinmoin
RUN tar xf ${MM_FILE} -C moinmoin --strip-components=1

# Install MoinMoin
RUN cd moinmoin && python setup.py install --force --prefix=/usr/local
ADD wikiconfig.py /usr/local/share/moin/
# File existed, comment the line below
# RUN mkdir /usr/local/share/moin/underlay
RUN chown -Rh www-data:www-data /usr/local/share/moin/underlay

# No such file or directory, comment
# Because of a permission error with chown I change the user here
# This is related to an known permission issue with Docker and AUFS
# https://github.com/docker/docker/issues/1295
# USER www-data
# RUN cd /usr/local/share/moin/ && tar xf underlay.tar -C underlay --strip-components=1
# USER root
RUN chown -R www-data:www-data /usr/local/share/moin/data
ADD logo.png /usr/local/lib/python2.7/dist-packages/MoinMoin/web/static/htdocs/common/

# Configure nginx
ADD nginx.conf /etc/nginx/
ADD moinmoin.conf /etc/nginx/sites-available/
RUN mkdir -p /var/cache/nginx/cache
RUN ln -s /etc/nginx/sites-available/moinmoin.conf \
  /etc/nginx/sites-enabled/moinmoin.conf
RUN rm /etc/nginx/sites-enabled/default

# Create self signed certificate
ADD generate_ssl_key.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/generate_ssl_key.sh
RUN /usr/local/bin/generate_ssl_key.sh moinmoin.example.org
RUN mv cert.pem /etc/ssl/certs/
RUN mv key.pem /etc/ssl/private/

# Cleanup
RUN rm ${MM_FILE}
RUN rm -rf /moinmoin
# Comment the line below
# RUN rm /usr/local/share/moin/underlay.tar
RUN apt-get purge -qqy curl
RUN apt-get autoremove -qqy && apt-get clean
RUN rm -rf /tmp/* /var/lib/apt/lists/*

VOLUME /usr/local/share/moin/data

EXPOSE 80
EXPOSE 443

CMD service rsyslog start && service nginx start && \
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
