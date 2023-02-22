#!/bin/bash

# check curl zsh installed and on path
if [ ! -x "$(which curl)" ]; then
    echo Please install curl before running this script
    exit 1
fi

# check docker installed and on path
if [ ! -x "$(which docker)" ]; then
    echo Please install docker before running this script
    exit 1
fi

# if [ ! -x "$(which zsh)" ]; then
#     echo Please install zsh shell before running this script
#     exit 1
# fi


# update variables of your project setup
CB_USERNAME=administrator
CB_PASSWORD=administrator
CB_CLUSTER_NAME=ecommerce
CB_BUCKETS=(ecommerce ecommerce_test)
CB_SCOPE_NAME=_default
CB_HOST=127.0.0.1
CB_PORT=8091
CB_COLLECTIONS=(users inventories addresses carts discounts products categories roles sessions perms)
flushOnly=0

#parse args
for arg in $@
do
    case $arg in
        --test) ENV=test;;
        --dev)  ENV=dev;;
        --flushOnly) flushOnly=true;; # skip create database flush bucket only
    esac
done



# creates cluster
function createCluster() {
    data=$(curl -o response.txt -w "%{http_code}"  -X POST "http://$CB_HOST:$CB_PORT/clusterInit" \
            -d "hostname=127.0.0.1" \
            -d "sendStats=true" \
            -d "services=kv%2Cn1ql%2Cindex" \
            -d "clusterName=$CB_CLUSTER_NAME" \
            -d "memoryQuota=1024" \
            -d "afamily=ipv4" \
            -d "afamilyOnly=false" \
            -d "nodeEncryption=off" \
            -d "username=$CB_USERNAME" \
            -d "password=$CB_PASSWORD" \
            -d "port=SAME" \
            -d "indexerStorageMode=plasma");
    sleep 15s

    if [[ "$data" != "200" ]]; then
        echo "Cluster creating"
    else 
        echo cluster already exist
    fi

    rm response.txt
}

function createBucket() {
    echo creating buckets

    for bucket in "${CB_BUCKETS[@]}"
    do
        data=$(curl -s -i -o response.txt   -w "%{http_code}"  \
            -X POST http://$CB_HOST:$CB_PORT/pools/default/buckets \
                        -u $CB_USERNAME:$CB_PASSWORD \
                        -d name=$bucket \
                        -d bucketType=couchbase \
                        -d ramQuota=256 \
                        -d durabilityMinLevel=none \
                        -d flushEnabled=1); 
        if [[ "$data" != "200" ]]; then
            echo "bucket created"
            rm response.txt
        else 
            echo bucket already exist
        fi

        sleep 10s
    done
};


function createCollections() {
    echo -e "creating collectons"
    # loop for al buckets
    for bucket in "${CB_BUCKETS[@]}"
    do
        # create collections in each bucket
        for collection in "${CB_COLLECTIONS[@]}"
        do
            data="$(curl -s -i -o response.txt   -w "%{http_code}" -X POST  http://$CB_HOST:$CB_PORT/pools/default/buckets/$bucket/scopes/_default/collections \
                    -u $CB_USERNAME:$CB_PASSWORD \
                    -d name="$collection" \
                    -d maxTTL=0)"
            if [ $data -eq 200 ]
            then 
                echo  "Collection '$collection' created\n"
            else 
                echo "Error:collection exist"
              
            fi
            rm response.txt 
            
        done
    done
      
}

function createIndex() {

    echo "create indexes"

    for bucket in "${CB_BUCKETS[@]}"
    do
        for collection in "${CB_COLLECTIONS[@]}"
        do
            data=$(curl -o response.txt -w "%{http_code}" -X POST http://$CB_HOST:8093/query/service \
                -u $CB_USERNAME:$CB_PASSWORD \
                -d "statement=CREATE PRIMARY INDEX \`#$collection\` ON $bucket._default.$collection USING GSI" )
       
            echo $data
        done
    done

    rm response.txt
}

function flushDb() {
    data=$(curl -s -i -o response.txt  -w "%{http_code}"  -X POST -u $CB_USERNAME:$CB_PASSWORD \
        http://$CB_HOST:$CB_PORT/pools/default/buckets/${CB_BUCKETS[1]}/controller/doFlush)

    if [ "$data" = "200" ]; then
        echo 'Bucket exist\nBucket flushed\n'
    else 
        echo 'Bucket doest not exist\n'
    fi
    rm response.txt
}

if [[ "$flushOnly" = "true" ]]
then
    flushDb
    exit 0
fi

createCluster
createBucket
createCollections
createIndex

if [[ "$ENV" = "test" ]]
then
    flushDb
fi

