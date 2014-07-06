class Net::AMQP::Payload::Method;

my %standard = (
    connection =>
        { id => 10,
          methods =>
              { start     => { id => 10, signature => ('octet', 'octet', 'table', 'longstring', 'longstring') },
                start-ok  => { id => 11, signature => ('table', 'shortstring', 'longstring', 'shortstring') },
                secure    => { id => 20, signature => ('longstring') },
                secure-ok => { id => 21, signature => ('longstring') },
                tune      => { id => 30, signature => ('short', 'long', 'short') },
                tune-ok   => { id => 31, signature => ('short', 'long', 'short') },
                open      => { id => 40, signature => ('path', 'shortstring', 'bit') },
                open-ok   => { id => 41, signature => ('shortstring') },
                close     => { id => 50, signature => ('short', 'shortstring', 'short', 'short') },
                close-ok  => { id => 51, signature => () } } },
    channel =>
        { id => 20,
          methods =>
              { open     => { id => 10, signature => ('shortstring') },
                open-ok  => { id => 11, signature => ('longstring') },
                flow     => { id => 20, signature => ('bit') },
                flow-ok  => { id => 21, signature => ('bit') },
                close    => { id => 40, signature => ('short', 'shortstring', 'short', 'short') },
                close-ok => { id => 41, signature => () } } },
    exchange =>
        { id => 40,
          methods =>
              { declare    => { id => 10, signature => ('short', 'shortstring', 'shortstring', 'bit', 'bit', 'bit', 'bit', 'bit', 'table') },
                declare-ok => { id => 11, signature => () },
                delete     => { id => 20, signature => ('short', 'shortstring', 'bit', 'bit') },
                delete-ok  => { id => 21, signature => () } } },
    queue =>
        { id => 50,
          methods =>
              { declare    => { id => 10, signature => ('short', 'shortstring', 'bit', 'bit', 'bit', 'bit', 'bit', 'table') },
                declare-ok => { id => 11, signature => ('shortstring', 'long', 'long') },
                bind       => { id => 20, signature => ('short', 'shortstring', 'shortstring', 'shortstring', 'bit', 'table') },
                bind-ok    => { id => 21, signature => () },
                unbind     => { id => 50, signature => ('short', 'shortstring', 'shortstring', 'shortstring', 'table') },
                unbind-ok  => { id => 51, signature => () },
                purge      => { id => 30, signature => ('short', 'shortstring', 'bit') },
                purge-ok   => { id => 31, signature => ('long') },
                delete     => { id => 40, signature => ('short', 'shortstring', 'bit', 'bit', 'bit') },
                delete-ok  => { id => 41, signature => ('long') },
              } },
    basic =>
        { id => 60,
          methods =>
              { qos           => { id => 10, signature => ('long', 'short', 'bit') },
                qos-ok        => { id => 11, signature => () },
                consume       => { id => 20, signature => ('short', 'shortstring', 'shortstring', 'bit', 'bit', 'bit', 'bit', 'table') },
                consume-ok    => { id => 21, signature => ('shortstring') },
                cancel        => { id => 30, signature => ('shortstring', 'bit') },
                cancel-ok     => { id => 31, signature => ('shortstring') },
                publish       => { id => 40, signature => ('short', 'shortstring', 'shortstring', 'bit', 'bit') },
                return        => { id => 50, signature => ('short', 'shortstring', 'shortstring', 'shortstring') },
                deliver       => { id => 60, signature => ('shortstring', 'longlong', 'bit', 'shortstring', 'shortstring') },
                get           => { id => 70, signature => ('short', 'shortstring', 'bit') },
                get-ok        => { id => 71, signature => ('longlong', 'bit', 'shortstring', 'shortstring', 'long') },
                get-empty     => { id => 72, signature => ('shortstring') },
                ack           => { id => 80, signature => ('longlong', 'bit') },
                reject        => { id => 90, signature => ('longlong', 'bit') },
                recover-async => { id => 100, signature => ('bit') },
                recover       => { id => 110, signature => ('bit') },
                recover-ok    => { id => 111, signature => () },
              } },
    tx =>
        { id => 90,
          methods =>
              { select      => { id => 10, signature => () },
                select-ok   => { id => 11, signature => () },
                commit      => { id => 20, signature => () },
                commit-ok   => { id => 21, signature => () },
                rollback    => { id => 30, signature => () },
                rollback-ok => { id => 31, signature => () },
              } },
);

