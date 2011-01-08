package HTMLDOMLite;
use strict;

my $html_ns = q<http://www.w3.org/1999/xhtml>;
my $atom_ns = q<http://www.w3.org/2005/Atom>;
my $xml_ns => q<http://www.w3.org/XML/1998/namespace>;
my $xmlns_ns => q<http://www.w3.org/2000/xmlns/>;

sub get_feature ($$;$) {
  return shift;
} # get_feature

sub create_document ($) {
  return HTMLDOMLite::Document->new;
} # create_document

sub create_document_type ($$) {
  my (undef, $name) = @_;
  return HTMLDOMLite::DocumentType->new (name => $name);
} # create_document_type

sub dl_create_html_document ($$) {
  my ($self, $title) = @_;
  my $doc = $self->create_document;
  $doc->append_child ($self->create_document_type ('html'));
  for ($doc->append_child ($doc->create_element_ns ($html_ns, 'html'))) {
    $_->append_child ($doc->create_element_ns ($html_ns, 'head'))
        ->append_child ($doc->create_element_ns ($html_ns, 'title'))
        ->text_content ($title);
    $_->append_child ($doc->create_element_ns ($html_ns, 'body'));
  }
  return $doc;
} # dl_create_html_document

sub create_atom_feed_document ($$) {
  my ($self, $feed_tag) = @_;
  my $doc = $self->create_document;
  for ($doc->append_child ($doc->create_element_ns ($atom_ns, 'feed'))) {
    $_->append_child ($doc->create_element_ns ($atom_ns, 'id'))
        ->text_content ($feed_tag);
  }
  return $doc;
} # create_atom_feed_document

package HTMLDOMLite::DOMImplementationRegistry;

$Message::DOM::ImplementationRegistry
    ||= $Message::DOM::DOMImplementationRegistry
    ||= 'HTMLDOMLite::DOMImplementationRegistry';

sub get_dom_implementation ($%) {
  return 'HTMLDOMLite';
} # get_dom_implementation

sub get_dom_implementation_list ($%) {
  return ['HTMLDOMLite'];
} # get_dom_implementation_list

package HTMLDOMLite::Node;

sub new ($%) {
  my $class = shift;
  my $self = bless {child_nodes => [], @_}, $class;
  return $self;
} # new

sub ELEMENT_NODE () { 1 }
sub ATTRIBUTE_NODE () { 2 }
sub TEXT_NODE () { 3 }
sub DOCUMENT_NODE () { 9 }
sub DOCUMENT_TYPE_NODE () { 10 }
sub DOCUMENT_FRAGMENT_NODE () { 11 }

sub child_nodes ($) {
  return shift->{child_nodes};
} # child_nodes

sub dl_get_child_elements_by_tag_name_ns ($$$) {
  my ($self, $nsuri, $lname) = @_;
  my $r = [];
  for (@{$self->{child_nodes}}) {
    push @$r, $_
        if $_->node_type eq HTMLDOMLite::Node::ELEMENT_NODE and $_->namespace_uri eq $nsuri and $_->local_name eq $lname;
  }
  return $r;
} # dl_get_child_elements_by_tag_name_ns

sub append_child ($$) {
  my ($self, $new_child) = @_;
  push @{$self->{child_nodes}}, $new_child;
  return $new_child;
} # append_child

package HTMLDOMLite::Document;
push our @ISA, 'HTMLDOMLite::Node';

sub node_type ($) {
  HTMLDOMLite::Node::DOCUMENT_NODE;
} # node_type

sub create_element_ns ($$$) {
  my ($self, $nsuri, $ln) = @_;
  return HTMLDOMLite::Element->new
      (namespace_uri => $nsuri, local_name => $ln, attributes => {});
} # create_element_ns

sub create_text_node ($$) {
  my ($self, $s) = @_;
  return HTMLDOMLite::Text->new (data => $s);
} # create_text_node

sub dl_outer_html ($) {
  return shift->dl_inner_html;
} # dl_outer_html

sub dl_inner_html ($) {
  my $self = shift;
  my $r = '';
  for (@{$self->{child_nodes}}) {
    $r .= $_->dl_outer_html;
  }
  return $r;
} # dl_inner_html

sub document_element ($) {
  my $self = shift;
  for (@{$self->child_nodes}) {
    return $_ if $_->node_type == HTMLDOMLite::Node::ELEMENT_NODE;
  }
  return undef;
} # document_element

sub dom_config ($) {
  my $self = shift;
  $self->{dom_config} ||= bless {}, 'HTMLDOMLite::DOMConfiguration';
  return $self->{dom_config};
} # dom_config

sub strict_error_checking ($;$) {
  my $self = shift;
  $self->{strict_error_checking} = shift if @_;
  return $self->{strict_error_checking};
} # strict_error_checking

sub body ($) {
  my $self = shift;
  my $root = $self->document_element;
  return undef unless $root;
  return $root->dl_get_child_elements_by_tag_name_ns ($html_ns, 'body')->[0];
} # body

package HTMLDOMLite::DOMConfiguration;

sub get_parameter ($$) {
  my ($self, $cpname) = @_;
  return $self->{lc $cpname};
} # get_parameter

sub set_parameter ($$$) {
  my ($self, $cpname, $value) = @_;
  $self->{lc $cpname} = $value;
} # set_parameter

package HTMLDOMLite::Element;
push our @ISA, 'HTMLDOMLite::Node';

