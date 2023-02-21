#!/bin/bash

/entrypoint.sh couchbase-server & 

CB_USERNAME=administrator
CB_PASSWORD=administrator
CB_CLUSTER_NAME=ecommerce
CB_BUCKET_NAME=ecommerce
CB_SCOPE_NAME=_default
CB_HOST=127.0.0.1
CB_PORT=8091
CB_COLLECTIONS=(user inventory address cart discount product category role session perm)


# check if deamon already started
isRunning="$(couchbase-server --status)"

# wait until deamon start
while [[ "$isRunning" != "Couchbase Server is running" ]]
do
echo $isAvailable
    isRunning="$(couchbase-server --status)"
    echo "waiting to couchbase deamon start"
    sleep 1s
done
# wait 5 seconds to be sure
sleep 5s

# create cluster
couchbase-cli cluster-init -c $CB_HOST \
--cluster-username $CB_USERNAME \
--cluster-password $CB_PASSWORD \
--services data,index,query \
--cluster-ramsize 512 \
--cluster-index-ramsize 256
sleep 2s

#create bucket on cluster
couchbase-cli bucket-create \
--cluster $CB_HOST:$CB_PORT \
--username $CB_USERNAME \
--password $CB_PASSWORD \
--bucket $CB_BUCKET_NAME \
--bucket-type couchbase \
--bucket-ramsize 512 \
--durability-min-level none \
--enable-flush 1
sleep 2s

# create collections
for collection in "${CB_COLLECTIONS[@]}"
do
    curl  -X POST \
        http://$CB_HOST:$CB_PORT/pools/default/buckets/$CB_BUCKET_NAME/scopes/_default/collections \
        -u $CB_USERNAME:$CB_PASSWORD \
        -d name=$collection \
        -d maxTTL=0
done

# create primary index
for collection in "${CB_COLLECTIONS[@]}"
do

    curl -X POST http://$CB_HOST:8093/query/service \
     -u $CB_USERNAME:$CB_PASSWORD \
     -d statement=create%20primary%20index%20on%20\`ecommerce\`._default.$collection 
     
done

sleep 2s

#flush testdb
sleep 2s
curl -X POST http://$CB_HOST:$CB_PORT/pools/default/buckets/$CB_BUCKET_NAME/controller/doFlush \
     -u $CB_USERNAME:$CB_PASSWORD 
    
echo couchbase ready
tail -f /dev/null