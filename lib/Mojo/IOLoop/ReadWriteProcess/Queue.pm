package Mojo::IOLoop::ReadWriteProcess::Queue;
use Mojo::Base -base;
use Scalar::Util qw(blessed);
use Mojo::IOLoop::ReadWriteProcess::Pool;
use Mojo::IOLoop::ReadWriteProcess;
has queue => sub { Mojo::IOLoop::ReadWriteProcess::Pool->new() };
has pool  => sub { Mojo::IOLoop::ReadWriteProcess::Pool->new() };

has [qw(auto_start auto_start_add)] => 0;

sub _dequeue {
  my $self    = shift;
  my $process = shift;

  $self->pool->remove($process);    # remove from $self Collection

# pick first from queue and remove it get(0), remove(0)


  shift @{$self->queue}
    if ($self->queue->first && $self->add($self->queue->first));

  $self->pool->last->start if $self->auto_start;

}

sub exhausted {
  shift->pool->size == 0;
}

sub consume {
  my $p = shift;
  until ($p->exhausted) {
    $p->start;
    $p->wait_stop;
  }
}

sub add {
  my $self = shift;

  return $self->queue->add(@_) unless $self->pool->add(@_);
  my $i = $self->pool->size - 1;
  $self->pool->last->once(stop => sub { $self->_dequeue($i) });

  $self->pool->last->start if $self->auto_start_add == 1;
  $self->pool->last;
}

sub AUTOLOAD {
  our $AUTOLOAD;
  my $fn = $AUTOLOAD;
  $fn =~ s/.*:://;
  return if $fn eq "DESTROY";
  my $self = shift;
  return (
    eval { $self->pool->Mojo::IOLoop::ReadWriteProcess::Pool::_cmd(@_, $fn) },
    (grep(/once|on|emit/, $fn))
    ?
      eval { $self->queue->Mojo::IOLoop::ReadWriteProcess::Pool::_cmd(@_, $fn) }
    : ());
}

1;

=encoding utf-8

=head1 NAME

Mojo::IOLoop::ReadWriteProcess::Pool - Pool of Mojo::IOLoop::ReadWriteProcess objects.

=head1 SYNOPSIS

    use Mojo::IOLoop::ReadWriteProcess qw(parallel);
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

=head1 METHODS

L<Mojo::IOLoop::ReadWriteProcess::Pool> inherits all methods from L<Mojo::Collection> and implements
the following new ones.
Note: It proxies all the other methods of L<Mojo::IOLoop::ReadWriteProcess> for the whole process group.

=head2 get

    use Mojo::IOLoop::ReadWriteProcess qw(parallel);
    my $pool = parallel(sub { print "Hello" } => 5);
    $pool->get(4);

Get the element specified in the pool (starting from 0).

=head2 add

    use Mojo::IOLoop::ReadWriteProcess qw(pool);
    my $pool = pool(maximum_processes => 2);
    $pool->add(sub { print "Hello 2! " });

Add the element specified in the pool.

=head2 remove

    use Mojo::IOLoop::ReadWriteProcess qw(parallel);
    my $pool = parallel(sub { print "Hello" } => 5);
    $pool->remove(4);

Remove the element specified in the pool.

=head2 maximum_processes

    use Mojo::IOLoop::ReadWriteProcess qw(parallel);
    my $pool = parallel(sub { print "Hello" } => 5);
    $pool->maximum_processes(30);
    $pool->add(...);

Prevent from adding processes to the pool. If we reach C<maximum_processes> number
of processes, C<add()> will refuse to add more to the pool.

=head1 ENVIRONMENT

You can set the MOJO_PROCESS_MAXIMUM_PROCESSES environment variable to specify the
the maximum number of processes allowed in L<Mojo::IOLoop::ReadWriteProcess> instances.

    MOJO_PROCESS_MAXIMUM_PROCESSES=10000

=head1 LICENSE

Copyright (C) Ettore Di Giacinto.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Ettore Di Giacinto E<lt>edigiacinto@suse.comE<gt>

=cut
