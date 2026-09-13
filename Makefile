.PHONY: agent app bundle sign notarize test lint run clean dmg release

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

dmg: bundle sign
	sh scripts/dmg.sh

notarize:
	sh scripts/notarize.sh

release: bundle sign dmg


run: bundle sign
	open build/NetTracker.app

clean:
	rm -rf build
