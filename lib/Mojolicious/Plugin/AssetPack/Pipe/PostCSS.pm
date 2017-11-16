
package Mojolicious::Plugin::AssetPack::Pipe::PostCSS;

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';
use Mojolicious::Plugin::AssetPack::Util qw( checksum diag DEBUG );
use Mojo::File qw(path);

has exe => 'postcss';

has exe_args => sub {
	my $pipe = shift;
	my $args = [];

	if ( my $cf = $pipe->config_file ) {
		push @{$args}, ( '--config', $cf );
	}

	push @{$args}, ( '--env', $pipe->app->mode );

	return $args;
};

has config_file => sub {
	my $pipe = shift;
	if ( $pipe->assetpack->store->asset('postcss.config.js') ) {
		return $pipe->assetpack->store->asset('postcss.config.js')->path;
	}
	return '';
};

sub process {
	my ( $pipe, $assets ) = @_;
	my $store = $pipe->assetpack->store;
	my $file;

	return $assets->each(
		sub {
			my ( $asset, $index ) = @_;
			return if $asset->format ne 'css';

			my $cfg_checksum = checksum( path( $pipe->config_file )->slurp );

			my $attrs = $asset->TO_JSON;
			$attrs->{'checksum'} = checksum( $attrs->{'checksum'} . $cfg_checksum );
			$attrs->{'key'} = 'postcss';

			if ( $file = $store->load($attrs) ) {
				return $asset->content($file)->FROM_JSON($attrs);
			}

			diag 'Process "%s", with checksum %s.', $asset->url, $attrs->{'checksum'} if DEBUG;

			my $stdout = '';
			my $input = $asset->content;
			$pipe->run( [ $pipe->exe => @{ $pipe->exe_args } ], \$input, \$stdout );
			return $asset->content( $store->save( \$stdout, $attrs ) )->FROM_JSON($attrs);
		}
	);
} ## end sub process


sub _install_postcss {
	my $self  = shift;
	my $class = ref $self;
	die "$class requires https://github.com/postcss/postcss-cli (maybe run 'npm i postcss-cli'?)";
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::PostCSS - Processed CSS files using
C<postcss>.

=head1 SYNOPSIS

  use Mojolicious::Lite;

  plugin AssetPack => {pipes => [qw(... PostCSS ...)]};

  # Override default if necessary
  app->asset->pipe("PostCSS")->exe("/some/custom/path/to/postcss");

  # Set custom application arguments if necessary
  # Usually, customisation should be done by modifying the postcss.config.js
  app->asset->pipe("PostCSS")->exe_args([ '-u autoprefixer', '--no-map' ]);

  # Have assets/postcss.config.js available with a config like this:
  # module.exports = (ctx) => ({
  #   'map': false,
  #   'use': ['autoprefixer', 'cssnano'],
  #   'plugins': {
  #     'autoprefixer': {},
  #     'cssnano': ctx.env === 'production' ? {} : false
  #   }
  # })

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Pipe::PostCSS> will process your CSS files
with the modular L<PostCSS|http://postcss.org/> transformation toolkit using
the L<postcss|https://github.com/postcss/postcss-cli> executeable.

B<NOTE:> Currently it is not possible to track modifications to the PostCSS
config file or take these into account as triggers for reprocessing the CSS
files. If you modify your config please delete all CSS files from the cache
(usually located at C<MOJO_HOME/assets/cache>).

=head1 ATTRIBUTES

=head2 exe

  $str = $pipe->exe;
  $pipe = $pipe->exe("/some/custom/path/to/postcss");

Can be used to set a custom executable (if, e.g., C<postcss> is not
found in your C<PATH>.

=head2 exe_args

  $array = $pipe->exe_args;
  $pipe = $pipe->exe_args([ '$input', '-u autoprefixer', '--no-map' ]);

Can be used to set custom L</exe> arguments.

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

The PostCSS configuration file. Default is C<MOJO_HOME/assets/postcss.config.js>.

=head1 METHODS

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
