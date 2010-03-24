sys: require 'sys'
fs: require 'fs'


runTest: (i,files) ->
  file: files[i]
  return unless file.match(/test\.coffee$/)
  filePath: path.join(__dirname, '../test', file)
  exec 'coffee ' + filePath, (err) ->
    if err
      sys.puts 'error in '+filePath
      throw err
    else
      runTest(i+1, files) if i < files.length-1

task 'build', 'build the app', ->
  exec 'coffee -c -o lib src/*', (err) ->
    throw err if err

task 'test', 'run tests', ->
  fs.readdir 'test', (err, files) ->
    runTest(0, files)