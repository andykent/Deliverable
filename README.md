Deliverable
===========

Deliverable is a evented webhook delivery server. 
The server is designed to proxy HTTP requests to remote machines that maybe slow, unreliable or non-existent.

Note
----
things are currently pretty beta so I really wouldn't rely on this for production use unless you are prepared to get your hands dirty.

Usage 
-----
Deliverable is an evented server optimised for holding thousands of connections open, Deliverable works as an proxy to the outside world, all you need to do is set a single header informing Deliverable of the final destination for your request. Here's an example.

Original...

    POST http://site.com/hook HTTP/1.1\r\n
    Content-Length: 5\r\n
    hello\r\n

Deliverable...

    POST http://localhost:5678/deliver HTTP/1.1\r\n
    X-Deliverable-Endpoint: http://site.com/hook\r\n
    Content-Length: 5\r\n
    hello\r\n

The call responds to all HTTP methods and forwards the full request body. Calls to Deliverable will return with a 200 status code immediately to indicate that the delivery has been received but this does not indicate that the message has been received at it's final destination successfully. There are two additional headers that your application can set in order to get feedback on a requests progress...

    X-Deliverable-Callback: http://site.com/success-callback\r\n
    X-Deliverable-Errback: http://site.com/error-callback\r\n

Current Features
----------------
- HTTP based delivery interface
- Async operation with support of callback and errback urls
- delivery statistics
- decaying retries on delivery failures

Planned Features
----------------
- client libraries
- Callbacks should contain the response data
- support for multiple delivery endpoints for the same message in a single http request
