deliverable: require '../lib/deliverable'
http: require 'http'
assert: require 'assert'
sys: require 'sys'

requestCount: 0
aRequest: false
bRequest: false

responder: http.createServer (request, response) ->
  request.body = ''
  request.addListener 'data', (data) -> request.body += data
  request.addListener 'end', (data) ->
    requestCount++
    aRequest: true if request.url is '/a'
    bRequest: true if request.url is '/b'
    response.writeHeader 200, {'Content-Type': 'text/plain'}
    response.write 'ok'
    response.close()
responder.listen 1234


client: http.createClient 5678, "localhost"

get: (url, headers, callback) ->
  request: client.request "GET", url, headers
  request.addListener 'response', (response) ->
    response.body: ''
    response.setBodyEncoding "utf8"
    response.addListener "data", (chunk) -> response.body+=chunk

    response.addListener "end", -> 
      callback(response) if callback
  request.close()



deliverable.start()

get '/deliver', {'X-Deliverable-Endpoint': 'http://localhost:1234/a; http://localhost:1234/b'}, -> 
  setTimeout (->
    deliverable.stop()
    responder.close()), 100

process.addListener 'exit', -> 
  assert.equal requestCount, 2
  assert.ok aRequest
  assert.ok bRequest