create table ml (ml text,
	file text, 
	address text,
	off int,
	options text);

insert into ml
values ('elena', 'actives', 'fukachan@sapporo.iij.ad.jp', 0, '');
insert into ml
values ('elena', 'members', 'fukachan@sapporo.iij.ad.jp', 0, '');

insert into ml
values ('elena', 'actives', 'fukachan@fml.org', 0, '');
insert into ml
values ('elena', 'members', 'fukachan@fml.org', 0, '');


select oid,* from ml ;

select oid,* from ml 
	where address = 'kenken@nuinui.fml.org'
		and
	file = 'actives' ;

select oid,* from ml 
	where address = 'fukachan@nuinui.fml.org'
		and
	file = 'actives' ;

\copy ml to /tmp/sql.dat

-- drop table ml ;
