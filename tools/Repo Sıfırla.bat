@ECHO OFF
TITLE SecondLife
SETLOCAL EnableDelayedExpansion
chcp 65001 >nul

SET current=%~dp0
PUSHD "%current%.."
SET root=%CD%\
SET branchname=main
SET versionfile=%root%VERSION.txt

ECHO Root klasor: %root%
CD /D "%root%"

:: Git deposu kontrolu
IF NOT EXIST "%root%.git" (
    ECHO HATA: Bu klasor bir git deposu degil: %root%
    PAUSE
    EXIT /B 1
)

:: ============================
:: VERSIYON OKUMA / OLUSTURMA
:: ============================
IF NOT EXIST "%versionfile%" (
    ECHO VERSION.txt bulunamadi, 1.0.0 olarak olusturuluyor.
    ECHO 1.0.0> "%versionfile%"
)

SET /P oldversion=<"%versionfile%"

FOR /F "tokens=1,2,3 delims=." %%A IN ("%oldversion%") DO (
    SET major=%%A
    SET minor=%%B
    SET patch=%%C
)

ECHO.
ECHO Mevcut versiyon: %oldversion%
ECHO Hangi versiyonu artirmak istiyorsunuz?
ECHO   1 = Patch  (%major%.%minor%.%patch% -^> %major%.%minor%.%patch%+1)
ECHO   2 = Minor  (%major%.%minor%.%patch% -^> %major%.%minor%+1.0)
ECHO   3 = Major  (%major%.%minor%.%patch% -^> %major%+1.0.0)
ECHO   4 = Degistirme
SET /P vchoice=Seciminiz (1/2/3/4) [varsayilan 1]: 
IF "%vchoice%"=="" SET vchoice=1

IF "%vchoice%"=="1" (
    SET /A patch=patch+1
) ELSE IF "%vchoice%"=="2" (
    SET /A minor=minor+1
    SET patch=0
) ELSE IF "%vchoice%"=="3" (
    SET /A major=major+1
    SET minor=0
    SET patch=0
)

SET newversion=%major%.%minor%.%patch%
ECHO.
ECHO Onceki versiyon : %oldversion%
ECHO Yeni versiyon   : %newversion%

:: ============================
:: COMMIT MESAJI ALMA (kullanicidan)
:: ============================
ECHO.
SET /P subject=Commit basligi girin [varsayilan: v%newversion% - Guncelleme]: 
IF "%subject%"=="" SET subject=v%newversion% - Guncelleme

ECHO Commit aciklamasi girin (bos birakabilirsiniz):
SET /P description=

(
ECHO %subject%
ECHO.
IF NOT "%description%"=="" (
    ECHO %description%
    ECHO.
)
ECHO Onceki versiyon : %oldversion%
ECHO Yeni versiyon   : %newversion%
ECHO Tarih           : %date% %time%
) > "%TEMP%\commitmsg.txt"

:: ============================
:: ISLEM TURU SECIMI
:: ============================
ECHO.
ECHO Islem turunu seçin:
ECHO   1 = Normal commit ^(gecmis KORUNUR, sadece degisiklikler gonderilir^) [VARSAYILAN]
ECHO   2 = Gecmisi TAMAMEN SIFIRLA ^(local + remote, GERI ALINAMAZ^)
SET /P mode=Seciminiz (1/2) [varsayilan 1]: 
IF "%mode%"=="" SET mode=1

:: Versiyon dosyasini guncelle (her iki modda da)
ECHO %newversion%> "%versionfile%"

IF "%mode%"=="2" GOTO :RESET_HISTORY

:: ============================
:: NORMAL COMMIT + PUSH (VARSAYILAN)
:: ============================
ECHO.
ECHO Normal commit yapiliyor, gecmis korunuyor...

git add .
IF ERRORLEVEL 1 (
    ECHO HATA: git add basarisiz!
    DEL "%TEMP%\commitmsg.txt"
    PAUSE
    EXIT /B 1
)

git commit -F "%TEMP%\commitmsg.txt"
IF ERRORLEVEL 1 (
    ECHO HATA: git commit basarisiz! ^(Belki de commit edilecek degisiklik yok^)
    DEL "%TEMP%\commitmsg.txt"
    PAUSE
    EXIT /B 1
)
DEL "%TEMP%\commitmsg.txt"

git push origin %branchname%
IF ERRORLEVEL 1 (
    ECHO HATA: git push basarisiz!
    PAUSE
    EXIT /B 1
)

git tag -f "v%newversion%"
git push origin "v%newversion%"

ECHO.
ECHO Islem basariyla tamamlandi: v%oldversion% -^> v%newversion%  ^(gecmis korundu^)
GOTO :SONA

:: ============================
:: GECMISI TAMAMEN SIFIRLA
:: ============================
:RESET_HISTORY
ECHO.
ECHO DIKKAT: Bu islem uzak repodaki TUM GECMISI silecek ve GERI ALINAMAZ!
ECHO Emin misiniz? (E/H)
SET /P onay=
IF /I NOT "%onay%"=="E" (
    ECHO Islem iptal edildi.
    PAUSE
    EXIT /B 0
)

:: Yedek
git branch backup-old-%branchname% %branchname%

:: Gecmissiz yeni branch
git checkout --orphan new-%branchname%

git add .
IF ERRORLEVEL 1 (
    ECHO HATA: git add basarisiz!
    PAUSE
    EXIT /B 1
)

git commit -F "%TEMP%\commitmsg.txt" 2>nul
IF NOT EXIST "%TEMP%\commitmsg.txt" (
    git commit -m "%subject%"
) 

git branch -D %branchname%
git branch -m %branchname%

git push -f -u origin %branchname%
IF ERRORLEVEL 1 (
    ECHO HATA: git push basarisiz!
    PAUSE
    EXIT /B 1
)

git tag -f "v%newversion%"
git push -f origin "v%newversion%"

ECHO.
ECHO Islem basariyla tamamlandi: v%oldversion% -^> v%newversion%  ^(GECMIS SIFIRLANDI^)

:SONA
POPD
ENDLOCAL
PAUSE