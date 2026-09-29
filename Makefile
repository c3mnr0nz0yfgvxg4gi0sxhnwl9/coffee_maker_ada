
all : coffee_maker

clean :
	-rm *.o *.ali

coffee_maker : coffee_maker.adb
	gnatmake coffee_maker.adb