has $.class-id;
has $.method-id;
has @.arguments;
has @.signature;
has $.method-name;

method !serialize-arg($type, $value, $buf? is copy, $bitsused?) {
    given $type {
        when 'bit' {
            if $bitsused == 0 {
                if $value {
                    $buf = buf8.new(1);
                } else {
                    $buf = buf8.new(0);
                }
            } else {
                if $value {
                    $buf[0] = $buf[0] +| (1 +< $bitsused);
                }
            }
        }
        when 'octet' {
            $buf = pack('C', $value);
        }
        when 'short' {
            $buf = pack('n', $value);
        }
        when 'long' {
            $buf = pack('N', $value);
        }
        when 'longlong' {
            $buf = pack('N', $value +> 32);
            $buf = pack('N', $value +& 0xFFFF);
        }
        when 'shortstring' {
            if $value.chars > 255 {
                die;
            }
            $buf = pack('C', $value.chars);
            $buf = $value.encode;
        }
        when 'longstring' {
            if $value.chars > (2**32 - 1) {
                die;
            }
            $buf = pack('N', $value.chars);
            $buf = $value.encode;
        }
        when 'table' {
            die;
        }
    }
}

method Buf {
    my $args = buf8.new();
    my $bitsused = 0;
    my $lastarg;
    for @.signature X @.arguments -> $arg, $value {
        if $arg ne 'bit' {
            $bitsused = 0;
        }
        if $lastarg eq 'bit' && $bitsused {
            $args[*-1] = self!serialize-arg($arg, $value, $args[*-1], $bitsused);
        } else {
            $args ~= self!serialize-arg($arg, $value);
        }
        $bitsused++;
        if $bitsused >= 8 {
            $bitsused = 0;
        }
    }
    return pack('nn', ($.class-id, $.method-id)) ~ $args;
}

