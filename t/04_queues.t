#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use POSIX;
use FindBin;
use Mojo::File qw(tempfile path);
use lib ("$FindBin::Bin/lib", "../lib", "lib");

use Mojo::IOLoop::ReadWriteProcess qw(queue process);

subtest queues => sub {
  my $q = queue(auto_start => 1);
  $q->pool->maximum_processes(2);
  $q->queue->maximum_processes(800);

  my $proc = 100;
  my $fired;

  my $i = 1;
  for (1 .. $proc) {
    my $p = process(sub { shift; return shift() })->args($i);
    $q->add($p);
    warn 'adding ' . $i;
    $i++;
  }

  my %output;
  $q->once(
    stop => sub {
      $fired++;
      $output{shift->return_status}++;
    });
  is $q->queue->size,             $proc - $q->pool->maximum_processes;
  is $q->pool->size,              2;
  is $q->pool->maximum_processes, 2;
  $q->consume;
  is $fired, $proc;
  is $q->queue->size, 0;
  is $q->pool->size,  0;

  $i = 1;
  for (1 .. $proc) {
    is $output{$i}, 1;
    $i++;
  }
};

subtest 'auto starting queues on add' => sub {
  my $q = queue(auto_start => 1, auto_start_add => 1);
  $q->pool->maximum_processes(2);
  $q->queue->maximum_processes(10000);
  my $proc = 1000;
  my $fired;
  my %output;
  my $i = 1;
  for (1 .. $proc) {
    my $p = process(sub { shift; return shift() })->args($i);
    $p->once(
      stop => sub {
        $fired++;
        $output{shift->return_status}++;
      });
    $q->add($p);
    $i++;
  }

  is $q->pool->maximum_processes, 2;
  $q->consume;
  is $q->queue->size, 0;
  is $q->pool->size,  0;
  is $fired, $proc;
  $i = 1;
  for (1 .. $proc) {
    is $output{$i}, 1 or diag explain \%output;
    $i++;
  }
};

done_testing;
