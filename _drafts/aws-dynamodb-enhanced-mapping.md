---
layout: post
title:  "Using the dynamodb-enhanced client"
categories: [aws]
tags: aws java kotlin lombok dynamodb
---

# Overview

The [DynamoDB Enhanced Client API][ddb-enhanced] library allows us to integrate DynamoDB into our application code.
The client supports an annotation-driven programming model to map objects into DynamoDB tables.
In this article, we want to explore how to use the client to map JavaBeans, Lombok Beans, and Kotlin data classes.
We will also use property-based testing (using Kotest) to thoroughly test our mapping with generated test inputs to ensure we get all edge cases in the mapping.
Let's start with a quick overview of the DynamoDB concepts that are relevant for this article.

# What is DynamoDB?

Amazon DynamoDB is a _key-value NoSQL database_. Keys are of type _String_, and values can be simple types such as _String, Number, Boolean_ or
complex types such as _List, Map, or Set_.[^1]

A table is the fundamental concept in DynamoDB. In contrast to relational databases, DynamoDB tables are schemaless. 
A DynamoDB table only needs its primary key to be defined when created.
The primary key can be simple (partition key of type _String_, _Number_, or _Binary_) or compound (_partition key_ and _sort key_).
All items inserted into the table need to define that primary key. Besides that, every item in the table
can have a different set of attribute keys and value types:

| partitionKey | attribute1 | attribute2 | attribute3 |
| -----------  | ----------- |
|key-1|string value|number value|string value|
|key-2|string value|null|list value|
|key-3|string value|_not set_|set value|

Items in the database are referenced by their primary key to be read, updated, or deleted.
DynamoDB also allows basic query support. With a compound key, you can query with the (partial) partition part of the key and traverse
all items in the order defined by the sort key.

This is, of course, only a brief overview of what DynamoDB is. Visit the [AWS documentation][ddb-what-is] for more details about DynamoDB.

# Using the low-level API

The first option to integrate DynamoDB is to use the low-level client API.
With the low-level client, an item in a DynamoDB table is represented as a map of type {% ihighlight java %}Map<String, AttributeValue>{% endihighlight %}.

{% highlight kotlin %}
{% github_sample /red-green-coding/aws-dynamodb-enhanced/blob/main/src/test/kotlin/basic/SimpleMappingSpec.kt tag:low-level-api %}
{% endhighlight %}

_AttributeValue_ is similar to a union type; this means it contains a value that can be of various types. Depending on the actual type of the value, we'll need to use the correct
accessor method (e.g., _s()_ for String) to access the contained values. 

In most applications, we don't want to use this low-level representation of the database contents throughout
the application as it is unwieldy and error-prone to use. Instead, we typically create model classes to represent database items. We now will look at the dynamodb-enhanced client
that offers a straightforward way to achieve that.

# Using DynamodDB-enhanced

# JavaBean

We'll first look at a basic JavaBean. A JavaBean is a class that needs to follow these conventions:
* It needs to have a no-arg constructor,
* it needs to have a getter and setter method for every attribute,
* the class needs to be annotated with _@DynamoDbBean_,
* the getter methods for the partition and sort key need to be annotated with (_@DynamoDbPartitionKey_ and _@DynamoDbSortKey_),
* the fields of the class can use types like _String_, _List_, or _Map_ suitable to the column type in the table.

{% highlight java %}
{% github_sample /red-green-coding/aws-dynamodb-enhanced/blob/main/src/main/java/basic/JavaItem.java tag:example %}
    // More getters and setters omitted for brevity
}
{% endhighlight %}

# Java records

Unfortunately, Java records are not supported by DynamoDB enhanced yet (see [Github issue][javaRecords]).

# Lombok @Data

As Java records are not supported, we can also use [Lombok][lombok] to avoid some of that boilerplate code needed to set up a JavaBean.
Using the _@Data_ annotation, we can achieve the same result as in the JavaBean example. The _onMethod_ parameter in Lombok's _@Getter_ annotation is used to
put the DynamoDB annotations on the generated getter code (see [documentation][lombok-gettersetter]).

{% highlight java %}
{% github_sample /red-green-coding/aws-dynamodb-enhanced/blob/main/src/main/java/basic/LombokMutableItem.java tag:example %}
{% endhighlight %}

# Lombok @Value

If we want to use an immutable Lombok value, we need to use a slightly different configuration to allow DynamodDB to
use the generated Lombok builder so it knows how to instantiate our model class.

{% highlight java %}
{% github_sample /red-green-coding/aws-dynamodb-enhanced/blob/main/src/main/java/basic/LombokImmutableItem.java tag:example %}
{% endhighlight %}

# Kotlin data classes

Kotlin data classes play poorly together with DynamoDB. We either need to give up some of Kotlin's features we love, like
having immutable data classes, or we need to [manually write builder classes][dataClass-builder] for our data classes, which is cumbersome.

Fortunately, there is another option. We can use the third-party library [dynamodb-kotlin-module][dataClass-lib] to easily use data classes with DynamoDB.
It offers its own set of annotations for annotating the model class and provides an alternative schema implementation compatible with Kotlin's data classes.

