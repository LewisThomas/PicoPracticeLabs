ruleset wovyn_base {
  meta {
    
    use module twilio_keys
    
    use module sensor_profile
    
    use module io.picolabs.wrangler alias wrangler
    
    use module twilio_module alias twilio
      with account_sid = keys:twilio{"account_sid"}
           auth_token = keys:twilio{"auth_token"}

    use module io.picolabs.subscription alias subscription
    
    shares __testing, print_heartbeat, print_formatted_temperature
  }
  global {
    print_heartbeat = function() {
      ent:heartbeat
    }
    
     //receiving_number = keys:twilio{"receiving_number"}
     sending_number = keys:twilio{"sending_number"}
     
    print_formatted_temperature = function() {
      ent:temperature
    }
    
    __testing = { "queries": [ { "name": "__testing" },
                                {"name":"print_heartbeat"},
                                {"name":"print_formatted_temperature"}],
                  "events": [{
                    "domain": "wovyn",
                    "type": "fake_heartbeat",
                    "attrs": ["temperature"]
                  },
                  {
                    "domain":"wovyn",
                    "type":"threshold_violation",
                    "attrs":["temperature"]
                  },
                  {
                    "domain":"wovyn",
                    "type":"change_number",
                    "attrs":["receiving_number"]
                  }] }
                  
    def_temperature_threshold = 85
    def_receiving_number = "+17609945971"

  }
  
  rule process_heartbeat {
    select when wovyn heartbeat
    pre {
      genericThingObj = event:attr("genericThing")
    }
    if (genericThingObj.klog("genericThing attribute: ")) then
      send_directive("this is a directive", {"body":"Rule was fired"})
    notfired {
    }
    else {
      // genericThingObj.decode();
      raise wovyn event "new_temperature_reading"
      attributes {
        "temperature": genericThingObj{["data","temperature"]}.head(){"temperatureF"},
        "timestamp": time:now()
      }
    }
    finally {
      ent:heartbeat := event:attrs
    }
  }
  
  rule debug_temperature_reading {
    select when wovyn fake_heartbeat
    always {
      raise wovyn event "new_temperature_reading"
      attributes {
        "temperature": event:attr("temperature"),
        "timestamp": time:now()
      }
    }
  }
  
  rule find_high_temps {
    select when wovyn new_temperature_reading
      pre {
        wasViolation = event:attr("temperature") > sensor_profile:get_temperature_threshold()
        message = wasViolation => "There was a temperature violation" | "There was not a temperature violation"
      }
      send_directive("Violation?", {"body":message})
      always {
        raise wovyn event "threshold_violation"
          attributes {
            "temperature":event:attr("temperature"),
            "timestamp":event:attr("timestamp")
          } if wasViolation;
          ent:temperature := event:attrs
      }
  }
  
  rule threshold_violation {
    select when wovyn threshold_violation
    foreach subscription:established().klog("Established array: ").filter(function(value) {
          value{"Tx_role"}.klog("VALUE IS") == "controller"
        }).klog("filtered array: ") setting (sub_entry)
      pre {
        //receiving_number = sensor_profile:get_receiving_number()
        eci = sub_entry{"Tx"}.klog("ECI IS BOI")
      }
      // event:send({
      // "eci":eci,
      // "eid":"temp_violation",
      // "domain":"sensor",
      // "type":"threshold_violation",
      // "attrs": {
      //   "temperature":event:attr("temperature")
      // }
      // })
      twilio:send_sms(receiving_number, sending_number, "Temperature threshold violation reached: " + event:attr("temperature") + " degrees F") setting (response)
      fired {
        ent:response := response
      }
    
  }
  
  rule change_receiving_number {
    select when wovyn change_number
    pre {
  
    }
    if event:attr("receiving_number") != "" && not event:attr("receiving_number").isnull() then
    send_directive("say", {"number": ent:receiving_number})
    fired {
      ent:receiving_number := "+" + event:attr("receiving_number")
    }
  }
  
  rule change_threshold {
    select when wovyn change_threshold
    pre {
      
    }
    if event:attr("new_threshold") != "" && not event:attr("new_threshold").isnull() then
          noop()//send_directive("say", {"threshold": ent:})
    fired {
      ent:temperature_threshold := event:attr("new_threshold")
    }
  }
  
  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    pre {
      attributes = event:attrs.klog("subcription:")
    }
    always {
      raise wrangler event "pending_subscription_approval"
        attributes attributes//.put(wrangler:myself{"name"})
    }
  }
  

}
