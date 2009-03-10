package Text::Mining::Shell;
use base qw(Term::Shell);
use Text::Mining;
use Text::Mining::Corpus;
use Text::Mining::Corpus::Document;
use File::Spec;
use YAML qw(DumpFile LoadFile);
use warnings;
use strict;
use Carp;

use version; our $VERSION = qv('0.0.6');

# Personal choices
our $config_filename  = '.corpus/shellrc';
our $history_filename = '.corpus/shell_history';
our $history_max_len  = 1_000;

# Package variables
our $tm;
our $current_corpus;
our @history;

# Term_Shell >

sub prompt_str { return "kodos> "; }

sub _load_config           { my ( $self ) = @_; return LoadFile( $self->_get_config_filename() ); }
sub _update_config         { my ( $shell, $arg_ref ) = @_; my $config    = $shell->_load_config(); foreach my $key ( keys %$arg_ref ) { $config->{$key} = $arg_ref->{$key}; } $shell->_save_config( $config ); }
sub _save_config           { my ( $self, $config ) = @_; DumpFile( $self->_get_config_filename(), $config ); }
sub _load_history          { my ( $self ) = @_; chomp( my $text = $self->_get_file_text( $self->_get_history_filename() ) ); @history = split(/\n/, $text); return \@history; }
sub _save_history          { my ( $self ) = @_; $self->_set_file_text( $self->_get_history_filename(), join("\n", @history) ); }
sub _get_config_filename   { return File::Spec->catfile( $ENV{HOME}, $config_filename ); }
sub _get_history_filename  { return File::Spec->catfile( $ENV{HOME}, $history_filename ); }

sub init {
	my ( $shell )      = @_;

	# TODO: Check for configuration files and create initial files

	my $config         = $shell->_load_config();
	   $tm             = Text::Mining->new();  print STDERR $tm->version(), "\n";
	   $current_corpus = $tm->get_corpus({ corpus_id => $config->{current_corpus} });

	# Set the command history
	$shell->{term}->SetHistory( @{ $shell->_load_history() } );
}

sub fini {
	my ( $shell ) = @_;

	# Save the command history
	$shell->_save_history();
}

sub postcmd {
	my ( $shell, $handler, $cmd, $args) = @_;

	# Capture commands with parameters and save to history list
	if ( $$handler =~ m/^run_/ ) { 
		push @history, "$$cmd " . join(' ', @$args); 

		# Limit the history to $history_max_len commands
		while ( @history > $history_max_len ) { shift @history; }
	}
}

# Term_Shell <
# Term_Shell <
# Term_Shell <





# System >
# System >
# System >

sub smry_cd { 'Change working directory' }
sub help_cd { <<'END';

cd - Change Directory
  cd [<path>]          : Change the current directory to the given 
                         directory. If no directory is given, the 
                         current value of $HOME is used.
END
}

sub run_cd {                        
	my ( $shell, $target_directory ) = @_;

	if ( defined $target_directory ) {
		# Adjust relative paths
		if ($target_directory =~ m/^[^\/]/ and -d $target_directory ) { 
			$target_directory = $ENV{PWD} . '/' . $target_directory;
		}
	} else {
		$target_directory = $ENV{HOME};
	} 

	chdir $target_directory;
	chomp( $ENV{PWD} = `pwd` );
}

sub smry_pwd { 'Print working directory' }
sub help_pwd { <<'END';

pwd - Print Working Directory
  pwd                  : Prints the current working directory.
END
}

sub run_pwd {
	my ( $shell ) = @_;
	print $ENV{PWD}, "\n";
}

sub smry_dir { 'List directory contents' }
sub help_dir { <<'END';

dir - List Directory Contents
  dir                  : Displays the contents of directory
END
}

sub run_dir {
	my ( $shell ) = @_;
	print $ENV{PWD}, "\n";
	print `ls -lh $ENV{PWD}`;
}

# System <
# System <
# System <







# Text_Mining >
# Text_Mining >
# Text_Mining >

sub smry_corpus_list { return "Corpus List -  corpus_list [<name>]"; }
sub help_corpus_list { 
	<<END;

corpus_list - Corpus List 
  corpus_list 			: Lists all corpuses
  corpus_show [<name>]          : Displays corpus with LIKE names

END
}

