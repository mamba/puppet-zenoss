# Module: zenoss
#
# Maintains configuration for SNMP monitoring through Zenoss
# see http://reductivelabs.com/trac/puppet/wiki/ExportedResources

# Class: zenoss
#
# Zenoss
class zenoss {

    # Class: zenoss::client
    #
    # Enables SNMP access for Zenoss
    class client {
	# exports these attributes to the puppetmaster database as a zenoss_host type
        @@zenoss_host { "$fqdn":
            #ensure => present,
            alias => "$hostname",
            ip => "$ipaddress",
            zenosstype => "$kernel",
            zenosscollector => "$zenosscollector",
            serialnumber => "$serialnumber",
            grouppath => ['/new'],
            systempath => ['/new'],
            zenossuri => $state ? {
                test => "http://user:pass@host:port/zport/dmd",
                integration => "http://user:pass@host:port/zport/dmd",
                production => "http://user:pass@host:port/zport/dmd",
                development => "http://user:pass@host:port/zport/dmd",
                default => "NO VALID ENVIRONMENT FOUND"
            }
       }
}

    # Class: zenoss::server
    #
    # Add this class to the host running the zenoss server
    class server {
        # run zenoss_host logic for all Zenoss_hosts stored in the puppet DB
        Zenoss_host <<| |>>
    }

}

