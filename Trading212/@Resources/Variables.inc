; ---------------------------------------------------------------------------
;  Layout, colours and runtime variables. Safe to edit / safe to commit.
;  Personal settings (API key and secret) live in Settings.inc instead.
; ---------------------------------------------------------------------------

[Variables]

; --- Layout ---------------------------------------------------------------
SkinWidth=248
SkinHeight=114
PaddingX=16

; --- Colours --------------------------------------------------------------
ColorBackground=20,22,26,235
ColorText=236,239,244,255
ColorTextDim=138,146,158,255
ColorUp=76,201,133,255
ColorDown=232,93,93,255
ColorFlat=138,146,158,255
ColorError=232,155,93,255

; --- Fonts ----------------------------------------------------------------
FontFace=Segoe UI
FontFaceValue=Segoe UI Semibold

; --- Text -----------------------------------------------------------------
; Currency signs as character references: this file must stay ASCII.
Euro=[\x20AC]
Pound=[\x00A3]

; --- API ------------------------------------------------------------------
BaseUrl=https://live.trading212.com

; --- Runtime values (overwritten by Portfolio.lua) ------------------------
TotalText=--
ChangeText=Waiting for data
ChangeColor=#ColorFlat#
StatusText=Loading
StatusColor=#ColorTextDim#
