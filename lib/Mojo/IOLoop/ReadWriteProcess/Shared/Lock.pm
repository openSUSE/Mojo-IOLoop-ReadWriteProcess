package Mojo::IOLoop::ReadWriteProcess::Shared::Lock;

use Mojo::Base 'Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore';

our @EXPORT_OK = qw(shared_lock semaphore);
use Exporter 'import';
use constant DEBUG => $ENV{MOJO_PROCESS_DEBUG};

# Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore has same defaults - but locks have 1 count and 1 as setup value
# Make it explict
has count  => 1;
has _value => 1;
has locked => 0;

sub shared_lock { __PACKAGE__->new(@_) }

sub lock {
  my $self = shift;
  warn "[debug:$$] Attempt to acquire lock " . $self->key if DEBUG;
  my $r = @_ > 0 ? $self->acquire(@_) : $self->acquire(wait => 1, undo => 0);
  warn "[debug:$$] lock Returned : $r" if DEBUG;
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
