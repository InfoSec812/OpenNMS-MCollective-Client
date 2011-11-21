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
    def updateKscReports(reportData)
      
    end
end

Hash reportData 
nodes.each do |node|
    facts = node[:data][:facts]
    if (facts==nil)
      printf("Error on facts")
    else
      nodeReports = facts['onmsReports'] ;
      if (nodeReports!=nil)
        nodeReports.split(",").each do |reportConfig|
          reportSettings = reportConfig.split("|")
          reportName = reportSettings[0]
          if (reportData[reportName]!=nil)
          else
            reportData[reportName] = Hash.new(nil) ;
            reportData[reportName]['node'] = facts['hostname']
            reportData[reportName]['']
          end
        end
      end
    end
end

reportUpdater = Report.new(nil, nil)
reportUpdater.updateKscReports(reportData)