sub node_type ($) {
  HTMLDOMLite::Node::ELEMENT_NODE;
} # node_type

sub text_content ($;$) {
  my $self = shift;
  if (@_) {
    if (length $_[0]) {
      my $text = HTMLDOMLite::Text->new (data => $_[0]);
      @{$self->{child_nodes}} = ($text);
    } else {
      @{$self->{child_nodes}} = ();
    }
  }
  if (defined wantarray) {
    my $r = '';
    for (@{$self->{child_nodes}}) {
      $r .= $_->text_content;
    }
    return $r;
  }
} # text_content

sub local_name ($) {
  return shift->{local_name};
} # local_name

sub namespace_uri ($) {
  return shift->{namespace_uri};
} # namespace_uri

sub dl_inner_html ($) {
  my $self = shift;
  my $r = '';
  for my $node (@{$self->{child_nodes}}) {
    if ($node->node_type == HTMLDOMLite::Node::TEXT_NODE) {
      my $v = $node->text_content;
      $v =~ s/&/&amp;/g;
      $v =~ s/</&lt;/g;
      $v =~ s/>/&gt;/g;
      $v =~ s/"/&quot;/g;
      $r .= $v;
    } else {
      $r .= $node->dl_outer_html;
    }
  }
  return $r;
} # dl_inner_html

sub dl_outer_html ($) {
  my $self = shift;
  my $local_name = $self->{local_name};
  my $r = '<' . $local_name;
  for my $nsuri (sort {$a cmp $b} keys %{$self->{attributes}}) {
    for my $ln (sort {$a cmp $b} keys %{$self->{attributes}->{$nsuri}}) {
      my $attr = $self->{attributes}->{$nsuri}->{$ln};
      my $v = $attr->{value};
      $v =~ s/&/&amp;/g;
      $v =~ s/</&lt;/g;
      $v =~ s/>/&gt;/g;
      $v =~ s/"/&quot;/g;
      $r .= ' ';
      $r .= $attr->{prefix} . ':' if length $nsuri;
      $r .= $ln . '="';
      $r .= $v;
      $r .= '"';
    }
  }
  $r .= '>';
  if ($local_name eq 'style' or $local_name eq 'script') {
    $r .= $self->text_content . '</' . $local_name . '>';
  } elsif (not {
    base => 1, img => 1, input => 1, embed => 1, meta => 1, link => 1,
  }->{$local_name}) {
    $r .= $self->dl_inner_html;
    $r .= '</' . $local_name . '>';
  }
  return $r;
} # dl_outer_html

sub get_attribute_ns ($$$) {
  my ($self, $nsuri, $ln) = @_;
  my $attr = $self->{attributes}->{$nsuri}->{$ln};
  if ($attr) {
    return $attr->{value};
  } else {
    return undef;
  }
} # get_attribute_ns

sub set_attribute_ns ($$$$) {
  my ($self, $nsuri, $qn, $value) = @_;
  my ($pfx, $ln) = split /:/, $qn, 2;
  ($pfx, $ln) = (undef, $pfx) unless defined $ln;
  $self->{attributes}->{$nsuri}->{$ln} = {value => $value, prefix => $pfx};
} # set_attribute_ns

sub AUTOLOAD {
  my $self = shift;
  our $AUTOLOAD;
  $AUTOLOAD =~ /([^:]+)$/;
  my $attr_name = $1;
  my $attr_info = { # nsuri, qname, lname, default
    $html_ns => {
      a => {
        href => [undef, 'href', 'href', undef],
      },
      th => {
        scope => [undef, 'scope', 'scope', undef],
      },
    },
    $atom_ns => {
      link => {
        #rel => [undef, 'rel', 'rel', undef], ## TODO: 
        href => [undef, 'href', 'href', undef],
        hreflang => [undef, 'hreflang', 'hreflang', undef],
        type => [undef, 'type', 'type', undef],
      },
      content => {
        type => [undef, 'type', 'type', undef],
      },
    },
  }->{$self->{namespace_uri}}->{$self->{local_name}}->{$attr_name} || {
    $html_ns => {
      title => [undef, 'title', 'title', undef],
    },
  }->{$self->{namespace_uri}}->{$attr_name};
  ## TODO: atom:feed -> title_element 
  ## atom:author->name, ->uri, ->email
  ## entry published_element title_element content_element  published_el,ement
  ## content container
  if ($attr_info) {
    if (@_) {
      $self->set_attribute_ns ($attr_info->[0], $attr_info->[1], $_[0]);
    }
    if (defined wantarray) {
      my $v = $self->get_attribute_ns ($attr_info->[0], $attr_info->[2]);
      return defined $v ? $v : $attr_info->[3];
    }
  } else {
    die "Can't locate method $AUTOLOAD";
  }
} # AUTOLOAD

package HTMLDOMLite::Text;
push our @ISA, 'HTMLDOMLite::Node';

sub node_type ($) {
  HTMLDOMLite::Node::TEXT_NODE;
} # node_type

sub text_content ($;$) {
  my $self = shift;
  $self->{data} = shift if @_;
  return $self->{data};
} # text_content

package HTMLDOMLite::DocumentType;
push our @ISA, 'HTMLDOMLite::Node';

sub node_type ($) {
  HTMLDOMLite::Node::DOCUMENT_TYPE_NODE;
} # node_type

sub dl_outer_html ($) {
  my $self = shift;
  return '<!DOCTYPE ' . $self->{name} . ">\n";
} # dl_outer_html

1;
