program = require 'commander'
Stats  = require './src/stats'
debug   = require('debug')('octodocker:stats')

program
  .version require('./package.json').version
  .usage '[options] <filter>'

class Command
  constructor: ->
    process.on 'uncaughtException', @die

  parseOptions: =>
    program.parse process.argv

    filter = program.args[0]

    stackEnvDir = process.env.STACK_ENV_DIR
    @dieHelp new Error 'Missing STACK_ENV_DIR' unless stackEnvDir?

    return { stackEnvDir, filter }

  run: =>
    { stackEnvDir, filter } = @parseOptions()
    stats = new Stats { stackEnvDir }
    stats.print { filter }, @die

  dieHelp: (error) =>
    program.outputHelp()
    return @die error

  die: (error) =>
    return process.exit(0) unless error?
    console.error error.stack
    process.exit 1

module.exports = Command
