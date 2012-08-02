This is an MCollective application file which allows mcollective to generate a provisioning requisition for OpenNMS network management system.

**PREREQUISITES**

1. A running OpenNMS server with version >=1.10.0 (There was a bug in earlier releases which would cause duplicate nodes to be provisioned)
2. A decent understanding of how OpenNMS provisioning works in the OpenNMS web interface.
3. A working marionette collective installation
4. Configured OpenNMS provisioning groups to which the provisioned nodes will be assigned.
5. Access from your mcollective client to the OpenNMS ReSTful API (i.e. Access to the OpenNMS web interface).

**IMPORTANT!!!**

If you have *EXISTING* nodes provisioned via the OpenNMS web interface, you will need to tell puppet/mcollective about the existing foreign ID. 

This is easily done by going through the web interface to the admin and editing a provisioning group. Each node will typically have a 
foreign id which is about 13 digits long. Place variables as described below in the "node" definition for your puppet manifest and 
ensure you are using the YAML based facts for mcollective as detailed at http://projects.puppetlabs.com/projects/mcollective-plugins/wiki/FactsFacterYAML

**EXAMPLE PUPPET CONFIG**

    node "mynode.mycompany.tld" {
        $onms_source = "Web Servers"             ## The OpenNMS provisioning group that this node should be a part of
        $onms_services = "ICMP,SNMP"             ## The comma separated list of services which should be monitored
        $onms_categories = "Production,Servers"  ## A comma separated list of categories to assign this node to in OpenNMS
        $onms_primary_interface = "eth0"         ## The interface which should be used for monitoring this node
        $onms_label = "${hostname}.recur"        ## The label which should be used to identify this node in OpenNMS
        $onms_foreign_id = "1327619063628"       ## Specify a foreign ID to use instead of the FQDN

        . . .
    }

**USAGE**

    mco provision --url "http://opennms.mycompany.com/opennms/rest/" --user admin --pass myadminpass

    --url   : The URL for the rest API of your OpenNMS server.
    --user  : The username with which we will authenticate to the OpenNMS server
    --pass  : The password with which we will authenticate to the OpenNMS server

You can avoid having to specify the URL, Username, and Password on the command-line using a personal ~/.mcollective client configuration and
adding the following configuration options

    plugin.provision.url=http://opennms.mycompany.com/opennms/rest/
    plugin.provision.user=admin
    plugin.provision.pass=admin

All other mco filters work as expected.


**EXAMPLE COMMAND LINES**

*1. Provision all nodes which have the "ssh" class applied.*

    mco provision --url "http://opennms.mycompany.com/opennms/rest/" --user admin --pass myadminpass -C ssh

*2. Provision all nodes which have FQDNs containing "web"*

    mco provision --url "http://opennms.mycompany.com/opennms/rest/" --user admin --pass myadminpass -F fqdn="/web/"

*3. Provision ALL nodes*

    mco provision --url "http://opennms.mycompany.com/opennms/rest/" --user admin --pass myadminpass


**INSTALLATION**

Place this in the mcollective *application* directory and that is all it takes:

For example, on Debian based systems, place it in */usr/share/mcollective/plugins/mcollective/application/*
