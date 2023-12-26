FROM ruby:3.2.2

RUN groupadd rails && useradd -m -g rails rails

RUN apt-get update \
  && rm -rf /var/lib/apt/lists/*

USER rails
RUN mkdir -p /home/rails/app
WORKDIR /home/rails/app

ARG rails_env='development'

ENV RUBY_YJIT_ENABLE=1 \
  RAILS_ENV=${rails_env} \
  BUNDLE_SILENCE_ROOT_WARNING=1 \
  RAILS_LOG_TO_STDOUT=true

COPY --chown=rails:rails .ruby-version Gemfile Gemfile.lock ./
COPY --chown=rails:rails . ./

RUN gem install bundler -v 2.4.20 \
  && bundle config path vendor/bundle \
  && bundle config set --local gemfile gemfiles/activerecord-70.gemfile \
  && bundle install --jobs 4 --retry 3

CMD ["bundle", "exec", "rake"]
