---
layout: post
title:  "Reuse the ObjectMapper!"
categories: java jackson
---
# Why you should reuse Jackson's ObjectMapper

As freelancers, we encounter a wide array of projects, each with its own unique characteristics and challenges.
Among the common issues we come across is the less-than-ideal utilization of Jackson's ObjectMapper, often resembling scenarios like this:

```java
public String toJson(SomeDto someObject){
    var mapper = new ObjectMapper();
    return mapper.writeValueAsString(someObject);
}
```

As you can see, every time we need to serialize an instance of SomeDto into a JSON string, we create a new instance of ObjectMapper.
The most extreme instance I've come across featuring this code was nestled within a Hibernate column mapper.

This practice is less than ideal.
Jackson's documentation is not really clear with recommendations here.
I found it being mention only in some source code samples, e.g. in [JavaDoc of the ObjectMapper](https://fasterxml.github.io/jackson-databind/javadoc/2.7/com/fasterxml/jackson/databind/ObjectMapper.html)

> `final ObjectMapper mapper = new ObjectMapper(); // can use static singleton, inject: just make sure to reuse!`

This why we created this writeup, which will allow us to refer to whenever we encounter this usage patterns.

tldr: If you care about serialization performance, reuse ObjectMapper instances.
They are threadsafe, if you do not change their configuration while using them.

## Why to reuse ObjectMapper instances
When arguing for reusing the ObjectMapper, we usually stated two main reasons:

- Creating the ObjectMapper itself is an expensive operation.
  Every instance requires a none trivial amount of internal state as seen in this screenshot taken from a debugger.
  <img src="/assets/reuse-object-mapper/object-mapper-memory.png" alt="object mapper inernal state" width="400"/>

- The ObjectMapper needs to examine every class (hierarchy) it wants to instantiate or that is a source for JSON.
  Therefor it employs reflection to find contructors, properties, methods and optional annotations.
  This information is then used to build a mapping strategy for serializing or deserializing.
  These two steps are none trivial and that is why the strategy is cached inside the mapper.
  Subsequent requests to de/serialize use the prepared strategy and are way cheaper.

Both of these are performance concerns.
If you use the ObjectMapper only sporadically, there's no need to be overly concerned.
However, there are a lot of cases where the ObjectMapper is used quite often (e.g. in HTTP services might call it 2 times for every HTTP request).
To actually validate our claims, we created a small benchmark.

## Benchmarks
The benchmarks are designed to give you a basic understanding of the performance (latency) disparities between reusing the ObjectMapper and generating a new instance for each call.
They employ a relatively modest payload and do not take full advantage of the extensive Jackson features available for customizing the serialization process.
In real-world situations, we anticipate the gap in performance to be even more pronounced.

We use the following payload, with corresponding classes in Java:
```json
{
  "some": "some",
  "dtoEnum": "B",
  "innerDto": {
    "num": 123,
    "strings": [ "1", "2" ]
  }
}
```

The following screenshot shows the results of the benchmark.
We can perform 68 serialization operations per microsecond when we create a new ObjectMapper instance every time.
In contrast we can perform 3137 serialization operations per microsecond if a prepared ObjectMapper is being used.
This is a difference by a factor of 40.
![img.png](/assets/reuse-object-mapper/benchmark.png)

In the previous chapter we also claimed that creating the ObjectMapper itself is expensive, and we created a benchmark to get some insight:
![img.png](/assets/reuse-object-mapper/benchmark_create_objectmapper.png)

We can see that creating the ObjectMapper is not particular expensive when compared with the numbers from the previous benchmark.
For this reason, costs of instantiation are not a strong argument for reusing the mapper.


Full benchmark results: [https://jmh.morethan.io/?gist=1d98e83fa1fcab88beaf40caa0ea35be](https://jmh.morethan.io/?gist=1d98e83fa1fcab88beaf40caa0ea35be)

Source code of the benchmark: [https://github.com/red-green-coding/object-mapper-tests](https://github.com/red-green-coding/object-mapper-tests)


## How to avoid creating new ObjectMapper instances

> Mapper instances are fully thread-safe provided that ALL configuration of the instance occurs before ANY read or write calls.

[JavaDoc](https://fasterxml.github.io/jackson-databind/javadoc/2.7/com/fasterxml/jackson/databind/ObjectMapper.html)

Meaning as long as we do not change its configuration, after we started to use it, we can share it between multiple threads.
In most cases we recommend to just use a static field like

```java
public static final ObjectMapper mapper = new ObjectMapper().registerModule(new ParameterNamesModule());
```

If you cannot for some reason be sure that the configuration will not change during runtime, the recommendation is to
> Construct and use ObjectReader for reading, ObjectWriter for writing. Both types are fully immutable ...

[JavaDoc](https://fasterxml.github.io/jackson-databind/javadoc/2.7/com/fasterxml/jackson/databind/ObjectMapper.html)

This is a bit less convenient, and we solely see reasons to use it.

## When to have multiple ObjectMapper instances?
When ObjectMappers share the same configuration, there's typically no need to employ separate instances.
However, there are scenarios where is makes sense to have multiple instances.
In many scenarios, JSON serves as the go-to format for external system communication.
These systems, though, might use JSON in slightly varying manners.
For instance, consider a peculiar legacy system that formats timestamps in an unconventional manner, while other systems adhere to a ISO-8601-compatible string format.
In such situations, opting for ObjectMappers with distinct configurations becomes entirely justifiable.

# Conclusion
The benchmarks show a huge difference in runtime cost between creating new instances and reusing existing ones.
As the ObjectMapper is threadsafe, we recommend to just assign it to a public static final variable and use it wherever you comminucate with same JSON dialect.

TODO: reference related posts