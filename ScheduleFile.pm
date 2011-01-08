package ScheduleFile;
use strict;
use utf8;
my $html_ns = q<http://www.w3.org/1999/xhtml>;

sub open_file ($$) {
  my ($class, $mode, $file_name) = @_;
  my $self = bless {entry => [], file_name => $file_name, mode => $mode}, $class;
  ## TODO: Lock
  open my $file, '<:encoding(utf8)', $file_name or die "$0: $mode $file_name: $!";
  while (<$file>) {
    tr/\x0A\x0D//d;
    next unless length;
    push @{$self->{entry}}, {map {_unescape ($_)} map {split /=/, $_, 2} split /\|/, $_};
  }
  close $file;
  return $self;
} # open_file

sub _unescape ($) {
  my $s = shift;
  $s =~ s/&nl;/\n/g;
  $s =~ s/&eq;/=/g;
  $s =~ s/&pipe;/|/g;
  $s =~ s/&amp;/&/g;
  $s;
} # _unescape

sub _escape ($) {
  my $s = shift;
  $s =~ s/&/&amp;/g;
  $s =~ s/\|/&pipe;/g;
  $s =~ s/=/&eq;/g;
  $s =~ s/\x0D\x0A?/&nl;/g;
  $s =~ s/\x0A/&nl;/g;
  $s;
} # _escape

sub for_each_entry ($$) {
  my ($self, $code) = @_;
  for (@{$self->{entry}}) {
    $code->(bless $_, 'ScheduleFile::Entry');
  }
} # for_each_entry

sub add_entry ($%) {
  my ($self, %entry) = @_;
  my $entry_number = 0;
  for (@{$self->{entry}}) {
    $entry_number = $_->{id} if $_->{id} > $entry_number;
  }
  $entry{id} = ++$entry_number;
  push @{$self->{entry}}, \%entry;
  $self->{modified} = 1;
  return bless \%entry, 'ScheduleFile::Entry';
} # add_entry

sub get_entry ($$) {
  my ($self, $id) = @_;
  for my $entry (@{$self->{entry}}) {
    return bless $entry, 'ScheduleFile::Entry' if $entry->{id} == $id;
  }
  return undef;
} # get_entry

sub stringify ($) {
  my $self = shift;
  my $r = join "\n", map {
    my $hash = $_;
    join '|', map {
      _escape ($_) . '=' . _escape ($hash->{$_})
    } keys %$hash;
  } @{$self->{entry}};
} # stringify

sub DESTROY ($) {
  my $self = shift;
  if ($self->{modified}) {
    if ($self->{mode} ne '>') {
      die "$0: $self->{file_name}: Can't write in mode |$self->{mode}|";
    }
    open my $file, '>:encoding(utf8)', $self->{file_name} or die "$0: $self->{file_name}: $!";
    print $file $self->stringify;
    close $file;
  }
  ## TODO: Unlock
} # DESTROY

package ScheduleFile::Entry;

sub propery_names ($) {
  my $self = shift;
  return keys %$self;
} # property_names

sub property ($$) {
  my ($self, $prop_name) = @_;
  my $class = 'ScheduleFile::Entry::Property';
  no strict 'refs';
  if (@{$class.'::'.$prop_name.'::ISA'}) {
    $class .= '::' . $prop_name;
  }
  return bless [$self, $prop_name], $class;
} # property

sub id ($) {
  return shift->property ('id')->value;
} # id

package ScheduleFile::Entry::Property;

sub value ($;$) {
  my $self = shift;
  if (@_) {
    $self->[0]->{$self->[1]} = shift;
  }
  return $self->[0]->{$self->[1]};
} # value

sub append_short_html ($$$$) {
  my ($self, $doc, $parent, $script_uri) = @_;
  $parent->append_child ($doc->create_text_node ($self->value));
} # append_short_html

sub append_long_html ($$$$) {
  my ($self, $doc, $parent, $script_uri) = @_;
  $self->append_short_html ($doc, $parent, $script_uri);
} # append_long_html

sub append_label_html ($$$) {
  my ($self, $doc, $parent, $script_uri) = @_;
  $parent->append_child ($doc->create_text_node ({
    date => '日時',
    id => '予定 #',
    title => '内容',
    description => '備考',
  }->{$self->[1]} or $self->[1]));
} # append_label_html

package ScheduleFile::Entry::Property::id;
push our @ISA, 'ScheduleFile::Entry::Property';

sub append_short_html ($$$) {
  my ($self, $doc, $parent, $script_uri) = @_;
  my $id = $self->value;
  for ($parent->append_child ($doc->create_element_ns ($html_ns, 'a'))) {
    $_->href ($script_uri . '/../item/' . $id);
    $_->text_content ($id);
  }
} # append_short_html

package ScheduleFile::Entry::Property::date;
push our @ISA, 'ScheduleFile::Entry::Property';

sub append_short_html ($$$) {
  my ($self, $doc, $parent, $script_uri) = @_;
  require DateLite;
  my $date = DateLite->parse_date ($self->value);
  $parent->append_child ($doc->create_text_node ($date->stringify_date . ' (' . $date->day_in_week_ja_short . ')'));
} # append_short_html

package ScheduleFile::Entry::Property::title;
push our @ISA, 'ScheduleFile::Entry::Property';

sub append_short_html ($$$) {
  my ($self, $doc, $parent, $script_uri) = @_;
  my $value = $self->value;
  my $id = $self->[0]->id;
  for ($parent->append_child ($doc->create_element_ns ($html_ns, 'a'))) {
    $_->href ($script_uri . '/../item/' . $id);
    $_->text_content ($value);
  }
} # append_short_html

1;
