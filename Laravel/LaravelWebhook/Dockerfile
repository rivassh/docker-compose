FROM php:fpm
RUN apt update
RUN apt install zip -y
RUN apt install libzip-dev -y
RUN docker-php-ext-install zip
RUN docker-php-ext-enable zip
COPY webhooks/composer.phar .

# RUN php composer.phar global require laravel/installer
CMD php-fpm