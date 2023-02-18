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
ENV="test"
SEED=0
CB_COLLECTIONS=(user inventory address cart discount product category role session perm)


#parse args

for arg in $@
do
    case $arg in
        --test) ENV=test;;
        --dev)  ENV=dev;;
        --seed) SEED=1;;
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
    data="$(curl -s -i -o response.txt -w "%{http_code}" -X POST http://$CB_HOST:$CB_PORT/clusterInit \
    -d "services=kv%2Cn1ql%2Cindex" \
    -d "clusterName=$CB_CLUSTER_NAME" \
    -d "memoryQuota=512" \
    -d "nodeEncryption=off" \
    -d "username=$CB_USERNAME" \
    -d "password=$CB_PASSWORD" \
    -d "port=SAME" )";

    rm response.txt 
    if [ $data -eq 200 ]; then
        echo -e "Cluster 'ecommerce' created\n "
    else
        echo -e "Cluster 'ecommerce' already exist\nSkipping creating cluster\n "
    fi
    echo -e "______________________________________________________\n "
}


function getRunningDbs() {

    if [ $( docker ps -a | grep ecommerce_test | wc -l ) -lt 1 ]; then
        echo "test database container doesnt exist, creating new test database container"
        resp=$(docker create --name ecommerce_test -p 8091-8096:8091-8096 -p 11210-11211:11210-11211 couchbase)
    fi

    if [ $( docker ps -a | grep ecommerce_dev | wc -l ) -lt 1 ]; then
        echo "dev database container doesnt exist, creating new dev database container\n"
        docker create --name ecommerce_dev -p 8091-8096:8091-8096 -p 11210-11211:11210-11211 couchbase
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


: '
    creates `ecommerce` bucket if not exist yet
'
function createBucket() {
    echo -e "Createing bucket name \"$CB_BUCKET_NAME\" on couchbas://$CB_HOST\n"
    data=$(curl -s -i -o response.txt   -w "%{http_code}"  -X POST http://$CB_HOST:$CB_PORT/pools/default/buckets \
                    -u $CB_USERNAME:$CB_PASSWORD \
                    -d name=$CB_BUCKET_NAME \
                    -d bucketType=couchbase \
                    -d ramQuota=512 \
                    -d durabilityMinLevel=none \
                    -d flushEnabled=1); 
    
    rm response.txt
    if [ $data -eq 400 ]; then
        echo -e "Bucket \'ecommerce\' already exist\nSkipping creating bucket\n"
    elif [ $data -eq 200 ]; then
        echo -e "Bucket 'ecommerce' created\n"
    fi
    echo -e "______________________________________________________\n"
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
    echo -e "______________________________________________________\n "
    echo -e "Checking collections\n"
    for collection in "${CB_COLLECTIONS[@]}"
    do
        data=$(curl -s -i -o response.txt   -w "%{http_code}" -X POST  http://$CB_HOST:$CB_PORT/pools/default/buckets/$CB_BUCKET_NAME/scopes/_default/collections \
                -u $CB_USERNAME:$CB_PASSWORD \
                -d name="$collection" \
                -d maxTTL=0)
        if [ $data -eq 200 ];then echo -e "Collection '$collection' created\n"
        else echo -e "Collection '$collection' already exist\n"; fi
        rm response.txt 
        
    done
    echo -e "______________________________________________________\n "
      
}

npm install seed-db/package.json -s
node seed-db/index.js -s

if  [ "$ENV" = "test" ]; then

    echo -e "Script running on $ENV enviroment\n"
    getRunningDbs
    shutDownDevDatabase
    startTestDatabase
    createCluster
    flushTestDbBucket
    createBucket
    createCollections
elif [ "$ENV" = "dev" ]; then
    echo -e "build database for development env"
    getRunningDbs
    shutDownTestDatabase
    startDevDatabase
    createCluster
    createBucket
    createCollections
 
 
    if [ $SEED ]; then
        echo seed 
        node seed-db/seed.js -s
        echo "Done."
    else 
        echo "Done."
    fi
fi


