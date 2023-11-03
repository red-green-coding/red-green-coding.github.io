---
layout: post
title:  "Using dynamodb-enhanced"
categories: [aws]
tags: aws kotlin lombok dynamodb
---

# Overview

The DynamoDB Enhanced Client API is a library that allows us to map between classes in our code and DynamoDB tables.
In this showcase we want to explore options how we can map between our code and the table.

Context 
* business applications
* prefer typed to untyped
* Kotlin (Java)

# What is dynamodb?

DynamoDB is a key-value database

| partitionKey | sortKey | attribute1 | attribute2 | attribute3 |
| -----------  | ----------- |
|key-1|0|string value|number value|string value|
|key-2|1|string value|null|list value|
|key-3|2|string value|_not set_|set value|

* all entries need to have a key (single attribute or compound)
* entries can differ in other attributes and types (schemaless)
* attributes may be null or not-set
* attributes can have different types


access primarily get/put/delete + some queries

# Low level API (Sample)

# Business applications

most often in our code we want to work at a higher abstraction level (ORM)

here we want to look at how we need to shape our classes so we can seamlessly map

# Anatomy of a DynamoDB bean

* getter/setter!
* or compatible builder

* plain Java
* Lombok
* Kotlin data classes

# plain Java

* Sample
* boilerplate
* java records not supported (Link to issue?)

# Lombok

* reference Lombok tutorial
* allows to avoid boilerplate
* Sample
* nested, recursive datastructures
* most, complex example

# Kotlin data classes

* not supported out of the box (Link to issue)
* Sample

# Conclusion

Showcase how to use dynamodb-enhanced

showed how to map from/to
* plain java
* Lombok
* Kotlin

Find the source code of our examples on [GitHub][github-examples].

[doc-what-is]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Introduction.html
[doc-datatypes]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.NamingRulesDataTypes.html#HowItWorks.DataTypes
[doc-enhanced]: https://github.com/aws/aws-sdk-java-v2/blob/master/services-custom/dynamodb-enhanced/README.md
[kotlin-support]: https://github.com/aws/aws-sdk-java-v2/issues/2096
[github-examples]: https://github.com/red-green-coding/todo

# Notes

[^1]: Footnote