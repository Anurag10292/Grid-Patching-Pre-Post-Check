#!/bin/bash
#execute this dbstat.sh on server of shared machine with oracle user account.
 
#parameter set
export PRM=$1;
export STAMP=`date +'%d%m%Y_%H%M%S'`;
 
PLATFORM=`uname`
if [ ${PLATFORM}!="SunOS" ]; then
OTAB="/etc/oratab"
else
OTAB="/etc/oratab"
fi
export ORATAB=$OTAB;
export SCRIPT_DIR=/u02/app/oracle/scripts/patching_verify;
export PRM_LIST=/u02/app/oracle/scripts/prmdblist.txt
export LOG_DIR=$SCRIPT_DIR/logs;
export PP_LOG=$LOG_DIR/$1;
export MCH=`hostname -s`;
export EC2I=`hostname`;
export Mailto=abcd@xyz.com
#echo "Parameter set step 1";
 
##Machine level
 
{
echo -e "Uptime of server:\n";
uptime;
echo -e "\nServer version:\n";
uname -a;
echo -e "\nDetail of oratab:\n";
cat $ORATAB|grep -v "^#";
 
##Running instances
echo -e "\nRunning instances and Total count:\n";
ps -ef | grep pmon_ | grep -v grep | sort -k8 && echo ' ' && ps -ef | grep pmon_ | grep -v grep | sort -k8|wc -l;
 
##Running listener
echo -e "\nRunning listeners on machine:\n";
ps -ef|grep -i tnslsnr|grep -v grep|sort -k8;
 
##Running agent OEM etc.
echo -e "\nRunning agents :\n";
ps -ef | grep agent | grep java | sed 's/\s\+/ /g' | cut -d " " -f 1,8 | sed 's/\/jdk.*//';
 
##filesystem detail
echo -e "\nFilesystem count :\n";
df -h|wc -l
echo -e "\nFilesystem details :\n";
df -h
##CronJobs Details
echo -e "\n Cron job details of grid:\n`crontab -l`";
#echo -e "\n Cron job details of oracle:\n`crontab -l -u oracle`";
 
}>$PP_LOG/dbstat_"$MCH"_final_"$STAMP".log
 
#grid env set
ORACLE_SID=`ps -ef | grep pmon | grep asm | awk '{print $NF}' | sed s'/asm_pmon_//' | egrep "^[+]"`
export ORAENV_ASK=NO
. oraenv >/dev/null;
{
##Verify cluster status.
echo -e "\nHAS status:\n";
crsctl check crs;
 
#echo -e "\nCluster initial resource status:\n";
#crsctl stat res -t -init;
 
echo -e "\nCluster resource status:\n";
crsctl stat res -t;
 
if [ `crsctl stat res -t -w '((TARGET != OFFLINE) and (STATE != ONLINE))'|wc -l` -eq 0 ]
then
echo -e "\nCluster resource status: Success";
else
echo -e "\nCluster resource status: Something wrong";
 
crsctl stat res -t -w '((TARGET != OFFLINE) and (STATE != ONLINE))';
crsctl stat res -w " STATE = OFFLINE" -t;
 
fi }>>$PP_LOG/dbstat_"$MCH"_final_"$STAMP".log
 
##ASM_Disk_Details.
echo -e "\nASM DiskGroup status:\n" >>$PP_LOG/dbstat_"$MCH"_final_"$STAMP".log
export ORACLE_SID=`ps -ef | grep pmon | grep asm | awk '{print $NF}' | sed s'/asm_pmon_//' | egrep "^[+]"`
export ORACLE_SID=$ORACLE_SID
export ORACLE_HOME=/u01/app/19.0.0.0/grid
export ORAENV_ASK=NO
. oraenv >/dev/null;
sqlplus -s "/ as sysdba" <<e1 >>$PP_LOG/dbstat_"$MCH"_final_"$STAMP".log
 
set feedback off
set SERVEROUTPUT ON
SET TRIMSPOOL ON
set lines 300 pages 1000
col NAME for a15
col PATH for a55
col DG_NAME for a15
col DG_STATE for a10
col FAILGROUP for a20
col MOUNT_S format a20;
col MOUNT_DAT format a20;
col HEADER_STATU format a15;
col MODE_ST format a15;
 
BEGIN
    dbms_output.put_line (CHR(10));
    DBMS_OUTPUT.PUT_LINE('OFFLINE DISK STATUS');
END;
/
 
 
select GROUP_NUMBER DG#, name, ALLOCATION_UNIT_SIZE AU_SZ, STATE,TYPE, TOTAL_MB, FREE_MB, OFFLINE_DISKS from v\$asm_diskgroup;
 
BEGIN
    dbms_output.put_line (CHR(10));
    DBMS_OUTPUT.PUT_LINE('ASM Diskgroup Space Details');
END;
/
 
