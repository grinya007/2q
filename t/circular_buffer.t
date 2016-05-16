#!/usr/bin/env perl
use strict;
use warnings;

use Test::More 'tests' => 12;

use FindBin qw/$RealBin/;
use lib $RealBin.'/../lib';

BEGIN { use_ok('Cache::TwoQ') }

use constant {
    'PREV' => Cache::TwoQ::PREV(),
    'NEXT' => Cache::TwoQ::NEXT(),
    'KEY'  => Cache::TwoQ::KEY(),
};

my $cb = Cache::TwoQ::CircularBuffer->new(7);

ok(ref($cb->{'head'}) eq 'ARRAY', 'circular buffer head is ok');
cmp_ok($cb->{'head'}, '==', $cb->{'head'}[PREV][NEXT], 'head->prev->next points to head');
cmp_ok($cb->{'head'}, '==', $cb->{'head'}[NEXT][PREV], 'head->next->prev points to head');

# putting something useful to node key
my $node = $cb->{'head'};
for (1..7) {
    $node->[KEY] = $_*10;
    $node = $node->[PREV];
}

sub serialize_cb {
    my ($cb) = @_;
    my $res = 'head: '.$cb->{'head'}[KEY].';';
    my $node = $cb->{'head'};
    for my $i (1 .. $cb->{'size'}) {
        $res .= ' '.$i.': '.$node->[KEY].';';
        $node = $node->[PREV];
    }
    return $res;
}

cmp_ok(
    serialize_cb($cb), 'eq',
    'head: 10; 1: 10; 2: 20; 3: 30; 4: 40; 5: 50; 6: 60; 7: 70;',
    'initial state is ok'
);

# NOTE every test case is modification of the previous state of buffer
# moving second node to head
$node = $cb->{'head'}[PREV];
$cb->set_head($node);
cmp_ok(
    serialize_cb($cb), 'eq',
    'head: 20; 1: 20; 2: 10; 3: 30; 4: 40; 5: 50; 6: 60; 7: 70;',
    'n2 => head: head pointer is ok, order is ok'
);

# moving fourth node to head
$node = $cb->{'head'}[PREV][PREV][PREV];
$cb->set_head($node);
cmp_ok(
    serialize_cb($cb), 'eq',
    'head: 40; 1: 40; 2: 20; 3: 10; 4: 30; 5: 50; 6: 60; 7: 70;',
    'n4 => head: head pointer is ok, order is ok'
);

# moving tail to head (internally it should just switch head pointer)
$node = $cb->{'head'}[NEXT];
$cb->set_head($node);
cmp_ok(
    serialize_cb($cb), 'eq',
    'head: 70; 1: 70; 2: 40; 3: 20; 4: 10; 5: 30; 6: 50; 7: 60;',
    'tail => head: head pointer is ok, order is ok'
);

# moving head to head (order 0 beers)
$node = $cb->{'head'};
$cb->set_head($node);
cmp_ok(
    serialize_cb($cb), 'eq',
    'head: 70; 1: 70; 2: 40; 3: 20; 4: 10; 5: 30; 6: 50; 7: 60;',
    'head => head: head pointer is ok, order is ok'
);

# moving head to tail
$node = $cb->{'head'};
$cb->set_tail($node);
cmp_ok(
    serialize_cb($cb), 'eq',
    'head: 40; 1: 40; 2: 20; 3: 10; 4: 30; 5: 50; 6: 60; 7: 70;',
    'head => tail: head pointer is ok, order is ok'
);

# moving third node to tail
$node = $cb->{'head'}[PREV][PREV];
$cb->set_tail($node);
cmp_ok(
    serialize_cb($cb), 'eq',
    'head: 40; 1: 40; 2: 20; 3: 30; 4: 50; 5: 60; 6: 70; 7: 10;',
    'n3 => tail: head pointer is ok, order is ok'
);

# moving tail to tail (order &*$^#@|% beers)
$node = $cb->{'head'}[NEXT];
$cb->set_tail($node);
cmp_ok(
    serialize_cb($cb), 'eq',
    'head: 40; 1: 40; 2: 20; 3: 30; 4: 50; 5: 60; 6: 70; 7: 10;',
    'tail => tail: head pointer is ok, order is ok'
);

