#!/usr/bin/env perl6
use v6;
use File::Temp;

class Text::VimColour:ver<0.5> {
    subset File of Str:D where -> $x { $x.IO.e }
    subset Path of Str:D where -> $x { $x.IO.parent.d }
    has Path  $!out;
    has File  $!in;
    has Str   $!lang;

    proto method BUILD(|z) {
        my $version = .[0] given split /','/, q:x/vim --version/ //'';
        fail "didn't find a recent vim, found $version" if $version !~~ /' Vi IMproved '7\.4 || 8\. /;
        {*}
        $!lang //= 'c';
        my $vim-let = $*VIM-LET || '';

        %*ENV<EXRC>='set directory=/tmp';
        my $cmd = qq«
            vim -E -s -c 'let g:html_no_progress=1|syntax on|set noswapfile|set bg=light|set ft=$!lang|{$vim-let}|runtime syntax/2html.vim|wq! $!out|quit' -cqa $!in 2>/dev/null >/dev/null
        »;
        my $proc = shell $cmd;
        fail "failed to run '$cmd', exit code {$proc.exitcode}" if $proc.exitcode != 0;
    }

    multi method BUILD(Str :$!lang, File :$!in,  Path :$!out) {};

    multi method BUILD(Str :$!lang, File :$!in) {
        $!out = _tempfile;
    }

    multi method BUILD(Str :$!lang, Str :$code where $code.chars > 0) {
        $!in  = _tempfile;
        $!in.IO.spurt: $code;
        $!out = _tempfile;
    }

    method html-full-page( --> Str)  {
        return $!out.IO.slurp;
    }

    method html( --> Str)  {
        self.html-full-page ~~  m/  '<body' .*? '>'  (.*) '</body>' / ;
        return ~$0;
    }

    method css( --> Str) {
        #`< should match:
            <style type="text/css"'>   ... </style>
            OR
            <style>
            <!--
            ...
            -->
            </style>
        >
        my $extract_style = rx/'<style' \s* ['type="text/css"']? \s* '>' \s* ['<!--']? \s*  (.*?) \s*    ['-->']? \s* '</style>'/;
        return self.html-full-page ~~  $extract_style ?? ~$0 !! '';
    }

    sub _tempfile( --> Str) {
        my ($name, $handle) = tempfile;
        close $handle;
        return $name;
    }
}
