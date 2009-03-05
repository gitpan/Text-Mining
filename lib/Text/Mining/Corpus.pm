package Text::Mining::Corpus;
use base qw(Text::Mining::Base);
use Class::Std;
use Class::Std::Utils;

use warnings;
use strict;
use Carp;

use version; our $VERSION = qv('0.0.4');

{
	my %id_of    : ATTR( );
	my %name_of  : ATTR( );
	my %desc_of  : ATTR( );
	my %path_of  : ATTR( );

	sub BUILD {      
		my ($self, $ident, $arg_ref) = @_;
	               
		if    (defined $arg_ref->{corpus_id})   { $self->_get_corpus($arg_ref); }
		elsif (defined $arg_ref->{corpus_name}) { $self->insert( $arg_ref ); }

		return;
	}

	sub submit_document           { my ( $self, $arg_ref ) = @_; $arg_ref->{corpus_id} = $id_of{ident $self}; return Text::Librarian::SubmitDocument->new( $arg_ref ); }
	sub delete_submitted_document { my ( $self, $arg_ref ) = @_; return Text::Librarian::SubmitDocument->delete( $arg_ref ); }

	sub get_id              { my ($self) = @_; return $id_of{ident $self}; }
	sub get_corpus_id       { my ($self) = @_; return $id_of{ident $self}; }
	sub get_name            { my ($self) = @_; return $name_of{ident $self}; }
	sub get_path            { my ($self) = @_; return $path_of{ident $self}; }
	sub get_desc            { my ($self) = @_; return $desc_of{ident $self}; }
	sub get_data_dir        { my ($self) = @_; return $self->_get_data_dir( $id_of{ident $self} ); }

	sub set_name            { my ($self, $value) = @_; $name_of{ident $self} = $value; return $self; }
	sub set_desc            { my ($self, $value) = @_; $desc_of{ident $self} = $value; return $self; }
	sub set_path            { my ($self, $value) = @_; $path_of{ident $self} = $value; return $self; }

	sub _get_corpus {
		my ($self, $arg_ref) = @_;
		my $ident = ident $self;

		my $sql  = "select corpus_id, corpus_name, corpus_desc, corpus_path ";
		   $sql .= "from corpuses ";
	   	   $sql .= "where corpus_id = '$arg_ref->{corpus_id}'";

		($id_of{$ident}, 
	   	 $name_of{$ident}, 
	   	 $desc_of{$ident}, 
	   	 $path_of{$ident}) = $self->library()->sqlexec( $sql, '@' );
	}

	sub update {
		my ( $self, $arg_ref )   = @_; 
		my $ident       = ident $self;
		my @updates     = ();

		if ( defined $arg_ref->{corpus_name} ) { $self->set_name( $arg_ref->{corpus_name} ); push @updates, "corpus_name = '" . $self->_html_to_sql( $arg_ref->{corpus_name} ) . "'"; }
		if ( defined $arg_ref->{corpus_desc} ) { $self->set_desc( $arg_ref->{corpus_desc} ); push @updates, "corpus_desc = '" . $self->_html_to_sql( $arg_ref->{corpus_desc} ) . "'"; }
		if ( defined $arg_ref->{corpus_path} ) { $self->set_path( $arg_ref->{corpus_path} ); push @updates, "corpus_path = '" . $self->_html_to_sql( $arg_ref->{corpus_path} ) . "'"; }

		my $sql  = "update corpuses set " . join( ', ', @updates ) . " where corpus_id = '$id_of{$ident}'";
	   	$self->library()->sqlexec( $sql );
	}

	sub insert {
		my ($self, $arg_ref)  = @_; 
		my $ident       = ident $self;

		( $name_of{$ident}, 
	   	  $desc_of{$ident}, 
	   	  $path_of{$ident} ) = ( $arg_ref->{corpus_name},
		                         $arg_ref->{corpus_desc},
		                         $arg_ref->{corpus_path} );

		foreach ('corpus_name', 'corpus_path', 'corpus_desc') { $arg_ref->{$_} = $self->_html_to_sql( $arg_ref->{$_} || '' ); }
		
		my $sql  = "insert into corpuses (corpus_name, corpus_path, corpus_desc) ";
		   $sql .= "values ( '$arg_ref->{corpus_name}', '$arg_ref->{corpus_path}', '$arg_ref->{corpus_desc}') ";
	   	$self->library()->sqlexec( $sql );

		   $sql  = "select LAST_INSERT_ID()";
	   	( $id_of{$ident} ) = $self->library()->sqlexec( $sql, '@' );
	}

	sub delete {
		my ( $self, $arg_ref )  = @_; 
		my $id = defined($arg_ref->{corpus_id}) ? $arg_ref->{corpus_id} : $id_of{ident $self};
	   	$self->library()->sqlexec( "delete from corpuses where corpus_id = '$id'" );
	   	$self->library()->sqlexec( "delete from submitted_documents where corpus_id = '$id'" );
	}

	sub clean {
		my ( $self ) = @_; 
		my @dirs     = $self->_get_dirs( $self->get_data_dir() );
		foreach my $dir ( @dirs ) { $self->clean_directory( $dir ); }
	}

	sub clean_directory {
		my ( $self, $dir ) = @_; 
		my @files      = $self->_get_files( $dir );
		my @sub_dirs   = $self->_get_dirs( $dir, 0 );
		my $file_count = scalar(@files);
		my $dir_count  = scalar(@sub_dirs);

		if ($file_count + $dir_count == 0) { rmdir($dir); }

		foreach my $file    ( @files )    { if (! ($file =~ m/\.zip$/i) ) { $self->clean_document( $dir . '/' . $file ); } }
		foreach my $sub_dir ( @sub_dirs ) { $self->clean_directory( $sub_dir ); }
	}

	sub clean_document {
		my ( $self, $file ) = @_; 
		my @parts           = split(/\//, $file);
		my $root_dir        = $self->_get_root_dir();
		my $file_name       = pop( @parts );
		   $file_name       =~ m/^([\w\.%-]*)\.([\w%-]*)$/;
		my $path            = join( '/', @parts );
		   $path            =~ s/$root_dir\/documents\/corpus_\d+//;
		foreach ($path, $file_name) { $_ = $self->_html_to_sql($_); }
		my $sql  = "select submitted_document_id, corpus_id from submitted_documents ";
		   $sql .= "where document_path = '$path' ";
		   $sql .= "  and document_file_name = '$file_name' ";
		my ( $id, $corpus_id ) = $self->library()->sqlexec( $sql, '@' );

		if (! $id )  { print STDERR "  Unlinking $file \n"; unlink( $file ); }
	}

	sub compress {
		my ( $self, $arg_ref ) = @_; 
		my $data_dir           = $self->get_data_dir();
		my @dirs               = $self->_get_dirs( $data_dir, 0 );
		foreach my $dir ( @dirs ) { $self->compress_directory( $dir ); }
	}

	sub compress_directory {
		my ( $self, $dir ) = @_; 
		my @files      = $self->_get_files( $dir );
		my @sub_dirs   = $self->_get_dirs( $dir, 0 );
		my $file_count = scalar(@files);
		my $dir_count  = scalar(@sub_dirs);

		if ($file_count + $dir_count == 0) { rmdir($dir); }

		foreach my $file    ( @files )    { if (! ($file =~ m/\.zip$/i) ) { $self->compress_document( $dir . '/' . $file ); } }
		foreach my $sub_dir ( @sub_dirs ) { $self->compress_directory( $sub_dir ); }
	}

	sub compress_document {
		my ( $self, $file ) = @_; 
		my @parts           = split(/\//, $file);
		my $root_dir        = $self->_get_root_dir();
		my $file_name       = pop( @parts );
		   $file_name       =~ m/^([\w\.%-]*)\.([\w%-]*)$/;
		my $file_root       = $1;
		my $path            = join( '/', @parts );
		   $path            =~ s/$root_dir\/documents\/corpus_(\d+)//;
		my $corpus_id       = $1;

		my $zip_file = $root_dir . '/documents/corpus_' . $corpus_id . $path . '/' . $file_root . '.zip';
		`zip -q $zip_file $file`;
		unlink( $file );

  		my @stat  = stat("$root_dir$path/$file_root.zip");
  		my $bytes = $stat[7] || '0';

		my $sql  = "update submitted_documents set compressed_file_name = '$file_root.zip', compressed_bytes = '$bytes' ";
		   $sql .= "where document_path = '$path' ";
		   $sql .= "  and document_file_name = '$file_name' ";
	   	$self->library()->sqlexec( $sql );
	}

	sub decompress {
		my ( $self, $arg_ref ) = @_; 
		my $data_dir           = $self->get_data_dir();
		my @dirs               = $self->_get_dirs( $data_dir, 0 );
		foreach my $dir ( @dirs ) { $self->decompress_directory( $dir ); }
	}

	sub decompress_directory {
		my ( $self, $dir ) = @_; 
		my @files      = $self->_get_files( $dir );
		my @sub_dirs   = $self->_get_dirs( $dir, 0 );

		foreach my $file ( @files ) {
			if ($file =~ m/\.zip$/i) { $self->decompress_document( $dir . '/' . $file ); } }
		foreach my $sub_dir ( @sub_dirs ) {
			$self->decompress_directory( $sub_dir ); }
	}

	sub decompress_document {
		my ( $self, $zip_file ) = @_; 
		`unzip -q -d/ $zip_file`;
		unlink( $zip_file );
	}

	sub import_urls {
		my ( $self, $arg_ref ) = @_; 
		my $ident              = ident $self;
		my $corpus_id          = $id_of{$ident};
		my $user_id            = $arg_ref->{submitted_by_user_id};
		my $source_type        = $arg_ref->{source_type};
		my @urls               = ();
		my $record_count       = 0;
		
		if ($source_type eq 'files' ) { @urls = $self->_parse_urls_from_files( $arg_ref ); }
		else                          { print STDERR "  Warning: no valid source_type for \$corpus->import_url()\n"; }
		
		my @insert_values = ();
		foreach my $url (@urls) {
			foreach ($url) { $_ = $self->_html_to_sql($_); }
			my $sql  = "select submitted_urls.submitted_url_id from submitted_urls ";
			   $sql .= " where submitted_urls.submitted_url = '$url'";
			my ( $url_id ) = $self->library()->sqlexec( $sql, '@' );
		
			if (! $url_id) {
				my @path = split(/\//, $url); shift(@path); shift(@path); 
				my $file = pop(@path);
				my $path = '';
				
				foreach ($path, $file) { $_ = $self->_html_to_sql($_); }
				push @insert_values, "($corpus_id, $user_id, '$url')";
			
				if (@insert_values == 100) {
					$record_count += 100;
					my $url_sql    = "insert into submitted_urls (corpus_id, submitted_by_user_id, submitted_url ) ";
					   $url_sql   .= "values " . join( ',', @insert_values ) . ";";
	   				$self->library()->sqlexec( $url_sql );
					@insert_values = ();
				}
			}
		}
		if ( @insert_values ) {
			$record_count += scalar( @insert_values );
			my $url_sql    = "insert into submitted_urls (corpus_id, submitted_by_user_id, submitted_url ) ";
			   $url_sql   .= "values " . join( ',', @insert_values ) . ";";
	   		$self->library()->sqlexec( $url_sql );
		}
		return $record_count;
	}

	sub _parse_urls_from_files {
		my ( $self, $arg_ref ) = @_; 
		my $ident              = ident $self;
		my $source_dir         = $arg_ref->{source_dir} ? $arg_ref->{source_dir} : $self->_get_root_dir() . '/document_sources/corpus_' . $id_of{$ident};
		my $link_type          = $arg_ref->{link_type};
		my %link               = ();
		
		my @files = $self->_get_files( $source_dir );

		foreach my $file (@files) {
			my $content = $self->_get_file_text($source_dir . "/$file");
			my $parser  = HTML::LinkExtor->new(); $parser->parse($content)->eof;
			my @links   = $parser->links;
		
			foreach my $linkarray (@links) {
				my @elements	= @$linkarray;
				my $elt_type 	= shift @elements;
		
				while (@elements) {
					my ($attr_name, $attr_value) = splice(@elements, 0, 2);
					if ($attr_value =~ m/^http(.*)$link_type$/i) { $link{$attr_value}++; }
				}
			}
		}
		return sort keys %link;
	}
}

1; # Magic true value required at end of module
__END__

=head1 NAME

Text::Mining::Corpus - Perl Tools for Text Mining


=head1 VERSION

This document describes Text::Mining::Corpus version 0.0.4


=head1 SYNOPSIS

    use Text::Mining::Corpus;

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
  
Text::Mining::Corpus requires no configuration files or environment variables.


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
C<bug-text-mining-corpus@rt.cpan.org>, or through the web interface at
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
