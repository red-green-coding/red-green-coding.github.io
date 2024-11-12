---
layout: post
title:  "Embedding ApexCharts.js in a Jekyll Blog Post"
categories: [jekyll]
tags: jekyll apexcharts
apexcharts: true
---

To add charts to our blog posts, we needed an integration with Jekyll but couldn’t find a suitable plugin. Here’s the custom solution we created. It builds on [ApexCharts.js][apexcharts], a flexible JavaScript library that makes it easy to create a wide range of appealing visualizations. It builds on ideas we found in the [Notepad.ONGHU][notepad.onghu] blog.

We want to be able to embed an ApexChart like this:

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

The chart here is the [Creating Your First JavaScript Chart][apexcharts-example] example from the ApexCharts documentation.

## Step 1: Enable ApexCharts in Your Jekyll Site

To load ApexCharts only when needed, we added the script conditionally in `_includes/footer.html`:

```html
{% raw %}{% if page.apexcharts %}{% endraw %}

<script src="https://cdn.jsdelivr.net/npm/apexcharts"></script>

{% raw %}{% endif %}{% endraw %}
```

In the same file we add another script block. This script block will execute after the page has loaded. It will find all elements that contain apex configuration and dynamically replace them with a rendered version that uses the provided configuration.

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

In each post where you want charts, modify the front matter:

```markdown
---
layout: post
title:  "My blog post"
apexcharts: true
---
```

## Step 2: Embed Charts in Your Post

Now, adding a chart is simple. Just put the configuration for your ApexChart in a markdown language element as in the above example.

### JavaScript content

You now can embed an ApexChart diagram by providing the configuration as a languabe block:

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

Alternatively you can use JSON syntax to define the diagram

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

[jekyll-tags]: https://jekyllrb.com/docs/plugins/tags/
[apexcharts]: https://apexcharts.com/
[apexcharts-example]: https://apexcharts.com/docs/creating-first-javascript-chart/
[notepad.onghu]: https://notepad.onghu.com/2023/using-mermaid-in-a-textile-post-jekyll/