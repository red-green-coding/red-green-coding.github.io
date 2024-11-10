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