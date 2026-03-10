# Stage 1: Download iGalerie
FROM php:8.4-apache AS downloader

ENV IGALERIE_VERSION=3.1.2

RUN <<EOF
set -ex
apt update
apt install -y --no-install-recommends curl unzip
curl -fsSL -o igalerie.zip "https://www.igalerie.org/igalerie-${IGALERIE_VERSION}.zip"
unzip -qq igalerie.zip
# Delete directory install and upgrade.php after install
sed -i "s#^\(.*\)\(die;\)#\1File::unlink(GALLERY_ROOT . '/upgrade.php');\n\1foreach (glob(GALLERY_ROOT . '/install/*') as \&\$f) { File::unlink(\$f); };\n\1rmdir(GALLERY_ROOT . '/install/');\n\1\2#g" igalerie/install/index.php
rm -rf /var/lib/apt/lists/*
EOF

# Stage 2: Final image
FROM php:8.4-apache
LABEL maintainer="Michael Nival <docker@mn-home.fr>"

RUN <<EOF
set -ex
savedAptMark="$(apt-mark showmanual)"

apt update
apt install -y --no-install-recommends \
  libpng-dev \
  libfreetype6-dev \
  libjpeg-dev \
  libwebp-dev \
  libonig-dev \
  libzip-dev \
  libsqlite3-dev \
  libpq-dev

docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp
docker-php-ext-install -j "$(nproc)" \
  gd \
  exif \
  zip \
  mbstring \
  pdo_sqlite \
  pdo_mysql \
  pdo_pgsql

# Reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
apt-mark auto '.*' > /dev/null
apt-mark manual $savedAptMark
ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
  | awk '/=>/ { print $3 }' \
  | sort -u \
  | xargs -r dpkg-query -S \
  | cut -d: -f1 \
  | sort -u \
  | xargs -rt apt-mark manual

apt purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/*
EOF

# Value forced in includes/prepend.php
ENV PHP_MEMORY_LIMIT=512M \
    PHP_UPLOAD_LIMIT=128M \
    IGALERIE_VERSION=3.1.2

RUN <<EOF cat > /usr/local/etc/php/conf.d/igalerie.ini
memory_limit=\${PHP_MEMORY_LIMIT}
upload_max_filesize=\${PHP_UPLOAD_LIMIT}
post_max_size=\${PHP_UPLOAD_LIMIT}
EOF

# Copy iGalerie from downloader stage
COPY --from=downloader /var/www/html/igalerie /var/www/html/

# Setup customs directory structure
RUN <<EOF
set -ex
mkdir /usr/local/src/customs
for i in albums cache config db errors files images pending template; do
  mv ${i} /usr/local/src/customs/
  ln -s customs/${i} .
done
chown -R www-data:www-data . /usr/local/src/customs
EOF

VOLUME /var/www/html/customs

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["apache2-foreground"]
