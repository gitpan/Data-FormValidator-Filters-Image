package Data::FormValidator::Filters::Image;

use strict;

use File::Basename;
use Image::Magick;
use MIME::Types;

=pod

=head1 NAME

Data::FormValidator::Filters::Image - Filter that allows you to shrink incoming image uploads using Data::FormValidator

=head1 SYNOPSIS

    use Data::FormValidator::Filters::Image qw( image_filter );

    # Build a Data::FormValidator Profile:
    my $my_profile = {
        required => qw( uploaded_image ),
        field_filters => {
            uploaded_image => image_filter(max_width => 800, max_height => 600),
        },
    };

    # Be sure to use a CGI.pm object as the form input
    # when using this filter
    my $q = new CGI;
    my $dfv = Data::FormValidator->check($q,$my_profile);

=head1 DESCRIPTION

Many users when uploading image files never bother to shrink them down to a reasonable size.
Instead of declining the upload because it is too large, this module will shrink the image
down to a reasonable size during the form validation stage.

The filter will try to fail gracefully by leaving the upload as is if the image resize
operation fails.

=cut

use vars qw( $VERSION @ISA @EXPORT @EXPORT_OK );

BEGIN {
    require Exporter;

    $VERSION = 0.10;

    @ISA = qw( Exporter );

    @EXPORT    = ();
    @EXPORT_OK = qw( image_filter );
}

=pod

=head1 FILTERS


=head2 image_filter( max_width => $width, max_height => $height )

This will create a filter that will reduce the size of an image that is
being uploaded so that it is bounded by the width and height provided.
The image will be scaled in a way that will not distort or stretch
the image.

 example:

 - upload an image that is 800 x 600
 - specify a max width of 100 and max height of 100

 The resulting image will be 100 x 75, since that is the
 largest scaled image we can create that is still within
 the bounds we specified.

=cut

sub image_filter {
    my %options    = @_;
    my $max_width  = delete $options{max_width};
    my $max_height = delete $options{max_height};

    return
      sub { return __shrink_image( shift, $max_width, $max_height, %options ) };
}

sub __shrink_image {
    my $fh         = shift;
    my $max_width  = shift;
    my $max_height = shift;
    my @the_rest   = @_;
    my $result;

    return $fh unless $fh && ref $fh eq 'Fh';
    my $filename = $fh->asString;
    binmode $fh;

    my $image;
    eval {
        $image = Image::Magick->new;
        $result = $image->Read( file => $fh );
    };
    if ($@) {
        #warn "Uploaded file was not an image";
        seek( $fh, 0, 0 );
        return $fh;
    }
    if ("$result") {
        #warn "$result";
        seek( $fh, 0, 0 );
        return $fh;
    }

    my ( $nw, $nh ) = my ( $ow, $oh ) = $image->Get( 'width', 'height' );

    unless ( $ow && $oh ) {
        #warn "Image has no width or height";
        seek( $fh, 0, 0 );
        return $fh;
    }

    if ( $max_width && $nw > $max_width ) {
        $nw = $max_width;
        $nh = $oh * ( $max_width / $ow );
    }
    if ( $max_height && $nh > $max_height ) {
        $nh = $max_height;
        $nw = $ow * ( $max_height / $oh );
    }

    $result = $image->Resize( width => $nw, height => $nh, @the_rest );
    if ("$result") {
        #warn "$result";
        seek( $fh, 0, 0 );
        return $fh;
    }

    #########################
    # Create a file handle object to simpulate a CGI.pm upload
    #  Pulled directly from CGI.pm by Lincoln Stein
    my $tmp_filename;
    my $seqno = unpack( "%16C*", join( '', localtime, values %ENV ) );
    $seqno += int rand(100);
    my $newfh;
    for ( my $cnt = 10 ; $cnt > 0 ; $cnt-- ) {
        next unless my $tmpfile = new CGITempFile($seqno);
        $tmp_filename = $tmpfile->as_string;
        last
          if defined( $newfh = Fh->new( $filename, $tmp_filename, 0 ) );
        $seqno += int rand(100);
    }
    die "CGI open of tmpfile: $!\n" unless defined $newfh;
    $CGI::DefaultClass->binmode($newfh)
      if $CGI::needs_binmode
      && defined fileno($newfh);
    #########################

    $image->Write( file => $newfh, filename => $filename );
    if ("$result") {
        #warn "$result";
        seek( $fh, 0, 0 );
        return $fh;
    }

    # rewind both filehandles before we return
    seek( $newfh, 0, 0 );
    seek( $fh,    0, 0 );
    return $newfh;
}

1;

__END__

=pod

=head1 SEE ALSO

Data::FormValidator

=head1 AUTHOR

Cees Hek <ceeshek@gmail.com>

=head1 COPYRIGHT

Copyright (c) 2005 SiteSuite Corporation - http://sitesuite.com.au/
All rights reserved.

This library is free software. You can modify and or distribute it under the same terms as Perl itself.

=cut
