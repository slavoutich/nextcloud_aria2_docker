FROM php:7.1-apache

RUN apt-get update && apt-get install -y \
  aria2 \
  rsync \
  bzip2 \
  libcurl4-openssl-dev \
  libfreetype6-dev \
  libicu-dev \
  libjpeg-dev \
  libldap2-dev \
  libmcrypt-dev \
  libmemcached-dev \
  libpng12-dev \
  libpq-dev \
  libxml2-dev \
  && rm -rf /var/lib/apt/lists/*

# https://docs.nextcloud.com/server/9/admin_manual/installation/source_installation.html
RUN debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)" \
  && docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr \
  && docker-php-ext-configure ldap --with-libdir="lib/$debMultiarch" \
  && docker-php-ext-install gd exif intl mbstring mcrypt ldap mysqli opcache pdo_mysql pdo_pgsql pgsql zip pcntl

# set recommended PHP.ini settings
# see https://docs.nextcloud.com/server/12/admin_manual/configuration_server/server_tuning.html#enable-php-opcache
RUN { \
  echo 'opcache.enable=1'; \
  echo 'opcache.enable_cli=1'; \
  echo 'opcache.interned_strings_buffer=8'; \
  echo 'opcache.max_accelerated_files=10000'; \
  echo 'opcache.memory_consumption=128'; \
  echo 'opcache.save_comments=1'; \
  echo 'opcache.revalidate_freq=1'; \
  } > /usr/local/etc/php/conf.d/opcache-recommended.ini
RUN a2enmod rewrite

# PECL extensions
RUN set -ex \
 && pecl install APCu-5.1.8 \
 && pecl install memcached-3.0.3 \
 && pecl install redis-3.1.3 \
 && docker-php-ext-enable apcu redis memcached
RUN a2enmod rewrite

ENV NEXTCLOUD_VERSION 12.0.2
VOLUME /var/www/html

COPY config/* /usr/src/nextcloud/config/

RUN curl -fsSL -o nextcloud.tar.bz2 \
    "https://download.nextcloud.com/server/releases/nextcloud-${NEXTCLOUD_VERSION}.tar.bz2" \
 && curl -fsSL -o nextcloud.tar.bz2.asc \
    "https://download.nextcloud.com/server/releases/nextcloud-${NEXTCLOUD_VERSION}.tar.bz2.asc" \
 && export GNUPGHOME="$(mktemp -d)" \
# gpg key from https://nextcloud.com/nextcloud.asc
 && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 28806A878AE423A28372792ED75899B9A724937A \
 && gpg --batch --verify nextcloud.tar.bz2.asc nextcloud.tar.bz2 \
 && rm -r "$GNUPGHOME" nextcloud.tar.bz2.asc \
 && tar -xjf nextcloud.tar.bz2 -C /usr/src/ \
 && rm nextcloud.tar.bz2 \
 && rm -rf /usr/src/nextcloud/updater \
 # https://docs.nextcloud.com/server/11/admin_manual/installation/installation_wizard.html#setting-strong-directory-permissions
 && mkdir -p /usr/src/nextcloud/data \
 && mkdir -p /usr/src/nextcloud/custom_apps \
 && find /usr/src/nextcloud/ -type f -print0 | xargs -0 chmod 0640 \
 && find /usr/src/nextcloud/ -type d -print0 | xargs -0 chmod 0750 \
 && chown -R root:www-data /usr/src/nextcloud/ \
 && chown -R www-data:www-data /usr/src/nextcloud/custom_apps/ \
 && chown -R www-data:www-data /usr/src/nextcloud/config/ \
 && chown -R www-data:www-data /usr/src/nextcloud/data/ \
 && chown -R www-data:www-data /usr/src/nextcloud/themes/ \
 && chmod +x /usr/src/nextcloud/occ

COPY docker-entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
