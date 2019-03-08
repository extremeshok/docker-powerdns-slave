#!/usr/bin/env bash

## enable case insensitve matching
shopt -s nocaseglob

# Create config file from template
#envtpl < /etc/powerdns/pdns.conf.tpl > /etc/powerdns/pdns.conf

## DEFAULTS
SQLITEDB_FULLPATH=${SQLITEDB_FULLPATH:-/data/pdns.sqlite}
SQLITEDB_DELETE_IF_CORRUPT=${SQLITEDB_DELETE_IF_CORRUPT:-yes}
SQLITEDB_VACUUM=${SQLITEDB_VACUUM:-yes}
MASTER=${MASTER:-no}
SUPERMASTER=${SUPERMASTER:-no}
SLAVE_RENOTIFY=${SLAVE_RENOTIFY:-no}
SLAVE_CYCLE_INTERVAL=${SLAVE_CYCLE_INTERVAL:-10}
DEFAULT_TTL=${DEFAULT_TTL:-3600}
HOSTNAME=${HOSTNAME:-$(hostname -f)}
DEFAULT_SOA_NAME=${DEFAULT_SOA_NAME:-$HOSTNAME}
DEFAULT_SOA_MAIL=${DEFAULT_SOA_MAIL:-$(echo "admin.${HOSTNAME#*\.}")}
ALLOW_AXFR_IPS=${ALLOW_AXFR_IPS:-127.0.0.0/8}
ALSO_NOTIFY=${ALSO_NOTIFY}
ALLOW_NOTIFY_FROM=${ALLOW_NOTIFY_FROM:-default}
DNSSEC=${DNSSEC:-yes}
WEBSERVER=${WEBSERVER:-yes}
WEBSERVER_ALLOW_FROM=${WEBSERVER_ALLOW_FROM:-0.0.0.0/0,::/0}
WEBSERVER_PASSWORD=${WEBSERVER_PASSWORD:-no}
API_KEY=${API_KEY:-no}
DEBUG=${DEBUG:-no}
GUARDIAN=${GUARDIAN:-yes}
ALLOW_UNSIGNED_SUPERMASTER=${ALLOW_UNSIGNED_SUPERMASTER:-yes}
ALLOW_UNSIGNED_NOTIFY=${ALLOW_UNSIGNED_NOTIFY:-yes}
CLEAN_PDNS_SUPERMASTERS=${CLEAN_PDNS_SUPERMASTERS:-yes}

## RUNTIME OPTIONS
OPTION_ARRAY=()
OPTION_ARRAY+=("--setuid=pdns")
OPTION_ARRAY+=("--setgid=pdns")
OPTION_ARRAY+=("--version-string=anonymous")

OPTION_ARRAY+=("--launch=gsqlite3")
OPTION_ARRAY+=("--gsqlite3-database=${SQLITEDB_FULLPATH}")
OPTION_ARRAY+=("--gsqlite3-pragma-foreign-keys")
OPTION_ARRAY+=("--gsqlite3-pragma-synchronous=0")
OPTION_ARRAY+=("--default-soa-name=${DEFAULT_SOA_NAME}")
OPTION_ARRAY+=("--allow-axfr-ips=${ALLOW_AXFR_IPS}")
OPTION_ARRAY+=("--daemon=no --no-config")

integer_regex='^[0-9]+$'
if [[ "$SLAVE_CYCLE_INTERVAL" =~ $integer_regex ]] ; then
  OPTION_ARRAY+=("--slave-cycle-interval=${SLAVE_CYCLE_INTERVAL}")
else
  echo "ERROR: SLAVE_CYCLE_INTERVAL must be an integer"
  exit 1
fi
if [[ "$DEFAULT_TTL" =~ $integer_regex ]] ; then
  OPTION_ARRAY+=("--default-ttl=${DEFAULT_TTL}")
else
  echo "ERROR: DEFAULT_TTL must be an integer"
  exit 1
fi

