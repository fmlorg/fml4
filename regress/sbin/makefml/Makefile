all: log.bye log.off
test: all

log.bye: bye_test.sh
	./bye_test.sh -c bye | tee log.bye 

log.off:  bye_test.sh
	./bye_test.sh -c off | tee log.off

clean:
	rm -f log.bye log.off
