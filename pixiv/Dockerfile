FROM ubuntu:14.10
MAINTAINER Kohei Suzuki <eagletmt@gmail.com>

RUN env DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common \
  && apt-add-repository ppa:brightbox/ruby-ng \
  && apt-get update \
  && env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
  && env DEBIAN_FRONTEND=noninteractive apt-get install -y ruby2.2 ruby2.2-dev build-essential zlib1g-dev \
  && apt-get clean
RUN gem install --no-user-install --no-ri --no-rdoc bundler -v 1.8.3

RUN mkdir -p /app

ADD Gemfile /tmp/Gemfile
ADD Gemfile.lock /tmp/Gemfile.lock
ADD pxfeed.gemspec /tmp/pxfeed.gemspec
ADD lib/pxfeed/version.rb /tmp/lib/pxfeed/version.rb
RUN cd /tmp && bundle install -j4 --deployment --path vendor/bundle

ADD . /app/
RUN mv /tmp/Gemfile /app/Gemfile \
  && mv /tmp/Gemfile.lock /app/Gemfile.lock \
  && mv /tmp/.bundle /app/.bundle \
  && mv /tmp/vendor /app/vendor

WORKDIR /app
ENTRYPOINT ["bundle", "exec", "bin/pxfeed"]