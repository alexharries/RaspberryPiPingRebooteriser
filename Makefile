relay:relay.o
	gcc relay.c -o relay -lwiringPi
clear:
	rm -rf *.o relay 
