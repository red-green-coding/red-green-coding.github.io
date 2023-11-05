---
layout: post
title:  "Using dynamodb-enhanced"
categories: [aws]
tags: aws kotlin lombok dynamodb
---

# Overview

The DynamoDB Enhanced Client API is a library that allows us to integrate DynamoDB into our application code.
Using the client, we can directly map between DynamoDB tables and our model classes.
In this example, we want to explore how to set up these classes for seamless mapping.

# What is DynamoDB?

Amazon DynamoDB is a key-value NoSQL database. Keys are of type _string_, and values can be either simple types as _String, Number, Boolean_ or
complex types as _List, Map, or Set_.[^1]

A table is the fundamental concept in DynamoDB. In contrast to relational databases DynamoDB tables are schemaless. This means that only the primary key needs
to be defined when creating the table. The primary key can be simple (partition key of type string, number, or binary) or compound (partition key + sort key).
All items inserted into the table need to define that primary key. Besides that, every item
can have a different set of attribute keys and value types:

| partitionKey | attribute1 | attribute2 | attribute3 |
| -----------  | ----------- |
|key-1|string value|number value|string value|
|key-2|string value|null|list value|
|key-3|string value|_not set_|set value|

Items in the database are identified by its primary key to be then read, updated, or deleted.
DynamoDB also allows basic query support. With a compound key you can query with the partition part of the key and you can then traverse
all items in the order defined by the sort key.

# Using the low-level API

The first option to integrate DynamoDB is to use the low-level client API.
With the low-level client an item in a DynamoDB table is represented as a map of type {% ihighlight java %}Map<String, AttributeValue>{% endihighlight %}.

{% highlight kotlin %}
{% github_sample /abendt/aws-dynamodb/blob/main/src/test/kotlin/basic/SimpleMappingSpec.kt tag:low-level-api %}
{% endhighlight %}

_AttributeValue_ is similiar to a union type, this means it contains a value that can be of several types. Depending on the actual type of the value we'll need to use the correct
accessor method (e.g. _s()_ for String) to access the contained values. In most applications we don't want to use this low-level representation of the database contents throughout
the application as it is unwieldly and error-prone to use. Instead we typically create model classes to represent database items. We now will have a look at the dynamodb-enhanced client
that offers a straight forward way to achieve that.

# Using DynamodDB enhanced

# Plain Java

We'll first look at a basic JavaBean. This is a class that needs to follow these conventions:
* It needs to have a no-arg constructor
* It needs to have a getter and setter method for every attribute
* It needs to be annotated with _@DynamoDbBean_
* the getter methods for the partition and and sort key need to be annotated with (_@DynamoDbPartitionKey_ and _@DynamoDbSortKey_)
* the fields of the class can use types like _String_, _List_ or _Map_ suitable to the column type in the Table.

{% highlight java %}
{% github_sample /abendt/aws-dynamodb/blob/main/src/main/java/basic/JavaRecord.java tag:example %}
    // more  getters and setters omitted for brevity
}
{% endhighlight %}

# Java records

Unfortunately Java records are not supported by DynamoDB enhanced yet (see [Github issue][javaRecords])

# Lombok

As Java records are not supported we also can use [Lombok][lombok] to avoid some of that boilerplate code thats needed to properly setup a JavaBean.
Using the _@Data_ annotation we can achieve the same result as in the plain Java example.

{% highlight java %}
{% github_sample /abendt/aws-dynamodb/blob/main/src/main/java/basic/LombokMutableRecord.java tag:example %}
{% endhighlight %}

# Lombok (immutable)

If we want to use an immutable Lombok value we need to use some additional configuration to allow DynamodDB to
use the generated Lombok builder so it can instantiate our model class.

{% highlight java %}
{% github_sample /abendt/aws-dynamodb/blob/main/src/main/java/basic/LombokImmutableRecord.java tag:example %}
{% endhighlight %}

# Kotlin data classes

Kotlin data classes don't play well together with DynamoDB. We either need to give up some of Kotlin's features we love like
having immutable data classes or we need to [manually write builder classes][dataClass-builder] for our data classes which is cumbersome.

Fortunately there is another option. We can use a [third-party library available][dataClass-lib], that allows us to easily use data classes with DynamoDB.
It offers its own set of annotations for annotatint the model class and provides us an alternative schema implementation that is compatible with Kotlin's data classes.

{% highlight kotlin %}
{% github_sample /abendt/aws-dynamodb/blob/main/src/main/kotlin/sample/KotlinRecord.kt tag:example %}
{% endhighlight %}

