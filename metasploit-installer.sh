#!/data/data/com.termux/files/usr/bin/bash

export TERMUX_PREFIX=/data/data/com.termux/files/usr
export TERMUX_OPT=$TERMUX_PREFIX/opt
METASPLOIT_URL=https://github.com/rapid7/metasploit-framework.git

mkdir -p $TERMUX_OPT

for i in aarch64-linux-android arm-linux-androideabi \
    i686-linux-android x86_64-linux-android; do

    if [ -e "$PREFIX/lib/ruby/3.0.0/${i}/bigdecimal.so" ]; then
        if [ -n "$(patchelf --print-needed "$PREFIX/lib/ruby/3.0.0/${i}/bigdecimal/util.so" | grep bigdecimal.so)" ]; then
            exit 0
        fi

        patchelf --add-needed \
            "$PREFIX/lib/ruby/3.0.0/${i}/bigdecimal.so" \
            "$PREFIX/lib/ruby/3.0.0/${i}/bigdecimal/util.so"
    fi
done

echo "[*] Removing previous version Metasploit Framework..."
rm -rf "$TERMUX_PREFIX"/opt/metasploit-framework

echo "[*] Downloading Metasploit Framework..."
cd $TERMUX_OPT
git clone --depth 1 $METASPLOIT_URL

echo "[*] Installing 'rubygems-update' if necessary..."
gem install --no-document --verbose rubygems-update

echo "[*] Updating Ruby gems..."
update_rubygems

echo "[*] Installing 'bundler'..."
gem install --no-document --verbose bundler

echo "[*] Installing Metasploit dependencies (may take long time)..."
gem install nokogiri -- --use-system-libraries
bundle config build.nokogiri --use-system-libraries
gem install actionpack
cd $TERMUX_OPT/metasploit-framework
bundle install -j$(nproc --all) --verbose

echo "[*] Running fixes..."
cd $TERMUX_OPT/metasploit-framework
sed -i "s@/etc/resolv.conf@$TERMUX_PREFIX/etc/resolv.conf@g" "$TERMUX_PREFIX"/opt/metasploit-framework/lib/net/dns/resolver.rb
find "$TERMUX_PREFIX"/opt/metasploit-framework -type f -executable -print0 | xargs -0 -r termux-fix-shebang
find "$TERMUX_PREFIX"/lib/ruby/gems -type f -iname \*.so -print0 | xargs -0 -r termux-elf-cleaner

for i in msfd msfrpc msfrpcd msfvenom; do
		ln -sfr "$TERMUX_PREFIX"/bin/msfconsole "$TERMUX_PREFIX"/bin/$i
	done

echo "[*] Setting up PostgreSQL database..."
mkdir -p "$TERMUX_PREFIX"/opt/metasploit-framework/config
cat <<- EOF > "$TERMUX_PREFIX"/opt/metasploit-framework/config/database.yml
production:
  adapter: postgresql
  database: msf_database
  username: msf
  password:
  host: 127.0.0.1
  port: 5432
  pool: 75
  timeout: 5
EOF
mkdir -p "$TERMUX_PREFIX"/var/lib/postgresql
pg_ctl -D "$TERMUX_PREFIX"/var/lib/postgresql stop > /dev/null 2>&1 || true
if ! pg_ctl -D "$TERMUX_PREFIX"/var/lib/postgresql start --silent; then
    initdb "$TERMUX_PREFIX"/var/lib/postgresql
    pg_ctl -D "$TERMUX_PREFIX"/var/lib/postgresql start --silent
fi
if [ -z "$(psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='msf'")" ]; then
    createuser msf
fi
if [ -z "$(psql -l | grep msf_database)" ]; then
    createdb msf_database
fi

# Clean some git cache
rm -rf $TERMUX_OPT/metasploit-framework/.git*
cd $HOME
echo "[*] Metasploit Framework installation finished."
echo "[*] Package made by @Yisus7u7 <jesuspixel5@gmail.com"

exit 0
