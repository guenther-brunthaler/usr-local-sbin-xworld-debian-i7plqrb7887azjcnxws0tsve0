#! /bin/sh
# Create script $script_name which downloads and checksum-verifies a list of
# updates read from standard input in the same format as output by "apt-get
# upgrade --print-uris -qq".
#
# The downloads in the script will be sorted such that smaller one will be
# downloaded first.
script_name=dls.sh

set -e
trap 'test $? = 0 || echo "$0 failed!" >& 2' 0
{
	cat << 'EOF'
#! /bin/sh
set -e

dl() {
	wget -c -q -O "$f" "$1${2+"$f"}"
}

compare_cs() {
	local s
	s=`$1 -b -- "$f" | cut -c -$2`
	if test x"$s" != x"$3"
	then
		echo "File '$f' has bad checksum!" >& 2
		false || exit
	fi
}

md5() {
	compare_cs md5sum 32 "$1"
}

sha256() {
	compare_cs sha256sum 64 "$1"
}

EOF
	while IFS= read -r u
	do
		eval "set -- $u"
		printf '%s\n' "$3:$u"
	done \
	| LC_COLLATE=C LC_NUMERIC=C sort -t : -nk 1,1 \
	| while IFS= read -r u
	do
		u=${u#*:}
		r=${u##*"'"}; u=${u%"'$r"}; u=${u#"'"}; r=${r#" "}
		eval "set -- $r"
		f=$1; s=$2; m=$3
		echo "f='$f'"
		if test x"${u%"$f"}" != x"$u"
		then
			echo "dl '${u%"$f"}' +"
		else
			echo "dl '$u'"
		fi
		if s=${m#MD5Sum:} && test x"$s" != x"$m"
		then
			echo "md5 $s"
		elif s=${m#SHA256:} && test x"$s" != x"$m"
		then
			echo "sha256 $s"
		else
			echo "Unsupported checksum type: $m" >& 2
			false || exit
		fi
	done
} | tee "$script_name"
