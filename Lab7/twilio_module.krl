ruleset twilio_module {
  meta {
    configure using account_sid = "ACf94b4ba12233105e05da6855a6fc99f5"
                    auth_token = "3ef248afab37bb234daf5bf4ce7ce1dc"
    provides
        send_sms, retrieve_message_history
  }
 
  global {
    DEFAULT_PAGE_SIZE = 1
    
    def_sending_number = +7605469321 
    
    send_sms = defaction(to, message) {
       from = def_sending_number
       base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
       http:post(base_url + "Messages.json", form = {
                "From":from,
                "To":to,
                "Body":message
            }) setting (response)
      returns response
    }
    
    retrieve_message_history = function(to, from, page_size) {
       base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>;
       http:get(base_url + "Messages.json", qs = {
                "From":from,
                "To":to,
                "PageSize":page_size.defaultsTo(0)//,
                //"Page":page_number
                //"Body":message
            })
    }
    
  }
}