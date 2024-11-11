---
layout: post
title:  "Embedding ApexCharts.js in a Jekyll Blog Post"
categories: [jekyll]
tags: jekyll apexcharts
apexcharts: true
---

To add charts to our blog posts, we needed an integration with Jekyll but couldn’t find a suitable plugin. Here’s the custom solution we created. It builds on [ApexCharts.js][apexcharts], a flexible JavaScript library that makes it easy to create a wide range of appealing visualizations.

## Step 1: Include ApexCharts in Your Jekyll Site

To load ApexCharts only when needed, we added the script conditionally in `_includes/head.html`:

```html
<head>
    ...
    {% if page.apexcharts %}
    <script src="https://cdn.jsdelivr.net/npm/apexcharts"></script>
    {% endif %}
</head>
```

In each post where you want charts, add this at the top:

```markdown
---
layout: post
title:  "My blog post"
apexcharts: true
---
```

## Step 2: Create a Custom Liquid Tag

We created a [custom liquid tag][jekyll-tags] in `_plugins/apex_charts.rb` to easily embed ApexCharts:

```ruby
module Jekyll
  class ApexChartsBlock < Liquid::Block
    def render(context)
      text = super

      string_length = 8
      id="a" + rand(36**string_length).to_s(36)

      <<~TEXT
        <div id=\"#{id}\"></div>
        <script type="module">
          const chartDiv = document.getElementById("#{id}");

          const chart = new ApexCharts(chartDiv, #{text});
          chart.render();
        </script>
      TEXT
    end
  end
end

Liquid::Template.register_tag('apexcharts', Jekyll::ApexChartsBlock)
```

The custom tag uses the provided configuration block to embed an ApexChart element directly into the page.

## Step 3: Embed Charts in Your Post

Now, adding a chart is simple. Just use the `{% raw %}{% apexcharts %}{% endraw %}` and respective `{% raw %}{% endapexcharts %}{% endraw %}` tag with your ApexCharts configuration. Here we reproduce the [Creating Your First JavaScript Chart][apexcharts-example] example from the ApexCharts documentation.


```javascript
{% raw %}{% apexcharts %}{% endraw %}
{
  chart: {
    type: 'line'
  },
  series: [{
    name: 'sales',
    data: [30,40,35,50,49,60,70,91,125]
  }],
  xaxis: {
    categories: [1991,1992,1993,1994,1995,1996,1997, 1998,1999]
  }
}
{% raw %}{% endapexcharts %}{% endraw %}
```

{% apexcharts %}
{
  chart: {
    type: 'line'
  },
  series: [{
    name: 'sales',
    data: [30,40,35,50,49,60,70,91,125]
  }],
  xaxis: {
    categories: [1991,1992,1993,1994,1995,1996,1997, 1998,1999]
  }
}
{% endapexcharts %}

## Alternative: Include Charts from an External File

Another option is to keep the chart configuration in a separate file, such as `_includes/jekyll-apexcharts/example.json`. This keeps your posts cleaner and easier to manage.

To include the chart in your post, use:

```markdown
{% raw %}{% apexcharts %}
{% include jekyll-apexcharts/example.json %}
{% endapexcharts %}{% endraw %}
```

{% apexcharts %}
{% include jekyll-apexcharts/example.json %}
{% endapexcharts %}

[jekyll-tags]: https://jekyllrb.com/docs/plugins/tags/
[apexcharts]: https://apexcharts.com/
[apexcharts-example]: https://apexcharts.com/docs/creating-first-javascript-chart/