#!/bin/zsh
echo -e "___________________________________________\n"
echo -e "Running test on services.product.controller\n" 
cd services/product && yarn test 
cd ../..
echo -e "___________________________________________\n"
echo -e "Runing e2e test on services.gateway\n"
cd services/gateway && yarn test:e2e 