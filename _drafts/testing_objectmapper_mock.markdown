---
layout: post
title:  "Avoid mocking that ObjectMapper!"
categories: bettertests
---

# Abstract

In this article we want to discuss why you should not mock the Jackson ObjectMapper

* people who are already convinced to not read 3rd party code don't need to read

# Context

A recurring problematic pattern we find in
codebases is the excessive use of mocking libraries while writing tests. In general mocking libraries are a powerful
tool and we use them a lot, its just important to understand their purpose and where to not use them.

# Problem

{% highlight kotlin %}
data class MyDto(val name: String, val birthYear: Int)

class MyOtherService {
   fun useDto(dto: MyDto) {...}  
}

@Service
class MyService(val mapper: ObjectMapper, val repo: MyOtherService) {
   fun consumeData(json: String) {
      val dto = mapper.readValue(json, MyDto)
      repo.useDto(dto)
   }
}
{% endhighlight %}

{% highlight kotlin %}
class MyServiceTest {
  
  @Mock
  val mapper: ObjectMapper
  
  @Mock
  val repo: MyOtherService

  @InjectMocks
  val service: MyService

  @Test
  fun canConsume() {
    var json = """{"name": "MyName", "birthYear": "1973"}"""

    Mockito.doReturn(MyDto("MyName", 1973)).when(mapper).readValue(...)

    service.consumeData(json)

    Mockito.verify(repo).save(...)
  }
}
{% endhighlight %}

* don't mock 3rd party code
* test contra variance

# Better

* don't mock the mapper use a real mapper instead (either create manually or use spy when using mockitoextension)
  * tests now test behaviour of the actual mapper

* make the mapper private
  * test does not depend on internals anymore 

# Fazit

* mapper was just an example, also generlly applies to 3rd party code

# Links

* everything that was referenced in the post

Check out the [Jekyll docs][jekyll-docs] for more info on how to get the most out of Jekyll. File all bugs/feature requests at [Jekyll’s GitHub repo][jekyll-gh]. If you have questions, you can ask them on [Jekyll Talk][jekyll-talk].

[jekyll-docs]: https://jekyllrb.com/docs/home
[jekyll-gh]:   https://github.com/jekyll/jekyll
[jekyll-talk]: https://talk.jekyllrb.com/
