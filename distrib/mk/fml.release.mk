__in_release_branch:
	@ if [ X$$IN_RELEASE_BRANCH = X ]; then \
		echo please define IN_RELEASE_BRANCH;\
		exit 1;\
	fi
