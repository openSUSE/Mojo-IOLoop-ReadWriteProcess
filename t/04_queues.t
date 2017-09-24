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
  $q->add(sub { return "Hello\n" });
  $q->add(sub { return "Wof\n" });
  $q->add(sub { return "Wof2\n" });
  $q->add(sub { return "Wof3\n" });
  my $fired;
  my %output;
  $q->once(
    stop => sub {
      $fired++;
      $output{shift->return_status}++;
    });
  is $q->queue->size,             2;
  is $q->pool->size,              2;
  is $q->pool->maximum_processes, 2;
  $q->consume;
  is $q->queue->size, 0;
  is $q->pool->size,  0;
  is $fired, 4;
  is $output{"Hello\n"}, 1;
  is $output{"Wof\n"},   1;
  is $output{"Wof2\n"},  1;
  is $output{"Wof3\n"},  1;
};

subtest 'auto starting queues on add' => sub {
  my $q = queue(auto_start => 1, auto_start_add => 1);
  $q->pool->maximum_processes(2);
  my $fired;
  my %output;
  foreach my $string (qw(Hello Wof Wof2 Wof3)) {
    my $p = process(sub { return $_[1] . "\n" })->args($string);
    $p->once(
      stop => sub {
        $fired++;
        $output{shift->return_status}++;
      });
    $q->add($p);
  }

  is $q->pool->maximum_processes, 2;
  $q->consume;
  is $q->queue->size, 0;
  is $q->pool->size,  0;
  is $fired, 4;
  is $output{"Hello\n"}, 1;
  is $output{"Wof\n"},   1;
  is $output{"Wof2\n"},  1;
  is $output{"Wof3\n"},  1;
};

done_testing;
