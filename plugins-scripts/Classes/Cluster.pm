package Classes::Cluster;
our @ISA = qw(Classes::Device);
use strict;

sub classify {
  my $self = shift;
  if ($self->opts->mode =~ /cluster.*ndbd.*/) {
    $self->set_variable('product', 'NDB');
    bless $self, 'Classes::Cluster::NDB';
  }
}

