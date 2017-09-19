# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

=encoding utf-8

=head1 NAME

Mojo::IOLoop::ReadWriteProcess - Execute external programs or internal code blocks as separate process.

=head1 SYNOPSIS

    use Mojo::IOLoop::ReadWriteProcess;

    # Code fork
    my $process = Mojo::IOLoop::ReadWriteProcess->new(sub { print "Hello\n" });
    $process->start();
    my $is_running = $process->is_running(); # Boolean
    my $stdout_line = $process->getline(); # Will return "Hello\n"
    my $pid = $process->pid(); # Process id
    $process->stop();
    $process->wait_stop(); # if you intend to wait its lifespan


    # Methods can be chained, thus this is valid:
    my $p = Mojo::IOLoop::ReadWriteProcess->new(sub { print "Hello\n" })->start()->stop();
    $output = $p->getline();

    # Handles seamelessy also external processes:
    my $process = Mojo::IOLoop::ReadWriteProcess->new(execute=> '/path/to/bin' )->args(qw(foo bar baz));
    $process->start();
    my $line_output = $process->getline();
    my $pid = $process->pid();
    $process->stop();

    # Errors (if any) are stored in the object:
    my @errors = $process->error;

    $process = Mojo::IOLoop::ReadWriteProcess->new(
               separate_err => 0, # merge STDERR to STDOUT
               code => sub {
                              my ($self) = shift;

                              # Access to the parent communication
                              # channels from the child
                              my $parent_output = $self->channel_out;
                              my $parent_input  = $self->channel_in;

                              print "TEST normal print\n";
                              print STDERR "TEST error print\n";

                              $self->channel_out->write("PING?");

                              return "256";
               })->start();
    $process->wait_stop; # We need to stop it to retrieve the exit status
    my $return = $process->return_status;
    # my $return = $process->exit_status; # equivalent
    # $return is 256

    # Still we can access directly to handlers from the object:
    my $stdout = $process->read_stream;
    my $stdin = $process->write_stream;
    my $stderr = $process->error_stream;
    # So this works:
    print $stdin "foo bar\n";
    my @lines = <$stdout>;

    # There is also an alternative channel of communication (just for forked processes):
    my $channel_in = $process->channel_in; # write to the child process
    my $channel_out = $process->channel_out; # read from the child process
    $process->channel_write("PING"); # convenience function


=head1 DESCRIPTION

Mojo::IOLoop::ReadWriteProcess is yet another process manager.


=head1 METHODS

=cut

package Mojo::IOLoop::ReadWriteProcess;

our $VERSION = "0.04";

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::File 'path';

our @EXPORT_OK = qw(parallel batch process);
use Exporter 'import';
use B::Deparse;
use Carp 'confess';
use IO::Handle;
use IO::Pipe;
use IO::Select;
use IPC::Open3;
use POSIX ":sys_wait_h";
use Symbol 'gensym';

use constant DEBUG => $ENV{MOJO_PROCESS_DEBUG};

has [
  qw(execute code write_stream process_id read_stream error_stream channel_in channel_out pidfile),
  qw(_internal_err _internal_return _status)
];
has blocking_stop         => 0;
has max_kill_attempts     => 5;
has kill_sleeptime        => 1;
has sleeptime_during_kill => 1;
has args                  => sub { [] };
has separate_err          => 1;
has autoflush             => 1;
has error                 => sub { Mojo::Collection->new };
has set_pipes             => 1;
has verbose               => 1;
has _deparse              => sub { B::Deparse->new }
  if DEBUG;

has _default_kill_signal => POSIX::SIGTERM;

=head1 ATTRIBUTES

=head2 execute

The program you want to run.

    use Mojo::IOLoop::ReadWriteProcess;
    my $process = Mojo::IOLoop::ReadWriteProcess->new(execute => "/usr/bin/perl");
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop();

=head2 code

The code you want to run in background.

    use Mojo::IOLoop::ReadWriteProcess;
    my $process = Mojo::IOLoop::ReadWriteProcess->new(code => sub { print "Hello" } );
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop();

