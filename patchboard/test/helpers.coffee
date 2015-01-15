fs = require("fs")
# read login:password from a file
string = fs.readFileSync("auth").toString()
string = string.slice(0, string.length-1)
[login, password] = string.split(":")

module.exports = {login, password}
