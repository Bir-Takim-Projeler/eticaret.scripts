
const { connect, PasswordAuthenticator } = require("couchbase");
const { users } = require("./user");
const { products, category } = require("./product");
const { createId } = require("@paralleldrive/cuid2")


//#region  mock data
const perm = {
    id: createId(),
    name: "addProduct",
    description: "can add product to database with this perm"
}

const roles = [
    {
    id: createId(),
    name: "admin",
    perms: [perm.id],
    description: "admin role"
    },
    {
        id: createId(),
        name: "user",
        perms: []
    }
]
    
const users = [
    {
        id: createId(),
        userName: "jdoe",
        firstName: "jhon",
        lastName: "doe",
        phone: "+000 0000 00",
        email: "jdoe@jdoe.com",
        address: [],
        roles: [role[1].id],
        sessions: []
    },
    {
        id: createId(),
        userName: "mdoe",
        firstName: "marry",
        lastName: "doe",
        phone: "+100 0000 00",
        email: "mdoe@mdoe.com",
        address: [],
        roles: [role[1].id],
        sessions: []
    },
    {
        id: createId(),
        userName: "admin",
        firstName: "admin",
        lastName: "admin",
        email: "admin@admin.com",
        address: [],
        roles: [role[0].id]
    }
]
    
const category = {
    id: createId(),
    name: "Telefon",
    description: "akilli telefonlar"
}
    
const products = [
    {
        id: createId(),
        name: "Iphone X",
        brand: "apple",
        sku: ["11021412"],
        specs: {},
        price: {
            type: "TL",
            unit: "11000",
            task: "18"
        },
        category: category.id,
        invertory: null,
        discount: null
    },
    {
        id: createId(), 
        name: "Red mi note9 pro",
        brand: "xiomi",
        sku: ["1189312"],
        description: "mir4 oynatmaz",
        price: {
            type: "TL",
            unit: "11000",
            task: "18"
        },
        category: category.id,
        invertory: null,
        discount: null
    }
]
    
//#endregion /mockdata

; (async () => {

    // connect db
    const cluster = await connect(
        "couchbase://localhost",
        new PasswordAuthenticator("administrator", "administrator"));
    const bucket = cluster.bucket("ecommerce")
    
    //#region buckets
    const userCollection     = bucket.collection("user")
    const permCollection     = bucket.collection("perm")
    const roleCollection     = bucket.collection("role")
    const productCollection  = bucket.collection("product")
    const categoryCollection = bucket.collection("category")
    //#endregion /buckets
    
    
    // add users
    for await (const user of users) await userCollection.insert(user.id, user)
    
    // add permission
    await permCollection.insert(perm.id, perm)

    // add roles
    for await (const role of roles) await roleCollection.insert(role.id, role)

    // add category
    await categoryCollection.insert(category.id, category)

    // add products
    for await (const product of products) await productCollection.insert(product.id, product)

})();