[![Build Status](https://travis-ci.org/mudler/Mojo-IOLoop-ReadWriteProcess.svg?branch=master)](https://travis-ci.org/mudler/Mojo-IOLoop-ReadWriteProcess)
# NAME

Mojo::IOLoop::ReadWriteProcess - Execute external programs or internal code blocks as separate process.

# SYNOPSIS

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

# DESCRIPTION

Mojo::IOLoop::ReadWriteProcess is yet another process manager.

# EVENTS

[Mojo::IOLoop::ReadWriteProcess](https://metacpan.org/pod/Mojo::IOLoop::ReadWriteProcess) inherits all events from [Mojo::EventEmitter](https://metacpan.org/pod/Mojo::EventEmitter) and can emit
the following new ones.

## process\_error

    $process->on(process_error => sub {
      my ($e) = @_;
      @errors = @{$e};
    });

Emitted when the process produce errors.

## start

    $process->on(start => sub {
      my ($process) = @_;
      $process->is_running();
    });

Emitted when the process starts.

## stop

    $process->on(stop => sub {
      my ($process) = @_;
      $process->restart();
    });

Emitted when the process stops.

# ATTRIBUTES

[Mojo::IOLoop::ReadWriteProcess](https://metacpan.org/pod/Mojo::IOLoop::ReadWriteProcess) inherits all attributes from [Mojo::EventEmitter](https://metacpan.org/pod/Mojo::EventEmitter) and implements
the following new ones.

## execute

    use Mojo::IOLoop::ReadWriteProcess;
    my $process = Mojo::IOLoop::ReadWriteProcess->new(execute => "/usr/bin/perl");
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop();

`execute` should contain the external program that you wish to run.

## code

    use Mojo::IOLoop::ReadWriteProcess;
    my $process = Mojo::IOLoop::ReadWriteProcess->new(code => sub { print "Hello" } );
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop();

It represent the code you want to run in background.

You do not need to specify `code`, it is implied if no arguments is given.

    my $process = Mojo::IOLoop::ReadWriteProcess->new(sub { print "Hello" });
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop();

## args

    use Mojo::IOLoop::ReadWriteProcess;
    my $process = Mojo::IOLoop::ReadWriteProcess->new(code => sub { print "Hello ".shift() }, args => "User" );
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop();

    # The process will print "Hello User"

Array or arrayref of options to pass by to the external binary or the code block.

## blocking\_stop

    use Mojo::IOLoop::ReadWriteProcess;
    my $process = Mojo::IOLoop::ReadWriteProcess->new(code => sub { print "Hello" }, blocking_stop => 1 );
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop(); # Will wait indefinitely until the process is stopped

Set it to 1 if you want to do blocking stop of the process.

## max\_kill\_attempts

    use Mojo::IOLoop::ReadWriteProcess;
    my $process = Mojo::IOLoop::ReadWriteProcess->new(code => sub { print "Hello" }, max_kill_attempts => 50 );
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop(); # It will attempt to send SIGTERM 50 times.

Defaults to `5`, is the number of attempts before bailing out.

It can be used with blocking\_stop, so if the number of attempts are exhausted,
a SIGKILL and waitpid will be tried at the end.

## kill\_sleeptime

Defaults to `1`, it's the seconds to wait before attempting SIGKILL when blocking\_stop is setted to 1.

## separate\_err

Defaults to `1`, it will create a separate channel to intercept process STDERR,
otherwise it will be redirected to STDOUT.

## verbose

Defaults to `1`, it indicates message verbosity.

## set\_pipes

Defaults to `1`, If enabled, additional pipes for process communication are automatically set up.

## autoflush

Defaults to `1`, If enabled autoflush of handlers is enabled automatically.

## error

Returns a [Mojo::Collection](https://metacpan.org/pod/Mojo::Collection) of errors.
Note: errors that can be captured only at the end of the process

# METHODS

[Mojo::IOLoop::ReadWriteProcess](https://metacpan.org/pod/Mojo::IOLoop::ReadWriteProcess) inherits all methods from [Mojo::EventEmitter](https://metacpan.org/pod/Mojo::EventEmitter) and implements
the following new ones.

## process()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    my $p = process sub { print "Hello\n" };
    $p->start()->wait_stop;

or even:

    process(sub { print "Hello\n" })->on( stop => sub { print "Done!\n"; } )->start->wait_stop;

Returns a [Mojo::IOLoop::ReadWriteProcess](https://metacpan.org/pod/Mojo::IOLoop::ReadWriteProcess) object that represent a process.

It accepts the same arguments as [Mojo::IOLoop::ReadWriteProcess](https://metacpan.org/pod/Mojo::IOLoop::ReadWriteProcess).

## diag()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    process(sub { print "Hello\n" })->on( stop => sub { shift->diag("Done!") } )->start->wait_stop;

Internal function to print information to STDERR if verbose attribute is set or either DEBUG mode enabled.
You can use it if you wish to display information on the process status.

## parallel()

    use Mojo::IOLoop::ReadWriteProcess qw(parallel);
    my $pool = parallel sub { print "Hello\n" } => 5;
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop();

Returns a [Mojo::IOLoop::ReadWriteProcess::Pool](https://metacpan.org/pod/Mojo::IOLoop::ReadWriteProcess::Pool) object that represent a group of processes.

It accepts the same arguments as [Mojo::IOLoop::ReadWriteProcess](https://metacpan.org/pod/Mojo::IOLoop::ReadWriteProcess), and the last one represent the number of processes to generate.

## batch()

    use Mojo::IOLoop::ReadWriteProcess qw(batch);
    my $pool = batch;
    $pool->add(sub { print "Hello\n" });
    $pool->on(stop => sub { shift->_diag("Done!") })->start->wait_stop;

Returns a [Mojo::IOLoop::ReadWriteProcess::Pool](https://metacpan.org/pod/Mojo::IOLoop::ReadWriteProcess::Pool) object generated from supplied arguments.
It accepts as input the same parameter of [Mojo::IOLoop::ReadWriteProcess::Pool](https://metacpan.org/pod/Mojo::IOLoop::ReadWriteProcess::Pool) constructor ( see parallel() ).

## wait()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    my $p = process(sub { print "Hello\n" })->wait;
    # ... here now you can mangle $p handlers and such

Waits until the process finishes, but does not performs cleanup operations (until stop is called).

## wait\_stop()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    my $p = process(sub { print "Hello\n" })->start->wait_stop;
    # $p is not running anymore, and all possible events have been granted to be emitted.

Waits until the process finishes, and perform cleanup operations.

## errored()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    my $p = process(sub { die "Nooo" })->start->wait_stop;
    $p->errored; # will return "1"

Returns a boolean indicating if the process had errors or not.

## write\_pidfile()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    my $p = process(sub { die "Nooo" } );
    $p->pidfile("foobar");
    $p->start();
    $p->write_pidfile();

Forces writing PID of process to specified pidfile in the attributes of the object.
Useful only if the process have been already started, otherwise if a pidfile it's supplied
as attribute, it will be done automatically.

## write\_stdin()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    my $p = process(sub { my $a = <STDIN>; print STDERR "Hello my name is $a\n"; } )->start;
    $p->write_stdin("Larry");
    # process STDERR will contain: "Hello my name is Larry\n"

Write data to process STDIN.

## write\_channel()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    my $p = process(sub {
                          my $parent_output = $self->channel_out;
                          my $parent_input  = $self->channel_in;

                          while(defined(my $line = <$parent_input>)) {
                            print $parent_output "PONG\n" if $line =~ /PING/i;
                          }
                      } )->start;
    $p->write_channel("PING");
    my $out = $p->read_channel;
    # $out is PONG
    my $child_output = $self->channel_output;
    while(defined(my $line = <$child_output>)) {
        print "Process is replying back with $line!\n";
        $p->write_channel("PING");
    }

Write data to process channel. Note, it's not STDIN, neither STDOUT, it's a complete separate channel
dedicated to parent-child communication.
In the parent process, you can access to the same pipes (but from the opposite direction):

    my $child_output = $self->channel_out;
    my $child_input  = $self->channel_in;

## read\_stdout()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    my $p = process(sub {
                          print "Boo\n"
                      } )->start;
    $p->read_stdout;

Gets a single line from process STDOUT.

## read\_channel()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    my $p = process(sub {
                          my $parent_output = $self->channel_out;
                          my $parent_input  = $self->channel_in;

                          print $parent_output "PONG\n";
                      } )->start;
    $p->read_channel;

Gets a single line from process channel.

## read\_stderr()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    my $p = process(sub {
                          print STDERR "Boo\n"
                      } )->start;
    $p->read_stderr;

Gets a single line from process STDERR.

## read\_all\_stdout()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    my $p = process(sub {
                          print "Boo\n"
                      } )->start;
    $p->read_all_stdout;

Gets all the STDOUT output of the process.

## read\_all\_channel()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    my $p = process(sub {
                          shift->channel_out->write("Ping")
                      } )->start;
    $p->read_all_channel;

