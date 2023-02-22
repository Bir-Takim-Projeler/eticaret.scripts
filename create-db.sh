#!/bin/zsh

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

if [ ! -x "$(which zsh)" ]; then
    echo Please install zsh shell before running this script
fi


# default values, you can set by providing script lie create-db.sh CB_USERNAME=USERNAME
CB_USERNAME=administrator
CB_PASSWORD=administrator
CB_CONTAINER_PREFIX=ecommerce
CB_CLUSTER_NAME=ecommerce
CB_BUCKET_NAME=$CB_CLUSTER_NAME
CB_SCOPE_NAME=_default
CB_HOST=localhost
CB_PORT=8091
ENVS=(test dev)
ENV="test"
CB_COLLECTIONS=(user inventory address cart discount product category role session perm)


#parse args

for arg in $@
do
    case $arg in
        --test) ENV=test;;
        --dev)  ENV=dev;;
        CB_USERNAME=*)  
            CB_USERNAME=$(echo $arg | cut  -c13- )
        ;;
        CB_PASSWORD=*)
            CB_PASSWORD=$(echo $arg | cut  -c13- )
        ;;
        CB_CONTAINER_NAME=*)
            CB_CONTAINER_NAME=$(echo $arg | cut -c19- )
        ;;
        CB_CLUSTER_NAME=*)
            CB_CLUSTER_NAME=$(echo $arg | cut -c17-)
        ;;
        CB_BUCKET_NAME=*)
            CB_BUCKET_NAME=$(echo $arg | cut -c16-)
        ;;
        CB_SCOPE_NAME=*)
            CB_SCOPE_NAME=$(echo $arg | cut -c16-)
        ;;
        CB_CONTAINER_PREFIX=*)
            CB_CONTAINER_PREFIX=$(echo $arg | cut -c21-)
        ;;
        CB_SCOPE=*)
            CB_SCOPE=$(echo $arg | cut -c10-)
        ;;
        CB_HOST=*)
            CB_HOST=$(echo $arg | cut -c9-)
        ;;
        CB_PORT=*)
            CB_PORT=$(echo $arg | cut -c9-)
        ;;
        CB_COLLECTIONS=*)
            CB_COLLECTIONS=$(echo $arg | cut -c16-)
            CB_COLLECTIONS=(${(@s:,:)CB_COLLECTIONS});
        ;;
    esac
done



# creates `ecommerce` cluster if not exist yet
function createCluster() {
    
    echo -e "Creating cluster\n"
    data="$(curl  -o response.txt   -w "%{http_code}"  -X POST http://$CB_HOST:$CB_PORT/clusterInit \
            -d "hostname=127.0.0.1" \
            -d "sendStats=true" \
            -d "services=kv%2Cn1ql%2Cindex" \
            -d "clusterName=$CB_CLUSTER_NAME" \
            -d "memoryQuota=512" \
            -d "afamily=ipv4" \
            -d "afamilyOnly=false" \
            -d "nodeEncryption=off" \
            -d "username=$CB_USERNAME" \
            -d "password=$CB_PASSWORD" \
            -d "port=SAME" \
            -d "indexerStorageMode=plasma" \
            -d "allowedHosts=127.0.0.1")";

   
    if [ $data -eq 200 ]; then
        echo -e "Cluster 'ecommerce' created\n "
    else
        echo -e "Cluster 'ecommerce' already exist\nSkipping creating cluster\n "
    fi
    echo -e "______________________________________________________\n "


    rm response.txt
}


function getRunningDbs() {

    if [ $( docker ps -a | grep ecommerce_test | wc -l ) -lt 1 ]; then
        echo "test database container doesnt exist, creating new test database container"
        resp=$(docker create --name ecommerce_test -p  8091-8097:8091-8097 -p 9123:9123 -p 9140:9140  -p 11210-11211:11210-11211 -p 11280:11280  couchbase)
    fi

    if [ $( docker ps -a | grep ecommerce_dev | wc -l ) -lt 1 ]; then
        echo "dev database container doesnt exist, creating new dev database container\n"
        docker create --name ecommerce_dev -p  8091-8097:8091-8097 -p 9123:9123 -p 9140:9140  -p 11210-11211:11210-11211 -p 11280:11280 couchbase
    fi

  

}


