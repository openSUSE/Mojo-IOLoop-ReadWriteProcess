requires 'Mojolicious';
requires 'IPC::SharedMem';

on configure => sub {
    requires 'Module::Build';
    requires 'perl', '5.016';
};

on test => sub {
    requires 'Test::More';
};
on develop => sub {
    requires 'Devel::Cover::Report::Codecovbash';
    requires 'Devel::Cover';
    requires 'Test::Pod::Coverage';
    requires 'Test::Pod';
}
