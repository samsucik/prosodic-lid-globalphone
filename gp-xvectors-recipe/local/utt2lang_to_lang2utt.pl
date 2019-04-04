#!/usr/bin/env perl

# Adapted from utils/utt2spk_to_spk2utt.pl by Paul Moore
# Copyright 2019 Paul Moore
# 
# Apache 2.0

# The same as the utt2spk_to_spk2utt.pl script, just changed name for clarity
# converts an utt2lang file to a spk2lang file.
# Takes input from the stdin or from a file argument;
# output goes to the standard out.

if ( @ARGV > 1 ) {
    die "Usage: utt2lang_to_spklang.pl [ utt2lang ] > lang2utt";
}

while(<>){
    @A = split(" ", $_);
    @A == 2 || die "Invalid line in utt2lang file: $_";
    ($u,$s) = @A;
    if(!$seen_spk{$s}) {
        $seen_spk{$s} = 1;
        push @spklist, $s;
    }
    push (@{$spk_hash{$s}}, "$u");
}
foreach $s (@spklist) {
    $l = join(' ',@{$spk_hash{$s}});
    print "$s $l\n";
}
