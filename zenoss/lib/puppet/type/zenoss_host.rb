#########################################################################
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Puppet Type: Zenoss_host
#
#
Puppet::Type.newtype(:zenoss_host) do
    @doc = "Manages hosts in Zenoss."

## there are two possibilities to run this type:
#   1. ensurable: uses exists?, create and destroy in the provider and the ensure => present property in the manifest
#       Destroy is not implementd as we don't want to delete devices.
#       This leads to problems if you manually remove a device in zenoss:
#           The zenoss_host is still marked as present and thus does not get readded
#           Setting the property ensure => absent will not help as exists? returns false (because the device was deleted)
#               puppet decides that everything is ok (the zenoss_host is already absent) and the property ensure stays 'present'
#   2. custom property: the property 'inzenoss' always tries to add a host to zenoss
#       Thus automatically removing a device from zenoss is not an option and if it is removed manually this is detected and the device gets readded.
#
#   => 1. supports the whole livecycle and expects that there are no manual manipulations
#   => 2. supports only adding a device and allows manual manipulations 

#    ensurable

    newproperty(:inzenoss) do
        
        desc "Assures the device is added to zenoss."

        newvalue :notavailable
        newvalue :available do
            debug("==> adding host to zenoss ...")
            result = provider.loadDevice(resource[:ip],
                            resource[:zenosstype])
            debug("<== done.")
        end
    
        defaultto :available # should value
    
        def retrieve
            debug("==> check if host is in zenoss ...")
            debug("    name: '#{resource[:name]}'")
            debug("    ip: '#{resource[:ip]}' (mapped from Facter.ipaddress in manifest)")
            debug("    alias: '#{resource[:alias]}'")
            #debug("    zenossuri: '#{resource[:zenossuri]}'") # do not log by default as it contains the zenoss password
            debug("    zenosstype: '#{resource[:zenosstype]}' (deducted (munge in type) from Facter.kernel (uname -s))")
            debug("    zenosscollector: '#{resource[:zenosscollector]}' mapped from Facter.zenosscollector in manifest")
            debug("    serialnumber: '#{resource[:serialnumber]}' mapped from Facter.serialnumber in manifest")
            debug("    grouppath: '#{resource[:grouppath]}' specified in mainfest")
            debug("    systempath: '#{resource[:systempath]}' specified in mainfest")
            debug("")
            # if we don't find the device with the name
            # it might just not be renamed yet, thus we also search for the IP as name.
            unless provider.existsDevice(resource[:name], resource[:zenosstype])
                result = provider.existsDevice(resource[:ip], resource[:zenosstype])
            else
                result = true
            end 
            debug("<== result: #{result}.")
            return result ? :available : :notavailable
        end
    end

    newparam(:zenosscollector) do
        # validation missing
        desc "The collector used by Zenoss to collect the data for this device."
    end

    newparam(:zenossuri) do
        # validation missing
        desc "The Zenoss DMD URIi, eg. 'http://user:pwd@localhost:8080/zport/dmd'."
    end

    newparam(:serialnumber) do
        # validation missing
        desc "The serial number of the host that should be added."
    end

    newparam(:grouppath) do
        # validation missing
        desc "The Zenoss group path."
    end

    newparam(:systempath) do
        # validation missing
        desc "The Zenoss system path."
    end

    newparam(:name) do
        desc "The name of the host."
        isnamevar
        # validation missing
    end

    newparam(:ip) do
        # validation missing
        desc "The IP address of the host."
    end

    newparam(:zenosstype) do
        desc "The host type (kernel fact)."
        # validation missing
 
        # munge values, depending on the kernel of the system 
        # if zenosstype depends on more than just the kernel 
        #    this should be solved with a custom fact.
        munge do |value|
            case value
            when "Linux" 
                "/Server/Linux" 
            when "AIX"
                "/Server/AIX"
            when "SunOS"
                "/Server/Solaris"
            else
                value
            end
        end
    end

end
