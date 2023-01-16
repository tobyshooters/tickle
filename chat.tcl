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

    freeaddrinfo(res);

    return sockfd;
}

$cc proc tickle::receive {int sockfd} Tcl_Obj* {
    // prepare message from client
    int len = 1024;
    char msg[len];
    struct sockaddr client;
    socklen_t size = sizeof client;

    // get client's message
    recvfrom(sockfd, msg, len, 0, &client, &size);

    // get client's ip
    char ip[INET_ADDRSTRLEN];
    struct in_addr addr = ((struct sockaddr_in*) &client)->sin_addr;
    inet_ntop(AF_INET, &addr, ip, sizeof ip);

    Tcl_Obj* result = Tcl_ObjPrintf("listener heard %s from %s\n", msg, ip);
    return result;
}

$cc proc tickle::talk {char* msg} void {
    // connect to localhost:3490
    struct addrinfo hints;
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET;      // ipv4
    hints.ai_socktype = SOCK_DGRAM; // tcp

    struct addrinfo *res;
    getaddrinfo("localhost", "3490", &hints, &res);
    int sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);

    // send message
    sendto(sockfd, msg, strlen(msg), 0, res->ai_addr, res->ai_addrlen);

    freeaddrinfo(res);
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
            puts "waiting"
            set msg [tickle::receive $fd]
            puts $msg
            thread::send -async $::mainTid {
                .text insert end "$msg\n"
                set msg ""
            }
        }
    }

    vwait forever
}

