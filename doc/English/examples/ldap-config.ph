# Database general definition
$USE_DATABASE            = 1;
$DATABASE_METHOD         = 'LDAP';
$DATABASE_DRIVER         = 'databases/ldap/toymodel.pl';

# LDAP specific
$LDAP_SERVER_HOST        = "ldap.fml.org";
$LDAP_SEARCH_BASE        = 'cn=elena, dc=fml, dc=org';
$LDAP_SEARCH_BIND        = "cn=root, dc=fml, dc=org";
$LDAP_SEARCH_PASSWORD    = $NULL;
$LDAP_SEARCH_CERT_FILE   = $NULL;
$LDAP_QUERY_FILTER       = "(objectclass=*)";

1;
