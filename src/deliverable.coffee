sys:  require 'sys'
http: require 'http'
url: require 'url'

MAX_ATTEMPTS: 5
RETRY_DELAY: 5 * 1000
SERVER_PORT: 5678
MAX_CONNECTIONS: 1024

ACTIVE_CONNECTIONS: 0
TOTAL_DELIVERIES: 0
ACTIVE_DELIVERIES: 0
SUCCESSFUL_DELIVERIES: 0
FAILED_DELIVERIES: 0
TOTAL_DELIVERY_ATTEMPTS: 0

url.fullPath: (uri) ->
  path: ''
  if uri.pathname
    path += uri.pathname
  else
    path += '/'
  path += '?' + uri.query if uri.query and uri.query != ''
  path

class Delivery
  constructor: (endpoint, request) ->
    TOTAL_DELIVERIES++
    ACTIVE_DELIVERIES++
    @id = TOTAL_DELIVERIES
    @request: request
    @attemptCount: 0
    @successful: null
    @endpoint: null
    @callback: null
    @errback: null
    @endpoint:  url.parse(endpoint)
    @callback:  url.parse(request.headers['x-deliverable-callback']) if request.headers['x-deliverable-callback']
    @errback:  url.parse(request.headers['x-deliverable-errback']) if request.headers['x-deliverable-errback']
    @log "Delivery Request Received: " + @endpoint.href
    @deliver()
  deliver: ->
    @attemptCount++
    @log "Atempting Delivery ("+@attemptCount+")"
    new DeliveryAttempt(this).deliver( (delivered) => @attemptComplete(delivered) )
  attemptComplete: (delivered) ->
    @log "Attempt Completed ("+@attemptCount+")"
    return @registerSuccess() if delivered
    if @attemptCount==MAX_ATTEMPTS
      @registerFailure()
    else
      setTimeout((=> @deliver()), (@attemptCount * @attemptCount) * RETRY_DELAY)
  registerSuccess: ->
    @successful: true
    @log "Delivery Successful (after "+@attemptCount+" attempts)"
    SUCCESSFUL_DELIVERIES++
    ACTIVE_DELIVERIES--
    @makeCallbackRequest(@callback) if @callback
  registerFailure: ->
    @successful: false
    @log "Delivery Failed Given Up (after "+@attemptCount+" attempts)"
    FAILED_DELIVERIES++
    ACTIVE_DELIVERIES--
    @makeCallbackRequest(@errback) if @errback
  makeCallbackRequest: (uri) ->
    @log "Running Callback: " + uri.href
    try
      client: http.createClient(uri.port || 80, uri.hostname)
      request: client.request 'POST', url.fullPath(uri)
      request.addListener 'response', (res) => @log "Callback Successful: " + uri.href
      request.close()
    catch e
      @log "Callback Failed: " + uri.href
  log: (msg) ->
    sys.log('['+@id+']\t' + msg)

class DeliveryAttempt
  constructor: (delivery) ->
    TOTAL_DELIVERY_ATTEMPTS++
    @delivery: delivery
    @method: delivery.request.method
    @headers: delivery.request.headers
    @body: delivery.request.body
    @endpoint: delivery.endpoint
    @cleanHeaders()
  deliver: (callback) ->
    if ACTIVE_CONNECTIONS >= MAX_CONNECTIONS
      @delivery.log('Waiting for a spare connection')
      setTimeout((=> @deliver(callback)), 100)
      return
    ACTIVE_CONNECTIONS++
    try
      client: http.createClient(@endpoint.port || 80, @endpoint.hostname)
      request: client.request @method, url.fullPath(@endpoint), @headers
      request.write(@body)
      request.addListener 'response', (res) -> 
        callback res.statusCode < 400
        res.addListener 'end', -> ACTIVE_CONNECTIONS--
      request.close()
    catch e
      ACTIVE_CONNECTIONS--
      callback(false)
  cleanHeaders: ->
    @headers['x-deliverable-endpoint']: null
    @headers['x-deliverable-errback']: null
    @headers['x-deliverable-callback']: null

deliveryRequest: (request, response) ->
  request.headers['x-deliverable-endpoint'].split('; ').forEach( (endpoint) -> new Delivery(endpoint, request) )
  response.writeHeader 200, {'Content-Type': 'text/plain'}
  response.write 'ACCEPTED'
  response.close()

statsRequest: (request, response) ->
  response.writeHeader 200, {'Content-Type': 'text/plain'}
  response.write JSON.stringify {
    MAX_ATTEMPTS: MAX_ATTEMPTS
    RETRY_DELAY: RETRY_DELAY
    TOTAL_DELIVERIES: TOTAL_DELIVERIES
    ACTIVE_DELIVERIES: ACTIVE_DELIVERIES
    SUCCESSFUL_DELIVERIES: SUCCESSFUL_DELIVERIES
    FAILED_DELIVERIES: FAILED_DELIVERIES
    TOTAL_DELIVERY_ATTEMPTS: TOTAL_DELIVERY_ATTEMPTS
  } 
  response.close()


server: http.createServer (request, response) ->
  request.body = ''
  request.addListener 'data', (data) -> request.body += data
  request.addListener 'end', (data) ->
    if request.url.search(/^\/deliver/) >= 0
      deliveryRequest(request, response) 
    else 
      statsRequest(request, response)

exports.start: ->
  server.listen SERVER_PORT
  
exports.stop: ->
  server.close()
