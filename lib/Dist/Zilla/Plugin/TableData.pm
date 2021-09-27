package Dist::Zilla::Plugin::TableData;

use 5.014;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

use Data::Dmp;

# AUTHORITY
# DATE
# DIST
# VERSION

with (
    'Dist::Zilla::Role::FileMunger',
    'Dist::Zilla::Role::FileFinderUser' => {
        default_finders => [':InstallModules'],
    },
);

sub munge_files {
    my $self = shift;

    local @INC = ("lib", @INC);

    my %seen_mods;
    for my $file (@{ $self->found_files }) {
        next unless $file->name =~ m!\Alib/((TableData/.+)\.pm)\z!;

        my $package_pm = $1;
        my $package = $2; $package =~ s!/!::!g;

        my $content = $file->content;

        # Add statistics to %STATS variable
      CREATE_STATS:
        {
            require $package_pm;
            no strict 'refs'; ## no critic: TestingAndDebugging::ProhibitNoStrict
            my $stats = \%{"$package\::STATS"};
            last if keys %$stats; # module creates its own stats, skip
            my $no_stats = ${"$package\::NO_STATS"};
            last if $no_stats; # module does not want stats, skip

            my $td = $package->new;

            my %stats = (
                num_rows => 0,
                num_columns => 0,
            );
            $td->each_item(
                sub {
                    my $row = shift;
                    $stats{num_rows}++;
                    1;
                }
            );
            $stats{num_columns} = $td->get_column_count;

            $content =~ s{^(#\s*STATS)$}{"our \%STATS = ".dmp(%stats)."; " . $1}em
                or die "Can't replace #STATS for ".$file->name.", make sure you put the #STATS placeholder in modules";
            $self->log(["replacing #STATS for %s", $file->name]);

            $file->content($content);
        }
    } # foreach file
    return;
}

__PACKAGE__->meta->make_immutable;
1;
# ABSTRACT: Plugin to use when building TableData::* distribution

=for Pod::Coverage .+

=head1 SYNOPSIS

In F<dist.ini>:

 [TableData]


=head1 DESCRIPTION

This plugin is to be used when building C<TableData::*> distribution. Currently
it does the following:

=over

=item * Replace C<# STATS> placeholder (which must exist) with table data statistics

=back


=head1 SEE ALSO

L<TableData>

L<Pod::Weaver::Plugin::TableData>
