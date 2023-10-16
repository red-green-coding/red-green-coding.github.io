---
layout: post
title:  "Avoid mocking that ObjectMapper! (part 2)"
categories: [bettertests]
---

# Overview

In [part #1][part-1] of this article we showed _why you shouldn't mock an ObjectMapper_ in your tests.
In the article we showed how we can improve our test code to be more meaningful and accurate by not
mocking third-party code in our tests. Instead we advocated to test using actual third-party code dependencies.
Today we want to go a step further and improve quality and maintainability of our tests by _decoupling 
our test code from the production code_.

# The problem

When test code and production code is too tightly coupled maintaining the codebase becomes more difficult.
Making refactorings tends to break tests. Changing the functionality even in small ways then often cause 
large changes to the tests. This will slow down further development and
Untreated this can decrease the acceptance of automated tests in a project.

## Maintaining the codebase

We are using the same example as in part #1.

{% highlight java %}
public class MyService1 {
    private ObjectMapper mapper;
    private CollaboratorService collaboratorService;

    MyService1(CollaboratorService collaboratorService, ObjectMapper mapper) {
        this.collaboratorService = collaboratorService;
        this.mapper = mapper;
    }

    void useData(String json) {
        try {
            var dto = mapper.readValue(json, MyValue.class);
            collaboratorService.useValue(dto);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
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
    CollaboratorService collaboratorService;

    @Spy
    ObjectMapper mapper;

    @Test
    void canConsumeJson() throws Exception {
        var data = """
                {"Name" "MyName", "yearOfBirth": "1973"}
                """;

        myService.useData(data);

        Mockito.verify(collaboratorService)
            .useValue(Mockito.argThat(arg -> arg.name().equals("MyName")));
    }
}
{% endhighlight %}

Lets assume now that for maintenance reason we want to switch to the alternative JSON mapper implementation [Gson][gson].
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

The reason is that our test now didn't construct the code under test correctly.
Of course we could fix that by modifiying the test but still this is
an unfortunate situation. 
A test should ideally only focus on the behaviour of the code under test and not make too many assumptions about its internals.
The problem is caused by the choice to put the ObjectMapper into the constructor of _MyService_.

As the test needs to know how the class-under-test is to be constructed this knowledge now has leaked into the test.
The test is closely coupled to the internals of the implementation.

To avoid this coupling we remove the mapper parameter from the constructor and instead either create it inside the class
or reference a shared, static instance.

{% highlight java %}
public class MyService4 {
    private Gson mapper = new Gson();
    private CollaboratorService collaboratorService;

    MyService4(CollaboratorService collaboratorService) {
        this.collaboratorService = collaborator;
    }

    void useData(String json) {
        try {
            var dto = mapper.fromJson(json, MyValue.class);
            collaborator.useValue(dto);
        } catch (JsonSyntaxException e) {
            throw new RuntimeException(e);
        }
    }
}
{% endhighlight %}

{% highlight java %}
@ExtendWith(MockitoExtension.class)
public class MyService4Test {

    @InjectMocks
    MyService4 myService;

    @Mock
    CollaboratorService collaborator;

    @Test
    void canConsumeJson() throws Exception {
        var data = """
                {"name": "MyName", "yearOfBirth": 1973}
                """;

        myService.useData(data);

        Mockito.verify(collaborator)
                .useValue(Mockito.argThat(arg -> arg.name().equals("MyName")));
    }
}
{% endhighlight %}

This serves a number of purposes:
* The mapper now is an implementation detail of _MyService_. Our test does not need to be concerned to provide a mapper.
* We are able to switch mapper libraries without the need to touch the test. 

From a design point of view we have changed the relationship between _MyService_ to the mapper from an association to an aggregation.

![diagram](/assets/plantuml/testing_objectmapper_constructor/diagram.png)

# Conclusion

Don't put all dependencies into the constructor, distinguish between actual collaborators and potential implementation details

# Notes

[part-1]: /bettertests/2023/10/16/testing_objectmapper_mock.html
[test-contravariance]: https://blog.cleancoder.com/uncle-bob/2017/10/03/TestContravariance.html
[gson]: https://github.com/google/gson