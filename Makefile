HOST ?= registry.duckdns.org
DOCKER_HOST ?= tcp://$(HOST):2375
DOCKER_CERT_PATH ?= ~/.docker
DOCKER_TLS_VERIFY ?= 1
DOCKER_REGISTRY_CERT_PATH ?= ../docker-registry/certs


all: gen-ca-key server-keys client-keys install

server-keys: gen-server-csr sign-server-csr

client-keys: gen-client-csr sign-client-csr

gen-ca-key:
	openssl genrsa -aes256 -out ca-key.pem 4096
	openssl req -new -x509 -days 365 -key ca-key.pem -sha256 -out ca.pem

gen-server-csr:
	openssl genrsa -out server-key.pem 4096
	openssl req -subj "/CN=$(HOST)" -sha256 -new -key server-key.pem -out server.csr
	echo subjectAltName = IP:127.0.0.1 > extfile.cnf

sign-server-csr:
	openssl x509 -req -days 365 -sha256 -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -extfile extfile.cnf

gen-client-csr:
	openssl genrsa -out key.pem 4096
	openssl req -subj '/CN=client' -new -key key.pem -out client.csr
	echo extendedKeyUsage = clientAuth > extfile.cnf

sign-client-csr:
	openssl x509 -req -days 365 -sha256 -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out cert.pem -extfile extfile.cnf

permission:
	chmod -v 0400 ca-key.pem key.pem server-key.pem
	chmod -v 0444 ca.pem server-cert.pem cert.pem

install: permission
	cp -vf {ca,cert,key,ca-key,server-key,server-cert}.pem $(DOCKER_REGISTRY_CERT_PATH)

install-server: permission
	sudo mkdir -pv /var/docker
	sudo cp -vf ca-key.pem server-key.pem server-cert.pem /var/docker

client-install:
	mkdir -pv ~/.docker
	cp -vf {ca,cert,key}.pem $(DOCKER_CERT_PATH)
	export DOCKER_HOST=$(DOCKER_HOST)
	export DOCKER_TLS_VERIFY=$(DOCKER_TLS_VERIFY)
	export DOCKER_CERT_PATH=$(DOCKER_CERT_PATH)

clean:
	rm -rf *.{pem,csr,slr,cnf}
