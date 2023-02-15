#!/bin/zsh

if [ ! -x "$(which curl)" ]; then
    echo Please install curl before running this script
    exit 0
fi

echo -e "Createing bucket name ecommerce on couchbas://localhost:8091\n___________________"

data=$(curl -s -i -o response.txt   -w "%{http_code}"  -X POST http://localhost:8091/pools/default/buckets \
                -u administrator:administrator \
                -d name=ecommerce \
                -d bucketType=couchbase \
                -d ramQuota=512 \
                -d durabilityMinLevel=none); 

rm response.txt 

if [ $data -eq 400 ]; then
    echo -e "Bucket 'ecommerce' already exist\nSkipping creating bucket\n___________________"
elif [ $data -eq 200 ]; then
    echo -e "Bucket 'ecommerce' created\n___________________"
fi

echo "Creating collections on ecommerce._default"

collections=(user inventory address cart discount product category role session perm)


for collection in "${collections[@]}"
do
    data=$(curl -s -i -o response.txt   -w "%{http_code}" -X POST  http://localhost:8091/pools/default/buckets/ecommerce/scopes/_default/collections \
            -u administrator:administrator \
            -d name="$collection" \
            -d maxTTL=0)
    if [ $data -eq 200 ];then echo -e "Collection '$collection' created on ecommerce._d fault\n___"
    else echo -e "Collection '$collection' already exist in ecommerce._default. Skipped creating collection\n___"; fi
    rm response.txt 
    
done


echo -e "___________________\nSeeding db"


if (( !$2 -eq "test" )); then
cd "$1/seed-db"

npm install -s

node index -s
echo "Done."

fi