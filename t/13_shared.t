#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use POSIX;
use FindBin;
use Mojo::File qw(tempfile tempdir path);
use lib ("$FindBin::Bin/lib", "../lib", "lib");

use Mojo::IOLoop::ReadWriteProcess
  qw(process queue shared_memory lock semaphore);
use Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore;
use Mojo::IOLoop::ReadWriteProcess::Shared::Memory;

subtest 'semaphore' => sub {

  my $sem = semaphore(key => 33131);

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $sem = semaphore->new(key => 33131);
        if ($sem->acquire(wait => 1, undo => 0)) {

          #    $sem->setval(0, $$);
          $sem->release();
        }
        Devel::Cover::report() if Devel::Cover->can('report');
      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();

  ok defined($sem->getval(0))
    if $sem->acquire(wait => 1, undo => 0)
    or die('Cannot acquire lock');
  diag explain $sem->getval(0);

  $sem->remove;
  $sem = semaphore(key => 3313);

  $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $sem = semaphore(key => 3313);
        if ($sem->acquire(wait => 1, undo => 0)) {

          #    $sem->setval(0, $$);
          $sem->release();
        }
        Devel::Cover::report() if Devel::Cover->can('report');
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
  my $lock = lock(key => $k);

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $l = lock(key => $k);
        if ($l->lock) {
          $l->unlock;
        }
        Devel::Cover::report() if Devel::Cover->can('report');
      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();

  ok defined($lock->getval(0));
  diag explain $lock->getval(0);
  $lock->remove();

};

subtest 'lock 2' => sub {

  my $lock = lock(key => 3331);

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $l = lock(key => 3331);
        if ($l->lock) {

          #  $l->setval(0, $$);
          $l->unlock;
        }
        Devel::Cover::report() if Devel::Cover->can('report');
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
  my $mem = shared_memory(key => $k);
  $mem->_lock->remove;
  my $default = shared_memory;
  is $default->key, $k;

  $mem = shared_memory(key => $k);
  $mem->clean;
  $mem->_lock->remove;

  $mem = shared_memory(key => $k);
  $mem->lock_section(sub { $mem->buffer('start') });

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {

        my $mem = shared_memory(key => $k);

        $mem->lock_section(
          sub {
            # Random sleeps to try to make threads race into lock section
            do { warn "$$: sleeping"; sleep rand(int(2)) }
              for 1 .. 5;
            my $b = $mem->buffer;
            $mem->buffer($$ . " $b");
            Devel::Cover::report() if Devel::Cover->can('report');
          });
      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();

  $mem = shared_memory(key => $k);
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
