PERL        = perl 
REGRESS     = $(PERL) ../../regress/www/global_variable_check.pl
SHOW_CONFIG = $(PERL) ../../regress/www/showConfig.pl

all: regress

regress:
	@ echo "--- %Config in SecureP"
	@ (cd ../../www/lib; $(SHOW_CONFIG) libcgi_cleanup.pl|sort|uniq)
	@ echo ""
	@ echo "--- regression check"
	@ (cd ../../www/lib; cat lib*pl | $(REGRESS) )
	@ echo ""
