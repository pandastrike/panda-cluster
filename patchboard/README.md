# Patchboard Example: Trivia Game

An example use of [Patchboard](https://github.com/automatthew/patchboard) to
provide an HTTP REST API.

## The Patchboard API Definition

* [URL mappings](./src/api/mappings.coffee)
* [Resource definitions](./src/api/resources.coffee)
* [Schema definitions](./src/api/schema.coffee)


## The Service

* [Server script](./bin/server.coffee)
* [HTTP request handlers](./src/handlers.coffee)
* [Application](./src/application.coffee)

Patchboard.Server uses the API Definition to construct an HTTP request
dispatcher.  The dispatcher takes a dictionary of handlers, which must
correspond to the resources and actions described in the API. The handler
properties represent the resource names.  The value of each property is
a dictionary of actions for that resource.  The value of each action is
a function which will be used to handle an HTTP request.

The application implementation is intentionally simple, meant only to
demonstrate how Patchboard request dispatching can be glued to a backend.


## Usage

Install NPM dependencies:

    npm install

Run the server:

    bin/server.coffee path/to/questions.json

For running the tests below:

    bin/server.coffee test/data/questions.json

## Functional test with Node.js

    coffee test/functional/base.coffee

## Functional test in the browser

The functional tests can also be run in a web browser, using bundled JavaScript.

    cd test/browser
    rake build

Then serve the files in that directory with any web server.  If you have Python
installed you can do this:

    python -m SimpleHTTPServer 9000 # or any available port

Then visit http://localhost:9000/ in a web browser.


## Acknowledgments

Trivia questions came from the "misterhouse" home automation project. I deserve a medal for extracting them from the data format they came in.  Not a very important medal, but something shiny.

https://github.com/hollie/misterhouse

https://github.com/hollie/misterhouse/tree/master/data/trivia

