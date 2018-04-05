MoinMoin on Raspberry Pi (Docker)
=============

[![Build Status](https://travis-ci.org/BruceFrankWang/rpi-moinmoin.svg?branch=master)](https://travis-ci.org/BruceFrankWang/rpi-moinmoin)

A Docker image with the Moinmoin wiki engine, uwsgi and nginx.

You can automatically download and run this with the following command
    
    sudo docker run -it -p 80:80 -v /srv/wiki:/srv/wiki --name MY_WIKI brucefrankwanh/rpi-moinmoin
    
Default superuser is `WikiAdmin`, you activate him by creating a new user named `WikiAdmin` and set your prefered password.

The pages are mounted as volume, so you can take backup of the system from the host.

You can detach from the container session with `CTRL-Q+P` and then `CTRL-C`
