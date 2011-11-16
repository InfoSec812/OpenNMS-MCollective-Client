module MCollective
    module Agent
        class OpenNMS<RPC::Agent
            # Agent to automatically provision nodes and reports in OpenNMS
            metadata :name          => "OpenNMS RPC Agent",
                     :description   => "Generates report configurations for, and sends provisioning requests to OpenNMS",
                     :author        => "Deven Phillips",
                     :license       => "GPLv2",
                     :version       => "0.1",
                     :url           => "
                                 

            def reports_action
                validate :msg, String

                reply.data = request[:msg]
            end

            def provision_action
            end
        end
    end
end
