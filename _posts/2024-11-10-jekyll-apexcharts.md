---
layout: post
title:  "Embedding ApexCharts.js in a Jekyll Blog Post"
categories: [jekyll]
tags: jekyll apexcharts
apexcharts: true
---

To add charts to our blog posts, we needed a Jekyll integration but couldn’t find a suitable plugin. Here’s the custom solution we developed. It leverages [ApexCharts.js][apexcharts], a flexible JavaScript library that makes it easy to create appealing visualizations, and is inspired by ideas from the [Notepad.ONGHU][notepad.onghu] blog.

Our goal was to embed an ApexChart with configurations like this:

<pre>
```apexchart
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
```
</pre>

This example, taken from the ApexCharts documentation on [Creating Your First JavaScript Chart][apexcharts-example] showcases a simple line chart of sales data over the years.

## Step 1: Enable ApexCharts in Your Jekyll Site

To load ApexCharts only when needed, add the following conditional script in `_includes/footer.html`:

```html
{% raw %}{% if page.apexcharts %}{% endraw %}

<script src="https://cdn.jsdelivr.net/npm/apexcharts"></script>

{% raw %}{% endif %}{% endraw %}
```

In the same file (within the same conditional), add another script block to render charts after the page loads. This script will find all code blocks containing ApexCharts configuration and replace them with rendered charts:

```html
<script>
    window.addEventListener('load', function() {
        const elements = document.querySelectorAll('.language-apexchart');

        elements.forEach(function(element) {

            let options;

            try {
                options = JSON.parse(element.textContent)
            } catch (e) {
                options = new Function("return " + element.textContent)()
            }

            // the highlight elements renders to pre -> code
            // we navigate to the parent of that
            const preElement = element.parentElement
            const parent = preElement.parentElement

            // Create a new div element
            const newDiv = document.createElement('div');

            // Optionally, you can set a class or ID to the new div
            newDiv.classList.add('new-chart-container');

            // Replace the original element tree with the new div
            parent.replaceChild(newDiv, preElement);

            const chart = new ApexCharts(newDiv, options);
            chart.render();
        });
    });
</script>
```

In each post where you want to use ApexCharts, modify the front matter to include `apexcharts: true`:

```markdown
---
layout: post
title:  "My blog post"
apexcharts: true
---
```

## Step 2: Embed Charts in Your Post

Embedding a chart is straightforward. Add the ApexChart configuration directly in a code block with the language specified as apexchart. Here’s an example:

### JavaScript content

When the page loads, the script will detect this apexchart block, parse the configuration, and render it as an interactive chart using ApexCharts.

<pre>
```apexchart
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
```
</pre>

```apexchart
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
```

### JSON content

Alternatively, you can define the chart configuration using JSON syntax:

<pre>
```apexchart
 {
  "chart": {
    "type": "line"
  },
  "series": [{
    "name": "sales",
    "data": [30,40,35,50,49,60,70,91,125]
  }],
  "xaxis": {
    "categories": [1991,1992,1993,1994,1995,1996,1997, 1998,1999]
  }
}
```
</pre>

```apexchart
 {
  "chart": {
    "type": "line"
  },
  "series": [{
    "name": "sales",
    "data": [30,40,35,50,49,60,70,91,125]
  }],
  "xaxis": {
    "categories": [1991,1992,1993,1994,1995,1996,1997, 1998,1999]
  }
}
```

### Include JSON content

A third option is to keep the chart configuration in an external JSON file for a cleaner post. Place the configuration in e.g. `_includes/jekyll-apexcharts/example.json`. To include the chart in your post, use:

<pre>
```apexchart
{% include jekyll-apexcharts/example.json %}
```
</pre>

```apexchart
{% include jekyll-apexcharts/example.json %}
```

This approach keeps your post sources shorter and easier to read, while still allowing ApexCharts to render the chart.

[jekyll-tags]: https://jekyllrb.com/docs/plugins/tags/
[apexcharts]: https://apexcharts.com/
[apexcharts-example]: https://apexcharts.com/docs/creating-first-javascript-chart/
[notepad.onghu]: https://notepad.onghu.com/2023/using-mermaid-in-a-textile-post-jekyll/