#!/bin/bash

### VARIABLES ###
PRE_PACK="rrdtool rrdtool-perl perl-Time-HiRes perl-GD php-gd" 
VER=""

# Setup Colours
boldblack='\E[1;30;40m'
boldred='\E[1;31;40m'
boldgreen='\E[1;32;40m'
boldyellow='\E[1;33;40m'
boldblue='\E[1;34;40m'
boldmagenta='\E[1;35;40m'
boldcyan='\E[1;36;40m'
boldwhite='\E[1;37;40m'

Reset="tput sgr0"

cecho() {
    message=$1
    color=$2
    echo -e "$color$message"
    $Reset
    return
}
clear

cecho "Installing Prerequisite Packages..." $boldyellow
yum install -y -q epel-release >/dev/null
yum install -y -q $PRE_PACK >/dev/null


cecho "Download & Configure pnp4agios ..." $boldyellow
cd /tmp
wget -q https://github.com/vutuyen6712/vutuyen6712.github.io/raw/master/software/pnp4nagios-0.6.25.tar.gz >/dev/null
tar xzf pnp4nagios-0.6.25.tar.gz >/dev/null
cd /tmp/pnp4nagios-0.6.25
./configure >/dev/null
if [ $? -eq 0 ]
then
    cecho "Download & configure has been completed" $boldgreen
else
    cecho "Download or configure failed" $boldred
    exit 1
fi


cecho "Compiling and Installing pnp4nagios  ..." $boldyellow
cd /tmp/pnp4nagios-0.6.25
make all >/dev/null
make fullinstall >/dev/null
if [ $? -eq 0 ]
then
    cecho "Download & configure has been completed" $boldgreen
else
    cecho "Download or configure failed" $boldred
    exit 1
fi


/usr/local/pnp4nagios/bin/npcd -d -f /usr/local/pnp4nagios/etc/npcd.cfg
systemctl enable npcd.service
rm -f /usr/local/pnp4nagios/share/install.php

cat <<EOF >> /usr/local/nagios/etc/nagios.cfg
process_performance_data=1
enable_environment_macros=1
host_perfdata_command=process-host-perfdata
service_perfdata_command=process-service-perfdata

# service performance data
service_perfdata_file=/usr/local/pnp4nagios/var/service-perfdata
service_perfdata_file_template=DATATYPE::SERVICEPERFDATA\tTIMET::\$TIMET\$\tHOSTNAME::\$HOSTNAME\$\tSERVICEDESC::\$SERVICEDESC\$\tSERVICEPERFDATA::\$SERVICEPERFDATA\$\tSERVICECHECKCOMMAND::\$SERVICECHECKCOMMAND\$\tHOSTSTATE::\$HOSTSTATE\$\tHOSTSTATETYPE::\$HOSTSTATETYPE\$\tSERVICESTATE::\$SERVICESTATE\$\tSERVICESTATETYPE::\$SERVICESTATETYPE\$
service_perfdata_file_mode=a
service_perfdata_file_processing_interval=15
service_perfdata_file_processing_command=process-service-perfdata-file

# host performance data
host_perfdata_file=/usr/local/pnp4nagios/var/host-perfdata
host_perfdata_file_template=DATATYPE::HOSTPERFDATA\tTIMET::\$TIMET\$\tHOSTNAME::\$HOSTNAME\$\tHOSTPERFDATA::\$HOSTPERFDATA\$\tHOSTCHECKCOMMAND::\$HOSTCHECKCOMMAND\$\tHOSTSTATE::\$HOSTSTATE\$\tHOSTSTATETYPE::\$HOSTSTATETYPE\$
host_perfdata_file_mode=a
host_perfdata_file_processing_interval=15
host_perfdata_file_processing_command=process-host-perfdata-file
EOF

cat <<EOF >> /usr/local/nagios/etc/objects/commands.cfg

define command{
       command_name    process-service-perfdata-file
       command_line    /bin/mv /usr/local/pnp4nagios/var/service-perfdata /usr/local/pnp4nagios/var/spool/service-perfdata.\$TIMET\$
}

define command{
       command_name    process-host-perfdata-file
       command_line    /bin/mv /usr/local/pnp4nagios/var/host-perfdata /usr/local/pnp4nagios/var/spool/host-perfdata.\$TIMET\$
}
EOF

cat <<EOF >> /usr/local/nagios/etc/objects/templates.cfg

define host {
        name            host-pnp
        action_url      /pnp4nagios/index.php/graph?host=\$HOSTNAME\$&srv=_HOST_' class='tips' rel='/pnp4nagios/index.php/popup?host=\$HOSTNAME\$&srv=_HOST_
        register        0
}
define service {
        name            srv-pnp
        action_url      /pnp4nagios/index.php/graph?host=\$HOSTNAME\$&srv=\$SERVICEDESC\$' class='tips' rel='/pnp4nagios/index.php/popup?host=\$HOSTNAME\$&srv=\$SERVICEDESC\$
        register        0
}
EOF

systemctl restart httpd.service; systemctl restart nagios.service