# enable dnssec
if [[ "${DNSSEC}" == "true" ]] || [[ "${DNSSEC}" == "yes" ]] ; then
  OPTION_ARRAY+=("--gsqlite3-dnssec=yes")
fi

# Enable APIKEY and/or webserver
if [[ "${API_KEY}" != "true" ]] && [[ "${API_KEY}" != "yes" ]] && [[ "${API_KEY}" != "false" ]]  && [[ "${API_KEY}" != "no" ]] ; then
  WEBSERVER="yes"
  OPTION_ARRAY+=("--api=yes")
  OPTION_ARRAY+=("--api-key=${API_KEY}")
fi
if [[ "${WEBSERVER}" == "true" ]] || [[ "${WEBSERVER}" == "yes" ]] ; then
  OPTION_ARRAY+=("--webserver=yes")
  OPTION_ARRAY+=("--webserver-address=0.0.0.0")
  OPTION_ARRAY+=("--webserver-port=8083")
  OPTION_ARRAY+=("--webserver-allow-from=${WEBSERVER_ALLOW_FROM}")
  if [[ "${WEBSERVER_PASSWORD}" != "true" ]] && [[ "${WEBSERVER_PASSWORD}" != "yes" ]] && [[ "${WEBSERVER_PASSWORD}" != "false" ]]  && [[ "${WEBSERVER_PASSWORD}" != "no" ]] ; then
    OPTION_ARRAY+=("--webserver-password=${WEBSERVER_PASSWORD}")
  fi
  if [[ "${DEBUG}" == "true" ]] || [[ "${DEBUG}" == "yes" ]] ; then
    OPTION_ARRAY+=("--webserver-print-arguments=yes")
  fi
else
  OPTION_ARRAY+=("--webserver=no")
fi

# Disable unsigned supermaster
if [[ "${ALLOW_UNSIGNED_SUPERMASTER}" == "false" ]] || [[ "${ALLOW_UNSIGNED_SUPERMASTER}" == "no" ]] ; then
  OPTION_ARRAY+=("--allow-unsigned-supermaster=no")
fi
# Disable unsigned notify
if [[ "${ALLOW_UNSIGNED_NOTIFY}" == "false" ]] || [[ "${ALLOW_UNSIGNED_NOTIFY}" == "no" ]] ; then
  OPTION_ARRAY+=("--allow-unsigned-notify=no")
fi

# Enable guardian process
if [[ "${GUARDIAN}" == "true" ]] || [[ "${GUARDIAN}" == "yes" ]] ; then
  OPTION_ARRAY+=("--guardian=yes")
fi

# Enable showing of dns queries if debugging enabled
if [[ "${DEBUG}" == "true" ]] || [[ "${DEBUG}" == "yes" ]] ; then
  OPTION_ARRAY+=("--log-dns-queries=yes")
  OPTION_ARRAY+=("--loglevel=5")
fi

# Master/Slave management
if [[ "${MASTER}" == "true" ]] || [[ "${MASTER}" == "yes" ]] || [[ "${SUPERMASTER}" == "true" ]] || [[ "${SUPERMASTER}" == "yes" ]]; then
  if [[ "${SUPERMASTER}" == "true" ]] || [[ "${SUPERMASTER}" == "yes" ]]; then
    echo "SUPERMASTER mode enabled"
    OPTION_ARRAY+=("--supermaster=yes")
  fi
  echo "MASTER mode enabled"
  OPTION_ARRAY+=("--master=yes")
  OPTION_ARRAY+=("--slave-renotify=${SLAVE_RENOTIFY}")
fi
echo "SLAVE mode enabled"
OPTION_ARRAY+=("--slave=yes")
if [[ "${ALLOW_NOTIFY_FROM}" == "default" ]] ; then
  if [[ -n $PDNS_SUPERMASTERS ]]; then
    supermaster_ip_list=""
    for i in $PDNS_SUPERMASTERS; do
      IFS=: read -r ipaddress ipname <<<"$i"
      supermaster_ip_list+=",$ipaddress"
    done
    OPTION_ARRAY+=("--allow-notify-from=${supermaster_ip_list#*,}")
  else
    OPTION_ARRAY+=("--allow-notify-from=0.0.0.0/0,::/0")
  fi
