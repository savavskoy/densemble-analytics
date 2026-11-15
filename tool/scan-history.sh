#!/usr/bin/env bash
# Scans the working tree and the whole git history for things that must never be published:
#   (a) every term of a local denylist file (env DENYLIST, one term per line, case-insensitive,
#       '#' starts a comment). The terms themselves are never printed.
#   (b) secrets: private keys, AWS / GitHub / Slack / Google / Telegram-style tokens, JWTs,
#       passwords written into URLs (password=... or user:password@host).
#   (c) private IPv4 addresses (10/8, 172.16/12, 192.168/16, 100.64/10, 169.254/16, loopback 127/8
#       outside "127.0.0.1") and absolute home-directory paths of a person.
#
# It prints only WHERE a finding is (kind, file:line, and the commit for history), never WHAT matched,
# so its output is safe to paste into a log. Exit status: 0 clean, 1 findings, 2 usage error.
#
#   DENYLIST=/path/to/private-terms.txt tool/scan-history.sh
#   ALLOW_NO_DENYLIST=1 tool/scan-history.sh          # secrets and addresses only (what CI does)
#   tool/scan-history.sh --tree-only [directory]
#
# When the folder is not a git repository yet, only the tree is scanned. The file LICENSE is allowed
# to contain denylisted terms (it names the copyright owner by design), and only for the denylist
# check: secret and address checks still apply to it.
# Requires bash and perl (both present on macOS and on GitHub's Ubuntu runners). Reads git, never writes.
set -u

TREE_ONLY=0
ROOT=""
for arg in "$@"; do
  case "$arg" in
    --tree-only) TREE_ONLY=1 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unknown option: $arg" >&2; exit 2 ;;
    *) ROOT="$arg" ;;
  esac
done
if [ -z "$ROOT" ]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
[ -d "$ROOT" ] || { echo "not a directory: $ROOT" >&2; exit 2; }
command -v perl >/dev/null 2>&1 || { echo "perl is required" >&2; exit 2; }

DENYLIST_FILE="${DENYLIST:-}"
if [ -n "$DENYLIST_FILE" ]; then
  [ -r "$DENYLIST_FILE" ] || { echo "DENYLIST is set but the file is not readable" >&2; exit 2; }
elif [ "${ALLOW_NO_DENYLIST:-}" != "1" ]; then
  echo "DENYLIST is not set. Point it at your local list of private terms, or set ALLOW_NO_DENYLIST=1 to scan for secrets and addresses only." >&2
  exit 2
else
  echo "note: no denylist given, project-name check skipped" >&2
fi

read -r -d '' PERL_PROGRAM <<'PERL'
use strict;
use warnings;

my ($mode, $denylist_path) = @ARGV;
my @terms;
if (defined $denylist_path && length $denylist_path) {
  open(my $fh, '<', $denylist_path) or die "cannot read denylist\n";
  while (my $t = <$fh>) {
    $t =~ s/\r?\n$//;
    $t =~ s/^\s+|\s+$//g;
    next if $t eq '' || $t =~ /^#/;
    push @terms, lc $t;
  }
  close $fh;
}

