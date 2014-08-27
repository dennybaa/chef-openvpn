class << self; include OpenvpnHelpers; end

# setup each client_config
openvpn_process :client_configs do
  config_name = self.conf_name
  config = self.conf

  # user_name required for given vpn server/config
  user_name = config[:user_name]

  if config[:data_bag]
    keys = data_bag_item(config[:data_bag], user_name)

    file "/etc/openvpn/#{config_name}/#{config_name}-ca.crt" do
      content keys['ca'].join("\n")
      owner "root"
      group "openvpn"
      mode 00640
    end

    file "/etc/openvpn/#{config_name}/#{user_name}.crt" do
      content keys['crt'].join("\n")
      owner "root"
      group "openvpn"
      mode 00640
    end

    file "/etc/openvpn/#{config_name}/#{user_name}.key" do
      content keys['key'].join("\n")
      owner "root"
      group "openvpn"
      mode 00600
    end
  elsif !config[:autopki] && !config[:autopki][:enabled]
    cookbook_file "/etc/openvpn/#{config_name}-#{user_name}-ca.crt" do
      source "#{config_name}-ca.crt"
      owner "root"
      group "openvpn"
      mode 00640
      cookbook config[:file_cookbook] if config[:file_cookbook]
    end

    if config[:auth][:type] == "cert" || config[:auth][:type] == "cert_passwd"
      cookbook_file "/etc/openvpn/#{config_name}-#{user_name}.crt" do
        source "#{config_name}-#{user_name}.crt"
        owner "root"
        group "openvpn"
        mode 00640
        cookbook config[:file_cookbook] if config[:file_cookbook]
      end

      cookbook_file "/etc/openvpn/#{config_name}-#{user_name}.key" do
        source "#{config_name}-#{user_name}.key"
        owner "root"
        group "openvpn"
        mode 00600  # not group or others accesible
        cookbook config[:file_cookbook] if config[:file_cookbook]
      end
    end
  end

  # Use route-up script
  if config[:use_route_up]
    script_erb = config[:route_up_script] || "route-up.sh.erb"

    template "/etc/openvpn/#{config_name}/route-up.sh" do
      source script_erb
      owner 'root'
      group 'root'
      mode  00755
      variables(:config_name => config_name, :config => config)
      cookbook config[:route_up_cookbook] if config[:route_up_cookbook]
      notifies :reload, "service[openvpn]"
    end
  end

  template "/etc/openvpn/#{config_name}-#{user_name}.conf" do
    source "client.conf.erb"
    owner "root"
    group "openvpn"
    mode 00640
    notifies :restart, "service[openvpn]"
    variables(:config_name => config_name, :config => config, :user_name => config[:user_name])
  end
end
