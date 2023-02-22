#!/bin/zsh

yarn --cwd libs/entities build
yarn --cwd services/product install
yarn --cwd services/product test
