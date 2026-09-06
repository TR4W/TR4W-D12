@echo off
cd c:\tr4w-d12

REM Seed every catalogue from the local LibreTranslate engine.
REM
REM --batch 40, NOT the mt_seed default of 1. The default is 1 because
REM batching maps results back BY POSITION, and a reordered response would
REM pair translations with the wrong keys silently. mt_seed alignment-checks
REM any batch >1 -- it re-translates a sample one at a time and compares --
REM so here the risk is guarded rather than merely accepted.
REM
REM It matters here and almost nowhere else: this script runs TWENTY
REM languages. Measured 2.04 s/string at --batch 1 against 0.12 s/string at
REM --batch 40: about 5 hours versus about 17 minutes for a full pass.
REM
REM A single ad-hoc `mt_seed.py --lang XXX` still defaults to 1, the right
REM default for the handful of new strings a normal run has to do.

python tools\i18n\mt_seed.py --batch 40 --lang CHN
python tools\i18n\mt_seed.py --batch 40 --lang CZE
python tools\i18n\mt_seed.py --batch 40 --lang DAN
python tools\i18n\mt_seed.py --batch 40 --lang DUT
python tools\i18n\mt_seed.py --batch 40 --lang ESP
python tools\i18n\mt_seed.py --batch 40 --lang FIN
python tools\i18n\mt_seed.py --batch 40 --lang FRA
python tools\i18n\mt_seed.py --batch 40 --lang GER
python tools\i18n\mt_seed.py --batch 40 --lang GRE
python tools\i18n\mt_seed.py --batch 40 --lang ITA
python tools\i18n\mt_seed.py --batch 40 --lang JPN
python tools\i18n\mt_seed.py --batch 40 --lang KOR
REM python tools\i18n\mt_seed.py --batch 40 --lang MNG
python tools\i18n\mt_seed.py --batch 40 --lang POL
python tools\i18n\mt_seed.py --batch 40 --lang POR
python tools\i18n\mt_seed.py --batch 40 --lang PTB
python tools\i18n\mt_seed.py --batch 40 --lang ROM
python tools\i18n\mt_seed.py --batch 40 --lang RUS
python tools\i18n\mt_seed.py --batch 40 --lang SER
python tools\i18n\mt_seed.py --batch 40 --lang SWE
python tools\i18n\mt_seed.py --batch 40 --lang UKR
