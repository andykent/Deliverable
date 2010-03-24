deliverable: require '../lib/deliverable'
http: require 'http'
assert: require 'assert'

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

get '/stats', {}, (response) -> 
  data: JSON.parse response.body
  assert.equal data.MAX_ATTEMPTS, 5
  assert.equal data.RETRY_DELAY, 5 * 1000
  assert.equal data.TOTAL_DELIVERIES, 0
  assert.equal data.ACTIVE_DELIVERIES, 0
  assert.equal data.SUCCESSFUL_DELIVERIES, 0
  assert.equal data.FAILED_DELIVERIES, 0
  assert.equal data.TOTAL_DELIVERY_ATTEMPTS, 0

  get '/deliver', {'X-Deliverable-Endpoint': 'http://localhost:1234'}, ->
    get '/stats', {}, (response) -> 
      data: JSON.parse response.body
      assert.equal data.TOTAL_DELIVERIES, 1
      assert.equal data.ACTIVE_DELIVERIES, 1
      assert.equal data.TOTAL_DELIVERY_ATTEMPTS, 1
      deliverable.stop()
