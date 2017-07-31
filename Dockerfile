# Musicbrainz docker
FROM quantumobject/docker-baseimage:latest
MAINTAINER Tim Chaubet "tim@chaubet.be"

#quantumobject is a bit late, so replacing xenial by zesty myself
RUN sed -i 's/xenial/zesty/g' /etc/apt/sources.list

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y apache2 \
                       bridge-utils \
                       build-essential \
                       bzip2 \
                       git-core \
                       htop \
                       iptables \
                       iputils-ping \
                       libapache2-mod-php7.0 \
                       libdb-dev \
                       libexpat1-dev \
                       libicu-dev \
                       libltdl7 \
                       libpq-dev \
                       libxml2-dev \
                       net-tools \
                       nodejs \
                       npm \
                       php7.0 \
                       php7.0-mbstring \
                       php7.0-gmp \
                       php7.0-pgsql \
                       php-mcrypt \
                       postgresql-client-9.6 \
                       postgresql-common \
                       postgresql-server-dev-9.6 \
                       redis-server \
                       vim \
                       zip \
 && apt-get -f -y install \
 && apt-get autoclean -y \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /tmp/* /var/tmp/* 
 
# copy base config files
# these will be moved to the volumes using the startup script
ADD www /tmp/www

RUN git clone https://github.com/metabrainz/postgresql-musicbrainz-unaccent.git \
 && git clone https://github.com/metabrainz/postgresql-musicbrainz-collate.git \
 && cd postgresql-musicbrainz-unaccent \
 && make \
 && make install \
 && cd ../postgresql-musicbrainz-collate \
 && make \
 && make install \
 && cd ../ 

### startup scripts ###

#Pre-config scrip that maybe need to be run one time only when the container run the first time .. using a flag to don't 
#run it again ... use for conf for service ... when run the first time ...
RUN mkdir -p /etc/my_init.d
COPY startup.sh /etc/my_init.d/startup.sh
RUN chmod +x /etc/my_init.d/startup.sh
    
# add apache2 deamon to runit
RUN mkdir -p /etc/service/apache2  /var/log/apache2 ; sync 
COPY apache2.sh /etc/service/apache2/run
RUN chmod +x /etc/service/apache2/run \
    && cp /var/log/cron/config /var/log/apache2/ \
    && chown -R www-data /var/log/apache2
    
COPY runonce.sh /sbin/runonce
RUN chmod +x /sbin/runonce; sync \
    && /bin/bash -c /sbin/runonce \
    && rm /sbin/runonce

VOLUME ["/config", "/www"]

COPY apache2.conf /etc/apache2/apache2.conf

# Exposing http port
EXPOSE 80

CMD ["/sbin/my_init"]