SELECT
    name,
    type,
    total_mb/1024/1024/3 Total_TB,
    free_mb/1024/1024/3 Free_TB,
    usable_file_mb/1024/1024 Usable_TB,
    ROUND((1- (usable_file_mb / (total_mb/3)))*100, 2)  pct_used
FROM
    v\$ASM_DISKGROUP;
 
BEGIN
    dbms_output.put_line (CHR(10));
    DBMS_OUTPUT.PUT_LINE('ASM Disks Detail');
END;
/
 
select dg.name dg_name, dg.state dg_state, dg.type, d.disk_number dsk_no,
d.path,d.total_mb,d.free_mb, d.mount_status, d.FAILGROUP, d.state
from v\$asm_diskgroup dg, v\$asm_disk d
where dg.group_number=d.group_number
order by dg_name, dsk_no;
 
BEGIN
    dbms_output.put_line (CHR(10));
    DBMS_OUTPUT.PUT_LINE('Voting Disks Detail');
END;
/
 
SELECT path, mount_status, mount_date, header_status , mode_status, failgroup
FROM v\$asm_disk
WHERE voting_file = 'Y';
 
e1
 
##Database_Details
echo -e "\nAll Running Databases Details:\n" >>$PP_LOG/dbstat_"$MCH"_final_"$STAMP".log
 
for PRM_NAME in `cat "${PRM_LIST}"`
do
. /home/oracle/${PRM_NAME}.env
export ORACLE_SID=$ORACLE_SID
export ORAENV_ASK=NO
echo -e "\nDatabase Name is $ORACLE_SID \n" >>$PP_LOG/dbstat_"$MCH"_final_"$STAMP".log
sqlplus -s "/ as sysdba" <<e1 >>$PP_LOG/dbstat_"$MCH"_final_"$STAMP".log
 
set feedback off
set SERVEROUTPUT ON
SET TRIMSPOOL ON
set lines 300 pages 1000
col INSTANCE_NAME for a15
col HOST_NAME for a30
col MACHINE for a35
col USERNAME for a20
col module for a25
col LOCKED_MODE for a20
col OBJECT_NAME for a30
col OBJECT_OWNER for a20
col OS_USER_NAME for a20
col INSTANCE for a10
col MODE for a11
col ROLE for a20
col HOST for a20
col STATUS for a15
col STARTUP_TIME for a20
col HOST_NAME format a30
col SYSTEM_ITEM for a40
col SYSTEM_VALUE for a60
column opname format a15 Heading Operation
column target format a28 Heading Target
column es format 999.9 Heading "Time|Ran"
column tr format 999.90 Heading "Time|Left"
column pct format 990 Heading "PCT"
column RATE format a30 Heading "I/O |Rate/m"
column TR format 99999
 
BEGIN
    dbms_output.put_line (CHR(10));
    DBMS_OUTPUT.PUT_LINE('Current date and time');
END;
/
select to_char(sysdate, 'dd-Mon-yyyy hh24:mi:ss') as "Date" from dual;
 
 
BEGIN
    dbms_output.put_line (CHR(10));
    DBMS_OUTPUT.PUT_LINE('Instance details');
END;
/
 
col INSTANCE for a10
col MODE for a11
col ROLE for a12
col HOST for a20
col STATUS for a15
col STARTUP_TIME for a20
col HOST_NAME format a30
select NAME "DB_NAME",INSTANCE_NAME "INSTANCE_NAME",HOST_NAME "HOST_NAME", OPEN_MODE "OPEN_MODE", log_mode, to_char(startup_time,'dd-Mon-rrrr hh24:mi:Ss')startup_time,LOGINS "LOGIN", STATUS,DATABASE_ROLE "ROLE", VERSION_FULL "VERSION" from gv\$database NATURAL JOIN gv\$instance;
 
col CURRENT_SCN for 9999999999999999999
SELECT CURRENT_SCN FROM V\$DATABASE;
 
BEGIN
    dbms_output.put_line (CHR(10));
    DBMS_OUTPUT.PUT_LINE('Complete Machine details');
END;
/
 
