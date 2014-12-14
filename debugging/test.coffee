{resolve} = require "path"
{parse} = require "c50n"
{read} = require "fairmont"
pc = require "../src/pandacluster"

options =
  channel: "stable"
  virtualization: "pv"
  write_path: "#{process.cwd()}/template.json"
  units: [{
    name: "docker-tcp.socket"
    runtime: "true"
    command: "start"
    enable: "yes"
    content: "../units/docker-tcp.service"
  },
  {
    name: "enable-docker-tcp.service"
    runtime: "true"
    command: "start"
    content: "../units/docker-tcp.service"
  }]

options2 = parse (read (resolve ("template-config.cson")))
pc.customize_template( options2 )
