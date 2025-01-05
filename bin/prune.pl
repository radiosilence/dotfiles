#!/usr/bin/env perl
use strict;
use warnings;
use v5.10;  # For say, given/when
use Getopt::Long qw(:config bundling);
use File::Path qw(remove_tree);
use Term::ANSIColor qw(:constants);
use List::Util qw(max);
use POSIX qw(strftime);
use locale;
use autodie;

# Pretty output helpers
sub hr { say '─' x (console_width() || 80) }
sub center { 
    my ($text, $width) = @_;
    my $padding = int(($width - length($text)) / 2);
    return (' ' x $padding) . $text;
}

# Get console width using Term::Size if available, fallback to 80
sub console_width {
    eval { 
        require Term::Size; 
        return (Term::Size::chars())[0];
    } || 80;
}

# Format size with thousands separator
sub format_size {
    my $size = shift;
    local $_ = reverse $size;
    s/(\d{3})(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $_;
}

# Colorize based on size
sub size_color {
    my ($size, $min_size) = @_;
    return $size < $min_size / 2 ? RED : YELLOW;
}

# Parse command line options
my %opts = (min_size => 3096);
GetOptions(
    'min-size|m=i' => \$opts{min_size},
    'yes|y' => \$opts{yes},
    'help|h' => sub {
        say "Usage: $0 [-m SIZE] [-y] [--help]";
        say "Find and delete directories below specified size.";
        say "Options:";
        say "  -m, --min-size SIZE  Minimum size in KB (default: 3096)";
        say "  -y, --yes           Skip confirmation prompt";
        say "  -h, --help          Show this help message";
        exit;
    },
) or die "Try '$0 --help' for more information.\n";

# Collect and sort directories
my @dirs;
open(my $find, '-|', 'find . -type d -exec du -sk {} +');
while (<$find>) {
    chomp;
    my ($size, $path) = split(/\t/, $_, 2);
    next if $size >= $opts{min_size} 
         || $path eq '.' 
         || $path =~ /\.[^\/]*(stfolder|git)/;
    push @dirs, [$path, $size];
}
close $find;

@dirs = sort { $a->[1] <=> $b->[1] } @dirs;

unless (@dirs) {
    say STDERR "No directories below ", format_size($opts{min_size}), " KB";
    exit 1;
}

# Pretty output
my $width = console_width();
hr();
say center("Small Directories", $width);
hr();
say "Found ", scalar(@dirs), " directories below ", 
    format_size($opts{min_size}), " KB\n";

# Calculate column widths for alignment
my $size_width = max map { length format_size($_->[1]) } @dirs;

# Print directories with color
for my $dir (@dirs) {
    my ($path, $size) = @$dir;
    printf "%s%*s KB%s │ %s\n",
        size_color($size, $opts{min_size}),
        $size_width,
        format_size($size),
        RESET,
        $path;
}
print "\n";

if ($opts{yes} || prompt("Delete these directories? [y/N] ")) {
    say "\nDeleting directories...";
    for my $dir (@dirs) {
        my ($path, $size) = @$dir;
        print YELLOW, "Deleting ", RESET, $path, "... ";
        eval {
            remove_tree($path, {safe => 0});
            say GREEN, "✓", RESET;
        } or do {
            say RED, "✗", RESET;
            warn "Failed to delete $path: $@";
        };
    }
    say GREEN, "\nOperation completed.", RESET;
} else {
    say BLUE, "\nOperation canceled.", RESET;
}

sub prompt {
    my $prompt = shift;
    print $prompt;
    my $answer = <STDIN>;
    return $answer && $answer =~ /^y/i;
}