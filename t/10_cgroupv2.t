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
use Mojo::IOLoop::ReadWriteProcess::CGroup qw(cgroupv2);

subtest mock => sub {
  my $cgroup = cgroupv2(name => "foo");

  isa_ok $cgroup, 'Mojo::IOLoop::ReadWriteProcess::CGroup::v2';

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

  $cgroup->type('test');
  is $cgroup->type, 'test', 'Correct CGroup type set';

  ok -e $cgroup->_cgroup->child(
    Mojo::IOLoop::ReadWriteProcess::CGroup::v2::TYPE_INTERFACE()),
    'CGroup type interface exists';
  is $cgroup->_cgroup->child(
    Mojo::IOLoop::ReadWriteProcess::CGroup::v2::TYPE_INTERFACE())->slurp,
    'test', 'CGroup type interface is correct';

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

  is $cgroup->populated, undef, 'Not populated - mocked test';  # We are mocking

  $cgroup->subtree_control('+cpu +memory -io');
  is $cgroup->subtree_control, '+cpu +memory -io', 'Correct CGroup type set';

  ok -e $cgroup->_cgroup->child(
    Mojo::IOLoop::ReadWriteProcess::CGroup::v2::SUBTREE_CONTROL_INTERFACE()),
    'CGroup controllers interface exists';
  is $cgroup->_cgroup->child(
    Mojo::IOLoop::ReadWriteProcess::CGroup::v2::SUBTREE_CONTROL_INTERFACE())
    ->slurp, '+cpu +memory -io', 'CGroup controllers interface is correct';

  $cgroup->io->max('20');
  is $cgroup->io->max, '20', 'Correct io.max set';

  $cgroup->cpu->max('30');
  is $cgroup->cpu->max, '30', 'Correct cpu.max set';

  $cgroup->memory->max('4');
  is $cgroup->memory->max, '4', 'Correct memory.max set';

  $cgroup->rdma->max('5');
  is $cgroup->rdma->max, '5', 'Correct rdma.max set';

  $cgroup->pid->max('6');
  is $cgroup->pid->max, '6', 'Correct pid.max set';

  my $cgroup2
    = cgroupv2->from(path($ENV{MOJO_CGROUP_FS}, 'test', 'test2', 'test3'));

  is $cgroup2->name,   'test',        "Cgroup name matches";
  is $cgroup2->parent, 'test2/test3', "Cgroup parent matches";

  is $cgroup2->_cgroup,
    path($ENV{MOJO_CGROUP_FS}, 'test', 'test2', 'test3')->to_string;
};

done_testing;
