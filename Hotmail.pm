package WWW::Hotmail;
use Carp;
use base 'WWW::Mechanize';
use 5.006;
use strict;
use warnings;

our $VERSION = '0.01';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new();
    $self->cookie_jar({});
    return $self;
}

sub login {
    my $self = shift;
    my $resp = $self->get("http://www.hotmail.com/");
    $resp->is_success || croak $resp->error_as_HTML;
    $self->form(1);
    $self->field(login    => shift);
    $self->field(passwd   => shift);
    $resp = $self->click("enter");
    $resp->is_success || croak $resp->error_as_HTML;
    $self->{content} =~ /URL=(.+js=no)/ or die "Hotmail format changed!";
    $self->get($1);
    croak "Couldn't log in " unless $self->{forms}[1];
    $self->form(2);
    $self->click;
    $self->{_WWWHotmail_msgs} = [ map { my $x = WWW::Hotmail::Message->new;
                                       $x->{_WWW_Hotmail_msg} = $_; 
                                       $x->{_WWW_Hotmail_parent} = $self;
                                       $x }
                                grep { $_->[0] =~ /getmsg/ }
                                @{$self->extract_links} ];
}

sub messages {
    my $self = shift;
    croak "Not logged in!" unless $self->{_WWWHotmail_msgs};
    return @{$self->{_WWWHotmail_msgs}};
}

package WWW::Hotmail::Message;
@WWW::Hotmail::Message::ISA = qw(WWW::Hotmail);

use Mail::Audit;

sub subject { $_[0]->{_WWW_Hotmail_msg}[1] }

sub retrieve {
    my $self = shift;
    my $resp = $self->{_WWW_Hotmail_parent}->get(
                       $self->{_WWW_Hotmail_msg}[0]."&raw=0"
               );
    $resp->is_success || croak $resp->error_as_HTML;
    my @mail = split /\n/,
    $self->{_WWW_Hotmail_parent}->{content};
    shift @mail; pop @mail until $mail[-1] =~ m|</pre>|; pop @mail;
    return Mail::Audit->new(data => \@mail);
}


sub delete {
    my $self = shift;
    my $resp = $self->{_WWW_Hotmail_parent}->get($self->{_WWW_Hotmail_msg}[0]);
    $resp->is_success || croak $resp->error_as_HTML;
    for (@{$self->{_WWW_Hotmail_parent}->extract_links()}) {
        if ($_->[1] eq "Delete") { 
            $self->{_WWW_Hotmail_parent}->get($_->[0]);
            last;
        }
    }
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

WWW::Hotmail - Connect to Hotmail and download messages

=head1 SYNOPSIS

  use WWW::Hotmail;
  my $browser = new WWW::Hotmail;
  $browser->login("foo", "bar");
  for ($browser->messages) { $_->retrieve->accept; $_->delete; }

=head1 DESCRIPTION

This module is a partial replacement for the C<gotmail> script
(http://ssl.usu.edu/paul/gotmail/), so if this doesn't do what you want,
try that instead.

Create a new C<WWW::Hotmail> object with C<new>, and then log in with
your Hotmail username and password. This will allow you to use the
C<messages> method to look at the mail in your inbox.

This method returns a list of C<WWW::Hotmail::Message>s; each message
supports three methods: C<subject> gives you the subject of the email,
just because it was stunningly easy to implement. C<retrieve> turns the
email into a C<Mail::Audit> object - see L<Mail::Audit> for more
details. Finally C<delete> moves it to your trash.

That's it. I said it was partial.

=head1 SEE ALSO

L<WWW::Mechanize>, L<Mail::Audit>, C<gotmail>

=head1 NOTE

This module is reasonable fragile. It seems to work, but I haven't
tested edge cases. If it breaks, you get to keep both pieces. I hope
to improve it in the future, but this is enough for release.

=head1 AUTHOR

Simon Cozens, E<lt>simon@kasei.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Kasei

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
