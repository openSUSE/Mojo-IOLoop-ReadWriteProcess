package Mojo::IOLoop::ReadWriteProcess::Shared::Lock;

use Mojo::Base 'Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore';
use constant DEBUG => $ENV{MOJO_PROCESS_DEBUG};
has key            => 42;
has count          => 1;
has _value         => 1;
has locked         => 0;

sub lock {
  my $self = shift;
  warn "[debug:$$] Attempt to acquire lock " . $self->key if DEBUG;
  my $r = @_ > 0 ? $self->acquire(@_) : $self->acquire(wait => 1, undo => 0);
  warn "[debug:$$] lock Returned : $r";
  $self->locked(1) if defined $r && $r == 1;
  return $r;
}
sub try_lock { shift->acquire(@_) }

sub unlock {
  my $self = shift;
  warn "[debug:$$] UNLock " . $self->key if DEBUG;
  my $r;
  eval {
    $r = $self->release(@_);
    $self->locked(0) if defined $r && $r == 1;
  };
  return $r;
}


!!42;