method !deserialize-arg($type, $data, $bitcount = 0) {
    given $type {
        when 'boolean' {
            return ?$data.unpack('C'), 1;
        }
        when 'bit' {
            return (($data.unpack('C') +> $bitcount) +& 1, 1);
        }
        when 'octeti' {
            die;
        }
        when 'octet' {
            return ($data.unpack('C'), 1);
        }
        when 'shorti' {
            die;
        }
        when 'short' {
            return ($data.unpack('n'), 2);
        }
        when 'longi' {
            die;
        }
        when 'long' {
            return ($data.unpack('N'), 4);
        }
        when 'longlongi' {
            die;
        }
        when 'longlong' {
            return (($data.unpack('N') +< 32) +| $data.subbuf(4).unpack('N'), 8);
        }
        when 'float' {
            die;
        }
        when 'double' {
            die;
        }
        when 'decimal' {
            die;
        }
        when 'shortstring' {
            my $len = $data.unpack('C');
            return $data.subbuf(1, $len).decode, $len + 1;
        }
        when 'longstring' {
            my $len = $data.unpack('N');
            return $data.subbuf(4, $len).decode, $len + 4;
        }
        when 'timestamp' {
            return (($data.unpack('N') +< 32) +| $data.subbuf(4).unpack('N'), 8);
        }
        when 'array' {
            die;
        }
        when 'table' {
            my %result;
            my $len = $data.unpack('N');
            my $tablebuf = $data.subbuf(4, $len);
            while $tablebuf.bytes {
                my $namelen = $tablebuf.unpack('C');
                my $name = $tablebuf.subbuf(1, $namelen).decode;

                my $type = $tablebuf.subbuf(1+$namelen, 1).decode;
                $tablebuf .= subbuf(2+$namelen);
                my $value;
                my $size;
                given $type {
                    when 't' {
                        ($value, $size) = self!deserialize-arg('boolean', $tablebuf);
                    }
                    when 'b' {
                        ($value, $size) = self!deserialize-arg('octeti', $tablebuf);
                    }
                    when 'B' {
                        ($value, $size) = self!deserialize-arg('octet', $tablebuf);
                    }
                    when 'U' {
                        ($value, $size) = self!deserialize-arg('shorti', $tablebuf);
                    }
                    when 'u' {
                        ($value, $size) = self!deserialize-arg('short', $tablebuf);
                    }
                    when 'I' {
                        ($value, $size) = self!deserialize-arg('longi', $tablebuf);
                    }
                    when 'i' {
                        ($value, $size) = self!deserialize-arg('long', $tablebuf);
                    }
                    when 'L' {
                        ($value, $size) = self!deserialize-arg('longlongi', $tablebuf);
                    }
                    when 'l' {
                        ($value, $size) = self!deserialize-arg('longlong', $tablebuf);
                    }
                    when 'f' {
                        ($value, $size) = self!deserialize-arg('float', $tablebuf);
                    }
                    when 'd' {
                        ($value, $size) = self!deserialize-arg('double', $tablebuf);
                    }
                    when 'D' {
                        ($value, $size) = self!deserialize-arg('decimal', $tablebuf);
                    }
                    when 's' {
                        ($value, $size) = self!deserialize-arg('shortstring', $tablebuf);
                    }
                    when 'S' {
                        ($value, $size) = self!deserialize-arg('longstring', $tablebuf);
                    }
                    when 'A' {
                        ($value, $size) = self!deserialize-arg('array', $tablebuf);
                    }
                    when 'T' {
                        ($value, $size) = self!deserialize-arg('timestamp', $tablebuf);
                    }
                    when 'F' {
                        ($value, $size) = self!deserialize-arg('table', $tablebuf);
                    }
                    when 'V' {
                        $size = 0;
                        $value = Nil;
                    }
                }
                %result{$name} = $value;
                $tablebuf .= subbuf($size);
            }
            return ($%result, $len + 4);
        }
    }
}

multi method new(Blob $data is copy) {
    my ($class-id, $method-id) = $data.unpack('nn');
    my $method-name;
    my @signature;
    my @arguments;
    for %standard.kv -> $class, %chash {
        if %chash<id> == $class-id {
            $method-name = $class ~ '.';
            for %standard{$class}<methods>.kv -> $method, %mhash {
                if %mhash<id> == $method-id {
                    $method-name ~= $method;
                    @signature = %mhash<signature>.list;
                }
            }
        }
    }
    $data .= subbuf(4);


    # get args
    my $bitbuf;
    my $bitcount = 0;
    for @signature -> $arg {
        my $value;
        my $size;
        if $arg eq 'bit' && $bitcount {
            ($value, $size) = self!deserialize-arg($arg, $bitbuf, $bitcount);
            $size = 0;
            $bitcount++;
            if $bitcount > 7 {
                $bitcount = 0;
            }
        } else {
            ($value, $size) = self!deserialize-arg($arg, $data);
            if $arg eq 'bit' {
                $bitcount++;
                $bitbuf = $data.subbuf(0, 1);
            }
        }

        say "arg($arg): "~$value.perl;

        @arguments.push($value);
        $data .= subbuf($size);
    }
    
    self.bless(:$class-id, :$method-id, :$method-name, :@signature, :@arguments);
}

multi method new(Str $method-name, *@arguments) {
    my $class-id;
    my $method-id;
    my @signature;

    my ($class, $method) = $method-name.split('.');
    $class-id = %standard{$class}<id>;
    $method-id = %standard{$class}<methods>{$method}<id>;
    @signature = %standard{$class}<methods>{$method}<signature>;
    self.bless(:$method-name, :$class-id, :$method-id, :@arguments, :@signature);
}
