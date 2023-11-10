---
layout: post
title:  "Please reuse Jackson's ObjectMapper"
categories: java jackson
---
# Why you should reuse Jackson's ObjectMapper

As freelancers, we encounter a wide array of projects, each with its unique characteristics and challenges.
Among the common issues we come across is the less-than-ideal utilization of [Jackson](https://github.com/FasterXML/jackson)'s ObjectMapper, often resembling scenarios like this:

```java
public String toJson(SomeDto someObject){
    var mapper = new ObjectMapper();
    return mapper.writeValueAsString(someObject);
}
```

As you can see, every time we need to serialize an instance of SomeDto into a JSON string, we create a new instance of ObjectMapper.
The most extreme example where we found this pattern was inside a Hibernate column mapper.

This practice is less than ideal. Jackson's documentation is not clear with recommendations here.
We found it is mentioned only in some source code samples, e.g., in [JavaDoc of the ObjectMapper](https://fasterxml.github.io/jackson-databind/javadoc/2.7/com/fasterxml/jackson/databind/ObjectMapper.html)

> `final ObjectMapper mapper = new ObjectMapper(); // can use static singleton, inject: just make sure to reuse!`

That is why we created this writeup, allowing us to refer to it whenever we encounter these usage patterns.

TLDR: If you care about serialization performance, reuse ObjectMapper instances.
If you do not change their configuration while using them, they are threadsafe.

## Why to reuse ObjectMapper instances
When arguing for reusing the ObjectMapper, we usually stated two main reasons:

- Creating the ObjectMapper itself is an expensive operation.
  Every instance requires a non-trivial amount of internal state, as seen in this screenshot taken from a debugger.
  <img src="/assets/reuse-object-mapper/object-mapper-memory.png" alt="object mapper inernal state" width="400"/>

- The ObjectMapper needs to examine every class (hierarchy) it wants to instantiate, or that is a source for JSON.
  Therefore, it employs reflection to find contructors, properties, methods, and optional annotations.
  This information is required to build a mapping strategy for serializing or deserializing.
  These two steps are non-trivial, so the strategy gets cached inside the mapper.
  Subsequent requests to de/serialize use the prepared strategy and are way cheaper.

Both of these are performance concerns.
If you use the ObjectMapper only sporadically, there's no need to be overly concerned.
However, there are a lot of cases where the ObjectMapper is used quite often (e.g., in HTTP services, we might call it two times for every HTTP request).
To validate our claims, we created a small benchmark.

## Benchmarks
The benchmarks are meant to provide a basic understanding of the performance (latency) disparities between reusing the ObjectMapper and generating a new instance for each call.
They employ a relatively modest payload and do not take full advantage of the extensive Jackson features available for customizing the serialization process.
We anticipate the performance gap to be even more pronounced in real-world situations.

We use the following payload with corresponding classes in Java:
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
We can perform 72 serialization operations per microsecond when we create a new ObjectMapper instance every time.
In contrast, we can perform 2,574 serialization operations per microsecond using a shared ObjectMapper.
This is a difference by a factor of 35.
If we look at deserialization, the difference is even more significant with a factor of more than 60.
![img.png](/assets/reuse-object-mapper/benchmark.png)

In the previous section, we also claimed that creating the ObjectMapper itself is expensive, and we created a benchmark to get some insight:
![img.png](/assets/reuse-object-mapper/benchmark_create_objectmapper.png)

Creating the ObjectMapper is not particularly expensive compared to the previous benchmark numbers.
For this reason, instantiation costs are not a strong argument for reusing the mapper.
Keep in mind that it will still increase the work for the garbage collector.


Full benchmark results: [https://jmh.morethan.io/?gist=1d98e83fa1fcab88beaf40caa0ea35be](https://jmh.morethan.io/?gist=1d98e83fa1fcab88beaf40caa0ea35be)

Source code of the benchmark: [https://github.com/red-green-coding/object-mapper-tests](https://github.com/red-green-coding/object-mapper-tests)


## How to avoid creating new ObjectMapper instances

> Mapper instances are fully threadsafe provided that ALL configuration of the instance occurs before ANY read or write calls.

[JavaDoc](https://fasterxml.github.io/jackson-databind/javadoc/2.7/com/fasterxml/jackson/databind/ObjectMapper.html)

This means that as long as we do not change its configuration after we start to use it, we can share it between multiple threads.
In most cases, we recommend just using a static field like

```java
public static final ObjectMapper mapper = new ObjectMapper().registerModule(new ParameterNamesModule());
```

If you cannot, for some reason, be sure that the configuration will not change during runtime, the recommendation is to
> Construct and use ObjectReader for reading, ObjectWriter for writing. Both types are fully immutable ...

[JavaDoc](https://fasterxml.github.io/jackson-databind/javadoc/2.7/com/fasterxml/jackson/databind/ObjectMapper.html)

This is less convenient, and we solely see reasons to use it.

## When to have multiple ObjectMapper instances?
When ObjectMappers share the same configuration, there's typically no need to employ separate instances.
However, there are scenarios where it makes sense to have multiple instances.
JSON is the go-to format for external system communication in many scenarios.
These systems, though, might use JSON in slightly varying manners.
For instance, consider a peculiar legacy system that unconventionally formats timestamps while other systems adhere to an ISO-8601-compatible string format.
In such situations, opting for ObjectMappers with distinct configurations becomes entirely justifiable.

# Conclusion
The benchmarks show a considerable difference in runtime cost between creating and reusing instances.
As the ObjectMapper is threadsafe, we recommend assigning it to a public static final variable and using it wherever you communicate with the same JSON dialect.

