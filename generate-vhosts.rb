#!/usr/bin/env ruby1.8

begin
  require 'rubygems'
rescue LoadError
end
require 'yaml'

CONFIG_PATH = '/etc/apache2/sites-available'

# No syntax checking whatsoever on the yaml files. You're on your own.

class Vhost

  def initialize(args)
    # This might be dangerous? I'm pretty sure we can trust whoever's
    # writing our vhost definitions :)
    args.each do |k,v|
      instance_variable_set "@#{k}", v
    end
    @type ||= 'standard'

    # We need to wrap @location in slashes, but if it's root, that gives us
    #   // or ///, so we collapse multiple sequential slashes to a single /.
    @location = "/#{@location}/"
    @location.gsub!(/\/+/,'/')

    @types = YAML.load(open("types.yml"))
  end

  def to_s
    if @types.has_key? @type
      eval("return \"#{@types[@type]}\"")
    end
  end

end


output = ""

# Default/catchall vhost.
output << <<END
<VirtualHost *:80>
  ServerAdmin webmaster@localhost

  DocumentRoot /var/www
  <Directory />
    Options FollowSymLinks
    AllowOverride None
  </Directory>
  <Directory /var/www/>
    Options Indexes FollowSymLinks MultiViews
    AllowOverride None
    Order allow,deny
    allow from all
  </Directory>

  ScriptAlias /cgi-bin/ /usr/lib/cgi-bin/
  <Directory "/usr/lib/cgi-bin">
    AllowOverride None
    Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
    Order allow,deny
    Allow from all
  </Directory>

  ErrorLog /var/log/apache2/error.log

  # Possible values include: debug, info, notice, warn, error, crit,
  # alert, emerg.
  LogLevel warn

  CustomLog /var/log/apache2/access.log combined

  Alias /doc/ "/usr/share/doc/"
  <Directory "/usr/share/doc/">
    Options Indexes MultiViews FollowSymLinks
    AllowOverride None
    Order deny,allow
    Deny from all
    Allow from 127.0.0.0/255.0.0.0 ::1/128
  </Directory>
</VirtualHost>

END

hosts = YAML.load(open("vhosts.yml"))

begin
  hosts.each do |k,v|
    vhost = Vhost.new(v.merge({'domain' => k}))
    output << vhost.to_s
  end
rescue
  exit 1 # Just return an error. We don't care what it is.
  # The initscript will smack somebody on the head and fail.
end

# Write the output file
File.open("#{CONFIG_PATH}/default",'w') do |f|
  f.puts output
end
