# 选择 PHP 8.3 带 FPM 的官方镜像
FROM php:8.3-fpm

# 设置工作目录
WORKDIR /var/www/html

# 安装必要依赖和扩展
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libonig-dev \
    mariadb-client \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql zip mbstring opcache

# 安装 composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# 复制当前目录代码（假设你已经有 flarum 源码）
COPY . /var/www/html

# 给予权限
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

# 安装 Flarum（如果你想镜像里直接安装）
RUN composer install --no-dev --optimize-autoloader

# 开放端口
EXPOSE 9000

# 启动 PHP-FPM
CMD ["php-fpm"]
