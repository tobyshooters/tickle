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

namespace eval tickle {}

$cc proc tickle::listen {} int {
    struct addrinfo hints;
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET;      // ipv4
    hints.ai_socktype = SOCK_DGRAM; // datagram
    hints.ai_flags = AI_PASSIVE;    // localhost

    struct addrinfo *res;
    getaddrinfo(NULL, "3490", &hints, &res);

    int sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    bind(sockfd, res->ai_addr, res->ai_addrlen);

    char ip[INET_ADDRSTRLEN];
    struct in_addr addr = ((struct sockaddr_in*) &res)->sin_addr;
    inet_ntop(AF_INET, &addr, ip, sizeof ip);
    printf("Listening @ %s\n", ip);

    freeaddrinfo(res);

    return sockfd;
}

$cc proc tickle::receive {int sockfd} Tcl_Obj* {
    int len = 1024;
    char msg[len];
    memset(msg, 0, sizeof msg);

    struct sockaddr client;
    socklen_t size = sizeof client;
    recvfrom(sockfd, msg, len-1, 0, &client, &size);
    msg[len] = '\0';

    Tcl_Obj* result = Tcl_ObjPrintf("%s", msg);
    return result;
}

$cc proc tickle::talk {char* msg} void {
    int sockfd = socket(AF_INET, SOCK_DGRAM, 0);

    int broadcast = 1;
    setsockopt(sockfd, SOL_SOCKET, SO_BROADCAST, &broadcast, sizeof broadcast);

    // broadcast address: can't use getaddrinfo...
    struct hostent *he = gethostbyname("192.168.1.255");

    struct sockaddr_in server;
    server.sin_family = AF_INET;
    server.sin_port = htons(3490);
    server.sin_addr = *((struct in_addr*) he->h_addr);
    memset(server.sin_zero, '\0', sizeof server.sin_zero);

    // send message
    printf("Broadcast %s\n", msg);
    sendto(sockfd, msg, strlen(msg), 0, (struct sockaddr *) &server, sizeof server);

    close(sockfd);
}

$cc compile

if {![info exists ::inChildThread]} {

    # Define the chat window
    package require Tk
    wm title . "Tickle"

    grid [tk::text .text -width 40 -height 10]

    grid [tk::entry .input -textvariable msg]
    bind .input <Return> {
        tickle::talk $msg
        set msg ""
    }

    # Listen to socket connections
    package require Thread
    set mainTid [::thread::id]

    set listener [::thread::create]
    ::thread::send -async $listener "set ::mainTid $mainTid"
    ::thread::send -async $listener {
        set ::inChildThread true
        source chat.tcl

        set fd [tickle::listen]

        while {1} {
            puts "Waiting for message"
            set msg [tickle::receive $fd]
            puts "Heard $msg"
            thread::send -async $::mainTid [list .text insert end "$msg\n"]
        }
    }

    vwait forever
}

