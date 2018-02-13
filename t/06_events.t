#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use POSIX;
use FindBin;
use Mojo::File qw(tempfile path);
use lib ("$FindBin::Bin/lib", "../lib", "lib");
use Mojo::IOLoop::ReadWriteProcess qw(process);

subtest SIG_CHLD => sub {
  my $test_script = "$FindBin::Bin/data/process_check.sh";
  plan skip_all =>
    "You do not seem to have bash, which is required (as for now) for this test"
    unless -e '/bin/bash';
  plan skip_all =>
"You do not seem to have $test_script. The script is required to run the test"
    unless -e $test_script;
  my $reached;
  my $collect;

# In case of overriding of standard behavior.
# XXX: Flaky tests, re-elaboration is needed
  my $p = process(code => sub { print "Hello\n" }, collect_status => 0);
  $p->on(collect_status => sub { $collect++ });
  $p->on(
    SIG_CHLD => sub {
      my $self = shift;
      $reached++;
      while ((my $pid = waitpid(-1, WNOHANG)) > 0) {
        $self->emit('collect_status' => $pid);
      }
    });

  $p->start;
  $p->wait;
  $p->stop;

  is $reached, 1, 'SIG_CHLD fired';
  is $collect, 1, 'collect_status fired once';

  ok !!$p->exit_status, 'Got exit status, self-collected';

  my $p2 = process(execute => $test_script, collect_status => 0);

  $p2->on(
    SIG_CHLD => sub {
      my $self = shift;
      $reached++;
      while ((my $pid = waitpid(-1, WNOHANG)) > 0) {
        $self->emit('collect_status' => $pid);
      }
    });

  $p2->start;
  sleep 1 until $p2->is_running;
  $p2->stop;

  is $reached, 2, 'SIG_CHLD fired';
  ok !!$p2->exit_status, 'Got exit status, self-collected';
};

subtest collect_status => sub {
  my $collect;
  my $sigcld;
  my $p = process(code => sub { print "Hello\n" }, collect_status => 0);
  $p->on(collect_status => sub { $collect++ });
  $p->on(
    SIG_CHLD => sub {
      $sigcld++;
    });
  $p->start;
  sleep 1 until $p->is_running;
  $p->stop();
  is $collect, undef, 'No collect_status fired';
  is $sigcld,  1,     'SIG_CHLD fired';

};

done_testing();
