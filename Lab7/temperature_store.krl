ruleset temperature_store {
  meta {
    shares __testing, inrange_temperatures, temperatures, threshold_violations, current_temperature
  }
  global {
    __testing = { "queries": [ { "name": "__testing" },
                                {"name":"inrange_temperatures"},
                                {"name":"temperatures"},
                                {"name":"threshold_violations"},
                                {"name":"current_temperature"}],
                  "events": [ {
                      "domain":"sensor",
                      "type":"reading_reset"
                  }
                    ] }
  
    temperatures = function() {
      ent:temperature_readings
    }
    
    threshold_violations = function() {
      ent:temp_threshold_violations
    }
    
    inrange_temperatures = function() {
      ent:temperature_readings.difference(ent:temp_threshold_violations)
    }
    
    current_temperature = function() {
      ent:temperature_readings[ent:temperature_readings.length() - 1].defaultsTo({"timestamp": "No available reading", "temperature":"No available reading"})
     .klog("tempArray value: ");
     }
    
    
    
  }
  
  rule collect_temperatures {
    select when wovyn new_temperature_reading
      pre {
        stamped_temperature = {}.put({"timestamp": event:attr("timestamp"), "temperature":event:attr("temperature")})
        //temperature_readings = ent:temperature_readings
      }
      noop()
      fired {
        //ent:temperature_readings := temperature_readings;
        
        //ent:temperature_readings{[timestamp]} := temperature;
        ent:temperature_readings := ent:temperature_readings.defaultsTo([]).append([stamped_temperature]) 
        //:= ent:temperature_readings.defaultsTo({}).put([timestamp], temperature)
      }
  }
  
  rule collect_threshold_violations {
    select when wovyn threshold_violation
    pre {
        stamped_temperature = {}.put({"timestamp": event:attr("timestamp"), "temperature":event:attr("temperature")})
    }
    noop();
    fired {
        ent:temp_threshold_violations := ent:temp_threshold_violations.defaultsTo([]).append([stamped_temperature]) 
    }
  }
  
  rule clear_temperatures {
    select when sensor reading_reset
    pre {
      
    }
    noop()
    fired {
      ent:temperature_readings := [];
      ent:temp_threshold_violations := []
    }
  }
}