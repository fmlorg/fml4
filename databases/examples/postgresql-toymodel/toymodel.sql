create table ml (ml text,
	file text, 
	address text,
	option text);

insert into ml
values ('elena', 'actives', 'rudo@nuinui.fml.org', '');
insert into ml
values ('elena', 'members', 'rudo@nuinui.fml.org', '');

insert into ml
values ('elena', 'actives', 'kenken@nuinui.fml.org', '');
insert into ml
values ('elena', 'members', 'kenken@nuinui.fml.org', '');

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

drop table ml ;
