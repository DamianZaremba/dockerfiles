FROM ubuntu:latest

MAINTAINER Constantinos Kouloumbris <c@kouloumbris.com>

# Surpress Upstart errors/warning
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl

#packages to install
ENV BUILD_PACKAGES="supervisor nginx php5-fpm git php5-mysql php-apc php5-curl php5-gd php5-intl php5-mcrypt php5-memcache php5-sqlite php5-tidy php5-xmlrpc php5-xsl php5-pgsql php5-mongo php5-ldap pwgen"

#for compatibiltiy
ENV DOCKER_USER_ID 501 
ENV DOCKER_USER_GID 20

ENV BOOT2DOCKER_ID 1000
ENV BOOT2DOCKER_GID 50

# # Tweaks to give the web service and php write permissions to the app
RUN usermod -u ${BOOT2DOCKER_ID} www-data
RUN usermod -G staff www-data

RUN groupmod -g $(($BOOT2DOCKER_GID + 10000)) $(getent group $BOOT2DOCKER_GID | cut -d: -f1)
RUN groupmod -g ${BOOT2DOCKER_GID} staff

# Install packages
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get install -y software-properties-common
RUN add-apt-repository ppa:nginx/stable
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y $BUILD_PACKAGES

# Cleanup
RUN apt-get remove --purge -y software-properties-common
RUN apt-get autoremove -y
RUN apt-get clean
RUN apt-get autoclean

#tweek nginx config
RUN sed -i -e '/worker_processes/c\worker_processes  5;' /etc/nginx/nginx.conf
RUN sed -i -e '/keepalive_timeout/c\keepalive_timeout  2;' /etc/nginx/nginx.conf
RUN sed -i -e '/client_max_body_size/c\client_max_body_size 100m;' /etc/nginx/nginx.conf
RUN echo "daemon off;" >> /etc/nginx/nginx.conf

#tweek php-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/fpm/php.ini
RUN sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php5/fpm/php.ini
RUN sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php5/fpm/php.ini
RUN sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php5/fpm/php-fpm.conf
RUN sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php5/fpm/pool.d/www.conf
RUN sed -i -e "s/pm.max_children = 5/pm.max_children = 9/g" /etc/php5/fpm/pool.d/www.conf
RUN sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" /etc/php5/fpm/pool.d/www.conf
RUN sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" /etc/php5/fpm/pool.d/www.conf
RUN sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" /etc/php5/fpm/pool.d/www.conf
RUN sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" /etc/php5/fpm/pool.d/www.conf

#fix ownership of sock file
RUN sed -i -e "s/;listen.mode = 0660/listen.mode = 0750/g" /etc/php5/fpm/pool.d/www.conf
RUN find /etc/php5/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;

# mycrypt conf
RUN php5enmod mcrypt

# nginx site conf
RUN rm -Rf /etc/nginx/conf.d/*
RUN rm -Rf /etc/nginx/sites-available/default
RUN mkdir -p /etc/nginx/ssl/
ADD conf/nginx-site.conf /etc/nginx/sites-available/default.conf
RUN ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf

# Supervisor Config
ADD conf/supervisord.conf /etc/supervisord.conf

# Start Supervisord
ADD scripts/start.sh /start.sh
RUN chmod 755 /start.sh

# Setup Volume
VOLUME ["/app"]

# change nginx directory
RUN mkdir -p /app/src/public
RUN mkdir -p /var/www/html/logs

# add test PHP file
ADD src/index.php /app/src/public/index.php
RUN chown -Rf www-data.www-data /app
RUN chown -Rf www-data.www-data /var/www/html


# Expose Ports
EXPOSE 443
EXPOSE 80

CMD ["/bin/bash", "/start.sh"]