WITH
rac AS (SELECT COUNT(*) instances, CASE COUNT(*) WHEN 1 THEN 'Single-instance' ELSE COUNT(*)||'-node RAC cluster' END db_type FROM gv\$instance),
mem AS (SELECT SUM(value) target FROM gv\$system_parameter2 WHERE name = 'memory_target'),
sga AS (SELECT SUM(value) target FROM gv\$system_parameter2 WHERE name = 'sga_target'),
pga AS (SELECT SUM(value) target FROM gv\$system_parameter2 WHERE name = 'pga_aggregate_target'),
db_block AS (SELECT value bytes FROM v\$system_parameter2 WHERE name = 'db_block_size'),
db AS (SELECT name, platform_name FROM v\$database),
pdbs AS (SELECT * FROM v\$pdbs),
inst AS (SELECT  host_name, version db_version FROM v\$instance),
data AS (SELECT  SUM(bytes) bytes, COUNT(*) files, COUNT(DISTINCT ts#) tablespaces FROM v\$datafile),
temp AS (SELECT  SUM(bytes) bytes FROM v\$tempfile),
log AS (SELECT SUM(bytes) * MAX(members) bytes FROM v\$log),
control AS (SELECT  SUM(block_size * file_size_blks) bytes FROM v\$controlfile),
cell AS (SELECT COUNT(DISTINCT cell_name) cnt FROM v\$cell_state),
core AS (SELECT  SUM(value) cnt FROM gv\$osstat WHERE stat_name = 'NUM_CPU_CORES'),
cpu AS (SELECT  SUM(value) cnt FROM gv\$osstat WHERE stat_name = 'NUM_CPUS'),
pmem AS (SELECT SUM(value) bytes FROM gv\$osstat WHERE stat_name = 'PHYSICAL_MEMORY_BYTES')
SELECT
       'Database name:' system_item, db.name system_value FROM db
UNION ALL
SELECT '    pdb:'||name, 'Open Mode:'||open_mode FROM pdbs -- need 12c flag
  UNION ALL
SELECT 'Oracle Database version:', inst.db_version FROM inst
UNION ALL
SELECT 'Database block size:', TRIM(TO_CHAR(db_block.bytes / POWER(2,10), '90'))||' KB' FROM db_block
UNION ALL
SELECT 'Database size:', TRIM(TO_CHAR(ROUND((data.bytes + temp.bytes + log.bytes + control.bytes) / POWER(10,12), 3), '999,999,990.000'))||' TB'
  FROM db, data, temp, log, control
UNION ALL
SELECT 'Datafiles:', data.files||' (on '||data.tablespaces||' tablespaces)' FROM data
UNION ALL
SELECT 'Database configuration:', rac.db_type FROM rac
UNION ALL
SELECT 'Database memory:',
CASE WHEN mem.target > 0 THEN 'MEMORY '||TRIM(TO_CHAR(ROUND(mem.target / POWER(2,30), 1), '999,990.0'))||' GB, ' END||
CASE WHEN sga.target > 0 THEN 'SGA '   ||TRIM(TO_CHAR(ROUND(sga.target / POWER(2,30), 1), '999,990.0'))||' GB, ' END||
CASE WHEN pga.target > 0 THEN 'PGA '   ||TRIM(TO_CHAR(ROUND(pga.target / POWER(2,30), 1), '999,990.0'))||' GB, ' END||
CASE WHEN mem.target > 0 THEN 'AMM' ELSE CASE WHEN sga.target > 0 THEN 'ASMM' ELSE 'MANUAL' END END
  FROM mem, sga, pga
UNION ALL
SELECT 'Hardware:', CASE WHEN cell.cnt > 0 THEN 'Engineered System '||
CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%5675%' THEN 'X2-2 ' END||
CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%2690%' THEN 'X3-2 ' END||
CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%2697%' THEN 'X4-2 ' END||
CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%2699%' THEN 'X5-2 or X-6 ' END||
CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%8160%' THEN 'X7-2 ' END||
CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%8870%' THEN 'X3-8 ' END||
CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%8895%' THEN 'X4-8 or X5-8 ' END||
'with '||cell.cnt||' storage servers'
ELSE 'Unknown' END FROM cell
  UNION ALL
SELECT 'Processor:', 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' FROM DUAL
UNION ALL
SELECT 'Physical CPUs:', core.cnt||' cores'||CASE WHEN rac.instances > 0 THEN ', on '||rac.db_type END FROM rac, core
UNION ALL
SELECT 'Oracle CPUs:', cpu.cnt||' CPUs (threads)'||CASE WHEN rac.instances > 0 THEN ', on '||rac.db_type END FROM rac, cpu
UNION ALL
SELECT 'Physical RAM:', TRIM(TO_CHAR(ROUND(pmem.bytes / POWER(2,30), 1), '999,990.0'))||' GB'||CASE WHEN rac.instances > 0 THEN ', on '||rac.db_type END FROM rac, pmem
UNION ALL
SELECT 'Operating system:', db.platform_name FROM db;
 
BEGIN
    dbms_output.put_line (CHR(10));
    DBMS_OUTPUT.PUT_LINE('PGA/SGA Consumption in Last 1 Hour');
END;
/
 
SELECT sn.INSTANCE_NUMBER, sga.allo sga, pga.allo pga, (sga.allo+pga.allo)total, TRUNC(SN.END_INTERVAL_TIME,'mi')time FROM(SELECT snap_id, INSTANCE_NUMBER, ROUND(SUM(bytes)/1024/1024/1024,3)allo FROM DBA_HIST_SGASTAT GROUP BY snap_id,INSTANCE_NUMBER)sga, (SELECT snap_id, INSTANCE_NUMBER, ROUND(SUM(VALUE)/1024/1024/1024,3)allo FROM DBA_HIST_PGASTAT WHERE name='total PGA allocated' GROUP BY snap_id,INSTANCE_NUMBER)pga, dba_hist_snapshot sn WHERE sn.snap_id=sga.snap_id AND sn.INSTANCE_NUMBER=sga.INSTANCE_NUMBER AND sn.snap_id=pga.snap_id AND sn.INSTANCE_NUMBER=pga.INSTANCE_NUMBER and TRUNC(SN.END_INTERVAL_TIME,'mi')>(SYSDATE-1/24) ORDER BY sn.snap_id ASC,sn.INSTANCE_NUMBER;
 
 
BEGIN
    dbms_output.put_line (CHR(10));
    DBMS_OUTPUT.PUT_LINE('PDB Details');
END;
/
 
col NAME for a15;
col OPEN_TIME for a35;
select INST_ID,NAME,OPEN_MODE,OPEN_TIME,RESTRICTED from gv\$pdbs;
 
 
BEGIN
    dbms_output.put_line (CHR(10));
    DBMS_OUTPUT.PUT_LINE('Total active/inactive sessions for both the instance (RAC command)');
END;
/
SELECT inst_id,status,count(*) TotalSessions FROM gv\$session GROUP BY status, inst_id order by 1,2;
 
 
BEGIN
    dbms_output.put_line (CHR(10));
    DBMS_OUTPUT.PUT_LINE('INVALID Object Count');
END;
/
 
select count(*) from dba_objects where status='INVALID';
 
col owner for a15
col object_name for a35
col object_type for a20
select count(*), object_type from cdb_objects
where status != 'VALID'
group by object_type;
 
BEGIN
    dbms_output.put_line (CHR(10));
    DBMS_OUTPUT.PUT_LINE('INVALID SYS Object Details');
END;
/
COLUMN object_name FORMAT A30
SELECT owner,
object_type,
object_name,
status
FROM dba_objects
WHERE status = 'INVALID' and OWNER='SYS';
 
 
BEGIN
    dbms_output.put_line (CHR(10));
    DBMS_OUTPUT.PUT_LINE('PDB_PLUG_IN_VIOLATION');
END;
/
col TIME for a15;
col NAME for a15;
col CAUSE for a30;
col MESSAGE for a30;
col ACTION for a20;
select * from PDB_PLUG_IN_VIOLATIONS where STATUS != 'RESOLVED';
 
BEGIN
    dbms_output.put_line (CHR(10));
    DBMS_OUTPUT.PUT_LINE('WALLET DETAILS');
END;
/
 
col WRL_TYPE for a10;
col WRL_PARAMETER for a50;
SELECT * FROM V\$ENCRYPTION_WALLET;
 
BEGIN
    dbms_output.put_line (CHR(10));
    DBMS_OUTPUT.PUT_LINE('Data Patch Verify');
END;
/
 
Col ACTION for a10;
Col ACTION_TIME for a35;
Col DESCRIPTION for a50
Col STATUS for a12
Col PATCH_TYPE for a20
select PATCH_ID, PATCH_TYPE, ACTION, ACTION_TIME, DESCRIPTION, STATUS from dba_registry_sqlpatch;
 
BEGIN
    dbms_output.put_line (CHR(10));
    DBMS_OUTPUT.PUT_LINE('Data Patch Registry');
END;
/
col COMP_NAME for a40
col STATUS for a10
select COMP_ID,COMP_NAME,VERSION,STATUS,MODIFIED from dba_registry;
 
--show parameter dump;
--show parameter pfile;
--create pfile='$LOG_DIR/init$ORACLE_SID.ora_$STAMP' from spfile;
--col NAME for a60
--select NAME from v\$controlfile;
--col FILE_NAME for a80
--select file_name from dba_data_files;
--select file_name from dba_temp_files;
--col MEMBER for a80
--select member from v\$logfile;
--select * from v\$recover_file;
--archive log list;
--col current_scn format 9999999999999
--select current_scn from v\$database;
--alter system switch logfile;
--alter system checkpoint;
--select count(*) from dba_objects;
--select count(*) from dba_objects where status='INVALID';
--select distinct status from dba_data_files;
--select distinct status from dba_objects;
 
e1
done
 
##Sending mail notification
echo "End-to-End DB Node Health : Cluster, ASM, DB & OS Overview : $EC2I - Check attached file for detail." |mailx -r abc@xyz.com -s " DB Node Comprehensive Status for $MCH : Cluster | ASM | DB | OS $1 logs " -a $PP_LOG/dbstat_"$MCH"_final_"$STAMP".log $Mailto;
