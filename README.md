Docker igalerie
============

Docker image to have the [igalerie](https://www.igalerie.org/) application

Quick Start
===========

```bash
docker run --name some-igalerie -p 8080:80 -d mnival/igalerie
```

It is advisable to mount a volume to preserve the data. In this case use:
```bash
docker run --name some-igalerie -p 8080:80 -v $(pwd)/customs:/var/www/html/customs -d mnival/igalerie
```

Interfaces
===========

Ports
-------
* 80 -- Apache (Web Interface)

Volumes
-------

/var/www/html/customs -- igalerie data

Maintainer
==========

Please submit all issues/suggestions/bugs via https://github.com/mnival/docker-igalerie
