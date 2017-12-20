sudo locale-gen de_CH.utf8
echo 'deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main' >> /etc/apt/sources.list.d/pgdg.list
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
apt-get update
apt-get upgrade
apt-get install -y postgresql-10 
apt-get install -y postgresql-client-10
apt-get install -y postgresql-10-postgis-2.4
sudo -u postgres psql -d postgres -c "CREATE ROLE ddluser LOGIN PASSWORD 'ddluser';"
sudo -u postgres psql -d postgres -c "CREATE ROLE dmluser LOGIN PASSWORD 'dmluser';"
sudo -u postgres psql -d postgres -c "CREATE ROLE oereb_read LOGIN PASSWORD 'oereb_read';"
sudo -u postgres psql -d postgres -c 'CREATE DATABASE sogis OWNER ddluser;'
sudo -u postgres psql -d sogis -c 'CREATE EXTENSION postgis;'
sudo -u postgres psql -d sogis -c 'CREATE EXTENSION "uuid-ossp";'
sudo -u postgres psql -d sogis -c 'GRANT SELECT ON geometry_columns TO dmluser;'
sudo -u postgres psql -d sogis -c 'GRANT SELECT ON spatial_ref_sys TO dmluser;'
sudo -u postgres psql -d sogis -c 'GRANT SELECT ON geography_columns TO dmluser;'
sudo -u postgres psql -d sogis -c 'GRANT SELECT ON raster_columns TO dmluser;'
sudo -u postgres psql -d sogis -c 'GRANT SELECT ON geometry_columns TO oereb_read;'
sudo -u postgres psql -d sogis -c 'GRANT SELECT ON spatial_ref_sys TO oereb_read;'
sudo -u postgres psql -d sogis -c 'GRANT SELECT ON geography_columns TO oereb_read;'
sudo -u postgres psql -d sogis -c 'GRANT SELECT ON raster_columns TO oereb_read;'
systemctl stop postgresql
rm /etc/postgresql/10/main/postgresql.conf
rm /etc/postgresql/10/main/pg_hba.conf
cp /vagrant/postgresql.conf /etc/postgresql/10/main
cp /vagrant/pg_hba.conf /etc/postgresql/10/main
sudo -u root chown postgres:postgres /etc/postgresql/10/main/postgresql.conf
sudo -u root chown postgres:postgres /etc/postgresql/10/main/pg_hba.conf
service postgresql start

apt-get --yes install unzip

add-apt-repository --yes ppa:webupd8team/java
apt-get update
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
apt-get --yes install oracle-java8-installer

mkdir -p /home/vagrant/apps/

cd ~
wget http://www.eisenhutinformatik.ch/interlis/ili2pg/ili2pg-3.11.0.zip -O ili2pg-3.11.0.zip
unzip -d /home/vagrant/apps/ ili2pg-3.11.0.zip
cd ~

cd ~
wget https://services.gradle.org/distributions/gradle-4.4.1-bin.zip -O gradle-4.4.1-bin.zip
unzip -d /home/vagrant/apps/ gradle-4.4.1-bin.zip
export PATH=$PATH:/home/vagrant/apps/gradle-4.4.1/bin
cd ~

# Import cadastral data (DM01)
java -jar /home/vagrant/apps/ili2pg-3.11.0/ili2pg.jar --dbhost localhost --dbdatabase sogis --dbusr ddluser --dbpwd ddluser --nameByTopic --disableValidation --defaultSrsCode 2056 --strokeArcs --createFk --createGeomIdx --createFkIdx --createEnumTabs --beautifyEnumDispName --createBasketCol --createDatasetCol --createMetaInfo --importTid --models DM01AVSO24LV95 --dbschema av_avdpool_ng --schemaimport

gradle -I /vagrant/av_avdpool_ng/init.gradle -b /vagrant/av_avdpool_ng/build.gradle replaceAllDatasets --continue

sudo -u postgres psql -d sogis -c 'GRANT USAGE ON SCHEMA av_avdpool_ng TO oereb_read;'
sudo -u postgres psql -d sogis -c 'GRANT SELECT ON ALL TABLES IN SCHEMA av_avdpool_ng TO oereb_read;'

# Import PLZ-Ortschaft
wget http://data.geo.admin.ch/ch.swisstopo-vd.ortschaftenverzeichnis_plz/PLZO_INTERLIS_LV95.zip -O PLZO_INTERLIS_LV95.zip
unzip -d /home/vagrant/ PLZO_INTERLIS_LV95.zip

java -jar /home/vagrant/apps/ili2pg-3.11.0/ili2pg.jar --dbhost localhost --dbdatabase sogis --dbusr ddluser --dbpwd ddluser --nameByTopic --disableValidation --defaultSrsCode 2056 --strokeArcs --createFk --createGeomIdx --createFkIdx --createEnumTabs --beautifyEnumDispName --createMetaInfo --importTid --models PLZOCH1LV95D --dbschema av_plzortschaft --import /home/vagrant/PLZO_INTERLIS_LV95/PLZO_ITF_LV95.itf

