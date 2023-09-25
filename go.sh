#!/bin/bash

set -x
set -e

export JEKYLL_VERSION=3.8

docker run --rm \
  --volume="$PWD:/srv/jekyll:Z" \
  --volume="$PWD/vendor/bundle:/usr/local/bundle:Z" \
  --env FORCE_POLLING=true \
  -p 4000:4000 \
  -it jekyll/builder:$JEKYLL_VERSION \
  jekyll $1
