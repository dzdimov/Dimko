#!/usr/bin/env bash
################################################################################
#
# ACM ElasticSearch  installation script
#
#
#                         Marjan Stefanoski <marjan.stefanoskiski@armedia.com>
#
################################################################################
# Configuration (add your configuraiton options here)
################################################################################

# Get the working directory for a script, no matter where it's exectued from!
_script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source acm function library
. $_script_dir/../../../lib/acm-functions
. $_script_dir/elastic-docker.properties


log "=> Linking binaries"
ln -s $_script_dir/../../../bin/$JAVA_PACKAGE $_script_dir/$JAVA_PACKAGE
ln -s $_script_dir/../../../bin/$ELASTICSEARCH_PACKAGE $_script_dir/$ELASTICSEARCH_PACKAGE
#ln -s $_script_dir/../../../bin/$X_PACK_PACKAGE $_script_dir/$X_PACK_PACKAGE


mkdir -p /opt/elasticsearch/{certs,private,data,logs,conf/scripts} || fail "!> Failed to create Elasticsearch folder structure"


log "#> Installing Java"
rpm -ivh $_script_dir/$JAVA_PACKAGE || fail "!> Failed to install Java"

log "#> Installing ElasticSearch"
rpm -ivh $_script_dir/$ELASTICSEARCH_PACKAGE || fail "!> Failed to install ElasticSearch"

log "#> Modifying permissions of data and log dir"
chown -R elasticsearch:elasticsearch /opt/elasticsearch || fail "!> Failed to modify permissions of ElasticSearch dirs"

log "#> Setting max open files for elasticsearch user"
echo "elasticsearch soft nproc 4096
elasticsearch hard nproc 4096
elasticsearch soft nofile 65536
elasticsearch hard nofile 65536" >> /etc/security/limits.conf || fail "!> Failed to set max open files"

log "#> Adding services to auto start"
sudo chkconfig --add elasticsearch || fail "!> Failed to add ElasticSearch"

log "=> Adding ElasticSearch to startup.sh & shutdown.sh scripts"
echo 'service elasticsearch start' >> /usr/local/bin/startup.sh
echo 'service elasticsearch stop' >> /usr/local/bin/shutdown.sh

log "=> Starting Elasticsearch"
service elasticsearch start || fail "!> Failed to start Elasticsearch"

log "=> Setting index cat script"
echo "curl 'localhost:9200/_cat/indices?v'" >> /usr/local/bin/escat-index || fail "!> Failed to set index cat script"
chmod +x /usr/local/bin/escat-index

log "=> Setting node cat script"
echo "curl 'localhost:9200/_cat/nodes?v'" >> /usr/local/bin/escat-node || fail "!> Failed to set node cat script"
chmod +x /usr/local/bin/escat-node

log "=> Setting ownership"
cp $_script_dir/fix-ownership.sh /usr/local/bin || fail "!> Failed to set ownership"
echo '/usr/local/bin/fix-ownership.sh' >> /usr/local/bin/startup.sh || fail "!> Failed to configure ownership on startup"


log "#> Backup default ElasticSearch configuration file"
cp /etc/elasticsearch/elasticsearch.yml /opt/elasticsearch/conf/elasticsearch.yml.backup || fail "!> Failed backup ElasticSearch configuration file"

log "#>Setting the port in the ElasticSearch config file "
sed -i "s|\$ES_PORT|$ES_PORT|g" "$_script_dir/elasticsearch.yml"
sed -i "s|CONF_DIR=\"\/etc\/elasticsearch\"|CONF_DIR=\"\/opt\/elasticsearch\/conf\"|g" /etc/rc.d/init.d/elasticsearch
sed -i "s|\-Edefault\.path\.data=\$DATA_DIR|"\ "|g" /etc/rc.d/init.d/elasticsearch

log "#> Copying ElasticSearch configuration file"
cp $_script_dir/elasticsearch.yml /opt/elasticsearch/conf || fail "!> Failed copy ElasticSearch configuration file"
cp  /etc/elasticsearch/jvm.options /opt/elasticsearch/conf/
cp  /etc/elasticsearch/log4j2.properties /opt/elasticsearch/conf/

chown -R elasticsearch.elasticsearch /opt/elasticsearch

log "=> Starting ElasticSearch "
service elasticsearch start
log "=> Waiting additional 90 seconds for elasticsearch to become responsive...."
sleep 90

log "=> Configuring elsaticsearch for acm_advanced_search "
curl -XPUT 'localhost:9200/acm_advanced_search?pretty' -H 'Content-Type: application/json' --data-binary @$_script_dir/acmIndexConfig.json

log "=> Configuring elsaticsearch for acm_quick_search "
curl -XPUT 'localhost:9200/acm_quick_search?pretty' -H 'Content-Type: application/json' --data-binary @$_script_dir/acmIndexConfig.json

log "=> Configuring elsaticsearch for acm_log_search "
curl -XPUT 'localhost:9200/acm_log_search?pretty' -H 'Content-Type: application/json' --data-binary @$_script_dir/acmIndexConfig.json

log "=> Stopping ElasticSearch"
service elasticsearch stop

chmod 644 /opt/elasticsearch/conf/*

#log "#> Installing X-Pack plugin"
#/usr/share/elasticsearch/bin/elasticsearch-plugin install --batch file:///$_script_dir/$X_PACK_PACKAGE || fail "!> Failed to install x-pack" 

log "#> Passwords for build in accounts ,elastic, kibana, logstash"
service elasticsearch start
sleep 90 

/usr/share/elasticsearch/bin/elasticsearch-setup-passwords auto -b -v > passwords || fail ">! Failed to generate ELK passwords"

curl -XPOST -u elastic:`grep "PASSWORD elastic = " /passwords | awk '{print $4}'` 'localhost:9200/_xpack/security/user/elastic/_password?pretty' -H 'Content-Type: application/json' -d'
{
  "password": "elasticpass"
}
'

curl -XPOST -u elastic:elasticpass 'localhost:9200/_xpack/security/user/kibana/_password?pretty' -H 'Content-Type: application/json' -d'
{
  "password": "kibanapass"
}
'

curl -XPOST -u elastic:elasticpass 'localhost:9200/_xpack/security/user/logstash_system/_password?pretty' -H 'Content-Type: application/json' -d'
{
  "password": "logstashpass"
}
'
rm /passwords -f

log "#> X-pack basic license"
#curl -XPUT -u elastic:elasticpass 'http://localhost:9200/_xpack/license' -H "Content-Type: application/json" -d @$_script_dir/license.json

log "#> ElasticSearch installation completed!"

exit 0
