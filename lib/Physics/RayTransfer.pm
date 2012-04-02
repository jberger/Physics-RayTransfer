=head1 NAME

Physics::RayTransfer - Object-oriented ray transfer analysis

=head1 SYNOPSIS

 use Physics::RayTransfer;

 my $sys = Physics::RayTransfer->new();
 $sys->add_mirror;
 $sys->add_space->parameter(sub{shift});
 $sys->add_mirror(8);

 my $d = [ map { $_ / 10 } (0..100) ];

 my @data = 
   map { $_->[1]->w(1063e-7) }
   $sys->evaluate_parameterized($d);

=head1 DESCRIPTION

This physics module is a helper for creating a system of ray transfer matrices (RTM) for analyzing optical systems. The most useful functionality is related to laser cavity stability analysis.

=head1 ClASSES

=head2 Physics::RayTransfer

This class provides the main simulation object, which houses the element objects and does the overall calculations.

=head3 METHODS

=over

=cut

use MooseX::Declare;
use Method::Signatures::Modifiers;

class Physics::RayTransfer {

  use Carp;
  use List::Util qw/reduce/;

=item new([%options])

Constructor. Can accept a hash of options, currently the only option key is C<elements> which takes an array reference of C<Physics::RayTransfer::Element> objects, ordered left-to-right.

=item elements()

Accessor for the array of elements which are currently a part of the system. These are implicitly ordered left-to-right.

=item add_element( Physics::RayTransfer::Element $object )

A helper method to push a manually constructed C<Physics::RayTransfer::Element> onto the C<elements> attribute.

=cut

  has 'elements' => (
    isa => 'ArrayRef[Physics::RayTransfer::Element]',
    is => 'rw', 
    default => sub{ [] },
    traits => ['Array'],
    handles => {
      add_element => 'push',
    },
  );

=item add_observer()

Shortcut method for adding a C<Physics::RayTransfer::Observer> object as the next element in the system (on the right side). Returns the object added.

=cut

  method add_observer () {
    my $obs = Physics::RayTransfer::Observer->new();
    $self->add_element( $obs );
    return $obs;
  }

=item add_space( [ Num $length ] )

Shortcut method for adding a C<Physics::RayTransfer::Space> object as the next element in the system (on the right side). Optionally takes a number representing the length of the object. Returns the object added.

=cut

  method add_space (Num $length?) {
    my $space = Physics::RayTransfer::Space->new( 
      (defined $length) ? ( length => $length ) : ()
    );
    $self->add_element($space);
    return $space;
  }

=item add_mirror( [ Num $radius ] )

Shortcut method for adding a C<Physics::RayTransfer::Mirror> object as the next element in the system (on the right side). Optionally takes a number representing the radius of curvature of the object's mirror. Returns the object added.

=cut

  method add_mirror (Num $radius?) {
    my $mirror = Physics::RayTransfer::Mirror->new(
      (defined $radius) ? ( radius => $radius ) : ()
    );
    $self->add_element($mirror);
    return $mirror;
  }

=item add_lens( [ Num $focal_length ] )

Shortcut method for adding a C<Physics::RayTransfer::Lens> object as the next element in the system (on the right side). Optionally takes a number representing the focal length of the object's lens. Returns the object added.

=cut

  method add_lens (Num $f?) {
    my $lens = Physics::RayTransfer::Lens->new(
      (defined $f) ? ( radius => $f ) : ()
    );
    $self->add_element($lens);
    return $lens;
  }

=item evaluate()

Returns a C<Physics::RayTransfer::Element> object which is equivalent to the system as a whole. See L</EVALUATION> for more.

=cut

  method evaluate (ArrayRef $vals?) {
    my $elements = $self->_construct;
    return reduce { $a->times($b) } map { $_->get } @$elements;
  }

=item evaluate_parameterized( ArrayRef $vals )

Takes an array reference of values for the parameterization functions. Returns 2D array (i.e. a list of array references). Foreach value an array reference is returned containg that value and a C<Physics::RayTransfer::Element> object which is equivalent to the system as a whole when that parameter is used for evaluation. See L</EVALUATION> for more.

=cut

  method evaluate_parameterized (ArrayRef $vals) {
    my $elements = $self->_construct;
    return map { 
      my $val = $_;
      my $new = 
        reduce { $a->times($b) } 
        map { $_->get($val) }
        @$elements;
      [ $val, $new ];
    } @$vals;
  }

  method _construct () {
    my @orig = @{ $self->elements };

    # see if system begins(left) and/or ends(right) with mirror
    my $left_mirror = shift @orig if $orig[0]->isa('Physics::RayTransfer::Mirror');
    my $right_mirror = pop @orig if $orig[-1]->isa('Physics::RayTransfer::Mirror');

    # see if an observer object exists
    my $has_observer = grep { $_->isa('Physics::RayTransfer::Observer') } @orig;

    croak "Cannot have more than one observer" if $has_observer > 1;

    # create an observer "at the end" for several cases
    unless ($has_observer) {
      my $obs = Physics::RayTransfer::Observer->new();
      if ( $right_mirror and not $left_mirror) {
        unshift @orig, $obs;
      } else {
        push @orig, $obs;
      }
    }


    # determine which elements are left or right of observer
    my (@left, @right);
    my $obs_seen = 0;

    foreach my $elem (@orig) {
      if ($elem->isa('Physics::RayTransfer::Observer')) {
        $obs_seen = 1;
        next;
      }
      
      if (! $obs_seen) {
        push @left, $elem;
      } else {
        push @right, $elem;
      }
    }

    # build elements array for evaluation
    my @elements;
    if ($left_mirror and $right_mirror) {
      #cavity begins and ends at observer
      push @elements, @right, $right_mirror, reverse(@right), reverse(@left), $left_mirror, @left;
    } else {
      push @elements, @left;
      if ($right_mirror) {
        push @elements, @right, $right_mirror, reverse(@right);
      }
    }

    return \@elements;
  }

}

