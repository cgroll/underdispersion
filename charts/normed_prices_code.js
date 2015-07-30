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

var dateInd = 12000;

var line = d3.svg.line()
	 .defined(function(d) { return !isNaN(d.ret); })
// .interpolate("basis")
	 .x(function(d) { return x(d.idx); })
	 .y(function(d) { return y(d.ret); });

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

var bisectDate = d3.bisector(function(d) { return d; }).left;

var vertMove = 0;

var tsdata = d3.csv("../data/normedPrices.csv", function (data) {
    
    var stockNames = d3.keys(data[0]).filter(function(key) { return key !== "idx"; });
    
    data.forEach(function(d) {
        d.idx = parseDate(d.idx);
    });
    
    var tseries = stockNames.map(function(name) {
        
        stockData = data.map(function(d) {
            return {idx: d.idx, ret: +d[name], stock: name};
        })
        return {name: name,
                values: stockData
               };
    });
	 
    var uniqueDates = data.map(function(d) {
		  return d.idx;
	 });
	 
    x.domain(d3.extent(data, function(d) { return d.idx; }));
	 
	 var stockRange = d3.max(tseries, function(c) { return d3.max(c.values, function(v) { return v.ret; }); }) - d3.min(tseries, function(c) { return d3.min(c.values, function(v) { return v.ret; }); });
	 
    y.domain([-stockRange, stockRange
				  // d3.min(tseries, function(c) { return d3.min(c.values, function(v) { return v.ret; }); }),
				  // d3.max(tseries, function(c) { return d3.max(c.values, function(v) { return v.ret; }); })
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
        .text("Log price");
	 
	 svg.append("rect")                                     // **********
        .attr("width", width)                              // **********
        .attr("height", height)                            // **********
        .style("fill", "none")                             // **********
        .style("pointer-events", "all")
        .on("mousemove", mouseclick);
	 
    var gdp = svg.selectAll(".gdp")
		  .data(tseries)
		  .enter()
		  .append("g")
		  .attr("class", "gdp")
		  .append("path")
		  .attr("class", "line")
		  .attr("d", function(d) { return line(d.values)});
	 
	 function mouseclick() {                                 // **********
        var x0 = x.invert(d3.mouse(this)[0]),
        i = bisectDate(uniqueDates, x0);
		  
		  dateInd = [];
		  if (i >= uniqueDates.length) {
				dateInd = i-1;
		  } else {
				d0 = uniqueDates[i - 1],                              // **********
				d1 = uniqueDates[i],                                  // **********
				dateInd = x(x0) - x(d0) > x(d1) - x(x0) ? i : (i-1);
		  }
		  redraw();
	 }
	 
	 function redraw() {
		  
		  gdp.transition()
				.duration(50)
				.attr("transform", function(d) {
					 var oldTransf = d3.select(this).attr("transform");
					 var nextTransf = oldTransf;
					 
					 var val = d.values[dateInd].ret;
		  			 if (!isNaN(val)) {
						  var vertMove = y(0) - y(val);
		  				  nextTransf =  "translate(" + 0 + "," + vertMove + ")";
					 };
					 return nextTransf;
				});
	 };
	 
});
