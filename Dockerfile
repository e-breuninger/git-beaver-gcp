FROM gitbeaver/release
ENV GOOGLE_APPLICATION_CREDENTIALS /secret/terraform-service-account.json
COPY gitbeaver/ /workdir/
ENTRYPOINT ["/gitbeaver", "workdir=/workdir", "main=startserver"]