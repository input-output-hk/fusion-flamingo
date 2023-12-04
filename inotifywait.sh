#!/bin/env bash
inotifywait -e close_write -r . \
  --exclude 'dist-newstyle|.git|./cardano-node/example'