You do not need to specify code, it is implied if no arguments is given.

    my $process = Mojo::IOLoop::ReadWriteProcess->new(sub { print "Hello" });
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop();

=head2 args

Array or arrayref of options to pass by to the external binary or the code block.

    use Mojo::IOLoop::ReadWriteProcess;
    my $process = Mojo::IOLoop::ReadWriteProcess->new(code => sub { print "Hello ".shift() }, args => "User" );
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop();

    # The process will print "Hello User"

=head2 blocking_stop

Set it to 1 if you want to do blocking stop of the process.

    use Mojo::IOLoop::ReadWriteProcess;
    my $process = Mojo::IOLoop::ReadWriteProcess->new(code => sub { print "Hello" }, blocking_stop => 1 );
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop(); # Will wait indefinitely until the process is stopped


=head2 max_kill_attempts

Defaults to 5, is the number of attempts before bailing out.

    use Mojo::IOLoop::ReadWriteProcess;
    my $process = Mojo::IOLoop::ReadWriteProcess->new(code => sub { print "Hello" }, max_kill_attempts => 50 );
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop(); # It will attempt to send SIGTERM 50 times.

It can be used with blocking_stop, so if the number of attempts are exhausted,
a SIGKILL and waitpid will be tried at the end.

=head2 kill_sleeptime

Defaults to 1, it's the seconds to wait before attempting SIGKILL when blocking_stop is setted to 1.

=head2 separate_err

Defaults to 1, it will create a separate channel to intercept process STDERR.

=head1 METHODS

=cut

# Override new() just to support sugar syntax
# so it is possible to do : process->new(sub{ print "Hello World\n" })->start->stop; and so on.
sub new {
  push(@_, code => splice @_, 1, 1) if ref $_[1] eq "CODE";
  return shift->SUPER::new(@_);
}

sub process { Mojo::IOLoop::ReadWriteProcess->new(@_) }

sub _diag {
  my ($self, @messages) = @_;
  my $caller = (caller(1))[3];
  print STDERR ">> ${caller}(): @messages\n" if $self->verbose;
}

=head2 parallel()

Returns a L<Mojo::IOLoop::ReadWriteProcess::Pool> object that represent a group of processes.

It accepts the same arguments as L<Mojo::IOLoop::ReadWriteProcess>, and the last one represent the number of processes to generate.

    use Mojo::IOLoop::ReadWriteProcess qw(parallel);
    my $pool = parallel sub { print "Hello\n" } => 5;
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop();

=cut

sub parallel {
  my $c = batch();
  $c->add(@_) for 1 .. +pop();
  return $c;
}
sub batch { return Mojo::IOLoop::ReadWriteProcess::Pool->new(@_) }

sub _open {
  my ($self, @args) = @_;
  $self->_diag('Execute: ' . (join ', ', map { "'$_'" } @args)) if DEBUG;
  $SIG{CHLD} = sub {
    local ($!, $?);
    $self->_shutdown while ((my $pid = waitpid(-1, WNOHANG)) > 0);
  };

  my ($wtr, $rdr, $err);
  $err = gensym;
  my $pid = open3($wtr, $rdr, ($self->separate_err) ? $err : undef, @args);

  die "Cannot create pipe: $!" unless defined $pid;
  $self->process_id($pid);

  # Defered collect of return status and removal of pidfile
  $self->once(collect_status =>
      sub { $self->_status($?); unlink($self->pidfile) if $self->pidfile; });

  return $self unless $self->set_pipes();

  $self->read_stream(IO::Handle->new_from_fd($rdr, "r"));
  $self->write_stream(IO::Handle->new_from_fd($wtr, "w"));
  $self->error_stream(($self->separate_err) ?
      IO::Handle->new_from_fd($err, "r")
    : $self->write_stream);

  return $self;
}

