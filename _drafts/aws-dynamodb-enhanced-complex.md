---
layout: post
title:  "Using dynamodb-enhanced (part 2)"
categories: [aws]
tags: aws kotlin lombok dynamodb
---

# Overview

The DynamoDB Enhanced Client API is a library that allows to integrate DynamoDB into application code.
The client supports an annotation-driven programming model to map objects into DynamoDB tables.
In this example we want to explore how we can map plain Java classes, Lombok classes and Kotlin data classes.
We will also use property-based testing to test our mapping with a large number of inputs to ensure we don't miss any edgecases in our mapping.

# A more complex example

TODO

* show model class with more types and nested types
* show that property-based test finds mapping issues where not all values of a given type can be mapped to a table

{% highlight java %}
{% github_sample /red-green-coding/aws-dynamodb-enhanced/blob/main/src/main/java/complex/LombokComplexItem.java tag:example %}
{% endhighlight %}

{% highlight java %}
{% github_sample /red-green-coding/aws-dynamodb-enhanced/blob/main/src/main/java/complex/NestedLombok.java tag:example %}
{% endhighlight %}

{% highlight kotlin %}
{% github_sample /red-green-coding/aws-dynamodb-enhanced/blob/main/src/test/kotlin/complex/Testdata.kt tag:example %}
{% endhighlight %}

* provide custom mapping (custom converter)
* constrain types we use to avoid

# Conclusion

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

[dataClass-featureRequest]: https://github.com/aws/aws-sdk-java-v2/issues/2096
[dataClass-lib]: https://betterprogramming.pub/i-made-a-kotlin-plugin-for-dynamo-db-mapper-cce1924fcd1e
[dataClass-builder]: https://github.com/aws/aws-sdk-java-v2/issues/2096#issuecomment-752667521

[proptest-intro]: https://fsharpforfunandprofit.com/series/property-based-testing/
[proptest-there-and-back]: https://fsharpforfunandprofit.com/posts/property-based-testing-3/#inverseRev

[kotest-proptest]: https://kotest.io/docs/proptest/property-based-testing.html
[kotest-testcontainers]: https://kotest.io/docs/extensions/test_containers.html

[github-examples]: https://github.com/red-green-coding/aws-dynamodb-enhanced
