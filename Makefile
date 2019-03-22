#
# Makefile
# @author Yaroslav Pogrebnyak <yyyaroslav@gmail.com>
# @author Ievgen Ponomarenko <kikomdev@gmail.com>
#

.PHONY: update clean build build-all run package deploy test authors dist

export GOBIN := ${PWD}/bin
export GO111MODULE=on

NAME := gobetween
VERSION := $(shell cat VERSION)
LDFLAGS := -X main.version=${VERSION}

default: build

clean:
	@echo Cleaning up...
	@rm bin/* -rf
	@rm dist/* -rf
	@echo Done.

build:
	@echo Building...
	go build -v -o ./bin/$(NAME) -ldflags '${LDFLAGS}' .
	@echo Done.

build-static:
	@echo Building...
	CGO_ENABLED=1 go build -v -o ./bin/$(NAME) -ldflags '-s -w --extldflags "-static" ${LDFLAGS}' .
	@echo Done.

run: build
	./bin/$(NAME) -c ./config/${NAME}.toml

test:
	@go test -v ./test/...

install: build
	install -d ${DESTDIR}/usr/local/bin/
	install -m 755 ./bin/${NAME} ${DESTDIR}/usr/local/bin/${NAME}
	install ./config/${NAME}.toml ${DESTDIR}/etc/${NAME}.toml

uninstall:
	rm -f ${DESTDIR}/usr/local/bin/${NAME}
	rm -f ${DESTDIR}/etc/${NAME}.toml

authors:
	@git log --format='%aN <%aE>' | LC_ALL=C.UTF-8 sort | uniq -c -i | sort -nr | sed "s/^ *[0-9]* //g" > AUTHORS
	@cat AUTHORS

deps: 
	go mod download

clean-dist:
	rm -rf ./dist/${VERSION}

dist:
	@# For linux 386 when building on linux amd64 you'll need 'libc6-dev-i386' package
	@echo Building dist

	@#             os    arch  cgo ext
	@set -e ;\
	for arch in  "linux   386  0      "  "linux   amd64 1      "  \
				 "windows 386  0 .exe "  "windows amd64 0 .exe "  \
				 "darwin  386  0      "  "darwin  amd64 0      "; \
	do \
		set -- $$arch ; \
		echo "******************* $$1_$$2 ********************" ;\
		distpath="./dist/${VERSION}/$$1_$$2" ;\
		mkdir -p $$distpath ; \
		CGO_ENABLED=$$3 GOOS=$$1 GOARCH=$$2 go build -v -o $$distpath/$(NAME)$$4 -ldflags '-s -w --extldflags "-static" ${LDFLAGS}' . ;\
		cp "README.md" "LICENSE" "CHANGELOG.md" "AUTHORS" $$distpath ;\
		mkdir -p $$distpath/config && cp "./config/gobetween.toml" $$distpath/config ;\
		if [ "$$1" = "linux" ]; then \
			cd $$distpath && tar -zcvf ../../${NAME}_${VERSION}_$$1_$$2.tar.gz * && cd - ;\
		else \
			cd $$distpath && zip -r ../../${NAME}_${VERSION}_$$1_$$2.zip . && cd - ;\
		fi \
	done

build-container-latest: build-static
	@echo Building docker container LATEST
	docker build -t yyyar/gobetween .

build-container-tagged: build-static
	@echo Building docker container ${VERSION}
	docker build -t yyyar/gobetween:${VERSION} .
