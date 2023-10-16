#!/bin/bash

set -e

goal_serve() {
  docker run \
      --volume="$PWD:/usr/src/app" \
      --volume="$PWD/vendor/bundle/gems:/usr/local/bundle" \
      --workdir=/usr/src/app \
      -p 4000:4000 \
      -it ruby:2.7 \
      bash -c "bundle install && bundle exec jekyll serve --host 0.0.0.0"
}

goal_build() {
  docker run \
      --volume="$PWD:/usr/src/app" \
      --volume="$PWD/vendor/bundle/gems:/usr/local/bundle" \
      --workdir=/usr/src/app \
      --env JEKYLL_ENV=production \
      -p 4000:4000 \
      -it ruby:2.7 \
      bash -c "bundle install && bundle exec jekyll build"
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
