source "c.tcl"

set cc [c create]

$cc include <stdio.h>
$cc include <stdlib.h>
$cc include <string.h>
$cc include <arpa/inet.h>
$cc include <sys/types.h>
$cc include <sys/socket.h>
$cc include <netdb.h>

$cc proc get_ips {char* hostname} void {

    // Configure IPv4 + TCP
    struct addrinfo hints;
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;

    // Syscall to lookup address information
    struct addrinfo *res;
    int err = getaddrinfo(hostname, NULL, &hints, &res);
    if (err) {
        fprintf(stderr, "got error: %s", gai_strerror(err));
        exit(1);
    }

    // Loop over linked-list
    struct addrinfo* p;
    char ip[INET_ADDRSTRLEN];
    for (p = res; p != NULL; p = p->ai_next) {
        struct sockaddr_in *sa = (struct sockaddr_in *) p->ai_addr;
        inet_ntop(AF_INET, &(sa->sin_addr), ip, sizeof ip);
        printf("%s => %s\n", ip, hostname);
    }
    freeaddrinfo(res);
}
$cc compile

puts [get_ips "www.google.com"]
puts [get_ips "www.wikipedia.com"]
