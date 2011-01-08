#! perl
use strict;
use CGI::Carp qw/fatalsToBrowser/;

schedule_list->new->process_request;
exit;

package schedule_list;
use CGILite;
BEGIN { push our @ISA, 'CGILite' }

sub on_get ($) {
  my $self = shift;

  use ScheduleFile;
  
  use HTMLDOMLite;
  my $html_ns = q<http://www.w3.org/1999/xhtml>;
  my $doc = HTMLDOMLite->dl_create_html_document ('Schedule');

my $body = $doc->body;

my $table = $doc->create_element_ns ($html_ns, 'table');
my $tbody = $doc->create_element_ns ($html_ns, 'tbody');
$table->append_child ($tbody);
$body->append_child ($table);

  my $data_file = ScheduleFile->open_file ('<', 'grid.txt');
  my $script_uri = $self->script_uri;

$data_file->for_each_entry (sub ($) {
  my $entry = shift;
  my $tr = $doc->create_element_ns ($html_ns, 'tr');
  my %param;
  for (qw/id date title/) {
    my $td = $doc->create_element_ns ($html_ns, $_ eq 'id' ? 'th' : 'td');
    $td->scope ('row') if $_ eq 'id';
    $entry->property ($_)->append_short_html ($doc, $td, $script_uri);
    $tr->append_child ($td);
  }
  $tbody->append_child ($tr);
});

  use Encode;
  my $out = $self->response_file;
  print $out "Content-Type: text/html; charset=utf-8\n";
  print $out "Cache-Control: no-cache\n";
  print $out "\n";
  print $out Encode::encode ('utf-8', $doc->dl_outer_html);
} # on_get