sub run_corpus_list { 
	my ( $shell, $target ) = @_;
	my $tm                 = Text::Mining->new();

	my $corpuses = $tm->get_all_corpuses();
		
	if ( @{ $corpuses }) { $shell->_print_corpus_head(); }
	foreach my $corpus ( @{ $corpuses }) {
		if ( $target ) {
			my $corpus_name = $corpus->get_name();
			if ( $corpus_name =~ m/$target/ ) {
				$shell->_print_corpus( $corpus );
			}
		} else {
			$shell->_print_corpus( $corpus );
		}
	}
}

sub smry_corpus_show { return "Corpus Show -  corpus_show [<id>|<name>]"; }
sub help_corpus_show { 
	<<END;

corpus_show - Corpus Show
  corpus_show [<id>|<name>]          : Displays one corpus 

END
}

sub run_corpus_show { 
	my ( $shell, $target ) = @_;
	my $tm                 = Text::Mining->new();

	if ( $target ) {
		my ( $corpus_id, $target_type );

		if ( $target =~ m/^\d+$/ ) {
			$corpus_id   = $target;
			$target_type = 'Corpus ID';
		} else {
			$corpus_id = $tm->get_corpus_id_from_name({ corpus_name => $target });
			$target_type = 'Corpus Name';
		}

		if ( $corpus_id ) {
			$shell->_print_corpus_head();
			$shell->_print_corpus( Text::Mining::Corpus->new({ corpus_id => $corpus_id }) );
		} else {
			print "  Corpus $target not found ($target_type).\n\n";
		}
	} else {
		print $shell->help_corpus_show();
	}
}

sub smry_corpus_set { return "Corpus Set -  corpus_set [<id>|<name>]"; }
sub help_corpus_set { 
	<<END;

corpus_set - Corpus Set 
  corpus_set 			: Displays current corpus
  corpus_set [<id>|<name>]      : Sets current corpus

END
}

sub run_corpus_set { 
	my ( $shell, $target ) = @_;
	my $tm                 = Text::Mining->new();

	if ( $target ) {
		my ( $corpus_id, $target_type );

		if ( $target =~ m/^\d+$/ ) {
			$corpus_id   = $target;
			$target_type = 'Corpus ID';
		} else {
			$corpus_id = $tm->get_corpus_id_from_name({ corpus_name => $target });
			$target_type = 'Corpus Name';
		}

		if ( $corpus_id ) { 
			$current_corpus = Text::Mining::Corpus->new({ corpus_id => $corpus_id }); 
			$shell->_update_config({ current_corpus => $corpus_id }); 
		}
		else              { print "  Corpus $target not found ($target_type).\n"; }
	} else {
		print "  Current corpus: " . $current_corpus->get_name() . "\n";
	}
}

sub smry_corpus_new { return "Create New Corpus -  corpus_new [<name>]"; }
sub help_corpus_new { 
	<<END;

corpus_new - Create new Corpus  
  corpus_new [<name>]		      : Create new corpus

END
}

sub run_corpus_new { 
	my ( $shell, $name ) = @_;
	my ( $corpus_name, $corpus_desc, $corpus_path );

	if (! $name) { $corpus_name = $shell->prompt( "  Corpus name: " ); }
	else         { $corpus_name = $name; }
	$corpus_desc = $shell->prompt( "  Corpus description: " );
	$corpus_path = $shell->prompt( "  Corpus path: " );

	my $params   = { corpus_name => $corpus_name,
	               corpus_desc => $corpus_desc,
		       corpus_path => $corpus_path };
	
	my $corpus   = Text::Mining::Corpus->new( $params );
	$shell->_print_corpus( $corpus );


}

sub smry_corpus_delete { return "Delete Corpus -  corpus_delete [<name>]"; }
sub help_corpus_delete { 
	<<END;

corpus_delete - Corpus Delete 
  corpus_delete [<name>]		      : Delete existing corpus

END
}

sub run_corpus_delete { 
	my ( $shell, $name ) = @_;
	my ( $corpus_name );
	if (! $name) { $corpus_name = $shell->prompt( "  Corpus name: " ); }
	else         { $corpus_name = $name; }
	my $params = { corpus_name => $corpus_name };
	
	my $corpus = Text::Mining::Corpus->new( $params );
	   $corpus->delete();

}

sub smry_document_add { return "Add Document -  document_add [<name>]"; }
sub help_document_add { 
	<<END;

document_add - Add a document to the current corpus
  document_add [<file_name>]	  : Filename optional first parameter 

END
}

