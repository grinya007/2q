#!/usr/bin/env perl
use strict;
use warnings;

use lib 'lib';

use Cache::TwoQ;

my $b = Cache::TwoQ::CircularBuffer->new(7);
my $n = $b->{'head'};
for (1..7) {
    $n->[3] = $_;
    $n = $n->[1];
}

print_b();

my $sn = $b->{'head'}[1];
$b->set_head($sn);

print_b();

$sn = $b->{'head'}[1][1][1];
$b->set_head($sn);

print_b();

$sn = $b->{'head'}[2];
$b->set_head($sn);

print_b();

$sn = $b->{'head'}[2][1];
$b->set_head($sn);

print_b();

$sn = $b->{'head'}[1][1];
$b->set_tail($sn);

print_b();

$sn = $b->{'head'}[2];
$b->set_tail($sn);

print_b();

$sn = $b->{'head'};
$b->set_tail($sn);

print_b();

sub print_b {
    print "$$b{head}[3]\t\t";
    my $n = $b->{'head'};
    while (1) {
        print "$$n[3]\t";
        $n = $n->[1];
        last if $n == $b->{'head'};
    }
    print "\n";
}
