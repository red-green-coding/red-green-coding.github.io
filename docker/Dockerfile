FROM ruby:2.7

ENV BUNDLE_GEMFILE=/app/bundle/Gemfile

WORKDIR /app/bundle

ADD Gemfile .

RUN bundle install

RUN mkdir /app/src

WORKDIR /app/src

ENTRYPOINT ["bundle", "exec", "jekyll"]
