DBDIR   = ../../../databases
SOURCES = postgresql-toymodel.pl mysql-toymodel.pl ldap-toymodel.pl
CONFIGS = postgresql-config.ph mysql-config.ph ldap-config.ph


all: update

update: $(SOURCES) $(CONFIGS)

postgresql-toymodel.pl: ${DBDIR}/postgresql/toymodel.pl
	cp ${DBDIR}/postgresql/toymodel.pl postgresql-toymodel.pl

mysql-toymodel.pl: ${DBDIR}/mysql/toymodel.pl
	cp ${DBDIR}/mysql/toymodel.pl	  mysql-toymodel.pl

ldap-toymodel.pl: ${DBDIR}/ldap/toymodel.pl
	cp ${DBDIR}/ldap/toymodel.pl	  ldap-toymodel.pl



postgresql-config.ph: ${DBDIR}/examples/postgresql-toymodel/sql_config.ph
	cp ${DBDIR}/examples/postgresql-toymodel/sql_config.ph \
		postgresql-config.ph

mysql-config.ph: ${DBDIR}/examples/mysql-toymodel/sql_config.ph
	cp ${DBDIR}/examples/mysql-toymodel/sql_config.ph \
		mysql-config.ph

ldap-config.ph: ${DBDIR}/examples/ldap-toymodel/ldap_config.ph
	cp ${DBDIR}/examples/ldap-toymodel/ldap_config.ph \
		ldap-config.ph
