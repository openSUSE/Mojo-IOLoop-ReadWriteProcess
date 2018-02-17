#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use POSIX;
use FindBin;
use Mojo::File qw(tempfile path);
use lib ("$FindBin::Bin/lib", "../lib", "lib");

use Mojo::IOLoop::ReadWriteProcess qw(process);
use Mojo::IOLoop::ReadWriteProcess::Test::Utils qw(attempt);
use Mojo::IOLoop;

use Mojo::IOLoop::ReadWriteProcess::Session qw(session);

subtest register => sub {
  my $s = Mojo::IOLoop::ReadWriteProcess::Session->singleton;
  my $p = process(sub { });
  $s->register(1 => $p);

  is_deeply ${$s->process_table()->{1}}, $p, 'Equal' or die diag explain $s;

  ${$s->process_table()->{1}}->{foo} = 'bar';

  is $p->{foo}, 'bar';

  session->resolve(1)->{foo} = 'kaboom';

  is $p->{foo}, 'kaboom';
};

done_testing();
