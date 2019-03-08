# docker-powerdns-slave
powerdns slave server

Designed to run a slave server which will connect to a hidden master/supermaster.

Domain updates are done via notify and AFXR

Very low resource usage, with 150 zones, approx memory usage is 16MB

View **docker-compose-sample.yml** in the source repository for usage

# features
Alpine latest with s6

Optimised sqlite3 backend (foreign-keys and synchronous=0)

graceful shutdowns with pdns_control

Supported modes: slave, master, supermaster (or a combination)

Optional Web and API

Debug output

Powerdns Guardian Enabled

Check for a corrupted sqlite database, reinitialize database if corrupted

Optimise (vacuum) sqlite database before launching

## Default Enviromental Options
SQLITEDB_FULLPATH=/data/pdns.sqlite

SQLITEDB_DELETE_IF_CORRUPT=yes

SQLITEDB_VACUUM=yes

SLAVE=yes

MASTER=no

SUPERMASTER=no

SLAVE_RENOTIFY=no

SLAVE_CYCLE_INTERVAL=10

DEFAULT_TTL=3600

DEFAULT_SOA_NAME=fullhostname

DEFAULT_SOA_MAIL=admin.hostname

ALLOW_AXFR_IPS=127.0.0.0/8

ALLOW_NOTIFY_FROM=0.0.0.0/0 **or will use the supermasters ip addresses**

DNSSEC=yes

WEBSERVER=yes

WEBSERVER_ALLOW_FROM=0.0.0.0/0

WEBSERVER_PASSWORD=no

API_KEY=no

DEBUG=yes

GUARDIAN=yes

ALLOW_UNSIGNED_SUPERMASTER=yes

ALLOW_UNSIGNED_NOTIFY=yes

CLEAN_PDNS_SUPERMASTERS=yes

## Extra Enviromental Options
ALSO_NOTIFY=11.11.11.11 22.22.22.22

PDNS_SUPERMASTERS=11.11.11.11 ns1.domain.com 22.22.22.22 ns2.domain.com
