#!/usr/bin/perl
use FindBin;
use lib ("$FindBin::Bin/../../lib");
use Mojo::IOLoop::ReadWriteProcess 'process';

exit process(execute => '/usr/bin/true')->start()->wait_stop()->exit_status();
