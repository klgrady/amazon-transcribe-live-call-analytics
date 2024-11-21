#!/bin/sh

if [ -n $5 ] && $5; then
  echo "Running internal script in: $PWD"
  ./.codecatalyst/git-merge.sh "$1" "$2" "$3" "$4"
else
  echo "Nothing to do. Skip in customer environment"
fi
