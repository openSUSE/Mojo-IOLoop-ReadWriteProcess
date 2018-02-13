#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use POSIX;
use FindBin;
use Mojo::File qw(tempfile path);
use lib ("$FindBin::Bin/lib", "../lib", "lib");
use Mojo::IOLoop::ReadWriteProcess qw(process);

subtest autodetect => sub {
  my $reached;
  my $collect;
  my $status;
  my $orphan2 = process(sub {  print "Hello from first process\n"; sleep 1 })->start;
  my $orphan = process(sub {  print "Hello from second process\n"; sleep 1 })->start;
  my $p = process(code => sub {
    print "Hello from master process\n";
    # Note: we do not collect any state, wait ensures that processes above are terminated
    $orphan->wait;
    $orphan2->wait;
  }, detect_subprocess => 1);
  my $fired;

  $p->on(new_subprocess => sub { $fired++ });
  $p->on(collect_status => sub { $status++ });

  $p->start();
  $p->wait_stop;
  is $status, 3, 'Status fired 2 times';
  is $p->subprocess->size, 2, 'detection works' or die diag explain $p;
  is $p->subprocess->last->pid,$orphan->pid, 'Orphan collected';
  is $fired, 2, 'New subprocess event fired';
  ok !!$p->exit_status, 'Got exit status from master';
};

done_testing();
