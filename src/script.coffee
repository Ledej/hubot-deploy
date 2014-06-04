# Description
#   Cut GitHub deployments from chat that deploy via hooks - https://github.com/atmos/hubot-deploy
#
# Commands:
#   hubot deploy - show detailed deployment usage, including apps and environments
#   hubot deploy <app>/<branch> to <env>/<roles> - deploys <app>'s <branch> to the <env> environment's <roles> servers
#   hubot where can I deploy <app> - see what environments you can deploy app
#   hubot deploy:lock <app> in <env> <reason> - lock the app in an environment with a reason
#   hubot deploy:unlock <app> in <env> - unlock an app in an environment
#   hubot auto-deploy:enable <app> in <env> - enable auto-deployment for the app in environment
#   hubot auto-deploy:disable <app> in <env> - disable auto-deployment for the app in environment
#
supported_tasks = [ DeployPrefix ]

Path          = require("path")
Deployment    = require(Path.join(__dirname, "deployment")).Deployment
DeployPrefix  = require(Path.join(__dirname, "patterns")).DeployPrefix
DeployPattern = require(Path.join(__dirname, "patterns")).DeployPattern
###########################################################################
module.exports = (robot) ->

  deployHelpRegex = new RegExp("#{DeployPrefix}\\??$", "i")
  robot.respond deployHelpRegex, (msg) ->
    console.log robot.helpCommands()
    cmds = robot.helpCommands().filter (cmd) ->
      cmd.match new RegExp("deploy", 'i')

    console.logs cmds
    if cmds.length == 0
      msg.send "No available commands match #{filter}"
      return

    prefix = robot.alias or robot.name
    cmds = cmds.map (cmd) ->
      cmd = cmd.replace /^hubot/, prefix
      cmd = cmd.replace /hubot/ig, robot.name
      cmd.replace /deploy/ig, DeployPrefix

    msg.send cmds.join "\n"

  deployEnvironmentRegex = new RegExp("where can i #{DeployPrefix} ([-_\.0-9a-z]+)\\?*$", "i")
  robot.respond deployEnvironmentRegex, (msg) ->
    name = msg.match[1]

    deployment = new Deployment(name, "unknown", "q")

    output  = "Environments for #{deployment.name}\n"
    output += "----------------------------------------------------------\n"
    for environment in deployment.environments
      output += "#{environment}      | Unknown state :cry:\n"
      output += "----------------------------------------------------------\n"

    msg.send output

  deployVersionRegex = new RegExp("#{DeployPrefix}\:version", "i")
  robot.respond deployVersionRegex, (msg) ->
    pkg = require Path.join __dirname, '..', 'package.json'
    msg.send "hubot-deploy v#{pkg.version}/hubot v#{robot.version}/node #{process.version}"

  robot.respond DeployPattern, (msg) ->
    task  = msg.match[1].replace(DeployPrefix, "deploy")
    force = msg.match[2] == '!'
    name  = msg.match[3]
    ref   = (msg.match[4]||'master')
    env   = (msg.match[5]||'production')
    hosts = (msg.match[6]||'')

    console.log "ohai 3"

    deployment = new Deployment(name, ref, task, env, force, hosts)

    unless deployment.isValidApp()
      msg.reply "#{name}? Never heard of it."
      return
    unless deployment.isValidEnv()
      msg.reply "#{name} doesn't seem to have an #{env} environment."
      return

    deployment.room = msg.message.user.room
    deployment.user = msg.envelope.user.name

    deployment.adapter = robot.adapterName

    console.log JSON.stringify(deployment.requestBody())

    deployment.post (responseMessage) ->
      msg.reply responseMessage if responseMessage?

