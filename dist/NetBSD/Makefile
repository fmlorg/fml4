all: sup

sup:
	eval echo `cat sup.conf` > /tmp/@@sup.conf
	sup -v /tmp/@@sup.conf
	rm -f /tmp/@@sup.conf

bsdmake:
	(cd src/usr.bin/make;make -f Makefile.boot)

clean:
	(cd src/usr.bin/make;make -f Makefile.boot clean)

