package DBIx::XML_RDB;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(); # Not exporting anything - this is OO.

$VERSION = '0.01';

use DBI;
use MIME::Base64;

sub new {
	my $this = shift;
	my $class = ref($this) || $this;
	my $self = {};
	bless $self, $class;
	$self->Initialise(@_) || return undef;
	return $self;
}

sub Initialise {
	my $self = shift;
	$self->{datasource} = shift;
	my $driver = shift;
	my $userid = shift;
	my $password = shift;
	my $dbname = shift;

	$self->{dbh} = DBI->connect("dbi:$driver:". $self->{datasource}, $userid, $password);
	if (!$self->{dbh}) {
		print STDERR "Connection failed\n";
		return 0;
	}

	if ($dbname) {
		if(!$self->{dbh}->do("use $dbname")) {
			print STDERR "USE $dbname failed\n";
			return 0;
		}
	}

	$self->{output} = "<?xml version=\"1.0\"?>\n";
	$self->{output} .= "<". $self->{datasource} . ">\n";

	return 1;
}

sub DESTROY {
	my $self = shift;
	$self->{dbh}->disconnect;
}

sub DoSql {
	my $self = shift;
	my $sql = shift;
	$self->{sth} = $self->{dbh}->prepare($sql) || die $self->{dbh}->errstr;
	$self->{sth}->execute || die $self->{sth}->errstr;
	$self->_CreateOutput;
	$self->{sth}->finish;
}

sub _CreateOutput {
	my $self = shift;

	my $fields = $self->{sth}->{NAME};

	# Now insert the actual data.

	$self->{output} .= "\t<RESULTSET statement=\"". $self->{sth}->{Statement} ."\">\n";

	my $row = 0;
	my @data;
	while (@data = $self->{sth}->fetchrow_array) {
		my $i = 0;
		$self->{output} .= "\t\t<ROW>\n";
		foreach my $f (@data) {
			if (defined $f) {
				my $encoding;
				if ($f !~ /^[\t\n\r\x20-\x7e]*$/) {
					# If this contains characters outside the UTF-8 range,
					# then encode it in base64
					$f = MIME::Base64::encode($f);
					$encoding = ' xml:packed="base64"';
				}
				else {
					$f =~ s/&/&amp;/g;
					$f =~ s/</&lt;/g;
					$f =~ s/>/&gt;/g;
					$f =~ s/'/&apos;/g;
					$f =~ s/"/&quot;/g;
				}
				$self->{output} .= "\t\t\t<" . $fields->[$i] . $encoding . '>' .$f . '</' . $fields->[$i] . ">\n";
			}
			$i++;
		}
		$self->{output} .= "\t\t</ROW>\n";
	}
	$self->{output} .= "\t</RESULTSET>\n";
}

sub GetData {
	my $self = shift;
	my $output = $self->{output} . "</". $self->{datasource} . ">\n";

	# Return output to starting state, in case we want to do more...
	$self->{output} = "<?xml version=\"1.0\"?>\n";
	$self->{output} .= "<". $self->{datasource} . ">\n";

	return $output;
}

1;
__END__

=head1 NAME

DBI::XML - Perl extension for creating XML from existing DBI datasources

=head1 SYNOPSIS

  use DBI::XML;
  my $xmlout = DBI::XML->new($datasource,
  		"ODBC", $userid, $password, $dbname) || die "Failed to make new xmlout";
  $xmlout->DoSql("select * from MyTable");
  print $xmlout->GetData;

=head1 DESCRIPTION

This module is a simple creator of XML data from DBI datasources. It allows you to
easily extract data from a database, and manipulate later using XML::Parser.

One use of this module might be (and will be soon from me) to extract data on the
web server, and send the raw data (in XML format) to a client's browser, and then
use either XML::Parser from PerlScript, or MSXML from VBScript/JavaScript on the
client's machine to generate HTML (obviously this relies upon using MS IE for their
Active Scripting Engine, and MSXML comes with IE5beta).

Another use is a simple database extraction tool, which is included, called sql2xml.
This tool simply dumps a table in a database to an XML file. This can be used in
conjunction with xml2sql (part of the XML::DBI(?) package) to transfer databases
from one platform or database server to another.

Binary data is encoded using MIME::Base64. This module has a dependency on that package,
as well as (obviously) on the DBI package.

Included with the distribution is a "Scriptlet" - this is basically a Win32 OLE
wrapper around this class, allowing you to call this module from any application
that supports OLE. To install it, first install the scriptlets download from
microsoft at http://msdn.microsoft.com/scripting. Then right-click on XMLDB.sct
in explorer and select "Register". Create your object as an instance of
"XMLDB.Scriptlet".

=head1 FUNCTIONS

=head2 new

	new ( $datasource, $dbidriver, $userid, $password [, $dbname] )

See the DBI documentation for what each of these means, except for $dbname which
is for support of Sybase and MSSQL server database names (using "use $dbname").

=head2 DoSql

	DoSql ( $sql )

Takes a simple Sql command string (either a select statement or on some DBMS's can be
a stored procedure call that returns a result set - Sybase and MSSql support this,
I don't know about others).

This doesn't do any checking if the sql is valid, if it fails, the procedure will "die",
so if you care about that, wrap it in an eval{} block.

The result set will be appended to the output. Subsequent calls to DoSql don't overwrite
the output, rather they append to it. This allows you to call DoSql multiple times before
getting the output (via GetData()).

=head2 GetData

Simply returns the XML generated from this SQL call. Unfortunately it doesn't stream out
as yet. I may add this in sometime in the future (this will probably mean an IO handle
being passed to new()).

The format of the XML output is something like this:

	<?xml version="1.0"?>
	<DataSource>
		<RESULTSET statement="select * from Table">
			<ROW>
			<Col1Name>Data</Col1Name>
			<Col2Name>Data</Col2Name>
			...
			</ROW>
			<ROW>
			...
			</ROW>
		</RESULTSET>
		<RESULTSET statement="select * from OtherTable">
		...
		</RESULTSET>
	</DataSource>

This is quite easy to parse using XML::Parser. Note that any data outside of normal
characters and numbers is converted to MIME::Base64 encoded data. You are responsible
for decoding it at the other end (see the MIME::Base64 module to do this).

=head1 AUTHOR

Matt Sergeant, msergeant@ndirect.co.uk (ISP) or sergeant@geocities.com (more permanent,
but slower response times).

=head1 SEE ALSO

perl(1).
XML::DBI.

=cut
