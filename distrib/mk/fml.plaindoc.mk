op: var/doc/op.jp

var/doc/op.jp: doc/smm/*wix
	env FML=${FML} $(SH) distrib/bin/DocReconfigure.op
