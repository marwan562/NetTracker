.PHONY: agent app bundle sign notarize test lint run clean

agent:
	sh scripts/build.sh

test:
	cd agent && go test -v ./...

lint:
	cd agent && golangci-lint run ./...

app:
	sh scripts/bundle.sh

bundle: agent app

sign:
	sh scripts/sign.sh

notarize:
	sh scripts/notarize.sh

release: bundle sign notarize

run: bundle sign
	open build/NetTracker.app

clean:
	rm -rf build
