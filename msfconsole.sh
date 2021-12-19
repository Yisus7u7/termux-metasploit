#!/data/data/com.termux/files/usr/bin/sh

SCRIPT_NAME=$(basename "$0")
METASPLOIT_PATH="$PREFIX/opt/metasploit-framework"


case "$SCRIPT_NAME" in
	msfconsole)
		if [ ! -d "$PREFIX/var/lib/postgresql" ]; then
			mkdir -p "$PREFIX/var/lib/postgresql"
			initdb "$PREFIX/var/lib/postgresql"
		fi
		if ! pg_ctl -D "$PREFIX/var/lib/postgresql" status > /dev/null 2>&1; then
			pg_ctl -D "$PREFIX/var/lib/postgresql" start --silent
		fi
		if [ -z "$(psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='msf'")" ]; then
			createuser msf
		fi
		if [ -z "$(psql -l | grep msf_database)" ]; then
			createdb msf_database
		fi
		exec ruby "$METASPLOIT_PATH/$SCRIPT_NAME" "$@"
		;;
	msfd|msfrpc|msfrpcd|msfvenom)
		exec ruby "$METASPLOIT_PATH/$SCRIPT_NAME" "$@"
		;;
	*)
		echo "[!] Unknown Metasploit command '$SCRIPT_NAME'."
		exit 1
		;;
esac
