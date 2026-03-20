#!/bin/env bash

# colour stdout to make it more visible
colour_stdout() {
  if command -v lolcat > /dev/null 2>&1; then
    while IFS= read -r line; do
      echo "⚡ $line" | lolcat
    done
  else
    while IFS= read -r line; do
      echo -e "\e[35m⚡ $line\e[0m"
    done
  fi
}

# sometimes it catches filesystem updates from previous command so this sleep avoids that
sleep 0.5
inotifywait -e close_write -r . \
  --exclude 'dist-newstyle|.git|./cardano-node/example' | colour_stdout
