# Use phusion/baseimage as base image. To make your builds reproducible, make
# sure you lock down to a specific version, not to `latest`!
# See https://github.com/phusion/baseimage-docker/blob/master/Changelog.md for
# a list of version numbers.
FROM phusion/baseimage:0.9.16

# Set correct environment variables.
ENV HOME /root

# Disable SSH
RUN rm -rf /etc/service/sshd /etc/my_init.d/00_regen_ssh_host_keys.sh

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

RUN apt-get update

# Install Mysql
RUN apt-get -y install mysql-server

# Install php
RUN apt-get -y install php5 php5-mysql

# Install Lychee dependencies
RUN apt-get -y install imagemagick php5-gd php5-curl php5-imagick

# Install nginx
RUN apt-get -y install php5-fpm nginx

# minimize mysql allocations
RUN echo '[mysqld]\ninnodb_data_file_path = ibdata1:10M:autoextend\ninnodb_log_file_size = 10KB\ninnodb_file_per_table = 1' > /etc/mysql/conf.d/small.cnf
RUN sed -i 's_^socket\s*=.*_socket = /tmp/mysqld.sock_g' /etc/mysql/*.cnf && ln -s /tmp/mysqld.sock /var/run/mysqld/mysqld.sock
RUN rm -rf /var/lib/mysql/* && mysql_install_db && chown -R mysql: /var/lib/mysql

# Setup mysql//mysql user
RUN /usr/sbin/mysqld & \
    sleep 10s &&\
    echo "GRANT ALL ON *.* TO mysql@'%' IDENTIFIED BY 'mysql' WITH GRANT OPTION; FLUSH PRIVILEGES; CREATE SCHEMA app;" | mysql

# setup nginx
ADD nginx.conf /etc/nginx/nginx.conf
RUN echo "cgi.fix_pathinfo = 0;" >> /etc/php5/fpm/php.ini
RUN sed -i 's_^listen\s*=\s*.*_listen = 127.0.0.1:9000_g' /etc/php5/fpm/pool.d/www.conf
RUN sed -i 's_^user\s*=\s*.*_user = 1000_g' /etc/php5/fpm/pool.d/www.conf
RUN sed -i 's_^group\s*=\s*.*_group = 1000_g' /etc/php5/fpm/pool.d/www.conf

RUN mkdir /etc/service/mysql
ADD mysql.sh /etc/service/mysql/run

RUN mkdir /etc/service/php
ADD php.sh /etc/service/php/run

RUN mkdir /etc/service/nginx
ADD nginx.sh /etc/service/nginx/run

ADD . /opt/app
RUN rm -rf /opt/app/.git
# symlink data and uploads to /var
RUN mv /opt/app/data /var && mv /opt/app/uploads /var && chmod -R 777 /var/uploads /var/data && ln -s /var/uploads /opt/app && ln -s /var/data /opt/app

EXPOSE 33411

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN rm -rf /usr/share/vim /usr/share/doc /usr/share/man /var/lib/dpkg /var/lib/belocs /var/lib/ucf /var/cache/debconf /var/log/*.log
