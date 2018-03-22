#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use POSIX;
use FindBin;
use Mojo::File qw(tempfile tempdir path);
use lib ("$FindBin::Bin/lib", "../lib", "lib");

BEGIN { $ENV{MOJO_CGROUP_FS} = tempdir() }

use Mojo::IOLoop::ReadWriteProcess qw(process);
use Mojo::IOLoop::ReadWriteProcess::Test::Utils qw(attempt);
use Mojo::IOLoop::ReadWriteProcess::CGroup qw(cgroupv2 cgroupv1);
use Mojo::IOLoop::ReadWriteProcess::Container qw(container);

subtest container => sub {

  eval { container(process => 2)->start(); };
  ok defined $@, 'Croaks if no sub or Mojo::IOLoop::ReadWriteProcess given';
  like $@,
qr/You need either to pass a Mojo::IOLoop::ReadWriteProcess object or a callback/;

  my $c = container(
    subreaper => 1,
    group     => "group",
    name      => "test",
    process   => sub { sleep 5 },
  );

  my @pids;
  my $fired;
  $c->session->on(register => sub { push(@pids, shift) });
  $c->once(stop => sub { $fired++ });
  $c->start();

  my $p       = $c->process();
  my $cgroups = $c->cgroups;
  is $cgroups->first->process_list, $p->pid . "\n",
    "procs interface contains the added pids"
    or diag explain $cgroups->first->process_list;

  ok $cgroups->first->contains_process($p->pid),
    "Parent contains pid " . $p->pid;

  attempt {
    attempts  => 20,
    condition => sub { $cgroups->first->processes->size == 1 },
    cb        => sub { sleep 1; }
  };

  $c->wait();
  is $cgroups->first->process_list, $p->pid . "\n"
    or die diag explain $cgroups->first->process_list;

  unlink $cgroups->first->_cgroup
    ->child(Mojo::IOLoop::ReadWriteProcess::CGroup::v1::PROCS_INTERFACE);
  $cgroups->first->remove();
  ok !$cgroups->first->exists();
  is $fired, 1;
};

subtest container_2 => sub {
  my $c = container(
    subreaper => 1,
    group     => "group",
    name      => "test",
    process   => process(sub { sleep 5 }),
  );

  my @pids;
  my $fired;
  $c->session->on(register => sub { push(@pids, shift) });
  $c->once(stop => sub { $fired++ });
  $c->start();

  my $p       = $c->process();
  my $cgroups = $c->cgroups;
  is $cgroups->first->process_list, $p->pid . "\n",
    "procs interface contains the added pids"
    or diag explain $cgroups->first->process_list;

  ok $cgroups->first->contains_process($p->pid),
    "Parent contains pid " . $p->pid;

  attempt {
    attempts  => 20,
    condition => sub { !$c->is_running },
    cb        => sub { sleep 1; }
  };

  $c->wait_stop();
  is $cgroups->first->process_list, $p->pid . "\n"
    or die diag explain $cgroups->first->process_list;

  unlink $cgroups->first->_cgroup
    ->child(Mojo::IOLoop::ReadWriteProcess::CGroup::v1::PROCS_INTERFACE);
  $cgroups->first->remove();
  ok !$cgroups->first->exists();
  is $fired, 1;
};

done_testing;
