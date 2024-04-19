. /vagrant_config/install.env

echo "******************************************************************************"
echo "Enable read-only Oracle home." `date`
echo "******************************************************************************"
cd $ORACLE_HOME/bin
./roohctl -enable 


echo "******************************************************************************"
echo "Configure network scripts." `date`
echo "******************************************************************************"

cat > ${READONLY_HOME}/network/admin/tnsnames.ora <<EOF
LISTENER${DB_DOMAIN_STR} = (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE1_FQ_HOSTNAME})(PORT = 1521))

${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR} =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE1_FQ_HOSTNAME})(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = ${ORACLE_SID})
    )
  )

${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE2_FQ_HOSTNAME})(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = ${ORACLE_SID})
    )
  )
EOF


cat > ${READONLY_HOME}/network/admin/listener.ora <<EOF
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE1_FQ_HOSTNAME})(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = ${NODE1_DB_UNIQUE_NAME})
      (SID_NAME = ${ORACLE_SID})
      (ORACLE_HOME = ${ORACLE_HOME})
    )
    (SID_DESC =
      (GLOBAL_DBNAME = ${NODE1_DB_UNIQUE_NAME}${DB_DOMAIN_STR})
      (SID_NAME = ${ORACLE_SID})
      (ORACLE_HOME = ${ORACLE_HOME})
    )
    (SID_DESC =
      (SID_NAME = ${ORACLE_SID})
      (GLOBAL_DBNAME = ${NODE1_DB_UNIQUE_NAME}_DGMGRL${DB_DOMAIN_STR})
      (ORACLE_HOME = ${ORACLE_HOME})
      (ENVS="TNS_ADMIN=${ORACLE_HOME}/network/admin")
    )
  )

ADR_BASE_LISTENER = ${ORACLE_BASE}
INBOUND_CONNECT_TIMEOUT_LISTENER=400
EOF


cat > ${READONLY_HOME}/network/admin/sqlnet.ora <<EOF
SQLNET.INBOUND_CONNECT_TIMEOUT=400
EOF

# Adding the Native Network Encryption was suggested by Claudia H�ffer, Peter Wahl and Richard Evans.
# I've made it optional.
if [ "${NATIVE_NETWORK_ENCRYPTION}" = "true" ]; then
  cat >> ${READONLY_HOME}/network/admin/sqlnet.ora <<EOF
SQLNET.ENCRYPTION_SERVER=REQUIRED
SQLNET.ENCRYPTION_TYPES_SERVER=(AES256)

SQLNET.ENCRYPTION_CLIENT=REQUIRED
SQLNET.ENCRYPTION_TYPES_CLIENT=(AES256)

SQLNET.CRYPTO_CHECKSUM_SERVER=REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_SERVER = (SHA256)

SQLNET.CRYPTO_CHECKSUM_CLIENT=REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_CLIENT = (SHA256)
EOF
fi

if [ "${DB_DOMAIN}" != "" ]; then
  cat >> ${READONLY_HOME}/network/admin/sqlnet.ora <<EOF
NAMES.DEFAULT_DOMAIN=${DB_DOMAIN}
EOF
fi

echo "******************************************************************************"
echo "Start listener." `date`
echo "******************************************************************************"
lsnrctl stop
lsnrctl start
lsnrctl status

echo "******************************************************************************"
echo "Create database." `date`
echo "******************************************************************************"
dbca -silent -createDatabase                                                 \
  -templateName General_Purpose.dbc                                          \
  -sid ${ORACLE_SID}                                                         \
  -responseFile NO_VALUE                                                     \
  -gdbname ${DB_NAME}${DB_DOMAIN_STR}                                        \
  -characterSet AL32UTF8                                                     \
  -sysPassword ${SYS_PASSWORD}                                               \
  -systemPassword ${SYS_PASSWORD}                                            \
  -createAsContainerDatabase true                                            \
  -numberOfPDBs 1                                                            \
  -pdbName ${PDB_NAME}                                                       \
  -pdbAdminPassword ${PDB_PASSWORD}                                          \
  -databaseType MULTIPURPOSE                                                 \
  -automaticMemoryManagement false                                           \
  -totalMemory 2048                                                          \
  -storageType FS                                                            \
  -datafileDestination "${DATA_DIR}"                                         \
  -redoLogFileSize 50                                                        \
  -emConfiguration NONE                                                      \
  -initparams db_name=${DB_NAME},db_unique_name=${NODE1_DB_UNIQUE_NAME}      \
  -ignorePreReqs

echo "******************************************************************************"
echo "Set the PDB to auto-start." `date`
echo "******************************************************************************"
sqlplus / as sysdba <<EOF
alter system set db_create_file_dest='${DATA_DIR}';
alter system set db_create_online_log_dest_1='${DATA_DIR}';
alter pluggable database ${PDB_NAME} save state;
alter system reset local_listener;
exit;
EOF

echo "******************************************************************************"
echo "Configure archivelog mode, standby logs and flashback." `date`
echo "******************************************************************************"
mkdir -p ${ORACLE_BASE}/fast_recovery_area

dgmgrl / as sysdba <<EOF
prepare database for data guard
  with db_unique_name is ${NODE1_DB_UNIQUE_NAME}
  db_recovery_file_dest is "${ORACLE_BASE}/fast_recovery_area"
  db_recovery_file_dest_size is 20g
  restart;
exit;
EOF
