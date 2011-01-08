#! perl
use strict;
use CGI::Carp qw/fatalsToBrowser/;

schedule_item->new->process_request;
exit;

package schedule_item;
use CGILite;
BEGIN { push our @ISA, 'CGILite' }

sub on_get ($) {
  my $self = shift;
  my $pi = $self->path_info;
  if (defined $pi and $pi =~ m#^/(\d+)$#) {
    my $id = $1;

    use ScheduleFile;
    my $data_file = ScheduleFile->open_file ('<', 'grid.txt');
    my $entry = $data_file->get_entry ($id);
    ($self->on_resource_not_found and return) unless $entry;
    my $script_uri = $self->script_uri;

    use HTMLDOMLite;
    my $html_ns = q<http://www.w3.org/1999/xhtml>;
    my $doc = HTMLDOMLite->dl_create_html_document ('Scheduled Item #' . $id);
    my $body = $doc->body;
    
    my $dl = $doc->create_element_ns ($html_ns, 'dl');
    $body->append_child ($dl);
    my %keys = map {$_ => 1} keys %$entry;
    delete $keys{$_} for qw/id date title/;
    for (qw/id date title/, keys %keys) {
      my $prop = $entry->property ($_);
      $prop->append_label_html ($doc, $dl->append_child ($doc->create_element_ns ($html_ns, 'dt')), $script_uri);
      $prop->append_long_html ($doc, $dl->append_child ($doc->create_element_ns ($html_ns, 'dd')), $script_uri);
    }
    
    use Encode;
    my $out = $self->response_file;
    print $out "Content-Type: text/html; charset=utf-8\n";
    print $out "\n";
    print $out Encode::encode ('utf-8', $doc->dl_outer_html);
  } else {
    $self->on_resource_not_found;
  }
} # on_get

sub on_post ($) {
  my $self = shift;
  unless (defined $self->path_info) {
    use ScheduleFile;
    my $data_file = ScheduleFile->open_file ('>', 'grid.txt');
    my %entry;
    my $params = $self->entity_body_parameters;
    for my $name (keys %$params) {
      $entry{$name} = $params->{$name}->[0];
    }
    delete $entry{_charset_};
    my $id = $data_file->add_entry (%entry)->id;
    undef $data_file;
    my $new_uri = $self->script_uri . "/$id";
    my $out = $self->response_file;
    print $out "Status: 303 Resource Created\n"; # Actually 201, but it has no redirection
    print $out "Location: $new_uri\n";
    print $out "Cache-Control: no-cache\n";
    print $out "Content-Type: text/plain; charset=us-ascii\n";
    print $out "\n";
    print $out "See <$new_uri>\n";
  } else {
    $self->on_resource_not_found;
  }
} # on_push

sub USE_ENTITY_BODY_PARAMETER { 1 }
