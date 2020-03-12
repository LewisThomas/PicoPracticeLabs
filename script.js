$(document).ready(function(){

  //params is a map
  var addParams = function(baseURL, params){
    if(!params){
      return baseURL;
    }

    var url = baseURL + '?';
    $.each(params, function(key, value){
      url += `&${key}=${value}`
    });

    return url;
  }

  //attrs is a map
  var buildEventURL = function(eci, eid, domain, type, attrs){
    var baseURL =  `${config.protocol}${config.server_host}/sky/event/${eci}/${eid}/${domain}/${type}`;
    return addParams(baseURL, attrs)
  }

  //params is a map
  var buildQueryURL = function(eci, rid, funcName, params){
    var baseURL =  `${config.protocol}${config.server_host}/sky/cloud/${eci}/${rid}/${funcName}`;
    return addParams(baseURL, params);
  }

  var retrieveCurrentTemp = function(){
    $.ajax({
      url: buildQueryURL(config.default_eci, config.temp_store_rid, config.temperature_func),
      dataType: "json",
      success: function(json){
        console.log(json);
        var mostRecent = json[json.length - 1];
        var html = `<p>${mostRecent.temperature}F</p><p>Recorded at: ${mostRecent.timestamp}</p>`
        var newTimestamp = (new Date()).toISOString();
        html += `<p>Successfully retrieved at: ${newTimestamp}</p>`
        $("#currentTemp").html(html)
      },
      error: function(error){
        console.error(error);
      }
    });
  };//end retrieveCurrentTemp

  var drawChart = function(){
    //retrieve the data
    $.ajax({
      url: buildQueryURL(config.default_eci, config.temp_store_rid, config.temperature_func),
      dataType: 'json',
      success: function(json){
        //retrieve the 10 most recent logs. If the array doesn't have 10 values, all values are returned.
        var toDisplay = json.slice(-10);
        console.log(toDisplay)
        var dataArray = toDisplay.map(function(tempRecording){
          console.log(tempRecording.tempF)
          console.log(tempRecording)
          return [tempRecording.timestamp, parseInt(tempRecording.temperature)]
        });

        //create the google chart data table
        var data = new google.visualization.DataTable();
        data.addColumn('string', 'timestamp');
        data.addColumn('number', 'temperature');
        data.addRows(dataArray);

        var options = { 'title': 'Most Recent Recordings (Up to 10)',
                        'chartArea': {
                          top: 55,
                          height: '40%',
                          width: '50%'
                        }
                      };
        console.log(data)
         var chart = new google.visualization.LineChart(document.getElementById('tempChart'));

         chart.draw(data, options);
      },
      error: function(error){
        console.error(error);
      }
    });
  };//end drawChart

  var setViolationLogs = function(){
    $.ajax({
      url: buildQueryURL(config.default_eci, config.temp_store_rid, config.violation_func),
      dataType: "json",
      success: function(json){
        console.log(json);
        var violations = json.reverse();
        var html = "";
          //console.log(violations)
          violations.forEach(function (violation) {

              console.log("violation: ", violation)
              console.log("temperature", violation.temperature)
          html += `<p>Violation at ${violation.timestamp} with temperature ${violation.temperature}F</p>`;
        });
        $("#violationLogs").html(html)
      },
      error: function(error){
        console.error(error);
      }
    });
  };//end violationLogs



  //END FUNCTION DECLARATIONS




  //load initial data
  retrieveCurrentTemp();
  setViolationLogs();

  //load the google chart api
  google.charts.load('current', {'packages':['corechart']});
  google.charts.setOnLoadCallback(drawChart);

  //BEGIN BUTTON SETUP
  $('#tempRefresh').click(function(e){
    e.preventDefault();
    retrieveCurrentTemp();
  });

  $('#chartRefresh').click(function(e){
    e.preventDefault();
    drawChart();
  });

  //END BUTTON SETUP


});
