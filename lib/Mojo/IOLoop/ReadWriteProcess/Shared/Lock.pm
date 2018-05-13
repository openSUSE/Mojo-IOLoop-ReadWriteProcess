package Mojo::IOLoop::ReadWriteProcess::Shared::Lock;

use Mojo::Base 'Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore';
use constant DEBUG => $ENV{MOJO_PROCESS_DEBUG};
has key            => 42;
has count          => 1;
has _value         => 1;

sub lock {
  warn "[debug:$$] Attempt to acquire lock " . $_[0]->key if DEBUG;
  shift->acquire(wait => 1);
}
sub try_lock { shift->acquire() }

sub unlock {
  warn "[debug:$$] UNLock " . $_[0]->key if DEBUG;
  shift->release(@_);
}

!!42;
