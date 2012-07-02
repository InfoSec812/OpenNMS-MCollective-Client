class MCollective::Application::Provision<MCollective::Application
    description "An application which generates an OpenNMS provisioning requisition based on command-line arguments, filters, and node facts"

    option  :url,
            :description    => "The URL for the OpenNMS server's ReST API",
            :arguments      => ["--url ONMSURL"],
            :type           => String

    option  :user,
            :description    => "The OpenNMS username which we should use for accessing the ReST API",
            :arguments      => ["--user USERNAME"],
            :type           => String

    option  :pass,
            :description    => "Password to be used for accessing the OpenNMS server's ReST API",
            :arguments      => ["--pass PASSWORD"],
            :type           => String

    option  :debug,
            :description    => "Show what actions would be taken, but do not actually perform the actions",
            :arguments      => ["--debug"],
            :type           => :bool,
            :default        => false

    def validate_configuration(configuration)
        unless (configuration[:user] && configuration[:pass] && configuration[:url])
            raise "You must specify server connection information so that requisitions can be sent to the API"
        end
    end

    def main
        validate_configuration(configuration)
        
        require 'faraday'
        require 'nokogiri'
        require 'json'
        require 'open-uri'
        time = Time.now
        
        timestamp = time.strftime("%Y-%m-%dT%H:%M:%S")
        
        offset = (time.utc_offset/60/60*100)
        
        debug = false
        if configuration[:debug]
            debug = true
        end

        url = configuration[:url]
        user = configuration[:user]
        pass = configuration[:pass]

        api = Faraday.new(:url => url) do |faraday|
            faraday.request     :url_encoded
            faraday.adapter     Faraday.default_adapter
        end
        if debug
            api = Faraday.new(:url => url) do |faraday|
                faraday.request     :url_encoded
                faraday.adapter     Faraday.default_adapter
                faraday.response    :logger
            end
        end
        api.basic_auth user, pass
        
        sources = Array.new
        
        util = rpcclient("rpcutil")
        util.progress = false
        
        # Iterate over the mcollective node responses
        util.inventory do |t, resp|
            facts = resp[:data][:facts]
            identity = facts['puppetHostName']
            ethAddr = facts['ipaddress_eth0']
            foreign_source = "default"
            node_label = facts['fqdn']
            if facts['onms-categories']
                categories = facts['onms-categories'].split(',')
            else
                categories = "Development".split(',')
            end
                        
            if facts['onms-services']
                services = facts['onms-services'].split(',')
            else
                services = "ICMP,SNMP".split(',')
            end
            
            if facts['onms-source']
                foreign_source = facts['onms-source']
            end
            
            if sources.index(foreign_source)==nil
                sources.push(foreign_source)
            end
            
            if facts['onms-label']
                node_label = facts['onms-label']
            end
            
            foreign_id = facts['fqdn']
            
            if facts['onms-foreign-id']
                foreign_id = facts['onms-foreign-id']
            end
            
            response = api.get "requisitions/"+URI::encode(foreign_source)
            if response.status == 200
                xmlData = response.body
                if xmlData == nil
                    puts "\n\nXML data is nil\n\n"
                end
                doc = Nokogiri::XML(xmlData)
                nodes = doc.xpath("//*[@node-label]")
                nodes.each do |node|
                    if (node.attr('node-label').strip==node_label)
                        if debug
                            puts "DEBUG: Found existing node: "+node.attr('foreign-id').strip+"\n"
                        end
                        foreign_id = node.attr('foreign-id').strip
                    end
                end
            else 
                puts "ERROR: HTTP GET response was "+response.status+".\n"
                if response.body
                    puts "\n\n"+response.body+"\n\n"
                end
            end
            
            node = "<node xmlns=\"http://xmlns.opennms.org/xsd/config/model-import\" node-label=\""+node_label+"\" foreign-id=\""+foreign_id+"\" building=\""+foreign_source+"\">"
            node << "<interface ip-addr=\""+ethAddr+"\" descr=\"eth0\" status=\"1\" snmp-primary=\"P\">"
            
            services.each do |service|
                node << "<monitored-service service-name=\""+service+"\"/>"
            end
            
            node << "</interface>"
            
            categories.each do |category|
                node << "<category name=\""+category+"\"/>"
            end
            
            node << "</node>"
            
            restPath = "requisitions/"+URI::encode(foreign_source)+"/nodes"

            if debug
                puts "DEBUG: Sending request to "+restPath+"\n\n"
                puts node+"\n\n"
            end
            
            if (!(debug))
                postResponse = api.post do |req|
                    req.url restPath
                    req.headers['Content-Type'] = 'application/xml'
                    req.body = node
                end
                if postResponse.status!=200
                    puts "ERROR: HTTP Status code was "+postResponse.status+".\n"
                end
            else
                puts "DEBUG: Sending node request to "+url+restPath+".\n\n"
                puts node+"\n\n"
            end
        end
        
        # Iterate over the updated sources and tell OpenNMS to import the changes
        sources.each do |src|
            uri = "requisitions/"+URI::encode(src)+"/import?rescanExisting=false"
            if (!(debug))
                putResp = api.put uri
                if putResp.status!=200
                    puts "ERROR: PUT response was "+putResp.status+".\n"
                end
            else
                puts "DEBUG: Sending import request to "+url+uri+".\n\n"
            end
        end
    end
end
