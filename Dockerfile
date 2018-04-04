# VERSION 1.0
# AUTHOR:         Bruce Frank Wang <bruce.frank.wang@gmail.com>
# DESCRIPTION:    Image with MoinMoin wiki, run on Raspberry Pi with uWSGI and Nginx
# TO_BUILD:
#         docker build -t rpi-moinmoin .
#     to accelerate apt-get update/install speed for people or machine in China:
#         docker build --build-arg USE_CN_REPO=true -t rpi-moinmoin .
#
# TO_RUN:
#        docker run -it -p 80:80 -v {HOST_DIR}:/srv/wiki --name my_wiki rpi-moinmoin

FROM arm32v7/debian:stretch-slim

LABEL maintainer="Bruce Frank Wang <bruce.frank.wang@gmail.com>" \
    forked_from="olavgg/moinmoin-wiki <https://github.com/olavgg/moinmoin-wiki>"

# For people or their machine in China, fetching from the official repository is usually slow.
# It depends on their network, somecase maybe fast.
# So I give people a choice to change the repository to a mirror site in China.
# And I select the USTC (University of Science and Technology of China) mirror site.

ARG USE_CN_REPO=FALSE

# A variable to setting local time.
# Use:
#         docker build ... --build-arg TIMEZONE={LOCAL TIME ZONE} ...
# You can find {LOCAL TIME ZONE} in </usr/share/zoneinfo>, Select a location nearby.
# Use the default value to ignore it, that means , the time zone of your docker container is UTC.

ARG TIMEZONE=UTC

# Change the repository or not
RUN if [ "$(echo ${USE_CN_REPO} | tr [:lower:] [:upper:])" = "TRUE" ]; then \
        cp /etc/apt/sources.list /etc/apt/backup-sources.list && \
        sed -i \
            -e 's|http://security.debian.org|http://mirrors.ustc.edu.cn/debian-security|g' \
            -e 's|http://deb.debian.org|http://mirrors.ustc.edu.cn|g' \
            /etc/apt/sources.list; \
    fi && \
    echo ${TIMEZONE} > /etc/timezone && \
    ln -fs /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata

# Set the variables about MoinMoin.
ENV MM_FILE=moin-1.9.9.tar.gz \
    MM_URL=http://static.moinmo.in/files \
    MM_SHA256SUM=4397d7760b7ae324d7914ffeb1a9eeb15e09933b61468072acd3c3870351efa4 \
    MM_PATCH_URL=https://bitbucket.org/thomaswaldmann/moin-1.9/commits \
    MM_PATCH_ID=561b7a9c2bd91b61d26cd8a5f39aa36bf5c6159e

# Install software
RUN apt-get update -qqy && \
    apt-get install -qqy --no-install-recommends \
        python \
        curl \
        nginx \
        uwsgi \
        uwsgi-plugin-python \
        patch \
        rsyslog

# Download, uncompress, patch and install MoinMoin.
RUN curl -Ok ${MM_URL}/${MM_FILE} && \
    if [ "${MM_SHA256SUM}" != "$(sha256sum ${MM_FILE} | awk '{print($1)}')" ]; then \
        exit 1; \
    fi; \
    mkdir moinmoin && \
    tar xf ${MM_FILE} -C moinmoin --strip-components=1 && \
    curl -Ok "${MM_PATCH_URL}/${MM_PATCH_ID}/raw" && \
    cd moinmoin && \
    patch -p1 </raw && \
    python setup.py install --force --prefix=/usr/local

# Set the variables about MoinMoin instance.
ENV WIKI_SOURCE=/usr/local/share/moin \
    WIKI_HTDOCS=/usr/local/lib/python2.7/dist-packages/MoinMoin/web/static/htdocs \
    WIKI_INSTANCE=/srv/wiki \
    WIKI_NAME="My Personal Wiki" \
    WIKI_ADMIN=WikiAdmin

# Copy files into image.
COPY moinmoin.ini ${WIKI_SOURCE}
COPY nginx.conf /etc/nginx/
COPY moinmoin.conf /etc/nginx/sites-available/
COPY run-moinmoin /usr/bin

# Configure nginx
RUN chmod +x /usr/bin/run-moinmoin && \
    mkdir -p /var/cache/nginx/cache && \
    ln -s \
        /etc/nginx/sites-available/moinmoin.conf \
        /etc/nginx/sites-enabled/moinmoin.conf && \
    rm /etc/nginx/sites-enabled/default

# Cleanup
RUN rm ${MM_FILE} && \
    rm -rf /moinmoin && \
    rm /raw && \
    apt-get purge -qqy curl patch && \
    apt-get autoremove -qqy && \
    apt-get clean -qqy && \
    rm -rf /tmp/* /var/lib/apt/lists/* && \
    unset -v MM_FILE MM_URL MM_SHA256SUM MM_PATCH_URL MM_PATCH_ID

VOLUME ${WIKI_INSTANCE}

EXPOSE 80

CMD /usr/bin/run-moinmoin && \
    service rsyslog start && \
    service nginx start && \
    uwsgi --ini ${WIKI_INSTANCE}/moinmoin.ini    
