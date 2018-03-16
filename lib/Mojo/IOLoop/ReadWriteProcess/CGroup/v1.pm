package Mojo::IOLoop::ReadWriteProcess::CGroup::v1;

# Refer to https://www.kernel.org/doc/Documentation/cgroup-v1/ for details

use Mojo::Base 'Mojo::IOLoop::ReadWriteProcess::CGroup';
use Mojo::File 'path';
use Mojo::Collection 'c';
use Carp 'confess';
our @EXPORT_OK = qw(cgroup);
use Exporter 'import';

use constant {PROCS_INTERFACE => 'cgroup.procs', TASKS_INTERFACE => 'tasks'};

use Scalar::Util ();
use Mojo::IOLoop::ReadWriteProcess::CGroup::v1::PID;
use Mojo::IOLoop::ReadWriteProcess::CGroup::v1::RDMA;
use Mojo::IOLoop::ReadWriteProcess::CGroup::v1::Memory;
use Mojo::IOLoop::ReadWriteProcess::CGroup::v1::Devices;
use Mojo::IOLoop::ReadWriteProcess::CGroup::v1::Cpuacct;
use Mojo::IOLoop::ReadWriteProcess::CGroup::v1::Cpuset;
use Mojo::IOLoop::ReadWriteProcess::CGroup::v1::Netcls;
use Mojo::IOLoop::ReadWriteProcess::CGroup::v1::Netprio;

has controller => '';

sub _cgroup {
  path($_[0]->parent
    ?
      path($_[0]->_vfs, $_[0]->controller, $_[0]->name, $_[0]->parent)
    : path($_[0]->_vfs, $_[0]->controller, $_[0]->name));
}

sub child {
  return $_[0]->new(
    name       => $_[0]->name,
    controller => $_[0]->controller,
    parent     => $_[0]->parent ? path($_[0]->parent, $_[1]) : $_[1])->create;
}

has pid => sub {
  my $pid
    = Mojo::IOLoop::ReadWriteProcess::CGroup::v1::PID->new(cgroup => shift);
  Scalar::Util::weaken $pid->{cgroup};
  return $pid;
};

has rdma => sub {
  my $rdma
    = Mojo::IOLoop::ReadWriteProcess::CGroup::v1::RDMA->new(cgroup => shift);
  Scalar::Util::weaken $rdma->{cgroup};
  return $rdma;
};

has memory => sub {
  my $memory
    = Mojo::IOLoop::ReadWriteProcess::CGroup::v1::Memory->new(cgroup => shift);
  Scalar::Util::weaken $memory->{cgroup};
  return $memory;
};

has devices => sub {
  my $devices
    = Mojo::IOLoop::ReadWriteProcess::CGroup::v1::Devices->new(cgroup => shift);
  Scalar::Util::weaken $devices->{cgroup};
  return $devices;
};

has cpuacct => sub {
  my $cpuacct
    = Mojo::IOLoop::ReadWriteProcess::CGroup::v1::Cpuacct->new(cgroup => shift);
  Scalar::Util::weaken $cpuacct->{cgroup};
  return $cpuacct;
};

has cpuset => sub {
  my $cpuset
    = Mojo::IOLoop::ReadWriteProcess::CGroup::v1::Cpuset->new(cgroup => shift);
  Scalar::Util::weaken $cpuset->{cgroup};
  return $cpuset;
};

has netcls => sub {
  my $netcls
    = Mojo::IOLoop::ReadWriteProcess::CGroup::v1::Netcls->new(cgroup => shift);
  Scalar::Util::weaken $netcls->{cgroup};
  return $netcls;
};

has netprio => sub {
  my $netprio
    = Mojo::IOLoop::ReadWriteProcess::CGroup::v1::Netprio->new(cgroup => shift);
  Scalar::Util::weaken $netprio->{cgroup};
  return $netprio;
};

# CGroups process interface
sub add_process {
  $_[0]->_appendln($_[0]->_cgroup->child(PROCS_INTERFACE) => pop);
}

sub process_list { shift->_list(PROCS_INTERFACE) }
sub processes    { c(shift->_listarray(PROCS_INTERFACE)) }

sub contains_process { shift->_contains(+PROCS_INTERFACE() => pop) }

# CGroups thread interface
sub add_thread {
  $_[0]->_appendln($_[0]->_cgroup->child(TASKS_INTERFACE) => pop);
}

sub thread_list { shift->_list(TASKS_INTERFACE) }

sub contains_thread { shift->_contains(+TASKS_INTERFACE() => pop) }

1;

=encoding utf-8

=head1 NAME

Mojo::IOLoop::ReadWriteProcess::CGroup::v1 - CGroups v1 implementation.

=head1 SYNOPSIS

    use Mojo::IOLoop::ReadWriteProcess::CGroup::v1;

    my $cgroup = Mojo::IOLoop::ReadWriteProcess::CGroup::v1->new( name => "test" );

    $cgroup->create;
    $cgroup->exists;
    my $child = $cgroup->child('bar');

=head1 DESCRIPTION

This module uses features that are only available on Linux,
and requires cgroups and capability for unshare syscalls to achieve pid isolation.

=head1 METHODS

L<Mojo::IOLoop::ReadWriteProcess::CGroup::v1> inherits all methods from L<Mojo::Base> and implements
the following new ones.

=head1 LICENSE

Copyright (C) Ettore Di Giacinto.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Ettore Di Giacinto E<lt>edigiacinto@suse.comE<gt>

=cut
