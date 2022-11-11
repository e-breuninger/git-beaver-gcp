FROM gitbeaver/release
COPY gitbeaver/ /workdir/
ENTRYPOINT ["/gitbeaver", "workdir=/workdir", "main=startserver"]