Crete secrets:
	encryptionkey=$$(docker run --rm docker.elastic.co/kibana/kibana:$(STACK_VERSION) /bin/sh -c "< /dev/urandom tr -dc _A-Za-z0-9 | head -c50") && \
	kubectl create secret generic kibana-savedobject-key --from-literal=encryptionkey=$$encryptionkey