#!raku

use v6.c;

use Test;

my Bool $got-test-meta = True;

my &m-meta-ok;

BEGIN {
    require Test::META <&meta-ok>;
    $got-test-meta = True;

    &m-meta-ok = &meta-ok;

    CATCH {
        when X::CompUnit::UnsatisfiedDependency {
            plan 1;
            skip-rest "no Test::META - skipping";
            done-testing;
            exit;
        }
    }

}

plan 1;

if $got-test-meta {
    m-meta-ok();
}
else {
    skip "no Test::META skipping";
}


done-testing;
# vim: expandtab shiftwidth=4 ft=raku
