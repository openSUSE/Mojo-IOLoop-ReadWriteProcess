package Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore;
use Mojo::Base -base;

use Carp;
use POSIX qw(O_WRONLY O_CREAT O_NONBLOCK O_NOCTTY);
use IPC::SysV
  qw(ftok IPC_NOWAIT IPC_CREAT IPC_EXCL S_IRUSR S_IWUSR S_IRGRP S_IWGRP S_IROTH S_IWOTH SEM_UNDO);
use IPC::Semaphore;

use constant DEBUG => $ENV{MOJO_PROCESS_DEBUG};
has key            => 42;
has _sem => sub { $_[0]->_create(shift->key) };
has count  => 1;
has _value => 1;

# The following is an adaptation over IPC::Semaphore::Concurrency
# Some pieces are actually a mere copy.
sub _create {

  # Create the semaphore and assign it its initial value
  my $self = shift;
  my $key  = shift;
  warn "[debug:$$] Create semaphore $key" if DEBUG;

  # Presubably the semaphore exists already, so try using it right away
  my $sem = IPC::Semaphore->new($key, 0, 0);
  if (!defined($sem)) {

    # Creatie a new semaphore...
    $sem = IPC::Semaphore->new($key, $self->count,
      IPC_CREAT | IPC_EXCL | S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH
        | S_IWOTH);
    if (!defined($sem)) {

      # Make sure another process did not create it in our back
      $sem = IPC::Semaphore->new($key, 0, 0)
        or carp "Semaphore creation failed!\n";
    }
    else {
      # If we created the semaphore now we assign its initial value
      for (my $i = 0; $i < $self->count; $i++)
      {    # TODO: Support array - see above
        $sem->op($i, $self->_value, 0);
      }
    }
  }

  # Return whatever last semget call got us
  return $sem;
}

sub acquire {
  my $self = shift;

  my %args;
  if (@_ >= 1 && $_[0] =~ /^\d+$/) {

    # Positional arguments
    ($args{'sem'}, $args{'wait'}, $args{'max'}, $args{'undo'}) = @_;
  }
  else {
    %args = @_;
  }

  # Defaults
  $args{'sem'}  = 0  if (!defined($args{'sem'}));
  $args{'wait'} = 0  if (!defined($args{'wait'}));
  $args{'max'}  = -1 if (!defined($args{'max'}));
  $args{'undo'} = 1  if (!defined($args{'undo'}));
  warn "[debug:$$] Acquire semaphore " . $self->key if DEBUG;

  my $sem   = $self->_sem;
  my $flags = IPC_NOWAIT;
  $flags |= SEM_UNDO if ($args{'undo'});

  my ($ret, $ncnt);

# Get blocked process count here to retain Errno (thus $!) after the first semop call.
  $ncnt = $self->getncnt($args{'sem'}) if ($args{'wait'});

  if (($ret = $sem->op($args{'sem'}, -1, $flags))) {
    return $ret;
  }
  elsif ($args{'wait'}) {
    return $ret if ($args{'max'} >= 0 && $ncnt >= $args{'max'});

    # Remove NOWAIT and block
    $flags ^= IPC_NOWAIT;
    return $sem->op($args{'sem'}, -1, $flags);
  }
  return $ret;
}


sub getall { shift->_sem->getall() }

sub getval { shift->_sem->getval(shift // 0) }

sub getncnt { shift->_sem->getncnt(shift // 0) }

sub setall { shift->_sem->setall(@_) }

sub setval { shift->_sem->setval(@_) }

sub stat { shift->_sem->stat() }

sub id { shift->_sem->id() }

sub release { shift->_sem->op(shift || 0, 1, 0) }

sub remove { shift->_sem->remove() }

!!42;
