#!/usr/bin/ruby

require 'mcollective'
require 'pp'
require 'xmlsimple'

include MCollective::RPC

util = rpcclient("rpcutil")
util.progress = false

nodes = util.inventory

kscReports = ''

class Report
    def title
        @title
    end
    
    def title=(title)
        @title = title
    end
    
    def id
        @id
    end
    
    def id=(id)
        @id = id
    end
    
    def show_timespan_button
        @show_timespan_button
    end
    
    def show_timespan_button=(show_timespan_button)
        @show_timespan_button = show_timespan_button
    end
    
    def show_graphtype_button
        @show_graphtype_button
    end
    
    def show_graphtype_button=(show_graphtype_button)
        @show_graphtype_button = show_graphtype_button
    end
    
    def graphs_per_line
        @graphs_per_line
    end

    def graphs_per_line=(graphs_per_line)
        @graphs_per_line = graphs_per_line
    end

    def graphs
        @graphs[]
    end

    def addGraph(graph)
        @graphs += graph
    end

    def getGraphs()
        return @graphs
    end
end

nodes.each do |node|
    facts = node[:data][:facts]
    if (facts["onmsReports"]!=nil) 
        facts["onmsReports"].split(",").each do |report|
            (repName,repType,repData) = report.split("|")
            
        end
    end
end

doc = REXML::Document.new XmlSimple.xml_out(facts, 'AttrPrefix' => true, 'RootName' => 'ReportsList')
d = ''
doc.write(d)
puts "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
puts "#{d}\n"