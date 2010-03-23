(function(){
  var ACTIVE_DELIVERIES, Delivery, DeliveryAttempt, FAILED_DELIVERIES, MAX_ATTEMPTS, RETRY_DELAY, SERVER_PORT, SUCCESSFUL_DELIVERIES, TOTAL_DELIVERIES, TOTAL_DELIVERY_ATTEMPTS, deliveryRequest, http, server, statsRequest, sys, url;
  sys = require('sys');
  http = require('http');
  url = require('url');
  MAX_ATTEMPTS = 5;
  RETRY_DELAY = 5 * 1000;
  SERVER_PORT = 5678;
  TOTAL_DELIVERIES = 0;
  ACTIVE_DELIVERIES = 0;
  SUCCESSFUL_DELIVERIES = 0;
  FAILED_DELIVERIES = 0;
  TOTAL_DELIVERY_ATTEMPTS = 0;
  url.fullPath = function fullPath(uri) {
    var path;
    path = '';
    uri.pathname ? path += uri.pathname : path += '/';
    if (uri.query && uri.query !== '') {
      path += '?' + uri.query;
    }
    return path;
  };
  Delivery = function Delivery(request) {
    TOTAL_DELIVERIES++;
    ACTIVE_DELIVERIES++;
    this.id = TOTAL_DELIVERIES;
    this.request = request;
    this.attemptCount = 0;
    this.successful = null;
    this.endpoint = null;
    this.callback = null;
    this.errback = null;
    if (request.headers['x-deliverable-endpoint']) {
      this.endpoint = url.parse(request.headers['x-deliverable-endpoint']);
    }
    if (request.headers['x-deliverable-callback']) {
      this.callback = url.parse(request.headers['x-deliverable-callback']);
    }
    if (request.headers['x-deliverable-errback']) {
      this.errback = url.parse(request.headers['x-deliverable-errback']);
    }
    this.log("Delivery Request Received: " + this.endpoint.href);
    this.deliver();
    return this;
  };
  Delivery.prototype.deliver = function deliver() {
    this.attemptCount++;
    this.log("Atempting Delivery (" + this.attemptCount + ")");
    return new DeliveryAttempt(this).deliver((function(__this) {
      var __func = function(delivered) {
        return this.attemptComplete(delivered);
      };
      return (function() {
        return __func.apply(__this, arguments);
      });
    })(this));
  };
  Delivery.prototype.attemptComplete = function attemptComplete(delivered) {
    this.log("Attempt Completed (" + this.attemptCount + ")");
    if (delivered) {
      return this.registerSuccess();
    }
    return this.attemptCount === MAX_ATTEMPTS ? this.registerFailure() : setTimeout(((function(__this) {
      var __func = function() {
        return this.deliver();
      };
      return (function() {
        return __func.apply(__this, arguments);
      });
    })(this)), (this.attemptCount * this.attemptCount) * RETRY_DELAY);
  };
  Delivery.prototype.registerSuccess = function registerSuccess() {
    this.successful = true;
    this.log("Delivery Successful (after " + this.attemptCount + " attempts)");
    SUCCESSFUL_DELIVERIES++;
    ACTIVE_DELIVERIES--;
    if (this.callback) {
      return this.makeCallbackRequest(this.callback);
    }
  };
  Delivery.prototype.registerFailure = function registerFailure() {
    this.successful = false;
    this.log("Delivery Failed Given Up (after " + this.attemptCount + " attempts)");
    FAILED_DELIVERIES++;
    ACTIVE_DELIVERIES--;
    if (this.errback) {
      return this.makeCallbackRequest(this.errback);
    }
  };
  Delivery.prototype.makeCallbackRequest = function makeCallbackRequest(uri) {
    var client, request;
    this.log("Running Callback: " + uri.href);
    try {
      client = http.createClient(uri.port || 80, uri.hostname);
      request = client.request('POST', url.fullPath(uri));
      request.addListener('response', ((function(__this) {
        var __func = function(res) {
          return this.log("Callback Successful: " + uri.href);
        };
        return (function() {
          return __func.apply(__this, arguments);
        });
      })(this)));
      return request.close();
    } catch (e) {
      return this.log("Callback Failed: " + uri.href);
    }
  };
  Delivery.prototype.log = function log(msg) {
    return sys.log('[' + this.id + ']\t' + msg);
  };
  DeliveryAttempt = function DeliveryAttempt(delivery) {
    TOTAL_DELIVERY_ATTEMPTS++;
    this.delivery = delivery;
    this.method = delivery.request.method;
    this.headers = delivery.request.headers;
    this.body = delivery.request.body;
    this.endpoint = delivery.endpoint;
    this.cleanHeaders();
    return this;
  };
  DeliveryAttempt.prototype.deliver = function deliver(callback) {
    var client, request;
    try {
      client = http.createClient(this.endpoint.port || 80, this.endpoint.hostname);
      request = client.request(this.method, url.fullPath(this.endpoint), this.headers);
      request.write(this.body);
      request.addListener('response', (function(res) {
        return callback(res.statusCode < 400);
      }));
      return request.close();
    } catch (e) {
      return callback(false);
    }
  };
  DeliveryAttempt.prototype.cleanHeaders = function cleanHeaders() {
    this.headers['x-deliverable-endpoint'] = null;
    this.headers['x-deliverable-errback'] = null;
    return this.headers['x-deliverable-callback'] = null;
  };
  deliveryRequest = function deliveryRequest(request, response) {
    new Delivery(request);
    response.writeHeader(200, {
      'Content-Type': 'text/plain'
    });
    response.write('ACCEPTED');
    return response.close();
  };
  statsRequest = function statsRequest(request, response) {
    response.writeHeader(200, {
      'Content-Type': 'text/plain'
    });
    response.write(JSON.stringify({
      MAX_ATTEMPTS: MAX_ATTEMPTS,
      RETRY_DELAY: RETRY_DELAY,
      TOTAL_DELIVERIES: TOTAL_DELIVERIES,
      ACTIVE_DELIVERIES: ACTIVE_DELIVERIES,
      SUCCESSFUL_DELIVERIES: SUCCESSFUL_DELIVERIES,
      FAILED_DELIVERIES: FAILED_DELIVERIES,
      TOTAL_DELIVERY_ATTEMPTS: TOTAL_DELIVERY_ATTEMPTS
    }));
    return response.close();
  };
  server = http.createServer(function(request, response) {
    request.body = '';
    request.addListener('data', function(data) {
      return request.body += data;
    });
    return request.addListener('end', function(data) {
      return request.url.search(/^\/deliver/) >= 0 ? deliveryRequest(request, response) : statsRequest(request, response);
    });
  });
  exports.start = function start() {
    return server.listen(SERVER_PORT);
  };
  exports.stop = function stop() {
    return server.close();
  };
})();
