.PHONY: test app install smoke clean

test:
	./scripts/test.sh

app:
	./scripts/build-app.sh

install: app
	./scripts/install.sh

smoke: app
	./scripts/smoke-cli.sh

clean:
	rm -rf .build dist
