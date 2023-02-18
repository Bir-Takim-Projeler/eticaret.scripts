#!/bin/zsh
zsh scripts/create-db.sh --test
yarn --cwd scripts/seed-db install
node scripts/seed-db/index.js
yarn --cwd services/product install
yarn --cwd services/product test
