#!/bin/perl


# This program is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see
# <http://www.gnu.org/licenses/>.


# usage: replace.pl <filename>
#
# replace file A with file B when the first line of file A is a key
# found in a look-up table; file B is specified by the value of the
# key
#
# Entries in the look-up table are lines.  Each line holds a key-value
# pair, seperated by a colon and a space: 'key: value'.
#


use strict;
use warnings;
use autodie;

use File::Copy;
use File::Basename;


# the editor to use
#
# Note: Use an editor that waits before it exits until you are
# finished editing the file.  Your sl client stops monitoring the file
# when the editor exits (or forks off into the background) before
# you´re done editing, and it may not replace the contents of its
# built-in editor with the contents of the file you´re editing.
#
use constant EDITOR => "emacsclient";
#
# "-c" makes emacsclient create a new frame.  If you start your
# favourite editor without such a parameter, you want to remove
# EDITORPARAM here an in the 'start_editor' function.
#
use constant EDITORPARAM => "-c";


# a wrapper function to start the editor
#
sub start_editor
  {
    my (@files_to_edit) = @_;

    system(EDITOR, EDITORPARAM, @files_to_edit);
  }


# unless the filename given as parameter is *.lsl, edit the file
#
unless($ARGV[0] =~ m/.*\.lsl/)
{
  start_editor($ARGV[0]);
  exit(0);
}


# the file name of the lookup table; specify an absolute path here
#
my $table = dirname(__FILE__) . "/../make/replaceassignments.txt";

# start the editor when the lookup table doesn´t exist
#
unless(-e $table)
  {
    start_editor($ARGV[0], $table);
    exit(0);
  }

# search the file for a pattern like "// =filename.[o|i]"
#
my $line;

open my $script, "<", $ARGV[0];
LINE: while($line = <$script>)
  {
    chomp $line;
    if($line =~ m!^// =!)
      {
	$line =~ s!^// =!!;
	unless(($line =~ m/^\S+\.o/) || ($line =~ m/^\S+\.i/))
	  {
	    start_editor($ARGV[0], $table);
	    exit(0);
	  }
	else
	  {
	    last LINE;
	  }
      }
  }
close $script;


# the pattern has been found: look up the key in the lookup table
#
# the key is looked up for *.o and *.i so that only one entry per
# script is needed in the lookup table to cover both *.i and *.o,
# provided that the directory structure doesn´t change
#
my $i_line = $line;
$i_line =~ s/\.i$/\.o/;
$i_line .= ": ";
$line .= ": ";
my $replacementfile = undef;
open my $assign, "<", $table;
while( <$assign> )
  {
    # ignore lines starting with "//" as comments
    #
    unless( m!^//!)
      {
	chomp $_;
	if( m/^$line/ || m/^$i_line/)
	  {
	    $replacementfile = $';
	    last;
	  }
      }
  }
close $assign;

if(defined($replacementfile))
  {
    if($line =~ m/.*\.i:/)
      {
	$replacementfile =~ s!/bin/!/dbg/!;
	$replacementfile =~ s/\.o$/\.i/;
      }

    # when the value of the key looks ok, replace the file, otherwise edit
    # the file and the table
    #
    if(($replacementfile =~ m/.*\.o$/) || ($replacementfile =~ m/.*\.i$/))
      {
	copy($replacementfile, $ARGV[0]);
      }
  }
else
  {
    start_editor($ARGV[0], $table);
  }
