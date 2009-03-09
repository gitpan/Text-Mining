package Text::Mining;
use base qw(Text::Mining::Base);
use Class::Std;
use Class::Std::Utils;
use Text::Mining::Corpus;
use Text::Mining::Corpus::Document;
use Text::Mining::Shell;

use warnings;
use strict;
use Carp;

use version; our $VERSION = qv('0.0.5');

{
	my %attribute_of : ATTR( get => 'attribute', set => 'attribute' );
	
	sub BUILD {      
		my ($self, $ident, $arg_ref) = @_;
	               
	#	&DBConnect( %{ $self->_library_connect_parameters() } );

		return;
	}

	sub shell { my $shell = Text::Mining::Shell->new(); $shell->cmdloop(); }
	sub version { return "VERSION $VERSION"; }

	sub create_corpus             { my ( $self, $arg_ref ) = @_; return Text::Mining::Corpus->new( $arg_ref ); }
	sub get_corpus                { my ( $self, $arg_ref ) = @_; return Text::Mining::Corpus->new( $arg_ref ); }
	sub delete_corpus             { my ( $self, $arg_ref ) = @_; my $corpus = Text::Mining::Corpus->new(); return $corpus->delete( $arg_ref ); }

	sub get_root_dir              { my ( $self ) = @_; return $self->_get_root_dir(); }
	sub get_root_url              { my ( $self ) = @_; return $self->_get_root_url(); }
	sub get_data_dir              { my ( $self, $corpus_id ) = @_; return $self->_get_data_dir( $corpus_id ); }

	sub get_submitted_document    { my ( $self, $arg_ref ) = @_; return Text::Mining::Corpus::Document->new( $arg_ref ); }
	sub count_submitted_waiting   { my ( $self ) = @_; my ( $count ) = $self->library()->sqlexec( "select count(*) from submitted_documents where exit_date = '0000-00-00 00:00:00'", '@' ); return $count; }
	sub count_submitted_complete  { my ( $self ) = @_; my ( $count ) = $self->library()->sqlexec( "select count(*) from submitted_documents where exit_date != '0000-00-00 00:00:00'", '@' ); return $count; }

	sub get_all_corpuses          { 
		my ( $self, @corpuses) = @_; 
		my $corpuses = $self->library()->sqlexec( "select corpus_id from corpuses order by corpus_id asc", '\@@' ); 
		foreach my $corpus (@$corpuses) { push @corpuses, Text::Mining::Corpus->new({ corpus_id => $corpus->[0] }); } 
		return \@corpuses; 
	}

	sub get_corpus_id             { 
		my ( $self, $arg_ref ) = @_; 
		my   $corpus           = Text::Mining::Corpus->new(); 
		my ( $corpus_id )      = $self->library()->sqlexec( "select corpus_id from corpuses where corpus_name = '" . $arg_ref->{corpus_name} . "'", '@' ); 
		return $corpus_id; 
	}

	sub process_urls {
		my ( $self ) = @_; 
		my $corpuses = $self->get_all_corpuses();
		foreach my $corpus( @$corpuses ) {
			my $data_dir      = $self->get_data_dir( $corpus->get_id() );
			my $sql           = "select submitted_url_id, corpus_id, submitted_by_user_id, submitted_url from submitted_urls where exit_date = '0000-00-00 00:00:00' and file_not_found = 0";
			my $urls          = $self->library()->sqlexec( $sql, '\@@' );
			foreach my $url ( @$urls ) { $self->_download_url( $url, $data_dir ); }
		}
	}

	sub reprocess_urls {
		my ( $self ) = @_; 
		my $corpuses = $self->get_all_corpuses();
		foreach my $corpus( @$corpuses ) {
			my ( $corpus_id ) = @$corpus;
			my $data_dir      = $self->get_data_dir( $corpus->get_id() );
			my $sql           = "select submitted_url_id, corpus_id, submitted_by_user_id, submitted_url from submitted_urls where file_not_found = 1";
			my $urls          = $self->library()->sqlexec( $sql, '\@@' );
			foreach my $url ( @$urls ) { $self->_download_url( $url, $data_dir ); }
		}
	}

	sub _download_url {
		my ( $self, $url_row, $data_dir )          = @_; 
		my ( $id, $corpus_id, $user_id, $url ) = @$url_row;
		my $file_name = $self->_parse_file_name( $url );
		my $path      = $self->_build_directories( $url, $data_dir );
		my $bytes     = $self->_download_file({ target_dir => $data_dir . $path,
		                                        url        => $url,
						        file_name  => $file_name });
		if ( $bytes ) { 
			my $sql  = "insert into submitted_documents (submitted_url_id, corpus_id, submitted_by_user_id, document_path, document_file_name, bytes ) ";
			   $sql .= "values ('$id', '$corpus_id', '$user_id', '$path', '$file_name', '$bytes' )";
			$self->library()->sqlexec( $sql );
			$self->library()->sqlexec( "update submitted_urls set exit_date = now(), file_found = 1, file_not_found = 0 where submitted_url_id = '$id'" ); }
		else 	      { 
			$self->library()->sqlexec( "update submitted_urls set exit_date = now(), file_found = 0, file_not_found = 1 where submitted_url_id = '$id'" ); }
	}

	sub _build_directories {
		my ( $self, $url, $corpus_data_dir ) = @_; 
		my @path     = split(/\//, $url); shift(@path); shift(@path); # Remove protocol
		my $file     = pop(@path);
		my $path     = '';
	
		foreach my $part (@path) { 
			$path .= '/' . $part; 
			if (! -e $corpus_data_dir . $path) { mkdir $corpus_data_dir . $path; } 
		}
		return $path;
	}
	
}

1; # Magic true value required at end of module
__END__

=head1 NAME

Text::Mining - Perl Tools for Text Mining


=head1 VERSION

This document describes Text::Mining version 0.0.5


=head1 SYNOPSIS

    use Text::Mining;

    my $wizard = CatalystX::Wizard->new({attribute => 'value'});

    print $wizard->get_attribute(), "\n";

    $wizard->set_attribute('new value');

    print $wizard->get_attribute(), "\n";

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
Text::Mining requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-text-mining@rt.cpan.org>, or through the web interface at
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
