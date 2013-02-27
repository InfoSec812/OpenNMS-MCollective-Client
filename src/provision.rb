###########################################################################
##																	   ##
## Copyright (c) 2012, Joseph Phillips, All Rights Reserved			  ##
##																	   ##
## This software released under the terms of the Modified BSD license.   ##
## A file with the name LICENSE should have accompanied this software.   ##
## The LICENSE file contains the details of the terms of software		##
## license.															  ##
##																	   ##
###########################################################################

class MCollective::Application::Provision<MCollective::Application
	description "An application which generates an OpenNMS provisioning requisition based on command-line arguments, filters, and node facts"

	option  :url,
			:description	=> "The URL for the OpenNMS server's ReST API",
			:arguments	  => ["--url ONMSURL"],
			:default		=> " ",
			:type		   => String

	option  :user,
			:description	=> "The OpenNMS username which we should use for accessing the ReST API",
			:arguments	  => ["--user USERNAME"],
			:default		=> " ",
			:type		   => String

	option  :pass,
			:description	=> "Password to be used for accessing the OpenNMS server's ReST API",
			:arguments	  => ["--pass PASSWORD"],
			:default		=> " ",
			:type		   => String

	option  :debug,
			:description	=> "Show what actions would be taken, but do not actually perform the actions",
			:arguments	  => ["--debug"],
			:type		   => :bool,
			:default		=> false

	def main
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

		$url = " "
		$user = " "
		$pass = " "
		
		if MCollective::Config.instance.pluginconf['provision.url']
			$url = MCollective::Config.instance.pluginconf['provision.url']
		end
		
		if MCollective::Config.instance.pluginconf['provision.user']
			$user = MCollective::Config.instance.pluginconf['provision.user']
		end
		
		if MCollective::Config.instance.pluginconf['provision.pass']
			$pass = MCollective::Config.instance.pluginconf['provision.pass']
		end
		
		if debug 
			puts "DEBUG: "+$url+" | "+$user+" | "+$pass+"\n"
		end
		
		if configuration[:url].strip.length>0
			$url = configuration[:url]
		end
		
		if configuration[:user].strip.length>0
			$user = configuration[:user]
		end
		
		if configuration[:pass].strip.length>0
			$pass = configuration[:pass]
		end
		
		if debug
			puts "DEBUG: "+$url+" | "+$user+" | "+$pass+"\n"
		end
		
		unless ($url.strip.length>0 && $user.strip.length>0 && $pass.strip.length>0)
			raise "You must specify server connection information so that requisitions can be sent to the API"
		end
		
		api = Faraday.new(:url => $url) do |faraday|
			faraday.request	 :url_encoded
			faraday.adapter	 Faraday.default_adapter
		end
		if debug
			api = Faraday.new(:url => $url) do |faraday|
				faraday.request	 :url_encoded
				faraday.adapter	 Faraday.default_adapter
				faraday.response	:logger
			end
		end
		api.basic_auth $user, $pass
		
		sources = Array.new
		
		util = rpcclient("rpcutil")
		util.progress = false
		
		# Iterate over the mcollective node responses
		util.inventory do |t, resp|

			continue = true

			if debug
				puts "DEBUG: Parsing responses\n"
			end
			facts = resp[:data][:facts]
			identity = facts['puppetHostName']
			if debug
				puts "DEBUG: Identity: "+identity+"\n"
			end
			
			ethAddr = facts['ipaddress']
			if ethAddr==nil
				continue = false
				puts "ERROR: The IP address for this node is blank. Refusing to provision without a primary IP\n"
			end
			foreign_source = "default"
			node_label = facts['fqdn']
			if node_label==nil
				continue = false
				puts "ERROR: The node label for this node is blank. Refusing to provision without a node label\n"
			end
			categories = nil
			if facts['onms_categories']
				categories = facts['onms_categories'].split(',')
			else
				categories = "Development".split(',')
			end
					
			if facts['onms_services']
				services = facts['onms_services'].split(',')
			else
				services = "ICMP,SNMP".split(',')
			end
			
			if facts['onms_source']
				foreign_source = facts['onms_source']
			else
				puts "ERROR: onms_source variable not found for node '"+node_label+"', refusing to try to provision\n"
				continue = false
			end
			
			if sources.index(foreign_source)==nil
				sources.push(foreign_source)
			end
			
			if facts['onms_label']
				node_label = facts['onms_label']
			else
				puts "ERROR: onms_source variable not found for node '"+node_label+"', refusing to try to provision\n"
				continue = false
			end
			
			foreign_id = facts['fqdn']
		
			if facts['onms_foreign-id']
				foreign_id = facts['onms_foreign_id']
			end
			
			if foreign_id==nil && continue==true
				response = api.get "requisitions/"+URI::encode(foreign_source)
				if response.status == 200
					xmlData = response.body
					if debug
						puts "DEBUG: Got XML data\n\n"+xmlData+"\n\n"
					end
					if xmlData == nil
						puts "\n\nXML data is nil\n\n"
					end
					doc = Nokogiri::XML(xmlData)

					if debug
						puts "DEBUG: Loaded XML data into parser\n"
					end

					nodes = doc.xpath("//*[@node-label]")

					if debug
						puts "DEBUG: Navigating the DOM\n"
					end

					nodes.each do |node|
						if debug
							puts "DEBUG: Getting current provisioning data for: "+node.attr('node-label')+"\n"
						end
						if (node.attr('node-label').strip==node_label)
							if debug
								puts "DEBUG: Found existing node: "+node.attr('foreign_id').strip+"\n"
							end
							foreign_id = node.attr('foreign_id').strip
						end
					end
				else 
					puts "ERROR: HTTP GET response was "+response.status+".\n"
					if response.body
						puts "\n\n"+response.body+"\n\n"
					end
				end
			end

			if continue
				if debug
					puts "DEBUG: Generating XML POST body for OpenNMS\n"
				end
			
				node = "<node xmlns=\"http://xmlns.opennms.org/xsd/config/model-import\" node-label=\""+node_label+"\" foreign-id=\""+foreign_id+"\" building=\""+foreign_source+"\">"
				node << "<interface ip-addr=\""+ethAddr+"\" descr=\"eth0\" status=\"1\" snmp-primary=\"P\">"

				if debug
					puts "DEBUG: Iterating over services\n"
				end
			
				services.each do |service|
					node << "<monitored-service service-name=\""+service+"\"/>"
				end
		
				node << "</interface>"

				if debug
					puts "DEBUG: Iterating over categories\n"
				end
			
				if categories!=nil
					categories.each do |category|
					if debug
						puts "DEBUG: Adding Category: "+category+"\n"
					end
						node << "<category name=\""+category+"\"/>"
					end
				end
			
				node << "</node>"

				if debug
					puts "DEBUG: Sending POST to OpenNMS\n"
				end
			
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
					puts "DEBUG: Sending node request to "+$url+restPath+".\n\n"
					puts node+"\n\n"
				end
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
				puts "DEBUG: Sending import request to "+$url+uri+".\n\n"
			end
		end
	end
end
