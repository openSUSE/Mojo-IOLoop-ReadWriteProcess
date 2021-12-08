requires 'Mojolicious', '7.24';
requires 'IPC::SharedMem';

on configure => sub {
    requires 'Module::Build';
    requires 'perl', '5.016';
};

on test => sub {
    requires 'Test::More', '0.98';
};
on develop => sub {
    requires 'Devel::Cover::Report::Codecovbash';
    requires 'Devel::Cover';
    requires 'Test::Pod::Coverage';
    requires 'Test::Pod';
}
