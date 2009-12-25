package Solution::Variable;
{
    use strict;
    use warnings;
    use lib '../../lib';
    use Solution::Error;
    our @ISA = qw[Solution::Document];

    #
    sub variable { return $_[0]->{'variable'} }

    sub new {
        my ($class, $args) = @_;
        raise Solution::ContextError {message => 'Missing template argument',
                                      fatal   => 1
            }
            if !defined $args->{'template'}
                || !$args->{'template'}->isa('Solution::Template');
        raise Solution::ContextError {message => 'Missing parent argument',
                                      fatal   => 1
            }
            if !defined $args->{'parent'};
        raise Solution::SyntaxError {
                   message => 'Missing variable name in ' . $args->{'markup'},
                   fatal   => 1
            }
            if !defined $args->{'variable'};
        return bless $args, $class;
    }

    sub render {
        my ($self) = @_;
        my $value = $self->template->context->resolve($self->variable);

        # XXX - Duplicated in Solution::Tag::Assign
    FILTER: for my $filter (@{$self->{'filters'}}) {
            my ($name, $args) = @$filter;
            map {
                $_
                    = m[^(['"])(.+)\1\s*$]
                    ? $2
                    : $self->template->context->resolve($_)
            } @$args;
        PACKAGE: for my $package (@{$self->template->filters}) {
                if (my $call = $package->can($name)) {
                    $value = $call->($value, @$args);
                    next FILTER;
                }
                else {
                    raise Solution::FilterNotFound $name;
                }
            }
        }
        return join '', @$value      if ref $value eq 'ARRAY';
        return join '', keys %$value if ref $value eq 'HASH';
        return $value;
    }
}
1;
