require 'fluent/plugin/filter'

module Fluent::Plugin
  class AddServiceProfile < Filter
    Fluent::Plugin.register_filter('add_service_profile', self)

    config_param :domain, :string
    config_param :username, :string
    config_param :ucsIp, :string

    @@tokenFile = "/tmp/token"

    def configure(conf)
      super
    end

    def filter(tag, time, record)
      bladeRegex = /sys\/chassis-\d\/blade-\d/
      message = record["message"]

      if message !~ bladeRegex
        return record
      end

      dn = message[bladeRegex,0]

      serviceProfile = getServiceProfile(dn, 1)
      record["serviceProfile"] = serviceProfile
      record
    end

    def getServiceProfile(dn, retries)
      if retries > 5
        log.error "unable to login to UCS to get service profile"
        return ""
      end

      token = getToken()

      queryBody = "<configResolveDn cookie=\"%s\" dn=\"%s\"></configResolveDn>" % [token, dn]
      response = callUcsApi(queryBody)
      profile = response[/assignedToDn="([\d\w\/-]+)"/,1]

      if profile.to_s.empty?
        log.info "login failed, retry ", retries
        File.delete(@@tokenFile)
        profile = getServiceProfile(dn, retries + 1)
      end

      return profile
    end

    def getToken()

      if File.exist?(@@tokenFile)
        token = File.read(@@tokenFile)
        return token
      end

      password = getPassword()
      fullUsername = domain + "\\" + username
      loginBody = "<aaaLogin inName=\"#{fullUsername}\" inPassword=\"#{password}\"></aaaLogin>"
      response = callUcsApi(loginBody)
      token = response[/outCookie="([\d\w\/-]+)"/,1]

      File.open(@@tokenFile, "w") do |f|
        f.write(token)
      end

      return token
    end

    def callUcsApi(body)
      uri = URI.parse("https://#{ucsIp}/nuova")
      header = {'Content-Type': 'text/xml'}

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_NONE
      request = Net::HTTP::Post.new(uri.request_uri, header)
      request.body = body

      response = https.request(request)
      response.body
    end

    def getPassword()
      File.read("/etc/password/ucsPassword").strip
    end
  end
end