{% highlight kotlin %}
{% github_sample /red-green-coding/aws-dynamodb-enhanced/blob/main/src/main/kotlin/sample/KotlinItem.kt tag:example %}
{% endhighlight %}

# Testing our mapping

We are using property-based testing[^2] to test our mapping comprehensively. The benefit of using a property-based testing approach is that
we will exercise our mapping configuration with a bigger range of generated inputs than if we write single example-based tests.
We can cover more edge cases and get good feedback if our model can be reliably mapped to the database and back.

In our tests, we will map a generated value to the database. Then, we will read that item from the database again and
finally compare if the item from the database equals our initial value.[^3]

Our tests are built using the property-based testing support of [Kotest][kotest-proptest].
Each such test uses a test data generator. It allows us to create and populate our model classes with random values. The data generator is implemented
using some [Kotest generators][kotest-generator]:

{% highlight kotlin %}
{% github_sample /red-green-coding/aws-dynamodb-enhanced/blob/main/src/test/kotlin/basic/Testdata.kt tag:example %}
{% endhighlight %}

Next is the test itself. It consists of the infrastructure needed to spin up a Localstack Docker container.

{% highlight kotlin %}
{% github_sample /red-green-coding/aws-dynamodb-enhanced/blob/main/src/test/kotlin/basic/SimpleMappingSpec.kt tag:localstack %}
{% endhighlight %}

Using the [Kotest testcontainers integration][kotest-testcontainers], we ensure that the test runner starts a Localstack container before
executing our test code. We then configure a DynamoDB client to connect to DynamoDB inside the Docker container.

With this infrastructure in place, we can finally define the test.

{% highlight kotlin %}
{% github_sample /red-green-coding/aws-dynamodb-enhanced/blob/main/src/test/kotlin/basic/SimpleMappingSpec.kt tag:proptest-java %}
{% endhighlight %}

The tests all passed, meaning we don't have any issues with our mapping. Part 2 of this article will look at a more
complex mapping. Our test setup will be helpful when testing the more complex mapping.

We have added equivalent tests for the Lombok data bean, the Lombok value bean, and the Kotlin data class. They mainly differ in the
generators they use to create the test data. Also, the Kotlin data class tests use the alternative schema implementation provided by the [dynamodb-kotlin-module][dataClass-lib].
See the corresponding [GitHub example][github-example-basic].

# Conclusion

In this example, we showed how to use the DynamoDB-enhanced client to map seamlessly between the Database items
and our model classes. We examined different options for how to set up the model classes with plain Java, Lombok, and Kotlin data classes.

Furthermore, we used property-based testing for comprehensive coverage of our mapping configuration. For completeness
we have also added a [JUnit-based test][github-example-junit].

The DynamoDB Enhanced Client API is way more flexible than we showed today. Head over to its [documentation][ddb-enhanced] for more details on how to use it further.

Find the source code of our examples on [GitHub][github-examples].

# Notes

[^1]: See [Supported data types][ddb-datatypes] for the list of supported data types.
[^2]: Read [The "Property Based Testing" series][proptest-intro] to get an introduction to the fundamentals of property-based testing.
[^3]: This corresponds to the [There and back again][proptest-there-and-back] approach as described in the [The "Property Based Testing" series][proptest-intro]

[ddb-what-is]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Introduction.html
[ddb-datatypes]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.NamingRulesDataTypes.html#HowItWorks.DataTypes
[ddb-enhanced]: https://github.com/aws/aws-sdk-java-v2/blob/master/services-custom/dynamodb-enhanced/README.md

[javaRecords]: https://github.com/aws/aws-sdk-java-v2/issues/4281#issuecomment-1678350710
[lombok]: https://projectlombok.org/
[lombok-gettersetter]: https://projectlombok.org/features/GetterSetter

[dataClass-featureRequest]: https://github.com/aws/aws-sdk-java-v2/issues/2096
[dataClass-lib]: https://betterprogramming.pub/i-made-a-kotlin-plugin-for-dynamo-db-mapper-cce1924fcd1e
[dataClass-builder]: https://github.com/aws/aws-sdk-java-v2/issues/2096#issuecomment-752667521

[proptest-intro]: https://fsharpforfunandprofit.com/series/property-based-testing/
[proptest-there-and-back]: https://fsharpforfunandprofit.com/posts/property-based-testing-3/#inverseRev

[kotest-generator]: https://kotest.io/docs/proptest/property-test-generators-list.html
[kotest-proptest]: https://kotest.io/docs/proptest/property-based-testing.html
[kotest-testcontainers]: https://kotest.io/docs/extensions/test_containers.html

[github-examples]: https://github.com/red-green-coding/aws-dynamodb-enhanced
[github-example-basic]: https://github.com/red-green-coding/aws-dynamodb-enhanced/blob/main/src/test/kotlin/basic/SimpleMappingSpec.kt#L29
[github-example-junit]: https://github.com/red-green-coding/aws-dynamodb-enhanced/blob/main/src/test/java/basic/SimpleMappingTest.java#L21
