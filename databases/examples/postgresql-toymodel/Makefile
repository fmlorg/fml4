all: test

test:
	cat toymodel.sql | psql -e -E -h postgres fml

clean:
	cat drop.sql | psql -e -E -h postgres fml
