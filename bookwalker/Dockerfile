FROM alpine:3.4
MAINTAINER Kohei Suzuki <eagletmt@gmail.com>

RUN apk add --update ruby-dev ruby-io-console ruby-json ca-certificates libxml2-dev libxslt-dev libgcrypt-dev g++ musl-dev make
RUN gem install --no-user-install --no-ri --no-rdoc bundler -v 1.12.5
RUN bundle config build.nokogiri --use-system-libraries

RUN mkdir -p /app

COPY Gemfile /tmp/Gemfile
COPY Gemfile.lock /tmp/Gemfile.lock
RUN cd /tmp && bundle install -j4 --deployment --path vendor/bundle

COPY bookwalker.rb /app/
RUN mv /tmp/Gemfile /app/Gemfile \
  && mv /tmp/Gemfile.lock /app/Gemfile.lock \
  && mv /tmp/.bundle /app/.bundle \
  && mv /tmp/vendor /app/vendor

WORKDIR /app
CMD ["bundle", "exec", "./bookwalker.rb"]
