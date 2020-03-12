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

  var updateData = function(){
    $.ajax({
      url: buildQueryURL(config.default_eci, config.profile_rid, config.profile_func),
      dataType: 'json',
      success: function(json){
        $('#name').html(`<p>${json.name}</p>`);
        $('#location').html(`<p>${json.location}</p>`);
        $('#contact').html(`<p>${json.contact}</p>`);
        $('#threshold').html(`<p>${json.threshold}F</p>`);
      },
      error: function(error){
        //console.error(error);
      }
    });
  };//end updateData

  updateData();

  var changeData = function(attrs){
    let url = buildEventURL(config.default_eci, "changeData", "sensor", "profile_updated", attrs);
    console.log("url:",url);
    $.ajax({
      url: url,
      dataType: 'json',
      success: function(json){
        console.log(json);
        updateData();
      },
      error: function(error){
        console.error(error);
      }
    });
  };

  //run on load functions
  updateData();

  //set up buttons
  $('#setName').click(function(e){
    e.preventDefault();
    changeData({
      "new_sensor_name": $('#newName').val()
    });
  });

  $('#setLocation').click(function(e){
    e.preventDefault();
    console.log($('#newlocation').val());
    changeData({
      "new_location": $('#newlocation').val()
    });
  });

  $('#setContact').click(function(e){
    e.preventDefault();
    console.log($('#newContact').val());
    changeData({
      "new_send_to": $('#newContact').val()
    });
  });

  $('#setThreshold').click(function(e){
    e.preventDefault();
    changeData({
      "new_threshold": $('#newThreshold').val()
    });
  });
});
