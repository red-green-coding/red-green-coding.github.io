---
layout: post
title:  "Avoid mocking that ObjectMapper! (part 2)"
categories: [bettertests]
---

# Overview

In [part #1][part-1] of this article, we showed _why you shouldn't mock an ObjectMapper_ in your tests.
The article showed how to improve our test code to be more meaningful and accurate by not
mocking third-party code in your tests. Instead, we advocated to test using actual third-party code dependencies.


Today, we want to go a step further and improve the quality and maintainability of our tests by _decoupling
our test code from the production code_.

# The problem

Maintaining the codebase becomes more complicated when test and production code are too tightly coupled.
Making refactorings tends to break tests. Changing the functionality, even in small ways, often causes
significant, rippling test changes. This will slow down further development and
Untreated, this can decrease the acceptance of automated tests in a project.

# Maintaining the codebase

We are using the same example as in part #1.

{% highlight java %}
public class MyService1 {
private ObjectMapper mapper;
private CollaboratorService collaborator;

    MyService1(CollaboratorService collaborator, ObjectMapper mapper) {
        this.collaborator = collaborator;
        this.mapper = mapper;
    }

    void useData(String json) {
        try {
            var dto = mapper.readValue(json, MyValue.class);
            collaborator.useValue(dto);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
}
{% endhighlight %}

We are using the latest version of the test

{% highlight java %}
@ExtendWith(MockitoExtension.class)
public class MyService2Test {

    @InjectMocks
    MyService1 myService;

    @Mock
    CollaboratorService collaborator;

    @Spy
    ObjectMapper mapper;

    @Test
    void canConsumeJson() throws Exception {
        var data = """
                {"Name" "MyName", "yearOfBirth": "1973"}
                """;

        myService.useData(data);

        Mockito.verify(collaborator)
            .useValue(Mockito.argThat(arg -> arg.name().equals("MyName")));
    }
}
{% endhighlight %}

Let's assume now that for maintenance reason, we want to switch to the alternative JSON mapper implementation [Gson][gson].
This is a refactoring as we only want to change an implementation detail, not the general functionality.

{% highlight java %}
public class MyService3 {
private Gson mapper;
private CollaboratorService collaborator;

    MyService3(Gson mapper, CollaboratorService collaborator) {
        this.mapper = mapper;
        this.collaborator = collaborator;
    }

    void useData(String json) {
        try {
            var dto = mapper.fromJson(json, MyDto.class);
            collaborator.useDto(dto);
        } catch (JsonSyntaxException e) {
            throw new RuntimeException(e);
        }
    }
}
{% endhighlight %}

When we re-run our tests, we see that they are failing now.

{% highlight bash %}
sample.MyService3Test

    ✘ canConsumeJson()

      NullPointerException: Cannot invoke "com.google.gson.Gson.fromJson(String, java.lang.Class)"
        because "this.mapper"
{% endhighlight %}

# Test code should be decoupled from the code it tests

The reason is that our test didn't construct the code under test correctly.
Of course, we could fix that by modifying the test, but still, this situation is unfortunate.
A test should focus only on the code's externally visible behavior and minimize assumptions about its internals.

In the current design, to create an instance of _MyService_, the ObjectMapper needs to be passed in as a constructor parameter.
This is a design choice we often find in projects that use Dependency injection frameworks like Spring.

In effect, the test needs to know how the class-under-test will be constructed.
The test is now closely coupled to the internals of the implementation.

# hide implementation details

To avoid this coupling, we can remove the mapper parameter from the constructor and instead either create it inside the class
or reference a shared, static instance (TODO footnote).

{% highlight java %}
public class MyService4 {
private Gson mapper = new Gson();
private CollaboratorService collaborator;

    MyService4(CollaboratorService collaborator) {
        this.collaborator = collaborator;
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

This serves several purposes:
* The mapper now is an implementation detail of _MyService_. Our test does not need to be concerned to provide a mapper.
* Consequently, we can now switch mapper libraries without needing to modify the test.

From a design point of view, we have changed the relationship between _MyService_ and the mapper from an association to an aggregation. MyService now "owns" the mapper.
Looking at the constructor of MyService, we still need to pass in an instance of _CollaboratorService_. This makes sense, as CS is another functional component of our system
that exists independently of MyService.

![diagram](/assets/plantuml/testing_objectmapper_constructor/diagram.png)

We often find this problematic pattern in projects that use DI frameworks like Spring and Mocking frameworks like Mockito in the tests.
With DI frameworks, people tend to put all dependencies into the constructor as it is the easiest thing.
With Mocking frameworks, people tend to mock everything.

Both are poor choices.

We should distinguish between collaborators and implementation details when we add dependencies to a class. When testing, we should carefully decide
if we want to replace the dependency of a class with a mock or use an actual implementation instead.

Applying Test-driven development gives you feedback about these kinds of problems. Listen to the tests. If something is not easy to test, then modify your design
to make it easier to test things.

# Conclusion

In this article, we showed how you can improve the quality of your unit tests by
decoupling the test logic from the internals of the production code.
This provides tests that don't require modification when we apply refactorings to the production code.

# Notes

[part-1]: {% post_url 2023-10-16-testing_objectmapper_mock %}
[test-contravariance]: https://blog.cleancoder.com/uncle-bob/2017/10/03/TestContravariance.html
[gson]: https://github.com/google/gson
