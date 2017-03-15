# BUILD CONTAINER
# docker build -t karmap .

# CONTAINER SYSTEMD
# docker run --privileged –v /sys/fs/cgroup:/sys/fs/cgroup:ro -it karmap /lib/systemd/systemd

# CONTAINER RSPEC
# docker run -it karmap /bin/bash

# STOP CONTAINER IF STUCK
# docker stop $(docker ps -a -q)

FROM ruby:2.3.3
MAINTAINER Extendi <info@extendi.it>
LABEL Description="This image is used to test KarmaP project" Vendor="Giovannelli Duccio (stim. prof.)" Version="0.0.5"
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

ENV container docker
ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive
RUN cd /lib/systemd/system/sysinit.target.wants/; ls | grep -v systemd-tmpfiles-setup | xargs rm -f $1 \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*; \
rm -f /lib/systemd/system/plymouth*; \
rm -f /lib/systemd/system/systemd-update-utmp*;
RUN systemctl set-default multi-user.target
ENV init /lib/systemd/systemd
VOLUME ["/sys/fs/cgroup"]
# ENTRYPOINT ["/lib/systemd/systemd"]

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		build-essential \
		dbus \
		git \
		libpq-dev \
		nodejs \
		postgresql

# POSTGRES
# see https://docs.docker.com/engine/examples/postgresql_service/
# USER postgres
# RUN /etc/init.d/postgresql start &&\
#    psql --command "CREATE USER docker WITH SUPERUSER PASSWORD 'docker';" &&\
#    createdb -O docker karma_test
# RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/9.4/main/pg_hba.conf
# RUN echo "listen_addresses='*'" >> /etc/postgresql/9.4/main/postgresql.conf
# EXPOSE 5432
# CMD ["/usr/lib/postgresql/9.4/bin/postgres", "-D", "/var/lib/postgresql/9.4/main", "-c", "config_file=/etc/postgresql/9.4/main/postgresql.conf"]

# PROJECT INIT
USER root
ENV INSTALL_PATH /var/www/karmap
ENV KARMA_AWS_ACCESS_KEY_ID AKIAJP6TDOEFESXXQXSA
ENV KARMA_AWS_SECRET_ACCESS_KEY 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
RUN mkdir -p $INSTALL_PATH
WORKDIR $INSTALL_PATH
RUN mkdir -p ./lib/karmap
COPY Gemfile Gemfile.lock karmap.gemspec ./
COPY ./lib/karmap/version.rb ./lib/karmap
RUN bundle install --binstubs
COPY . .
VOLUME ["$INSTALL_PATH/public"]