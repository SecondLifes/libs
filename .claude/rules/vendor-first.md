# AI Rule: Vendor First
Version: 1.3.0
Status: ACTIVE
Author: System Architect
Son Güncelleme: 2026-07-15

## Kapsam
Vendor (mORMot2, UniDAC, DevEx, Jedi, TMS) kütüphanelerinin kullanım önceliği.
Contract-Provider-API soyutlaması (özel durum) kaldırılmıştır — artık tüm
durumlarda doğrudan vendor kullanımı esastır (bkz.
ai/memory/conflict-report.md ÇAKIŞMA 1&2 güncellemesi).

## Kurallar
1. Yeni kod üretiminde her zaman doğrudan vendor kullanımı esastır;
   interface/mocking soyutlama katmanına gerek yoktur.
2. Performans kritikse vendor'ın native API'ları (LITE) tercih edilmelidir.
3. Tekerleği yeniden icat etme: Eğer mORMot2 veya Spring4D bir özelliği
   sağlıyorsa onu kullan.

## Yeni Fonksiyon/Algoritma Yazmadan Önce Arama
Yeni bir fonksiyon veya algoritma (ör. bir performans düzeltmesi) yazmadan
ÖNCE Grep/Glob ile hem kendi kod tabanında hem `src\vendor` ağacında ara. Bu
sadece "doğrudan çağrılabilecek bir fonksiyon var mı" sorusu değil — bir
ALGORİTMA/YAKLAŞIM referansı da olabilir (2026-07-05'te `TDtSchedule.NextTime`'ı
hızlandırırken, aynı dosyanın kendi başlık yorumunda kaynağı olarak gösterilen
QDAC `TQPlanMask.GetNextTime` incelendi ve saniye-saniye yerine alan-bazlı
atlamalı arama yaptığı görüldü — bu, doğrudan kopyalanamasa bile [tip şekilleri
farklı olduğu için] uyarlanacak doğru yaklaşımı gösterdi).
