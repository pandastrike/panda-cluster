media_type = (name) ->
  "application/vnd.trivial.#{name}+json;version=1.0"

module.exports =

  id: "urn:patchboard.trivial"
  definitions:

    cluster:
      mediaType: media_type "cluster"

#    user:
#      extends: {$ref: "urn:patchboard#resource"}
#      mediaType: media_type "user"
#      properties:
#        login:
#          required: true
#          type: "string"
#          pattern: "^[a-zA-z0-9_.]{3,32}"
#        email:
#          type: "string"
#          format: "email"
#        password:
#          type: "string"
#          minLength: 4
#          maxLength: 64
#        questions: {$ref: "#questions"}
#        answered:
#          type: "array"
#          items: {$ref: "#question"}
#
#    questions:
#      mediaType: media_type "questions"
#      extends: {$ref: "urn:patchboard#resource"}
#
#    question:
#      extends: {$ref: "urn:patchboard#resource"}
#      mediaType: media_type "question"
#      properties:
#        expires:
#          type: "integer"
#          format: "utc-millisec"
#        question:
#          type: "string"
#        answers:
#          type: "object"
#          additionalProperties:
#            type: "string"
#
#    answer:
#      mediaType: media_type "answer"
#      type: "object"
#      properties:
#        letter:
#          type: "string"
#          enum: ["a", "b", "c", "d"]
#        blank:
#          type: "string"
#
#    result:
#      type: "object"
#      mediaType: media_type "result"
#      properties:
#        success: {type: "boolean"}
#        correct: {type: "string"}
#
#    #global_statistics:
#      #extends: {$ref: "urn:patchboard#resource"}
#
#    #statistics:
#      #extends: {$ref: "urn:patchboard#resource"}
#      #mediaType: media_type "statistics"
#      #properties:
#        #questions: {type: "integer"}
#        #correct: {type: "integer"}
#        #incorrect: {type: "integer"}
#        #timeouts: {type: "integer"}
#        #score: {type: "number"}
#        #percentile: {type: "integer"}
#
