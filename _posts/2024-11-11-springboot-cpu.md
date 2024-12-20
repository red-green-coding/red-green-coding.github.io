---
layout: post
title:  "Tomcat vs. WebFlux for CPU-bound workloads"
categories: [spring-boot]
tags: spring-boot kotlin webflux tomcat
apexcharts: true
---

![img.png](/assets/springboot-cpu/img.jpg)

This article focuses on optimizing Spring Boot backend performance for CPU-intensive operations, such as data processing and computational tasks. We compare two popular setups: Tomcat (the traditional stack) and WebFlux/Netty (the reactive, non-blocking stack), using Kotlin.

# Context

In [a previous article][part-1], we explored performance for blocking I/O operations in Spring Boot applications, comparing Tomcat and WebFlux stacks. Now, we shift our focus to CPU-intensive tasks. While blocking I/O primarily affects system responsiveness by tying up resources, CPU-bound operations might require efficient task management and execution strategies to prevent bottlenecks and maintain high throughput under load. This part examines both Tomcat and WebFlux configurations for handling CPU-bound operations, analyzing how each stack manages these tasks and the performance implications of each approach.

# Service Setup

We will compare two Spring Boot applications that perform some CPU-intensive operations. Similar to our approach in [part 1][part-1], we will use one application based on the spring-boot-starter-web (Tomcat) and another using spring-boot-starter-webflux (Netty by default). Both applications will be packaged as Docker images and deployed in containers to ensure a consistent testing environment.

To evaluate the performance of CPU-heavy tasks, we will implement several endpoints to simulate a compute intensive scenario. These endpoints will demonstrate how each stack manages computational workloads, allowing us to analyze the impact on responsiveness and throughput.

Refer to [part 1][part-1] for details on the overall setup. It also covers the metrics we monitor and the methods used to collect them.

## REST Endpoints performing CPU-intensive calculations

First we created a function to simulate a CPU-bound calculations. 

