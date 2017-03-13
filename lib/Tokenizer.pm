package Tokenizer;

sub new {
    #print "Tokenizer args @_\n";
    my ($class, $dict, $debug) = @_;
    my $this = {
        'dict' => $dict,
        'debug' => $debug
    };
    #$this->{"_SID"} = 0;
    bless($this, $class);
    #print "DICT: $this->{dict}\n";
    return $this;
}

sub tokenize {
}

1;
