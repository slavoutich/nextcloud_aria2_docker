FROM nextcloud:12.0.3-apache

RUN apt-get update && apt-get install -y \
  aria2 \
  && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
