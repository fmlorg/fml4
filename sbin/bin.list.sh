(
	cat etc/list_of_use| grep '\.pl' | sed s@../../@@| tr ' ' '\012' 
	echo *.pl bin/*.p? sbin/*.p? libexec/*.pl| tr ' ' '\012'
	echo config.ph-fundamental-j
)|sort|uniq

