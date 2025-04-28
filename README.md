# docker-compose for several stacks and projects

# install compose plugin on docker

source: https://github.com/docker/compose?tab=readme-ov-file#linux

download from: https://github.com/docker/compose/releases

or use docker compose plugin: https://docs.docker.com/compose/install

# portainer

* A dashboard to monitoring over docker contaiers, images etc

`docker-compose -f Infrastructure/portainer/docker-compose.yml up -d`

docker run -it --cpus=0.2 -e DEBUG=cypress:launcher:* --entrypoint=cypress cypress/included:13.10.0 info
