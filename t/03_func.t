#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use POSIX;
use FindBin;
use Mojo::File qw(tempfile path);
use lib ("$FindBin::Bin/lib", "../lib", "lib");
use Mojo::IOLoop::ReadWriteProcess qw(process);

subtest _new_err => sub {
  my $p = process();
  $p->_new_err("Test");
  is $p->error->last->to_string, "Test";
  $p->_new_err("Test", "Test");
  ok !$p->error->last->to_string;
};

done_testing;