elif [[ -n ${ALLOW_NOTIFY_FROM} ]]; then
  OPTION_ARRAY+=("--allow-notify-from=${ALLOW_NOTIFY_FROM}")
else
  echo "ALLOW_NOTIFY_FROM is not set, please configure this or add a supermaster."
  exit 1
fi

# also-notify
if [[ -n ${ALSO_NOTIFY} ]] ; then
  OPTION_ARRAY+=("--also-notify=$ALSO_NOTIFY")
fi

# default-soa-email
if [[ -n ${DEFAULT_SOA_MAIL} ]] ; then
  OPTION_ARRAY+=("--default-soa-mail=${DEFAULT_SOA_MAIL}")
fi

######## SQLite Management
if [[ -e ${SQLITEDB_FULLPATH} ]] ; then
  echo "Database exist, Assuming this is not the first launch"
  # check the sqlite db is valid
  result="$(sqlite3 ${SQLITEDB_FULLPATH} "pragma integrity_check;")"
  if [[ "$result" != "ok" ]] ; then
    if [[ "${SQLITEDB_DELETE_IF_CORRUPT}" == "true" ]] || [[ "${SQLITEDB_DELETE_IF_CORRUPT}" == "yes" ]] ; then
      echo "Warning: Removing corrupt database: ${SQLITEDB_FULLPATH}"
      rm -f ${SQLITEDB_FULLPATH}
    else
      echo "ERROR: Corrupt database: ${SQLITEDB_FULLPATH}"
      echo "$result"
      exit 1
    fi
  elif [[ "${SQLITEDB_VACUUM}" == "true" ]] || [[ "${SQLITEDB_VACUUM}" == "yes" ]] ; then
    echo "Optimising database ${SQLITEDB_FULLPATH}"
    sqlite3 ${SQLITEDB_FULLPATH} "VACUUM;"
  fi
fi

# Init the sqlite db if it does not exist
if [[ ! -e ${SQLITEDB_FULLPATH} ]] ; then
  echo "Creating database: ${SQLITEDB_FULLPATH}"
  mkdir -p "${SQLITEDB_FULLPATH%/*}"
  cat /etc/pdns/schema.sqlite3.sql | sqlite3 ${SQLITEDB_FULLPATH}
  if [[ ! -e ${SQLITEDB_FULLPATH} ]] ; then
    echo "ERROR: Failed to create ${SQLITEDB_FULLPATH}"
    exit 1
  fi
fi

# Truncate / empty the supermasters table
if [[ "${CLEAN_PDNS_SUPERMASTERS}" == "true" ]] || [[ "${CLEAN_PDNS_SUPERMASTERS}" == "yes" ]] ; then
  echo "Removing all supermasters from database"
  sqlite3 ${SQLITEDB_FULLPATH} "DELETE FROM supermasters;"
fi

# Recreate list of Supermasters.
if [[ -n $PDNS_SUPERMASTERS ]]; then
  echo "PDNS_SUPERMASTERS: $PDNS_SUPERMASTERS"
  for i in $PDNS_SUPERMASTERS; do
    IFS=: read -r ipaddress ipname <<<"$i"
    echo "Adding supermaster ${ipname} with ipaddress ${ipaddress}"
    sqlite3 ${SQLITEDB_FULLPATH} "replace into supermasters values ('${ipaddress}','${ipname}', 'admin');"
  done
fi

# enforce correct permissions
chown -R pdns:pdns ${SQLITEDB_FULLPATH%/*}

# Start PowerDNS
echo "/usr/sbin/pdns_server ${OPTION_ARRAY[*]}"

#enable graceful shutdowns, this is done in the finish script
#trap "/usr/bin/pdns_control --no-config --socket-dir=/var/run/ quit" SIGHUP SIGINT SIGTERM

#start the server
# shellcheck disable=SC2128,SC2068
/usr/sbin/pdns_server ${OPTION_ARRAY[@]}