sub run_document_add { 
	my ( $shell, $file_name ) = @_;

#	if (! $current_corpus ) { print "  You must set a current corpus (corpus_set)."; }
	if (! $file_name) { $file_name = $shell->prompt( "  File name: " ); }

	if      (-e $file_name && -d $file_name) { 
		print "  Dir found.\n"; 
	} elsif (-e $file_name && -f $file_name) { 
		print "  File found.\n"; 
	} else                                   { 
		print "  File not found.\n"; 
	}
	
#	my $params = { corpus_name => $corpus_name };
#	my $corpus = Text::Mining::Corpus->new( $params );
#	   $corpus->delete();

}

sub smry_test { return " Template subroutine \n"; }
sub help_test { return " Test Help \n"; }

sub run_test { 
	my ( $shell ) = @_;
	my $answer    = $shell->prompt(" What did you do last summer? ", "default");
	print " Test Run $answer\n"; 
}

# Text_Mining <
# Text_Mining <
# Text_Mining <






# Internals >
# Internals >
# Internals >

sub _print_corpus_head {
	print "  Corpus\tName\t\tDesc\t\tPath\n";
}

sub _print_corpus {
	my ( $shell, $corpus ) = @_;
	print "  ", $corpus->get_corpus_id(), "\t", 
	            $corpus->get_name(), "\t", 
	            $corpus->get_desc(), "\t", 
	            $corpus->get_path(), "\n";
}

sub _get_file_text {
	my ( $self, $path_file_name ) = @_;
	my ($text, $line);
	if (-e $path_file_name) {
		open  (my $IN, '<', $path_file_name) || $self->_status( "(Get) Cannot open $path_file_name: $!" );
		while ($line = <$IN>) { $text .= $line; }
		close ($IN)                          || $self->_status( "(Get) Cannot close $path_file_name: $!" );
	}
	return $text;
}

sub _set_file_text {
	my ( $self, $path_file_name, $text ) = @_;
	open  (my $OUT, '>', $path_file_name)        || $self->_status( "(Set) Cannot open $path_file_name: $!" );
	print {$OUT} $text                           || $self->_status( "(Set) Cannot write $path_file_name: $!" );
	close ($OUT)                                 || $self->_status( "(Set) Cannot close $path_file_name: $!" );
}

sub _add_file_text {
	my ( $self, $path_file_name, $text ) = @_;
	open  (my $OUT, '>>', $path_file_name)       || $self->_status( "(Add) Cannot open $path_file_name: $!" );
	print {$OUT} $text                           || $self->_status( "(Add) Cannot write $path_file_name: $!" );
	close ($OUT)                                 || $self->_status( "(Add) Cannot close $path_file_name: $!" );
}

sub _status {
	my ( $self, $msg ) = @_;
	my $status_file = $self->get_status_filename();
	open  (my $OUT, '>>', $status_file)          || croak( "(Status) Cannot open $status_file: $!" );
	print {$OUT} "  STATUS: $msg \n"             || croak( "(Status) Cannot write $status_file: $!" );
	close ($OUT)                                 || croak( "(Status) Cannot close $status_file: $!" );
	return;

# Internals <

}

1; # Magic true value required at end of module
__END__

=head1 NAME

Text::Mining::Shell - Command Line Tools for Text Mining

=head1 VERSION

This document describes Text::Mining::Shell version 0.0.6

=head1 SYNOPSIS

    use Text::Mining;

    my $tm = Text::Mining->new();
    $tm->shell();

  
=head1 DESCRIPTION

This module provides the methods for a shell-based system for text mining 
using Term::Shell.

=head1 INTERFACE 

Commands generally take the form of noun_verb where nouns are library, 
corpus, document, language, word, concept, and representation and 
verbs are list, new, show, update, and delete.

The system is better documented online. After starting the shell, 
type "help" and hit enter for a list of commands.


=head1 CONFIGURATION AND ENVIRONMENT

Text::Mining::Shell requires a configuration file at ~/.corpus/shellrc.


Text::Mining::Shell also requires Text::Mining to accomplish anything, and 
it requires a configuration file at ~/.corpus/config.

The default location of these files and their contents may change in future versions.

Future versions will include an install method for initializing the configurations.

=head1 DEPENDENCIES

 Term::Shell;
 Text::Mining;
 Text::Mining::Corpus;
 Text::Mining::Corpus::Document;
 File::Spec;
 YAML;
 
=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-text-mining-shell@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Roger A Hall  C<< <rogerhall@cpan.org> >>


=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009, Roger A Hall C<< <rogerhall@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENSE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
