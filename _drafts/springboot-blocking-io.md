---
layout: post
title:  "Boosting Spring Boot Performance: Tomcat vs. WebFlux/Netty for Blocking I/O"
categories: [spring-boot]
tags: spring-boot kotlin webflux tomcat
---

![img.png](/assets/springboot-blocking-io/img.png)

This article focuses on optimizing Spring Boot backend performance when working with blocking I/O operations, such as fetching data from external services. We compare two popular setups: Tomcat (with traditional blocking architecture) and WebFlux/Netty (non-blocking) using Kotlin. You’ll gain insights into how to handle blocking operations in each setup and the key configurations to improve performance.

# What Metrics Matter?

In user-facing backend performance, two key metrics determine how responsive and scalable your system are:

* **Average Latency**: The delay between a request and its response, typically measured in milliseconds (ms). Lower latency means faster response times, which directly improves the user experience by reducing wait times.
* **Requests per Second (RPS)**: The number of requests your system can process in one second. A higher RPS reflects your system’s ability to manage more concurrent users efficiently without degrading performance.

To measure both latency and RPS, we can use the HTTP benchmarking tool [wrk][wrk]. The following command simulates a workload with:

```shell
wrk -t12 -c400 -d30s http://localhost:8080/endpoint
```

This will run a performance test using:
* _12_ threads (`-t12`)
* _400_ concurrent connections (`-c400`)
* a _30-second_ duration (`-d30s`)

When the test completes, wrk will report several metrics, including the latency and RPS that we are interested in. Below is an example output:

```
Running 30s test @ http://localhost:8080/blockingIO
  12 threads and 400 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.01s    88.79ms   1.50s    93.60%
    Req/Sec    41.54     33.18   190.00     78.44%
  Latency Distribution
     50%    1.00s 
     75%    1.01s 
     90%    1.02s 
     99%    1.46s 
  11636 requests in 30.08s, 1.38MB read
  Socket errors: connect 0, read 399, write 0, timeout 0
Requests/sec:    386.86
Transfer/sec:     46.85KB
```

# Service Setup

We will compare two basic Spring Boot applications:
* One using _spring-boot-starter-web_ (Tomcat) 
* One using _spring-boot-starter-webflux_ (Netty by default)

Both applications are built into Docker images and run as containers to ensure a consistent test environment across different machines. To evaluate performance, we defined several REST endpoints to demonstrate how each stack handles blocking I/O differently.

## No-op endpoints

These endpoints measure the raw performance of each stack by returning a fixed result without performing any actual processing. Both stacks allow the use of:

* Regular functions
* Kotlin suspending functions

By comparing these, we gain insight into the out-of-the-box performance capabilities of each stack.

{% highlight kotlin %}
@GetMapping("/noop")
fun noop(): String {
    return "Noop"
}
{% endhighlight %}

{% highlight kotlin %}
@GetMapping("/suspendNoop")
suspend fun suspendNoop(): String {
    return "suspendNoop"
}
{% endhighlight %}

## Endpoints performing I/O

To simulate blocking I/O operations, we added a `Thread.sleep(500)` call, introducing a _500ms_ delay. This simulates the waiting time when interacting with external services or databases and also blocks the current thread.
For each stack, we followed the recommended patterns to handle blocking I/O efficiently:

### Tomcat

#### Blocking the controller

In Tomcat, we can directly block the controller thread to do perform I/O:

{% highlight kotlin %}
@GetMapping("/blockingIO")
fun blockingIO(): String {
    Thread.sleep(500)
    return "blockingIO"
}
{% endhighlight %}

#### Suspend + Dispatchers.IO

Within a suspending function, we must perform the blocking operations on `Dispatchers.IO`. This will ensure the blocking operation is performed on a Dispatcher (with underlying Threadpool) suited to blocking operations. The initial controller coroutine is suspended until the result is available:

{% highlight kotlin %}
@GetMapping("/suspendIO")
suspend fun supendIO(): String {
    return withContext(Dispatchers.IO) {
        Thread.sleep(500)
        "suspendIO"
    }
}
{% endhighlight %}

#### CompletableFuture

We can wrap the blocking operation in a _CompletableFuture_ and schedule it on a thread pool appropriate for handling such tasks. This approach allows us to offload the execution of the blocking task to a separate thread, avoiding the blocking of the main request thread.

In this scenario, we return the CompletableFuture from our controller, and Spring will take care of handling it. Once the future is resolved, Spring completes the HTTP response:

