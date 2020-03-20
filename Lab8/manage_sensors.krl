ruleset manage_sensors {
  meta {
    shares __testing, sensors, retrieveAllTemperatureData,children, establishedSubscriptions, getReports
    
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
  }
  global {
    __testing = { "queries": [ { "name": "__testing" },
                               {"name":"sensors"},
                               {"name":"retrieveAllTemperatureData"},
                               {"name":"children"},
                               {"name":"establishedSubscriptions"},
                               {"name":"getReports"}
                             ],
                  "events": [
                    {
                      "domain":"sensor",
                      "type":"new_sensor",
                      "attrs":["sensor_name"]
                    },
                    {
                      "domain":"collection",
                      "type":"empty"
                    },
                    {
                      "domain":"sensor",
                      "type":"ask_for_reports"
                    },
                    {
                      "domain":"sensor",
                      "type":"unneeded_sensor",
                      "attrs":["sensor_name"]
                    },
                    {
                      "domain":"sensor",
                      "type":"friendly_sensor_subscription",
                      "attrs":["name","sensor_role","wellKnown_Tx"]
                    }
                    ] }
    def_receiving_number = "17609945971"
    def_threshold = 90
    def_location = "PicoLabs"
    
    sensors = function() {
      ent:sensors
    }
    
    nameFromID = function(id) {
      "TempSensor " + id
    }
    
    nameFromSubID = function(sub_id) {
      sensor_name = ent:sensors.filter(function(v,k) {
        v{["subscription_id"]} == sub_id.klog("filtering sub ID")
        // v.klog("filtering on sensors got this")
      }).klog("filtered list: ").keys()[0];
      sensor_name
    }
    
    children = function() {
      wrangler:children()
    }
    
    getSensorPicoFromName = function(name) {
      name
    }
  
    establishedSubscriptions = function() {
      subscription:established()
    }
    
    retrieveAllTemperatureData = function() {
      subscription:established().filter(function(v,k) {
        v{"Tx_role"} == "temperature_sensor"
      }).collect(function(child) {
        nameFromSubID(child{"Id"})
      }).klog("halfway is: ")
      .map(function(value) {
          targetSubscription = value[0];
          eci = targetSubscription{"Tx"};
          wrangler:skyQuery(eci, "temperature_store","current_temperature")
      });
    }

    getReports = function() {
      ent:reports.defaultsTo([]).reverse().slice(ent:reports.length() > 4 => 4 | ent:reports.length())
    }
    
  }
  /*
  rule sensor_needed {
    select when 
  }*/
  
  
  /*
    Rules that create the sensor as a child, install the requisite rulesets into it, and then initialize its profile with default values. The sensor name is stored in the
    entity variable ent:sensors for identifying sensors by their subscription.
  */

  rule getReports {
    select when sensor ask_for_reports
    pre {
      reportID = random:uuid()
      temperatureSensors = ent:sensors
    }
    always {
      ent:reports := ent:reports.defaultsTo([]).append([{
        "report_id":reportID,
        "temperature_sensors":temperatureSensors.length(),
        "responding":0,
        "temperatures": []
      }])
      raise wrangler event "send_event_on_subs" attributes {
        "domain":"sensor",
        "type":"manager_wants_report",
        "attrs":{
          "report_id":  reportID
        },
        "Tx_role":"temperature_sensor"
      }
    }
  }

  rule receiveReport {
    select when sensor report_received
    pre {
      sensors_report = event:attr("report")
      reportID = event:attr("report_id")
    }
    always {
      ent:reports := ent:reports.map(function(report){
        report{"report_id"} != reportID => report | report.set(["responding"], report{"responding"} + 1)
                                                          .set(["temperatures"], report{"temperatures"}.append(sensors_report))
      })
    }
  }
  
  rule create_sensor {
    select when sensor new_sensor
    pre {
       new_sensor_name = event:attr("sensor_name")
       exists = ent:sensors >< new_sensor_name
    }
    if not exists
    then
    noop()
    fired {
      raise wrangler event "child_creation"
        attributes {
          "name": nameFromID(new_sensor_name),
          "color":"#ff0000",
          "sensor_name": new_sensor_name
        }
    }
  }
  
  rule install_rulesets {
    select when wrangler child_initialized
      pre {
        the_sensor_pico = {"id":event:attr("id"), "eci":event:attr("eci")}
        sensor_name = event:attrs{"sensor_name"}
      }
      if sensor_name
      then
        event:send({
            "eci":the_sensor_pico{"eci"},
            "eid":"install_ruleset",
            "domain":"wrangler",
            "type":"install_rulesets_requested",
            "attrs": {
                "rids":["temperature_store","wovyn_base","sensor_profile","io.picolabs.subscription"]
            }
          })
      fired {
        raise sensor event "new_sensor_created" attributes event:attrs;
        ent:sensors := ent:sensors.defaultsTo({});
        ent:sensors{[sensor_name]} := the_sensor_pico
      }
      
  }
  
  rule initialize_profile {
    select when wrangler child_initialized
    pre {
      sensor_name = event:attrs{"sensor_name"}
      the_sensor_pico = ent:sensors{sensor_name}.klog("sensor_pico: ")
    }
    event:send({
      "eci":the_sensor_pico{"eci"},
      "eid":"initialize_profile",
      "domain":"sensor",
      "type":"profile_updated",
      "attrs": {
        "new_location":def_location,
        "new_sensor_name":sensor_name,
        "new_threshold":def_threshold,
        "new_send_to":def_receiving_number
      }
    })
  }
  
  /*
  Create a new subscription to the initialized child
  */
  
  rule create_subscription_to_new_sensor {
    select when sensor new_sensor_created
    pre {
        the_sensor_pico = {"id":event:attr("id"), "eci":event:attr("eci")}
        sensor_name = event:attrs{"sensor_name"}
    }
    if sensor_name
    then
    noop()
    fired {
    raise wrangler event "subscription" 
    attributes {
        "name":nameFromID(sensor_name),
        "Rx_role": "controller",
        "Tx_role":"temperature_sensor",
        "channel_type":"subscription",
        "wellKnown_Tx":the_sensor_pico{"eci"}
      }
    }
  }
  
  rule record_subscription_id {
    select when wrangler subscription_added 
    pre {
      sub_id = event:attr("Id")
      name = event:attr("name").replace(re#TempSensor #, "")
      //substr(11) == "TempSensor " => event:attr("name").substr(11) | event:attr("name")
    }
    noop()
    always {
      ent:sensors{[name, "subscription_id"]} := sub_id
    }
  }
  
  /*
  Rules to handle receiving a subscription request to a new sensor not in this collection
  */
  
  rule friendly_sensor_subscription {
    select when sensor friendly_sensor_subscription
    pre {
      name = event:attr("name")
      rx_role = "controller"
      tx_role = "temperature_sensor"
      sensor_role = event:attr("sensor_role")
      channel_type = "subscription"
      wellknown_Tx = event:attr("wellKnown_Tx")
    }
    if wellknown_Tx && sensor_role == "temperature_sensor" && name then
    noop()
    //send_directive("hey", {"wellknown":wellknown_Tx, "name":name})
    fired {
      raise wrangler event "subscription"
        attributes {
        "name":name,
        "Rx_role": rx_role,
        "Tx_role":tx_role,
        "channel_type":channel_type,
        "wellKnown_Tx":wellknown_Tx
        }
        
    }
  }
  
  /*
  rule send_friendly_sensor_subscription {
    select when sensor initiate_friendly_sensor_subscription
    pre {
      name = event:attr("name")
      sensor_role = event:attr("sensor_role")
      wellknownwellKnown_Tx
    }
  }
  */
  
  /*
  Rules to handle removal of sensors 
  */
  
  rule unneeded_sensor {
    select when sensor unneeded_sensor
      pre {
      sensor_name = event:attr("sensor_name")
      //sensor_id = ent:sensors{[sensor_name,"id"]}.klog("sensor_id: ")
      subscription_id = ent:sensors{[sensor_name,"subscription_id"]}.klog("SUBSCRIPTION ID: ")
      sub_to_delete = subscription:established("Id", subscription_id.defaultsTo("invalid")).klog("ESTABLISHED ARRAY: ").head()
      
      }
      if (sub_to_delete) then
      send_directive("subscription", {"sub_id":subscription_id, "sub_filtered_array":sub_to_delete})
      fired {
        raise wrangler event "subscription_cancellation"
          attributes {"Rx":sub_to_delete{"Rx"}.klog("sub_to_delete: ")};
          
      }
  }
  
  rule remove_child_after_subscription_removed {
    select when wrangler subscription_removed
    pre {
      sub_id = event:attr("bus"){"Id"}.klog("ths ID IS BOI: ")
      sensor_name = nameFromSubID(sub_id)
      child_sensor_name = nameFromID(sensor_name)
      test = event:attrs.klog("attrs in sub removed: ")
    }
    if wrangler:children().filter(function(value) {
      value{"name"}.klog("children value name: ") == child_sensor_name.klog("event attr name: ")
    }).length() > 0 then
    send_directive("sub_removed: ", event:attrs)
    fired {
      raise wrangler event "child_deletion" 
        attributes {
          "name":child_sensor_name
          //"id":event:attr("id")
        };
    }
    finally {
      ent:sensors := ent:sensors.delete([sensor_name])
    }
  }
  
  rule collection_empty {
    select when collection empty
    always {
      ent:sensors := {}
    }
  }
}

