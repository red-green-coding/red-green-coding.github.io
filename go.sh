#!/bin/bash

set -e

export JEKYLL_VERSION=3.8

goal_serve() {
  docker run --rm \
    --volume="$PWD:/usr/src/app" \
    --volume="$PWD/vendor/bundle/gems:/usr/local/bundle" \
    --workdir=/usr/src/app \
    --env FORCE_POLLING=true \
    -p 4000:4000 \
    -p 40000:40000 \
    -it ruby:2.7 \
    bash -c "bundle install && bundle exec jekyll serve --drafts --livereload --livereload_port 40000 --force_polling --incremental"
}

goal_build() {
  docker run --rm \
    --volume="$PWD:/srv/jekyll:Z" \
    --volume="$PWD/vendor/bundle:/usr/local/bundle:Z" \
    --env JEKYLL_ENV=production \
    jekyll/builder:$JEKYLL_VERSION \
    jekyll build
}

goal_help() {
  echo "usage: $0 <goal>
    available goals
    serve   -- serve the blog locally (http://localhost:4000)
    build   -- build the blog (builds static artifact for publishing)
    "
  exit 1
}

main() {
  local TARGET=${1:-}
  if [ -n "${TARGET}" ] && type -t "goal_$TARGET" &>/dev/null; then
    "goal_$TARGET" "${@:2}"
  else
    goal_help
  fi
}

main "$@"
