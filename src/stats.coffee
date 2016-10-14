_          = require 'lodash'
colors     = require 'colors'
async      = require 'async'
Docker     = require './docker'
prettysize = require 'prettysize'
debug      = require('debug')('octodocker:stats-model')

class Stats
  constructor: ({ stackEnvDir }) ->
    throw new Error 'Missing stackEnvDir' unless stackEnvDir?
    @docker = new Docker { stackEnvDir }

  print: ({ filter }, callback) =>
    keyLength = 0
    @docker.eachContainer { filter }, ({ containerName, machineName }, container, next) =>
      @sampleStats container, (error, stats) =>
        return next error if error?
        key = "[#{machineName.cyan}] #{containerName.bold}"
        debug { machineName, containerName, stats }
        keyLength = key.length if key.length > keyLength
        paddedKey = _.padEnd key, keyLength - key.length
        console.log "#{paddedKey}: #{'CPU'.underline}: #{stats.cpu_percent}% #{'MEM'.underline}: #{stats.memory_usage} / #{stats.memory_max}"
        next()
    , callback

  getStats: (container, callback) =>
    container.stats { stream: false }, callback

  sampleStats: (container, callback) =>
    sampleCount = 0
    cpuSum = 0
    sysSum = 0
    lastStats = null
    async.timesSeries 2, (n, next) =>
      @getStats container, (error, stats) =>
        return next error if error?
        sampleCount++

        cpuSum += stats.cpu_stats.cpu_usage.total_usage
        sysSum += stats.cpu_stats.system_cpu_usage
        lastStats = stats
        return _.delay next, 50 if n > 0
        next()
    , (error) =>
      return callback error if error?
      lastStats.cpu_stats.cpu_usage.total_usage = cpuSum / sampleCount
      lastStats.cpu_stats.system_cpu_usage = sysSum / sampleCount
      stats = @_parseStats lastStats
      callback null, stats

  _parseStats: (stats) =>
    return {
      cpu_percent: @_getCPU(stats),
      memory_usage: prettysize(stats.memory_stats.usage),
      memory_max: prettysize(stats.memory_stats.max_usage),
    }

  _getCPU: (stats) =>
    cpu = stats.cpu_stats.cpu_usage.total_usage
    systemCpu = stats.cpu_stats.system_cpu_usage
    percpu = stats.cpu_stats.cpu_usage.percpu_usage.length
    rawPercent = (cpu * 1.0 / systemCpu) * percpu * 100
    return _.round(rawPercent, 2)

module.exports = Stats
