const { connect, PasswordAuthenticator } = require("couchbase");



; (async () => {

    // connect db
    const cluster = await connect(
        "couchbase://localhost",
        new PasswordAuthenticator("administrator", "administrator"));
    const bucket = cluster.bucket("ecommerce")

       //#region  create indexes
    //
    const collections = ["user", "invertory", "address", "cart", "discount", "product", "category", "role", "session", "perm"]
    
    for await (const collection of collections) {

        console.log(" ___________________")
        console.log("creating primary index on collection: %s", collection)
        try {
            await cluster.query(`CREATE PRIMARY INDEX \`#${collection}\` ON \`ecommerce\`._default.\`${collection}\``)
        } catch (error) {
             console.log("primary index already exist on collection: %s", collection)
        }

    }
  
    //#endregion

})();