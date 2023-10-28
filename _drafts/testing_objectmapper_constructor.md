---
layout: post
title:  "Avoid mocking that ObjectMapper! (part 2)"
categories: [bettertests]
---

# Overview

In [part #1][part-1] of this article, we showed _why you shouldn't mock an ObjectMapper_ in your tests.
The article showed how to improve tests to be more meaningful and accurate by not
mocking third-party code. Instead, we advocated testing using actual third-party code dependencies.

Today, we want to go a step further and improve the quality and maintainability of our tests by _decoupling
our test code from the production code_.

# The problem

Maintaining the codebase can become more complicated when test and production code are too tightly coupled.
When test and production code is too tightly coupled,
adding functionality, even in small ways, causes many tests to break, often in unrelated locations.

Another area is refactorings. We usually want to improve our code base by doing
structural changes that don't change external behavior. With too tightly coupled test and production code, these
refactorings tend to break many tests, though the code still behaves correctly.

Fixing these test failures is an arduous and risky task, as you need to introduce even more changes to the code.
Adding new functionality over time becomes more and more cumbersome.
Refactorings are often avoided as they cause rippling changes through the test code.

If not treated, this process will gradually reduce the quality of the tests, slowing future development even more.

# Maintaining the codebase

Let's look at a small example to understand the problem better.
We use the same example from [part #1][part-1] of this article.

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

Following is the current version of the test

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

Let's assume that for maintenance reasons, we want to do a refactoring.
For example, we want to switch the JSON mapper from Jackon to the alternative implementation [Gson][gson].

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

The reason the test is failing is that the test didn't construct the class under test correctly.
To fix that, we would also need to modify the test. This is the exact situation we want to avoid.

The root cause here is the design choice to put the ObjectMapper as a parameter into the constructor of our class.
In consequence, our test also needs to know which mapper implementation the production code uses so it can construct the test subject.
As the test does not know how to provide the updated dependency, it will fail. _The tests are too tightly coupled to the production code_.

Let's look at how we can improve the situation by decoupling the test from the production code.

# hide implementation details

The underlying problem here is that in the initial design, there is no differentiation between implementation details
and actual collaborators. All dependencies are passed into the constructor.

We often find this pattern to put all dependencies of a class in its constructor in projects that use dependency injection frameworks.
Dependency injection frameworks make it easy to structure your code like that, as the framework will do all the construction work for you.

This ease is continued by the use of mocking frameworks like [Mockito][mockito], as it again makes it very easy to create our class and just mock
all of its dependencies.

These seemingly effortless choices can hurt the long-term maintainability of our codebase as they also tend to allow unintentional coupling between test and production code to creep into the codebase.

In addition, people often tend to follow the advice to have one test per unit (e.g., class, function), which can lead to tight coupling, too.

To improve the design, we will hide the implementation details by removing the mapper parameter from the constructor.
Instead, we create the mapper inside our class or
reference a shared, static instance.

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

The change serves several purposes:
* The mapper now is an implementation detail of _MyService_. The test does not need to be concerned to provide a mapper.
* Consequently, we can now switch mapper implementations without modifying the test.

Looking at the constructor of _MyService_, we still need to pass in an instance of _CollaboratorService_.
From a design point of view, this is sensible, as _CollaboratorService_ is another functional component of our system, which exists independently of _MyService_.

We can also express this changed relationship in a UML diagram with association vs. aggregation
* association: MyService _knows_ a CollaboratorService
* aggregation: MyService _owns_ a mapper[^1]

![diagram](/assets/plantuml/testing_objectmapper_constructor/diagram.png)

# Listen to the tests

When adding dependencies to our code, we should distinguish between collaborators and implementation details.
When writing tests, we should carefully decide
if we want to replace the dependency of a class with a mock or use an actual implementation instead[^2].
These choices will have an effect on the quality of
the tests and, consequently, on the maintainability of our codebase.

Of course, this is just a tiny example. In real-world projects with tests that are too tightly coupled with production code,
small changes often cause many tests to fail for many more reasons than we looked at here. In addition to what we discussed here,
there are many more things
we need to consider to avoid coupling the test code to the production code too much.

Applying Test-driven development gives you feedback about these kinds of problems. Listen to the tests. If something is not easy to test, then modify your design
to make it easier to test things. The main benefit of Test-driven development is that you get this feedback early on in the lifetime of some code.
If you listen to this feedback and design your code accordingly you will end up with modular code, that is testable and can be modified easily.

We do this as otherwise the
time needed to fix these tests can seriously slow down ongoing development
and reduce the further adoption of test-driven development
as people conclude that unit tests hinder development.

# Conclusion

In this article, we showed how we can improve the quality of unit tests by
decoupling tests from production code.

We achieved this by modifying the design of our production code to better distinguish between implementation details
and required dependencies.

These design changes allow us to have tests with less knowledge about the internals of the production code.
Tests written that way allow us to add features and make refactorings more easily while breaking fewer unrelated tests. 

# Notes

[^1]: We would still consider this to be an _aggregation_ even if you are referencing a shared mapper. The fact that the mapper is shared is just an implementation detail.
[^2]: Remember to avoid mocking third-party code (see [Part #1][part-1]).

[part-1]: {% post_url 2023-10-16-testing_objectmapper_mock %}
[mockito]: https://site.mockito.org/
[gson]: https://github.com/google/gson
[test-contravariance]: https://blog.cleancoder.com/uncle-bob/2017/10/03/TestContravariance.html
