.PHONY: all build install uninstall clean

all: build

build:
	./Scripts/build.sh

install: build
	./Scripts/install.sh

uninstall:
	./Scripts/uninstall.sh

clean:
	rm -rf build .build
