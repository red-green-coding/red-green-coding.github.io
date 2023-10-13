---
layout: post
title:  "Avoid mocking the ObjectMapper!"
categories: bettertests
---

# Overview

In this quick article, we'll show _why you shouldn't mock an ObjectMapper in your tests_. 
We assume that you have a general understanding of Mocking with Mockito (examples are in Java). 

Note: people who are already convinced that you shouldn't mock 3rd party code don't need to read further.

# The problem

A recurring problematic pattern we find in
codebases is when the _Jackson ObjectMapper_ is mocked in unit tests. This is an anti-pattern as it violates an important guideline: _Dont't mock 3rd party code!_.

Lets first have a look at some sourcecode and then dive in to understand why this matters.

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
Note: the displayed code has been trimmed for readability and will not compile like this!

Not lets look at the corresponding test. The test uses the problematic pattern we want to have a look at.

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

# Don't mock the ObjectMapper

If we look a bit closer we can see that there are two problems with the JSON mapping:
* the JSON payload has an attribute named _Name_, in the DTO that field is named _name_
* the attribute _yearOfBirth_ has the type string, in the DTO that field is of type number

Although our tests pass the underlying code is broken. It will not be able to handle the JSON payload described in the test.

Mocking third-party dependencies like the ObjectMapper often leads to inaccurate and fragile unit tests.
Third-party dependencies can and will change, and mocking them may not reflect their actual behavior. This is especially true with a complex beast like the ObjectMapper.
Its behaviour not just depends on which methods our code directly calls, the mapper also needs to be configured properly.

This leads us to the conclusion that mocking the ObjectMapper too risky for our purposes. We want our tests to be accurate. 

Instead its much better to just use a real mapper in our tests.
We can achieve that by slightly modifiying the test:

{% highlight java %}
@ExtendWith(MockitoExtension.class)
public class MyService2Test {

    @InjectMocks
    MyService1 myService;

    @Mock
    MyOtherService myOtherService;

    // use real mapper instead of mock
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

By using a _@Spy_ annotation we are still letting mockito do the wiring. Instead of creating a mock it will now create a real ObjectMapper instance. When we re-run 
the test we can see that it now fails:

{% highlight bash %}
✘ canConsumeJson()

    UnrecognizedPropertyException: 
        Unrecognized field "Name" (class sample.MyDto), 
        not marked as ignorable (2 known properties: "name", "yearOfBirth"])
{% endhighlight %}

# don't mock 3rd party code

Of course this problem is not limited to the ObjectMapper.
Most 3rd party code we use in our projects is rather complex. This is especially true for 3rd party code 
that communicates with external systems like databases or message brokers. So you should avoid mocking 3rd party code in general.

Using the real ObjectMapper instead of a mocked one was an easy change. With some of the mentioned dependencies it might be not that easy. If you'd want to use a real Database client
in your test you would also need some real database to connect to. This is the realm of integration testing. Have a look at [testcontainers][testcontainers], it allows you to define such dependencies
as code integrated into your tests.

# Conclusion

In this article, we explained why you should avoid mocking the _ObjectMapper_ in your unit tests. 
Instead we show thats it's more accurate to test using a real mapper instance.

The implementation of the examples can be found over on [GitHub][github-examples]. 

Check out the [Mockito documentation][mockito] for more info on how to use Mockito. Also see their article about [How to write good tests][mockito-how].

[mockito]: https://site.mockito.org/
[mockito-how]: https://github.com/mockito/mockito/wiki/How-to-write-good-tests
[github-examples]: https://github.com/red-green-coding/bettertests-objectmapper-mock
[testcontainers]: https://testcontainers.com/
