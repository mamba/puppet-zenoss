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


# Puppet Provider Zenoss
#
#
Puppet::Type.type(:zenoss_host).provide(:zenoss) do 
    desc "Provider for ZenOSS.  
          http://www.zenoss.com/community/docs/howtos/send-events/
          http://www.zenoss.com/community/docs/howtos/add-device/"

    require "xmlrpc/client"

    def printmsg(msg)
        debug("==> #{msg}")
    end

    def printmsgout(msg)
        debug("<== #{msg}")
    end

#    def exists?
#        debug("")
#        debug("Call exists for #{resource[:alias]}")
#        # if we don't find the device with the name
#        # it might just not be renamed yet.
#        unless existsDevice(resource[:name], resource[:zenosstype])
#            return existsDevice(resource[:ip], resource[:zenosstype])
#        else
#            return true
#        end
#    end
#
#    def create
#        loadDevice(resource[:ip], resource[:zenosstype])
#    end
#
#    def destroy
#        # never destroy a device
#    end 

    def initialize(resources = nil)
        super
        printmsg "Called initialize."
    end

    ##
    #
    # this method checks if a given device exists in the given device path
    # it is called to check if a device was already added
    #
    def existsDevice(_devName, _devPath)
        begin
            printmsg("calling existsDevice...")
            uribase = resource[:zenossuri]
            uriext = "/Devices#{_devPath}/devices/#{_devName}"
            uri = "#{uribase}#{uriext}"
            debug("The URI: <uribase>#{uriext}")
            s = XMLRPC::Client.new2("#{uri}")
            begin
                debug("get Id: #{s.call('getId')}")
                result = true                   # device exists
                return result
            rescue XMLRPC::FaultException => fe # device does not exist
                result = false
                return result
            ensure
                printmsgout "result: #{result}"
            end
        rescue XMLRPC::FaultException => e
            err(e.faultCode)
            err(e.faultString)
        end
    end

    ##
    #
    # this method loads a device into zenoss
    #
    # The device is added with its IP adress as name.
    # This is necessary to cope with environments where no DNS server is available.
    # After the device was successfully added, we can rename it
    #
    # Ranaming has a bug in Zenoss 2.3.0, see the renameDevice method for more information.
    #
    def loadDevice(_devName, _devPath)
        begin
            info("==> Adding device '#{resource[:alias]}' to Zenoss ...")
            uribase = resource[:zenossuri]
            zenosscollector = resource[:zenosscollector]
            grouppath = resource[:grouppath]
            systempath = resource[:systempath]
            serialnumber = resource[:serialnumber]
            uriext = "/DeviceLoader"
            uri = "#{uribase}#{uriext}"
            debug("The URI: <uribase>#{uriext}")
            s = XMLRPC::Client.new2("#{uri}")
            out = s.call("loadDevice", "#{_devName}", "#{_devPath}",
                        "",         #  tag=""
                        serialnumber,  #  serialNumber=""
                        "",         #  zSnmpCommunity=""
                        161,        #  zSnmpPort=161,
                        "",         #  zSnmpVer=None
                        0,          #  rackSlot=0,
                        1000,       #  productionState=1000,
                        "Added: #{Time.now.to_s}",  #  comments="",
                        #
                        # if some of the properties hwManufacturer, hwProductNames, osManufacturer and osProductName
                        # are set, the others don't get set after a device remodel cycle.
                        # Thus, either set all of them or none, if you want to get automatically collected information
                        # you have to leave them empty.
                        #
                        "",         #  hwManufacturer="",
                        "",         #  hwProductName="",
                        "",         #  osManufacturer="",
                        "",         #  osProductName="",
                        "",         #  locationPath="",
                        grouppath,         #  groupPaths=[],
                        systempath,         #  systemPaths=[],
                        zenosscollector,  #  performanceMonitor="localhost"
                        "none",     #  discoverProto="snmp"
                        3)          #  priority=3,
                       #"")         #  REQUEST=None) # omit this to get a correct XMLRPC response!

            if out == 0
                result = "'0' => successfully added device."
                info("<== result: #{result}")
                # if the device was successuffly added, rename it.
                renameDevice(resource[:ip], resource[:zenosstype], resource[:name])
            elsif out == 1
                result = "'1' => device could not be added, may be it already exists (actually this should be error code '2' ...). May be there is something wrong with the Zenoss server."
                err("<== result: #{result}")
            else
                result = out.to_s
                err("<== result: Unknown return code: '#{result}'")
            end
        rescue XMLRPC::FaultException => e
            err("Error occurred while adding the device.")
            err("Error code:")
            err(e.faultCode)
            err("Error string:")
            err(e.faultString)
        ensure
            debug("")
        end
    end

    ##
    #
    # Renames a device
    #
    # In Zenoss version 2.3.0 is a bug in the renaming function:
    #
    # http://dev.zenoss.com/trac/ticket/4020
    #
    # The renaming works only if Zenoss was accordingly patched previously.
    #
    def renameDevice(_devName, _devPath, _newDevName)
        begin
            failmsg = "Could not rename the device, may be the current Zenoss version was not patched or is too old!"
            info("==> Rename the device #{_devName} to #{_newDevName} ...")
            uribase = resource[:zenossuri]
            uriext = "/Devices#{_devPath}/devices/#{_devName}"
            uri = "#{uribase}#{uriext}"
            debug("The URI: <uribase>#{uriext}")
            s = XMLRPC::Client.new2("#{uri}")
            out = s.call("renameDevice", "#{_newDevName}")
            debug("|| result: #{out}")
            info("<== device successfully renamed.")
            return true
        rescue RuntimeError => re
            if re.inspect =~ /HTTP-Error: 302 Moved Temporarily/
                debug("ignore 'HTTP-Error: 302 Moved Temporarily'.")
                info("<== device successfully renamed.")
                return true
            else
                err("#{failmsg}")
                err(re)
                return false
            end
        rescue Exception => e
            err("#{failmsg}")
            err("Error code:")
            err(e.faultCode)
            err("Error string:")
            err(e.faultString)
            return false
        end
    end

end
