package Solution::Block;
{
    use strict;
    use warnings;
    our $VERSION = 0.001;
    use lib '../../lib';
    use Solution::Error;
    our @ISA = qw[Solution::Document];

    sub new {
        my ($class, $args) = @_;
        raise Solution::ContextError {message => 'Missing template argument',
                                      fatal   => 1
            }
            if !defined $args->{'template'};
        raise Solution::ContextError {message => 'Missing parent argument',
                                      fatal   => 1
            }
            if !defined $args->{'parent'};
        raise Solution::SyntaxError {
             message => 'else tags are non-conditional: ' . $args->{'markup'},
             fatal   => 1
            }
            if $args->{'tag_name'} eq 'else' && $args->{'attrs'};
        my $self = bless {tag_name   => $args->{'tag_name'},
                          conditions => undef,
                          nodelist   => [],
                          template   => $args->{'template'},
                          parent     => $args->{'parent'},
        }, $class;
        $self->{'conditions'} = (
            $args->{'tag_name'} eq 'else'
            ? [1]
            : sub {    # Oh, what a mess...
                my @conditions = split m[\s+\b(and|or)\b\s+],
                    $args->{'attrs'};
                my @equality;
                while (my $x = shift @conditions) {
                    push @equality,
                        ($x =~ m[\b(?:and|or)\b]
                         ? bless({template  => $args->{'template'},
                                  parent    => $self,
                                  condition => $x,
                                  lvalue    => pop @equality,
                                  rvalue =>
                                      Solution::Condition->new(
                                          {template => $args->{'template'},
                                           parent   => $self,
                                           attrs    => shift @conditions
                                          }
                                      )
                                 },
                                 'Solution::Condition'
                             )
                         : Solution::Condition->new(
                                          {attrs    => $x,
                                           template => $args->{'template'},
                                           parent   => $self,
                                          }
                         )
                        );
                }
                \@equality;
                }
                ->()
        );
        return $self;
    }
}
1;
