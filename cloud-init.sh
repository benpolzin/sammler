#!/bin/bash

# create user
sudo adduser --disabled-password --gecos "" ben
sudo gpasswd -a ben sudo
sudo echo 'ben ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/cloud-init
sudo mkdir /home/ben/.ssh
sudo chmod 700 /home/ben/.ssh/
sudo chown ben:ben /home/ben/.ssh/
sudo cat > /home/ben/.ssh/authorized_keys << EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC2LdYZcjiVkdG4bmllrSoSn1AyJ1tL/6m9NHCeekqHeP5zvNc0KRcSamFRpnnv+pp2ChBLfYMCVHs1w8hbu10FxFSWnVOKCfxBVz9oBkHBRtvjlsMoHWY1Wot2aj13KrdEOysg0tRYaOH+p1rTQ+dkFSoO9KE/rfdlL2cTHfPC6ON1HaGfBoZcCd3UeIaN5PoS7G/mXatUG/m1/yLSWIC0j4w8d7QmTJXje9BnMPayAW39w4yk7L/lqtusgi2zFYZKawtUAdcqgveRBtfD+jPbrb1YO9gYIikP0Jh1kkDSim5Ay0w5PdjO3XHzxAKZ4acOvc8S0oyzcvMw/cPX/xFU5jwzaRqD1LJtkMWFU8Nh7ni71ZRmsX866Q1UJzbDNFDE/Q3MKwD1d5BkurvM3NVhqXzO6JzbOSDOLnVNY0YUSHth4xnfToITu0z95L200DA3G+D6KRnUum5JYajY6c41jwvzFdxXR25I7stHIuMOmxG+JYW/EgcZnd/j8eBMV4JhlVl5PplR+qGmhlnA1MQXdUWqej/1fMg42MMmKQ6NB64az9zFLlQ2Y5HPzDHsCnx21cVX1gFywWElpclsmukdr9VJXSzBXTi6qbk1o4llL6iMwV/WHIYSmO3Vp2PbTLuodzk9deLY/O0l+/LDYAXM3bQDLlTibKy1+udbK6PmyQ== ben@polzin.us
EOF
sudo chown ben:ben /home/ben/.ssh/authorized_keys
sudo sed -i -e '/^PermitRootLogin/s/^.*$/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i -e '$aAllowUsers ben' /etc/ssh/sshd_config
sudo restart ssh
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw enable

# Add Elastic GPG Key and repositories including Oracle Java 8. Run installs
wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

echo "deb https://packages.elastic.co/elasticsearch/2.x/debian stable main" | sudo tee -a /etc/apt/sources.list.d/elasticsearch-2.x.list
echo "deb https://packages.elastic.co/logstash/2.3/debian stable main" | sudo tee -a /etc/apt/sources.list
echo "deb http://packages.elastic.co/kibana/4.5/debian stable main" | sudo tee -a /etc/apt/sources.list
echo "deb https://packages.elastic.co/beats/apt stable main" |  sudo tee -a /etc/apt/sources.list.d/beats.list
sudo add-apt-repository -y ppa:webupd8team/java
sudo apt-get -y update
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
sudo apt-get -y install oracle-java8-installer
sudo apt-get -y install elasticsearch
sudo apt-get -y install kibana
sudo apt-get -y install logstash
sudo apt-get -y install filebeat
sudo /opt/kibana/bin/kibana plugin --install elastic/sense

