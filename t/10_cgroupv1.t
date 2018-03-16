#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use POSIX;
use FindBin;
use Mojo::File qw(tempfile tempdir path);
use lib ("$FindBin::Bin/lib", "../lib", "lib");

BEGIN { $ENV{MOJO_CGROUP_FS} = tempdir() }

use Mojo::IOLoop::ReadWriteProcess qw(process);
use Mojo::IOLoop::ReadWriteProcess::Test::Utils qw(attempt);
use Mojo::IOLoop;
use Mojo::IOLoop::ReadWriteProcess::CGroup qw(cgroupv1);

subtest mock => sub {
  my $cgroup = cgroupv1(name => "foo");

  isa_ok $cgroup, 'Mojo::IOLoop::ReadWriteProcess::CGroup::v1';

  my $child_cgroup = $cgroup->child('bar');
  $child_cgroup->create();
  ok $child_cgroup->exists, 'Child cgroup exists';
  ok -d $child_cgroup->_cgroup, 'Folder is created';
  $child_cgroup->remove;
  is $child_cgroup->exists, undef, 'Child group does not exist anymore';

  ok $cgroup->exists, 'Parent CGroup exists';
  ok -d $cgroup->_cgroup, 'Parent CGroup folder exists';
  ok $cgroup->_cgroup ne $child_cgroup->_cgroup,
    'Child and parent has different CGroup path'
    or diag explain [$cgroup, $child_cgroup];
  $cgroup->remove;
  is $cgroup->exists, undef, 'Parent group does not exist anymore';

  $child_cgroup->create();
  $child_cgroup->add_process("3");
  $child_cgroup->add_process("5");
  is $child_cgroup->process_list, "3\n5\n",
    "procs interface contains the added pids"
    or die diag explain $child_cgroup->process_list;

  ok $child_cgroup->contains_process("3"), "Child contains pid 3";
  ok $child_cgroup->contains_process("5"), "Child contains pid 5";
  ok !$child_cgroup->contains_process("10"), "Child does not contain pid 10";
  ok !$child_cgroup->contains_process("20"), "Child does not contain pid 20";

  $cgroup->create();
  $cgroup->add_process("30");
  $cgroup->add_process("50");
  is $cgroup->process_list, "30\n50\n",
    "procs interface contains the added pids"
    or die diag explain $cgroup->process_list;

  ok $cgroup->contains_process("30"), "Parent contains pid 30";
  ok $cgroup->contains_process("50"), "Parent contains pid 50";
  ok !$cgroup->contains_process("3"), "Parent does not contain pid 3";
  ok !$cgroup->contains_process("5"), "Parent does not contain pid 5";

  $cgroup->create();
  $cgroup->add_thread("20");
  $cgroup->add_thread("40");
  is $cgroup->thread_list, "20\n40\n",
    "thread interface contains the added threads ID"
    or die diag explain $cgroup->thread_list;

  ok $cgroup->contains_thread("20"), "Parent contains thread ID 20";
  ok $cgroup->contains_thread("40"), "Parent contains thread ID 40";
  ok !$cgroup->contains_thread("30"), "Parent does not contain thread ID 30";
  ok !$cgroup->contains_thread("50"), "Parent does not contain thread ID 50";


  $cgroup->pid->max('6');
  is $cgroup->pid->max, '6', 'Correct pid.max set';
};

done_testing;
