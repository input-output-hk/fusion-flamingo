#!/bin/env bash
# sometimes it catches filesystem updates from previous command so this sleep avoids that
sleep 0.5
inotifywait -e close_write -r . \
  --exclude 'dist-newstyle|.git|./cardano-node/example'
