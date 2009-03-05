use Test::More tests => 17;

BEGIN {
use_ok( 'Text::Librarian' );
}

# Create a new librarian
my $librarian = Text::Librarian->new();
ok( $librarian, "\$librarian = Text::Librarian->new()" );

# Create a new corpus
my $corpus = $librarian->create_corpus({ corpus_name => 'Test Corpus', 
                                         corpus_path => '/home/roger/projects/comprehension/documents/corpus_1', 
				         corpus_desc => 'Testing the software' });
ok( $corpus, "\$corpus = \$librarian->create_corpus()" );

# Save the ID so we can delete it later
my $corpus_id = $corpus->get_id();
ok( $corpus_id, "\$corpus_id = \$corpus->get_id()" );

# Get all corpuses
my $corpuses = $librarian->get_all_corpuses();
ok( $corpuses, "\$corpuses = \$librarian->get_all_corpuses()" );

# Display the corpuses
#foreach my $corpus (@$corpuses) { print "  CORPUS: " . join(', ', $corpus->get_name(), $corpus->get_path()) . "\n"; }

# Submit a document to the corpus
my $doc = $corpus->submit_document({ corpus_id            => $corpus_id,
                                     submitted_by_user_id => 1,
				     bytes                => '14042',
				     document_path        => 'testing',
				     document_file_name   => 'testing' });
ok( $doc, "\$doc = \$corpus->submit_document()" );

# Delete the submission
# $corpus->delete_submitted_document({ submitted_document_id => $doc->get_id() }); # Also works
$doc->delete();

# Delete the test corpus
$librarian->delete_corpus({ corpus_id => $corpus_id }); # This also deletes submitted documents

# Display the corpuses
#my $corpuses = $librarian->get_all_corpuses();
#foreach my $corpus (@$corpuses) { print "  CORPUS: " . join(', ', $corpus->get_name(), $corpus->get_path()) . "\n"; }

# Get a submitted document and display properties
my $submitted_document = $librarian->get_submitted_document({ submitted_document_id => 12 });
ok( $submitted_document, "\$submitted_document = \$librarian->get_submitted_document()" );

my $sd_id = $submitted_document->get_submitted_document_id();
ok( $sd_id, "$sd_id -> \$id = \$submitted_document->get_submitted_document_id()" );

my $c_id = $submitted_document->get_corpus_id();
ok( $c_id, "\$c_id = \$submitted_document->get_corpus_id()" );

my $sb_id = $submitted_document->get_submitted_by_user_id();
ok( $sb_id, "\$sb_id = \$submitted_document->get_submitted_by_user_id()" );

my $dpath = $submitted_document->get_document_path();
ok( $dpath, "\$dpath = \$submitted_document->get_document_path()" );

my $dfile = $submitted_document->get_document_file_name();
ok( $dfile, "\$dfile = \$submitted_document->get_document_file_name()" );

my $bytes = $submitted_document->get_bytes();
ok( $bytes, "\$bytes = \$submitted_document->get_bytes()" );

my $enter = $submitted_document->get_enter_date();
ok( $enter, "\$enter = \$submitted_document->get_enter_date()" );

my $exit = $submitted_document->get_exit_date();
ok( $exit, "\$exit = \$submitted_document->get_exit_date()" );

my $waiting  = $librarian->count_submitted_waiting();
ok( $waiting >= 0, "\$waiting = \$librarian->count_submitted_waiting()" );

my $complete = $librarian->count_submitted_complete();
ok( $complete >= 0, "\$complete = \$librarian->count_submitted_complete()" );

