#!/bin/bash
# Docker
# Author: Osama Zarraa

RedColor='\033[0;31m'
WhiteColor='\033[0m'

DAEMON_PORT=2375
DAEMON_PORT_SSL=2376

redInput() {
    read -p "$1 > " value
    echo "$value"
}

# Docker
#################
dockerInstall() {
    sudo apt install docker-compose
}

dockerRestart() {
    sudo service docker restart
}

# Images
#################
dockerImages() {
    sudo docker image ls
}

dockerImagesRemove() {
    sudo docker rmi $(sudo docker images -a -q)
}

dockerImageBuild() {
    name=$(redInput "Image tag: ")
    if [ "$name" == "" ]; then
        return
    fi
    path=$(redInput "Image path (absolute path): ")
    if [ "$path" == "" ]; then
        return
    fi

    cd $path
    sudo docker build -t $name .
    cd $PWD

    ret=$(redInput "Save image to current directory? (y/n)")
    if [ "$ret" == "y" ]; then
        sudo docker save -o $(pwd)/image.tar $name
    fi
}

# Containers
#################
dockerContainers() {
    sudo docker container ls
}

dockerContainersStop() {
    sudo docker stop $(sudo docker ps -aq)
}

dockerContainersRemove() {
    dockerContainersStop
    sudo docker rm $(sudo docker ps -aq)
}

# Networks
#################
dockerNetworks() {
    sudo docker network ls
}

# Volumes
#################
dockerVolumes() {
    sudo docker volume ls
}

dockerVolumesPrune() {
    sudo docker volume prune
}

# Daemon
#################
dockerDaemonInstall() {
    useSelfSigned=$(redInput "Use self signed certificate? (y/n): ")
    if [ "$useSelfSigned" = 'y' ]; then
        dockerDaemonCertificateCreate
    fi
    dockerDaemonServiceCreate
}

dockerDaemonServiceCreate() {
    sudo mkdir -p /etc/systemd/system/docker.service.d
    echo "[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --tlsverify --tlscacert=/etc/docker/ssl/ca.pem --tlscert=/etc/docker/ssl/server-cert.pem --tlskey=/etc/docker/ssl/server-key.pem -H unix:// -H=tcp://0.0.0.0:$DAEMON_PORT_SSL" >/etc/systemd/system/docker.service.d/options.conf

    sudo systemctl daemon-reload
    dockerRestart
}

