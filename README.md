# e-breuninger/git-beaver

## Purpose

This repository builds a GitBeaver docker image and installs it into an existing GCP project as cloud run service.
GitBeaver is an open source git-ops tool that can be 
used to combine information from multiple git repositories in a programmatic fashion.
Further information on the GitBeaver project can be found [here](TODO).

## Docker image

The [docker image](Dockerfile) is derived from a specific curated release provided also 
by Breuninger (in [this repository]()). NOTE: This is currently not true, as long as core development 
is still ongoing. We do not use a release version tag, yet, rather take the lates image 
from branch "main".

## Links

Useful urls:

 * Logs: https://console.cloud.google.com/run/detail/europe-west3/git-beaver/logs?project=breuninger-core-gitbeaver