# kind => regex. Each describes a class of problem; the matched text is never printed.
my @patterns = (
  ['secret:private-key',   qr/-----BEGIN (?:[A-Z]+ )*PRIVATE KEY-----/],
  ['secret:aws-key',       qr/\b(?:AKIA|ASIA)[0-9A-Z]{16}\b/],
  ['secret:github-token',  qr/\bgh[pousr]_[A-Za-z0-9]{30,}\b|\bgithub_pat_[A-Za-z0-9_]{20,}\b/],
  ['secret:slack-token',   qr/\bxox[abprs]-[A-Za-z0-9-]{10,}/],
  ['secret:google-key',    qr/\bAIza[0-9A-Za-z_-]{35}\b/],
  ['secret:telegram-token',qr/\b[0-9]{8,10}:[A-Za-z0-9_-]{35}\b/],
  ['secret:jwt',           qr/\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/],
  ['secret:url-password-param', qr{://[^\s'"<>]*[?&;](?:password|passwd|pwd)=[^&\s'"<>]+}i],
  ['address:private-ipv4', qr/(?<![\d.])(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}|100\.(?:6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.\d{1,3}\.\d{1,3}|169\.254\.\d{1,3}\.\d{1,3}|127\.(?!0\.0\.1(?![\d]))\d{1,3}\.\d{1,3}\.\d{1,3})(?![\d])/],
  ['path:home-directory',  qr{(?<![A-Za-z0-9_.-])/(?:Users|home)/[^\s/'"`:]+}],
);

# user:password@host in a URL, unless the password is an obvious placeholder
my $userinfo = qr{://([^\s/:@'"<>]+):([^\s/@'"<>]+)@};
my $placeholder = qr/^(?:pass|password|passwd|pw|p|y|secret|analytics|changeme|xxx+|\*+|\.\.\.|example|test|user|<.*>|\$.*|\{.*\}|%.*|[A-Za-z_]*_pw|CHANGE_ME.*|your[-_].*|replace[-_].*)$/i;

sub scan_line {
  my ($line) = @_;
  my @kinds;
  if (@terms) {
    my $l = lc $line;
    for my $t (@terms) {
      if (index($l, $t) >= 0) { push @kinds, 'denylist'; last; }
    }
  }
  for my $p (@patterns) {
    push @kinds, $p->[0] if $line =~ $p->[1];
  }
  while ($line =~ /$userinfo/g) {
    my $pw = $2;
    push @kinds, 'secret:url-userinfo-password' unless $pw =~ $placeholder;
  }
  return @kinds;
}

my %seen;
my $count = 0;
sub report {
  my ($kind, $where) = @_;
  my $key = "$kind $where";
  return if $seen{$key}++;
  $count++;
  print "$kind  $where\n";
}

sub is_license { my ($path) = @_; return $path =~ m{(?:^|/)LICENSE$}; }

if ($mode eq 'tree') {
  local $/ = "\0";
  while (my $file = <STDIN>) {
    chomp $file;
    $file =~ s{^\./}{};
    next unless -f $file && -r $file;
    open(my $fh, '<:raw', $file) or next;
    local $/ = "\n";
    my $n = 0;
    while (my $line = <$fh>) {
      $n++;
      last if $n == 1 && index($line, "\0") >= 0;    # binary file
      for my $k (scan_line($line)) {
        next if $k eq 'denylist' && is_license($file);
        report($k, "$file:$n");
      }
    }
    close $fh;
    # file names count too
    for my $k (scan_line($file)) {
      next if $k ne 'denylist';
      report('denylist', "$file (file name)") unless is_license($file);
    }
  }
}
else {
  # git log -p --all: commit header and message, then diffs. Only added lines (and messages) are scanned,
  # since everything that ever sat in history was added by some commit.
  my ($commit, $path, $newline, $in_diff) = ('', '', 0, 0);
  while (my $line = <STDIN>) {
    $line =~ s/\r?\n$//;
    if ($line =~ /^commit ([0-9a-f]{7,40})/) {
      ($commit, $path, $newline, $in_diff) = (substr($1, 0, 10), '', 0, 0);
      next;
    }
    if ($line =~ m{^diff --git a/(.*) b/(.*)$}) {
      $in_diff = 1;
      $path = $2;
      for my $k (scan_line($path)) { report($k, "$commit:$path (file name)") if $k eq 'denylist' && !is_license($path); }
      next;
    }
    if (!$in_diff) {
      next unless $line =~ /^    /;                       # commit message lines
      for my $k (scan_line($line)) { report($k, "$commit:commit-message"); }
      next;
    }
    if ($line =~ /^@@ -\d+(?:,\d+)? \+(\d+)/) { $newline = $1 - 1; next; }
    next if $line =~ /^(?:index |--- |\+\+\+ |new file|deleted file|old mode|new mode|similarity|rename |Binary files)/;
    if ($line =~ /^\+/) {
      $newline++;
      for my $k (scan_line(substr($line, 1))) {
        next if $k eq 'denylist' && is_license($path);
        report($k, "$commit:$path:$newline");
      }
    }
    elsif ($line =~ /^ /) { $newline++; }
  }
}
print STDERR "$count finding(s)\n";
exit($count == 0 ? 0 : 1);
PERL

cd "$ROOT" || exit 2
status=0
IS_GIT=0
if [ "$TREE_ONLY" -eq 0 ] && git rev-parse --git-dir >/dev/null 2>&1 && git rev-parse --verify -q HEAD >/dev/null 2>&1; then
  IS_GIT=1
fi

echo "== working tree: $ROOT"
if git rev-parse --git-dir >/dev/null 2>&1; then
  # tracked and untracked files that are not ignored: exactly what a `git add .` would publish
  git ls-files -z --cached --others --exclude-standard
else
  find . \( -name .git -o -name node_modules -o -name dist -o -name build -o -name .dart_tool -o -name coverage -o -name .DS_Store \) -prune -o -type f -print0
fi | perl -e "$PERL_PROGRAM" -- tree "$DENYLIST_FILE" || status=1

if [ "$IS_GIT" -eq 1 ]; then
  echo "== git history (all branches and tags)"
  git log -p --all --no-color --no-ext-diff --reverse 2>/dev/null \
    | perl -e "$PERL_PROGRAM" -- history "$DENYLIST_FILE" || status=1
elif [ "$TREE_ONLY" -eq 0 ]; then
  echo "== git history: skipped (not a git repository with commits yet)"
fi

if [ "$status" -eq 0 ]; then
  echo "clean"
else
  echo "FINDINGS above: fix them (and rewrite history if the finding is in a commit) before publishing" >&2
fi
exit "$status"