{% highlight kotlin %}
val ioExecutor = Executors.newCachedThreadPool()

@GetMapping("/completableFutureIO")
fun completableIO(): CompletableFuture<String> {
    return CompletableFuture.supplyAsync({
        Thread.sleep(500)
        "completableFutureIO"
    }, ioExecutor)
}
{% endhighlight %}

#### Deferred

In Kotlin, _Deferred_ is a non-blocking equivalent to Java’s CompletableFuture. We can use it to wrap a blocking operation inside a coroutine that runs on the Dispatchers.IO context, specifically optimized for blocking I/O operations. 

In this approach, we return the Deferred result from the controller, and Spring will automatically handle the Deferred, completing the HTTP response once the coroutine finishes:

{% highlight kotlin %}
@GetMapping("/deferredIO1")
suspend fun deferredIO1(): Deferred<String> =
    coroutineScope {
        async(Dispatchers.IO) {
            Thread.sleep(500)
            "deferredIO1"
        }
    }
{% endhighlight %}

### WebFlux/Netty

#### No-op endpoints

We utilize the same no-op endpoint in the WebFlux/Netty stack as in the Tomcat stack. This endpoint measures the WebFlux framework's raw performance by returning a fixed response without any processing overhead.

#### Be careful with blocking I/O!

When using the Netty framework, it’s crucial to be careful with blocking I/O operations, as demonstrated in the Tomcat blocking example above. Netty operates on a limited number of threads (typically one thread per CPU core) within an event loop architecture. Blocking calls on these threads will prevent the event loop from processing other incoming requests, resulting in significant performance degradation and increased latency.

We'll reuse the Tomcat blocking example to illustrate the impact of blocking I/O directly on the controller thread. Our measurements will demonstrate how such an approach leads to poor performance and increased latency in the Netty environment.

#### Mono + Schedulers.boundedElastic()

We can use the _Mono_ type in the Spring reactive stack to represent asynchronous computations. However, when performing blocking I/O operations, it’s crucial to use an appropriate scheduler to avoid blocking the event loop[^1]:

{% highlight kotlin %}
@GetMapping("/monoIO1")
fun monoIO1(): Mono<String> =
    Mono.fromCallable {
        Thread.sleep(500)
        "monoIO1"
    }.subscribeOn(Schedulers.boundedElastic())
{% endhighlight %}

# Measurements

## Tomcat

|                           | Requests per second | Average latency p99 (ms) |
|--------------------------:|---------------------|--------------------------|
|                      noop | 9200                | 100                      |
|            suspend + noop | 4800                | 190                      |
|                  blocking | 392                 | 1030                     |
|  suspend + Dispatchers.IO | 125                 | 3500                     |
|         CompletableFuture | 760                 | 599                      |
| Deferred + Dispatchers.IO | 125                 | 3500                     |

When comparing the no-op endpoints, we observe that Kotlin’s coroutine machinery introduces some overhead compared to using regular functions.

The results for blocking I/O are not surprising: Tomcat uses a pool of [200 threads by default][tomcat-threadpool-default]. Since each thread can be blocked for 500ms during a blocking operation, it can theoretically handle a maximum of 400 requests per second (RPS). Our measurements align with this theoretical maximum, confirming the expected performance under these conditions.

When we wrap the blocking I/O operation in a _CompletableFuture_ submitted to a _separate thread pool_, we allow the controller thread to be freed earlier to handle new connections. This adjustment significantly improves throughput, with measurements showing an increase of approximately _760 RPS_.

The performance results using suspend functions and the Deferred type in combination with Dispatchers.IO might initially seem surprising. However, upon checking the [documentation][dispatchers-io], we note that the number of threads used by tasks in this dispatcher defaults to the greater of 64 threads or the number of CPU cores available. This limit can constrain performance if the number of concurrent tasks exceeds this threshold.

To optimize performance further, we can create a custom dispatcher that utilizes an unbounded and caching thread pool when using `withContext(...)`. This allows for more flexibility and can improve performance when handling blocking I/O in high-throughput scenarios:

{% highlight kotlin %}
val ioDispatcher = Executors.newCachedThreadPool().asCoroutineDispatcher()

@GetMapping("/deferredIO2")
suspend fun deferredIO2(): Deferred<String> =
    coroutineScope {
        async(ioDispatcher) {
            Thread.sleep(500)
            "deferredIO2"
        }
    }
{% endhighlight %}