{% highlight kotlin %}
fun performCpuWork(limit: Int): String {
    return calculatePrimes(limit).sum().toString()
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
This function is CPU-demanding because:

1. It performs nested loops for each number, iterating over potential divisors up to the square root.
2. As the limit increases, the number of calculations grows significantly, making it computationally intensive due to the high volume of modulo operations, square root operations and conditional checks.

Returning the list of primes prevents Hotspot from optimizing away the computation.

### Tomcat

#### Using the controller thread

In our initial setup, we handle the CPU-intensive work directly on the controller thread. This approach serves as a baseline, allowing us to compare the performance impact of alternative setups.

{% highlight kotlin %}
@GetMapping("/cpu0")
fun cpuDirect0(@RequestParam("limit") limit: Int): String {
    return performCpuWork(limit)
}
{% endhighlight %}

#### Suspend

In this version, we perform the CPU-intensive work within the controller coroutine. This setup uses Kotlin’s suspending functions and runs on the controller coroutine.

{% highlight kotlin %}
@GetMapping("/cpu1")
suspend fun cpuDirect(@RequestParam("limit") limit: Int): String {
    return performCpuWork(limit)
}
{% endhighlight %}

#### Suspend + Dispatchers.Default

Here, we offload the CPU-intensive calculation to `Dispatchers.Default`, which uses a thread pool optimized for CPU-bound tasks with a limited number of threads[^1].

{% highlight kotlin %}
@GetMapping("/cpu2")
suspend fun cpuDispatcher(@RequestParam("limit") limit: Int): String {
    return withContext(Dispatchers.Default) { // size = number of processors
        performCpuWork(limit)
    }
}
{% endhighlight %}

#### CompletableFuture

In this approach, we offload the CPU-intensive calculation to a fixed thread pool sized to match the number of available processors. We use `CompletableFuture` to handle the asynchronous processing, which frees up the controller thread.

{% highlight kotlin %}
val jobExecutor = 
    Executors.newFixedThreadPool(Runtime.getRuntime().availableProcessors())

@GetMapping("/cpu3")
fun cpuThreadpool(@RequestParam("limit") limit: Int): CompletableFuture<String> =
    CompletableFuture.supplyAsync({
        performCpuWork(limit)
    }, jobExecutor)
{% endhighlight %}

### WebFlux/Netty

We will re-use the examples from the tomcat stack above: 
* Regular function + do work on the controller thread
* suspend function + do work on the controller thread
* suspend function + Dispatchers.Default

#### Mono

In addition to the previous examples, we use a approach specific to the reactive stack. In this example, we wrap the CPU-bound calculation inside a `Mono` without any additional precautions:

{% highlight kotlin %}
@GetMapping("/cpu3")
fun monoCpu(@RequestParam("limit") limit: Int): Mono<String> {
    return Mono.fromCallable {
        performCpuWork(limit)
    }
}
{% endhighlight %}

This approach uses the reactive Mono to handle the CPU work asynchronously, but without offloading to a dedicated Scheduler. 

#### Mono + Schedulers.parallel()

To optimize the CPU-bound task, we run the Mono on `Schedulers.parallel()`. This scheduler is backed by a fixed-size thread pool, optimized for parallel CPU-bound work, with a number of threads equal to the available CPU cores:

{% highlight kotlin %}
@GetMapping("/cpu4")
fun monoCpu(@RequestParam("limit") limit: Int): Mono<String> {
    return Mono.fromCallable {
        performCpuWork(limit)
    }.subscribeOn(Schedulers.parallel()) // size = number of processors
}
{% endhighlight %}

# Measurements

Each endpoint was tested for RPS and p99 latency using wrk with the following parameters:

```shell
wrk --latency -t12 -c400 -d30s --timeout 30s 'http://localhost:8080/$endpoint?limit=$limit'
```
The limit parameter (number of prime calculations) was set to _1000, 10,000, 50,000, 100,000, 200,000, and 300,000_ to simulate varying CPU loads. Other parameters configured wrk to use _12 threads_, _400 connections_, and a _30-second runtime_ for each test. For more information on the tool wrk, refer to [part 1][part-1].

## Tomcat

```apexchart
{
    series: [{
                name: "Regular",
                data: [13409.62, 12037.07, 2479.87, 430, 149.59, 59.92, 31.30]
            },
            {
                name: "Suspend",
                data: [8600.64, 7127.31, 2160.12, 406.73, 155.87, 54.44, 32.18]
            },
            {
                name: "Dispatchers.Default",
                data: [8006.54, 6707.28, 2817.29, 723.68, 314.04, 127.87, 75.18]
            },
            {
                name: "CompletableFuture",
                data: [8542.10, 7183.47, 3022.05, 782.12, 330.39, 140.13, 81.66]
            }
            ],
    chart: {
        height: 350,
        type: 'line',
        zoom: {
            enabled: false,
            type: "x"
        }
    },
    dataLabels: {
        enabled: false
    },
    stroke: {
        curve: 'straight'
    },
    title: {
        text: 'Requests per second',
        align: 'left'
    },
    grid: {
        row: {
            colors: ['#f3f3f3', 'transparent'],
            opacity: 0.5
        },
    },
    xaxis: {
        type: "numeric",
        categories: [100, 1000, 10000, 50000, 100000, 200000, 300000],
        min: 0,
        title: {
            text: "number of primes"
        }
    },
    yaxis: {
        logarithmic: true,
        min: 0,
        title: {
            text: "rps"
        }
    }
}
```

> ⬆ Note: The y-axis uses a logarithmic scale to highlight differences on the right side of the chart.

With lower CPU work (fewer prime number calculations), using a separate worker thread actually performs worse than direct execution, as the cost of switching threads outweighs any gains. However, as CPU work increases, offloading doubles the RPS for both the `CompletableFuture` and `Dispatchers.Default` versions.

```apexchart
{
    series: [{
                name: "Regular",
                data: [85.51, 86.67, 298.28, 4 * 1000, 5.9 * 1000, 9.3 * 1000, 15 * 1000]
            },
            {
                name: "Suspend",
                data: [97.06, 100.44, 305, 2 * 1000, 3.8 * 1000, 10.9 * 1000, 13.4 * 1000]
            },
            {
                name: "Dispatchers.Default",
                data: [101.84, 103.23, 194.09, 589.05, 1.30 * 1000, 3.19 * 1000, 5.28 * 1000]
            },
            {
                name: "CompletableFuture",
                data: [104.37, 103.96, 177.08, 531.59, 1.21 * 1000, 2.86 * 1000, 4.93 * 1000]
            }
            ],
    chart: {
        height: 350,
        type: 'line',
        zoom: {
            enabled: false,
            type: "x"
        }
    },
    dataLabels: {
        enabled: false
    },
    stroke: {
        curve: 'straight'
    },
    title: {
        text: 'Latency p99 (ms)',
        align: 'left'
    },
    grid: {
        row: {
            colors: ['#f3f3f3', 'transparent'],
            opacity: 0.5
        },
    },
    xaxis: {
        type: "numeric",
        categories: [100, 1000, 10000, 50000, 100000, 200000, 300000],
        min: 0,
        title: {
            text: "number of primes"
        }
    },
    yaxis: {
        logarithmic: false,
        min: 0,
        title: {
            text: "latency p99 ms"
        }
    }
}
```

Examining p99 latency shows that as CPU work increases, latency also rises. However, with a separate thread pool, latency grows at a much slower rate compared to direct execution.

Interpretation:
Offloading CPU work only helps with high CPU loads. When CPU work is light, switching threads adds extra cost, canceling out any potential benefits.

## WebFlux

```apexchart
{
    series: [{
                name: "Regular",
                data: [ 17354.40, 15766.58, 4582.06, 696.24, 275.95, 105.23, 56.09]
            },
            {
                name: "Suspend",
                data: [
12443.80,
13750.43,
4382.51,
686.80,
275.94,
105.95,
57.46]
            },
            {
                name: "Dispatchers.Default",
                data: [11201.15,
13375.77,
3904.49,
768.86,
319.27,
128.67,
74.05]
            },
            {
                name: "Mono",
                data: [17188.41,
16533.75,
4478.27,
672.16,
263.97,
101.86,
54.87]
            }, {
                name: "Mono + Schedulers.parallel()",
                data: [16322.02,
15261.63,
3915.53,
799.84,
335.47,
136.56,
78.19]
            }
            ],
    chart: {
        height: 350,
        type: 'line',
        zoom: {
            enabled: false,
            type: "x"
        }
    },
    dataLabels: {
        enabled: false
    },
    stroke: {
        curve: 'straight'
    },
    title: {
        text: 'Requests per second',
        align: 'left'
    },
    grid: {
        row: {
            colors: ['#f3f3f3', 'transparent'],
            opacity: 0.5
        },
    },
    xaxis: {
        type: "numeric",
        categories: [100, 1000, 10000, 50000, 100000, 200000, 300000],
        min: 0,
        title: {
            text: "number of primes"
        }
    },
    yaxis: {
        logarithmic: true,
        min: 0,
        title: {
            text: "rps"
        }
    }
}
```

> ⬆ Note: The y-axis uses a logarithmic scale to highlight differences on the right side of the chart.

The results are similar in the WebFlux stack, but the difference between direct execution and offloaded computation is less pronounced than in the Tomcat stack. Offloading CPU-heavy computation still improves performance, but the RPS gains from offloading don't seem as significant.

```apexchart
{
    series: [{
                name: "Regular",
                data: [
84.28,
86.06,
205.51,
4.61 * 1000,
14.74 * 1000,
23.60 * 1000,
26.72 * 1000]
            },
            {
                name: "Suspend",
                data: [86.60,
90.19,
198.12,
4.70*1000,
14.24*1000,
24.96*1000,
26.59*1000]
            },
            {
                name: "Dispatchers.Default",
                data: [
84.44,
88.22,
173.49,
603.37,
1.30*1000,
3.11*1000,
5.39*1000]
            },
            {
                name: "Mono",
                data: [85.31,
83.98,
195.28,
4.65 * 1000,
14.98 * 1000,
24.61 * 1000,
28.41 * 1000]
            } , {
                name: "Mono + Schedulers.parallel()",
                data: [82.36,
82.80,
149.07,
554.07,
1.26*1000,
2.97*1000,
5.11*1000]
            }
            ],
    chart: {
        height: 350,
        type: 'line',
        zoom: {
            enabled: false,
            type: "x"
        }
    },
    dataLabels: {
        enabled: false
    },
    stroke: {
        curve: 'straight'
    },
    title: {
        text: 'Latency p99 (ms)',
        align: 'left'
    },
    grid: {
        row: {
            colors: ['#f3f3f3', 'transparent'],
            opacity: 0.5
        },
    },
    xaxis: {
        type: "numeric",
        categories: [100, 1000, 10000, 50000, 100000, 200000, 300000],
        min: 0,
        title: {
            text: "number of primes"
        }
    },
    yaxis: {
        logarithmic: false,
        min: 0,
        title: {
            text: "latency p99 ms"
        }
    }
}
```

However, the impact is more noticeable when we look at latency. The latency values for direct executions are worse than those observed in the Tomcat stack. We interpret this as the combined cost of frequent context switches and the added latency from performing work on the event loop of the reactive stack[^2]. 

# Improvements

Finally, we explore two approaches to further improve performance. One involves using cooperative concurrency for CPU-bound logic, while the other focuses on limiting concurrency without the need for a thread pool.

## Be cooperative!

When multiple CPU-intensive calculations run concurrently on different coroutines within `Schedulers.Default`, latencies can increase as each calculation holds the CPU for an extended period.

Improving coroutine performance in such CPU-bound tasks is possible by structuring the logic to be [cooperative][cooperative], allowing CPU time to be distributed more evenly between the active calculations.

{% highlight kotlin %}
suspend fun performCpuWorkCoop(limit: Int, batchSize: Int): String {
    return calculatePrimesCoop(limit, batch).size.toString()
}

suspend fun calculatePrimesCoop(limit: Int, batchSize: Int): List<Int> {
    val primes = mutableListOf<Int>()
    for (i in 2..limit) {
        if (i % batchSize == 0) yield()

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

We modified the code to call [yield()][yield] every `batchSize` elements, allowing control to return to the coroutine scheduler and enabling other coroutines to run concurrently. 

This change should help reduce p99 latency by processing tasks across multiple coroutines more evenly. Next, we’ll measure the effects of varying `batchSize` values on performance.

```apexchart
{
    series: [
            {
                name: "Suspend (baseline)",
                data: [7127.31, 2160.12, 155.87, 32.18]
            },
            {
                name: "Coop batch size=100",
                data: [6413.60,
2591.96,
248.90,
58.24]
            },
            {
                name: "Coop batch size=1000",
                data: [
6581.95,
2818.70,
287.69,
62.19]
            },
 {
                name: "Coop batch size=10000",
                data: [
6332.20,
2780.21,
294.50,
65.29
]
            },
{
                name: "Coop batch size=100000",
                data: [
6592.01,
2845.57,
315.98,
74.91
]
            }
            ],
    chart: {
        height: 350,
        type: 'line',
        zoom: {
            enabled: false,
            type: "x"
        }
    },
    dataLabels: {
        enabled: false
    },
    stroke: {
        curve: 'straight'
    },
    title: {
        text: 'Requests per second',
        align: 'left'
    },
    grid: {
        row: {
            colors: ['#f3f3f3', 'transparent'],
            opacity: 0.5
        },
    },
    xaxis: {
        type: "numeric",
        categories: [1000, 10000, 100000, 300000],
        min: 0,
        title: {
            text: "number of primes"
        }
    },
    yaxis: {
        logarithmic: true,
        min: 0,
        title: {
            text: "rps"
        }
    }
}
```

The change positively impacts RPS, showing improvements over the plain suspend baseline. Larger batch sizes are advantageous, likely due to the overhead introduced by frequent `yield()` calls.

```apexchart
{
    series: [
            {
                name: "Suspend (baseline)",
                data: [
90.19,
198.12,
14.24*1000,
26.59*1000]
            },
            {
                name: "Coop batch size=100",
                data: [
110.81,
208.83,
2.29*1000,
8.91*1000
]
            },
            {
                name: "Coop batch size=1000",
                data: [
107.39,
209.68,
1.98*1000,
8.42*1000]
            },

{
                name: "Coop batch size=10000",
                data: [
143.14,
198.55,
1.88*1000,
7.98*1000]
            },
{
                name: "Coop batch size=100000",
                data: [
131.61,
197.66,
1.38*1000,
5.98*1000
]
            }

            ],
    chart: {
        height: 350,
        type: 'line',
        zoom: {
            enabled: false,
            type: "x"
        }
    },
    dataLabels: {
        enabled: false
    },
    stroke: {
        curve: 'straight'
    },
    title: {
        text: 'Latency p99 (ms)',
        align: 'left'
    },
    grid: {
        row: {
            colors: ['#f3f3f3', 'transparent'],
            opacity: 0.5
        },
    },
    xaxis: {
        type: "numeric",
        categories: [1000, 10000, 100000, 300000],
        min: 0,
        title: {
            text: "number of primes"
        }
    },
    yaxis: {
        logarithmic: false,
        min: 0,
        title: {
            text: "latency p99 ms"
        }
    }
}
```

A similar trend appears in p99 latency values, where the cooperative change consistently reduces latency. Larger batch sizes once again seem beneficial.

Overall, this approach proves highly effective. However, a potential drawback is that the computation logic must be coroutine-aware by using the `suspend` keyword and using the library function `yield()`, which may not always be desirable or possible.

## Limiting concurrency

An alternative approach to improve performance is to limit concurrency in our CPU-intensive code:

{% highlight kotlin %}
val semaphore = Semaphore(Runtime.getRuntime().availableProcessors())

fun performCpuWork(limit: Int): String {
    semaphore.acquire()

    try {
        return calculatePrimes(limit).size.toString()
    } finally {
        semaphore.release()
    }
}
{% endhighlight %}

By restricting the number of active concurrent calculations with a Semaphore, we control how many tasks can access the CPU-bound code simultaneously, reducing context switching and potentially improving performance[^3].

Here, the Semaphore argument is set to match the number of CPU cores. This ensures only as many tasks as there are CPU cores can run concurrently.

```apexchart
{
    series: [{
                name: "Regular (baseline)",
                data: [13409.62, 12037.07, 2479.87, 430, 149.59, 59.92, 31.30]
            },
            {
                name: "Regular + Semapore",
                data: [13934.53,
11236.27,
3237.73,
760.23,
331.47,
135.89,
80.35]
            }
            ],
    chart: {
        height: 350,
        type: 'line',
        zoom: {
            enabled: false,
            type: "x"
        }
    },
    dataLabels: {
        enabled: false
    },
    stroke: {
        curve: 'straight'
    },
    title: {
        text: 'Requests per second',
        align: 'left'
    },
    grid: {
        row: {
            colors: ['#f3f3f3', 'transparent'],
            opacity: 0.5
        },
    },
    xaxis: {
        type: "numeric",
        categories: [100, 1000, 10000, 50000, 100000, 200000, 300000],
        min: 0,
        title: {
            text: "number of primes"
        }
    },
    yaxis: {
        logarithmic: true,
        min: 0,
        title: {
            text: "rps"
        }
    }
}
```

As expected, we observe a positive impact on RPS.

```apexchart
{
    series: [{
                name: "Regular (baseline)",
                data: [85.51, 86.67, 298.28, 4 * 1000, 5.9 * 1000, 9.3 * 1000, 15 * 1000]
            },
            {
                name: "Regular + Semaphore",
                data: [91.66,
171.36,
236.14,
723.05,
1.26 * 1000,
2.94 * 1000,
5.09 * 1000]
            },
            ],
    chart: {
        height: 350,
        type: 'line',
        zoom: {
            enabled: false,
            type: "x"
        }
    },
    dataLabels: {
        enabled: false
    },
    stroke: {
        curve: 'straight'
    },
    title: {
        text: 'Latency p99 (ms)',
        align: 'left'
    },
    grid: {
        row: {
            colors: ['#f3f3f3', 'transparent'],
            opacity: 0.5
        },
    },
    xaxis: {
        type: "numeric",
        categories: [100, 1000, 10000, 50000, 100000, 200000, 300000],
        min: 0,
        title: {
            text: "number of primes"
        }
    },
    yaxis: {
        logarithmic: false,
        min: 0,
        title: {
            text: "latency p99 ms"
        }
    }
}
```

We also see improvements in latency. In general, performance gains here come from lowering concurrency in the CPU-intensive part. This can be done with a dedicated thread pool or, as in this example, by using a semaphore to limit simultaneous tasks.

A semaphore provides fine-grained control over concurrency with a lower abstraction level, which is simple to use but requires careful handling to avoid issues like deadlocks. A fixed thread pool, on the other hand, abstracts task management and handles scheduling automatically, making it easier for scaling parallel workloads. While a semaphore is straightforward for controlling a single resource, a shared thread pool can simplify managing multiple concurrent tasks.

# Key takeaways

**Limit concurrency for CPU-bound code**: Reducing concurrency in CPU-intensive code can improve performance by minimizing context switching.

**Use CPU Worker Pool**: A common approach to limiting concurrency is offloading compute-intensive tasks to a dedicated worker pool with a fixed number of threads, typically matching the available CPU cores.

**Limit Concurrency with Semaphores**: A semaphore offers another way to control concurrency in CPU-bound tasks by setting a maximum limit on concurrent executions, helping to reduce context switching and balance CPU load without requiring a separate worker pool.

**Optional on Tomcat, Mandatory on WebFlux**: Offloading CPU work can be an optional improvement in a Tomcat stack. However, in a WebFlux (reactive) stack, it’s essential to avoid blocking or long calculations, as they can more severely impact performance. Be mindful of the specific requirements and limitations of your stack to make informed design decisions.

**Task size matters**: The need for optimization became apparent only with larger workloads (e.g., with a parameter of _50,000+_ for our prime number calculation). For lighter CPU loads, the added complexity provided little benefit or even introduced overhead, making such optimizations unnecessary for low-intensity tasks.

**Cooperative processing**: Modifying CPU-bound tasks to be cooperative, by adding `yield()` calls, can significantly enhance both RPS and latency for coroutine-based implementations. This adjustment, while effective, requires restructuring the logic as a `suspend` function, which may not always be practical. 

**Do your own measurements**: The performance impact of concurrency strategies, such as offloading, limiting concurrency, and cooperative processing, varies widely based on the specific workload and CPU demands. Always measure and evaluate these approaches in the context of your unique requirements to ensure the best results.

# Notes

[part-1]: {% post_url 2024-10-29-springboot-blocking-io %}
[dispatchers-default]: https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-dispatchers/-default.html
[schedulers-parallel]: https://projectreactor.io/docs/core/milestone/reference/coreFeatures/schedulers.html
[yield]: https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/yield.html
[cooperative]: https://en.wikipedia.org/wiki/Cooperative_multitasking
[kotlin-semaphore]: https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines.sync/-semaphore/
[kotlin-semaphore-withpermit]: https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines.sync/with-permit.html

[^1]: One thread per CPU core, with a minimum of 2 threads.
[^2]: A key takeaway/reminder here: Avoid performing I/O or long calculations on the event loop!
[^3]: We chose to use a Java Semaphore here. Kotlin also has its own [semaphore][kotlin-semaphore], which is more idiomatic to Kotlin code and includes the [withPermit][kotlin-semaphore-withpermit] function, but it can only be used within suspend functions.
