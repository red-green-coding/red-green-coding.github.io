#!/bin/bash

set -e

export JEKYLL_VERSION=3.8

goal_serve() {
  goal_docker

  docker run --rm -p 4000:4000 -p 40000:40000 -v $(pwd):/app/src jekyll-container serve\
      --host 0.0.0.0 --drafts --livereload --livereload_port 40000 --force_polling
}

goal_build() {
  goal_docker
  rm -rf _site
  docker run --rm -p 4000:4000 -p 40000:40000 --env JEKYLL_ENV=production -v $(pwd):/app/src jekyll-container build
}

goal_docker() {
  docker build -t jekyll-container docker

  docker run --rm --entrypoint cat jekyll-container /app/bundle/Gemfile.lock > docker/Gemfile.lock
}

goal_clean() {
    rm -rf .sass-cache _site vendor .jekyll-metadata
}

goal_help() {
  echo "usage: $0 <goal>
    available goals
    serve   -- serve the blog locally (http://localhost:4000)
    build   -- build the blog (builds static artifact for publishing)
    docker  -- creates docker build image (tag: jekyll-container)
    clean   -- remove all generated content
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
