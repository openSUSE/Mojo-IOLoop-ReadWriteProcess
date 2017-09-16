#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use POSIX;
use FindBin;
use Mojo::File qw(tempfile path);
use lib ("$FindBin::Bin/lib", "..");

subtest parallel => sub {
  use Mojo::IOLoop::ReadWriteProcess;
  my $n_proc = 15;
  my $fired;

  my $c = Mojo::IOLoop::ReadWriteProcess->new->parallel(
    sub { print "Hello world\n"; } => $n_proc);

  isa_ok($c, "Mojo::IOLoop::ReadWriteProcess::Pool");
  is $c->size(), $n_proc;

  my @processes = $c->start();
  is @processes, $n_proc;

  $c->each(
    sub {
      $fired++;
      my $out;
      $_[0]->wait_stop;
      ok !$_[0]->is_running;
      is shift->getline(), "Hello world\n";
    });
  is $fired, $n_proc;

  my $b = $c->restart();
  is $b, $c;
  sleep 3;
  $c->each(
    sub {
      $fired++;
      $_[0]->wait_stop;
      ok !$_[0]->is_running;
      is shift->getline(), "Hello world\n";
    });
  is $fired, $n_proc * 2;

  $c->start()->wait_stop();
  $c->each(
    sub {
      ok !$_[0]->is_running;
    });
};

subtest batch => sub {
  use Mojo::IOLoop::ReadWriteProcess;
  my @stack;
  my $n_proc = 5;
  my $fired;

  push(@stack,
    Mojo::IOLoop::ReadWriteProcess->new(sub { print "Hello world\n" }))
    for (1 .. $n_proc);

  my $c = Mojo::IOLoop::ReadWriteProcess->batch(@stack);

  isa_ok($c, "Mojo::IOLoop::ReadWriteProcess::Pool");
  is $c->size(), $n_proc;

  $c->each(sub { shift->start(); });


  $c->each(sub { $fired++; $_[0]->wait_stop(); is shift->getline(), "Hello world\n" });
  is $fired, $n_proc;
  $c->stop();

  $c->add(Mojo::IOLoop::ReadWriteProcess->new(sub { print "Hello world 3\n" }));
  $c->start();
  $c->wait();
  is $c->last->getline, "Hello world 3\n";
  $c->stop();

  my $result;
  $c->add(Mojo::IOLoop::ReadWriteProcess->new(sub { return 40 + 2 }));
  $c->last->on(
    stop => sub {
      $result = shift->return_status;
    });
  $c->last->start()->wait_stop();
  is $result, 42;
};

subtest "Working with pools" => sub {

  my $n_proc = 20;
  my $number = 1;
  my @stack;
  for (1 .. $n_proc) {
    push(
      @stack,
      Mojo::IOLoop::ReadWriteProcess->new(
        sub { my $self = shift; my $number = shift; return 40 + $number }
      )->args([$number]));
    $number++;
  }
  my $pool = Mojo::IOLoop::ReadWriteProcess->batch(@stack);
  my $results;
  my $results2;
  # $pool->each(
  #   sub {
  #     shift->on(stop => sub { $results->{+shift->return_status}++ });
  #   });

  $pool->on(stop => sub {$results2->{+shift->return_status}++ });

  $pool->start->wait_stop;

  my $i = 1;
  for (1 .. $n_proc) {
  #  is $results->{40 + $i}, 1;

    #is $results2->{40+$i}, 1;
    $i++;
  }
};

done_testing;
