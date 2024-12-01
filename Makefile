# isucon ユーザーじゃなければ適宜変更する
export ISUCON_USER=isucon
export ISUCON_GROUP=isucon

export NGINX_USER=root
export NGINX_GROUP=root

export MYSQL_USER=root
export MYSQL_GROUP=root

# 初回に実行する
# ディレクトリ作成・nginx / mysql の設定ファイルを取得
init: init-dir get-nginxconf get-mysqlconf

init-dir:
	mkdir -p conf/nginx/sites-enabled
	mkdir -p conf/nginx/sites-available
	mkdir -p log

# 各ツールのインストール
install-tools: install-pt-query-digest install-alp install-command

install-alp:
	wget https://github.com/tkuchiki/alp/releases/download/v1.0.9/alp_linux_amd64.zip
	sudo apt-get install -y unzip
	unzip alp_linux_amd64.zip
	sudo install ./alp /usr/local/bin
	rm alp
	rm alp_linux_amd64.zip

install-pt-query-digest:
	sudo apt-get update
	sudo apt-get install -y percona-toolkit

install-command:
	sudo apt-get install -y rsync

# 必要なら実行
# デフォルト 11211 ポート
# ※ Ruby の場合は Gemfile に gem 'dalli' を追加するなどクライアントのダウンロード別途必要
install-memcached:
	sudo apt install memcached

# 本番のサーバー構成に合わせて適宜書き換える
set-nginxconf:
	sudo rsync -rv conf/nginx/nginx.conf /etc/nginx/nginx.conf
	sudo rsync -rv conf/nginx/sites-enabled/* /etc/nginx/sites-enabled
	sudo rsync -rv conf/nginx/sites-available/* /etc/nginx/sites-available
	sudo chown ${NGINX_USER}:${NGINX_GROUP} /etc/nginx/nginx.conf
	sudo chown -R ${NGINX_USER}:${NGINX_GROUP} /etc/nginx/sites-enabled
	sudo chown -R ${NGINX_USER}:${NGINX_GROUP} /etc/nginx/sites-available

set-mysqlconf:
	sudo rsync -rv conf/mysqld.cnf /etc/mysql/mysql.conf.d
	sudo chown ${MYSQL_USER}:${MYSQL_GROUP} /etc/mysql/mysql.conf.d/mysqld.cnf

# 本番のサーバー構成に合わせて適宜書き換える
get-nginxconf:
	sudo rsync -rv /etc/nginx/nginx.conf conf/nginx
	sudo rsync -rv /etc/nginx/sites-enabled/* conf/nginx/sites-enabled
	sudo rsync -rv /etc/nginx/sites-available/* conf/nginx/sites-available
	sudo chown ${ISUCON_USER}:${ISUCON_GROUP} conf/nginx/nginx.conf
	sudo chown -R ${ISUCON_USER}:${ISUCON_GROUP} conf/nginx/sites-enabled
	sudo chown -R ${ISUCON_USER}:${ISUCON_GROUP} conf/nginx/sites-available

get-mysqlconf:
	sudo rsync -rv /etc/mysql/mysql.conf.d/mysqld.cnf conf/
	sudo chown ${ISUCON_USER}:${ISUCON_GROUP} conf/mysqld.cnf

# 現状のログをリポジトリ配下にコピー
copylog:
	sudo cat /var/log/nginx/access.log > /home/${ISUCON_USER}/log/nginx-access.log
	sudo cat /var/log/mysql/slow.log > /home/${ISUCON_USER}/log/slow.log

# pt-query-digest と alp でログを解析
# NOTE: alp の -m オプションの引数は適宜変更する
analyze:
	pt-query-digest cat /home/${ISUCON_USER}/log/slow.log > /home/${ISUCON_USER}/log/ptqd-result
	cat /home/${ISUCON_USER}/log/nginx-access.log | alp ltsv -m "/api/livestream/.*/livecomment/.*/report,/api/livestream/.*/exit,/api/livestream/.*/livecomment,/api/livestream/.*/ngwords,/api/livestream/.*/reaction,/api/livestream/.*/report,/api/livestream/.*/statistics,/api/livestream/.*/enter,/api/livestream/.*/livecomment,/api/livestream/.*/moderate,/api/livestream/.*/reaction,/api/livestream/reservation,/api/livestream/search,/api/livestream/.*,/api/livestream,/api/user/.*/icon,/api/user/.*/livestream,/api/user/.*/statistics,/api/user/.*/theme,/api/user/me,/api/user/.*" --sort=sum -r > /home/${ISUCON_USER}/log/alp-result

# 現状のログとその解析結果を git 配下にコピー
save-log:
	if [ -f "/home/${ISUCON_USER}/log/nginx-access.log" ]; then mv /home/${ISUCON_USER}/log/nginx-access.log /home/${ISUCON_USER}/log/nginx-access-`date "+%Y%m%d_%H%M%S"`.log ; fi
	if [ -f "/home/${ISUCON_USER}/log/slow.log" ]; then mv /home/${ISUCON_USER}/log/slow.log /home/${ISUCON_USER}/log/slow-`date "+%Y%m%d_%H%M%S"`.log ; fi
	if [ -f "/home/${ISUCON_USER}/log/ptqd-result" ]; then mv /home/${ISUCON_USER}/log/ptqd-result /home/${ISUCON_USER}/log/ptqd-result-`date "+%Y%m%d_%H%M%S"` ; fi
	if [ -f "/home/${ISUCON_USER}/log/alp-result" ]; then mv /home/${ISUCON_USER}/log/alp-result /home/${ISUCON_USER}/log/alp-result-`date "+%Y%m%d_%H%M%S"` ; fi

# ベンチ回す前に、以前の nginx / mysql のログを削除
cleanlog:
	sudo sh -c "echo > /var/log/mysql/slow.log"
	sudo sh -c "echo > /var/log/nginx/access.log"

# 各デーモンの再起動
# isupipe.ruby.service は適宜変更する
# memcached.service 入れる場合は以下も追加
# sudo systemctl restart memcached.service
restart:
	sudo systemctl restart nginx
	sudo systemctl restart mysql
	sudo systemctl restart isupipe-ruby.service

# ベンチ回す前の準備
prepare-bench: set-nginxconf set-mysqlconf restart cleanlog save-log

# ベンチ回した後のログ解析
after-bench: copylog analyze

# 簡易的に git に push
push:
	git add .
	git commit -m "push from Makefile"
	git push origin main
