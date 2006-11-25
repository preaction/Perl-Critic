#######################################################################
#      $URL$
#     $Date$
#   $Author$
# $Revision$
########################################################################

package Perl::Critic::Policy::Variables::ProhibitPackageVars;

use strict;
use warnings;
use Perl::Critic::Utils;
use List::MoreUtils qw(all any);
use base 'Perl::Critic::Policy';

our $VERSION = 0.22;

#---------------------------------------------------------------------------

my $desc = q{Package variable declared or used};
my $expl = [ 73, 75 ];

#---------------------------------------------------------------------------

sub default_severity { return $SEVERITY_MEDIUM    }
sub default_themes   { return qw(pbp unreliable) }
sub applies_to       { return qw(PPI::Token::Symbol
                                 PPI::Statement::Variable
                                 PPI::Statement::Include) }

our @DEFAULT_PACKAGE_EXCEPTIONS = qw(
    File::Find
    Data::Dumper
);

#---------------------------------------------------------------------------

sub new {
    my $class = shift;
    my %config = @_;

    my $self = bless {}, $class;

    # Set list of package exceptions from configuration, if defined.
    $self->{_packages} =
        defined $config{packages}
            ? [ split m{ \s+ }mx, $config{packages} ]
            : [ @DEFAULT_PACKAGE_EXCEPTIONS ];

    # Add to list of packages
    if ( defined $config{add_packages} ) {
        push( @{$self->{_packages}}, split m{ \s+ }mx, $config{add_packages} );
    }

    return $self;
}

sub violates {
    my ( $self, $elem, undef ) = @_;

    return unless _is_package_var($elem) || _is_our_var($elem) || _is_vars_pragma($elem);

    if ( $elem =~ m{ \A [@\$%] (.*) :: }mx ) { # REVIEW: This is redundant to a check in _is_package_var
        my $package = $1;
        return if any { $package eq $_ } @{$self->{_packages}};
    }

    return $self->violation( $desc, $expl, $elem );
}

sub _is_package_var {
    my $elem = shift;
    $elem->isa('PPI::Token::Symbol') || return;
    return $elem =~ m{ \A [@\$%] .* :: }mx && $elem !~ m{ :: [A-Z0-9_]+ \z }mx;
}

sub _is_our_var {
    my $elem = shift;
    $elem->isa('PPI::Statement::Variable') || return;
    return $elem->type() eq 'our' && !_all_upcase( $elem->variables() );
}

sub _is_vars_pragma {
    my $elem = shift;
    $elem->isa('PPI::Statement::Include') || return;
    $elem->pragma() eq 'vars' || return;

    # Older Perls don't support the C<our> keyword, so we try to let
    # people use the C<vars> pragma instead, but only if all the
    # variable names are uppercase.  Since there are lots of ways to
    # pass arguments to pragmas (e.g. "$foo" or qw($foo) ) we just use
    # a regex to match things that look like variables names.

    if ($elem =~ m{ [@\$%&] ( [\w+] ) }mx) {
        my $varname = $1;
        return 1 if $varname =~ m{ [a-z] }mx;
    }
    return;
}

sub _all_upcase {
    return all { $_ eq uc $_ } @_;
}

1;

__END__

#---------------------------------------------------------------------------

=pod

=head1 NAME

Perl::Critic::Policy::Variables::ProhibitPackageVars

=head1 DESCRIPTION

Conway suggests avoiding package variables completely, because they
expose your internals to other packages.  Never use a package variable
when a lexical variable will suffice.  If your package needs to keep
some dynamic state, consider using an object or closures to keep the
state private.

This policy assumes that you're using C<strict vars> so that naked
variable declarations are not package variables by default.  Thus, it
complains you declare a variable with C<our> or C<use vars>, or if you
make reference to variable with a fully-qualified package name.

  $Some::Package::foo = 1;    #not ok
  our $foo            = 1;    #not ok
  use vars '$foo';            #not ok
  $foo = 1;                   #not allowed by 'strict'
  local $foo = 1;             #bad taste, but technically ok.
  use vars '$FOO';            #ok, because it's ALL CAPS
  my $foo = 1;                #ok

In practice though, its not really practical to prohibit all package
variables.  Common variables like C<$VERSION> and C<@EXPORT> need to
be global, as do any variables that you want to Export.  To work
around this, the Policy overlooks any variables that are in ALL_CAPS.
This forces you to put all your exported variables in ALL_CAPS too, which
seems to be the usual practice anyway.

There is room for exceptions.  Some modules, like the core File::Find
module, use package variables as their only interface, and others
like Data::Dumper use package variables as their most common
interface.  These module can be specified from your F<.perlcriticrc>
file, and the policy will ignore them.

    [Variables::ProhibitPackageVars]
    packages = File::Find Data::Dumper

This is the default setting.  Using C<packages =>  will override
these defaults.

You can also add packages to the defaults like so:

    [Variables::ProhibitPackageVars]
    add_packages = My::Package

You can add package C<main> to the list of packages, but that will
only OK variables explicitly in the C<main> package.

=head1 SEE ALSO

L<Perl::Critic::Policy::Variables::ProhibitPunctuationVars>

L<Perl::Critic::Policy::Variables::ProhibitLocalVars>

=head1 AUTHOR

Jeffrey Ryan Thalhammer <thaljef@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2005-2006 Jeffrey Ryan Thalhammer.  All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  The full text of this license
can be found in the LICENSE file included with this module.

=cut

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 78
#   indent-tabs-mode: nil
#   c-indentation-style: bsd
# End:
# ex: set ts=8 sts=4 sw=4 tw=78 expandtab :
