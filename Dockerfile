FROM alpine:3.18

ARG TARGETARCH
RUN apk add --no-cache curl \
    && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${TARGETARCH}/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER 65534:65534

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["echo", "{{PUBLIC_IP}}"]