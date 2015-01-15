Testify = require("testify")

assert = require("assert")

Client = require("patchboard-js")

window.onload = ->
  Testify.reporter = new Testify.DOMReporter("testify", 1000)

  Client.discover "http://localhost:1979/", (error, client) ->
    throw error if error

    {resources} = client
    Testify.test "Trivial API", (suite) ->

      suite.test "create a user", (context) ->

        login = Math.random().toString()

        resources.users.create {login: login}, (error, response) ->
          context.test "Expected response", ->
            assert.ifError(error)

          context.test "has expected fields", ->
            {resource} = response
            assert.equal resource.login, login
            assert.ok resource.url
            assert.ok !resource.email

          context.test "has expected subresources", ->
            {resource} = response
            assert.equal resource.questions.constructor, Function

          suite.test "searching for a user", (context) ->
            resources.user_search(login: login).get (error, response) ->
              context.test "Expected response", ->
                assert.ifError(error)

              context.test "user is good", ->
                user = response.resource
                assert.equal user.resource_type, "user"

          suite.test "asking for a question", (context) ->
            {resource} = response
            resource.questions(category: "Science").ask (error, {resource}) ->

              context.test "Expected response", ->
                assert.ifError(error)

              context.test "question has expected fields", ->
                assert.ok resource.url
                assert.ok resource.question
                assert.ok "abcd".split("").every (item) ->
                  resource[item]

              suite.test "answering the question", (context) ->
                resource.answer {letter: "d"}, (error, response) ->

                  context.test "Expected response", ->
                    assert.ifError(error)

                  context.test "success", ->
                    result = response.resource
                    assert.equal result.success, true
                    assert.equal result.correct, "d"

                    suite.test "attempting to answer again", (context) ->
                      resource.answer {letter: "d"}, (error, response) ->

                        context.test "receive expected HTTP error", ->
                          assert.ok error
                          assert.equal error.status, 409
                          data = JSON.parse error.response.body
                          assert.equal data.message, "conflict"


