Testify = require "testify"
assert = require "assert"

Application = require "../../src/application"
app = new Application
  question_ttl: 100

Testify.test "Trivial Application", (suite) ->


  suite.test "creating a user", (context) ->
    app.create_user {login: "matthew"}, (error, user) ->
      context.test "result has expected properties", ->
        assert.equal user.login, "matthew"
        assert.equal user.asked?.constructor, Object

      suite.test "logging in", (context) ->
        app.login login: "matthew", (error, user) ->
          context.test "supplies user in callback", ->
            assert.ifError error
            assert.ok user

      suite.test "attempting to create user with existing login", (context) ->
        app.create_user {login: "matthew"}, (error, user) ->
          context.test "receive expected error", ->
            assert.ok error
            assert.equal error.name, "conflict"


        suite.test "asking a question", (context) ->

          app.ask user.id, (error, question) ->

            context.test "expected properties", ->
              assert.ok !question.answer

            context.test "answering the question correctly", (context) ->
              # What a cheater.
              correct_answer = app.questions.user_questions[question.id].answer
              app.answer_question question.id,
                {letter: correct_answer}, (error, result) ->
                  context.test "receive successful result", ->
                    assert.equal result.success, true
                    assert.ok result.correct

            context.test "attempting to answer again", (context) ->
              app.answer_question question.id, {letter: "a"}, (error, result) ->
                context.test "receive correct error", ->
                  assert.ok error
                  assert.equal error.name, "conflict"

        context.test "answering a question after expiry", (context) ->
          app.ask user.id, (error, question) ->
            fn = ->
              app.answer_question question.id, {letter: "a"}, (error, result) ->
                context.test "receive correct error", ->
                  assert.ok error
                  assert.equal error.name, "forbidden"
            setTimeout fn, 120