The custom dispatcher can also be used with the _suspend + Dispatchers.IO_ example. 

|                              | Requests per second | Average latency p99 (ms) |
|-----------------------------:|---------------------|--------------------------|
| Deferred + custom dispatcher | 764                 | 595                      |

This drastically improves the performance so it's comparable to the `CompletableFuture` example.

## WebFlux

|                | Requests per second | Average latency p99 (ms) |
|---------------:|---------------------|--------------------------|
|           noop | 15806.90            | 84.08                    |
| suspend + noop | 14316.92            | 85.86                    |
|   blocking I/O | 7.7                 | 29000                    |
|     mono + I/O | 19.60               | 20000                    |

When examining the results from the no-op endpoints, it is evident that the WebFlux stack can deliver higher performance compared to the Tomcat stack. This improved performance is largely due to WebFlux's non-blocking nature, which allows it to handle a larger number of concurrent requests while consuming less system resources.

The results for blocking I/O operations in WebFlux are particularly concerning. When we perform blocking calls, we violate the conventions of the reactive stack, leading to poor performance outcomes. These issues may not be easily identifiable through code review alone in a more complex system. Additionally these issues do not typically affect functionality, they can go undetected in standard (non-load) testing[^2].

The performance results for Mono may initially appear surprising. Drawing from our previous experience with the Coroutine dispatcher configuration, we checked the [documentation for the elastic scheduler][reactor-boundedelastic]. We found the following: _The maximum number of concurrent threads is bounded by a cap (by default ten times the number of available CPU cores_. In our case, with 1 CPU core, this results in a cap of 10 threads. This helps to better understand the numbers we are seeing:

![equation.png](/assets/springboot-blocking-io/equation.png)

Thus, to improve performance, we need to provide a bigger threadpool. We achieve that by using a customized scheduler:

{% highlight kotlin %}
val scheduler = Schedulers.fromExecutor(Executors.newCachedThreadPool())

@GetMapping("/monoIO2")
fun monoIO2(): Mono<String> =
  Mono.fromCallable {
    Thread.sleep(500)
    "monoIO2"
    }.subscribeOn(scheduler)
{% endhighlight %}

After implementing the custom scheduler, we can measure the new performance metrics to evaluate its effectiveness:

|                         | Requests per second | Average latency p99 (ms) |
|------------------------:|---------------------|--------------------------|
| Mono + custom scheduler | 772.27              | 529.25                   |

This implementation improves performance, making it slightly better than the Tomcat example using CompletableFuture. However, in a more realistic scenario, we wouldn’t rely on _Thread.sleep_ to simulate I/O. Instead, we would utilize an actual client and fetch some data from an external system. In such cases, there is significant potential for further improvement by switching to a non-blocking client rather than continuing with a blocking one. Exploring this transition is beyond the scope of this article but is an essential consideration for enhancing performance in real-world applications.

# Conclusion

In our performance comparison, WebFlux generally demonstrates better out-of-the-box performance than Tomcat. We also learned that when utilizing WebFlux or Kotlin coroutines, following the framework's conventions is crucial to avoid introducing potential performance limitations.

In our synthetic use case, WebFlux's performance did not surpass that of Tomcat (comparing the _Tomcat CompletableFuture_ with the _WebFlux Mono_ example). This outcome underscores the importance of context in performance evaluations. 

When performing performance optimizations, it is essential to follow a structured process: first, define the scenario that accurately reflects your use cases; next, conduct tests and retests to gather performance data; and finally, evaluate whether the observed changes are relevant to your application. By following these steps, you can make informed decisions about which performance-related optimizations are applicable to your specific needs.

# Notes

[^1]: See [How Do I Wrap a Synchronous, Blocking Call?][reactor-blocking]

[^2]: To assist in identifying these blocking calls, tools like [BlockHound][blockhound] can be invaluable. BlockHound can help detect blocking calls in a non-blocking environment,

[reactor-blocking]: https://projectreactor.io/docs/core/release/reference/#faq.wrap-blocking
[wrk]: https://github.com/wg/wrk

[tomcat-threadpool-default]: https://www.baeldung.com/java-web-thread-pool-config#bd-1-embedded-tomcat

[reactor-boundedelastic]: https://projectreactor.io/docs/core/release/api/reactor/core/scheduler/Schedulers.html#boundedElastic--

[dispatchers-io]: https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-dispatchers/-i-o.html

[blockhound]: https://github.com/reactor/BlockHound