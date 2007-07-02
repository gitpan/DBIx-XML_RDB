package DBIx::XML_RDB;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %XMLCHARS $REXMLCHARS);

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(); # Not exporting anything - this is OO.

$VERSION = '0.06';

use DBI;

sub new {
	my $this = shift;
	my $class = ref($this) || $this;
	my $self = {};
	bless $self, $class;
	$self->Initialise(@_) || return undef;
	return $self;
}

%XMLCHARS = (
        '&' => '&amp;',
        '<' => '&lt;',
        '>' => '&gt;',
        '"' => '&quot;',
        );

sub xmlenc {
    my $str = shift;
    $str =~ s/([&<>"])/$XMLCHARS{$1}/ge; #"
    return $str;
}

sub Initialise {
	my $self = shift;
	$self->{datasource} = shift;
	my $driver = shift;
	my $userid = shift;
	my $password = shift;
	my $dbname = shift;
	$self->{verbose} = shift;

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
	
  # too early
	#ver 0.05# $self->{output} .= "<DBI driver=\"". xmlenc($self->{datasource}) . "\">\n";

	# init default values
	$self->document_tagname(''); 
	$self->resultset_tagname('');
	$self->row_tagname('');
	$self->document_nameattr('');
	$self->resultset_nameattr('');
	$self->row_nameattr('');

	return 1;
}

sub DESTROY {
	my $self = shift;
	$self->{dbh}->disconnect;
}

sub DoSql {
	my $self = shift;
	my $sql = shift;

  unless( $self->{output} ) {
  	$self->{output} = "<?xml version=\"1.0\"?>\n";
  	$self->{output} .= "<".$self->document_tagname().$self->document_nameattr()." driver=\"". xmlenc($self->{datasource}) . "\">\n";
  }
	
	$self->{sth} = $self->{dbh}->prepare($sql) || die $self->{dbh}->errstr;
	$self->{sth}->execute || die $self->{sth}->errstr;
	$self->_CreateOutput();
	$self->{sth}->finish;
}

sub _CreateOutput {
	my $self = shift;

	my $fields = $self->{sth}->{NAME};
	
	# Now insert the actual data.

	#ver 0.05# $self->{output} .= "\t<RESULTSET statement=\"". xmlenc($self->{sth}->{Statement}) ."\">\n";
	$self->{output} .= "\t<".$self->resultset_tagname().$self->resultset_nameattr()." statement=\"". xmlenc($self->{sth}->{Statement}) ."\">\n";

	my $row = 0;
	my @data;
	while (@data = $self->{sth}->fetchrow_array) {
		print STDERR "Row: ", $row++, "\n" if $self->{verbose};
		my $i = 0;
		#ver 0.05# $self->{output} .= "\t\t<ROW>\n";
		$self->{output} .= "\t\t<".$self->row_tagname().$self->row_nameattr().">\n";
		foreach my $f (@data) {
			if (defined $f) {
				$self->{output} .= "\t\t\t<" . $fields->[$i] . '>' . xmlenc($f) . '</' . $fields->[$i] . ">\n";
			}
			$i++;
		}
		#ver 0.05# $self->{output} .= "\t\t</ROW>\n";
		$self->{output} .= "\t\t</".$self->row_tagname().">\n";
	}
	$self->{output} .= "\t</".$self->resultset_tagname().">\n";
}

sub GetData {
	my $self = shift;
	#ver 0.05# my $output = $self->{output} . "</DBI>\n";
	my $output = $self->{output} . "</".$self->document_tagname().">\n";

	# Return output to starting state, in case we want to do more...
	$self->{output} = "<?xml version=\"1.0\"?>\n";
	#ver 0.05# $self->{output} .= "<DBI driver=\"" . xmlenc($self->{datasource}) . "\">\n";
	$self->{output} .= "<".$self->document_tagname().$self->document_nameattr()." driver=\"" . xmlenc($self->{datasource}) . "\">\n";

	return $output;
}

sub document_tagname { 
  my $attr = 'document_tagname';
  my $self = shift;
  my $name = shift;
  my $val;
  if
  ( defined $name ) {
    $val = length($name) ? $name : 'DBI';
  }
  return $self->_naming_param($attr,$val);
}

sub resultset_tagname { 
  my $attr = 'resultset_tagname';
  my $self = shift;
  my $name = shift;
  my $val;
  if
  ( defined $name ) {
    $val = length($name) ? $name : 'RESULTSET';
  }
  return $self->_naming_param($attr,$val);
}

sub row_tagname { 
  my $attr = 'row_tagname';
  my $self = shift;
  my $name = shift;
  my $val;
  if
  ( defined $name ) {
    $val = length($name) ? $name : 'ROW';
  }
  return $self->_naming_param($attr,$val);
}

sub document_nameattr { 
  my $attr = 'document_nameattr';
  my $self = shift;
  my $name = shift;
  my $val;
  if
  ( defined $name ) {
    $val = length($name) ? (' name="'.xmlenc($name).'"') : '';
  }
  return $self->_naming_param($attr,$val);
}

sub resultset_nameattr { 
  my $attr = 'resultset_nameattr';
  my $self = shift;
  my $name = shift;
  my $val;
  if
  ( defined $name ) {
    $val = length($name) ? (' name="'.xmlenc($name).'"') : '';
  }
  return $self->_naming_param($attr,$val);
}

sub row_nameattr { 
  my $attr = 'row_nameattr';
  my $self = shift;
  my $name = shift;
  my $val;
  if
  ( defined $name ) {
    $val = length($name) ? (' name="'.xmlenc($name).'"') : '';
  }
  return $self->_naming_param($attr,$val);
}

sub _naming_param {
  my $self = shift;
  my $attr = shift;
  my $val  = shift;
  
  if
  ( defined $val ) {
    $self->{$attr} = $val;
    return $val
  }
  elsif
  ( exists $self->{$attr} ) {
    return  $self->{$attr}
  }
  
  return undef;
}

1;
__END__

=head1 NAME

DBIx::XML_RDB - Perl extension for creating XML from existing DBI datasources

=head1 SYNOPSIS

  use DBIx::XML_RDB;
  my $xmlout = DBIx::XML_RDB->new($datasource,
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

Binary data is encoded using UTF-8. This is automatically decoded when parsing
with XML::Parser.

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
	<DBI driver="dbi:Sybase:database=foo">
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
	</DBI>

This is quite easy to parse using XML::Parser.

=head2 document_tagname

  document_tagname ( [ $tagname ] )
  
Get/Set tagname of the main xml document, defaults to 'DBI'.
With $value=undef returns the tagname.
With $value='' sets the default 'DBI'

=head2 resultset_tagname

  resultset_tagname ( [ $tagname ] )
  
Default value: 'RESULTSET'
  
See document_tagname
  
=head2 row_tagname

  row_tagname ( [ $tagname ] )
  
Default value: 'ROW'

See document_tagname
  
=head2 document_nameattr

  document_nameattr ( [ $value ] )
  
Get/Set value of the 'name' attribute of main xml document. 
With $value=undef returns the whole attribute definition, example: name="my_name".
With $value='' sets the return value to default ''.

=head2 resultset_nameattr

  resultset_nameattr ( [ $nameattr ] )
  
See document_nameattr
  
=head2 row_nameattr

  row_nameattr ( [ $nameattr ] )
  
See document_nameattr
  

=head1 AUTHOR

Matt Sergeant, matt@sergeant.org

Daniel Peder, Daniel.Peder@infoset.cz ( the tagname and nameattr )

=head1 SEE ALSO

XML::Parser

=cut
