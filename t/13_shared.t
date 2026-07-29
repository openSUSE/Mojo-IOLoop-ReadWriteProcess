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
use Mojo::IOLoop::ReadWriteProcess::Shared::Lock;
use Mojo::IOLoop::ReadWriteProcess::Shared::Memory;
use Data::Dumper;
use Time::HiRes ();

use constant DEBUG => $ENV{MOJO_PROCESS_DEBUG};
plan skip_all => "Skipped unless TEST_SHARED is set" unless $ENV{TEST_SHARED};

# Nudge forked workers to race into the lock section
sub race_sleep { Time::HiRes::sleep(rand(0.1)) unless DEBUG }

# Pin segment size to avoid mid-test reallocation races; keep default 10K.
# NOTE: this disables the dynamic-resize path for the whole file.
Mojo::IOLoop::ReadWriteProcess::Shared::Memory->attr(dynamic_resize => 0);

subtest 'semaphore' => sub {

  my $sem_key = 33131;

  my $sem = Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore::semaphore(
    key => $sem_key);

  ok(defined $sem->id, ' We have semaphore id ( ' . $sem->id . ' )');
  ok(defined $sem->stat,
    ' We have semaphore stats ( ' . Dumper($sem->stat) . ' )');
  is($sem->stat->[7], 1, 'Default semaphore size is 1');

  $sem->setval(0, 1);
  is $sem->getval(0), 1, 'Semaphore value set to 1';
  $sem->setval(0, 0);
  is $sem->getval(0), 0, 'Semaphore value set 0';
  $sem->setval(0, 1);
  is $sem->getval(0), 1, 'Semaphore value set to 1';
  $sem->setall(0);
  is $sem->getval(0), 0, 'Semaphore value set 0';
  $sem->setval(0, 1);

  is $sem->getall,  1, 'We have one semaphore, which is free to go';
  is $sem->getncnt, 0, '0 Processes waiting for the semaphore';

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $sem = semaphore(key => $sem_key);
        my $e   = 1;
        if ($sem->acquire({wait => 1, undo => 0})) {
          $e = 0;
          $sem->release();
        }
        Devel::Cover::report() if Devel::Cover->can('report');
        exit($e);
      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();

  is $q->done->size, 20, '20 Processes consumed';

  $q->done->each(
    sub {
      is $_[0]->exit_status, 0,
          "Process: "
        . shift->pid
        . " exited with 0 (semaphore acquired at least once)";
    });

  $sem->remove;
};

subtest 'lock' => sub {
  my $k = 2342385;
  my $lock
    = Mojo::IOLoop::ReadWriteProcess::Shared::Lock::shared_lock(key => $k);

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $l = lock(key => $k);
        my $e = 1;
        if ($l->lock) {
          $e = 0;
          $l->unlock;
        }
        Devel::Cover::report() if Devel::Cover->can('report');
        exit($e);
      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();

  is $q->done->size, 20, '20 Processes consumed';
  $q->done->each(
    sub {
      is $_[0]->exit_status, 0,
          "Process: "
        . shift->pid
        . " exited with 0 (semaphore acquired at least once)";
    });

  $lock->remove();

};

subtest 'lock section' => sub {

  my $lock
    = Mojo::IOLoop::ReadWriteProcess::Shared::Memory::shared_lock(key => 3331);

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $l = lock(key => 3331);
        my $e = 1;
        $l->section(sub { $e = 0 });

        Devel::Cover::report() if Devel::Cover->can('report');
        exit($e);
      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();
  is $q->done->size, 20, '20 Processes consumed';
  $q->done->each(
    sub {
      is $_[0]->exit_status, 0,
          "Process: "
        . shift->pid
        . " exited with 0 (semaphore acquired at least once)";
    });
  $lock->remove;
};

subtest 'concurrent memory read/write' => sub {
  use IPC::SysV 'ftok';

  my $k   = ftok($0, 0);
  my $mem = shared_memory(key => $k);
  $mem->_lock->remove;
  my $default = shared_memory;
  is $default->key, $k, "Default memory key is : $k";

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
        race_sleep();
        $mem->lock_section(
          sub {
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
      ok((length $mem->buffer > 0), 'Buffer is there');
    });
  $mem->lock_section(
    sub {
      my @pids = split(/ /, $mem->buffer);
      is scalar @pids, 21, 'There are 20 pids and the start word (21)';
      diag 'Buffer was: ' . $mem->buffer if scalar @pids != 21;
    });

  $mem->_lock->remove;
  $mem->remove;
};