function shutDownTestDatabase() {
     testDb=$(docker container inspect ecommerce_test | grep -oP '(?<="Status": ")[^"]*' ) 

    if [ "$testDb" = "running" ]; then
        echo -e "test database running, shutting down dev database\n"
        resp=$(docker container stop ecommerce_test)
        echo "test database shutted down\n"
    fi
}

function wait_for() {
    timeout=$1
    shift 1
    until [ $timeout -le 0 ] || ("$@" &> /dev/null); do
        echo waiting for "$@"
        sleep 1
        timeout=$(( timeout - 1 ))
    done
    if [ $timeout -le 0 ]; then
        return 1
    fi
}

function startTestDatabase() {
    testDb=$(docker container inspect ecommerce_test | grep -oP '(?<="Status": ")[^"]*' ) 
    if [ "$testDb" = "running" ]; then
        echo -e "test database already running\n"
    else 
        resp=$(docker container start ecommerce_test)
        sleep 20s
        echo "test database started\n"
        devDb=$(docker container inspect ecommerce_dev | grep -oP '(?<="Status": ")[^"]*' ) 
    fi
}


function shutDownDevDatabase() {
    devDb=$(docker container inspect ecommerce_dev | grep -oP '(?<="Status": ")[^"]*' ) 

    if [ "$devDb" = "running" ]; then
        echo -e "dev database running, shutting down dev database\n"
        resp=$(docker container stop ecommerce_dev)
        echo "dev database shutted down\n"
    fi
}


function startDevDatabase() {
    devDb=$(docker container inspect ecommerce_dev | grep -oP '(?<="Status": ")[^"]*' ) 
    if [ "$devDb" = "running" ]; then
        echo -e "dev database already running\n"
    else 
        resp=$(docker container start ecommerce_dev)
        sleep 20s
        echo "dev database started\n"

        
        testDb=$(docker container inspect ecommerce_test  | grep -oP '(?<="Status": ")[^"]*' ) 
    fi
}


# creates test and dev env buckets
function createBucket() {

    data=$(curl -s -i -o response.txt  -w "%{http_code}" \
            -X POST http://$CB_HOST:$CB_PORT/pools/default/buckets \
            -u $CB_USERNAME:$CB_PASSWORD \
            -d name=$CB_BUCKET_NAME \
            -d bucketType=couchbase \
            -d ramQuota=512 \
            -d durabilityMinLevel=none \
            -d flushEnabled=1); 
    
    rm response.txt
};


function flushTestDbBucket() {

  
    echo -e "______________________________________________________\n "
    echo -e "check if bucket exist\n"
    data=$(curl -s -i -o response.txt  -w "%{http_code}"  -X POST -u $CB_USERNAME:$CB_PASSWORD \
        http://$CB_HOST:$CB_PORT/pools/default/buckets/$CB_BUCKET_NAME/controller/doFlush)

    echo -e "______________________________________________________\n "

    if [ "$data" = "200" ]; then
        echo -e "Bucket exist\nBucket flushed\n"
    else 
        echo -e "Bucket doest not exist\n"
    fi
    rm response.txt
}


function createCollections() {
    # loop for al buckets
    for bucket in "${CB_BUCKETS[@]}"
    do
        # create collections in each bucket
        for collection in "${CB_COLLECTIONS[@]}"
        do
            data=$(curl -s -i -o response.txt   -w "%{http_code}" -X POST  http://$CB_HOST:$CB_PORT/pools/default/buckets/$bucket/scopes/_default/collections \
                    -u $CB_USERNAME:$CB_PASSWORD \
                    -d name="$collection" \
                    -d maxTTL=0)
            if [ $data -eq 200 ]
            then 
                echo  "Collection '$collection' created\n"
            else 
                echo "Error:collection exist; quit with exit code 1"
                exit 1
            fi
            rm response.txt 
            
        done
    done
      
}


if  [ "$ENV" = "test" ]; then
    flushTestDbBucket

fi

    createCluster
    createBucket
    createCollections

