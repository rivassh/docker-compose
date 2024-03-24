FROM php:5.6-fpm

RUN apt-get update \
    && apt-get install -y libxml2-dev libcurl4-openssl-dev unzip wget \
    && docker-php-ext-install soap \
    && docker-php-ext-install mysqli \
    && docker-php-ext-install pdo \
    && docker-php-ext-install pdo_mysql \
    && apt-get install -y libfreetype6-dev libjpeg62-turbo-dev  \
    && docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/    \
    && docker-php-ext-install gd \
    && apt-get install -y zlib1g-dev \
    && apt-get install -y libzip-dev zip \
    && docker-php-ext-install zip \
    && apt-get update && apt-get install -y libmemcached11 libmemcachedutil2 libmemcached-dev libz-dev git \
    && apt-get install -y libcurl4-openssl-dev pkg-config libssl-dev \
    && apt-get autoremove -y \
    && curl -sS https://getcomposer.org/installer | php \ 
    && mv composer.phar /usr/local/bin/composer \
    &&  rm -rf /tmp/pear \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean


RUN set -x \
    && apt-get update \
    && apt-get install -y libldap2-dev \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ \
    && docker-php-ext-install ldap \
    && apt-get purge -y --auto-remove libldap2-dev

RUN docker-php-ext-install bcmath \
    && docker-php-ext-install sockets


RUN docker-php-ext-configure pcntl --enable-pcntl && \ 
    docker-php-ext-install pcntl 

RUN docker-php-ext-install mysql

RUN wget http://ftp.us.debian.org/debian/pool/main/libm/libmcrypt/libmcrypt-dev_2.5.8-3.4+b1_amd64.deb \
    && wget http://ftp.us.debian.org/debian/pool/main/libm/libmcrypt/libmcrypt4_2.5.8-3.4+b1_amd64.deb \
    && dpkg -i libmcrypt4_2.5.8-3.4+b1_amd64.deb \
    && dpkg -i libmcrypt-dev_2.5.8-3.4+b1_amd64.deb \
    && docker-php-ext-install mcrypt

ENV http_proxy ''
ENV https_proxy ''

RUN groupadd -g 1000 nginxx
RUN useradd -d /opt -s /bin/bash -u 1000 -g 1000 nginxx
# User and group own home directory
RUN chown -R nginxx:nginxx /opt


WORKDIR /opt

CMD ["php-fpm", "--nodaemonize"]
