package DateLite;
use utf8;
use Time::Local qw/timegm/;

sub new ($$) {
  my ($class, $unixtime) = @_;
  my $self = bless \$unixtime, $class;
  return $self;
} # new

sub parse_date ($$) {
  my ($class, $date) = @_;
  my $unixtime = 0;
  if ($date =~ /^(\d+)-(\d+)-(\d+)$/) {
    $unixtime = timegm (0, 0, 0, $3, $2-1, $1);
  }
  return $class->new ($unixtime);
} # parse_date

sub stringify_date ($) {
  my $self = shift;
  my @time = gmtime $$self;
  return sprintf '%04d-%02d-%02d',
      $time[5] + 1900, $time[4] + 1, $time[3];
} # stringify_date

sub stringify_rfc3339_datetime ($) {
  my $self = shift;
  my @time = gmtime $$self;
  return sprintf '%04d-%02d-%02dT%02d:%02d:%02dZ',
      $time[5] + 1900, $time[4] + 1, $time[3], $time[2], $time[1], $time[0];
} # stringify_rfc3339_datetime

sub day_in_week ($) {
  my $self = shift;
  return (gmtime $$self)[6];
} # day_in_week

sub day_in_week_ja_short ($) {
  my $self = shift;
  return [qw/日 月 火 水 木 金 土/]->[$self->day_in_week];
} # day_in_week_ja_short

1;