sub _fork {
  my ($self, $code, @args) = @_;
  die "Can't spawn child without code" unless ref($code) eq "CODE";

  # STDIN/STDOUT/STDERR redirect.
  my ($input_pipe, $output_pipe, $output_err_pipe);

  # Separated handles that could be used for internal comunication.
  my ($channel_in, $channel_out);

  if ($self->set_pipes) {
    $input_pipe      = IO::Pipe->new();
    $output_pipe     = IO::Pipe->new();
    $output_err_pipe = IO::Pipe->new();
    $channel_in      = IO::Pipe->new();
    $channel_out     = IO::Pipe->new();
  }

  my $internal_err    = IO::Pipe->new();
  my $internal_return = IO::Pipe->new();

  # Internal pipes to retrieve error/return
  $self->_internal_err($internal_err);
  $self->_internal_return($internal_return);

  # Defered collect of return status
  $self->once(
    collect_status => sub {
      my $self = shift;
      $self or return;
      my $return_reader
        = $self->_internal_return->isa("IO::Pipe::End")
        ?
        $self->_internal_return
        : $self->_internal_return->reader();
      my $internal_err_reader
        = $self->_internal_err->isa("IO::Pipe::End") ?
        $self->_internal_err
        : $self->_internal_err->reader();
      $self->_new_err('Cannot read from return code pipe') && return
        unless IO::Select->new($return_reader)->can_read(10);
      $self->_new_err('Cannot read from errors code pipe') && return
        unless IO::Select->new($internal_err_reader)->can_read(10);

      my @result_return = $return_reader->getlines();
      my @result_error  = $internal_err_reader->getlines();

      $self->_diag("Forked code Process Errors: " . join("\n", @result_error))
        if DEBUG;
      $self->_diag("Forked code Process Returns: " . join("\n", @result_return))
        if DEBUG;

      $self->_status(@result_return) if @result_return;
      push(
        @{$self->error},
        map { Mojo::IOLoop::ReadWriteProcess::Exception->new($_) }
          @result_error
      ) if @result_error;
      unlink($self->pidfile) if $self->pidfile;
    });


  if (DEBUG) {
    my $code_str = $self->_deparse->coderef2text($code);
    $self->_diag("Fork: $code_str");
  }


  my $pid = fork;
  die "Cannot fork: $!" unless defined $pid;

  if ($pid == 0) {
    local $SIG{CHLD};
    local $SIG{TERM} = sub { $self->_exit(1) };

    my $return
      = $self->_internal_return->isa("IO::Pipe::End") ?
      $self->_internal_return
      : $self->_internal_return->writer();
    my $internal_err
      = $self->_internal_err->isa("IO::Pipe::End") ?
      $self->_internal_err
      : $self->_internal_err->writer();
    $return->autoflush(1);
    $internal_err->autoflush(1);

    # Set pipes to redirect STDIN/STDOUT/STDERR + channels if desired
    if ($self->set_pipes()) {
      my $stdout = $output_pipe->writer();
      my $stderr = ($self->separate_err) ? $output_err_pipe->writer() : $stdout;
      my $stdin  = $input_pipe->reader();
      open STDERR, ">&", $stderr or !!$internal_err->write($!) or die $!;
      open STDOUT, ">&", $stdout or !!$internal_err->write($!) or die $!;
      open STDIN,  ">&", $stdin  or !!$internal_err->write($!) or die $!;

      $self->read_stream($stdin);
      $self->error_stream($stderr);
      $self->write_stream($stdout);

      $self->channel_in($channel_in->reader);
      $self->channel_out($channel_out->writer);
      $self->$_->autoflush($self->autoflush)
        for qw(read_stream error_stream write_stream channel_in channel_out);
    }
    $! = 0;
    my $rt;
    eval { $rt = $code->($self, @args); };
    $internal_err->write($@) if $@;
    $internal_err->write($!) if !$@ && $!;
    $return->write($rt);
    $self->_exit($@ // $!);
  }
  $self->process_id($pid);

  $SIG{CHLD} = sub {
    local ($!, $?);
    $self->_shutdown while ((my $pid = waitpid(-1, WNOHANG)) > 0);
  };

  return $self unless $self->set_pipes();

  $self->read_stream($output_pipe->reader);
  $self->error_stream(
    ($self->separate_err) ? $output_err_pipe->reader() : $self->read_stream());
  $self->write_stream($input_pipe->writer);
  $self->channel_in($channel_in->writer);
  $self->channel_out($channel_out->reader);
  $self->$_->autoflush($self->autoflush)
    for qw(read_stream error_stream write_stream channel_in channel_out);

  return $self;
}

sub _new_err {
  my $self = shift;
  my $err  = Mojo::IOLoop::ReadWriteProcess::Exception->new(@_);
  push(@{$self->error}, $err);

  $self->emit(process_error => [$err]);
  return $self;
}

sub _exit {
  my $code = shift // 0;
  eval { POSIX::_exit($code); };
  exit($code);
}

sub wait {
  my $self = shift;
  sleep $self->sleeptime_during_kill while ($self->is_running);
  return $self;
}

sub wait_stop { shift->wait->stop }

sub errored { !!@{shift->error} ? 1 : 0 }

sub write_pidfile {
  my ($self, $pidfile) = @_;
  $self->pidfile($pidfile) if $pidfile;
  return unless $self->pid;
  return unless $self->pidfile;

  path($self->pidfile)->spurt($self->pid);
  return $self;
}

# Convenience functions
sub _syswrite {
  my $stream = shift;
  return unless $stream;
  $stream->syswrite($_ . "\n") for @_;
}

sub _getline {
  return unless IO::Select->new($_[0])->can_read(10);
  shift->getline;
}

sub _getlines {
  return unless IO::Select->new($_[0])->can_read(10);
  wantarray ? shift->getlines : join '\n', @{[shift->getlines]};
}

# Write to the controlled-process STDIN
sub write_stdin {
  my ($self, @data) = @_;
  _syswrite($self->write_stream, @data);
  return $self;
}

# Write to the channel
sub write_channel {
  my ($self, @data) = @_;
  _syswrite($self->channel_in, @data);
  return $self;
}

# Get a line from the current process output stream
sub read_stdout { _getline(shift->read_stream) }

# Get a line from the process channel
sub read_channel { _getline(shift->channel_out) }

# Get a line from the current process output stream
sub read_stderr {
  return $_[0]->getline unless $_[0]->separate_err;
  _getline(shift->error_stream);
}

# Get all lines from the current process output stream
sub read_all_stdout { _getlines(shift->read_stream) }

# Get all lines from the process channel
sub read_all_channel { _getlines(shift->channel_out); }

# Get all lines from the current process output stream
sub read_all_stderr {
  return $_[0]->getline unless $_[0]->separate_err;
  _getlines(shift->error_stream);
}

# Start the process
sub start {
  my $self = shift;
  return $self if $self->is_running;
  die "Nothing to do" unless !!$self->execute || !!$self->code;

  my @args
    = $self->args ?
    ref($self->args) eq "ARRAY"
      ? @{$self->args}
      : $self->args
    : ();

  if ($self->code) {
    $self->_fork($self->code, @args);
  }
  elsif ($self->execute) {
    $self->_open($self->execute, @args);
  }

  $self->write_pidfile;
  $self->emit('start');

  return $self;
}

sub exit_status {
  $_[0]->_status ? shift->_status >> 8 : undef;
}

sub signal {
  my $self = shift;
  my $signal = shift // $self->_default_kill_signal;
  return unless $self->is_running;
  $self->_diag("Sending signal '$signal' to " . $self->process_id) if DEBUG;
  kill $signal => $self->process_id;
  return $self;
}

# Stop the process and retrieve child status
sub stop {
  my $self = shift;
  return $self->_shutdown unless $self->is_running;

  my $ret;
  my $attempt = 1;
  until ((defined $ret && $ret == $self->process_id)
      || !$self->is_running
      || $attempt > $self->max_kill_attempts)
  {
    $self->_diag("attempt ($attempt/"
        . $self->max_kill_attempts
        . ") to kill process: "
        . $self->pid)
      if DEBUG;
    sleep $self->sleeptime_during_kill if $self->sleeptime_during_kill;
    $self->signal();
    $ret = waitpid($self->process_id, WNOHANG);
    $self->_status($?);
    $attempt++;
  }

  sleep $self->kill_sleeptime if $self->kill_sleeptime;

  if ($self->blocking_stop && $self->is_running) {
    $self->_diag(
      "Could not kill process id: " . $self->process_id . " going for SIGKILL")
      if DEBUG;
    $self->signal(POSIX::SIGKILL);
    waitpid($self->process_id, 0);
    $self->_status($?);
  }
  elsif ($self->is_running) {
    $self->_diag("Could not kill process id: " . $self->process_id) if DEBUG;
    $self->_new_err('Could not kill process');
  }

  return $self->_shutdown;
}

sub _shutdown {
  my $self = shift;
  $self->emit('collect_status');
  $self->emit('process_error', $self->error)
    if $self->error && $self->error->size > 0;
  $self->emit('stop');
  return $self;
}

# Restart process if running, otherwise starts it
sub restart { $_[0]->is_running ? $_[0]->stop->start : $_[0]->start; }

# Check if process is currently running
sub is_running { return $_[0]->process_id ? kill 0 => $_[0]->process_id : 0; }

sub DESTROY { +shift()->_shutdown; }

# General alias
*pid           = \&process_id;
*return_status = \&_status;
*died          = \&_errored;

# Aliases - write
*write         = \&write_stdin;
*stdin         = \&write_stdin;
*channel_write = \&write_channel;

# Aliases - read
*read             = \&read_stdout;
*stdout           = \&read_stdout;
*getline          = \&read_stdout;
*stderr           = \&read_stderr;
*err_getline      = \&read_stderr;
*channel_read     = \&read_channel;
*read_all         = \&read_all_stdout;
*getlines         = \&read_all_stdout;
*stderr_all       = \&read_all_stderr;
*err_getlines     = \&read_all_stderr;
*channel_read_all = \&read_all_channel;

# Aliases - IO::Handle
*stdin_handle        = \&write_stream;
*stdout_handle       = \&read_stream;
*stderr_handle       = \&error_stream;
*channe_write_handle = \&channel_in;
*channel_read_handle = \&channel_out;

=head1 LICENSE

Copyright (C) Ettore Di Giacinto.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Ettore Di Giacinto E<lt>edigiacinto@suse.comE<gt>

=cut

package Mojo::IOLoop::ReadWriteProcess::Pool;

use Mojo::Base 'Mojo::Collection';

sub _cmd {
  my $c    = shift;
  my $f    = pop;
  my @args = @_;
  my @r;
  $c->each(
    sub {
      push(@r, +shift()->$f(@args));
    });
  wantarray ? @r : $c;
}

sub get { my $s = shift; @{$s}[+shift()] }
sub add { push @{+shift()}, Mojo::IOLoop::ReadWriteProcess->new(@_) }
sub remove { my $s = shift; delete @{$s}[+shift()] }
sub start  { shift->_cmd('start') }
sub stop   { shift->_cmd('stop') }
sub wait_stop { shift->_cmd('wait_stop') }
sub once      { shift->_cmd(@_, 'once') }
sub wait      { shift->_cmd(@_, 'wait') }

sub restart { shift->_cmd('restart') }
sub on      { shift->_cmd(@_, 'on') }
sub emit    { shift->_cmd(@_, 'emit') }

# sub AUTOLOAD {
#   our $AUTOLOAD;
#   my $fn = $AUTOLOAD;
#   $fn =~ s/.*:://;
#   return if $fn eq "DESTROY";
#   +shift()->_cmd(@_, $fn);
# }

package Mojo::IOLoop::ReadWriteProcess::Exception;
use Mojo::Base -base;

sub new {
  my $class = shift;
  my $value = @_ == 1 ? $_[0] : "";
  return bless \$value, ref $class || $class;
}

sub to_string { "${$_[0]}" }

1;

__END__
