source c.tcl

set cc [c create]

$cc proc cprint {char* p} void {
    printf("from c: %s\n", p);
}

$cc compile

cprint "hello world"
