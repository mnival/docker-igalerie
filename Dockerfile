FROM php:8.2.10-apache-bullseye
LABEL maintainer "Michael Nival <docker@mn-home.fr>"

RUN set -ex; \
  \
  savedAptMark="$(apt-mark showmanual)"; \
  \
  apt update; \
  apt install -y --no-install-recommends \
    libfreetype6-dev \
    libjpeg-dev \
    libwebp-dev \
    libonig-dev \
    libzip-dev \
    libsqlite3-dev \
    libpq-dev \
  ; \
  \
  debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
  docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
  docker-php-ext-install -j "$(nproc)" \
    gd \
    exif \
    zip \
    mbstring \
    pdo_sqlite \
    pdo_mysql \
    pdo_pgsql \
  ; \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
        | awk '/=>/ { print $3 }' \
        | sort -u \
        | xargs -r dpkg-query -S \
        | cut -d: -f1 \
        | sort -u \
        | xargs -rt apt-mark manual; \
    \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*

# Value forced in includes/prepend.php
ENV PHP_MEMORY_LIMIT 512M
ENV PHP_UPLOAD_LIMIT 128M

RUN { \
  echo 'memory_limit=${PHP_MEMORY_LIMIT}'; \
  echo 'upload_max_filesize=${PHP_UPLOAD_LIMIT}'; \
  echo 'post_max_size=${PHP_UPLOAD_LIMIT}'; \
  } > /usr/local/etc/php/conf.d/igalerie.ini

VOLUME /var/www/html/customs

ENV IGALERIE_VERSION 3.0.19

RUN set -ex; \
  fetchDeps=" \
    unzip \
  "; \
  \
  apt update; \
  apt install -y --no-install-recommends $fetchDeps; \
  \
  curl -fsSL -o igalerie.zip "https://www.igalerie.org/igalerie-${IGALERIE_VERSION}.zip"; \
  unzip -qq igalerie.zip; \
  mv igalerie/* .; \
  rm -r igalerie/ igalerie.zip; \
  mkdir /usr/local/src/customs; \
  for i in albums cache config db errors files images pending template; do \
    mv ${i} /usr/local/src/customs/; \
    ln -s customs/${i} .; \
  done; \
  chown -R www-data:www-data . /usr/local/src/customs; \
  # Delete directory install and upgrade.php after install
  sed -i "s#^\(.*\)\(die;\)#\1File::unlink(GALLERY_ROOT . '/upgrade.php');\n\1foreach (glob(GALLERY_ROOT . '/install/*') as \&\$f) { File::unlink(\$f); };\n\1rmdir(GALLERY_ROOT . '/install/');\n\1\2#g" install/index.php; \
  apt purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $fetchDeps; \
  rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["apache2-foreground"]
