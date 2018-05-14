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

  my $sem
    = Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore->new(key => 33131);

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $sem = Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore->new(
          key => 33131);
        if ($sem->acquire(wait => 1, undo => 0)) {

          #    $sem->setval(0, $$);
          $sem->release();
        }

      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();

  ok defined($sem->getval(0))
    if $sem->acquire(wait => 1, undo => 0)
    or die('Cannot acquire lock');
  diag explain $sem->getval(0);

  $sem->remove;
  $sem = Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore->new(key => 3313);

  $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $sem
          = Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore->new(key => 3313);
        if ($sem->acquire(wait => 1, undo => 0)) {

          #    $sem->setval(0, $$);
          $sem->release();
        }

      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();

  ok defined($sem->getval(0))
    if $sem->acquire(wait => 1, undo => 0)
    or die('Cannot acquire lock');
  diag explain $sem->getval(0);
  $sem->release;
  $sem->remove;
};

subtest 'lock' => sub {
  my $k = 2342385;
  my $lock = Mojo::IOLoop::ReadWriteProcess::Shared::Lock->new(key => $k);

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $l = Mojo::IOLoop::ReadWriteProcess::Shared::Lock->new(key => $k);
        if ($l->lock) {
          $l->unlock;
        }

      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();

  ok defined($lock->getval(0));
  diag explain $lock->getval(0);
  $lock->remove();

};

subtest 'lock 2' => sub {

  my $lock = Mojo::IOLoop::ReadWriteProcess::Shared::Lock->new(key => 3331);

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $l = Mojo::IOLoop::ReadWriteProcess::Shared::Lock->new(key => 3331);
        if ($l->lock) {
          $l->setval(0, $$);
          $l->unlock;
        }

      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();

  ok defined($lock->getval(0));
  diag explain $lock->getval(0);
  $lock->remove;
};

subtest 'memory' => sub {
  use IPC::SysV qw/SEM_UNDO IPC_CREAT ftok/;

  my $k = ftok($0, 0);    #124551; # ftok($0, 0)
  my $mem = Mojo::IOLoop::ReadWriteProcess::Shared::Memory->new(key => $k);
  $mem->_lock->remove;

  $mem = Mojo::IOLoop::ReadWriteProcess::Shared::Memory->new(key => $k);
  $mem->clean;
  $mem->_lock->remove;

  $mem = Mojo::IOLoop::ReadWriteProcess::Shared::Memory->new(key => $k);
  $mem->lock_section(sub { $mem->buffer('start') });

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
            # Random sleeps to try to make threads race into lock section
            do { warn "$$: sleeping"; sleep rand(int(2)) }
              for 1 .. 5;
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

  $mem->_lock->remove;
};

done_testing();
