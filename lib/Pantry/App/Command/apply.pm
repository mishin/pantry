use v5.14;
use warnings;

package Pantry::App::Command::apply;
# ABSTRACT: Implements pantry apply subcommand
# VERSION

use Pantry::App -command;
use autodie;
use JSON;

use namespace::clean;

sub abstract {
  return 'Apply recipes or attributes to a node or role'
}

sub command_type {
  return 'TARGET';
}

sub options {
  my ($self) = @_;
  return ($self->data_options, $self->selector_options);
}

my %setters = (
  node => {
    default => 'set_attribute',
    override => undef,
  },
  role => {
    default => 'set_default_attribute',
    override => 'set_override_attribute',
  },
  environment => {
    default => 'set_default_attribute',
    override => 'set_override_attribute',
  },
  bag => {
    default => 'set_attribute',
    override => undef,
  },
);

sub valid_types {
  return keys %setters;
}

for my $t ( keys %setters ) {
  no strict 'refs';
  *{"_apply_$t"} = sub {
    my ($self, $opt, $name) = @_;
    $self->_apply_obj($opt, $t, $name);
  };
}

sub _apply_obj {
  my ($self, $opt, $type, $name) = @_;

  my $options;
  $options->{env} = $opt->{env} if $opt->{env};
  my $obj = $self->_check_name($type, $name, $options);

  if ( $type eq 'node' ) {
    $self->_apply_runlist($obj, $opt)
  }
  elsif ( $type eq 'role' ) {
    if ( $options->{env} ) {
      $self->_apply_env_runlist($obj, $opt)
    }
    else {
      $self->_apply_runlist($obj, $opt)
    }
  }
  else {
    # nothing else has run lists
  }

  for my $k ( sort keys %{$setters{$type}} ) {
    if ( my $method = $setters{$type}{$k} ) {
      $self->_set_attributes($obj, $opt, $k, $method);
    }
    elsif ( $opt->{$k} ) {
      $k = ucfirst $k;
      warn "$k attributes do not apply to $type objects.  Skipping them.\n";
    }
  }

  $obj->save;
  return;
}

sub _apply_runlist {
  my ($self, $obj, $opt) = @_;
  if ($opt->{role}) {
    $obj->append_to_run_list(map { "role[$_]" } @{$opt->{role}});
  }
  if ($opt->{recipe}) {
    $obj->append_to_run_list(map { "recipe[$_]" } @{$opt->{recipe}});
  }
  return;
}

sub _apply_env_runlist {
  my ($self, $obj, $opt) = @_;
  if ($opt->{role}) {
    $obj->append_to_env_run_list($opt->{env}, [map { "role[$_]" } @{$opt->{role}}]);
  }
  if ($opt->{recipe}) {
    $obj->append_to_env_run_list($opt->{env}, [map { "recipe[$_]" } @{$opt->{recipe}}]);
  }
  return;
}

sub _set_attributes {
  my ($self, $obj, $opt, $which, $method) = @_;
  if ($opt->{$which}) {
    for my $attr ( @{ $opt->{$which} } ) {
      my ($key, $value) = split /=/, $attr, 2; # split on first '='
      if ( $value =~ /(?<!\\),/ ) {
        # split on unescaped commas, then unescape escaped commas
        $value = [ map { $self->_boolify($_) } map { s/\\,/,/gr } split /(?<!\\),/, $value ];
      }
      else {
        $value = $self->_boolify($value);
      }
      $obj->$method($key, $value);
    }
  }
  return;
}

sub _boolify {
  my ($self, $value) = @_;
  if ($value eq 'false') {
    $value = JSON::false;
  }
  elsif ( $value eq 'true' ) {
    $value = JSON::true;
  }
  return $value;
}

1;

=for Pod::Coverage options validate

=head1 SYNOPSIS

  $ pantry apply node foo.example.com --recipe nginx --default nginx.port=8080

=head1 DESCRIPTION

This class implements the C<pantry apply> command, which is used to apply recipes or attributes
to a node.

=cut

# vim: ts=2 sts=2 sw=2 et:
