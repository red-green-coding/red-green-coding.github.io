#!/bin/bash

set -x
set -e

export JEKYLL_VERSION=3.8

goal_serve() {
  docker run --rm \
    --volume="$PWD:/srv/jekyll:Z" \
    --volume="$PWD/vendor/bundle:/usr/local/bundle:Z" \
    --env FORCE_POLLING=true \
    -p 4000:4000 \
    -it jekyll/builder:$JEKYLL_VERSION \
    jekyll serve
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