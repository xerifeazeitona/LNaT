## Load Balancing :: Definition
A Load Balancer acts as a traffic director to distribute and manage traffic across the backend nodes
Redundancy and High Availability in application infrastructure
Permits horizontal scalability of the application infrastructure
Provides architectural flexibility (if something goes down or behaves badly, it's easy to take it down and bring up without affecting the architecture in a major way)

## Load Balancing :: Simple example
If we have several application nodes behind a load balancer, when a client wants to access the application, it connects to the load balancer which will evaluate the best application node to redirect the client, based on pre configured rules.

## Load Balancing :: Modes
Modes are algorithms that Load Balancers use to define which is the best host to point to.
- **Round Robin** - Requests are distributed sequentially
- **Least Connections** - New requests are sent to the backend nodes with the least current connections
- **Source / IP Hash** - The IP of the client is used to determine the backend destination

One thing to keep in mind with load balancing is, let's say you have a web app that isn't stateless and uses some manner of non shared session handling. Each request from the browser has the potential to land on a different backend node, and this can cause some pretty interesting troubleshooting scenarios. For example, if you had 2 backend nodes the app may only work half of the time.
One way to mitigate this is through *Session Persistence*.

- **Session Persistence** - Used for maintaining session integrity by sticking to the same back end node.

## Load Balancing :: Types
- **Hardware** - A hardware appliance with proprietary software
- **Software** - Software on commodity hardware

This section focuses on software based load balancers but the concepts apply to both types.

## Load Balancing :: Configuration
In order to be able to use load balancers, there are some configurations that need to take place, both on the front end and on the back end.

- **Front End**
	- **Protocol** - Mode of TCP connections (e.g. http)
	- **Mode** - Round robin, least connected, ip hash etc
	- **Listening Port** - The port the load balancer listens on

- **Back End**
	- **Server Pool** - The list of backend hosts that should receive traffic

## Load Balancing :: Services
- **NGINX**
	- Can function as a caching web server as well as load balancer
	- Limited statistics
	- Paid solution for more flexibility and metrics

- **HAProxy**
	- Robust metrics
	- Easy to integrate with third-party monitoring
	- Does not provide web server capability