Gets all the channel output of the process.

## read\_all\_stderr()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    my $p = process(sub {
                          print STDERR "Boo\n"
                      } )->start;
    $p->read_all_stderr;

Gets all the STDERR output of the process.

## start()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    my $p = process(sub {
                          print STDERR "Boo\n"
                      } )->start;

Starts the process

## exit\_status()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    my $p = process( execute => "/path/to/bin" )->start;

    $p->wait_stop->exit_status;

Inspect the process exit status, it works for forks too, but it does the shifting magic,
which is particularly useful when dealing with external processes.

## signal()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    use POSIX;
    my $p = process( execute => "/path/to/bin" )->start;

    $p->signal(POSIX::SIGKILL);

Send a signal to the process

## stop()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    use POSIX;
    my $p = process( execute => "/path/to/bin" )->start->stop;

Stop the process. Unless you use `wait_stop()`, it will attempt to kill the process
without waiting the process to finish. By defaults it send `SIGTERM` to the child.
You can change that by defining the internal attribute `_default_kill_signal`.
Note, if you want to be \*sure\* that the process gets killed, you can enable the
`blocking_stop` attribute, that will attempt to send `SIGKILL` after `max_kill_attempts`
is reached.

## restart()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    my $p = process( execute => "/path/to/bin" )->restart;

