---
layout: post
title:  "Avoid mocking the ObjectMapper!"
categories: [bettertests]
---

# Overview

In this short article, we'll show _why you shouldn't mock an ObjectMapper_ in your tests.
We assume you have a general understanding of Java, Unit testing, and Mocking with Mockito.
Here is a [tutorial][mockito-tutorial] to refresh your knowledge about the annotations used in our code samples.

# The problem

A recurring problematic pattern in
codebases is when the tests mock the [Jackson ObjectMapper][jackson].
Mocking the ObjectMapper violates an important guideline: _Don't mock third-party code_.

First, let's look at a source code example and then understand why this guideline matters.

{% highlight java %}
public record MyValue(String name, int yearOfBirth) { }

public class CollaboratorService {
    public void useValue(MyValue v) { ... }
}

public class MyService1 {
    private ObjectMapper mapper;
    private CollaboratorService collaborator;

    MyService1(CollaboratorService collaborator, ObjectMapper mapper) {
        this.collaborator = collaborator;
        this.mapper = mapper;
    }

    void useData(String json) {
        var dto = mapper.readValue(json, MyValue.class);
        collaborator.useValue(dto);
    }
}
{% endhighlight %}

The code example consists of a value class _MyValue_, the class _MyService_ we want to test, and the class _CollaboratorService_, which is
a dependency of MyService. This a trimmed-down example of code that we could often find in existing codebases.

Now, let's look at the corresponding test.

{% highlight java %}
@ExtendWith(MockitoExtension.class)
public class MyService1Test {

    @InjectMocks
    MyService1 myService;

    @Mock
    CollaboratorService collaborator;

    @Mock
    ObjectMapper mapper;

    @Test
    void canConsumeJson() throws Exception {
        var data = """
                {"Name" "MyName", "yearOfBirth": "1973"}
                """;

        Mockito.doReturn(new MyValue("MyName", 1973))
            .when(mapper).readValue(data, MyValue.class);

        myService.useData(data);

        Mockito.verify(collaborator)
            .useValue(Mockito.argThat(arg -> arg.name().equals("MyName")));
    }
}
{% endhighlight %}

As we can see, the test replaces all dependencies of _MyService_ with mocks during testing. Why is this problematic?

# Don't mock the ObjectMapper

If we take a closer look, we can see that there are two problems with the JSON mapping:
* in the JSON test data, there is an attribute with the key _Name_. In the value class _MyValue_, that field is called _name_. This will let the mapping fail if we run that code in production.
* in the JSON test data, the attribute _yearOfBirth_ is of type string. In _MyValue_, the field _yearOfBirth_ is of type number. Depending on the behavior of the mapper, this implicit type conversion might work in production or not.

Although our tests pass, the underlying code does not work correctly. It will not be able to handle the JSON payload as expected. Our
test is inaccurate because now some crucial behavior of our class under test is replaced by a mock. The test becomes relatively meaningless by that.

Mocking third-party dependencies, as seen here, can often lead to these problems. Tests become inaccurate and fragile.
Third-party dependencies can and will change, and mocking them may not reflect their actual behavior. The developer of the tests likely makes wrong assumptions about how the mapper behaves and configures the mock based on those incorrect assumptions.

Making wrong assumptions will probably happen with a complex beast like the ObjectMapper.
Its behavior does not just depend on which methods our code directly calls. The mapper also needs to be appropriately configured.

As we want our tests to be meaningful and accurate, we generally avoid mocking ObjectMapper in tests. Instead, we use an actual mapper.

Luckily, this is a relatively easy change. We will re-use a pre-configured shared mapper instance 
to ensure the test and production code use the same mapper configuration.
Re-using a shared instance mapper is a general good practice[^1].

{% highlight java %}
@ExtendWith(MockitoExtension.class)
public class MyService2Test {

    @InjectMocks
    MyService1 myService;

    @Mock
    CollaboratorService collaborator;

    //Use a real mapper instead of a mock
    @Spy
    ObjectMapper mapper = MapperConfig.configuredMapper();

    @Test
    void canConsumeJson() throws Exception {
        var data = """
                {"Name" "MyName", "yearOfBirth": "1973"}
                """;

        // No need to stub the mapper anymore

        myService.useData(data);

        Mockito.verify(collaborator)
            .useValue(Mockito.argThat(arg -> arg.name().equals("MyName")));
    }
}
{% endhighlight %}

By using a _@Spy_ annotation, we are still letting Mockito do the wiring. Instead of creating a mock, it will use the provided ObjectMapper instance. When we re-run
the test, we can see that it now fails:

{% highlight bash %}
✘ canConsumeJson()

    UnrecognizedPropertyException: 
        Unrecognized field "Name" (class sample.MyValue), 
        not marked as ignorable (2 known properties: "name", "yearOfBirth"])
{% endhighlight %}

We now get better feedback about the state of our code and can either fix our implementation or adapt the test data, depending on which was wrong.

# Don't mock third-party code

Of course, this problem is wider than the ObjectMapper.
Most third-party code we typically use is rather complex, especially when this code communicates with external systems like databases or message brokers.
As shown with the ObjectMapper, it is advisable to follow the guideline to not mock third-party code. The risk-benefit ratio is not worth it.
The Mockito documentation even mentions this in the article about [How to write good tests][mockito-how].

Switching from an ObjectMapper mock to a real one was relatively easy in our example.
With some of the dependencies mentioned above, it may be more difficult.
If we need to use an actual database client to test our code, we'll also need an actual database so that the database client has something it can connect to.
Writing tests interacting with external systems is the realm of integration testing and a separate topic, which we will not cover today.

# Conclusion

This article explained why you should avoid mocking the _ObjectMapper_ in your unit tests.
Instead, we show that testing using an actual mapper instance is more beneficial.

Find the source code of our examples on [GitHub][github-examples].

Check out the [Mockito documentation][mockito] for more info on how to use Mockito.

[mockito]: https://site.mockito.org/
[mockito-tutorial]: https://www.baeldung.com/mockito-annotations
[jackson]: https://github.com/FasterXML/jackson-docs
[mockito-how]: https://github.com/mockito/mockito/wiki/How-to-write-good-tests#dont-mock-a-type-you-dont-own
[github-examples]: https://github.com/red-green-coding/bettertests-objectmapper-mock
[javadoc]: https://fasterxml.github.io/jackson-databind/javadoc/2.7/com/fasterxml/jackson/databind/ObjectMapper.html

# Notes

[^1]: The ObjectMapper is threadsafe ([javadoc][javadoc]), so it's generally safe to re-use and share it throughout the code