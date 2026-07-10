#!/usr/bin/perl

use Mojo::Base -strict;
use Test::More;
use Time::HiRes qw(sleep);
use FindBin;
use lib ("$FindBin::Bin/lib", "../lib", "lib");
use Mojo::IOLoop::ReadWriteProcess qw(process batch);
use Data::Dumper;

my $sleepduration = 0;

subtest "Signal on IO" => sub {
    my @stack;

    my $p1 = process(sub { sleep 2; print "Hello world\n" });
    for my $i (1 .. 10) {
        push (@stack, process(sub { sleep 0.2 * $i; print "Bye Bye"})) 
    }
    my $c = batch @stack;

    $p1->start;
    $c->start();
    is ($p1->getline(), "Hello world\n", "P1 can read with signals received!");
    is (!!$!{EINTR}, 1, "EINTR is set");
};

done_testing;
