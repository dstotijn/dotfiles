#!/usr/bin/env bash

# git-flow
#
# Installs latest version of git-flow.

if test ! $(which git-flow)
then
  if test $(which brew)
  then
    echo "  Installing git-flow for you."
    brew install git-flow 
  fi
fi
