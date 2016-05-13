package Cache::TwoQ;
use strict;
use warnings;

use constant {
    'NAME'  => 0,
    'PREV'  => 1,
    'NEXT'  => 2,

    'KEY'   => 3,
    'VAL'   => 4,
    'EXP'   => 5,
};

sub new {
    my ($class, $size) = @_;
    die('gimme size (>= 10) as a single argument') if (
        !$size || $size !~ /^\d+$/ || $size < 10
    );
    my $fifo_size = int(0.1 * $size);
    my $self = {};
    $self->{'size'} = $size;
    $self->{'fifo'} = Cache::TwoQ::CircularBuffer->new($fifo_size, 'fifo');
    $self->{'lru'} = Cache::TwoQ::CircularBuffer->new($size - $fifo_size, 'lru');
    $self->{'fifo_empty'} = $self->{'fifo'}{'head'};
    $self->{'lru_empty'} = $self->{'lru'}{'head'};
    $self->{'hash_map'} = {};
    return bless($self, $class);
}

sub set {
    my ($self, $key, $val, $exp) = @_;
    die('gimme at least key as the first argument') unless (
        defined($key)
    );
    # TODO check arguments

    my $node;
    $exp = time() + $exp if ($exp);
    if ($node = $self->{'hash_map'}{$key}) {
        $node->[VAL] = $val;
        $node->[EXP] = $exp;
    }
    elsif ($node = $self->{'fifo_empty'}) {
        $node->[KEY] = $key;
        $node->[VAL] = $val;
        $node->[EXP] = $exp;
        $self->{'hash_map'}{$key} = $node;
        if ($node->[PREV] == $self->{'fifo'}{'head'}) {
            $self->{'fifo_empty'} = undef;
        }
        else {
            $self->{'fifo_empty'} = $node->[PREV];
        }
    }
    else {
        $node = $self->{'fifo'}{'head'}[NEXT];
        delete($self->{'hash_map'}{$node->[KEY]});
        $node->[KEY] = $key;
        $node->[VAL] = $val;
        $node->[EXP] = $exp;
        $self->{'hash_map'}{$key} = $node;
    }
    $self->{$node->[NAME]}->set_head($node);
}

sub get {
    my ($self, $key) = @_;
    die('gimme key as a single argument') unless (
        defined($key)
    );
    # TODO check arguments

    my $node = $self->{'hash_map'}{$key};

    # no such key
    return undef unless ($node);

    # key is expired
    if ($node->[EXP] && $node->[EXP] < time()) {
        delete($self->{'hash_map'}{$key});
        $node->[KEY] = undef;
        $node->[VAL] = undef;
        $node->[EXP] = undef;
        $self->{$node->[NAME].'_empty'} = $node unless (
            $self->{$node->[NAME].'_empty'}
        );
        $self->{$node->[NAME]}->set_tail($node);
        return undef;
    }

    # key is in lru
    if ($node->[NAME] eq 'lru') {
        $self->{'lru'}->set_head($node);
        return $node->[VAL];
    }

    # key is in fifo and lru has an empty node
    if (my $lnode = $self->{'lru_empty'}) {
        $self->{'hash_map'}{$key} = $lnode;
        $lnode->[KEY] = $key;
        $lnode->[VAL] = $node->[VAL];
        $lnode->[EXP] = $node->[EXP];
        $node->[KEY] = undef;
        $node->[VAL] = undef;
        $node->[EXP] = undef;
        $self->{'fifo_empty'} = $node unless (
            $self->{'fifo_empty'}
        );
        $self->{'fifo'}->set_tail($node);
        if ($lnode->[PREV] == $self->{'lru'}{'head'}) {
            $self->{'lru_empty'} = undef;
        }
        else {
            $self->{'lru_empty'} = $lnode->[PREV];
        }
        $self->{'lru'}->set_head($lnode);
        return $lnode->[VAL];
    }

    # key is in fifo and lru is full
    my $lnode = $self->{'lru'}{'head'}[NEXT];
    $self->{'hash_map'}{$key} = $lnode;
    my $lkey = $lnode->[KEY];
    my $lval = $lnode->[VAL];
    my $lexp = $lnode->[EXP];
    $lnode->[KEY] = $key;
    $lnode->[VAL] = $node->[VAL];
    $lnode->[EXP] = $node->[EXP];
    $self->{'lru'}->set_head($lnode);
    if ($lexp && $lexp < time()) {
        delete($self->{'hash_map'}{$lkey});
        $node->[KEY] = undef;
        $node->[VAL] = undef;
        $node->[EXP] = undef;
        $self->{'fifo_empty'} = $node unless (
            $self->{'fifo_empty'}
        );
        $self->{'fifo'}->set_tail($node);
    }
    else {
        $self->{'hash_map'}{$lkey} = $node;
        $node->[KEY] = $lkey;
        $node->[VAL] = $lval;
        $node->[EXP] = $lexp;
        $self->{'fifo'}->set_head($node);
    }
    return $lnode->[VAL];
}

package Cache::TwoQ::CircularBuffer;
use strict;
use warnings;

use constant {
    'NAME' => 0,
    'PREV' => 1,
    'NEXT' => 2,
};

sub new {
    my ($class, $size, $name) = @_;
    die('gimme size as a single argument') if (
        !$size || $size !~ /^\d+$/
    );

    my $head = [$name, (undef) x 5];
    my $prev_node = $head;
    for (2 .. $size) {
        my $node = [$name, (undef) x 5];
        $node->[PREV] = $prev_node;
        $prev_node->[NEXT] = $node;
        $prev_node = $node;
    }
    $head->[PREV] = $prev_node;
    $prev_node->[NEXT] = $head;

    return bless({
        'size'  => $size,
        'head'  => $head,
        'name'  => $name,    
    }, $class);
}

sub set_head {
    my ($self, $node) = @_;
    # TODO check arguments
    return if ($node == $self->{'head'});
    if ($node->[PREV] == $self->{'head'}) {
        $self->{'head'} = $node;
    }
    else {
        $node->[PREV][NEXT] = $node->[NEXT];
        $node->[NEXT][PREV] = $node->[PREV];
        $node->[NEXT] = $self->{'head'}[NEXT];
        $node->[PREV] = $self->{'head'};
        $self->{'head'}[NEXT][PREV] = $node;
        $self->{'head'}[NEXT] = $node;
        $self->{'head'} = $node;
    }
}

sub set_tail {
    my ($self, $node) = @_;
    # TODO check arguments
    return if ($node == $self->{'head'}[NEXT]);
    if ($node == $self->{'head'}) {
        $self->{'head'} = $node->[PREV];
    }
    else {
        $node->[PREV][NEXT] = $node->[NEXT];
        $node->[NEXT][PREV] = $node->[PREV];
        $node->[NEXT] = $self->{'head'}[NEXT];
        $node->[PREV] = $self->{'head'};
        $self->{'head'}[NEXT][PREV] = $node;
        $self->{'head'}[NEXT] = $node;
    }
}

1;
