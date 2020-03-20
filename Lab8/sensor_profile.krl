ruleset sensor_profile {
  meta {
    shares __testing, get_all
    
    provides get_temperature_threshold, get_receiving_number
  }
  global {
    __testing = { "queries": [ 
                            { 
                              "name": "__testing" 
                              
                            },
                            {
                              "name":"get_all"
                            }
                            ],
                  "events": [ 
                    {
                      "domain":"sensor",
                      "type":"profile_updated"
                    },
                    {
                      "domain":"sensor",
                      "type":"attributes"
                    },
                    {
                      "domain":"test",
                      "type":"view_profile"
                    }
                    ] }
    get_temperature_threshold = function() {
      ent:temperature_threshold.defaultsTo(def_temperature_threshold)
    }
    
    get_receiving_number = function() {
      ent:receiving_number.defaultsTo(def_receiving_number)
    }
    
    get_all = function() {
      {
        "name":ent:sensor_name,
        "location":ent:current_location,
        "contact":get_receiving_number(),
        "threshold":get_temperature_threshold()
      }
    }
                  
  }
  
  rule debug_event_attributes {
    select when sensor profile_updated
    pre {
      
    }
    send_directive("attrs", event:attrs)
    fired {
      // event:attrs.klog(event:attrs);
      ent:attributes := event:attrs
    }
  }
  
  rule profile_update {
    select when sensor profile_updated
    pre {
      new_location = event:attr("new_location").defaultsTo(ent:current_location)
      new_sensor_name = event:attr("new_sensor_name").defaultsTo(ent:sensor_name)
      new_contact_number = event:attr("new_send_to").defaultsTo(ent:receiving_number)
      new_threshold = event:attr("new_threshold").defaultsTo(ent:temperature_threshold)
    }
    send_directive("attributes", ent:attributes)
    fired {
      ent:current_location := new_location;
      ent:sensor_name := new_sensor_name;
      
      raise wovyn event "change_threshold"
      attributes {"new_threshold":new_threshold};
      
      raise wovyn event "change_number"
      attributes {"receiving_number":new_contact_number};
      
      raise test event "view_profile"
      attributes {
        "location":ent:current_location,
        "sensor name":ent:sensor_name,
        "receiving number":ent:receiving_number,
        "threshold temperature":ent:tempearture_threshold
      }
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
  
  rule debug_profile_changed {
    select when test view_profile
    pre {
      
    }
    send_directive("attributes", event:attrs)
  }
}
