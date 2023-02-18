#!/bin/zsh
zsh scripts/create-db.sh --test
yarn --cwd services/product install
yarn --cwd services/product test
