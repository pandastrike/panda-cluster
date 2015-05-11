#===============================================================================
# panda-cluster - DNS
#===============================================================================
{last} = require "fairmont"

module.exports =
  # Enforces "fully qualified" form of hostnames and domains.  Idompotent.
  fully_qualify: (name) ->
    if last(name) == "."
      return name
    else
      return name + "."

  # This is named somewhat sarcastically.  Enforces "regular" form of hostnames
  # and domains that is more expected when navigating.  Idompotnent.
  regularly_qualify: (name) ->
    if last(name) == "."
      return name[...-1]
    else
      return name

  # Given a URL of many possible formats, return the root domain.
  # TODO: This could use some polish.
  # https://awesome.example.com/test/42#?=What+is+the+answer  =>  example.com.
  root: (url) ->
    try
      # Find and remove protocol (http, ftp, etc.), if present, and get domain

      if url.indexOf("://") != -1
        domain = url.split('/')[2]
      else
        domain = url.split('/')[0]

      # Find and remove port number
      domain = domain.split(':')[0]

      # Now grab the root domain, the top-level-domain, plus what's to the left of it.
      # Be careful of tld's that are followed by a period.
      foo = domain.split "."
      if foo[foo.length - 1] == ""
        domain = "#{foo[foo.length - 3]}.#{foo[foo.length - 2]}"
      else
        domain = "#{foo[foo.length - 2]}.#{foo[foo.length - 1]}"

      # And finally, make the sure the root_domain ends with a "."
      domain = domain + "."
      return domain
