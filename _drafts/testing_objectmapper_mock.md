---
layout: post
title:  "Avoid mocking the ObjectMapper!"
categories: [bettertests]
---

# Overview

In this quick article, we'll show _why you shouldn't mock an ObjectMapper_ in your tests.
We assume that you have a general understanding of Java, Unit testing, and Mocking with Mockito.
Here is a [Tutorial][mockito-tutorial] to refresh your knowledge about the annotations used in our code samples.

_Note: people who are already convinced that you shouldn't mock third-party code don't need to read further._

# The problem

A recurring problematic pattern we find in
codebases is when the [Jackson ObjectMapper][jackson] is mocked in unit tests.
This violates an important guideline: _Dont't mock third-party code_.

Let's first have a look at some source code and then dive in to understand why this guideline matters.

{% highlight java %}
public record MyDto(String name, int yearOfBirth) {
}

public class MyOtherService {
public void useDto(MyDto dto) {
...
}
}

public class MyService1 {
private ObjectMapper mapper;
private MyOtherService myOtherService;

    MyService1(MyOtherService myOtherService, ObjectMapper mapper) {
        this.myOtherService = myOtherService;
        this.mapper = mapper;
    }

    void useData(String json) {
        var dto = mapper.readValue(json, MyDto.class);
        myOtherService.useDto(dto);
    }
}
{% endhighlight %}

The code example consists of a DTO class, the class _MyService_ we want to test, and the class _MyOtherService_ which is
a dependency of our class to test. This a trimmed-down example of code like we often find in existing codebases.

Now let's look at the corresponding test. The test uses the problematic pattern we mentioned above.

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

        Mockito.doReturn(new MyDto("MyName", 1973)).when(mapper).readValue(data, MyDto.class);

        myService.useData(data);

        Mockito.verify(myOtherService).useDto(Mockito.argThat(arg -> arg.name().equals("MyName")));
    }
}
{% endhighlight %}

As we can see, all dependencies of _MyService_ are replaced with mocks during the test. Why is this problematic?

# Don't mock the ObjectMapper

If we look a bit closer we can see that there are two problems with the JSON mapping:
* the JSON payload has an attribute named _Name_, in the DTO that field is named _name_
* the attribute _yearOfBirth_ has the type string, in the DTO that field is of type number

Although our tests pass the underlying code is broken. It will not be able to handle the JSON payload described in the test. Our
test is not very accurate because the central behavior of our class under test is now being provided by a mock. This causes the test to become quite meaningless.

Mocking third-party dependencies like the ObjectMapper often leads to this. Tests become inaccurate and fragile.
Third-party dependencies can and will change, and mocking them may not reflect their actual behavior.
This is especially true with a complex beast like the ObjectMapper.
Its behavior not just depends on which methods our code directly calls, the mapper also needs to be configured properly.

This leads us to the conclusion, that we consider mocking an ObjectMapper as too risky for our purposes.
We want our tests to be meaningful and accurate.

Luckily there is a rather easy fix. An ObjectMapper is easy to create, by just invoking its constructor: `new ObjectMapper()`. (TODO footnote re-use shared mapper)
We slightly modified our test to use a real mapper instead of a mocked one:

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
                {"name" "MyName", "yearOfBirth": 1974"}
                """;

        myService.useData(data);

        Mockito.verify(myOtherService).useDto(Mockito.argThat(arg -> arg.name().equals("MyName")));
    }
}
{% endhighlight %}

By using a _@Spy_ annotation we are still letting Mockito do the wiring. Instead of creating a mock, it will now create a real ObjectMapper instance. When we re-run
the test we can see that it now fails:

{% highlight bash %}
✘ canConsumeJson()

    UnrecognizedPropertyException: 
        Unrecognized field "Name" (class sample.MyDto), 
        not marked as ignorable (2 known properties: "name", "yearOfBirth"])
{% endhighlight %}

We now get better feedback about the state of our code and can either fix our implementation or adapt the test data, depending on which was wrong.

# Don't mock third-party code

Of course, this problem is not limited to the ObjectMapper.
Most third-party code we typically use is rather complex. This is especially true for third-party code
that communicates with external systems like databases or message brokers.
This is why the guideline exists to avoid mocking third-party code in general. The risk-benefit ratio is just not good.

In our example switching from an ObjectMapper mock to a real one was a rather easy change.
With some of the above-mentioned dependencies, it might be not that easy.
If for example, we want to use a real Database client in our test we would also need some real database to connect to.
This is the realm of integration testing and another topic.

# Conclusion

In this article, we explained why you should avoid mocking the _ObjectMapper_ in your unit tests.
Instead, we show that it's more accurate to test using a real mapper instance.

The implementation of the examples can be found on [GitHub][github-examples].

Check out the [Mockito documentation][mockito] for more info on how to use Mockito.
Also, see the section _Don't mock a type you don't own!_ in their article about [How to write good tests][mockito-how].

[mockito]: https://site.mockito.org/
[mockito-tutorial]: https://www.baeldung.com/mockito-annotations
[jackson]: https://github.com/FasterXML/jackson-docs
[mockito-how]: https://github.com/mockito/mockito/wiki/How-to-write-good-tests#dont-mock-a-type-you-dont-own
[github-examples]: https://github.com/red-green-coding/bettertests-objectmapper-mock
