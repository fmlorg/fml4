.if ! exists(CHANGES)
__BUILD_INIT__ += __touch_info
.endif

.if ! exists(conf/release_version)
__BUILD_INIT__ += __init_conf
__BUILD_END__  += __note_conf
.endif

.if ! exists(${COMPILE_DIR}/release_version)
__BUILD_INIT__ += __init_conf
__BUILD_END__  += __note_conf
.endif

World: world
world: build

__touch_info:
	echo ${FML}
	touch CHANGES

__init_conf:
	echo `cat conf/release`" (`date +%C%y%m%d`)" > conf/release_version
	@ echo ""; cat conf/release_version ; echo "";

__note_conf:
	@ echo ""
	@ echo --- see /tmp/fml.note ---
	@ cat /tmp/fml.note
	@ echo ""

__init_build:
	@ env FML=${FML} ${MAKE} -f distrib/mk/fml.sys.mk __setup

init_build: __init_build ${__BUILD_INIT__}
	echo COMPILE_DIR ${COMPILE_DIR}
