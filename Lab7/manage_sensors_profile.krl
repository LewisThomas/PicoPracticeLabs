ruleset manage_sensors_profile {
  meta {
    shares __testing
    
    use module twilio_keys
    
    use module twilio_module alias twilio
      with account_sid = keys:twilio{"account_sid"}
           auth_token = keys:twilio{"auth_token"}
    
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ ] }
                  
    def_receiving_number = "17609945971"
    def_threshold = 90
    def_location = "PicoLabs"
  }
  
  
  
  rule threshold_violation {
    select when sensor threshold_violation
    pre {

    }
    twilio:send_sms(ent:receiving_number.defaultsTo("+" + def_receiving_number), 
                    "Temperature threshold violation reached: " + event:attr("temperature") + " degrees F") setting (response)
    always {
    }
  }
}

