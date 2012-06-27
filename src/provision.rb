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

        require 'rest_client'
        require 'nokogiri'

        source = configuration[:source]
        time = Time.now
        
        timestamp = time.strftime("%Y-%m-%dT%H:%M:%S")
        
        offset = (time.utc_offset/60/60*100)
        
        url = configuration[:url]
        urlParts = url.split('://')
        proto = urlParts[0]
        remains = urlParts[1]
        user = configuration[:user]
        pass = configuration[:pass]
        address = proto+"://"+user+":"+pass+"@"+remains
        
        puts "<model-import xmlns=\"http://xmlns.opennms.org/xsd/config/model-import\" date-stamp=\"%s%+05d\" last-import=\"%s%+05d\" foreign-source=\"%s\">\n" % [timestamp, offset, timestamp, offset, source]
        
        util = rpcclient("rpcutil")
        util.progress = false
        
        util.inventory do |t, resp|
            facts = resp[:data][:facts]
            identity = facts['puppetHostName']
            ethAddr = facts['ipaddress_eth0']
            foreign_source = "default"
            node_label = facts['fqdn']
            
            if facts['onms-source']
                foreign_source = facts['onms-source']
            end

            if facts['onms-label']
                node_label = facts['onms-label']
            end
            
            foreign_id = node_label
            
            response = RestClient.get address+"requisitions/"+foreign_source
            xmlData = response.to_str
            doc = Nokogiri::XML(xmlData)
            nodes = doc.xpath("//*[@node-label]")
            nodes.each do |node|
                if (node.attr('node-label').strip==node_label)
                    puts "Found the node label and foreign-id\n"
                    foreign_id = node.attr('foreign-id').strip
                end
            end
            
            puts "\t<node node-label=\"%s\" foreign-id=\"%s\" >\n" % [node_label, foreign_id]
            puts "\t\t<interface ip-addr=\"%s\" descr=\"eth0\" status=\"1\" snmp-primary=\"P\">\n" % [ethAddr]
           
            configuration[:services].split(',').each do |service|
                puts "\t\t\t<monitored-service service-name=\"%s\"/>" % [service]
            end
             
            puts "\t\t</interface>\n"
            
            configuration[:categories].split(',').each do |category|
                puts "\t\t<category name=\"%s\"/>\n" % [category]
            end
            
            puts "\t</node>\n"
        end
	puts "</model-import>\n"
    end
end
