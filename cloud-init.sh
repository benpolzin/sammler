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
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# Create certs to use for logstash and filebeat
# Must add private key manually
sudo mkdir -p /etc/pki/tls/certs
sudo mkdir /etc/pki/tls/private
sudo cat > /etc/pki/tls/certs/logstash-forwarder.crt << EOF
-----BEGIN CERTIFICATE-----
MIIEezCCA9ygAwIBAgIJAIaqehxq4H8JMAoGCCqGSM49BAMCMHUxCzAJBgNVBAYT
AlVTMRIwEAYDVQQIDAlNaW5uZXNvdGExDTALBgNVBAcMBEh1Z28xDzANBgNVBAoM
BlBvbHppbjEaMBgGA1UECwwRQ29sbGFib3JhdGlvbiBMYWIxFjAUBgNVBAMMDWVs
ay5wb2x6aW4udXMwHhcNMTYwODA5MDI1NTU0WhcNMjYwODA3MDI1NTU0WjB1MQsw
CQYDVQQGEwJVUzESMBAGA1UECAwJTWlubmVzb3RhMQ0wCwYDVQQHDARIdWdvMQ8w
DQYDVQQKDAZQb2x6aW4xGjAYBgNVBAsMEUNvbGxhYm9yYXRpb24gTGFiMRYwFAYD
VQQDDA1lbGsucG9semluLnVzMIICXDCCAc8GByqGSM49AgEwggHCAgEBME0GByqG
SM49AQECQgH/////////////////////////////////////////////////////
/////////////////////////////////zCBngRCAf//////////////////////
///////////////////////////////////////////////////////////////8
BEFRlT65YY4cmh+SmiGgtoVA7qLacluZsxXzuLSJkY7xCeFWGTlR7H6TexZSwL07
sb8HNXPfiD0sNPHvRR/Ua1A/AAMVANCeiAApHLhTlsxnFzkyhKqg2mS6BIGFBADG
hY4GtwQE6c2ePstmI5W0QpxkgTkFP7Uh+CivYGtNPbqhS1537+dZKP4dwSei/6je
M0izwYVqQpv5fn4xwuW9ZgEYOSlqeJo7wARcil+0LH0b2Zj1RElXm0RoF6+9Fyc+
ZiyX7nKZXvQmQMVQuQE/rQdhNTxwhqJywkCIvpR2n9FmUAJCAf//////////////
////////////////////////////+lGGh4O/L5Zrf8wBSPcJpdA7tcm4iZxHrrtv
tx6ROGQJAgEBA4GGAAQAhzNqvwUHWw9fWhwoslVR4bW9wv1nLPn/l5YmmcHT4oAc
LtNWtweTjfwq7ESJsQHpRe+UEVt+N6BE+wy8wMm//ToAvYyCafk16H0Lo+CnbguE
80eWgmFxmXmb4oRQse83gSOyaG7j0YN3n3I5kmwZeGW/9CFem828OAvz2K+fFI4J
ZdujUDBOMB0GA1UdDgQWBBSra60PrydGgpueqyIpWGKsmpKFXDAfBgNVHSMEGDAW
gBSra60PrydGgpueqyIpWGKsmpKFXDAMBgNVHRMEBTADAQH/MAoGCCqGSM49BAMC
A4GMADCBiAJCALdKwhYSUREXYW0SLkIixT1RDKqdF8C4Y2JvfGUdMRtkrWBPdAOb
eTnZALdI02g0p9tTv/Mr6VvUaEWXg50HVnooAkIAzbEkFXLNCITm/YUXYrOpRfst
jAYxcnHQdQ5mQNirZxZ0xQQ9evQbYeWyGh4mAux+JmYlVrvwxAAcnc2bzzBBP+4=
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
    codec => multiline {
      pattern => "^\d{6,12}\.\d{3}\s|%{TIME}\.\d{3}"
      negate => true
      what => previous
    }
    port => 5044
    ssl => true
    ssl_certificate => "/etc/pki/tls/certs/logstash-forwarder.crt"
    ssl_key => "/etc/pki/tls/private/logstash-forwarder.key"
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
sudo serivce filebeat restart
sudo update-rc.d elasticsearch defaults 95 10
sudo update-rc.d kibana defaults 95 10
sudo update-rc.d filebeat defaults 95 10
sudo update-rc.d logstash defaults 96 9
