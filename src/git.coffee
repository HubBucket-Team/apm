{spawn} = require 'child_process'
path = require 'path'
_ = require 'underscore-plus'
npm = require 'npm'
config = require './apm'
fs = require './fs'

addPortableGitToEnv = (env) ->
  localAppData = env.LOCALAPPDATA
  return unless localAppData

  githubPath = path.join(localAppData, 'GitHub')

  try
    children = fs.readdirSync(githubPath)
  catch error
    return

  for child in children when child.indexOf('PortableGit_') is 0
    cmdPath = path.join(githubPath, child, 'cmd')
    binPath = path.join(githubPath, child, 'bin')
    corePath = path.join(githubPath, child, 'mingw64', 'libexec', 'git-core')
    unless fs.isDirectorySync(corePath)
      corePath = path.join(githubPath, child, 'mingw32', 'libexec', 'git-core')
    if env.Path
      env.Path += "#{path.delimiter}#{cmdPath}#{path.delimiter}#{binPath}#{path.delimiter}#{corePath}"
    else
      env.Path = "#{cmdPath}#{path.delimiter}#{binPath}#{path.delimiter}#{corePath}"
    break

  return

addGitBashToEnv = (env) ->
  # First, check ProgramW6432, as it will _always_ point to the 64-bit Program Files directory
  if env.ProgramW6432
    gitPath = path.join(env.ProgramW6432, 'Git')

  # Next, check ProgramFiles - this will point to x86 Program Files
  # when running a 32-bit process on x64, 64-bit Program Files
  # when running a 64-bit process on x64, and x86 Program Files when running on 32-bit Windows
  unless fs.isDirectorySync(gitPath)
    if env.ProgramFiles
      gitPath = path.join(env.ProgramFiles, 'Git')

  # Finally, check ProgramFiles(x86) to see if 32-bit Git was installed on 64-bit Windows
  unless fs.isDirectorySync(gitPath)
    if env['ProgramFiles(x86)']
      gitPath = path.join(env['ProgramFiles(x86)'], 'Git')

  return unless fs.isDirectorySync(gitPath)

  # corePath = path.join(gitPath, 'mingw64', 'libexec', 'git-core')
  # unless fs.isDirectorySync(corePath)
  #   corePath = path.join(gitPath, 'mingw32', 'libexec', 'git-core')

  cmdPath = path.join(gitPath, 'cmd')
  binPath = path.join(gitPath, 'bin')
  if env.Path
    env.Path += "#{path.delimiter}#{cmdPath}#{path.delimiter}#{binPath}"
  else
    env.Path = "#{cmdPath}#{path.delimiter}#{binPath}"

exports.addGitToEnv = (env) ->
  return if process.platform isnt 'win32'
  addPortableGitToEnv(env)
  addGitBashToEnv(env)

exports.getGitVersion = (callback) ->
  npmOptions =
    userconfig: config.getUserConfigPath()
    globalconfig: config.getGlobalConfigPath()
  npm.load npmOptions, ->
    git = npm.config.get('git') ? 'git'
    exports.addGitToEnv(process.env)
    spawned = spawn(git, ['--version'])
    outputChunks = []
    spawned.stderr.on 'data', (chunk) -> outputChunks.push(chunk)
    spawned.stdout.on 'data', (chunk) -> outputChunks.push(chunk)
    spawned.on 'error', ->
    spawned.on 'close', (code) ->
      if code is 0
        [gitName, versionName, version] = Buffer.concat(outputChunks).toString().split(' ')
        version = version?.trim()
      callback(version)
