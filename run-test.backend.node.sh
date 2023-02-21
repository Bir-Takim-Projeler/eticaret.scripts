#!/bin/zsh
cd scripts/database && docker-compose up


yarn --cwd services/product install
yarn --cwd services/product test
