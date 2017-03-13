package Splitter;

sub new {
    my ($class, $debug) = @_;
    my $this = {
        # 'delimiters' => $delimiters,
        'debug' => $debug
    };
    bless($this, $class);
    return $this;
}

sub split {
}

1;