# Install nginx to use as reverse proxy
sudo apt-get -y install nginx apache2-utils
sudo echo 'ben:$apr1$mpquTx2.$Diwt9wgsmJaYrfdFNUgo3.' > /etc/nginx/htpasswd.users
sudo cp /etc/nginx/sites-available/default ~/nginx-sites-available-default.bak
sudo cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80;

    server_name elk.polzin.us;

    auth_basic "Restricted Access";
    auth_basic_user_file /etc/nginx/htpasswd.users;

    location / {
        proxy_pass http://localhost:5601;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Create certs to use for logstash and filebeat
# Must add private key manually
# sudo cat > /etc/pki/tls/private/logstash-forwarder.key << EOF
#
sudo mkdir -p /etc/pki/tls/certs
sudo mkdir /etc/pki/tls/private
sudo cat > /etc/pki/tls/certs/logstash-forwarder.crt << EOF
-----BEGIN CERTIFICATE-----
MIIDAzCCAeugAwIBAgIJAMjjdNvQhtuGMA0GCSqGSIb3DQEBCwUAMBgxFjAUBgNV
BAMMDWVsay5wb2x6aW4udXMwHhcNMTYwODExMDMzNTQxWhcNMjYwODA5MDMzNTQx
WjAYMRYwFAYDVQQDDA1lbGsucG9semluLnVzMIIBIjANBgkqhkiG9w0BAQEFAAOC
AQ8AMIIBCgKCAQEAowbxNVH+zl/eeEL1zbJg1s/+QHBcHO2B++eHB+H/xM0ybicV
cvN+RXmne+0kMMOS2xMHVCs5CgRNopAwF9lGRYsdA6yPAjWyO26BI9XnoZzRnOME
r8a8KV2+XYRJ35FUCqlzbzfA7Bh7KsmU2NYrPcShPg9wJ0ObdP2aSGz6qzJq1Asu
vQxQAGrZYw3vD35nOUM9d07YfmoA7GrOFschTplQny3aGxc2Btc677gDIifXACCB
dm8Rc3v39NREmxGKnil/xlGTjQnaVELbYZzXv6CCD2tPPTIRg0Psox/aXqZe7QXe
/BTlgi4ZKUc6TLd2z7/iqVniD/L2mHNrNlUe1wIDAQABo1AwTjAdBgNVHQ4EFgQU
ZyqyDtv2WrKDHwxWF3SuRgY1QKgwHwYDVR0jBBgwFoAUZyqyDtv2WrKDHwxWF3Su
RgY1QKgwDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAhA30xrcnGjHo
D+otPi8BOvxEH/tOHOZ+NmHcXXYXJKfHg+416Y8/C78vX3x9ylwIEOq6Zq0ufMIV
3WbhEyAUyz+81ZuublHI+HaHE+MCIt13jDrFu9JqyqbQK0NS27r8XxcHEGky/7hV
/0gCFIKdBDMnyQu9/aUhGN0SjNpbZO7ApcFbOSJf9rXIY52tF9aVb9wXFPH2apWy
LXgB+qeuZP4Rk1bXIkd/E1qb9klcRzWEIdmC0Qyjd6aw83sVldbLd2A9apiwazIl
kLNgZK2efs2IiG7wG6qS2tJ723TTuyQa2B9c+QRPzit8oLItKqRi+XnLdCUj8L2z
KxFhK/pIew==
-----END CERTIFICATE-----
EOF

# Set up CUCM trace log extraction
mkdir ~/cucmlogs
echo "find /home/ben/cucmlogs/ -name '*.gz' -exec gunzip '{}' \;" > ~/unziplogs.sh
chmod +x ~/unziplogs.sh
chmod 700 ~/unziplogs.sh
crontab -l > mycron
echo "00 * * * * /home/ben/unziplogs.sh" >> mycron
crontab mycron
rm mycron

# Set up Filebeat config

sudo cat > /etc/filebeat/filebeat.yml << EOF
############################# Filebeat ######################################
filebeat:
  prospectors:
    -
      paths:
        - /home/ben/cucmlogs/*/*/cm/trace/ccm/sdl/*.txt
      input_type: log
      exclude_files: [".gz$"]
  registry_file: /var/lib/filebeat/registry
output:
  logstash:
    hosts: ["localhost:5044"]
    tls:
      certificate_authorities: ["/etc/pki/tls/certs/logstash-forwarder.crt"]
shipper:

############################# Logging #########################################

# There are three options for the log ouput: syslog, file, stderr.
# Under Windos systems, the log files are per default sent to the file output,
# under all other system per default to syslog.
logging:

  # Send all logging output to syslog. On Windows default is false, otherwise
  # default is true.
  #to_syslog: true

  # Write all logging output to files. Beats automatically rotate files if rotateeverybytes
  # limit is reached.
  #to_files: true

  # To enable logging to files, to_files option has to be set to true
  files:
    # The directory where the log files will written to.
    #path: /var/log/mybeat

    # The name of the files where the logs are written to.
    #name: mybeat

    # Configure log file size limit. If limit is reached, log file will be
    # automatically rotated
    rotateeverybytes: 10485760 # = 10MB

    # Number of rotated log files to keep. Oldest files will be deleted first.
    #keepfiles: 7

  # Enable debug output for selected components. To enable all selectors use ["*"]
  # Other available selectors are beat, publish, service
  # Multiple selectors can be chained.
  #selectors: [ ]

  # Sets log level. The default log level is error.
  # Available log levels are: critical, error, warning, info, debug
  #level: error
EOF

# Set up Logstash config
sudo cat > /etc/logstash/conf.d/01-beats-input.conf << EOF
input {
  beats {
    port => 5044
    ssl => true
    ssl_certificate => "/etc/pki/tls/certs/logstash-forwarder.crt"
    ssl_key => "/etc/pki/tls/private/logstash-forwarder.key"
    codec => multiline {
      pattern => "^\d{6,12}\.\d{3}\s|%{TIME}\.\d{3}"
      negate => true
      what => previous
    }
  }
}
EOF

sudo cat > /etc/logstash/conf.d/10-beats-filter.conf << EOF
filter {
    grok {
      match => { "message" => "(?<cucm_linesequence>^\d{6,12}\.\d{3})\s\|%{TIME:timestamp}\s\|(?<cucm_app>\b\w+\b)\s+\|%{GREEDYDATA:sdl_message}" }
      add_field => [ "received_at", "%{@timestamp}" ]
    }
}
EOF

sudo cat > /etc/logstash/conf.d/99-beats-output.conf << EOF
output {
  elasticsearch {
    hosts => "localhost:9200"
    manage_template => false
    index => "%{[@metadata][beat]}-%{+YYYY.MM.dd}"
    document_type => "%{[@metadata][type]}"
  }
}
EOF

# Set up Elastic config

# Set up Kibana config

# Start all services and set to start on boot

sudo service nginx restart
sudo service elasticsearch restart
sudo service kibana restart
sudo service logstash restart
sudo service filebeat restart
sudo update-rc.d elasticsearch defaults 95 10
sudo update-rc.d kibana defaults 95 10
sudo update-rc.d filebeat defaults 95 10
sudo update-rc.d logstash defaults 96 9