# Testing our mapping

To test our mapping comprehensively we are using property-based testing[^2]. The benefit of that approach is that
we will exercise our mapping configuration with a much bigger range of generated inputs than if we write single example based tests.
With this approach we will cover much more edge cases and learn if our model can be safely mapped to the database and back.

In our tests we will take a generated value and map it to the database. Then we will read that item from the database and
finally compare if the item from the database equals our initial value.[^3]

Our examples are implemented using [Kotest][kotest-proptest]

The test consists of a Testdata generator. It allows to create our model classes and populates them with random values

{% highlight kotlin %}
{% github_sample /abendt/aws-dynamodb/blob/main/src/test/kotlin/basic/Testdata.kt tag:example %}
{% endhighlight %}

Next is the test itself, it consists of the infrastructure needed to spin up a Localstack Docker container

{% highlight kotlin %}
{% github_sample /abendt/aws-dynamodb/blob/main/src/test/kotlin/basic/SimpleMappingSpec.kt tag:localstack %}
{% endhighlight %}

Using the [Kotest testcontainers integration][kotest-testcontainers] we ensure a Localstack container will be started before
our test runs. We then configure a DynamoDB client so that it can connect to DynamoDB inside the Docker container.

With this infrastructure in place we are finally able to run the test

{% highlight kotlin %}
{% github_sample /abendt/aws-dynamodb/blob/main/src/test/kotlin/basic/SimpleMappingSpec.kt tag:proptest-java %}
{% endhighlight %}

We have added equivalent tests for the Lombok data bean, the Lombok value bean and the Kotlin data class. They mainly differ in the
generators they use to create the test data. The Kotlin data class tests uses the alternative schema implementation provided by the [library][dataClass-lib].

# A more complex example

TODO

* show model class with more types and nested types
* show that property based test finds mapping issues where programming language types cannot be mapped to table 

{% highlight java %}
{% github_sample /abendt/aws-dynamodb/blob/main/src/main/java/complex/LombokComplexRecord.java tag:example %}
{% endhighlight %}

{% highlight java %}
{% github_sample /abendt/aws-dynamodb/blob/main/src/main/java/complex/NestedLombok.java tag:example %}
{% endhighlight %}

{% highlight kotlin %}
{% github_sample /abendt/aws-dynamodb/blob/main/src/test/kotlin/complex/Testdata.kt tag:example %}
{% endhighlight %}

* provide custom mapping (custom converter)
* constrain types we use to avoid

# Conclusion

In this example we showed how we can use the DynamoDB enhanced client to map seamlessly between the Database items
and our model classes. We examined different options how to setup the model classes with plain Java, Lombok and Kotlin data classes.

Furthermore we used property-based testing for comprehensive coverage of our mapping configuration.By that we could
find identify some edge-cases that would let the mapping fail.

Find the source code of our examples on [GitHub][github-examples].

# Notes

[^1]: See [Supported data types][ddb-datatypes] for the list of supported data types.
[^2]: Read [The "Property Based Testing" series][proptest-intro] to get an introduction into the fundamentals of property-based testing.
[^3]: This corresponds to the [There and back again][proptest-there-and-back] approach as described in the [The "Property Based Testing" series][proptest-intro]

[ddb-what-is]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Introduction.html
[ddb-datatypes]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.NamingRulesDataTypes.html#HowItWorks.DataTypes
[ddb-enhanced]: https://github.com/aws/aws-sdk-java-v2/blob/master/services-custom/dynamodb-enhanced/README.md

[javaRecords]: https://github.com/aws/aws-sdk-java-v2/issues/4281#issuecomment-1678350710
[lombok]: https://projectlombok.org/

[dataClass-featureRequest]: https://github.com/aws/aws-sdk-java-v2/issues/2096
[dataClass-lib]: https://betterprogramming.pub/i-made-a-kotlin-plugin-for-dynamo-db-mapper-cce1924fcd1e
[dataClass-builder]: https://github.com/aws/aws-sdk-java-v2/issues/2096#issuecomment-752667521

[proptest-intro]: https://fsharpforfunandprofit.com/series/property-based-testing/
[proptest-there-and-back]: https://fsharpforfunandprofit.com/posts/property-based-testing-3/#inverseRev

[kotest-proptest]: https://kotest.io/docs/proptest/property-based-testing.html
[kotest-testcontainers]: https://kotest.io/docs/extensions/test_containers.html

[github-examples]: https://github.com/abendt/aws-dynamodb
