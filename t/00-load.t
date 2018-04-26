#!perl -T
# vim:syntax=perl:tabstop=4:number:noexpandtab:

use Test::More tests => 1;

BEGIN {
	use_ok('Mojolicious::Plugin::AssetPack::Pipe::PostCSS') || print "Bail out!";
}

diag( "Testing Mojolicious::Plugin::AssetPack::Pipe::PostCSS  $Mojolicious::Plugin::AssetPack::Pipe::PostCSS::VERSION, Perl $], $^X" );
