FROM ruby:2.7

ENV BUNDLE_GEMFILE=/app/bundle/Gemfile

WORKDIR /app/bundle

RUN apt-get clean
RUN apt-get update
RUN apt-get -y install plantuml

ADD Gemfile .
ADD Gemfile.lock .

RUN bundle install

RUN mkdir /app/src

WORKDIR /app/src

ENTRYPOINT ["bundle", "exec", "jekyll"]
