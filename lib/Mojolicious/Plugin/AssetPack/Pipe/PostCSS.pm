
package Mojolicious::Plugin::AssetPack::Pipe::PostCSS;

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';
use Mojolicious::Plugin::AssetPack::Util qw( diag DEBUG );
use Mojo::Home;
use Data::Dumper;

has app => 'postcss';

has app_args => sub {
	my $self = shift;
	my $args = [];

	if ( my $cf = $self->config_file ) {
		push @{$args}, sprintf( '--config %s', $cf )
	}

	if ( defined( $ENV{'MOJO_MODE'} ) ) {
		push @{$args}, sprintf( '--env %s', $ENV{'MOJO_MODE'} );
	}
	else {
		push @{$args}, '--env development'; 
	}

	return $args;
};

has config_file => sub {
	my $self = shift;
	return Mojo::Home->new->rel_file('postcss.config.js');
};

sub process {
	my ( $self, $assets ) = @_;
	my $store = $self->assetpack->store;
	my $file;

	return $assets->each(
		sub {
			my ( $asset, $index ) = @_;
			return if $asset->format ne 'css';

			my $attrs = $asset->TO_JSON;
			$attrs->{'key'} = 'postcss';

			if ( my $cf = $self->config_file ) {
				my $cf_mtime = ( stat($cf) )[9];

				if ( my $file = $store->load($attrs) ) {
					if ( $cf_mtime < $file->mtime ) {
						return $asset->content($file);
					}
				}
			}
			else {
				if ( my $file = $store->load($attrs) ) {
					return $asset->content($file);
				}
			}

			diag 'Process "%s", with checksum %s.', $asset->url, $attrs->{'checksum'} if DEBUG;

			my $stdout;
			$self->run( [ $self->app => @{ $self->app_args } ], \$asset->content, \$stdout );

			$asset->content( $store->save( \$stdout, $attrs ) )->FROM_JSON($attrs);
		}
	);
} ## end sub process


sub _install_postcss {
	my $self  = shift;
	my $class = ref $self;
	die "$class requires https://github.com/postcss/postcss-cli";
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::PostCSS - Processed CSS files using
C<postcss>.

=head1 SYNOPSIS

  use Mojolicious::Lite;
  
  plugin AssetPack => {pipes => [qw(... PostCSS ...)]};

  app->asset->pipe("PostCSS")->app("/some/custom/path/to/postcss");
 
  # Set custom application arguments:
  app->asset->pipe("PostCSS")->app_args([ '-u autoprefixer', '--no-map' ]);

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Pipe::PostCSS> will process your CSS files
with the modular L<PostCSS|http://postcss.org/> transformation toolkit using
the L<postcss|https://github.com/postcss/postcss-cli> executeable.

=head1 ATTRIBUTES

=head2 app

  $str = $self->app;
  $self = $self->app("/some/custom/path/to/postcss");
 
Can be used to set a custom application (if, e.g., C<postcss> is not
found in your C<PATH>.

=head2 app_args

  $array = $self->app_args;
  $self = $self->app_args([ '$input', '-u autoprefixer', '--no-map' ]);
 
Can be used to set custom L</app> arguments.

By default, only two options will be set:

=over 4

=item C<--config>

Will be used to make PostCSS load L</config_file> (unless that option is
unset). You should probably modify that file to set any other options for
PostCSS translators.

=item C<--env>

Will be set to the same value as C<MOJO_MODE>.

=back

The C<env> option can then be used in the config file; e.g.:

  module.exports = (ctx) => ({
    plugins: {
      'cssnano': ctx.env === 'production' ? {} : false
    }
  )

Cf. L<https://github.com/postcss/postcss-cli#options> for a list of
available options and for a description of the config file.

Note that setting your own options will B<replace> the default options.

=head2 config_file

The PostCSS configuration file. Default is C<MOJO_HOME/postcss.config.js>.

=head1 METHODS
 
=head2 process
 
See L<Mojolicious::Plugin::AssetPack::Pipe/process>.
 
=head1 SEE ALSO
 
L<Mojolicious::Plugin::AssetPack>.
 
=cut

