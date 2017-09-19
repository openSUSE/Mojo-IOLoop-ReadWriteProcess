#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use POSIX;
use FindBin;
use Mojo::File qw(tempfile path);
use lib ("$FindBin::Bin/lib", "../lib", "lib");
use Mojo::IOLoop::ReadWriteProcess qw(parallel batch);

subtest parallel => sub {
  my $n_proc = 30;
  my $fired;

  my $c = parallel(
    code           => sub { print "Hello world\n"; },
    kill_sleeptime => 0,
    $n_proc
  );

  isa_ok($c, "Mojo::IOLoop::ReadWriteProcess::Pool");
  is $c->size(), $n_proc;

  $c->once(stop => sub { $fired++; });
  $c->start();
  $c->each(sub { is shift->getline(), "Hello world\n"; });
  $c->wait_stop;
  is $fired, $n_proc;

  $c->once(stop => sub { $fired++ });
  my $b = $c->restart();
  is $b, $c;
  sleep 3;
  $c->wait_stop;
  is $fired, $n_proc * 2;
};

subtest batch => sub {
  use Mojo::IOLoop::ReadWriteProcess qw(batch);
  my @stack;
  my $n_proc = 30;
  my $fired;

  push(
    @stack,
    Mojo::IOLoop::ReadWriteProcess->new(
      code           => sub { print "Hello world\n" },
      kill_sleeptime => 0
    )) for (1 .. $n_proc);

  my $c = batch @stack;

  isa_ok($c, "Mojo::IOLoop::ReadWriteProcess::Pool");
  is $c->size(), $n_proc;

  $c->once(stop => sub { $fired++; });
  $c->start();
  $c->each(sub { is shift->getline(), "Hello world\n"; });
  $c->wait_stop;

  is $fired, $n_proc;

  $c->add(sub { print "Hello world 3\n" });
  $c->start();
  is $c->last->getline, "Hello world 3\n";
  $c->wait_stop();

  my $result;
  $c->add(sub { return 40 + 2 });
  $c->last->on(
    stop => sub {
      $result = shift->return_status;
    });
  $c->last->start()->wait_stop();
  is $result, 42;
};

subtest "Working with pools" => sub {
  my $n_proc = 30;
  my $number = 1;
  my $pool   = batch;
  for (1 .. $n_proc) {
    $pool->add(
      code => sub { my $self = shift; my $number = shift; return 40 + $number },
      args => $number
    );
    $number++;
  }
  my $results;
  $pool->once(stop => sub { $results->{+shift()->return_status}++; });
  $pool->start->wait_stop;
  my $i = 1;
  for (1 .. $n_proc) {
    is $results->{40 + $i}, 1;
    $i++;
  }
  ok $pool->get(0) != $pool->get(1);
  $pool->remove(3);
  is $pool->get(3), undef;
};

done_testing;
