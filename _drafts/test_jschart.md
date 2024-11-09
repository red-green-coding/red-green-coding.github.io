---
layout: post
title:  "JsChart Demo"
categories: [test]
apexcharts: true
---

# Title

## Subtitle

## Diagram

This is text in the section with the diagram

## Section after diagram

this is text in the section after the diagram

<script>

const options = {
          series: [{
            name: "Regular",
            data: [13409.62, 12037.07, 2479.87, 430, 149.59]
        },
{
            name: "Suspend",
            data: [8600.64, 7127.31, 2160.12, 406.73, 155.87]
        },
{
            name: "Dispatchers.Default",
            data: [8006.54, 6707.28, 2817.29, 723.68, 314.04]
        },
{
            name: "CompletableFuture",
            data: [8542.10, 7183.47, 3022.05, 782.12, 330.39]
        }
],
          chart: {
          height: 350,
          type: 'line',
          zoom: {
            enabled: true,
            type: "x" 
          }
        },
        dataLabels: {
          enabled: false
        },
        stroke: {
          curve: 'straight'
        },
        title: {
          text: 'Requests per second',
          align: 'left'
        },
        grid: {
          row: {
            colors: ['#f3f3f3', 'transparent'],
            opacity: 0.5
          },
        },
        xaxis: {
            type: "numeric",
            categories: [100, 1000, 10000, 50000, 100000],
            min: 0
        },
        yaxis: {
            logarithmic: true,
            min: 0
        }
        };

        const parent = document.getElementById('diagram');

        const chartDiv = document.createElement('div');
        parent.appendChild(chartDiv);

        const chart = new ApexCharts(chartDiv, options);
        chart.render();

</script>