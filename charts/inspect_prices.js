// define margins
var margin = {top: 20, right: 80, bottom: 30, left: 150};

// graphics size without axis
var width = 960 - margin.left - margin.right;
var height = 500 - margin.top - margin.bottom;

var svg = d3.select("body").append("svg")
    .attr("width", width + margin.left + margin.right)
    .attr("height", height + margin.top + margin.bottom)
    .append("g")
    .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

// axes scales
var x = d3.time.scale()
    .range([0, width]);

var y = d3.scale.linear()
    .range([height, 0]);

var xAxis = d3.svg.axis()
    .scale(x)
    .orient("bottom");

var yAxis = d3.svg.axis()
    .scale(y)
    .orient("left")
    .ticks(5);

// parse dates and remove missing values
var parseDate = d3.time.format("%Y-%m-%d").parse;

var line = d3.svg.line()
    .defined(function(d) { return !isNaN(d.gdp); })
    // .interpolate("basis")
    .x(function(d) { return x(d.idx); })
    .y(function(d) { return y(d.gdp); });

var tsdata = d3.csv("../underdispersion_data/normedPrices.csv", function (data) {
    
    var countryNames = d3.keys(data[0]).filter(function(key) { return key !== "idx"; });
    
    data.forEach(function(d) {
        d.idx = parseDate(d.idx);
    });
    
    var tseries = countryNames.map(function(name) {
        
        countryData = data.map(function(d) {
            return {idx: d.idx, gdp: +d[name], country: name};
        })
        return {name: name,
                values: countryData
               };
    });
    
    x.domain(d3.extent(data, function(d) { return d.idx; }));
    
    y.domain([
        d3.min(tseries, function(c) { return d3.min(c.values, function(v) { return v.gdp; }); }),
        d3.max(tseries, function(c) { return d3.max(c.values, function(v) { return v.gdp; }); })
    ]);
    
    svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + height + ")")
        .call(xAxis);
    
    svg.append("g")
        .attr("class", "y axis")
        .call(yAxis)
        .append("text")
        .attr("transform", "rotate(-90)")
        .attr("y", 6)
        .attr("dy", ".71em")
        .style("text-anchor", "end")
        .text("GDP in bn $");
    
    var gdp = svg.selectAll(".gdp")
        .data(tseries)
        .enter()
        .append("g")
        .attr("class", "gdp")
        .append("path")
        .attr("class", "line")
        .attr("d", function(d) { d.line = this; return line(d.values); });
    
    // .on("mouseover", onmouseover)
    // .on("mouseout", onmouseout);
    
    // function onmouseover(d, i) {
    //     var currClass = d3.select(this).attr("class");
    //     d3.select(this).attr("class", "current");
    //     var blurb = '<h2>' + this.__data__.name + '</h2>';
    //     d3.selectAll("h2").text(this.__data__.name)
    //     // d3.select("#default-blurb").hide();
    //     d3.select("#blurb-content").html(blurb);
    // }
    
    // function onmouseout(d, i) {
    //     d3.select(this).attr("class", "line");
    //     d3.selectAll("h2").text("World")
    // }
    
    // voronoi
    var voronoi = d3.geom.voronoi()
        .x(function(d) { return x(d.idx); })
        .y(function(d) { return y(d.gdp); })
        .clipExtent([[-margin.left, -margin.top], [width + margin.right, height + margin.bottom]]);
    
    var voronoiGroup = svg.append("g")
        .attr("class", "voronoi");
    
    voronoiGroup.selectAll("path")
        .data(voronoi(d3.nest()
                      .key(function(d) { return x(d.idx) + "," + y(d.gdp); })
                      .rollup(function(v) { return v[0]; })
                      .entries(d3.merge(tseries.map(function(d) { return d.values; })))
                      .map(function(d) { return d.values; })
                      .filter(function(d) { return !isNaN(d.gdp) })))
        .enter().append("path")
        .attr("d", function(d) { return "M" + d.join("L") + "Z"; })
        .datum(function(d) { return d.point; })
        .on("mouseover", mouseover)
        .on("mouseout", mouseout);
    
    function mouseover(d) {
        svg.selectAll("path").filter(function(c) { return c.name == d.country})
            .attr("class", "city--hover")
        d3.selectAll("h2").text(d.country)
        // gdp[0].filter(function(c) { return c.__data__.name == d.country })
        //     d3.select(d.country.line).classed("city--hover", true);
        //     d.country.line.parentNode.appendChild(d.country.line);
        //     // focus.attr("transform", "translate(" + x(d.date) + "," + y(d.value) + ")");
        //     // focus.select("text").text(d.city.name);
    }
    
    function mouseout(d) {
        svg.selectAll("path").filter(function(c) { return c.name == d.country})
            .attr("class", "line")
        d3.selectAll("h2").text("World")
        // d3.select(d.country.line).classed("city--hover", false);
        // focus.attr("transform", "translate(-100,-100)");
    }
    
    
});
