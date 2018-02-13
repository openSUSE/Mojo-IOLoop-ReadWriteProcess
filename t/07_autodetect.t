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
  local $SIG{CHLD};

  my $reached;
  my $collect;
  my $status;
  my $fired;

  my $orphan2
    = process(sub { print "Hello from first process\n"; sleep 1 })->start;
  my $orphan
    = process(sub { print "Hello from second process\n"; sleep 1 })->start;
  my $p = process(
    code => sub {
      print "Hello from master process\n";
      sleep 2;
      return 2;
    },
    detect_subprocess => 1
  );

  $p->on(new_subprocess => sub { $fired++ });
  $p->on(collect_status => sub { $status++ });

  $p->start();
  $p->wait_stop;
  is $status, 3, 'Status fired 3 times';
  is $p->subprocess->size, 2, 'detection works' or die diag explain $p;

  is $p->subprocess->grep(sub { $_->pid eq $orphan->pid })->first->pid,
    $orphan->pid, 'Orphan collected';
  is $p->subprocess->grep(sub { $_->pid eq $orphan2->pid })->first->pid,
    $orphan2->pid, 'Orphan2 collected';

  is $fired, 2, 'New subprocess event fired';
  is $p->return_status, 2, 'Got exit status from master';
};

subtest autodetect_fork => sub {

  my $fired;
  my $status;
  local $SIG{CHLD};

  # Fork, and die after a bit
  my $pid = fork;
  die "Cannot fork: $!" unless defined $pid;
  if ($pid == 0) { sleep 2; die(); }
  $pid = fork;
  die "Cannot fork: $!" unless defined $pid;
  if ($pid == 0) { sleep 2; die(); }
  $pid = fork;
  die "Cannot fork: $!" unless defined $pid;
  if ($pid == 0) { sleep 2; die(); }
  $pid = fork;
  die "Cannot fork: $!" unless defined $pid;
  if ($pid == 0) { sleep 2; die(); }
  $pid = fork;
  die "Cannot fork: $!" unless defined $pid;
  if ($pid == 0) { sleep 2; die(); }
  $pid = fork;
  die "Cannot fork: $!" unless defined $pid;
  if ($pid == 0) { sleep 2; die(); }

  my $master_p = process(sub { sleep 4; });
  $master_p->detect_subprocess(1);
  $master_p->on(new_subprocess => sub { $fired++ });
  $master_p->on(collect_status => sub { $status++ });

  $master_p->start();
  $master_p->wait_stop;
  is $status, 7, 'Status fired 7 times';
  is $master_p->subprocess->size, 6, 'detection works'
    or die diag explain $master_p;
};

done_testing();
