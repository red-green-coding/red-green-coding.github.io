---
layout: post
title:  "Avoid mocking the ObjectMapper!"
categories: [bettertests]
---

# Overview

In this quick article, we'll show _why you shouldn't mock an ObjectMapper_ in your tests.
We assume you have a general understanding of Java, Unit testing, and Mocking with Mockito.
Here is a [Tutorial][mockito-tutorial] to refresh your knowledge about the annotations used in our code samples.

_Note: If you already believe that mocking third-party code is wrong, you can stop reading now._

# The problem

A recurring problematic pattern in
codebases is when the tests mock the [Jackson ObjectMapper][jackson].
Mocking the ObjectMapper violates an important guideline: _Don't mock third-party code_.

Let's first look at a source code example and then understand why this guideline matters.

{% highlight java %}
public record MyValue(String name, int yearOfBirth) { }

public class MyOtherService {
    public void useValue(MyValue v) { ... }
}

public class MyService1 {
    private ObjectMapper mapper;
    private MyOtherService myOtherService;

    MyService1(MyOtherService myOtherService, ObjectMapper mapper) {
        this.myOtherService = myOtherService;
        this.mapper = mapper;
    }

    void useData(String json) {
        var dto = mapper.readValue(json, MyValue.class);
        myOtherService.useValue(dto);
    }
}
{% endhighlight %}

The code example consists of a value _MyValue_, the class _MyService_ we want to test, and the class _MyOtherService_, which is
a dependency of MyService. This a trimmed-down example of code like we often find in existing codebases.

Now, let's look at the corresponding test.

{% highlight java %}
@ExtendWith(MockitoExtension.class)
public class MyService1Test {

    @InjectMocks
    MyService1 myService;

    @Mock
    MyOtherService myOtherService;

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

        Mockito.verify(myOtherService)
            .useValue(Mockito.argThat(arg -> arg.name().equals("MyName")));
    }
}
{% endhighlight %}

As we can see, the test replaces all dependencies of _MyService_ with mocks during the. Why is this problematic?

# Don't mock the ObjectMapper

If we take a closer look, we can see that there are two problems with the JSON mapping:
* the JSON payload has an attribute named _Name_. In the _value_, that field is named _name_
* the attribute _yearOfBirth_ has the type string. In the _value_, that field is of type number

Although our tests pass, the underlying code does not work correctly. It will not be able to handle the JSON payload as expected. Our
test is not very accurate because a mock is now providing the central behavior of our class under test. The test becomes relatively meaningless by that.

Mocking third-party dependencies like the ObjectMapper can often lead to these problems. Tests become inaccurate and fragile.
Third-party dependencies can and will change, and mocking them may not reflect their actual behavior. It's very likely that the developer of the tests makes wrong assumptions about how the mapper behaves and configures the mock based on those incorrect assumptions.

Making wrong assumptions is most probably with a complex beast like the ObjectMapper.
Its behavior does not just depend on which methods our code directly calls. The mapper also needs to be appropriately configured.

As we want our tests to be meaningful and accurate, we generally avoid mocking ObjectMapper in tests. Instead, we use an actual mapper.

Luckily, this is a relatively easy change. An ObjectMapper is easy to create by invoking its constructor: `new ObjectMapper()`[^1].
We modify our test to use an actual mapper instead of a mocked one:

{% highlight java %}
@ExtendWith(MockitoExtension.class)
public class MyService2Test {

    @InjectMocks
    MyService1 myService;

    @Mock
    MyOtherService myOtherService;

    //Use a real mapper instead of a mock
    @Spy
    ObjectMapper mapper;

    @Test
    void canConsumeJson() throws Exception {
        var data = """
                {"Name" "MyName", "yearOfBirth": "1973"}
                """;

        // No need to stub the mapper anymore

        myService.useData(data);

        Mockito.verify(myOtherService)
            .useValue(Mockito.argThat(arg -> arg.name().equals("MyName")));
    }
}
{% endhighlight %}

By using a _@Spy_ annotation, we are still letting Mockito do the wiring. Instead of creating a mock, it will create an actual ObjectMapper instance. When we re-run
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
With some of the dependencies mentioned above, it may not be easy.
If, for example, we want to use an actual Database client in our test, we would also need a real database to connect to.
This is the realm of integration testing and a topic on its own.

# Conclusion

This article explained why you should avoid mocking the _ObjectMapper_ in your unit tests.
Instead, we show that testing using an actual mapper instance is more accurate.

Find the source code of our examples on [GitHub][github-examples].

Check out the [Mockito documentation][mockito] for more info on how to use Mockito.

[mockito]: https://site.mockito.org/
[mockito-tutorial]: https://www.baeldung.com/mockito-annotations
[jackson]: https://github.com/FasterXML/jackson-docs
[mockito-how]: https://github.com/mockito/mockito/wiki/How-to-write-good-tests#dont-mock-a-type-you-dont-own
[github-examples]: https://github.com/red-green-coding/bettertests-objectmapper-mock

# Notes

[^1]: In an actual project, we would re-use the application's mapper instead of creating a new one.