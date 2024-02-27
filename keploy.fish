#!/bin/bash

function installKeploy
    set IS_CI 0
    for arg in $argv 
        switch $arg
            case -isCI
                set IS_CI 1
                shift
        end
    end

    function install_keploy_arm 
        curl --silent --location "https://github.com/keploy/keploy/releases/latest/download/keploy_linux_arm64.tar.gz" | tar xz -C /tmp

        sudo mkdir -p /usr/local/bin && sudo mv /tmp/keploy /usr/local/bin/keploybin

        set_alias 'sudo -E env PATH="$PATH" keploybin'

        set dockerStatus (check_docker_status_for_linux)
        if test $dockerStatus -eq 1
            return
        end
        add_network
    end

    function check_sudo
        if id -Gn | grep -q '\bdocker\b'
            # echo "check sudo is giving 1"
            echo 1
            # return 1
        else
            # echo "check sudo is giving 0"
            echo 0
            #return 0 
        end
    end


    function install_keploy_amd
        curl --silent --location "https://github.com/keploy/keploy/releases/latest/download/keploy_linux_amd64.tar.gz" | tar xz -C /tmp

        sudo mkdir -p /usr/local/bin && sudo mv /tmp/keploy /usr/local/bin/keploybin

        set_alias 'sudo -E env PATH="$PATH" keploybin'

        set dockerStatus (check_docker_status_for_linux)
        if test $dockerStatus -eq 0
            return
        end
        add_network
    end



    # Get the alias to set and set it
    function set_alias
        set command $argv[1]

        if string match '*docker*' $command
            set sudoCheck (check_sudo)

            echo "sudoCheck: $sudoCheck"
            if test $sudoCheck -eq 1
                and test "$OS_NAME"="Linux"
                set ALIAS_CMD "alias keploy 'sudo $command'"
            else
                set ALIAS_CMD "alias keploy '$command'"
            end
        else
            set ALIAS_CMD "alias keploy '$command'"
        end

        if test -f ~/.config/fish/config.fish
            if string match '*alias keploy*' (cat ~/.config/fish/config.fish) 
                sed -i '' '/^alias keploy /d' ~/.config/fish/config.fish
            end
            echo "$ALIAS_CMD" >> ~/.config/fish/config.fish
        else
            alias keploy $command
        end
    end


    function check_docker_status_for_linux
        set sudoCheck (check_sudo)
        set network_alias ""

        if test $sudoCheck -eq 1
            set network_alias "sudo"
        end
        if ! $network_alias which docker &> /dev/null
            echo -n "Docker not found on device, please install docker and reinstall keploy if you have applications running on docker"
            return 0
        end
        if ! $network_alias docker info &> /dev/null
            echo "Please start docker and reinstall keploy if you have applications running on docker"
            return 0
        end
        return 1
    end


    function check_docker_status_for_Darwin
        set sudoCheck (check_sudo)
        set network_alias ""

        if test $sudoCheck -eq 1
            set network_alias "sudo"
        end
        if ! $network_alias which docker &> /dev/null
            echo -n "Docker not found on device, please install docker to use Keploy"
            return 0
        end
        # Check if docker is running
        if ! $network_alias docker info &> /dev/null
            echo -n "Keploy only supports intercepting and replaying docker containers on macOS, and requires Docker to be installed and running. Please start Docker and try again."
            return 0
        end
        return 1
    end

    function add_network 
        if ! $network_alias docker network ls | grep -q 'keploy-network';
            $network_alias docker network create keploy-network
        end
    end

    function install_docker
        if string match "Darwin" $OS_NAME
            set dockerStatus (check_docker_status_for_Darwin)
            
            if test $dockerStatus -eq 0
                return
            end
            add_network
            if ! docker volume inspect debugfs &> /dev/null
                docker volume create --driver local --opt type=debugfs --opt device=debugfs debugfs
            end
            set_alias 'docker run --pull always --name keploy-v2 -p 16789:16789 --privileged --pid=host -it -v $(pwd):$(pwd) -w $(pwd) -v /sys/fs/cgroup:/sys/fs/cgroup -v debugfs:/sys/kernel/debug:rw -v /sys/fs/bpf:/sys/fs/bpf -v /var/run/docker.sock:/var/run/docker.sock -v '"$HOME"'/.keploy-config:/root/.keploy-config -v '"$HOME"'/.keploy:/root/.keploy --rm ghcr.io/keploy/keploy'
        else
            set_alias 'docker run --pull always --name keploy-v2 -p 16789:16789 --privileged --pid=host -it -v $(pwd):$(pwd) -w $(pwd) -v /sys/fs/cgroup:/sys/fs/cgroup -v /sys/kernel/debug:/sys/kernel/debug -v /sys/fs/bpf:/sys/fs/bpf -v /var/run/docker.sock:/var/run/docker.sock -v '"$HOME"'/.keploy-config:/root/.keploy-config -v '"$HOME"'/.keploy:/root/.keploy --rm ghcr.io/keploy/keploy'
        end
    end


    set ARCH (uname -m)


    if test $IS_CI -eq 0
        set OS_NAME (uname -s)
        if string match "Darwin" $OS_NAME 
            install_docker
            return
        else if string match "Linux" $OS_NAME
            if ! sudo mountpoint -q /sys/kernel/debug
                sudo mount -t debugfs debugfs /sys/kernel/debug
            end
            if string match "x86_64" $ARCH
                install_keploy_amd
            else if string match "aarch64" $ARCH
                install_keploy_arm
            else
                echo "Unsupported architecture: $ARCH"
                return
            end
        else if string match "MINGW32_NT*" $OS_NAME
            echo  "\e]8;; https://pureinfotech.com/install-windows-subsystem-linux-2-windows-10\aWindows not supported please run on WSL2\e]8;;\a"
        else if string match "MINGW64_NT*" $OS_NAME
            echo "\e]8;; https://pureinfotech.com/install-windows-subsystem-linux-2-windows-10\aWindows not supported please run on WSL2\e]8;;\a"
        else
            echo "Unknown OS, install linux to run keploy"
        end

    else
        if string match "x86_64" $ARCH
            install_keploy_amd
        else if string match "aarch64" $ARCH
            install_keploy_arm
        else
            echo "Unsupported architecture: $ARCH"
            return
        end
    end
end

installKeploy

if command -v keploy > /dev/null
    keploy example
    rm keploy.sh
end
