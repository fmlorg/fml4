#
# $FML$
#

all: help

help:
	echo "make scan"
	echo "make symlink"

scan:
	@ ( cd ../..; make scan )
	@ cp ../../__scan__ .

link:	clean_link _link

clean_link:
	for file in * ; do  test -h $$file && rm -f $$file || true ; done

_link:
	ln -s ../../kern .
	ln -s ../../proc .
	ln -s ../../sbin .
	ln -s ../../etc  .
	ln -s ../../cf   .
	ln -s /var/spool/ml/elena/log .

clean:
	@ (cd ../..; make clean )
