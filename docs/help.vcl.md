---
original_path: "D:\dev\Delphi\00-Lib\01\docs\units\help.vcl.md"
source: 01
copied_at_utc: 2026-07-02T17:23:22Z
sha256: a11ae7aa560190af63d742a21ed84cfdd4bb6e7224389d79e9029cabebb33f4b
---

# help.vcl
TForm, TWinControl, TObject, TMenuItem ve TAction için VCL helper'ları; form fabrikası ve event bridge.

## Gereksinimler
`Vcl.Forms`, `Vcl.Controls`, `Vcl.Menus`, `Vcl.ActnList`, `mormot.core.rtti`

## TFormHelper — Metodlar

| Metod | Açıklama |
|---|---|
| `_Show / _ShowModal` | Form gösterir, fluent |
| `_Hide / _Close` | Form gizler/kapatır, fluent |
| `_ShowWait` | Form aktif olana kadar bekler |
| `_AnimateShow` | Thread'de alpha-fade ile gösterir |
| `_FitToScreen([ratio])` | Formu ekranın ratio kadarına ölçekler |
| `_ScaleToCurrentMonitor` | Monitör DPI'ye göre yeniden ölçekler |
| `_Center` | Ekrana göre ortalar |
| `_DefaultKeySet` | Enter/Esc tuşlarını standartlaştırır |
| `_SetWindowsState(state)` | WindowState atar |

## TWinControlHelper — Metodlar

| Metod | Açıklama |
|---|---|
| `_Enable / _Disable` | Enabled atar, fluent |
| `_SetFocus` | Focus verir, fluent |
| `_SetParent(parent)` | Parent değiştirir, fluent |

## TObjectHelper — Metodlar

| Metod | Açıklama |
|---|---|
| `_ValueGet(path)` | RTTI ile nesne üzerinde path bazlı property okur |
| `_ValueSet(path, val)` | RTTI ile property yazar |

## TFormFactory

Form kayıt ve bulma fabrikası. Singleton (`GlobalFormFactory`).

| Metod | Açıklama |
|---|---|
| `RegisterForm(form)` | Form'u fabrikaya kaydeder |
| `UnregisterForm(form)` | Fabrikadan çıkarır |
| `GetForm<T>` | T tipinde kayıtlı formu döner |

## TFormEventBridge

Form WndProc olaylarını `ICmds` komutlarına bağlar.

```pascal
TFormEventBridge.CreateBridge(MyForm, GlobalCmds);
```

## Örnek

```pascal
uses help.vcl;

// Ekrana sığdırarak göster
MyForm._FitToScreen(0.8)._Center._Show;

// Modal + fluent
MyDetailForm._ShowModal;

// RTTI property okuma
var val := MyObj._ValueGet('Address.City');
```
