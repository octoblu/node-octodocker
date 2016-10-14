_         = require 'lodash'
fs        = require 'fs'
path      = require 'path'
async     = require 'async'
Dockerode = require 'dockerode'

class Docker
  constructor: ({ stackEnvDir }) ->
    throw new Error 'Missing stackEnvDir' unless stackEnvDir?
    @machineDir = path.join(stackEnvDir, 'machine', 'machines')
    @machines = {}
    @_init()

  each: (fn, done) =>
    async.eachOf @machines, fn, done

  eachContainer: ({ filter }, fn, done) =>
    @each (machine, machineId, nextMachine) =>
      machineName = @_getMachineName(machineId)
      machine.listContainers (error, containers) =>
        return done error if error?
        async.eachLimit containers, 5, (containerInfo, next) =>
          containerName = @_getContainerName(containerInfo)
          return next() if filter? && containerName.indexOf(filter) < 0
          fn({ containerName, machineId, machineName, containerInfo }, machine.getContainer(containerInfo.Id), next)
        , nextMachine
    , done

  _getContainerName: (containerInfo) =>
    return _.first(containerInfo.Names)?.replace(/^\//, '')?.replace(/\.\w+$/, '')

  _getMachineName: (machineId) =>
    stackName = process.env.STACK_NAME
    machineId.replace("#{stackName}-", '')

  _init: =>
    files = fs.readdirSync @machineDir
    _.each files, @_initDocker

  _initDocker: (machineId) =>
    config = require(path.join(@machineDir, machineId, 'config.json'))
    @machines[machineId] = new Dockerode {
      host: config.Driver.IPAddress,
      port: 2376,
      ca: @_cert(machineId, 'ca'),
      cert: @_cert(machineId, 'cert'),
      key: @_cert(machineId, 'key')
    }

  _cert: (machineId, name) =>
    return fs.readFileSync path.join(@machineDir, machineId, "#{name}.pem")

module.exports = Docker
