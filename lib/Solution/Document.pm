package Solution::Document;
{
    use strict;
    use warnings;
    use lib '../';
    our $VERSION = 0.001;
    use Solution::Variable;
    use Solution::Utility;

    #
    sub template { return $_[0]->{'template'} }

    #sub template    { return $_[0]->{'template'} }
    #sub parent  { return $_[0]->{'parent'}; }
    #sub context { return $_[0]->{'context'}; }
    #sub filters { return $_[0]->{'filters'}; }
    #sub resolve {
    #    return $_[0]->context->resolve($_[1], defined $_[2] ? $_[2] : ());
    #}
    #sub stack  { return $_[0]->context->stack($_[1]); }
    #sub scopes { return $_[0]->context->scopes; }
    #sub scope  { return $_[0]->context->scope; }
    #sub merge  { return $_[0]->context->merge($_[1]); }
    #BEGIN { our @ISA = qw[Solution::Template]; }
    sub new {
        my ($class, $args) = @_;
        raise Solution::ContextError {message => 'Missing template argument',
                                      fatal   => 1
            }
            if !defined $args->{'template'};
        return bless $args, $class;
    }

    sub parse {
        my ($class, $args, $tokens);
        (scalar @_ == 3 ? ($class, $args, $tokens) : ($class, $tokens)) = @_;
        my $self;
        if (ref $class) { $self = $class; }
        else {
            raise Solution::ContextError {
                                       message => 'Missing template argument',
                                       fatal   => 1
                }
                if !defined $args->{'template'};
            $args->{'nodelist'}
                ||= [];    # XXX - In the future, this may be preloaded?
            $self = bless $args, $class;
        }
    NODE: while (my $token = shift @{$tokens}) {
            if ($token =~ qr[^${Solution::Utility::TagStart}  # {%
                                (.+?)                         # etc
                              ${Solution::Utility::TagEnd}    # %}
                             $]x
                )
            {   my ($tag, $attrs) = (split ' ', $1, 2);

                #warn $tag;
                #use Data::Dump qw[pp];
                #warn pp $self;
                my ($package, $call) = $self->template->tags->{$tag};
                if ($package
                    && ($call = $self->template->tags->{$tag}->can('new')))
                {   push @{$self->{'nodelist'}},
                        $call->($package,
                                {template => $self->template,
                                 parent   => $self,
                                 tag_name => $tag,
                                 markup   => $token,
                                 attrs    => $attrs
                                },
                                $tokens
                        );
                }
                elsif ($self->can('end_tag') && $tag =~ $self->end_tag) {
                    last NODE;
                }
                elsif (   $self->can('conditional_tag')
                       && defined $self->conditional_tag
                       && $tag =~ $self->conditional_tag)
                {   $self->push_block({tag_name => $tag,
                                       attrs    => $attrs,
                                       markup   => $token,
                                       template => $self->template,
                                       parent   => $self
                                      },
                                      $tokens
                    );
                }
                else {
                    raise Solution::SyntaxError {
                                          message => 'Unknown tag: ' . $token,
                                          fatal   => 1
                    };
                }
            }
            elsif (
                $token =~ qr
                    [^${Solution::Utility::VariableStart}
                        (.+?)
                        ${Solution::Utility::VariableEnd}
                    $]x
                )
            {   my ($variable, $filters) = split qr[\s*\|\s*], $1, 2;
                my @filters;
                for my $filter (split $Solution::Utility::FilterSeparator,
                                $filters || '')
                {   my ($filter, $args)
                        = split $Solution::Utility::FilterArgumentSeparator,
                        $filter, 2;
                    $filter =~ s[\s*$][]; # XXX - the splitter should clean...
                    $filter =~ s[^\s*][]; # XXX -  ...this up for us.
                    my @args
                        = $args
                        ? split
                        $Solution::Utility::VariableFilterArgumentParser,
                        $args
                        : ();
                    push @filters, [$filter, \@args];
                }
                push @{$self->{'nodelist'}},
                    Solution::Variable->new({template => $self->template,
                                             parent   => $self,
                                             markup   => $token,
                                             variable => $variable,
                                             filters  => \@filters
                                            }
                    );
            }
            else {
                push @{$self->{'nodelist'}}, $token;
            }
        }
        return $self;
    }

    sub render {
        my ($self) = @_;
        my $return = '';
        for my $node (@{$self->{'nodelist'}}) {
            my $rendering = ref $node ? $node->render() : $node;
            $return .= defined $rendering ? $rendering : '';
        }
        return $return;
    }
}
1;
