class MCollective::Application::Provision<MCollective::Application
    description "An application which generates an OpenNMS provisioning requisition based on command-line arguments, filters, and node facts"

    option  :source,
            :description    => "The foreign source ID for this requisition, defaults to \"default\"",
            :arguments      => ["--source SOURCE"],
            :default        => "default",
            :type           => String

    option  :categories,
            :description    => "A comma separated list of categories to assign to the selected nodes, defaults to \"Development\"",
            :arguments      => ["--categories CATEGORIES"],
            :default        => "Development",
            :type           => String

    option  :services,
            :description    => "A comma separated list of services which should be monitored for the selected nodes, defaults to ICMP and SNMP",
            :arguments      => ["--services SERVICES"],
            :default        => "ICMP,SNMP",
            :type           => String

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
        
        source = configuration[:source]
        time = Time.now
        
        timestamp = time.strftime("%Y-%m-%dT%H:%M:%S")
        
        offset = (time.utc_offset/60/60*100)
        
        url = configuration[:url]
        user = configuration[:user]
        pass = configuration[:pass]
        api = Faraday.new(:url => url) do |faraday|
            faraday.request     :url_encoded
            faraday.adapter     Faraday.default_adapter
            faraday.response    :logger
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
            
            if facts['onms-source']
                foreign_source = facts['onms-source']
            end
            
            if source.index(foreign_source)==nil
                source << foreign_source
            end
            
            if facts['onms-label']
                node_label = facts['onms-label']
            end
            
            foreign_id = facts['fqdn']
            
            if facts['onms-foreign-id']
                foreign_id = facts['onms-foreign-id']
            end
            
            response = api.get "requisitions/"+URI::encode(foreign_source)
            xmlData = response.body
            if xmlData != nil
                puts "\n\n"+xmlData+"\n\n"
            else
                puts "\n\nXML data is nil\n\n"
            end
            doc = Nokogiri::XML(xmlData)
            nodes = doc.xpath("//*[@node-label]")
            nodes.each do |node|
                puts "DEBUG: "+node.attr('node-label').strip+" -- "+node_label+"\n"
                if (node.attr('node-label').strip==node_label)
                    puts "Found the node label and foreign-id\n"
                    foreign_id = node.attr('foreign-id').strip
                end
            end
            
            node = "<node xmlns=\"http://xmlns.opennms.org/xsd/config/model-import\" node-label=\""+node_label+"\" foreign-id=\""+foreign_id+"\" building=\""+foreign_source+"\">"
            node << "<interface ip-addr=\""+ethAddr+"\" descr=\"eth0\" status=\"1\" snmp-primary=\"P\">"
            
            configuration[:services].split(',').each do |service|
                node << "<monitored-service service-name=\""+service+"\"/>"
            end
            
            node << "</interface>"
            
            configuration[:categories].split(',').each do |category|
                node << "<category name=\""+category+"\"/>"
            end
            
            node << "</node>"
            
            restPath = "requisitions/"+URI::encode(foreign_source)+"/nodes"
            puts "\n\nNODE XML\n"+node+"\n\n"

            postResponse = api.post do |req|
                req.url restPath
                req.headers['Content-Type'] = 'application/xml'
                req.body = node
            end
            puts "\n\nPOST RESULT\n"+postResponse.body+"\n\n"
            ## TODO: Post the NODE XML to the OpenNMS ReST API for addition to the requisition
        end
        
        # Iterate over the updated sources and tell OpenNMS to import the changes
        sources.each do |source|
            uri = "requisitions/"+source+"/import?rescanExisting=false"
            putResp = api.put uri
            puts "\n\nPUT RESPONSE\n"+putResp+"\n\n"
        end
    end
end
