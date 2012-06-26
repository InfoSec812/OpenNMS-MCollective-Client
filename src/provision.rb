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

    option  :username,
            :description    => "The OpenNMS username which we should use for accessing the ReST API",
            :arguments      => ["--onms-user USERNAME"],
            :type           => String

    option  :password,
            :description    => "Password to be used for accessing the OpenNMS server's ReST API",
            :arguments      => ["--onms-pass PASSWORD"],
            :type           => String

    option  :reqpath,
            :description    => "Path to the directory where OpenNMS requisitions are placed in order to be imported",
            :arguments      => ["--reqpath PATH"],
            :type           => String,
            :default        => "/etc/opennms/imports/pending"

    def main
        source = configuration[:source]
        time = Time.now
        
        timestamp = time.strftime("%Y-%m-%dT%H:%M:%S")
        
        offset = (time.utc_offset/60/60*100)
        
        baseid = (time.to_f*1000).to_i
        
        puts "<model-import xmlns=\"http://xmlns.opennms.org/xsd/config/model-import\" date-stamp=\"%s%+05d\" last-import=\"%s%+05d\" foreign-source=\"%s\">\n" % [timestamp, offset, timestamp, offset, source]
        
        util = rpcclient("rpcutil")
        util.progress = false
        
        util.inventory do |t, resp|
            facts = resp[:data][:facts]
            identity = facts['puppetHostName']
            ethAddr = facts['ipaddress_eth0']
            foreign-source = "default"
            
            if facts['onms-source']
                foreign-source = facts['onms-source']
                
            end
                       
            baseid = baseid+1
            
            puts "\t<node node-label=\"%s\" foreign-id=\"%d\" >\n" % [identity, baseid]
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