sudo -u postgres psql -d sogis -c 'GRANT USAGE ON SCHEMA av_plzortschaft TO oereb_read;'
sudo -u postgres psql -d sogis -c 'GRANT SELECT ON ALL TABLES IN SCHEMA av_plzortschaft TO oereb_read;'

# Import OEREB data (Transferstruktur)
java -jar /home/vagrant/apps/ili2pg-3.11.0/ili2pg.jar --dbhost localhost --dbdatabase sogis --dbusr ddluser --dbpwd ddluser --createBasketCol --createDatasetCol --createMetaInfo --importTid --nameByTopic --disableValidation --defaultSrsCode 2056 --expandMultilingual --coalesceCatalogueRef --createFk --strokeArcs --createGeomIdx --createFkIdx --createEnumTabs --beautifyEnumDispName  --models "OeREBKRMvs_V1_1;OeREBKRMtrsfr_V1_1" --dbschema agi_oereb_trsfr --schemaimport

java -jar /home/vagrant/apps/ili2pg-3.11.0/ili2pg.jar --dbhost localhost --dbdatabase sogis --dbusr ddluser --dbpwd ddluser --createBasketCol --createDatasetCol --createMetaInfo --importTid --nameByTopic --disableValidation --defaultSrsCode 2056 --expandMultilingual --coalesceCatalogueRef --createFk --strokeArcs --createGeomIdx --createFkIdx --createEnumTabs --beautifyEnumDispName --models OeREBKRMvs_V1_1 --dbschema agi_oereb_trsfr --dataset OeREBKRM_V1_1_Gesetze --import /vagrant/oereb-daten/ch/OeREBKRM_V1_1_Gesetze_20170101.xml

java -jar /home/vagrant/apps/ili2pg-3.11.0/ili2pg.jar --dbhost localhost --dbdatabase sogis --dbusr ddluser --dbpwd ddluser --createBasketCol --createDatasetCol --createMetaInfo --importTid --nameByTopic --disableValidation --defaultSrsCode 2056 --expandMultilingual --coalesceCatalogueRef --createFk --strokeArcs --createGeomIdx --createFkIdx --createEnumTabs --beautifyEnumDispName --models OeREBKRMtrsfr_V1_1 --dbschema agi_oereb_trsfr --dataset ch.bazl.sicherheitszonenplan --import /vagrant/oereb-daten/ch/ch.bazl.sicherheitszonenplan.oereb_20131118.xtf

java -jar /home/vagrant/apps/ili2pg-3.11.0/ili2pg.jar --dbhost localhost --dbdatabase sogis --dbusr ddluser --dbpwd ddluser --createBasketCol --createDatasetCol --createMetaInfo --importTid --nameByTopic --disableValidation --defaultSrsCode 2056 --expandMultilingual --coalesceCatalogueRef --createFk --strokeArcs --createGeomIdx --createFkIdx --createEnumTabs --beautifyEnumDispName --models OeREBKRMtrsfr_V1_1 --dbschema agi_oereb_trsfr --dataset ch.bav.kataster-belasteter-standorte-oev --import /vagrant/oereb-daten/ch/ch.bav.kataster-belasteter-standorte-oev.oereb_20171012.xtf

java -jar /home/vagrant/apps/ili2pg-3.11.0/ili2pg.jar --dbhost localhost --dbdatabase sogis --dbusr ddluser --dbpwd ddluser --createBasketCol --createDatasetCol --createMetaInfo --importTid --nameByTopic --disableValidation --defaultSrsCode 2056 --expandMultilingual --coalesceCatalogueRef --createFk --strokeArcs --createGeomIdx --createFkIdx --createEnumTabs --beautifyEnumDispName --models OeREBKRMtrsfr_V1_1 --dbschema agi_oereb_trsfr --dataset ch.bazl.kataster-belasteter-standorte-zivilflugplaetze --import /vagrant/oereb-daten/ch/ch.bazl.kataster-belasteter-standorte-zivilflugplaetze.oereb_20171012.xtf

java -jar /home/vagrant/apps/ili2pg-3.11.0/ili2pg.jar --dbhost localhost --dbdatabase sogis --dbusr ddluser --dbpwd ddluser --createBasketCol --createDatasetCol --createMetaInfo --importTid --nameByTopic --disableValidation --defaultSrsCode 2056 --expandMultilingual --coalesceCatalogueRef --createFk --strokeArcs --createGeomIdx --createFkIdx --createEnumTabs --beautifyEnumDispName --models OeREBKRMtrsfr_V1_1 --dbschema agi_oereb_trsfr --dataset ch.bazl.projektierungszonen-flughafenanlagen --import /vagrant/oereb-daten/ch/ch.bazl.projektierungszonen-flughafenanlagen.oereb_20161128.xtf

sudo -u postgres psql -d sogis -c 'GRANT USAGE ON SCHEMA agi_oereb_trsfr TO oereb_read;'
sudo -u postgres psql -d sogis -c 'GRANT SELECT ON ALL TABLES IN SCHEMA agi_oereb_trsfr TO oereb_read;'

# Import NPLSO data and copy to Transferstruktur
# TODO