dockerDaemonCertificateCreate() {
    HOST=$(redInput "Host of this server: ")
    if [ "$HOST" = "" ]; then
        return
    fi
    # create folders
    sudo mkdir -p /etc/docker/ssl
    sudo mkdir -p ~/.docker

    # create CA
    dockerDaemonCertificateCACreate

    # create Server key
    dockerDaemonCertificateServerCreate $HOST

    # create config for clients
    echo extendedKeyUsage = clientAuth >~/.docker/extfile-client.cnf
    sudo rm -v ~/.docker/*.srl ~/.docker/*.csr
}

dockerDaemonCertificateCACreate() {
    openssl genrsa -aes256 -out ~/.docker/ca-key.pem 4096
    openssl req -new -x509 -days 365 -key ~/.docker/ca-key.pem -sha256 -out ~/.docker/ca.pem
    sudo cp ~/.docker/ca.pem /etc/docker/ssl
}

dockerDaemonCertificateServerCreate() {
    echo extendedKeyUsage = serverAuth >>/etc/docker/ssl/extfile.cnf
    echo subjectAltName = DNS:$1,IP:127.0.0.1 >>/etc/docker/ssl/extfile.cnf

    openssl genrsa -out /etc/docker/ssl/server-key.pem 4096
    openssl req -subj "/CN=$1" -sha256 -new -key /etc/docker/ssl/server-key.pem -out /etc/docker/ssl/server.csr
    openssl x509 -req -days 365 -sha256 -in /etc/docker/ssl/server.csr -CA ~/.docker/ca.pem -CAkey ~/.docker/ca-key.pem -CAcreateserial -out /etc/docker/ssl/server-cert.pem -extfile /etc/docker/ssl/extfile.cnf
}

dockerDaemonCertificateClientAdd() {
    NAME=$(redInput "client name: ")
    if [ "$NAME" = "" ]; then
        return
    fi

    sudo mkdir -p ~/.docker/$NAME
    FolderPath=~/.docker/$NAME

    openssl genrsa -out $FolderPath/key.pem 4096
    openssl req -subj '/CN=client' -new -key $FolderPath/key.pem -out $FolderPath/client.csr
    openssl x509 -req -days 365 -sha256 -in $FolderPath/client.csr -CA ~/.docker/ca.pem -CAkey ~/.docker/ca-key.pem -CAcreateserial -out $FolderPath/cert.pem -extfile ~/.docker/extfile-client.cnf
    sudo rm -v $FolderPath/client.csr

    openssl pkcs12 -export -out $FolderPath/$NAME.pfx -inkey $FolderPath/key.pem -in $FolderPath/cert.pem
}

# bench for security
#################
dockerBenchForSecurity() {
    git clone https://github.com/docker/docker-bench-security.git
    cd docker-bench-security
    sudo docker-compose run --rm docker-bench-security
    sudo rm -rf docker-bench-security
}

# Secrets
#################
dockerSecrets() {
    sudo docker secret ls
}

dockerSecretsAdd() {
    openssl rand -base64 20 | docker secret create mysql_password -
}

# Start
########################################################
showMenu() {
    format="${RedColor}%-30s ${WhiteColor}%-10s\n"
    printf "$format" "install" "install docker"
    printf "$format" "restart" "restart docker"
    printf "$format" "daemon:install" "install docker daemon"
    printf "$format" "daemon:clients:add" "add a client certificate"
    printf "$format" "images" "show docker images"
    printf "$format" "images:remove" "remove docker images"
    printf "$format" "images:build" "build a new docker image"
    printf "$format" "containers" "show docker containers"
    printf "$format" "containers:stop" "stop docker containers"
    printf "$format" "containers:remove" "stop and remove all docker containers"
    printf "$format" "networks" "show docker networks"
    printf "$format" "volumes" "show docker volumes"
    printf "$format" "secrets" "show docker secrets"
    printf "$format" "secrets:add" "add docker secret"
    printf "$format" "volumes:prune" "remove all local volumes not used by at least one container"
    printf "$format" "benchmark" "benchmark for security"
}

run() {
    showMenu
    while :; do
        command=$(redInput "Select choice")
        case "$command" in

        # Docker
        "install")
            dockerInstall
            ;;
        "restart")
            dockerRestart
            ;;
        "compose:install")
            dockerComposeInstall
            ;;

            # Images
        "images")
            dockerImages
            ;;

        "images:remove")
            dockerImagesRemove
            ;;

        "images:build")
            dockerImageBuild
            ;;

            # Containers
        "containers")
            dockerContainers
            ;;
        "containers:stop")
            dockerContainersStop
            ;;
        "containers:remove")
            dockerContainersRemove
            ;;

            # Volumes
        "volumes")
            dockerVolumes
            ;;
        "volumes:prune")
            dockerVolumesPrune
            ;;

            # Networks
        "networks")
            dockerNetworks
            ;;

            # Secrets
        "secrets")
            dockerSecrets
            ;;
        "secrets:add")
            dockerSecretsAdd
            ;;

            # Daemon
        "daemon:install")
            dockerDaemonInstall
            ;;
        "daemon:clients:add")
            dockerDaemonCertificateClientAdd
            ;;

            # Utils
        "benchmark")
            dockerBenchForSecurity
            ;;
        *)
            if [ ! "$command" = "" ]; then
                echo "\"$command\" is not found, please try again"
            fi
            showMenu
            ;;
        esac
    done
}
run
