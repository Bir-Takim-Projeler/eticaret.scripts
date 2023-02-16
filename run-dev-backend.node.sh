#!/bin/zsh



yarn load:scripts
yarn load:proto
cd libs/entities 
yarn install && tsc
cd ../..
cd services/product || yarn start:dev
cd services/gateway  || yarn start:dev
