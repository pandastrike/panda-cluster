module.exports = (application, database) ->

  response_callback = (context) ->
    context.set_cors_headers "*"
    {match} = context
    resource_type = match.resource_type
    status = match.success_status || 200
    (error, result) ->
      if error
        context.error error.name, error.message
      else
        context.respond status, result

  clusters:
    # FIXME: figure out async
    create: async (context) ->
      {account, cluster_name} = context.request.body
      rand_url = Math.random().toString(36).substring(20)
      try
        updated_doc = database.update { account: account.email },
          { $set: { "clusters.#{cluster_name}": rand_url } },
          { multi: false }
        # FIXME: properly return the URL to destroy this cluster
        context.rand_url = context.url + "/clusters/destroy/#{rand_url}"
        application.create context.request.body, response_callback(context)
      catch
        context.error 500, "something done broke"
    destroy: async (context) ->
      # FIXME: should rand_url actually be in the url if you also need to send token anyway
      # FIXME: mappings.coffee: how to allow both set path and template path with var :url
      {account, cluster_name, url} = context.request.body
      try
        doc = database.findOne { account: account.email, "account.clusters.#{cluster_name}": url },
        application.destroy context.request.body, response_callback(context)
      catch
        context.error 500, "something done broke"

  users:
    create: async (context) ->
      try
        {email} = context.request.body.account
        account = database.insert { "accounts.#{email}": context.request.body }
        application.create context.request.body, response_callback(context)
      catch
        context.error 500, "something done broke"

  # TODO: support get and delete user? 
  user:
    get: (context) ->
      application.get_user context.match.path.id, response_callback(context)
    delete: (context) ->
      application.delete_user context.match.path.id, response_callback(context)

#  questions:
#    ask: (context) ->
#      context.set_cors_headers "*"
#      user_id = context.match.path.id
#      application.ask user_id, (error, result) ->
#        if error
#          context.error error.name, error.message
#        else
#          if result
#            context.respond 201, result
#          else
#            # There are no more questions to ask.
#            url = context.url "statistics", user_id
#            context.respond 303, {url: url},
#              "Location": url
#              "Content-Type": "application/json"
#
#
#  question:
#    answer: (context) ->
#      context.set_cors_headers "*"
#      id = context.match.path.id
#      answer = context.request.body
#      application.answer_question id, answer, response_callback(context)
#
#  #statistics:
#    #get: (context) ->
#      #id = context.match.path.id
#      #application.statistics id, response_callback(context)
#
#  #global_statistics:
#    #get: (context) ->
#      #application.global_statistics response_callback(context)
#
#
#
