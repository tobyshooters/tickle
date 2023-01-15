source "c.tcl"

set cc [c create]

$cc include <stdio.h>
$cc include <stdlib.h>
$cc include <string.h>
$cc include <arpa/inet.h>
$cc include <sys/types.h>
$cc include <sys/socket.h>
$cc include <netdb.h>
$cc include <unistd.h>

namespace eval tickle {
    $cc proc serve {} void {
        struct addrinfo hints;
        memset(&hints, 0, sizeof hints);
        hints.ai_family = AF_INET;       // ipv4
        hints.ai_socktype = SOCK_STREAM; // tcp
        hints.ai_flags = AI_PASSIVE;

        struct addrinfo *res;
        getaddrinfo(NULL, "3490", &hints, &res);

        int sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
        bind(sockfd, res->ai_addr, res->ai_addrlen);
        listen(sockfd, 10);

        while (1) {
            // Wait for incoming connections
            struct sockaddr_storage client;
            socklen_t size = sizeof client;
            int fd = accept(sockfd, (struct sockaddr *) &client, &size);

            // Send message to first client
            char* msg = "hello world!";
            send(fd, msg, strlen(msg), 0);
            close(fd);
        }

        close(sockfd);
        freeaddrinfo(res);
    }

    $cc proc join {char* hostname} int {
        struct addrinfo hints;
        memset(&hints, 0, sizeof hints);
        hints.ai_family = AF_INET;       // ipv4
        hints.ai_socktype = SOCK_STREAM; // tcp

        struct addrinfo *res;
        getaddrinfo(hostname, "3490", &hints, &res);

        int sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
        connect(sockfd, res->ai_addr, res->ai_addrlen);

        freeaddrinfo(res);
        return sockfd;
    }

    $cc proc ping {int sockfd} void {
        // Get name of server
        struct sockaddr_in name;
        socklen_t size;
        getpeername(sockfd, (struct sockaddr *)&name, &size);

        char ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &(name.sin_addr), ip, sizeof ip);

        // Get message
        char reply[1024];
        recv(sockfd, reply, sizeof reply, 0);
        printf("%s: %s\n", ip, reply);
    }

    $cc compile
}


package require Thread
proc spawn {body} {
    ::thread::create [subst {
        set ::inthread true
        eval {$body}
    }]
}

if {![info exists ::inthread]} {
    spawn {
        source tickle.tcl
        tickle::serve
    }

    spawn {
        source tickle.tcl
        set fd [tickle::join "localhost"]
        tickle::ping $fd
    }

    vwait forever
}

