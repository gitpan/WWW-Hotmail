package WWW::Hotmail;

use Carp;
use base 'WWW::Mechanize';
use 5.006;
use strict;
use warnings;

our $VERSION = '0.04';

sub new {
    my $class = shift;
	# avoid complaints from M$ by using IE 6.0
    my $self = $class->SUPER::new(agent => 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)');
    $self->cookie_jar({});
	return $self;
}

sub login {
	my ($self,$email,$pass) = @_;
    Carp::croak 'must supply full email address as username'
		unless ($email =~ m/\@([^.]+)\.(.+)/);
	my $domain = lc("$1_$2");
	my $resp = $self->get("http://www.hotmail.com/");
    $resp->is_success || Carp::croak $resp->error_as_HTML;
	# bypass the js detection page
	if ($self->{content} =~ m/hiddenform/i) {
		$self->form_name('hiddenform');
		$self->submit();
	}
    $self->form_name('form1');
	# this SHOULD cover charter.com, compaq.net, hotmail.com, msn.com, passport.com, and webtv.net
	if ($self->{content} =~ m#name="$domain" action="([^"]+)"#) {
		# current_form returns a HTML::Form obj
		$self->current_form()->action($1);
	} else {
		die 'hotmail format changed or email domain not used with Hotmail';
	}
    $self->field(login => $email);
    $self->field(passwd => $pass);
    $resp = $self->click("submit1"); # finally!
    $resp->is_success || Carp::croak $resp->error_as_HTML;
    $self->{content} =~ /URL=(.+)"/ or die "Hotmail format changed!";
    $self->get($1);
	
	# look for the base url for the mailbox
	if ($self->{content} =~ m/_UM = "([^"]+)";/) {
		$self->{_WWWHotmail_base} = $1;
	} else {
	   	Carp::croak "Couldn't log in to Hotmail";
	}	
	
	my $last_page = 1;
	my $i = 1;
	# traverse all pages
    while ($i <= $last_page) {
		# sorting avoids getting the same message twice
		$self->get("/cgi-bin/HoTMaiL?".$self->{_WWWHotmail_base}."&page=$i&Sort=rDate");
		# this finds the ->| link (last page)
		if ($i == 1 && $self->{content} =~ m/'page=(\d+)'/i) {
			$last_page = $1;
		}
		# replace javascript junk
		# and adapt it to grab 'from' AND 'subjects'
		# TODO this can be done better
		my $content = $self->content();
		$content =~ s/\r|\n|&nbsp;//g;
		$content =~ s/javascript\:G\('([^']+)'\)">([^<]+)<\/a><\/td><td>([^<]+)<\/td>/$1">$2|$3<\/a>/gi;
		$self->update_html($content);
		push(@{$self->{_WWWHotmail_msgs}},map { my $x = WWW::Hotmail::Message->new;
                                       $x->{_WWW_Hotmail_msg} = $_; 
                                       $x->{_WWW_Hotmail_parent} = $self;
                                       $x }
                                grep { $_->url() =~ /getmsg/ }
                                @{$self->links});
		$i++;
	}
}

sub messages {
    my $self = shift;
    Carp::croak "Not logged in!" unless $self->{_WWWHotmail_msgs};
    return @{$self->{_WWWHotmail_msgs}};
}

package WWW::Hotmail::Message;
@WWW::Hotmail::Message::ISA = qw(WWW::Hotmail);

use Mail::Audit;

# TODO this can also be done better
sub from { (split(/\|/,$_[0]->{_WWW_Hotmail_msg}->text()))[0] }

sub subject { (split(/\|/,$_[0]->{_WWW_Hotmail_msg}->text()))[1] }

sub _link { $_[0]->{_WWW_Hotmail_msg} }

sub retrieve {
    my $self = shift;
    my $resp = $self->{_WWW_Hotmail_parent}->get(
                       $self->_link()->url()."&raw=0"
               );
    $resp->is_success || Carp::croak $resp->error_as_HTML;
	
	# fix Hotmail's conversions
	my $content = $self->{_WWW_Hotmail_parent}->content();
	$content =~ s/&lt;/</gi;
	$content =~ s/&gt;/>/gi;
	$content =~ s/&quot;/"/gi;
	$content =~ s/&amp;/&/gi;

	# clip the top and bottom
	my @mail = split(/\n/,$content);
    shift @mail;
	pop @mail until $mail[-1] =~ m|</pre>|;
	pop @mail;
	# repair line endings
	@mail = map { $_."\n" } @mail;
    my $msg = Mail::Audit->new(data => \@mail);
	# set this option for them
	$msg->noexit(1);
	return $msg;
}

sub delete {
    my $self = shift;
    my $resp = $self->{_WWW_Hotmail_parent}->get($self->_link()->url());
    $resp->is_success || Carp::croak $resp->error_as_HTML;
    for (@{$self->{_WWW_Hotmail_parent}->links()}) {
        if ($_->[1] && $_->[1] eq "Delete") { 
            $self->{_WWW_Hotmail_parent}->get($_->url());
            last;
       }
    }
}

1;
__END__

=head1 NAME

WWW::Hotmail - Connect to Hotmail and download messages

=head1 SYNOPSIS

  use WWW::Hotmail;
  my $hotmail = new WWW::Hotmail;
  $hotmail->login('foo@hotmail.com', "bar");
  for ($hotmail->messages) { $_->retrieve->accept; $_->delete; }

=head1 DESCRIPTION

This module is a partial replacement for the C<gotmail> script
(http://ssl.usu.edu/paul/gotmail/), so if this doesn't do what you want,
try that instead.

Create a new C<WWW::Hotmail> object with C<new>, and then log in with
your MSN username and password. Make sure to add the domain to your
username, for example foo@hotmail.com.  Then this will allow you to use
the C<messages> method to look at the mail in your inbox.

This method returns a list of C<WWW::Hotmail::Message>s; each message
supports four methods: C<subject> gives you the subject of the email,
just because it was stunningly easy to implement. C<retrieve> retrieves
an email into a C<Mail::Audit> object - see L<Mail::Audit> for more
details. C<from> gives you the from field. Finally C<delete> moves it
to your trash.

This module should work with email addresses at charter.com, compaq.net,
hotmail.com, msn.com, passport.com, and webtv.net

That's it. I said it was partial.

=head1 SEE ALSO

L<WWW::Mechanize>, L<Mail::Audit>, C<gotmail>

=head1 NOTE

This module is reasonable fragile. It seems to work, but I haven't
tested edge cases. If it breaks, you get to keep both pieces. I hope
to improve it in the future, but this is enough for release.

=head1 AUTHOR

David Davis, E<lt>xantus@cpan.orgE<gt>
- I've taken ownership of this module, please direct all questions to me.

=head1 ORIGINAL AUTHOR

Simon Cozens, E<lt>simon@kasei.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003-2004 by Kasei

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
