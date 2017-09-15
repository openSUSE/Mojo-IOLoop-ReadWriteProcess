[![Build Status](https://travis-ci.org/mudler/Mojo-IOLoop-ReadWriteProcess.svg?branch=master)](https://travis-ci.org/mudler/Mojo-IOLoop-ReadWriteProcess)
# NAME

Mojo::IOLoop::ReadWriteProcess - Execute external programs or internal code blocks as separate process.

# SYNOPSIS

    use Mojo::IOLoop::ReadWriteProcess;

    # Fork process:
    my $process = Mojo::IOLoop::ReadWriteProcess->new(sub { print "Hello\n" });
    $process->start();
    my $is_running = $process->is_running();
    my $hello = $process->getline(); # just a convenient function around the handler
    my $pid = $process->pid();
    $process->stop();

    #  $hello is "Hello\n"
    # $pid will contain the process id
    # $is_running will be 1 if the process is still in execution when called

    my $p = Mojo::IOLoop::ReadWriteProcess->new(sub { print "Hello\n" })->start()->stop();
    $output = $p->getline();

    # Handles seamelessy also external processes:

    my $process = Mojo::IOLoop::ReadWriteProcess->new(execute=> '/path/to/bin' )->args([qw(foo bar baz)]);
    $process->start();
    my $hello = $process->getline();
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
    $process->stop unless $process->is_running; # We need to stop it to retrieve the exit status
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

# LICENSE

Copyright (C) Ettore Di Giacinto.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Ettore Di Giacinto <edigiacinto@suse.com>
