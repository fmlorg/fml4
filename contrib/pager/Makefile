all:
	rm -f db/table
	perl conv.pl -k 1 db/kuten-1 >> db/table
	perl conv.pl -k 2 db/kuten-2 >> db/table
	perl conv.pl -k 3 db/kuten-3 >> db/table
	perl conv.pl -k 6 db/kuten-6 >> db/table
	perl conv.pl -k 7 db/kuten-7 >> db/table
	perl conv.pl -k 8 db/kuten-8 >> db/table
	perl table2assoc.pl db/table > db/assoc.pl

dist:
	rcp euc2jiskuten.pl README eriko:~/.ftp/pager-calling

clean:
	gar *~

CONTRIB: contrib

contrib:
	
