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

# METHODS

# ATTRIBUTES

## execute

The program you want to run.

    use Mojo::IOLoop::ReadWriteProcess;
    my $process = Mojo::IOLoop::ReadWriteProcess->new(execute => "/usr/bin/perl");
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop();

## code

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

## args

Array or arrayref of options to pass by to the external binary or the code block.

    use Mojo::IOLoop::ReadWriteProcess;
    my $process = Mojo::IOLoop::ReadWriteProcess->new(code => sub { print "Hello ".shift() }, args => "User" );
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop();

    # The process will print "Hello User"

## blocking\_stop

Set it to 1 if you want to do blocking stop of the process.

    use Mojo::IOLoop::ReadWriteProcess;
    my $process = Mojo::IOLoop::ReadWriteProcess->new(code => sub { print "Hello" }, blocking_stop => 1 );
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop(); # Will wait indefinitely until the process is stopped

## max\_kill\_attempts

Defaults to 5, is the number of attempts before bailing out.

    use Mojo::IOLoop::ReadWriteProcess;
    my $process = Mojo::IOLoop::ReadWriteProcess->new(code => sub { print "Hello" }, max_kill_attempts => 50 );
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop(); # It will attempt to send SIGTERM 50 times.

It can be used with blocking\_stop, so if the number of attempts are exhausted,
a SIGKILL and waitpid will be tried at the end.

## kill\_sleeptime

Defaults to 1, it's the seconds to wait before attempting SIGKILL when blocking\_stop is setted to 1.

## separate\_err

Defaults to 1, it will create a separate channel to intercept process STDERR.

# METHODS

## parallel()

Returns a [Mojo::IOLoop::ReadWriteProcess::Pool](https://metacpan.org/pod/Mojo::IOLoop::ReadWriteProcess::Pool) object that represent a group of processes.

It accepts the same arguments as [Mojo::IOLoop::ReadWriteProcess](https://metacpan.org/pod/Mojo::IOLoop::ReadWriteProcess), and the last one represent the number of processes to generate.

    use Mojo::IOLoop::ReadWriteProcess qw(parallel);
    my $pool = parallel sub { print "Hello\n" } => 5;
    $pool->start();
    $pool->on( stop => sub { print "Process: ".$p->pid." finished"; );
    $pool->stop();

# LICENSE

Copyright (C) Ettore Di Giacinto.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Ettore Di Giacinto <edigiacinto@suse.com>
