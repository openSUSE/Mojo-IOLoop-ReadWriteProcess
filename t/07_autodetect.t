#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use POSIX;
use FindBin;
use Mojo::File qw(tempfile path);
use lib ("$FindBin::Bin/lib", "../lib", "lib");
use Mojo::IOLoop::ReadWriteProcess qw(process);

subtest autodetect => sub {
  local $SIG{CHLD};

  my $reached;
  my $collect;
  my $status;
  my $fired;

  my $orphan2
    = process(sub { print "Hello from first process\n"; sleep 1 })->start;
  my $orphan
    = process(sub { print "Hello from second process\n"; sleep 1 })->start;
  my $p = process(
    code => sub {
      print "Hello from master process\n";
      sleep 2;
      return 2;
    },
    detect_subprocess => 1
  );

  $p->on(new_subprocess => sub { $fired++ });
  $p->on(collect_status => sub { $status++ });

  $p->start();

  sleep 1
    for (0 .. 10)
    ;    # If we just sleep and then exit, we won't be able to catch signals

  $p->stop;
  is $status, 3, 'Status fired 3 times';
  is $p->subprocess->size, 2, 'detection works' or die diag explain $p;

  is $p->subprocess->grep(sub { $_->pid eq $orphan->pid })->first->pid,
    $orphan->pid, 'Orphan collected';
  is $p->subprocess->grep(sub { $_->pid eq $orphan2->pid })->first->pid,
    $orphan2->pid, 'Orphan2 collected';

  is $fired, 2, 'New subprocess event fired';
  is $p->return_status, 2, 'Got exit status from master';
};

subtest autodetect_fork => sub {
  my $fired;
  my $status;
  local $SIG{CHLD};

  my $master_p = process(sub { });
  $master_p->detect_subprocess(1);
  $master_p->on(new_subprocess => sub { $fired++ });
  $master_p->on(collect_status => sub { $status++ });
  $master_p->start();

  # Fork, and die after a bit
  my $pid = fork;
  die "Cannot fork: $!" unless defined $pid;
  if ($pid == 0) { sleep 2; exit 110 }
  $pid = fork;
  die "Cannot fork: $!" unless defined $pid;
  if ($pid == 0) { sleep 2; exit 110 }
  $pid = fork;
  die "Cannot fork: $!" unless defined $pid;
  if ($pid == 0) { sleep 2; exit 110 }
  $pid = fork;
  die "Cannot fork: $!" unless defined $pid;
  if ($pid == 0) { sleep 2; exit 110 }
  $pid = fork;
  die "Cannot fork: $!" unless defined $pid;
  if ($pid == 0) { sleep 2; exit 110 }
  $pid = fork;
  die "Cannot fork: $!" unless defined $pid;
  if ($pid == 0) { sleep 2; exit 110 }

  sleep 1
    for (0 .. 20)
    ;    # If we just sleep and then exit, we won't be able to catch signals
  $master_p->stop;
  is $status, 7, 'Status fired 7 times';
  is $fired,  6, 'Status fired 7 times';

  is $master_p->subprocess->size, 6, 'detection works'
    or die diag explain $master_p;

  $master_p->subprocess->each(
    sub { is $_->exit_status, 110, 'Correct status from process ' . $_->pid });
};


subtest subreaper => sub {
  my $fired;
  my $status;
  local $SIG{CHLD};

  my $sys;
  eval { $sys = Mojo::IOLoop::ReadWriteProcess::_get_prctl_syscall; };
  plan skip_all => "You do not seem to have subreaper capabilities"
    if ($@ || !defined $sys);

  my $master_p = process(
    sub {
      # Fork, and die after a bit
      my $pid = fork;
      die "Cannot fork: $!" unless defined $pid;
      if ($pid == 0) { sleep 2; exit 120 }
      $pid = fork;
      die "Cannot fork: $!" unless defined $pid;
      if ($pid == 0) {
        $pid = fork;
        die "Cannot fork: $!" unless defined $pid;
        if ($pid == 0) { sleep 2; exit 120 }
        exit 120;
      }
      $pid = fork;
      die "Cannot fork: $!" unless defined $pid;
      if ($pid == 0) {
        $pid = fork;
        die "Cannot fork: $!" unless defined $pid;
        if ($pid == 0) {
          $pid = fork;
          die "Cannot fork: $!" unless defined $pid;
          if ($pid == 0) {
            $pid = fork;
            die "Cannot fork: $!" unless defined $pid;
            if ($pid == 0) { sleep 2; exit 120 }
            sleep 2;
            exit 120;
          }
          exit 120;
        }
        exit 120;
      }
    });

  $master_p->detect_subprocess(1);
  $master_p->subreaper(1);
  $master_p->on(new_subprocess => sub { $fired++ });
  $master_p->on(collect_status => sub { $status++ });

  # On start we setup the current process as subreaper
  # So it's up on us to disable it after process is done.
  $master_p->on(stop => sub { shift()->disable_subreaper });
  $master_p->start();

  sleep 1
    for (0 .. 10)
    ;    # If we just sleep and then exit, we won't be able to catch signals

  $master_p->stop();
  is $status, 8, 'collect_status fired 8 times';
  is $fired,  7, 'new_subprocess fired 7 times';

  is $master_p->subprocess->size, 7, 'detection works'
    or die diag explain $master_p;
  $master_p->subprocess->each(
    sub { is $_->exit_status, 120, 'Correct status from process ' . $_->pid });

};

