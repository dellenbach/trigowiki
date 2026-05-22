chcp 65001
:: 6.7.2018, Del, Trigonet

REM Startzeit in DB schreiben
for /f "tokens=*" %%a in ('powershell -command "[guid]::NewGuid().ToString()"') do (set "uuid=%%a")
call "C:\Python\Python3\python.exe" "\\trigonet.local\gis\batchtools\Prozessmonitoring\Prozessmonitoring.py" "Startzeit" %uuid% "%0" "%DATE% %TIME%"

:: Mysql Backup
rem \\trigonet.local\gis\batchtools\mysql\mysqldump.exe -htrigowiki.trigonet.local -uroot  -ppw4mysql wikidb > \\trigonet.local\dfs\data\Archiv\SDE_Backup\Trigowiki_Backup\trigow_brisen.sql
\\trigonet.local\gis\batchtools\mysql\mysqldump.exe -htrigowiki.trigonet.local -uroot  -ppw4mysql wikidb > \\trigonet.local\DFS\SQL-Backup_trigonet.local\BRISEN\Trigowiki_Backup\trigow_brisen.sql

:: Filebackup

:: FULL
rem \\trigonet.local\gis\batchtools\putty\pscp.exe -scp -C -r -l del -pw trigowiki2018 trigowiki.trigonet.georz.com:/srv/mediawiki \\trigonet.local\DFS\SQL-Backup_trigonet.local\BRISEN\Trigowiki_Backup


:: IMAGES, Config Only echo y | auto store key
rem echo y | \\trigonet.local\gis\batchtools\putty\pscp.exe -scp -r -l del -pw trigowiki2018 trigowiki.trigonet.local:/srv/mediawiki/images \\trigonet.local\dfs\data\Archiv\SDE_Backup\Trigowiki_Backup\
rem echo y | \\trigonet.local\gis\batchtools\putty\pscp.exe -scp -r -l del -pw trigowiki2018 trigowiki.trigonet.local:/srv/mediawiki/config \\trigonet.local\dfs\data\Archiv\SDE_Backup\Trigowiki_Backup\


echo y | \\trigonet.local\gis\batchtools\putty\pscp.exe -scp -r -l del -pw trigowiki2018 trigowiki.trigonet.local:/srv/mediawiki/images \\trigonet.local\DFS\SQL-Backup_trigonet.local\BRISEN\Trigowiki_Backup\
echo y | \\trigonet.local\gis\batchtools\putty\pscp.exe -scp -r -l del -pw trigowiki2018 trigowiki.trigonet.local:/srv/mediawiki/config \\trigonet.local\DFS\SQL-Backup_trigonet.local\BRISEN\Trigowiki_Backup\

REM Endzeit in DB schreiben
call "C:\Python\Python3\python.exe" "\\trigonet.local\gis\batchtools\Prozessmonitoring\Prozessmonitoring.py" "Endzeit" %uuid% "%DATE% %TIME%"