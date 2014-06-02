#!/usr/bin/env bash

# Drush
#
# Installs latest version of Drush.

if test ! $(which drush)
then
  if test $(which brew)
  then
    echo "  Installing Drush for you."
    brew install drush
  fi
fi
