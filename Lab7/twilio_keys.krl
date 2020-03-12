ruleset twilio_keys {
  meta {
    key twilio {
          "account_sid": "ACf94b4ba12233105e05da6855a6fc99f5", 
          "auth_token" : "3ef248afab37bb234daf5bf4ce7ce1dc"
    }
    provides keys twilio to use_twilio, wovyn_base, manage_sensors_profile
  }
}