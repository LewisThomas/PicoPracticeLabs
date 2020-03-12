ruleset sensor_gossip {
  meta {
    shares __testing, retrieve_temperature_logs, generateSeen, getCount,others_seen, getLastMessage
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
  }
  global {
    __testing = { "queries": [ 
                  { "name": "__testing" },
                  {"name":"retrieve_temperature_logs"},
                  {"name":"generateSeen"},
                  {"name":"others_seen"},
                  {"name":"getLastMessage"},
                  {
                    "name":"getCount"
                  }
                  ],
                  "events": [ {
                                "domain":"gossip",
                                "type":"friendly_node_subscription",
                                "attrs":["name","wellKnown_Tx"]
                              },
                              {
                                "domain":"gossip",
                                "type":"heartbeat"
                              }//,
                              //{
                                //"eci":destination_eci.klog("DESTINATION ECI"),
                                //"eid":"gossipin'",
                                //"domain":"gossip",
                                //"type":message_type,
                                //"attrs": {
                                //  "message":actualMessage.klog("ACTUAL MESSAGE IS: "),
                                //  "this_pico_id":meta:picoId
                                //}
                              //}
                              ] }
                  
    getPeerForRumor = function(others_seen) {
      //thisPicoSeen = generateSeen();
      mapToThisPicosNumber = others_seen.klog("OTHERS SEEN").map(function(value,key){
        value{meta:picoId}.defaultsTo(-1)
      }).klog("MAP FOR EACH PICO FOR THIS PICO");
      mostNeededPeer = mapToThisPicosNumber.values().sort("numeric")[0];
      mapToThisPicosNumber.filter(function(value,key) {
        value == mostNeededPeer
      })
    }
    
    getPeerForSeen = function() {
      //seen = generateSeen();
      numberOthers = ent:peers.keys().klog("PEERS KEYS").length().klog("SEEN LENGTH");
      ent:peers.keys()[random:integer(numberOthers - 1)]
    }
    
    prepareMessage = function(others_seen) {
      random:integer(1) => prepareSeenMessage(others_seen) | prepareRumorMessage(others_seen)
    }
    
    prepareSeenMessage = function(others_seen) {
      {
      "message":generateSeen(),
      "destinationPeer":getPeerForSeen().klog("The returned peer for seen was: "),
      "type":"seen"
      }.klog("PREPARE SEEN MESSAGE RETURNED")
    }
    
    generateSeen = function() {
      ent:picos_temp_logs.map(function(value,key) {
        getHighestSequence(value)
      })
    }
    
    getHighestSequence = function(messageMap) {
      messageNumbers = messageMap.keys().map(function(value) {value.split(":")[1].as("Number")}).sort("numeric").klog("MESSAGE NUMBERS: ");
      messageNumbers[0].as("Number") == 0 => 
      messageNumbers.filter(function(value) {
        (not (messageNumbers >< (value + 1)))
      })[0] | -1
    }
    
    prepareRumorMessage = function(others_seen) {
      peerId = getPeerForRumor(others_seen);
      destinationPeer = peerId.klog("PEER FOR RUMOR RETURNED");
      rumor = generateRumor(destinationPeer.values()[0]).klog("MESSAGE NUMERIC INDEX");
      {
        "message": rumor,
        "destinationPeer": destinationPeer.keys()[0],
        "type":"rumor"
      }
    }
    
    generateRumor = function(messageNumberToSend) {
      picoMessageIndex = (meta:picoId + ":" + (messageNumberToSend.as("Number") + 1)).klog("MESSAGE INDEX");
      ent:picos_temp_logs{[meta:picoId, picoMessageIndex]}.klog("RETURNED FROM GENERATE RUMOR: ")
    }
    
    

    
    
    heartbeat_interval = 5
    
    retrieve_temperature_logs = function() {
      ent:picos_temp_logs.klog("picos temp logs: ")
    }
    
    others_seen = function() {
      ent:others_seen
    }
    
    getCount = function() {
      ent:counter
    }
    
    getLastMessage = function() {
      ent:last_message_sent
    }
  }
  
  //Update this picos temperature logs every time the sensor sends a new reading
  rule on_wovyn_heartbeat {
    select when wovyn new_temperature_reading
    pre {
      messageID = meta:picoId + ":" + ent:counter.defaultsTo(0)
     
      messageContents = {
        "message_id": messageID,
        "temperature":event:attr("temperature"),
        "timestamp":event:attr("timestamp")
      }
    }
    fired {
      //ent:picos_temp_logs{[meta:picoId,messageID]} := messageContents; // This kept returning null
      ent:picos_temp_logs := ent:picos_temp_logs.defaultsTo({}).put([meta:picoId, messageID], messageContents); // This works
      ent:counter := ent:counter.defaultsTo(0) + 1
    }
  }
  
  
  //Rules to handle sending rumors and seen messages
  rule gossip_heartbeat {
    select when gossip heartbeat
    pre{
      message_vehicle = prepareMessage(ent:others_seen.klog("OTHERS SEEN WHEN CALLED"))
      destination_pico_id = message_vehicle{"destinationPeer"}.klog("MESSAGE_VEHICLE: ")
      actualMessage = message_vehicle{"message"}.klog("ACTUAL MESSAGE: ")
      message_type = message_vehicle{"type"}
      message_number = actualMessage{"message_id"}.klog("BEFORE SPLIT MESSAGE ID").split(":")[1].klog("SPLIT FOR MESSAGE NUMBER: ")
      destination_eci = ent:peers{[destination_pico_id, "Tx"]}
    } if actualMessage then
      event:send({
        "eci":destination_eci.klog("DESTINATION ECI"),
        "eid":"gossipin'",
        "domain":"gossip",
        "type":message_type,
        "attrs": {
          "message":actualMessage.klog("ACTUAL MESSAGE IS: "),
          "this_pico_id":meta:picoId
        }
      })
    fired {
      raise gossip event "update_state" attributes {
        "pico_id":destination_pico_id,
        "type":message_type,
        "message_number":message_number,
        "original_pico":actualMessage{"message_id"}.split(":")[0]
      }
    }
    finally {
      ent:last_message_sent := actualMessage;
      schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": heartbeat_interval})
    }
  }
  
  rule update_state_from_message_type {
    select when gossip update_state
    pre {
      message_type = event:attr("type")
      pico_id = event:attr("pico_id")
      message_sent_number = event:attr("message_number").klog("MESSAGE NUMBER FOR UPDATE STATE WAS:")
      current_message = ent:others_seen{[pico_id,meta:picoId]}.defaultsTo(-1);
      original_pico = event:attr("original_pico")
    }
    if (message_type == "rumor" && current_message < message_sent_number && original_pico == meta:picoId) then
    noop();
    fired {
      ent:others_seen := ent:others_seen.defaultsTo({}).put([pico_id,meta:picoId], message_sent_number.as("Number"))
    }
    
  }

//Rules for adding new peers

  
  
  
  
  
  
  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    pre {
      attributes = event:attrs.klog("subcription:")
    }
    always {
      ent:subscription_inbound := event:attrs;
      raise wrangler event "pending_subscription_approval"
        attributes attributes//.put(wrangler:myself{"name"});=
        
    
    }
  }
  
  rule get_peer_ids {
    select when wrangler subscription_added
    foreach subscription:established() setting (subscription)
    pre {
      //Tx = event:attr("_Tx").defaultsTo(event:attr("Tx")).klog("tx result: ")//.defaultsTo(event:attr("Tx"))
    }
    if (subscription{"Rx_role"}.klog("RX_ROLE: ") == "node") then
      event:send({
        "eci":subscription{"Tx"},
        "eid":"getting_info",
        "domain":"gossip",
        "type":"get_peer_id",
        "attrs":{
          "channel":subscription{"Tx"}
      }
    })
    fired {
      ent:subscription_result := event:attrs
    }
  }
  
  rule send_pico_id {
    select when gossip get_peer_id
    pre {
      id = meta:picoId;
      relevant_subscription = subscription:established().filter(function(value) {
        value{"Rx"} == event:attr("channel")
      })[0]
      tx = relevant_subscription{"Tx"}

    }
    event:send({
      "eci":tx,
      "eid":"sending_info",
      "domain":"gossip",
      "type":"new_peer_info",
      "attrs":{
        "id":id,
        "channel":event:attr("channel")
      }
    })
  }
  
  rule record_new_peer_tx {
    select when gossip new_peer_info
    pre {
    other_pico_id = event:attr("id")
    other_pico_tx = event:attr("channel")
    }
    noop();
    fired {
      ent:peers := ent:peers.defaultsTo({}).put([other_pico_id], {"Tx":other_pico_tx});
      //ent:others_seen{[other_pico_id, meta:picoId]} := -1
      ent:others_seen := ent:others_seen.defaultsTo({}).put([other_pico_id,meta:picoId], -1)
    }
  }
  /*
  rule record_subscription_id {
    select when wrangler pending_subscription
    pre {
      sub_id = event:attr("Id")
      //sensor_type = event:attr("sensor_type")
      name = event:attr("name").replace(re#TempSensor #, "")
      //substr(11) == "TempSensor " => event:attr("name").substr(11) | event:attr("name")
    }
    noop()//send_directive("PENDING_SUB", event:attrs.klog("EVENT ATTRIBUTES"))
    always {
      ent:sensors{[name, "subscription_id"]} := sub_id;
      //ent:sensors{[name,"sensor_type"]} := sensor_type
    }
  }
  */
  rule friendly_node_subscription {
    select when gossip friendly_node_subscription
    pre {
      name = event:attr("name")
      rx_role = "node"
      tx_role = "node"
      //sensor_role = event:attr("sensor_role")
      channel_type = "subscription"
      wellknown_Tx = event:attr("wellKnown_Tx")
    }
    if wellknown_Tx && name then
    noop()
    //send_directive("hey", {"wellknown":wellknown_Tx, "name":name})
    fired {
      raise wrangler event "subscription"
        attributes {
        "name":name,
        "Rx_role": rx_role,
        "Tx_role":tx_role,
        "channel_type":channel_type,
        "wellKnown_Tx":wellknown_Tx,
        "sensor_role":sensor_role
        }
        
    }
  }
  
  /**
   * Rules for receiving gossip events
   * 
   * 
   *
   * */
   
   rule react_to_seen {
     select when gossip seen
       foreach generateSeen() setting (number, pico)
        pre {
          message = event:attr("message");
          thatPicoSeen = message{[pico]}.defaultsTo(-1);
          
        }
        if number >= thatPicoSeen then
        noop()
        fired {
          messages_to_send = ent:picos_temp_logs{[pico]}.filter(function(value, key) {
            key.split(":")[1] > thatPicoSeen
          });
          
          raise gossip event "send_rumor" attributes {
            "destination_pico":event:attr("this_pico_id"),
            "messages":messages_to_send.klog("MESSAGES TO SEND")
          };
          //messageNumbersToSend.map(function(value,))
          
          raise gossip event "update_others_seen" attributes {
            "original_pico_id":event:attr("this_pico_id"),
            "number_of_pico_messages_seen":thatPicoSeen,
            "relevant_pico":pico
          }
          
        }
        
   }
   
   rule update_others_seen {
     select when gossip update_others_seen
     pre {
       pico_id = event:attr("original_pico_id")
       num_messages = event:attr("number_of_pico_messages_seen")
       relevant_pico = event:attr("relevant_pico")
     }
     if ent:others_seen{[pico_id,relevant_pico]}.defaultsTo(-1) < num_messages then
     noop()
     fired {
       ent:others_seen := ent:others_seen.defaultsTo({}).put([pico_id, relevant_pico], num_messages.as("Number"))
     }
   }
   
   rule send_rumors_from_seen {
     select when gossip send_rumor
       foreach event:attr("messages") setting (value, key)
         pre {
           
         }
         event:send({
          "eci":ent:peers{[event:attr("destination_pico"), "Tx"]}.klog("DESTINATION ECI FOR SENDING THOSE RUMORS"),
          "eid":"gossipin'",
          "domain":"gossip",
          "type":"rumor",
          "attrs": {
            "message":value
        }
      })
      fired {
        raise gossip event "update_state" attributes {
          "pico_id":event:attr("destination_pico"),
          "type":"rumor",
          "message_number":key.split(":")[1],
          "original_pico":key.split(":")[0]
        }
      }
   }
   
   rule react_to_rumor {
     select when gossip rumor
      pre {
        message_id = event:attr("message"){"message_id"}.klog("MESSAGE ID WAS: ")
        relevant_pico = message_id.split(":")[0].klog("FOUND RELEVANT PICO: ")
      }
      if (relevant_pico && message_id && event:attr("message")) then
      noop()
      fired {
        ent:picos_temp_logs := ent:picos_temp_logs.defaultsTo({}).put([relevant_pico, message_id], event:attr("message"))
      }
        
   }
  
}

