FROM ruby:3.4.2-alpine

RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    postgresql-client \
    bash \
    tzdata

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN bundle install --jobs=4

RUN mkdir -p /app/log /app/tmp/pids

COPY . .

RUN mkdir -p /app/.docker
COPY .docker/entrypoint.sh /app/.docker/entrypoint.sh
RUN chmod +x /app/.docker/entrypoint.sh

EXPOSE 9292

ENTRYPOINT ["/app/.docker/entrypoint.sh"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
