package CGILite;
use strict;
use Encode;
use Encode::Guess qw/euc-jp shiftjis 7bit-jis/;

sub new ($) {
  my ($class) = @_;
  my $self = bless {env => \%main::ENV, in => \*main::STDIN, out => \*main::STDOUT}, $class;
  binmode $self->{in};
  binmode $self->{out};
  return $self;
} # new

sub meta_variable ($$) {
  my ($self, $varname) = @_;
  return $self->{env}->{$varname};
} # meta_variable

sub path_info ($) {
  my $self = shift;
  my $pi = $self->meta_variable ('PATH_INFO');
  $pi = undef if defined $pi and not length $pi;
  if (wantarray) {
    return () unless defined $pi;
    return map {_percent_decode_unreserved ($_)} split m#/#, $pi;
  } else {
    return $pi;
  }
}

sub response_file ($) {
  return shift->{out};
} # response_file

sub script_uri ($) {
  my $self = shift;
  my $r = 'http://'; # BUG: no HTTPS support
  $r .= $self->meta_variable ('SERVER_NAME');
  $r .= ':' . $self->meta_variable ('SERVER_PORT');
  my $v = $self->meta_variable ('SCRIPT_NAME'); # BUG: SCRIPT_NAME MUST be percent-encoded
  $v =~ s/\.cgi$//;
  $r .= $v;
  return $r;
} # script_absolute_path

sub USE_ENTITY_BODY_PARAMETER { 0 }

sub entity_body_parameters ($) {
  my $self = shift;
  unless ($self->{entity_body_parameters}) {
    my $ct = $self->meta_variable ('CONTENT_TYPE');
    my $entity_body_ref = $self->entity_body_ref;
    my $charset = '';
    if ($ct eq 'application/x-www-form-urlencoded') {
      #
    } elsif ($ct =~ m#^\s*application/x-www-form-urlencoded\s*;\s*charset\s*=\s*"?utf-8"?\s*$#) {
      $charset = 'utf-8';
    } else {
      $entity_body_ref = \ '';
    }
    
    my %params;
    for (split /[;&]/, $$entity_body_ref) {
      my ($name, $val) = split /=/, $_, 2;
      for ($name, $val) {
        tr/+/ /;
        s/%([0-9A-Fa-f][0-9A-Fa-f])/pack 'C', hex $1/ge;
      }
      $params{$name} ||= [];
      push @{$params{$name}}, $val;
      if ($name eq '_charset_') {
        $val =~ s/\s//g;
        $charset ||= $val;
      }
    }
    $charset ||= 'guess';
    for (keys %params) {
      my $name = Encode::decode ($charset, $_);
      for (@{$params{$_}}) {
        push @{$self->{entity_body_parameters}->{$name} ||= []}, 
            Encode::decode ($charset, $_);
      }
    }
  }
  return $self->{entity_body_parameters};
} # entity_body_parameters

sub entity_body_ref ($) {
  my $self = shift;
  unless (defined $self->{body}) {
    my $body;
    read $self->{in}, $body, $self->meta_variable ('CONTENT_LENGTH');
    $self->{body} = \$body;
  }
  return $self->{body};
} # entity_body_ref

sub process_request ($) {
  my $self = shift;

  if ($self->USE_ENTITY_BODY_PARAMETER) {
    my $ct = lc $self->meta_variable ('CONTENT_TYPE');
    if (not defined $ct or $ct eq '') {
      #
    } elsif ($ct eq 'application/x-www-form-urlencoded' or
        $ct =~ m#^\s*application/x-www-form-urlencoded\s*;\s*charset\s*=\s*"?utf-8"?\s*$#) {
      ## TODO: Unsupported charset error (406)
    } else {
      $self->on_entity_body_not_accepted;
      return;
    }
  }
  
  my $method = $self->meta_variable ('REQUEST_METHOD');
  if (($method eq 'GET' or $method eq 'HEAD') and $self->can ('on_get')) {
    $self->on_get;
  } elsif ($method eq 'POST' and $self->can ('on_post')) {
    $self->on_post;
  } elsif ($method eq 'PUT' and $self->can ('on_put')) {
    $self->on_put;
  } elsif ($method eq 'DELETE' and $self->can ('on_delete')) {
    $self->on_delete;
  } else {
    $self->on_method_not_allowed;
  }
} # process_request

sub on_method_not_allowed ($) {
  my $self = shift;
  my $out = $self->{out};
  print $out "Status: 405 Method Not Allowed\n";
  print $out "Content-Type: text/plain; charset=iso-8859-1\n";
  print $out "\n";
  print $out 'Method |' . $self->meta_variable ('REQUEST_METHOD') . '| is not allowed.';
} # on_method_not_allowed

sub on_entity_body_not_accepted ($) {
  my $self = shift;
  my $out = $self->{out};
  print $out "Status: 406 Entity-Body Content-Type Not Accepted\n";
  print $out "Content-Type: text/plain; charset=iso-8859-1\n";
  print $out "\n";
  print $out 'Content-Type |' . $self->meta_variable ('CONTENT_TYPE') . '| is not allowed.';
} # on_entity_body_not_accepted

sub on_resource_not_found ($) {
  my $self = shift;
  my $out = $self->{out};
  print $out "Status: 404 Resource Not Found\n";
  print $out "Content-Type: text/plain; charset=iso-8859-1\n";
  print $out "\n";
  print $out 'Requested resource is not found.';
} # on_resource_not_found

sub _percent_decode_unreserved ($) {
  my $s = shift; # [0-9A-Za-z_~.-] as per RFC 3986
  $s =~ s/%(2[DdEe]|3[0-9]|[46][1-9A-Fa-f]|5[0-9AaFf]|7[0-9AaEe])/chr hex $1/ge;
  return $s;
} # _percent_decode_unreserved

1;
