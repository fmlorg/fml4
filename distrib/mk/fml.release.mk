__init_snapshot:
	@ if [ X$$BRANCH_SNAPSHOT = X ]; then \
		echo please define BRANCH_SNAPSHOT;\
		exit 1;\
	fi
