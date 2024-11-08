---
layout: post
title:  "Tomcat vs. WebFlux with CPU intensive calculations"
categories: [spring-boot]
tags: spring-boot kotlin webflux tomcat
---

![img.png](/assets/springboot-cpu/img.jpg)

This article focuses on optimizing Spring Boot backend performance for CPU-intensive operations, such as data processing and computational tasks. We compare two popular setups: Tomcat (the traditional stack) and WebFlux/Netty (the reactive, non-blocking stack), using Kotlin.

# Context

In [a previous article][part-1], we explored performance for blocking I/O operations in Spring Boot applications, comparing Tomcat and WebFlux stacks. Now, we shift our focus to CPU-intensive tasks. While blocking I/O primarily affects system responsiveness by tying up resources, CPU-heavy operations might require efficient task management and execution strategies to prevent bottlenecks and maintain high throughput under load. This part examines both Tomcat and WebFlux configurations for handling CPU-bound operations, analyzing how each stack manages these tasks and the performance implications of each approach.

# Service Setup

We will compare two Spring Boot applications that perform some CPU-intensive operations. Similar to our approach in [part 1][part-1], we will use one application based on the spring-boot-starter-web (Tomcat) and another using spring-boot-starter-webflux (Netty by default). Both applications will be packaged as Docker images and deployed in containers to ensure a consistent testing environment.

To evaluate the performance of CPU-heavy tasks, we will implement several endpoints to simulate a compute heavy scenario. These endpoints will demonstrate how each stack manages computational workloads, allowing us to analyze the impact on responsiveness and throughput.

Refer to [part 1][part-1] for details on the overall setup. It also covers the metrics we monitor and the methods used to collect them.

## Endpoints performing CPU heavy calculations

First we created a function to simulate a CPU heavy calculations. 

{% highlight kotlin %}
fun performCpuWork(): String {
    return calculatePrimes(200_000).sum().toString()
}

fun calculatePrimes(limit: Int): List<Int> {
    val primes = mutableListOf<Int>()
    for (i in 2..limit) {
        var isPrime = true
        for (j in 2..Math.sqrt(i.toDouble()).toInt()) {
            if (i % j == 0) {
                isPrime = false
                break
            }
        }
        if (isPrime) primes.add(i)
    }
    return primes
}
{% endhighlight %}

The function generates a list of all prime numbers up to a given limit. 
This function is CPU-heavy because:

1. It performs nested loops for each number, iterating over potential divisors up to the square root.
2. As the limit increases, the number of calculations grows significantly, making it computationally intensive due to the high volume of modulo operations, square root operations and conditional checks.

Returning the list of primes prevents Hotspot from optimizing away the computation.

### Tomcat

#### Using the controller thread

In our initial setup, we handle the CPU-intensive work directly on the controller thread. This approach serves as a baseline, allowing us to compare the performance impact of alternative setups.

{% highlight kotlin %}
@GetMapping("/cpu0")
fun cpuDirect0(): String {
    return performCpuWork()
}
{% endhighlight %}

#### Suspend

In this version, we perform the CPU-intensive work within the controller coroutine. This setup leverages Kotlin’s suspending functions and runs on the thread of the controller coroutine.

{% highlight kotlin %}
@GetMapping("/cpu1")
suspend fun cpuDirect(): String {
    return performCpuWork()
}
{% endhighlight %}

#### Suspend + Dispatchers.Default

Here, we offload the CPU-intensive calculation to `Dispatchers.Default`, which uses a thread pool optimized for CPU-bound tasks with a limited number of threads[^1].

{% highlight kotlin %}
@GetMapping("/cpu2")
suspend fun cpuDispatcher(): String {
    return withContext(Dispatchers.Default) { // size = number of processors
        performCpuWork()
    }
}
{% endhighlight %}

#### CompletableFuture

In this approach, we offload the CPU-intensive calculation to a fixed thread pool sized to match the number of available processors. We use CompletableFuture to handle the asynchronous processing, which frees up the controller thread.

{% highlight kotlin %}
val jobExecutor = 
    Executors.newFixedThreadPool(Runtime.getRuntime().availableProcessors())

@GetMapping("/cpu3")
fun cpuThreadpool(): CompletableFuture<String> =
    CompletableFuture.supplyAsync({
        performCpuWork()
    }, jobExecutor)
{% endhighlight %}

### WebFlux/Netty

#### Mono + Schedulers.parallel()

In this example on the reactive stack, we wrap the calculation in a `Mono` and run it on `Schedulers.parallel()`. This scheduler is backed by a fixed-size thread pool, optimized for parallel CPU-bound work, with a number of threads equal to the available CPU cores.

{% highlight kotlin %}
@GetMapping("/cpu3")
fun monoCpu(): Mono<String> {
    return Mono.fromCallable {
        performCpuWork()
    }.subscribeOn(Schedulers.parallel()) // size = number of processors
}
{% endhighlight %}

# Measurements

## Tomcat

|                                       | Requests per second | Latency p99 (s) |
|--------------------------------------:|---------------------|-----------------|
|                            controller | 43.68               | 19.17           |
|                               suspend | 49.53               | 12.51           |
|         suspend + Dispatchers.Default | 124.21              | 3.26            |
| CompletableFuture + fixed thread pool | 134.98              | 3.00            |

In the results, offloading the CPU-intensive computation to a specialized, fixed-size thread pool significantly improved both throughput and latency. This approach allows Tomcat to handle more requests per second with reduced latency, highlighting the benefits of managing CPU-bound tasks outside the main controller thread.

## WebFlux

|                               | Requests per second | Latency p99 (s) |
|------------------------------:|---------------------|-----------------|
|                    controller | 104.64              | 24.41           |
|                       suspend | 92.58               | 24.76           |
| suspend + Dispatchers.Default | 113.21              | 6.34            |
|  Mono + Schedulers.parallel() | 137.82              | 2.90            |

The results are similar in the WebFlux stack, but the difference between direct execution and offloaded computation is less pronounced than in the Tomcat stack. Offloading CPU-heavy computation still improves performance, but the gains from offloading are not as significant.

# Key takeaways

**Offloading CPU heavy computations improves performance!**: Despite being aware of this approach, we were still surprised by how much of a difference offloading CPU-bound tasks to specialized thread pools can make.

**Context matters**: This improvement was noticeable only with more intensive calculations (e.g., using a parameter value of _200,000_ for our prime number calculation). For lighter CPU work, the difference was negligible. Thus, this setup is irrelevant for low-complexity tasks.

**Do your own measurements!**: Whether it’s beneficial to use a thread pool for CPU-bound work depends heavily on the use case and the amount of computation involved. Always perform your own measurements to determine if it’s worth the effort.

For our primarily I/O-heavy services—such as those involving database reads, external system interactions, and light data transformations offloading CPU work does not provide significant benefits. Therefore, there is no need to introduce additional complexity for these types of workloads.

# Notes

[part-1]: {% post_url 2024-10-29-springboot-blocking-io %}
[dispatchers-default]: https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-dispatchers/-default.html
[schedulers-parallel]: https://projectreactor.io/docs/core/milestone/reference/coreFeatures/schedulers.html

[^1]: One thread per CPU core, with a minimum of 2 threads.