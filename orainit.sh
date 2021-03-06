#! /bin/bash
#
# DESC: Script to start/stop Oracle 10g Database by SystemV
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: orainit.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

#
#
#
#
# orainit:        Starts/Stops the Oracle processes
# chkconfig: 3 97 03
# description:  This init script handels the starting and stopping\
#               of the needed oracle processes. 
#
#
ORA_OWNER=oracle
ORACLE_SID=TCT
ORACLE_BASE=/opt/u00/app/oracle
ORACLE_HOME=$ORACLE_BASE/product/10.2.0/db1
RC=0


case "$1" in
start)
    echo "-----------------------------------------------------"
    echo "Starting listener"
    su - $ORA_OWNER -c "$ORACLE_HOME/bin/lsnrctl start >/dev/null " 
    pgrep -fl tnslsnr >/dev/null
    if [ $? -ne 0 ]
    then
       echo "ERROR: Listener is not running"
       RC=1
    else
       echo "Done"
    fi
    echo "-----------------------------------------------------"
    echo "Starting oracle DB Instance $ORACLE_SID"
    su - $ORA_OWNER -c "ORACLE_SID=$ORACLE_SID; sqlplus -S / as sysdba << EOF
    set linesize 1000
    set pagesize 10000
    set feedback off
    set heading off
    startup
    " >/dev/null 
    pgrep -fl ora_pmon_$ORACLE_SID >/dev/null
    if [ $? -ne 0 ]
    then
       echo "ERROR: ora_pmon_$ORACLE_SID process is not running"
       RC=1
    else
       echo "Done"
    fi
    echo "-----------------------------------------------------"
    echo "Starting Enterprise Manager for Instance $ORACLE_SID"
    su - $ORA_OWNER -c "ORACLE_SID=$ORACLE_SID; $ORACLE_HOME/bin/emctl start dbconsole >/dev/null" 
    pgrep -lf "dbconsole.*$ORACLE_SID" >/dev/null
    if [ $? -ne 0 ]
    then
       echo "ERROR: Enterprise Manager is not running"
       RC=1
    else
       echo "Done"
    fi
    exit $RC
;;
stop)
    echo "-----------------------------------------------------"
    echo "Stoping oracle DB for Instance $ORACLE_SID"
    su - $ORA_OWNER -c "ORACLE_SID=$ORACLE_SID; sqlplus -S / as sysdba << EOF
    set linesize 1000
    set pagesize 10000
    set feedback off
    set heading off
    shutdown immediate
    " >/dev/null
    pgrep -fl ora_pmon_$ORACLE_SID >/dev/null
    if [ $? -eq 0 ]
    then
       echo "ERROR: ora_pmon_$ORACLE_SID process is still running"
       RC=1
    else
       echo "Done"
    fi
    echo "-----------------------------------------------------"
    echo "Stoping Enterprise Manager for Instance $ORACLE_SI"
    su - $ORA_OWNER -c "ORACLE_SID=$ORACLE_SID; $ORACLE_HOME/bin/emctl stop dbconsole >/dev/null" 
    pgrep -lf "dbconsole.*$ORACLE_SID" >/dev/null
    if [ $? -eq 0 ]
    then
       echo "ERROR: Enterprise Manager is still running"
       RC=1
    else
       echo "Done"
    fi
    RC=1 ; RC=$(pgrep -f ora_pmon | wc -l)
    if [ $RC == 0 ]
    then
       echo "-----------------------------------------------------"
       echo "Stoping listener"
       su - $ORA_OWNER -c "$ORACLE_HOME/bin/lsnrctl stop >/dev/null" 
       pgrep -fl tnslsnr >/dev/null
       if [ $? -eq 0 ]
       then
          echo "ERROR: Listener is still running"
          RC=1
       else
          echo "Done"
       fi
    fi
    exit $RC
;;
status)
    echo "-----------------------------------------------------"
    echo "Status of Enterprise Manager for Instance $ORACLE_SID"
    su - $ORA_OWNER -c "ORACLE_SID=$ORACLE_SID; $ORACLE_HOME/bin/emctl status dbconsole" | egrep -q 'Enterprise Manager .* is running'
    if [ $? -eq 0 ]
    then
       echo "Enterprise Manager is running"
    else
       echo "Enterprise Manager is stopped"
       RC=1
    fi
    echo "-----------------------------------------------------"
    echo "Status listener"
    su - $ORA_OWNER -c "$ORACLE_HOME/bin/lsnrctl status" | egrep -q "$ORACLE_SID\", status READY"
    if [ $? -eq 0 ]
    then
       echo "Listener is running for Instance $ORACLE_SID"
    else
       echo "Listener is stopped or not handling Instance $ORACLE_SID"
       RC=1
    fi

    echo "-----------------------------------------------------"
    echo "Status Oracle Instance: $ORACLE_SID"
    su - $ORA_OWNER -c "ORACLE_SID=$ORACLE_SID; echo '
    set linesize 1000
    set pagesize 10000
    set feedback off
    set heading off
    select * from v\$instance ;
    ' | sqlplus -S / as sysdba" | grep $ORACLE_SID | awk '{print $6}' | grep -q OPEN ; RC=$?
    if [ $RC == 0 ]
    then
       echo "Instance $ORACLE_SID is running"
    else
       echo "Instance $ORACLE_SID is stopped"
    fi
    exit $RC
;;
*)
echo "Usage: $0 {start|stop|status}"
esac

################################################################################
# $Log: orainit.sh,v $
# Revision 1.2  2012/06/10 19:18:50  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:16  chris
# Initial revision
#
