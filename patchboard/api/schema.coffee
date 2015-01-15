module.exports =
  id: "github.com"
  type: "object"
  properties:

    resource:
      properties:
        url:
          type: "string"
          format: "uri"
          readonly: true
        id:
          type: "number"
          readonly: true

    cluster:
      mediaType: "application/vnd.pandacluster+json"
      properties:
        ssh_key: {type: "string", required: "true"}
        cluster_name: {type: "string", required: "true"}
        