subtest subreaper_bash => sub {
  my $fired;
  my $status;
  local $SIG{CHLD};

  my $sys;
  eval { $sys = Mojo::IOLoop::ReadWriteProcess::_get_prctl_syscall; };
  plan skip_all => "You do not seem to have subreaper capabilities"
    if ($@ || !defined $sys);
  my $test_script = "$FindBin::Bin/data/subreaper/master.sh";
  plan skip_all =>
    "You do not seem to have bash, which is required (as for now) for this test"
    unless -e '/bin/bash';
  plan skip_all =>
"You do not seem to have $test_script. The script is required to run the test"
    unless -e $test_script;

  my $master_p = process(
    sub {
      exec($test_script);
    });

  $master_p->detect_subprocess(1);
  $master_p->subreaper(1);
  $master_p->on(new_subprocess => sub { $fired++ });
  $master_p->on(collect_status => sub { $status++ });
  $master_p->on(stop           => sub { shift()->disable_subreaper });
  $master_p->start();
  is $master_p->subreaper, 1,
    'We are subreaper';    # Goes to 0 if attempt was unsuccessful

  sleep 1
    for (0 .. 15)
    ;    # If we just sleep and then exit, we won't be able to catch signals

  $master_p->stop();
  is $status, 8, 'collect_status fired 8 times';
  is $fired,  7, 'new_subprocess fired 7 times';

  is $master_p->subprocess->size, 7, 'detection works'
    or die diag explain $master_p;
};


subtest subreaper_bash_execute => sub {
  my $fired;
  my $status;
  local $SIG{CHLD};

  my $sys;
  eval { $sys = Mojo::IOLoop::ReadWriteProcess::_get_prctl_syscall; };
  plan skip_all => "You do not seem to have subreaper capabilities"
    if ($@ || !defined $sys);
  my $test_script = "$FindBin::Bin/data/subreaper/master.sh";
  plan skip_all =>
    "You do not seem to have bash, which is required (as for now) for this test"
    unless -e '/bin/bash';
  plan skip_all =>
"You do not seem to have $test_script. The script is required to run the test"
    unless -e $test_script;


  my $master_p
    = process(execute => $test_script, detect_subprocess => 1, subreaper => 1);

  $master_p->on(new_subprocess => sub { $fired++ });
  $master_p->on(collect_status => sub { $status++ });
  $master_p->on(stop           => sub { shift()->disable_subreaper });
  $master_p->start();
  is $master_p->subreaper, 1, 'We are subreaper';

  sleep 1
    for (0 .. 15)
    ;    # If we just sleep and then exit, we won't be able to catch signals

  $master_p->stop();
  is $status, 8, 'collect_status fired 8 times';
  is $fired,  7, 'new_subprocess fired 7 times';

  is $master_p->subprocess->size, 7, 'detection works'
    or die diag explain $master_p;
};


subtest manager => sub {
  my $fired;
  my $status;
  local $SIG{CHLD};

  my $sys;
  eval { $sys = Mojo::IOLoop::ReadWriteProcess::_get_prctl_syscall; };
  plan skip_all => "You do not seem to have subreaper capabilities"
    if ($@ || !defined $sys);

  my $master_p = process(
    sub {
      my $p = shift;
      $p->enable_subreaper;

      process(sub { sleep 4; exit 1 })->start();
      process(
        sub {
          sleep 4;
          process(sub { sleep 1; })->start();
        })->start();
      process(sub { sleep 4; exit 0 })->start();
      process(sub { sleep 4; die })->start();
      my $manager
        = process(sub { sleep 2 })->detect_subprocess(1)->subreaper(1)->start();
      sleep 1 for (0 .. 10);
      $manager->stop;
      return $manager->subprocess->size;
    });

  $master_p->detect_subprocess(1);
  $master_p->subreaper(1);
  $master_p->on(collect_status => sub { $status++ });

  # On start we setup the current process as subreaper
  # So it's up on us to disable it after process is done.
  $master_p->on(stop => sub { shift()->disable_subreaper });
  $master_p->start();

  sleep 1
    for (0 .. 10)
    ;    # If we just sleep and then exit, we won't be able to catch signals

  $master_p->stop();
  is $status, 1, 'collect_status fired 1 times';

  is $master_p->subprocess->size, 0, 'detection works'
    or die diag explain $master_p;


  is $master_p->return_status, 5,
'detection works, 5 processes in total finished or died under manager process'
    or die diag explain $master_p;
};


subtest subreaper_bash_roulette => sub {
  my $fired;
  my $status;
  local $SIG{CHLD};

  my $sys;
  eval { $sys = Mojo::IOLoop::ReadWriteProcess::_get_prctl_syscall; };
  plan skip_all => "You do not seem to have subreaper capabilities"
    if ($@ || !defined $sys);
  my $test_script = "$FindBin::Bin/data/subreaper/roulette.sh";
  plan skip_all =>
    "You do not seem to have bash, which is required (as for now) for this test"
    unless -e '/bin/bash';
  plan skip_all =>
"You do not seem to have $test_script. The script is required to run the test"
    unless -e $test_script;

# In this tests the bash scripts are going to create child processes and then die immediately

  my $master_p = process(execute => $test_script);

  $master_p->detect_subprocess(1);
  $master_p->subreaper(1);
  $master_p->on(new_subprocess => sub { $fired++ });
  $master_p->on(collect_status => sub { $status++ });
  $master_p->on(stop           => sub { shift()->disable_subreaper });
  $master_p->start();
  is $master_p->subreaper, 1,
    'We are subreaper';    # Goes to 0 if attempt was unsuccessful

  # If we just sleep and then exit, we won't be able to catch signals

  sleep 1 for (0 .. 20);

  $master_p->stop();
  is $status, 9, 'collect_status fired 8 times';
  is $fired,  8, 'new_subprocess fired 7 times';

  is $master_p->subprocess->size, 8, 'detection works'
    or die diag explain $master_p;
  is $master_p->exit_status, '1', 'Correct master process exit status';
};


done_testing();
