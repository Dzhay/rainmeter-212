; ---------------------------------------------------------------------------
;  Trading 212 skin - personal settings
;
;  1. Generate an API key in the Trading 212 app (Live mode):
;       Settings -> API -> Generate key
;     Enable ONLY the "Account data" permission. Leave everything else off,
;     especially anything mentioning orders or trading.
;  2. The app shows an API key and an API secret. The secret is shown once.
;     Paste both below and save. The skin starts within 5 seconds.
;
;  This file is plain text - anyone with access to your Windows profile can
;  read it. Do not screenshot or stream it. Reinstalling the .rmskin keeps
;  the values you enter here.
; ---------------------------------------------------------------------------

[Variables]

ApiKey=
ApiSecret=

; Seconds between API polls. account/summary allows 1 request per 5 seconds.
RefreshSeconds=60

; Leave empty to use your account's currency: EUR, GBP and USD show their
; sign, any other currency shows its code (e.g. "PLN 1,234.56"). Set it to
; override, e.g. US$ . This file must stay ASCII, so write other signs as
; character references, e.g. [\x00A5] for the yen sign.
CurrencySymbol=
