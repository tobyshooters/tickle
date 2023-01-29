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
$cc include <time.h>

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
    int len = 1024;
    char msg[len];
    memset(msg, 0, sizeof msg);

    struct sockaddr client;
    socklen_t size = sizeof client;
    recvfrom(sockfd, msg, len-1, 0, &client, &size);
    msg[len] = '\0';

    char ip[INET_ADDRSTRLEN];
    struct sockaddr_in *sa = (struct sockaddr_in *) &client;
    inet_ntop(AF_INET, &(sa->sin_addr), ip, sizeof ip);

    // append ip to dict
    char packet[1024];
    sprintf(packet, "%s ip %s",msg, ip);

    Tcl_Obj* result = Tcl_ObjPrintf("%s", packet);
    return result;
}

$cc proc tickle::talk {char* msg int palilalia} void {
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

    char packet[1024];

    if (palilalia) {
        // msg variable is pre-structured, e.g from history
        strcpy(packet, msg);
    } else {
        // "structured data" as tcl dictionary
        char host[256];
        gethostname(host, sizeof(host));     // get own hostname to send with message
        unsigned ts = (unsigned) time(NULL); // timestamp when message is sent
        sprintf(packet, "host %s msg \"%s\" ts %u", host, msg, ts);
    }

    sendto(sockfd, packet, strlen(packet), 0, (struct sockaddr *) &server, sizeof server);
    close(sockfd);
}

$cc compile

proc handle_payload {payload} {
    dict with payload {
        set dt [clock format $ts -format "%D %r"]
        set src [format %-30s "$host @ $ip:"]

        thread::send -async $::mainTid [list .text insert end "$dt\n" meta]
        thread::send -async $::mainTid [list .text insert end "$src $msg\n\n"]
        thread::send -async $::mainTid [list .text see end]
    }
}

if {![info exists ::inChildThread]} {

    # Define the chat window
    package require Tk
    wm title . "tickle"
    wm geometry . 480x240
    grid columnconfigure . 0 -weight 1
    grid rowconfigure . 0 -weight 1

    tk::text .text -highlightthickness 0 -padx 11 -pady 11 -yscrollcommand {.ys set}
    .text tag configure meta -font {Courier 12 italic}
    grid .text -column 0 -row 0 -sticky nswe

    tk::scrollbar .ys -orient vertical -command {.text yview}
    grid .ys -column 1 -row 0 -sticky ns

    tk::entry .input -textvariable msg
    grid .input -padx 11 -column 0 -row 1 -sticky ew
    bind .input <Return> {
        tickle::talk $msg 0
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

        # Read in history
        set hist [open "history.txt" r]
        set data [split [read $hist] "\n"]
        foreach payload $data {
            if {$payload ne {}} {
                puts $payload
                handle_payload $payload
            }
        }
        close $hist

        # Listen for future messages
        set fd [tickle::listen]

        while {1} {
            set payload [tickle::receive $fd]
            puts $payload

            set hist [open "history.txt" a]
            puts $hist $payload
            close $hist

            handle_payload $payload
        }
    }

    vwait forever
}

