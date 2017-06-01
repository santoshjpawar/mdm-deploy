#!/bin/bash
# Install MDM CE product on single node
#

INSTALLER_DIRECTORY=/var/tmp/install_temp
INSTALLER_ARCHIVE_NAME=mdm-installers.zip
INSTALLER_SOURCE=http://169.45.158.182:8000/$INSTALLER_ARCHIVE_NAME

#################################################
# Copy installation files                       #
#################################################
# Copy all installation files into $INSTALLER_DIRECTORY from file repository
mkdir -p $INSTALLER_DIRECTORY
cd $INSTALLER_DIRECTORY
wget $INSTALLER_SOURCE
unzip $INSTALLER_ARCHIVE_NAME
rm -rf $INSTALLER_ARCHIVE_NAME

# Copy other supporting files to $INSTALLER_DIRECTORY from Git project
curr_dir=`dirname $0`
cp -f $curr_dir/../../../db2-response $curr_dir/../../../db-prepare.sh $curr_dir/../../../env_settings.ini $curr_dir/../../../response $INSTALLER_DIRECTORY/

chmod +x $INSTALLER_DIRECTORY/*.sh

#################################################
# Preinstallation tasks                         #
#################################################
# Install pre-req packages
yum makecache fast
yum install -y cpan make openssh-clients perl unzip libaio compat-libstdc++-33 numactl nmap net-tools file telnet

#################################################
# DB2 installation                              #
#################################################
# Extract the installer
cd $INSTALLER_DIRECTORY
unzip server.zip

# Run the installer
cd server
./db2setup -r $INSTALLER_DIRECTORY/db2-response

# Start the database
su - db2inst1 -c "db2start"

# Configure PIM database
su - db2inst1 -c "$INSTALLER_DIRECTORY/db-prepare.sh"

#################################################
# IM installation                               #
#################################################
# Create user and group to use with websphere and Installation Manager
groupadd -r wasadmin && useradd -r -g wasadmin wasadmin

# Extract the installer
cd $INSTALLER_DIRECTORY
unzip ibm-im.zip

# Run the installer
cd IM
./installc -acceptLicense -log /opt/im_install.log

# Update file permissions
cd /opt
chown -R wasadmin:wasadmin IBM

#################################################
# WAS installation                              #
#################################################
# Extract the installer
cd $INSTALLER_DIRECTORY
unzip ibm-java.zip
unzip ibm-was.zip

# Run the installer
cd /opt/IBM/InstallationManager/eclipse
./IBMIM -acceptLicense --launcher.ini silent-install.ini input $INSTALLER_DIRECTORY/response

# Create WAS profile
cd /opt/IBM/WebSphere/AppServer/bin
./manageprofiles.sh -create -profileName server1 -cellName mdmserver1 -nodeName mdmserver1Node01 -templatePath /opt/IBM/WebSphere/AppServer/profileTemplates/default/

# Configure JDK
./managesdk.sh -enableProfileAll -sdkname 8.0_64 -enableServers

# Start WAS
cd /opt/IBM/WebSphere/AppServer/bin
./startServer.sh server1

#################################################
# MDMCE installation                            #
#################################################
# Extract the installer
cd $INSTALLER_DIRECTORY
unzip ibm-mdmce.zip -d /opt/11.6/

# Update environment setting file
/usr/bin/cp -f $INSTALLER_DIRECTORY/env_settings.ini /opt/11.6/MDM/bin/conf

# Update bash profile
echo ". /home/db2inst1/sqllib/db2profile" >> ~/.bash_profile
echo "export MQ_INSTALL_DIR=/opt/mqm" >> ~/.bash_profile
echo "export PERL5LIB=/opt/11.6/MDM/bin/perllib" >> ~/.bash_profile
echo "export LANG=en_us" >> ~/.bash_profile
echo "export TOP=/opt/11.6/MDM" >> ~/.bash_profile
echo "export ANT_HOME=/opt/IBM/WebSphere/AppServer/deploytool/itp/plugins/org.eclipse.wst.command.env_1.0.409.v201004211805.jar" >> ~/.bash_profile
echo "export ANT_OPTS=-xmx1024m" >> ~/.bash_profile
echo "export ANT_ARGS=-noclasspath" >> ~/.bash_profile
echo "export CLASSPATH=\$CLASSPATH:/opt/mqm/javalib/providerutil.jar;" >> ~/.bash_profile
echo "export CLASSPATH=\$CLASSPATH:/opt/mqm/javalib/ldap.jar;" >> ~/.bash_profile
echo "export CLASSPATH=\$CLASSPATH:/opt/mqm/javalib/jta.jar;" >> ~/.bash_profile
echo "export CLASSPATH=\$CLASSPATH:/opt/mqm/javalib/jndi.jar;" >> ~/.bash_profile
echo "export CLASSPATH=\$CLASSPATH:/opt/mqm/javalib/jms.jar;" >> ~/.bash_profile
echo "export CLASSPATH=\$CLASSPATH:/opt/mqm/javalib/connector.jar;" >> ~/.bash_profile
echo "export CLASSPATH=\$CLASSPATH:/opt/mqm/javalib/fscontext.jar;" >> ~/.bash_profile
echo "export CLASSPATH=\$CLASSPATH:/opt/mqm/javalib/com.ibm.mqjms.jar;" >> ~/.bash_profile
echo "export CLASSPATH=\$CLASSPATH:/opt/mqm/javalib/com.ibm.mq.jar;" >> ~/.bash_profile
echo "PATH=\$PATH:\$ANT_HOME/bin" >> ~/.bash_profile

# Source bash profile
source ~/.bash_profile

# Update env_settings.ini
chmod 666 /opt/11.6/MDM/bin/conf/env_settings.ini

# Install MDMCE
cd $TOP
echo y | ./setup.sh
cd $TOP/bin
./configureEnv.sh --over
echo "y y" | $TOP/bin/db/create_schema.sh
cd $TOP/bin/websphere
echo y | ./create_vhost.sh
echo y | ./create_appsvr.sh
echo y | ./install_war.sh
cd $TOP/bin/go
./start_local.sh