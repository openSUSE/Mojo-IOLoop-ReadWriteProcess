#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use POSIX;
use FindBin;
use Mojo::File qw(tempfile tempdir path);
use lib ("$FindBin::Bin/lib", "../lib", "lib");
BEGIN { $ENV{MOJO_PROCESS_DEBUG} = 1 }

use Mojo::IOLoop::ReadWriteProcess qw(process queue);
use Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore;
use Mojo::IOLoop::ReadWriteProcess::Shared::Memory;


subtest 'semaphore' => sub {

  my $sem = Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore->new();

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $sem = Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore->new();
        if ($sem->acquire(wait => 1)) {
          $sem->setval(0, $$);
          $sem->release();
        }

      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();

  ok defined($sem->getval(0))
    if $sem->acquire(wait => 1)
    or die('Cannot acquire lock');
  diag explain $sem->getval(0);


  $sem = Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore->new(key => 33);

  $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $sem
          = Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore->new(key => 33);
        if ($sem->acquire(wait => 1)) {
          $sem->setval(0, $$);
          $sem->release();
        }

      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();

  ok defined($sem->getval(0))
    if $sem->acquire(wait => 1)
    or die('Cannot acquire lock');
  diag explain $sem->getval(0);

};

subtest 'lock' => sub {

  my $lock = Mojo::IOLoop::ReadWriteProcess::Shared::Lock->new();

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $l = Mojo::IOLoop::ReadWriteProcess::Shared::Lock->new();
        if ($l->lock) {
          $l->setval(0, $$);
          $l->unlock;
        }

      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();

  ok defined($lock->getval(0));
  diag explain $lock->getval(0);

};

subtest 'lock' => sub {

  my $lock = Mojo::IOLoop::ReadWriteProcess::Shared::Lock->new(key => 445);

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $l = Mojo::IOLoop::ReadWriteProcess::Shared::Lock->new(key => 445);
        if ($l->lock) {
          $l->setval(0, $$);
          $l->unlock;
        }

      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();

  ok defined($lock->getval(0));
  diag explain $lock->getval(0);

};

subtest 'memory' => sub {

  my $k = 114552;
  my $mem = Mojo::IOLoop::ReadWriteProcess::Shared::Memory->new(key => $k);
  $mem->lock_section(
    sub {
      $mem->buffer("start");
    });

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {

        my $mem
          = Mojo::IOLoop::ReadWriteProcess::Shared::Memory->new(key => $k);

        $mem->lock_section(
          sub {
            my $b = $mem->buffer;
            $mem->buffer($$ . " $b");
          });
      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();

  $mem = Mojo::IOLoop::ReadWriteProcess::Shared::Memory->new(key => $k);
  $mem->lock_section(
    sub {
      ok(length $mem->buffer > 0);
    });
  $mem->lock_section(
    sub {
      my @pids = split(/ /, $mem->buffer);
      is scalar @pids, 21;
      diag explain \@pids;
    });


};

done_testing();