It restarts the process if stopped, or if already running, it stops it first.

## is\_running()

    use Mojo::IOLoop::ReadWriteProcess qw(process);
    my $p = process( execute => "/path/to/bin" )->start;
    $p->is_running;

Boolean, it inspect if the process is currently running or not.

# NAME

Mojo::IOLoop::ReadWriteProcess::Pool - Pool of Mojo::IOLoop::ReadWriteProcess objects.

# SYNOPSIS

    my $n_proc = 20;
    my $fired;

    my $p = parallel sub { print "Hello world\n"; } => $n_proc;

    # Subscribe to all "stop" events in the pool
    $p->once(stop => sub { $fired++; });

    # Start all processes belonging to the pool
    $p->start();

    # Receive the process output
    $p->each(sub { my $p = shift; $p->getline(); });
    $p->wait_stop;

    # Get the last one! (it's a Mojo::Collection!)
    $p->last()->stop();

# METHODS

[Mojo::IOLoop::ReadWriteProcess::Pool](https://metacpan.org/pod/Mojo::IOLoop::ReadWriteProcess::Pool) inherits all methods from [Mojo::Collection](https://metacpan.org/pod/Mojo::Collection) and implements
the following new ones.
Note: It proxies all the other methods of [Mojo::IOLoop::ReadWriteProcess](https://metacpan.org/pod/Mojo::IOLoop::ReadWriteProcess) for the whole process group.

## get

    use Mojo::IOLoop::ReadWriteProcess qw(parallel);
    my $pool = parallel(sub { print "Hello" } => 5);
    $pool->get(4);

Get the element specified in the pool (starting from 0).

## add

    use Mojo::IOLoop::ReadWriteProcess qw(parallel);
    my $pool = pool;
    $pool->add(sub { print "Hello 2! " });

Add the element specified in the pool.

## remove

    use Mojo::IOLoop::ReadWriteProcess qw(parallel);
    my $pool = parallel(sub { print "Hello" } => 5);
    $pool->remove(4);

Remove the element specified in the pool.

# LICENSE

Copyright (C) Ettore Di Giacinto.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Ettore Di Giacinto <edigiacinto@suse.com>
