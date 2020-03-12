ruleset temperature_store {
  meta {
    use module io.picolabs.subscription alias subscription
    
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
  
  rule send_report {
    select when sensor report_requested
    pre {
      eci = event:attr("Tx").klog("TX WAS: ")
      relevant_sub = subscription:established().filter(function(value) {
        value{"Tx"} == eci
      })[0].klog("relevant sub is: ")
      current_temperature = current_temperature()
      Rx = relevant_sub{"Rx"}
      report_id = event:attr("report_id")
      
    }
    event:send({
      "eci":eci,
      "eid":"requested_report",
      "domain":"sensor",
      "type":"report_sent",
      "attrs":{
        "report":current_temperature,
        "Rx":Rx,
        "report_id":report_id,
        "sensor_type":"temperature_sensor"
      }
    })
    
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