=pod

=back

=head3 EVALUATION

The evaluation process is perhaps the important part of the simulation. It is at this point that the objects are converted into a series of matricies which are multiplied out to get the equivalent single matrix. This can either be done in a purely numerical way (C<evaluate>) or repeatedly for multiple values of some parameter (C<evaluate_parameterized>). 

The conversion to a series of matricies depends on the layout of your system. The most basic is just a linear array of optical elements. In such a system there are no end mirror objects. The input ray is assumed to originate on the left. If a C<Physics::RayTranser::Observer> object (henceforth called "an observer") is placed somewhere in the system, this is then seen as the endpoint. If no observer is placed one will be assumed on the right side.

A more complicated system having a C<Physics::RayTransfer::Mirror> object (henceforth called "a mirror") as the last element on the right will have its ray start on the left, traverse the system, reflect off the mirror and then return back through the system. An observer will stop the light I<only on the return trip>. If no observer has been placed, one will implicitly exist on the leftmost part of the system, meaning the light will travel from left to right and back to the starting point.

Finally if there are mirrors at both the left and right of the system, this triggers I<cavity> mode, most useful for laser cavity simulation. In cavity mode, light both starts and stops at the observer, making a complete round trip inside the cavity (passing the observer once). If no observer is placed, the observer is implicitly positioned just before the right mirror (assumed to be the output coupler).

=head2 Physics::RayTransfer::Element

=cut

class Physics::RayTransfer::Element {

  has 'a' => ( isa => 'Num', is => 'rw', default => 1 );
  has 'b' => ( isa => 'Num', is => 'rw', builder => '_build_b', lazy => 1 );
  has 'c' => ( isa => 'Num', is => 'rw', builder => '_build_c', lazy => 1 );
  has 'd' => ( isa => 'Num', is => 'rw', default => 1 );

  method _build_b () { 0 };
  method _build_c () { 0 };

  has 'parameter' => (
    isa => 'CodeRef',
    is => 'rw',
    predicate => 'has_parameter',
  );

  method get_parameterized (Num $val?) {
    return $self;
  }

  method get (Num $val?) {
    if (defined $val and $self->has_parameter) {
      my $param_val = $self->parameter->($val);
      return $self->get_parameterized($param_val);
    } else {
      return $self;
    }
  }

  method w (Num $lambda) {
    my $stability = $self->stability($lambda);
    return undef if abs($stability) >= 1;

    return sqrt( 
      abs($self->b) * $lambda / (4*atan2(1,1))
      * sqrt(
        1 / ( 1 - $stability ** 2 )
      )
    );
  }

  method stability (Num $lambda) {
    my $stability = ($self->a + $self->d) / 2;
    return $stability;
  }

  method times (Physics::RayTransfer::Element $right) {
    my $a = $self->a * $right->a + $self->b * $right->c;
    my $b = $self->a * $right->b + $self->b * $right->d;
    my $c = $self->c * $right->a + $self->d * $right->c;
    my $d = $self->c * $right->b + $self->d * $right->d;

    return Physics::RayTransfer::Element->new(
      a => $a, b => $b, c => $c, d => $d,
    );
  }

  method as_arrayref () {
    return [$self->a, $self->b, $self->c, $self->d];
  }
}

=head2 Physics::RayTransfer::Observer

=cut

class Physics::RayTransfer::Observer
  extends Physics::RayTransfer::Element {

}

=head2 Physics::RayTransfer::Space

=cut

class Physics::RayTransfer::Space
  extends Physics::RayTransfer::Element {

  has 'length' => (isa => 'Num', is => 'rw', default => 0);

  override _build_b () {
    return $self->length;
  }

  override get_parameterized (Num $length) {
    return __PACKAGE__->new( b => $length );
  }
}

=head2 Physics::RayTransfer::Mirror

=cut

class Physics::RayTransfer::Mirror
  extends Physics::RayTransfer::Element {

  has 'radius' => (isa => 'Num', is => 'rw', predicate => 'has_radius');

  method _radius_to_c () {
    my $c_term;

    if ($self->has_radius) {
      $c_term = - 2 / $self->radius;
    } else {
      $c_term = 0;
    }

    return $c_term;
  }

  override _build_c () {
    my $c = $self->_radius_to_c;
    return $c;
  }

  override get_parameterized (Num $c) {
    return __PACKAGE__->new( c => $c );
  }
}

=head2 Physics::RayTransfer::Lens

=cut

class Physics::RayTransfer::Lens
  extends Physics::RayTransfer::Element {

  has 'f' => (isa => 'Num', is => 'rw', predicate => 'has_f');

  method _f_to_c () {
    my $c_term;

    if ($self->has_f) {
      $c_term = - 1 / $self->f;
    } else {
      $c_term = 0;
    }

    return $c_term;
  }

  override _build_c () {
    my $c = $self->_f_to_c;
    return $c;
  }

  override get_parameterized (Num $c) {
    return __PACKAGE__->new( c => $c );
  }
}

=head1 SEE ALSO

=over

=item *

=back

=head1 SOURCE REPOSITORY

L<http://github.com/jberger/Physics-RayTransfer>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.