sub free_mem {
  my $mem = shared_memory;
  $mem->_lock->remove;
  $mem->remove;

  $mem = shared_memory;
  $mem->clean;
  $mem->_lock->remove;

  $mem = shared_memory;

  if ($mem->try_lock) {
    $mem->buffer(freeze({}));
    $mem->unlock;
  }
}

sub test_mem {
  my $mem = shared_memory(destroy => 1);
  $mem->lock_section(
    sub {
      ok((length $mem->buffer > 0), 'Buffer is there');
      my $data = thaw($mem->buffer);
      my @pids = keys %{$data};
      is scalar @pids, 20, 'There are 20 pids';
      diag explain $data;
    });

  is $mem->stat->[8], 0, 'No process attached to memory';
}

subtest 'storable' => sub {
  use Storable qw(freeze thaw);
  use Mojo::IOLoop::ReadWriteProcess::Shared::Memory
    qw(shared_lock shared_memory semaphore);

  free_mem;

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $mem = shared_memory;
        race_sleep();
        $mem->lock_section(
          sub {
            my $data = thaw($mem->buffer);
            $data->{$$}++;
            $mem->buffer(freeze($data));
            Devel::Cover::report() if Devel::Cover->can('report');
          });
      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();
  is $q->done->size, 20, 'Queue consumed 20 processes';

  test_mem;
};

#
# subtest 'locking with undo' => sub {
#   use Storable qw(freeze thaw);
#
#   free_mem;
#
#   my $q = queue;
#   $q->pool->maximum_processes(10);
#   $q->queue->maximum_processes(50);
#
#   $q->add(
#     process(
#       sub {
#         my $mem = shared_memory;
#
#         if ($mem->lock(undo => 1, wait => 1))
#         {    # Do not unlock/release with undo => 1
#         eval {  my $data = thaw($mem->buffer);
#           $data->{$$}++;
#           $mem->buffer(freeze($data));
#                 $mem->save();
#         };
#         warn "FAILED UNDO $@" if $@;
#
#         #  $mem->unlock();
#         }
#         Devel::Cover::report() if Devel::Cover->can('report');
#         exit(0);
#       }
#     )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;
#
#   $q->consume();
#   is $q->done->size, 20, 'Queue consumed 20 processes';
#
#   test_mem;
# };

subtest 'dying in locked section' => sub {
  use Storable qw(freeze thaw);

  free_mem;

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(20);

  $q->add(
    process(
      sub {
        my $mem = shared_memory;
        race_sleep();
        $mem->lock_section(
          sub {
            my $data = thaw($mem->buffer);
            $data->{$$}++;
            $mem->buffer(freeze($data));
            Devel::Cover::report() if Devel::Cover->can('report');
            die("Process failed!");
          });
        Devel::Cover::report() if Devel::Cover->can('report');
      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();
  is $q->done->size, 20, 'Queue consumed 20 processes';

  test_mem;
};

subtest 'dynamic resize' => sub {
  my $k = 33135;

  my $mem = shared_memory(
    key               => $k,
    dynamic_resize    => 1,
    dynamic_increment => 1,
    dynamic_decrement => 1,
    _size             => 10,
  );

  $mem->lock_section(
    sub {
      $mem->buffer("A" x 20);
    });

  ok($mem->_size >= 20, 'Memory size grew to at least 20');
  $mem->load;
  is($mem->buffer, "A" x 20, 'Memory content was saved correctly');

  # Test lock/unlock (covers sub lock)
  ok($mem->lock, 'Lock acquired manually');
  $mem->unlock;

# Instantiate second shared_memory instance to cover $s != $cur_size in _loadsize
  my $mem2 = shared_memory(
    key               => $k,
    dynamic_resize    => 1,
    dynamic_increment => 1,
    dynamic_decrement => 1,
    _size             => 10240,
  );
  ok(defined $mem2, 'Second memory instance created with different size');

  # Attach $mem2 to the shared memory segment
  $mem2->load;

  # Test the detach path in _loadsize (covers line 74)
  $mem2->_size(500);
  $mem2->_loadsize;
  $mem2->load;

  # Test _safe_remove return 0 path (covers line 182)
  $mem->_shared_memory->detach;
  is($mem->_safe_remove, 0,
    'Memory is not removed because second instance is attached');

  $mem2->lock_section(
    sub {
      $mem2->buffer("B" x 5);
    });

  ok($mem2->_size < 20, 'Memory size decreased');
  $mem2->load;
  is($mem2->buffer, "B" x 5, 'Memory content was saved correctly');

  $mem2->_lock->remove;
  $mem2->remove;
};

done_testing();
