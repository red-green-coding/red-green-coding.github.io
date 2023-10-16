---
layout: post
title:  "Avoid mocking that ObjectMapper! (part 2)"
categories: [bettertests]
---

# Overview

In part #1 of this article we showed _why you shouldn't mock an ObjectMapper_ in your tests.
In the article we showed how we can improve our test code to be more meaningful and accurate by not
mocking third-party code in our tests. Instead we advocated to test using actual third-party code dependencies.
Today we want to go a step further and improve quality and maintainability of our tests by _decoupling 
our test code from the production code_.

# The problem

When test code and production code is too tightly coupled maintaining the codebase becomes more difficult.
Making refactorings tends to break tests. Changing the functionality even in small ways then often cause 
large changes to the tests. This will slow down further development and
Untreated this can decrease the acceptance of automated tests in a project.

## Maintaining out codebase

We build on the example from the article TODO

{% highlight java %}
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

We are using the updated version of the test

{% highlight java %}
@ExtendWith(MockitoExtension.class)
public class MyService2Test {

    @InjectMocks
    MyService1 myService;

    @Mock
    MyOtherService myOtherService;

    @Spy
    ObjectMapper mapper;

    @Test
    void canConsumeJson() throws Exception {
        var data = """
                {"Name" "MyName", "yearOfBirth": "1973"}
                """;

        myService.useData(data);

        Mockito.verify(myOtherService)
            .useValue(Mockito.argThat(arg -> arg.name().equals("MyName")));
    }
}
{% endhighlight %}

Lets assume now that for maintaince reason we want to switch to the alternative JSON mapper implementation [Gson][gson].
We consider this to be a refactoring. The functionality of our class is not supposed to change, we are just changing
an implementation detail.

{% highlight java %}
public class MyService3 {
    private Gson mapper;
    private MyOtherService myOtherService;

    MyService3(Gson mapper, MyOtherService myOtherService) {
        this.mapper = mapper;
        this.myOtherService = myOtherService;
    }

    void useData(String json) {
        try {
            var dto = mapper.fromJson(json, MyDto.class);
            myOtherService.useDto(dto);
        } catch (JsonSyntaxException e) {
            throw new RuntimeException(e);
        }
    }
}
{% endhighlight %}

When we re-run our tests we see that they are failing now.

{% highlight bash %}
sample.MyService3Test

    ✘ canConsumeJson()

      NullPointerException: Cannot invoke "com.google.gson.Gson.fromJson(String, java.lang.Class)"
        because "this.mapper"
{% endhighlight %}

## Test code should be decoupled from the code it tests

The reason is that our test now didn't construct the code under test correctly. Of course we could fix that by modifiying the test but still this is
an unfortunate situation. A test should ideally only focus on the behaviour of the code under test and not make too many assumptions about its internals.
By the design choice to make

It shouldn't really matter what kind of mapper we are using inside of _MyService_. What should matter is if it behaves correctly. The problem
here is that the code

# Conclusion

![diagram](/assets/plantuml/testing_objectmapper_constructor/diagram.png)

# Notes

[test-contravariance]: https://blog.cleancoder.com/uncle-bob/2017/10/03/TestContravariance.html
[gson]: https://github.com/google/gson