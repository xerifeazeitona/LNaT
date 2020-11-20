## Proxy Servers :: Definition
A Proxy Server is a host that acts as a *proxy* on the behalf of client requests. For example, when you make a web request through a proxy, the proxy is actually making the web request on your behalf and returning you the result.
You could use a proxy to circumvent monitoring, blocking and censorship and you do this by leveraging a proxy in a location less subject to those restrictions.
Alternatively, you can use a proxy to impose monitoring, blocking and censorship against users of your network. For example, prohibiting corporate access to sites like facebook and youtube.
You can also use proxies to improve web performance by using caching. For example, if you have a corporate network that access some particular sites very frequently, you could leverage proxy caching so it doesn't have to get everything from the web for each access.

## Proxy Servers :: Simple example
A client computer with a tcp connection into a proxy host, which then manages the web requests for that client. Typically the client must be configured to use the proxy server, but you could also configure the gateway itself to use the proxy for a transparent implementation.

## Proxy Servers :: Squid
The most popular Linux proxy is squid. As defined in squid's website:
"Squid is a **caching proxy** for the Web supporting HTTP, HTTPS, FTP and more. It reduces bandwidth and improves response times by caching and reusing frequently-requested web pages. Squid has extensive **access controls** and makes a great server accelerator."