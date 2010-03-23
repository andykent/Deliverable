deliverable: require '../lib/deliverable'
http: require 'http'
assert: require 'assert'

requestCount: 0

responder: http.createServer (request, response) ->
  request.body = ''
  request.addListener 'data', (data) -> request.body += data
  request.addListener 'end', (data) ->
    requestCount++
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

get '/deliver', {'X-Deliverable-Endpoint': 'http://localhost:1234'}, ->
  setTimeout (->
    deliverable.stop()
    responder.close()), 100

process.addListener 'exit', -> 
  assert.equal requestCount, 1